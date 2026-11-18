use std::collections::HashMap;
use std::future::Future;
use std::io::SeekFrom;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use futures_util::stream::{FuturesUnordered, StreamExt};
use sha2::{Digest, Sha256};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};
use tokio::sync::{mpsc, watch, Semaphore};
use tracing::{debug, info, warn};

use crate::crypto::{self, ENCRYPTED_CHUNK_OVERHEAD};
use crate::db::Database;
use crate::error::{CoreError, Result};
use crate::models::{
    FileChunk, FileRecord, NewFile, NewFileChunk, TaskKind, TaskRecord, TaskState,
};
use crate::telegram::TelegramClient;

/// Default maximum chunk size: 1 GiB.
pub const DEFAULT_CHUNK_SIZE: u64 = 1024 * 1024 * 1024;

/// Default number of chunks transferred concurrently per file.
pub const DEFAULT_MAX_CONCURRENT_CHUNKS: usize = 3;

const IO_BUFFER_SIZE: usize = 64 * 1024;

/// Byte range specification for a single file chunk.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChunkSpec {
    pub index: u64,
    pub offset: u64,
    pub size: u64,
}

/// Automatic retry configuration for Telegram `FLOOD_WAIT` responses.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RetryPolicy {
    pub max_retries: u32,
    pub max_flood_wait_secs: u64,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_retries: 5,
            max_flood_wait_secs: 300,
        }
    }
}

/// Configuration controlling chunk sizing, parallel chunk transfers, and `FloodWait` retries.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChunkerConfig {
    pub chunk_size: u64,
    pub max_concurrent_chunks: usize,
    pub retry_policy: RetryPolicy,
}

impl Default for ChunkerConfig {
    fn default() -> Self {
        Self {
            chunk_size: DEFAULT_CHUNK_SIZE,
            max_concurrent_chunks: DEFAULT_MAX_CONCURRENT_CHUNKS,
            retry_policy: RetryPolicy::default(),
        }
    }
}

impl ChunkerConfig {
    /// Creates a validated chunker configuration with a positive chunk size in bytes.
    pub fn new(chunk_size: u64) -> Result<Self> {
        if chunk_size == 0 {
            return Err(CoreError::InvalidConfig(
                "chunk_size must be greater than zero".to_string(),
            ));
        }
        Ok(Self {
            chunk_size,
            ..Self::default()
        })
    }

    /// Sets maximum concurrent chunk uploads/downloads per file.
    pub fn with_concurrency(mut self, max_concurrent_chunks: usize) -> Result<Self> {
        if max_concurrent_chunks == 0 {
            return Err(CoreError::InvalidConfig(
                "max_concurrent_chunks must be greater than zero".to_string(),
            ));
        }
        self.max_concurrent_chunks = max_concurrent_chunks;
        Ok(self)
    }

    /// Overrides the `FLOOD_WAIT` retry policy.
    pub fn with_retry_policy(mut self, retry_policy: RetryPolicy) -> Self {
        self.retry_policy = retry_policy;
        self
    }
}

/// Real-time notifications emitted during a file transfer.
#[derive(Debug, Clone, PartialEq)]
pub enum TransferNotice {
    Progress {
        task_id: i64,
        file_id: i64,
        kind: TaskKind,
        progress: f64,
    },
    FloodWait {
        task_id: i64,
        file_id: i64,
        seconds: u64,
        attempt: u32,
    },
}

/// Plans sequential byte-range chunks for a file of `file_size` bytes.
///
/// Returns an empty vector when `file_size == 0`.
pub fn plan_chunks(file_size: u64, chunk_size: u64) -> Result<Vec<ChunkSpec>> {
    if chunk_size == 0 {
        return Err(CoreError::InvalidConfig(
            "chunk_size must be greater than zero".to_string(),
        ));
    }
    if file_size == 0 {
        return Ok(Vec::new());
    }

    let mut specs = Vec::new();
    let mut offset = 0u64;
    let mut index = 0u64;

    while offset < file_size {
        let remaining = file_size - offset;
        let size = remaining.min(chunk_size);
        specs.push(ChunkSpec {
            index,
            offset,
            size,
        });
        offset += size;
        index += 1;
    }

    Ok(specs)
}

/// Computes the lowercase hex SHA-256 digest of a file using streaming I/O.
pub async fn compute_file_sha256(path: &Path) -> Result<String> {
    let mut file = tokio::fs::File::open(path).await?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; IO_BUFFER_SIZE];

    loop {
        let n = file.read(&mut buf).await?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }

    Ok(hex::encode(hasher.finalize()))
}

/// Abstraction over chunk upload/download transport (Telegram in production, mock in tests).
pub trait ChunkTransport: Send + Sync {
    /// Uploads `size` bytes starting at `offset` from `path` and returns the Telegram message ID.
    fn upload_chunk(
        &self,
        path: &Path,
        offset: u64,
        size: u64,
        file_name: String,
        caption: String,
    ) -> impl Future<Output = Result<i32>> + Send;

    /// Uploads an in-memory chunk buffer (e.g. encrypted payload) and returns the message ID.
    fn upload_bytes(
        &self,
        data: Vec<u8>,
        file_name: String,
        caption: String,
    ) -> impl Future<Output = Result<i32>> + Send;

    /// Downloads the chunk payload referenced by `message_id` into `dest`.
    fn download_chunk(
        &self,
        message_id: i32,
        dest: &Path,
    ) -> impl Future<Output = Result<()>> + Send;
}

impl ChunkTransport for TelegramClient {
    async fn upload_chunk(
        &self,
        path: &Path,
        offset: u64,
        size: u64,
        file_name: String,
        caption: String,
    ) -> Result<i32> {
        let size_usize = usize::try_from(size).map_err(|_| {
            CoreError::InvalidConfig(format!(
                "chunk size {size} exceeds addressable usize on this platform"
            ))
        })?;
        let mut file = tokio::fs::File::open(path).await?;
        file.seek(SeekFrom::Start(offset)).await?;
        let mut limited = file.take(size);
        self.upload_stream(&mut limited, size_usize, file_name, &caption)
            .await
    }

    async fn upload_bytes(&self, data: Vec<u8>, file_name: String, caption: String) -> Result<i32> {
        self.upload_bytes(data, file_name, &caption).await
    }

    async fn download_chunk(&self, message_id: i32, dest: &Path) -> Result<()> {
        self.download_file(message_id, dest).await
    }
}

/// Orchestrates chunked, parallel, resumable, `FloodWait`-resilient transfers.
pub struct TransferEngine<'a, T: ChunkTransport> {
    db: &'a Database,
    transport: &'a T,
    config: ChunkerConfig,
    notifier: Option<mpsc::UnboundedSender<TransferNotice>>,
    encryption_password: Option<String>,
    pause_signal: Option<watch::Receiver<bool>>,
}

impl<'a, T: ChunkTransport> TransferEngine<'a, T> {
    /// Creates a new transfer engine backed by `db` and `transport`.
    pub fn new(db: &'a Database, transport: &'a T, config: ChunkerConfig) -> Self {
        Self {
            db,
            transport,
            config,
            notifier: None,
            encryption_password: None,
            pause_signal: None,
        }
    }

    /// Attaches an optional live progress/`FloodWait` notification channel.
    pub fn with_notifier(mut self, notifier: mpsc::UnboundedSender<TransferNotice>) -> Self {
        self.notifier = Some(notifier);
        self
    }

    /// Enables client-side AES-256-GCM chunk encryption/decryption when `Some(non_empty_password)`.
    pub fn with_encryption_password(mut self, password: Option<String>) -> Self {
        self.encryption_password = password.filter(|p| !p.is_empty());
        self
    }

    /// Attaches a cooperative pause watch channel checked during chunk transfers.
    pub fn with_pause_signal(mut self, pause_signal: watch::Receiver<bool>) -> Self {
        self.pause_signal = Some(pause_signal);
        self
    }

    fn is_paused(&self) -> bool {
        self.pause_signal
            .as_ref()
            .is_some_and(|rx| *rx.borrow())
    }

    /// Uploads `source_path` in parallel chunks into `folder_id`, automatically resuming
    /// any interrupted upload for the same file identity (folder, name, size, SHA-256).
    pub async fn upload_file(
        &self,
        source_path: &Path,
        folder_id: Option<i64>,
    ) -> Result<FileRecord> {
        if !source_path.is_file() {
            return Err(CoreError::InvalidConfig(format!(
                "source path '{}' must point to an existing file",
                source_path.display()
            )));
        }
        let file_name = source_path
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .ok_or_else(|| {
                CoreError::InvalidConfig(format!(
                    "source path '{}' does not have a valid file name",
                    source_path.display()
                ))
            })?;

        let file_size = tokio::fs::metadata(source_path).await?.len();
        let file_size_i64 = i64::try_from(file_size).map_err(|_| {
            CoreError::InvalidConfig(format!("file size {file_size} exceeds i64::MAX"))
        })?;
        let mime_type = mime_guess::from_path(source_path)
            .first_or_octet_stream()
            .essence_str()
            .to_string();

        info!(path = %source_path.display(), size = file_size, "Computing SHA-256 before upload");
        let sha256 = compute_file_sha256(source_path).await?;
        let is_encrypted = self.encryption_password.is_some();

        let file = self
            .resolve_or_create_file(
                folder_id,
                &file_name,
                file_size_i64,
                &mime_type,
                &sha256,
                is_encrypted,
            )
            .await?;

        let task = self.acquire_task(TaskKind::Upload, file.id).await?;
        self.emit_notice(TransferNotice::Progress {
            task_id: task.id,
            file_id: file.id,
            kind: TaskKind::Upload,
            progress: task.progress,
        });
        if self.is_paused() {
            self.mark_task_paused(task.id, task.progress).await;
            return Err(CoreError::TaskPaused);
        }
        let existing_chunks: HashMap<u64, FileChunk> = self
            .db
            .list_file_chunks(file.id)
            .await?
            .into_iter()
            .filter_map(|chunk| {
                u64::try_from(chunk.chunk_index)
                    .ok()
                    .map(|idx| (idx, chunk))
            })
            .collect();

        let specs = plan_chunks(file_size, self.config.chunk_size)?;
        let total_chunks = specs.len();
        let per_chunk_overhead = if is_encrypted {
            ENCRYPTED_CHUNK_OVERHEAD
        } else {
            0
        };
        let (pending_specs, mut uploaded_bytes) = match partition_existing_chunks(
            &specs,
            &existing_chunks,
            file.id,
            per_chunk_overhead,
        ) {
            Ok(res) => res,
            Err(err) => {
                self.mark_task_failed(task.id, 0.0, &err).await;
                return Err(err);
            }
        };

        if uploaded_bytes > 0 {
            self.report_progress(
                task.id,
                file.id,
                TaskKind::Upload,
                fraction(uploaded_bytes, file_size),
            )
            .await;
        }

        if let Err(err) = self
            .upload_pending_chunks(
                source_path,
                &file_name,
                &file,
                task.id,
                total_chunks,
                file_size,
                pending_specs,
                &mut uploaded_bytes,
            )
            .await
        {
            if matches!(err, CoreError::TaskPaused) {
                self.mark_task_paused(task.id, fraction(uploaded_bytes, file_size))
                    .await;
            } else {
                self.mark_task_failed(task.id, fraction(uploaded_bytes, file_size), &err)
                    .await;
            }
            return Err(err);
        }

        self.db
            .update_task_progress(task.id, TaskState::Completed, 1.0, None)
            .await?;
        self.emit_notice(TransferNotice::Progress {
            task_id: task.id,
            file_id: file.id,
            kind: TaskKind::Upload,
            progress: 1.0,
        });
        info!(file_id = file.id, name = %file.name, chunks = total_chunks, encrypted = is_encrypted, "Chunked upload completed");
        Ok(file)
    }

    #[allow(clippy::too_many_arguments)]
    async fn upload_pending_chunks(
        &self,
        source_path: &Path,
        file_name: &str,
        file: &FileRecord,
        task_id: i64,
        total_chunks: usize,
        file_size: u64,
        pending_specs: Vec<ChunkSpec>,
        uploaded_bytes: &mut u64,
    ) -> Result<()> {
        let concurrency = self.config.max_concurrent_chunks.max(1);
        let semaphore = Arc::new(Semaphore::new(concurrency));
        let mut in_flight = FuturesUnordered::new();

        for spec in pending_specs {
            let permit_sem = Arc::clone(&semaphore);
            let chunk_name = format_chunk_file_name(file_name, spec.index, total_chunks);
            let caption = format!("{file_name} [{}/{}]", spec.index + 1, total_chunks);
            let policy = self.config.retry_policy;
            let notifier = self.notifier.as_ref();
            let file_id = file.id;
            let enc_pw = self.encryption_password.clone();

            in_flight.push(async move {
                let _permit = permit_sem.acquire().await.map_err(|_| {
                    CoreError::InvalidConfig("upload chunk semaphore closed".to_string())
                })?;

                let (msg_id, stored_size) = if let Some(password) = enc_pw {
                    let encrypted = read_and_encrypt_chunk(source_path, spec, password).await?;
                    let enc_len = encrypted.len() as u64;
                    let msg_id = retry_on_flood_wait(policy, task_id, file_id, notifier, || {
                        self.transport.upload_bytes(
                            encrypted.clone(),
                            chunk_name.clone(),
                            caption.clone(),
                        )
                    })
                    .await?;
                    (msg_id, enc_len)
                } else {
                    let msg_id = retry_on_flood_wait(policy, task_id, file_id, notifier, || {
                        self.transport.upload_chunk(
                            source_path,
                            spec.offset,
                            spec.size,
                            chunk_name.clone(),
                            caption.clone(),
                        )
                    })
                    .await?;
                    (msg_id, spec.size)
                };

                Ok::<(ChunkSpec, i32, u64), CoreError>((spec, msg_id, stored_size))
            });
        }

        let mut pause_rx = self.pause_signal.clone();
        loop {
            let res = tokio::select! {
                biased;
                _ = wait_for_pause_signal(pause_rx.as_mut()) => {
                    return Err(CoreError::TaskPaused);
                }
                maybe_res = in_flight.next() => {
                    let Some(res) = maybe_res else { break; };
                    res
                }
            };
            let (spec, msg_id, stored_size) = res?;
            let chunk_index_i64 = i64::try_from(spec.index).map_err(|_| {
                CoreError::InvalidConfig(format!("chunk index {} exceeds i64::MAX", spec.index))
            })?;
            let chunk_size_i64 = i64::try_from(stored_size).map_err(|_| {
                CoreError::InvalidConfig(format!("chunk size {stored_size} exceeds i64::MAX"))
            })?;

            self.db
                .insert_file_chunk(&NewFileChunk {
                    file_id: file.id,
                    chunk_index: chunk_index_i64,
                    telegram_message_id: msg_id,
                    size: chunk_size_i64,
                })
                .await?;

            *uploaded_bytes += spec.size;
            self.report_progress(
                task_id,
                file.id,
                TaskKind::Upload,
                fraction(*uploaded_bytes, file_size),
            )
            .await;
        }

        Ok(())
    }

    /// Downloads all chunks for `file_id` concurrently, resumes any already-staged chunk files,
    /// decrypts (if encrypted), reassembles them in order into `dest_path`, and verifies SHA-256.
    pub async fn download_file(&self, file_id: i64, dest_path: &Path) -> Result<()> {
        if dest_path.file_name().is_none() {
            return Err(CoreError::InvalidConfig(format!(
                "destination path '{}' must include a file name",
                dest_path.display()
            )));
        }

        let file = self.db.get_file(file_id).await?;
        if file.is_encrypted && self.encryption_password.is_none() {
            return Err(CoreError::Encryption(
                "file is encrypted; provide a decryption password".to_string(),
            ));
        }

        let chunks = self.db.list_file_chunks(file_id).await?;
        let total_chunk_bytes = validate_chunks(&file, &chunks)?;

        let task = self.acquire_task(TaskKind::Download, file.id).await?;
        self.emit_notice(TransferNotice::Progress {
            task_id: task.id,
            file_id: file.id,
            kind: TaskKind::Download,
            progress: task.progress,
        });
        if self.is_paused() {
            self.mark_task_paused(task.id, task.progress).await;
            return Err(CoreError::TaskPaused);
        }

        if let Some(parent) = dest_path.parent().filter(|p| !p.as_os_str().is_empty()) {
            tokio::fs::create_dir_all(parent).await?;
        }

        let downloaded_bytes = AtomicU64::new(0);
        let part_paths = match self
            .download_missing_chunks(
                &file,
                total_chunk_bytes,
                &chunks,
                dest_path,
                task.id,
                &downloaded_bytes,
            )
            .await
        {
            Ok(paths) => paths,
            Err(err) => {
                let done = downloaded_bytes.load(Ordering::Relaxed);
                if matches!(err, CoreError::TaskPaused) {
                    self.mark_task_paused(task.id, fraction(done, total_chunk_bytes))
                        .await;
                } else {
                    self.mark_task_failed(task.id, fraction(done, total_chunk_bytes), &err)
                        .await;
                }
                return Err(err);
            }
        };

        let assembling_path = staging_path(dest_path, &format!("assembling.{}", file.id))?;
        let decrypt_pw = if file.is_encrypted {
            self.encryption_password.as_deref()
        } else {
            None
        };
        if let Err(err) =
            reassemble_and_verify(&part_paths, &file.sha256, &assembling_path, decrypt_pw).await
        {
            let _ = tokio::fs::remove_file(&assembling_path).await;
            self.mark_task_failed(task.id, 1.0, &err).await;
            return Err(err);
        }

        if let Err(err) = tokio::fs::rename(&assembling_path, dest_path).await {
            let _ = tokio::fs::remove_file(&assembling_path).await;
            let core_err = CoreError::Io(err);
            self.mark_task_failed(task.id, 1.0, &core_err).await;
            return Err(core_err);
        }

        cleanup_part_files(&part_paths).await;
        self.db
            .update_task_progress(task.id, TaskState::Completed, 1.0, None)
            .await?;
        self.emit_notice(TransferNotice::Progress {
            task_id: task.id,
            file_id: file.id,
            kind: TaskKind::Download,
            progress: 1.0,
        });

        info!(file_id = file.id, dest = %dest_path.display(), "Chunked download and SHA-256 verification completed");
        Ok(())
    }

    async fn resolve_or_create_file(
        &self,
        folder_id: Option<i64>,
        name: &str,
        size: i64,
        mime_type: &str,
        sha256: &str,
        is_encrypted: bool,
    ) -> Result<FileRecord> {
        if let Some(existing) = self
            .db
            .find_file_by_identity(folder_id, name, size, sha256, is_encrypted)
            .await?
        {
            info!(file_id = existing.id, name = %existing.name, "Resuming existing file record");
            return Ok(existing);
        }

        self.db
            .create_file(&NewFile {
                folder_id,
                name: name.to_string(),
                size,
                mime_type: mime_type.to_string(),
                sha256: sha256.to_string(),
                is_encrypted,
            })
            .await
    }

    async fn acquire_task(&self, kind: TaskKind, file_id: i64) -> Result<TaskRecord> {
        if let Some(existing) = self.db.find_active_task_for_file(file_id, kind).await? {
            return self
                .db
                .update_task_progress(existing.id, TaskState::Running, existing.progress, None)
                .await;
        }
        let created = self.db.create_task(kind, file_id).await?;
        self.db
            .update_task_progress(created.id, TaskState::Running, 0.0, None)
            .await
    }

    async fn report_progress(&self, task_id: i64, file_id: i64, kind: TaskKind, progress: f64) {
        let clamped = progress.clamp(0.0, 1.0);
        let _ = self
            .db
            .update_task_progress(task_id, TaskState::Running, clamped, None)
            .await;
        self.emit_notice(TransferNotice::Progress {
            task_id,
            file_id,
            kind,
            progress: clamped,
        });
    }

    fn emit_notice(&self, notice: TransferNotice) {
        if let Some(tx) = &self.notifier {
            let _ = tx.send(notice);
        }
    }

    async fn mark_task_paused(&self, task_id: i64, progress: f64) {
        let clamped = progress.clamp(0.0, 1.0);
        let _ = self
            .db
            .update_task_progress(task_id, TaskState::Paused, clamped, None)
            .await;
    }

    async fn mark_task_failed(&self, task_id: i64, progress: f64, err: &CoreError) {
        let clamped = progress.clamp(0.0, 1.0);
        let msg = err.to_string();
        let _ = self
            .db
            .update_task_progress(task_id, TaskState::Failed, clamped, Some(&msg))
            .await;
    }

    async fn download_missing_chunks(
        &self,
        file: &FileRecord,
        expected_bytes: u64,
        chunks: &[FileChunk],
        dest_path: &Path,
        task_id: i64,
        downloaded_bytes: &AtomicU64,
    ) -> Result<Vec<PathBuf>> {
        let mut ordered_parts: Vec<Option<PathBuf>> = vec![None; chunks.len()];
        let concurrency = self.config.max_concurrent_chunks.max(1);
        let semaphore = Arc::new(Semaphore::new(concurrency));
        let mut in_flight = FuturesUnordered::new();

        for (pos, chunk) in chunks.iter().enumerate() {
            let chunk_size = u64::try_from(chunk.size).map_err(|_| {
                CoreError::InvalidConfig(format!("chunk {} has negative size", chunk.id))
            })?;
            let part_path = staging_path(
                dest_path,
                &format!("part.{}.{}", file.id, chunk.chunk_index),
            )?;

            if let Ok(meta) = tokio::fs::metadata(&part_path).await {
                if meta.is_file() && meta.len() == chunk_size {
                    debug!(
                        file_id = file.id,
                        chunk_index = chunk.chunk_index,
                        "Reusing already-downloaded chunk part"
                    );
                    downloaded_bytes.fetch_add(chunk_size, Ordering::Relaxed);
                    ordered_parts[pos] = Some(part_path);
                    continue;
                }
            }

            let tmp_path =
                staging_path(dest_path, &format!("tmp.{}.{}", file.id, chunk.chunk_index))?;
            let permit_sem = Arc::clone(&semaphore);
            let policy = self.config.retry_policy;
            let notifier = self.notifier.as_ref();
            let file_id = file.id;
            let msg_id = chunk.telegram_message_id;

            in_flight.push(async move {
                let _permit = permit_sem.acquire().await.map_err(|_| {
                    CoreError::InvalidConfig("download chunk semaphore closed".to_string())
                })?;

                let _ = tokio::fs::remove_file(&tmp_path).await;

                if let Err(err) =
                    retry_on_flood_wait(policy, task_id, file_id, notifier, || async {
                        let _ = tokio::fs::remove_file(&tmp_path).await;
                        self.transport.download_chunk(msg_id, &tmp_path).await
                    })
                    .await
                {
                    let _ = tokio::fs::remove_file(&tmp_path).await;
                    return Err(err);
                }

                let actual_size = tokio::fs::metadata(&tmp_path).await?.len();
                if actual_size != chunk_size {
                    let _ = tokio::fs::remove_file(&tmp_path).await;
                    return Err(CoreError::IncompleteChunks {
                        file_id,
                        expected_bytes: chunk_size,
                        actual_bytes: actual_size,
                    });
                }

                tokio::fs::rename(&tmp_path, &part_path).await?;
                Ok::<(usize, PathBuf, u64), CoreError>((pos, part_path, chunk_size))
            });
        }

        let reused_bytes = downloaded_bytes.load(Ordering::Relaxed);
        if reused_bytes > 0 {
            self.report_progress(
                task_id,
                file.id,
                TaskKind::Download,
                fraction(reused_bytes, expected_bytes),
            )
            .await;
        }

        let mut pause_rx = self.pause_signal.clone();
        loop {
            let res = tokio::select! {
                biased;
                _ = wait_for_pause_signal(pause_rx.as_mut()) => {
                    return Err(CoreError::TaskPaused);
                }
                maybe_res = in_flight.next() => {
                    let Some(res) = maybe_res else { break; };
                    res
                }
            };
            let (pos, part_path, chunk_size) = res?;
            ordered_parts[pos] = Some(part_path);
            let total_done = downloaded_bytes.fetch_add(chunk_size, Ordering::Relaxed) + chunk_size;
            self.report_progress(
                task_id,
                file.id,
                TaskKind::Download,
                fraction(total_done, expected_bytes),
            )
            .await;
        }

        Ok(ordered_parts.into_iter().flatten().collect())
    }
}

async fn wait_for_pause_signal(sig: Option<&mut watch::Receiver<bool>>) {
    let Some(rx) = sig else {
        std::future::pending::<()>().await;
        return;
    };
    loop {
        if *rx.borrow_and_update() {
            return;
        }
        if rx.changed().await.is_err() {
            std::future::pending::<()>().await;
            return;
        }
    }
}

async fn read_and_encrypt_chunk(
    source_path: &Path,
    spec: ChunkSpec,
    password: String,
) -> Result<Vec<u8>> {
    let size_usize = usize::try_from(spec.size).map_err(|_| {
        CoreError::InvalidConfig(format!(
            "chunk size {} exceeds addressable usize on this platform",
            spec.size
        ))
    })?;
    let mut file = tokio::fs::File::open(source_path).await?;
    file.seek(SeekFrom::Start(spec.offset)).await?;
    let mut plain = vec![0u8; size_usize];
    file.read_exact(&mut plain).await?;

    tokio::task::spawn_blocking(move || crypto::encrypt_bytes(&plain, &password))
        .await
        .map_err(|err| CoreError::Encryption(format!("encryption worker panicked: {err}")))?
}

fn partition_existing_chunks(
    specs: &[ChunkSpec],
    existing_chunks: &HashMap<u64, FileChunk>,
    file_id: i64,
    per_chunk_overhead: u64,
) -> Result<(Vec<ChunkSpec>, u64)> {
    let mut pending = Vec::new();
    let mut uploaded_bytes = 0u64;

    for &spec in specs {
        if let Some(existing) = existing_chunks.get(&spec.index) {
            let expected_stored_size = spec
                .size
                .checked_add(per_chunk_overhead)
                .ok_or_else(|| CoreError::InvalidConfig("chunk size overflow".to_string()))?;
            let expected_i64 = i64::try_from(expected_stored_size).unwrap_or(i64::MAX);
            if existing.size != expected_i64 {
                return Err(CoreError::InvalidConfig(format!(
                    "cannot resume file {}: chunk {} size mismatch (recorded {}, planned {})",
                    file_id, spec.index, existing.size, expected_stored_size
                )));
            }
            debug!(
                file_id,
                chunk_index = spec.index,
                "Skipping already-uploaded chunk"
            );
            uploaded_bytes += spec.size;
        } else {
            pending.push(spec);
        }
    }

    Ok((pending, uploaded_bytes))
}

async fn retry_on_flood_wait<Op, Fut, R>(
    policy: RetryPolicy,
    task_id: i64,
    file_id: i64,
    notifier: Option<&mpsc::UnboundedSender<TransferNotice>>,
    mut op: Op,
) -> Result<R>
where
    Op: FnMut() -> Fut,
    Fut: Future<Output = Result<R>>,
{
    let mut attempt = 0u32;
    loop {
        match op().await {
            Ok(val) => return Ok(val),
            Err(err) => {
                let Some(wait_secs) = err.flood_wait_seconds() else {
                    return Err(err);
                };
                if attempt >= policy.max_retries || wait_secs > policy.max_flood_wait_secs {
                    return Err(err);
                }
                attempt += 1;
                warn!(
                    task_id,
                    file_id,
                    wait_secs,
                    attempt,
                    max_retries = policy.max_retries,
                    "Hit Telegram FLOOD_WAIT; sleeping before retry"
                );
                if let Some(tx) = notifier {
                    let _ = tx.send(TransferNotice::FloodWait {
                        task_id,
                        file_id,
                        seconds: wait_secs,
                        attempt,
                    });
                }
                tokio::time::sleep(Duration::from_secs(wait_secs)).await;
            }
        }
    }
}

fn validate_chunks(file: &FileRecord, chunks: &[FileChunk]) -> Result<u64> {
    let expected_plain_bytes = u64::try_from(file.size)
        .map_err(|_| CoreError::InvalidConfig(format!("file {} has negative size", file.id)))?;

    let mut actual_chunk_bytes = 0u64;
    for (idx, chunk) in chunks.iter().enumerate() {
        let expected_idx = i64::try_from(idx)
            .map_err(|_| CoreError::InvalidConfig("chunk count exceeds i64::MAX".to_string()))?;
        if chunk.chunk_index != expected_idx || chunk.size < 0 {
            return Err(CoreError::IncompleteChunks {
                file_id: file.id,
                expected_bytes: expected_plain_bytes,
                actual_bytes: actual_chunk_bytes,
            });
        }
        actual_chunk_bytes = actual_chunk_bytes
            .checked_add(chunk.size as u64)
            .ok_or_else(|| CoreError::InvalidConfig("total chunk size overflow".to_string()))?;
    }

    let expected_total_chunk_bytes = if file.is_encrypted && expected_plain_bytes > 0 {
        let overhead = (chunks.len() as u64)
            .checked_mul(ENCRYPTED_CHUNK_OVERHEAD)
            .ok_or_else(|| CoreError::InvalidConfig("encrypted overhead overflow".to_string()))?;
        expected_plain_bytes
            .checked_add(overhead)
            .ok_or_else(|| CoreError::InvalidConfig("encrypted chunk total overflow".to_string()))?
    } else {
        expected_plain_bytes
    };

    if actual_chunk_bytes != expected_total_chunk_bytes {
        return Err(CoreError::IncompleteChunks {
            file_id: file.id,
            expected_bytes: expected_total_chunk_bytes,
            actual_bytes: actual_chunk_bytes,
        });
    }

    Ok(expected_total_chunk_bytes)
}

async fn reassemble_and_verify(
    part_paths: &[PathBuf],
    expected_sha256: &str,
    assembling_path: &Path,
    decryption_password: Option<&str>,
) -> Result<()> {
    let mut out = tokio::fs::File::create(assembling_path).await?;
    let mut hasher = Sha256::new();

    if let Some(password) = decryption_password {
        for part_path in part_paths {
            let frame = tokio::fs::read(part_path).await?;
            let pw = password.to_string();
            let plaintext = tokio::task::spawn_blocking(move || crypto::decrypt_bytes(&frame, &pw))
                .await
                .map_err(|err| {
                    CoreError::Encryption(format!("decryption worker panicked: {err}"))
                })??;
            hasher.update(&plaintext);
            out.write_all(&plaintext).await?;
        }
    } else {
        let mut buf = vec![0u8; IO_BUFFER_SIZE];
        for part_path in part_paths {
            let mut part = tokio::fs::File::open(part_path).await?;
            loop {
                let n = part.read(&mut buf).await?;
                if n == 0 {
                    break;
                }
                hasher.update(&buf[..n]);
                out.write_all(&buf[..n]).await?;
            }
        }
    }

    out.flush().await?;
    drop(out);

    let actual_sha256 = hex::encode(hasher.finalize());
    if !actual_sha256.eq_ignore_ascii_case(expected_sha256) {
        return Err(CoreError::ChecksumMismatch {
            expected: expected_sha256.to_string(),
            actual: actual_sha256,
        });
    }

    Ok(())
}

async fn cleanup_part_files(part_paths: &[PathBuf]) {
    for path in part_paths {
        if let Err(err) = tokio::fs::remove_file(path).await {
            warn!(path = %path.display(), error = %err, "Failed to clean up staging part file");
        }
    }
}

fn staging_path(dest_path: &Path, suffix: &str) -> Result<PathBuf> {
    let file_name = dest_path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .ok_or_else(|| {
            CoreError::InvalidConfig(format!(
                "destination path '{}' does not have a valid file name",
                dest_path.display()
            ))
        })?;
    Ok(dest_path.with_file_name(format!(".{file_name}.teledrive_{suffix}")))
}

fn format_chunk_file_name(base_name: &str, index: u64, total_chunks: usize) -> String {
    if total_chunks <= 1 {
        base_name.to_string()
    } else {
        format!("{base_name}.part.{index:04}")
    }
}

fn fraction(done: u64, total: u64) -> f64 {
    if total == 0 {
        1.0
    } else {
        (done as f64 / total as f64).min(1.0)
    }
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicBool, AtomicI32, AtomicUsize, Ordering};
    use std::sync::Mutex;
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::*;

    struct TempDirGuard(PathBuf);

    impl TempDirGuard {
        fn new(label: &str) -> Self {
            let nanos = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let dir = std::env::temp_dir().join(format!(
                "teledrive_chunker_test_{label}_{}_{}",
                std::process::id(),
                nanos
            ));
            std::fs::create_dir_all(&dir).unwrap();
            Self(dir)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for TempDirGuard {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    struct MockTransport {
        blobs: Mutex<HashMap<i32, Vec<u8>>>,
        next_msg_id: AtomicI32,
        fail_upload_calls_left: AtomicUsize,
        fail_download_calls_left: AtomicUsize,
        upload_count: AtomicUsize,
        download_count: AtomicUsize,
        corrupt_first_download: AtomicBool,
    }

    impl MockTransport {
        fn new() -> Self {
            Self {
                blobs: Mutex::new(HashMap::new()),
                next_msg_id: AtomicI32::new(1),
                fail_upload_calls_left: AtomicUsize::new(0),
                fail_download_calls_left: AtomicUsize::new(0),
                upload_count: AtomicUsize::new(0),
                download_count: AtomicUsize::new(0),
                corrupt_first_download: AtomicBool::new(false),
            }
        }

        fn fail_after_uploads(&self, succeed_count: usize) {
            self.fail_upload_calls_left
                .store(succeed_count + 1, Ordering::SeqCst);
        }

        fn fail_after_downloads(&self, succeed_count: usize) {
            self.fail_download_calls_left
                .store(succeed_count + 1, Ordering::SeqCst);
        }
    }

    impl ChunkTransport for MockTransport {
        async fn upload_chunk(
            &self,
            path: &Path,
            offset: u64,
            size: u64,
            _file_name: String,
            _caption: String,
        ) -> Result<i32> {
            let fail_countdown = self.fail_upload_calls_left.load(Ordering::SeqCst);
            if fail_countdown > 0 {
                let prev = self.fail_upload_calls_left.fetch_sub(1, Ordering::SeqCst);
                if prev == 1 {
                    return Err(CoreError::Io(std::io::Error::new(
                        std::io::ErrorKind::ConnectionReset,
                        "simulated upload disconnect",
                    )));
                }
            }

            let mut file = tokio::fs::File::open(path).await?;
            file.seek(SeekFrom::Start(offset)).await?;
            let mut buf = vec![0u8; size as usize];
            file.read_exact(&mut buf).await?;

            let msg_id = self.next_msg_id.fetch_add(1, Ordering::SeqCst);
            self.blobs.lock().unwrap().insert(msg_id, buf);
            self.upload_count.fetch_add(1, Ordering::SeqCst);
            Ok(msg_id)
        }

        async fn upload_bytes(
            &self,
            data: Vec<u8>,
            _file_name: String,
            _caption: String,
        ) -> Result<i32> {
            let msg_id = self.next_msg_id.fetch_add(1, Ordering::SeqCst);
            self.blobs.lock().unwrap().insert(msg_id, data);
            self.upload_count.fetch_add(1, Ordering::SeqCst);
            Ok(msg_id)
        }

        async fn download_chunk(&self, message_id: i32, dest: &Path) -> Result<()> {
            let fail_countdown = self.fail_download_calls_left.load(Ordering::SeqCst);
            if fail_countdown > 0 {
                let prev = self.fail_download_calls_left.fetch_sub(1, Ordering::SeqCst);
                if prev == 1 {
                    return Err(CoreError::Io(std::io::Error::new(
                        std::io::ErrorKind::ConnectionAborted,
                        "simulated download disconnect",
                    )));
                }
            }

            let mut data = self
                .blobs
                .lock()
                .unwrap()
                .get(&message_id)
                .cloned()
                .ok_or(CoreError::MessageNotFound(message_id))?;

            if self.corrupt_first_download.swap(false, Ordering::SeqCst) && !data.is_empty() {
                data[0] ^= 0xff;
            }

            tokio::fs::write(dest, &data).await?;
            self.download_count.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }
    }

    #[test]
    fn plan_chunks_handles_exact_and_partial_boundaries() {
        assert!(matches!(
            plan_chunks(100, 0),
            Err(CoreError::InvalidConfig(_))
        ));
        assert!(plan_chunks(0, 1024).unwrap().is_empty());

        let exact = plan_chunks(2048, 1024).unwrap();
        assert_eq!(
            exact,
            vec![
                ChunkSpec {
                    index: 0,
                    offset: 0,
                    size: 1024
                },
                ChunkSpec {
                    index: 1,
                    offset: 1024,
                    size: 1024
                },
            ]
        );

        let partial = plan_chunks(2500, 1024).unwrap();
        assert_eq!(
            partial,
            vec![
                ChunkSpec {
                    index: 0,
                    offset: 0,
                    size: 1024
                },
                ChunkSpec {
                    index: 1,
                    offset: 1024,
                    size: 1024
                },
                ChunkSpec {
                    index: 2,
                    offset: 2048,
                    size: 452
                },
            ]
        );
    }

    #[tokio::test]
    async fn upload_and_download_resume_after_interruption() {
        let dir = TempDirGuard::new("resume");
        let src_path = dir.path().join("payload.bin");
        let dst_path = dir.path().join("restored.bin");

        let payload: Vec<u8> = (0..2500u32).map(|i| (i % 251) as u8).collect();
        std::fs::write(&src_path, &payload).unwrap();

        let db = Database::connect_in_memory().await.unwrap();
        let transport = MockTransport::new();
        // Use sequential chunks here so the deterministic disconnect after 1 chunk happens on chunk 1.
        let config = ChunkerConfig::new(1024)
            .unwrap()
            .with_concurrency(1)
            .unwrap();
        let engine = TransferEngine::new(&db, &transport, config);

        // Simulate upload disconnecting after chunk 0 succeeds (during chunk 1).
        transport.fail_after_uploads(1);
        assert!(engine.upload_file(&src_path, None).await.is_err());
        assert_eq!(transport.upload_count.load(Ordering::SeqCst), 1);

        // Resume upload: chunk 0 must NOT be uploaded again; only chunks 1 and 2 upload.
        let file = engine.upload_file(&src_path, None).await.unwrap();
        assert_eq!(transport.upload_count.load(Ordering::SeqCst), 3);
        assert_eq!(db.list_file_chunks(file.id).await.unwrap().len(), 3);

        // Simulate download disconnecting after chunk 0 succeeds (during chunk 1).
        transport.fail_after_downloads(1);
        assert!(engine.download_file(file.id, &dst_path).await.is_err());
        assert_eq!(transport.download_count.load(Ordering::SeqCst), 1);

        // Resume download: chunk 0 must NOT be downloaded again; only chunks 1 and 2 download.
        engine.download_file(file.id, &dst_path).await.unwrap();
        assert_eq!(transport.download_count.load(Ordering::SeqCst), 3);
        assert_eq!(std::fs::read(&dst_path).unwrap(), payload);

        // Staging `.teledrive_part` files should be cleaned up on success.
        let part0 = staging_path(&dst_path, &format!("part.{}.0", file.id)).unwrap();
        assert!(!part0.exists());
    }

    #[tokio::test]
    async fn download_detects_sha256_checksum_mismatch() {
        let dir = TempDirGuard::new("checksum");
        let src_path = dir.path().join("source.bin");
        let dst_path = dir.path().join("corrupt.bin");

        let payload = vec![42u8; 2048];
        std::fs::write(&src_path, &payload).unwrap();

        let db = Database::connect_in_memory().await.unwrap();
        let transport = MockTransport::new();
        let config = ChunkerConfig::new(1024)
            .unwrap()
            .with_concurrency(1)
            .unwrap();
        let engine = TransferEngine::new(&db, &transport, config);

        let file = engine.upload_file(&src_path, None).await.unwrap();
        transport
            .corrupt_first_download
            .store(true, Ordering::SeqCst);

        let err = engine.download_file(file.id, &dst_path).await.unwrap_err();
        assert!(matches!(err, CoreError::ChecksumMismatch { .. }));
        assert!(!dst_path.exists());
    }

    #[tokio::test]
    async fn encrypted_chunk_upload_and_download_roundtrip() {
        let dir = TempDirGuard::new("encrypted");
        let src_path = dir.path().join("secret.bin");
        let dst_path = dir.path().join("decrypted.bin");

        let payload: Vec<u8> = (0..2600u32).map(|i| (i % 241) as u8).collect();
        std::fs::write(&src_path, &payload).unwrap();

        let db = Database::connect_in_memory().await.unwrap();
        let transport = MockTransport::new();
        let config = ChunkerConfig::new(1024).unwrap();
        let upload_engine = TransferEngine::new(&db, &transport, config)
            .with_encryption_password(Some("vault-passphrase".to_string()));

        let file = upload_engine.upload_file(&src_path, None).await.unwrap();
        assert!(file.is_encrypted);
        assert_eq!(file.size, payload.len() as i64);

        // Stored chunks on Telegram must be larger by ENCRYPTED_CHUNK_OVERHEAD and not match plaintext.
        let chunks = db.list_file_chunks(file.id).await.unwrap();
        assert_eq!(chunks.len(), 3);
        let first_blob = transport
            .blobs
            .lock()
            .unwrap()
            .get(&chunks[0].telegram_message_id)
            .cloned()
            .unwrap();
        assert_eq!(first_blob.len(), 1024 + ENCRYPTED_CHUNK_OVERHEAD as usize);
        assert_ne!(&first_blob[36..], &payload[..1024]);

        // Missing password must fail before downloading.
        let no_pw_engine = TransferEngine::new(&db, &transport, config);
        assert!(matches!(
            no_pw_engine.download_file(file.id, &dst_path).await,
            Err(CoreError::Encryption(_))
        ));

        // Wrong password must fail decryption.
        let wrong_pw_engine = TransferEngine::new(&db, &transport, config)
            .with_encryption_password(Some("wrong-pass".to_string()));
        assert!(matches!(
            wrong_pw_engine.download_file(file.id, &dst_path).await,
            Err(CoreError::Encryption(_))
        ));
        assert!(!dst_path.exists());

        // Correct password reuses staged `.teledrive_part` files, decrypts, and passes SHA-256!
        let right_pw_engine = TransferEngine::new(&db, &transport, config)
            .with_encryption_password(Some("vault-passphrase".to_string()));
        right_pw_engine
            .download_file(file.id, &dst_path)
            .await
            .unwrap();
        assert_eq!(std::fs::read(&dst_path).unwrap(), payload);
    }
}

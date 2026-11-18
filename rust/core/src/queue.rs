use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use tokio::sync::{mpsc, watch, Semaphore};
use tokio::task::JoinSet;
use tracing::{error, info};

use crate::chunker::{ChunkTransport, ChunkerConfig, TransferEngine, TransferNotice};
use crate::db::Database;
use crate::error::{CoreError, Result};
use crate::models::TaskKind;

/// Default number of transfer jobs executed concurrently by [`TaskQueueManager`].
pub const DEFAULT_MAX_CONCURRENT_TASKS: usize = 2;

/// Job submitted to [`TaskQueueManager`].
#[derive(Debug, Clone)]
pub enum QueueRequest {
    Upload {
        source_path: PathBuf,
        folder_id: Option<i64>,
        encryption_password: Option<String>,
    },
    Download {
        file_id: i64,
        dest_path: PathBuf,
        encryption_password: Option<String>,
    },
}

impl QueueRequest {
    fn kind(&self) -> TaskKind {
        match self {
            Self::Upload { .. } => TaskKind::Upload,
            Self::Download { .. } => TaskKind::Download,
        }
    }

    fn label(&self) -> String {
        match self {
            Self::Upload { source_path, .. } => source_path
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| source_path.display().to_string()),
            Self::Download {
                file_id, dest_path, ..
            } => {
                let name = dest_path
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_else(|| dest_path.display().to_string());
                format!("file#{file_id} -> {name}")
            }
        }
    }
}

/// Real-time status events emitted by [`TaskQueueManager`].
#[derive(Debug, Clone, PartialEq)]
pub enum QueueEvent {
    TaskStarted {
        file_label: String,
        kind: TaskKind,
    },
    TaskProgress {
        task_id: i64,
        file_id: i64,
        kind: TaskKind,
        progress: f64,
    },
    TaskFloodWait {
        task_id: i64,
        file_id: i64,
        seconds: u64,
        attempt: u32,
    },
    TaskCompleted {
        task_id: i64,
        file_id: i64,
        kind: TaskKind,
    },
    TaskPaused {
        task_id: i64,
        file_id: i64,
        kind: TaskKind,
    },
    TaskFailed {
        file_label: String,
        kind: TaskKind,
        error: String,
    },
}

#[derive(Debug, Default)]
struct QueueControlInner {
    next_token: u64,
    paused_tasks: HashSet<i64>,
    active_pause_tx: HashMap<i64, (u64, watch::Sender<bool>)>,
    saved_requests: HashMap<i64, QueueRequest>,
}

/// Thread-safe coordinator enabling cooperative pause and resume of queued/active tasks.
#[derive(Debug, Clone, Default)]
pub struct QueueControl {
    inner: Arc<Mutex<QueueControlInner>>,
}

impl QueueControl {
    fn next_job_token(&self) -> u64 {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        guard.next_token = guard.next_token.wrapping_add(1);
        guard.next_token
    }

    fn register_task(
        &self,
        task_id: i64,
        job_token: u64,
        pause_tx: watch::Sender<bool>,
        req: QueueRequest,
    ) {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        guard.saved_requests.insert(task_id, req);
        guard
            .active_pause_tx
            .insert(task_id, (job_token, pause_tx.clone()));
        if guard.paused_tasks.contains(&task_id) {
            let _ = pause_tx.send(true);
        }
    }

    fn unregister_task(&self, task_id: i64, job_token: u64) {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        if guard
            .active_pause_tx
            .get(&task_id)
            .is_some_and(|(tok, _)| *tok == job_token)
        {
            guard.active_pause_tx.remove(&task_id);
        }
    }

    /// Requests that `task_id` pause cooperatively at the earliest safe boundary.
    pub fn pause_task(&self, task_id: i64) {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        guard.paused_tasks.insert(task_id);
        if let Some((_, tx)) = guard.active_pause_tx.get(&task_id) {
            let _ = tx.send(true);
        }
    }

    /// Clears the pause flag for `task_id` and returns the [`QueueRequest`] to re-enqueue.
    pub fn prepare_resume(
        &self,
        task_id: i64,
        encryption_password: Option<String>,
        fallback_file_id: i64,
        fallback_dest_path: Option<PathBuf>,
        is_download: bool,
    ) -> Option<QueueRequest> {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        guard.paused_tasks.remove(&task_id);
        if let Some(mut saved) = guard.saved_requests.get(&task_id).cloned() {
            match &mut saved {
                QueueRequest::Upload {
                    encryption_password: ref mut pw,
                    ..
                }
                | QueueRequest::Download {
                    encryption_password: ref mut pw,
                    ..
                } => *pw = encryption_password,
            }
            return Some(saved);
        }
        if is_download {
            return fallback_dest_path.map(|dest_path| QueueRequest::Download {
                file_id: fallback_file_id,
                dest_path,
                encryption_password,
            });
        }
        None
    }
}

/// Configuration for [`TaskQueueManager`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QueueConfig {
    pub max_concurrent_tasks: usize,
    pub chunker: ChunkerConfig,
}

impl Default for QueueConfig {
    fn default() -> Self {
        Self {
            max_concurrent_tasks: DEFAULT_MAX_CONCURRENT_TASKS,
            chunker: ChunkerConfig::default(),
        }
    }
}

impl QueueConfig {
    /// Creates a validated queue configuration.
    pub fn new(max_concurrent_tasks: usize, chunker: ChunkerConfig) -> Result<Self> {
        if max_concurrent_tasks == 0 {
            return Err(CoreError::InvalidConfig(
                "max_concurrent_tasks must be greater than zero".to_string(),
            ));
        }
        Ok(Self {
            max_concurrent_tasks,
            chunker,
        })
    }
}

/// Asynchronous queue manager executing concurrent upload/download jobs with `FloodWait` retries.
#[derive(Clone)]
pub struct TaskQueueManager<T: ChunkTransport + Clone + 'static> {
    db: Database,
    transport: T,
    config: QueueConfig,
}

impl<T: ChunkTransport + Clone + 'static> TaskQueueManager<T> {
    /// Creates a new queue manager backed by `db` and `transport`.
    pub fn new(db: Database, transport: T, config: QueueConfig) -> Self {
        Self {
            db,
            transport,
            config,
        }
    }

    /// Runs a finite batch of `requests` up to `max_concurrent_tasks` concurrently,
    /// returning per-request `Result<file_id>` in the same order as `requests`.
    pub async fn run_batch(
        &self,
        requests: Vec<QueueRequest>,
        event_tx: Option<mpsc::UnboundedSender<QueueEvent>>,
    ) -> Vec<Result<i64>> {
        let total = requests.len();
        if total == 0 {
            return Vec::new();
        }

        let semaphore = Arc::new(Semaphore::new(self.config.max_concurrent_tasks.max(1)));
        let mut join_set = JoinSet::new();

        for (idx, req) in requests.into_iter().enumerate() {
            let db = self.db.clone();
            let transport = self.transport.clone();
            let chunker = self.config.chunker;
            let permit_sem = Arc::clone(&semaphore);
            let tx = event_tx.clone();

            join_set.spawn(async move {
                let _permit = match permit_sem.acquire_owned().await {
                    Ok(permit) => permit,
                    Err(_) => {
                        return (
                            idx,
                            Err(CoreError::InvalidConfig(
                                "queue semaphore closed unexpectedly".to_string(),
                            )),
                        );
                    }
                };
                let outcome = execute_queue_request(
                    &db,
                    &transport,
                    chunker,
                    req,
                    tx.as_ref(),
                    None,
                )
                .await;
                (idx, outcome)
            });
        }

        let mut results: Vec<Option<Result<i64>>> = (0..total).map(|_| None).collect();
        while let Some(joined) = join_set.join_next().await {
            match joined {
                Ok((idx, outcome)) => {
                    if let Some(slot) = results.get_mut(idx) {
                        *slot = Some(outcome);
                    }
                }
                Err(join_err) => {
                    error!(error = %join_err, "Queue worker task terminated abnormally");
                }
            }
        }

        results
            .into_iter()
            .map(|entry| {
                entry.unwrap_or_else(|| {
                    Err(CoreError::InvalidConfig(
                        "queue worker task failed to produce a result".to_string(),
                    ))
                })
            })
            .collect()
    }

    /// Spawns a persistent background queue worker driven by `mpsc` channels for GUI integration.
    pub fn spawn_worker(
        self,
    ) -> (
        mpsc::UnboundedSender<QueueRequest>,
        mpsc::UnboundedReceiver<QueueEvent>,
    ) {
        let (req_tx, event_rx, _control) = self.spawn_controlled_worker();
        (req_tx, event_rx)
    }

    /// Spawns a persistent background queue worker along with a [`QueueControl`] handle for pause/resume.
    pub fn spawn_controlled_worker(
        self,
    ) -> (
        mpsc::UnboundedSender<QueueRequest>,
        mpsc::UnboundedReceiver<QueueEvent>,
        QueueControl,
    ) {
        let (req_tx, mut req_rx) = mpsc::unbounded_channel::<QueueRequest>();
        let (event_tx, event_rx) = mpsc::unbounded_channel::<QueueEvent>();
        let control = QueueControl::default();
        let worker_control = control.clone();

        tokio::spawn(async move {
            let semaphore = Arc::new(Semaphore::new(self.config.max_concurrent_tasks.max(1)));
            while let Some(req) = req_rx.recv().await {
                let Ok(permit) = Arc::clone(&semaphore).acquire_owned().await else {
                    break;
                };
                let db = self.db.clone();
                let transport = self.transport.clone();
                let chunker = self.config.chunker;
                let tx = event_tx.clone();
                let ctl = worker_control.clone();

                tokio::spawn(async move {
                    let _permit = permit;
                    let _ = execute_queue_request(&db, &transport, chunker, req, Some(&tx), Some(&ctl)).await;
                });
            }
        });

        (req_tx, event_rx, control)
    }
}

async fn execute_queue_request<T: ChunkTransport>(
    db: &Database,
    transport: &T,
    chunker: ChunkerConfig,
    req: QueueRequest,
    event_tx: Option<&mpsc::UnboundedSender<QueueEvent>>,
    control: Option<&QueueControl>,
) -> Result<i64> {
    let kind = req.kind();
    let label = req.label();
    emit_event(
        event_tx,
        QueueEvent::TaskStarted {
            file_label: label.clone(),
            kind,
        },
    );

    let (pause_tx, pause_rx) = watch::channel(false);
    let job_token = control.map_or(0, QueueControl::next_job_token);
    let bound_task = Arc::new(Mutex::new(None::<(i64, i64)>));

    let (notice_tx, mut notice_rx) = mpsc::unbounded_channel::<TransferNotice>();
    let bridge = {
        let out_tx = event_tx.cloned();
        let ctl = control.cloned();
        let req_clone = req.clone();
        let pause_tx_clone = pause_tx.clone();
        let bound_clone = Arc::clone(&bound_task);
        tokio::spawn(async move {
            while let Some(notice) = notice_rx.recv().await {
                let (task_id, file_id) = match &notice {
                    TransferNotice::Progress {
                        task_id, file_id, ..
                    }
                    | TransferNotice::FloodWait {
                        task_id, file_id, ..
                    } => (*task_id, *file_id),
                };
                {
                    let mut guard = bound_clone.lock().unwrap_or_else(|e| e.into_inner());
                    if guard.is_none() {
                        *guard = Some((task_id, file_id));
                        if let Some(ctl) = &ctl {
                            ctl.register_task(
                                task_id,
                                job_token,
                                pause_tx_clone.clone(),
                                req_clone.clone(),
                            );
                        }
                    }
                }
                if let Some(out_tx) = &out_tx {
                    let ev = match notice {
                        TransferNotice::Progress {
                            task_id,
                            file_id,
                            kind,
                            progress,
                        } => QueueEvent::TaskProgress {
                            task_id,
                            file_id,
                            kind,
                            progress,
                        },
                        TransferNotice::FloodWait {
                            task_id,
                            file_id,
                            seconds,
                            attempt,
                        } => QueueEvent::TaskFloodWait {
                            task_id,
                            file_id,
                            seconds,
                            attempt,
                        },
                    };
                    if out_tx.send(ev).is_err() {
                        break;
                    }
                }
            }
        })
    };

    let outcome = match req {
        QueueRequest::Upload {
            source_path,
            folder_id,
            encryption_password,
        } => TransferEngine::new(db, transport, chunker)
            .with_notifier(notice_tx)
            .with_encryption_password(encryption_password)
            .with_pause_signal(pause_rx)
            .upload_file(&source_path, folder_id)
            .await
            .map(|f| f.id),
        QueueRequest::Download {
            file_id,
            dest_path,
            encryption_password,
        } => TransferEngine::new(db, transport, chunker)
            .with_notifier(notice_tx)
            .with_encryption_password(encryption_password)
            .with_pause_signal(pause_rx)
            .download_file(file_id, &dest_path)
            .await
            .map(|()| file_id),
    };

    let _ = bridge.await;
    let bound = *bound_task.lock().unwrap_or_else(|e| e.into_inner());
    if let (Some(ctl), Some((task_id, _))) = (control, bound) {
        ctl.unregister_task(task_id, job_token);
    }

    match outcome {
        Ok(file_id) => {
            let task_id = db
                .find_latest_task_for_file(file_id, kind)
                .await?
                .map(|t| t.id)
                .unwrap_or(0);
            info!(
                task_id,
                file_id,
                kind = kind.as_str(),
                "Queued task completed"
            );
            emit_event(
                event_tx,
                QueueEvent::TaskCompleted {
                    task_id,
                    file_id,
                    kind,
                },
            );
            Ok(file_id)
        }
        Err(CoreError::TaskPaused) => {
            if let Some((task_id, file_id)) = bound {
                info!(task_id, file_id, kind = kind.as_str(), "Queued task paused");
                emit_event(
                    event_tx,
                    QueueEvent::TaskPaused {
                        task_id,
                        file_id,
                        kind,
                    },
                );
            }
            Err(CoreError::TaskPaused)
        }
        Err(err) => {
            error!(file_label = %label, kind = kind.as_str(), error = %err, "Queued task failed");
            emit_event(
                event_tx,
                QueueEvent::TaskFailed {
                    file_label: label,
                    kind,
                    error: err.to_string(),
                },
            );
            Err(err)
        }
    }
}

fn emit_event(event_tx: Option<&mpsc::UnboundedSender<QueueEvent>>, event: QueueEvent) {
    if let Some(tx) = event_tx {
        let _ = tx.send(event);
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::io::SeekFrom;
    use std::path::Path;
    use std::sync::atomic::{AtomicI32, AtomicUsize, Ordering};
    use std::sync::Mutex;
    use std::time::{Duration, SystemTime, UNIX_EPOCH};

    use tokio::io::{AsyncReadExt, AsyncSeekExt};

    use crate::chunker::RetryPolicy;
    use crate::models::TaskState;

    use super::*;

    struct TempDirGuard(PathBuf);

    impl TempDirGuard {
        fn new(label: &str) -> Self {
            let nanos = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let dir = std::env::temp_dir().join(format!(
                "teledrive_queue_test_{label}_{}_{}",
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

    #[derive(Clone)]
    struct FloodyMockTransport {
        blobs: Arc<Mutex<HashMap<i32, Vec<u8>>>>,
        next_msg_id: Arc<AtomicI32>,
        flood_waits_remaining: Arc<AtomicUsize>,
        active_uploads: Arc<AtomicUsize>,
        peak_concurrent_uploads: Arc<AtomicUsize>,
        upload_delay_ms: u64,
    }

    impl FloodyMockTransport {
        fn new(flood_waits: usize, upload_delay_ms: u64) -> Self {
            Self {
                blobs: Arc::new(Mutex::new(HashMap::new())),
                next_msg_id: Arc::new(AtomicI32::new(1)),
                flood_waits_remaining: Arc::new(AtomicUsize::new(flood_waits)),
                active_uploads: Arc::new(AtomicUsize::new(0)),
                peak_concurrent_uploads: Arc::new(AtomicUsize::new(0)),
                upload_delay_ms,
            }
        }
    }

    impl ChunkTransport for FloodyMockTransport {
        async fn upload_chunk(
            &self,
            path: &Path,
            offset: u64,
            size: u64,
            _file_name: String,
            _caption: String,
        ) -> Result<i32> {
            let current = self.active_uploads.fetch_add(1, Ordering::SeqCst) + 1;
            self.peak_concurrent_uploads
                .fetch_max(current, Ordering::SeqCst);

            let res = async {
                if self.upload_delay_ms > 0 {
                    tokio::time::sleep(std::time::Duration::from_millis(self.upload_delay_ms))
                        .await;
                }

                let prev = self.flood_waits_remaining.load(Ordering::SeqCst);
                if prev > 0
                    && self
                        .flood_waits_remaining
                        .compare_exchange(prev, prev - 1, Ordering::SeqCst, Ordering::SeqCst)
                        .is_ok()
                {
                    return Err(CoreError::FloodWait { seconds: 1 });
                }

                let mut file = tokio::fs::File::open(path).await?;
                file.seek(SeekFrom::Start(offset)).await?;
                let mut buf = vec![0u8; size as usize];
                file.read_exact(&mut buf).await?;

                let msg_id = self.next_msg_id.fetch_add(1, Ordering::SeqCst);
                self.blobs.lock().unwrap().insert(msg_id, buf);
                Ok(msg_id)
            }
            .await;

            self.active_uploads.fetch_sub(1, Ordering::SeqCst);
            res
        }

        async fn upload_bytes(
            &self,
            data: Vec<u8>,
            _file_name: String,
            _caption: String,
        ) -> Result<i32> {
            let msg_id = self.next_msg_id.fetch_add(1, Ordering::SeqCst);
            self.blobs.lock().unwrap().insert(msg_id, data);
            Ok(msg_id)
        }

        async fn download_chunk(&self, message_id: i32, dest: &Path) -> Result<()> {
            let data = self
                .blobs
                .lock()
                .unwrap()
                .get(&message_id)
                .cloned()
                .ok_or(CoreError::MessageNotFound(message_id))?;
            tokio::fs::write(dest, &data).await?;
            Ok(())
        }
    }

    #[tokio::test]
    async fn flood_wait_is_retried_automatically() {
        let dir = TempDirGuard::new("flood");
        let src_path = dir.path().join("flood_test.bin");
        let dst_path = dir.path().join("flood_restored.bin");

        let payload: Vec<u8> = (0..1800u32).map(|i| (i % 199) as u8).collect();
        std::fs::write(&src_path, &payload).unwrap();

        let db = Database::connect_in_memory().await.unwrap();
        let transport = FloodyMockTransport::new(1, 0);
        let chunker = ChunkerConfig::new(1024)
            .unwrap()
            .with_concurrency(2)
            .unwrap()
            .with_retry_policy(RetryPolicy {
                max_retries: 3,
                max_flood_wait_secs: 10,
            });
        let manager = TaskQueueManager::new(
            db.clone(),
            transport.clone(),
            QueueConfig::new(2, chunker).unwrap(),
        );

        let (tx, mut rx) = mpsc::unbounded_channel();
        let upload_res = manager
            .run_batch(
                vec![QueueRequest::Upload {
                    source_path: src_path,
                    folder_id: None,
                    encryption_password: None,
                }],
                Some(tx),
            )
            .await;

        assert_eq!(upload_res.len(), 1);
        let file_id = upload_res[0].as_ref().copied().unwrap();

        let mut events = Vec::new();
        while let Ok(ev) = rx.try_recv() {
            events.push(ev);
        }

        assert!(events.iter().any(|e| matches!(
            e,
            QueueEvent::TaskFloodWait {
                seconds: 1,
                attempt: 1,
                ..
            }
        )));
        assert!(events.iter().any(
            |e| matches!(e, QueueEvent::TaskCompleted { file_id: fid, .. } if *fid == file_id)
        ));

        let download_res = manager
            .run_batch(
                vec![QueueRequest::Download {
                    file_id,
                    dest_path: dst_path.clone(),
                    encryption_password: None,
                }],
                None,
            )
            .await;
        assert!(download_res[0].is_ok());
        assert_eq!(std::fs::read(&dst_path).unwrap(), payload);
    }

    #[tokio::test]
    async fn queue_manager_runs_uploads_and_chunks_in_parallel() {
        let dir = TempDirGuard::new("parallel");
        let mut requests = Vec::new();
        for idx in 0..3 {
            let p = dir.path().join(format!("item_{idx}.bin"));
            std::fs::write(&p, vec![idx as u8 + 1; 2500]).unwrap();
            requests.push(QueueRequest::Upload {
                source_path: p,
                folder_id: None,
                encryption_password: None,
            });
        }

        let db = Database::connect_in_memory().await.unwrap();
        let transport = FloodyMockTransport::new(0, 40);
        let chunker = ChunkerConfig::new(1024)
            .unwrap()
            .with_concurrency(2)
            .unwrap();
        let manager = TaskQueueManager::new(
            db.clone(),
            transport.clone(),
            QueueConfig::new(2, chunker).unwrap(),
        );

        let (tx, mut rx) = mpsc::unbounded_channel();
        let outcomes = manager.run_batch(requests, Some(tx)).await;
        assert_eq!(outcomes.len(), 3);
        for outcome in &outcomes {
            assert!(outcome.is_ok());
        }

        // With 2 concurrent tasks x 2 concurrent chunks and 40ms upload delay, peak concurrency > 1.
        assert!(transport.peak_concurrent_uploads.load(Ordering::SeqCst) > 1);

        let tasks = db.list_tasks().await.unwrap();
        assert_eq!(tasks.len(), 3);
        for task in tasks {
            assert_eq!(task.state_enum().unwrap(), TaskState::Completed);
            assert_eq!(task.progress, 1.0);
        }

        let mut completed_events = 0usize;
        while let Ok(ev) = rx.try_recv() {
            if matches!(ev, QueueEvent::TaskCompleted { .. }) {
                completed_events += 1;
            }
        }
        assert_eq!(completed_events, 3);
    }

    #[tokio::test]
    async fn pause_and_resume_preserves_progress_and_completes() {
        let dir = TempDirGuard::new("pause_resume");
        let src_path = dir.path().join("big.bin");
        let payload: Vec<u8> = (0..5000).map(|i| (i % 251) as u8).collect();
        std::fs::write(&src_path, &payload).unwrap();

        let db = Database::connect_in_memory().await.unwrap();
        let transport = FloodyMockTransport::new(0, 60);
        let chunker = ChunkerConfig::new(1024)
            .unwrap()
            .with_concurrency(1)
            .unwrap();
        let manager = TaskQueueManager::new(
            db.clone(),
            transport.clone(),
            QueueConfig::new(1, chunker).unwrap(),
        );

        let (req_tx, mut ev_rx, control) = manager.spawn_controlled_worker();
        req_tx
            .send(QueueRequest::Upload {
                source_path: src_path.clone(),
                folder_id: None,
                encryption_password: None,
            })
            .unwrap();

        // Wait for at least one chunk progress update so task_id is registered and partially uploaded.
        let mut paused_task_id = None;
        let deadline = tokio::time::Instant::now() + Duration::from_secs(5);
        while tokio::time::Instant::now() < deadline {
            if let Ok(Some(ev)) =
                tokio::time::timeout(Duration::from_secs(2), ev_rx.recv()).await
            {
                if let QueueEvent::TaskProgress {
                    task_id, progress, ..
                } = ev
                {
                    if progress > 0.0 && paused_task_id.is_none() {
                        paused_task_id = Some(task_id);
                        control.pause_task(task_id);
                    }
                } else if let QueueEvent::TaskPaused { task_id, .. } = ev {
                    paused_task_id = Some(task_id);
                    break;
                }
            }
        }

        let task_id = paused_task_id.expect("expected task to pause");
        let paused_task = db.get_task(task_id).await.unwrap();
        assert_eq!(paused_task.state_enum().unwrap(), TaskState::Paused);

        // Resume the paused task and wait for completion.
        let resumed_req = control
            .prepare_resume(task_id, None, paused_task.file_id, None, false)
            .expect("saved request available for resume");
        req_tx.send(resumed_req).unwrap();

        let mut completed = false;
        let resume_deadline = tokio::time::Instant::now() + Duration::from_secs(5);
        while tokio::time::Instant::now() < resume_deadline {
            if let Ok(Some(ev)) =
                tokio::time::timeout(Duration::from_secs(2), ev_rx.recv()).await
            {
                if matches!(ev, QueueEvent::TaskCompleted { task_id: tid, .. } if tid == task_id) {
                    completed = true;
                    break;
                }
            }
        }
        assert!(completed, "resumed task did not complete");

        let finished = db.get_task(task_id).await.unwrap();
        assert_eq!(finished.state_enum().unwrap(), TaskState::Completed);
        assert_eq!(finished.progress, 1.0);
    }
}

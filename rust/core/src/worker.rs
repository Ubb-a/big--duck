use std::collections::HashSet;
use std::path::{Path, PathBuf};

use grammers_client::types::{LoginToken, PasswordToken};
use tokio::sync::mpsc;
use tracing::{error, info, warn};

use crate::backup::{restore_backup_from_telegram, upload_backup_to_telegram};
use crate::chunker::{ChunkerConfig, DEFAULT_CHUNK_SIZE};
use crate::db::Database;
use crate::error::{CoreError, Result};
use crate::keyring_store::{account_key_from_path, delete_session_from_keyring};
use crate::models::{FileRecord, Folder, TaskKind, TaskRecord, TaskState};
use crate::queue::{
    QueueConfig, QueueControl, QueueEvent, QueueRequest, TaskQueueManager,
    DEFAULT_MAX_CONCURRENT_TASKS,
};
use crate::telegram::{StorageChat, TelegramClient, TelegramConfig};

/// Telegram authentication state exposed to the UI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthStatus {
    Disconnected,
    Connecting,
    AwaitingPhone,
    AwaitingCode {
        phone: String,
    },
    AwaitingPassword {
        hint: Option<String>,
    },
    Authorized {
        user_id: i64,
        full_name: String,
        username: Option<String>,
    },
}

/// Snapshot of the current virtual directory and background transfer tasks.
#[derive(Debug, Clone, PartialEq)]
pub struct DirectorySnapshot {
    pub current_folder: Option<Folder>,
    pub breadcrumbs: Vec<Folder>,
    pub all_folders: Vec<Folder>,
    pub all_files: Vec<FileRecord>,
    pub folders: Vec<Folder>,
    pub files: Vec<FileRecord>,
    pub tasks: Vec<TaskRecord>,
}

/// Commands sent from the GUI thread to the background core worker thread.
#[derive(Debug, Clone)]
pub enum CoreCommand {
    Connect {
        api_id: i32,
        api_hash: String,
        session_path: PathBuf,
    },
    SubmitPhone {
        phone: String,
    },
    SubmitCode {
        code: String,
    },
    SubmitPassword {
        password: String,
    },
    OpenFolder {
        folder_id: Option<i64>,
    },
    Refresh,
    CreateFolder {
        parent_id: Option<i64>,
        name: String,
    },
    RenameFolder {
        id: i64,
        new_name: String,
    },
    MoveFolder {
        id: i64,
        new_parent_id: Option<i64>,
    },
    DeleteFolder {
        id: i64,
    },
    RenameFile {
        id: i64,
        new_name: String,
    },
    MoveFile {
        id: i64,
        new_folder_id: Option<i64>,
    },
    DeleteFile {
        id: i64,
    },
    UploadFiles {
        paths: Vec<PathBuf>,
        folder_id: Option<i64>,
    },
    DownloadFile {
        file_id: i64,
        dest_path: PathBuf,
    },
    PauseTask {
        task_id: i64,
    },
    ResumeTask {
        task_id: i64,
        dest_path: Option<PathBuf>,
    },
    SetChunkSize {
        chunk_size: u64,
    },
    SetEncryptionPassword {
        password: Option<String>,
    },
    BackupIndex {
        password: String,
    },
    RestoreIndex {
        password: String,
        message_id: Option<i32>,
    },
    ListChats,
    SetTargetChat {
        chat_id: Option<i64>,
    },
    CreateStorageChat {
        title: String,
        kind: String,
    },
    ResetAuthStep,
    Logout,
    Shutdown,
}

/// Events pushed from the background core worker thread to the GUI thread.
#[derive(Debug, Clone, PartialEq)]
pub enum CoreEvent {
    AuthChanged(AuthStatus),
    Snapshot(DirectorySnapshot),
    Queue(QueueEvent),
    ChatsListed(Vec<StorageChat>),
    StorageChatCreated(StorageChat),
    TargetChatChanged(Option<i64>),
    Info(String),
    Error(String),
}

/// Bidirectional `mpsc` channel handle connecting the UI thread to the core worker thread.
pub struct CoreWorkerHandle {
    pub cmd_tx: mpsc::UnboundedSender<CoreCommand>,
    pub event_rx: mpsc::UnboundedReceiver<CoreEvent>,
}

impl CoreWorkerHandle {
    /// Sends a command to the background core worker thread.
    pub fn send(&self, cmd: CoreCommand) -> Result<()> {
        self.cmd_tx.send(cmd).map_err(|_| {
            CoreError::InvalidConfig("core worker thread is no longer running".to_string())
        })
    }

    /// Polls for the next pending event without blocking the UI thread.
    pub fn try_recv(&mut self) -> Option<CoreEvent> {
        self.event_rx.try_recv().ok()
    }
}

/// Spawns `teledrive-core` inside a dedicated OS thread with its own Tokio runtime,
/// communicating exclusively via `tokio::sync::mpsc` channels.
pub fn spawn_core_worker(db_path: PathBuf, initial_tg: Option<TelegramConfig>) -> CoreWorkerHandle {
    let (cmd_tx, cmd_rx) = mpsc::unbounded_channel();
    let (event_tx, event_rx) = mpsc::unbounded_channel();

    let spawn_res = std::thread::Builder::new()
        .name("teledrive-core".to_string())
        .spawn(move || {
            let runtime = match tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
            {
                Ok(rt) => rt,
                Err(err) => {
                    let _ = event_tx.send(CoreEvent::Error(format!(
                        "Failed to start Tokio runtime: {err}"
                    )));
                    return;
                }
            };

            runtime.block_on(run_worker_loop(db_path, initial_tg, cmd_rx, event_tx));
        });

    if let Err(err) = spawn_res {
        error!(error = %err, "Failed to spawn core worker thread");
    }

    CoreWorkerHandle { cmd_tx, event_rx }
}

struct WorkerState {
    db: Database,
    client: Option<TelegramClient>,
    last_session_path: Option<PathBuf>,
    is_authorized: bool,
    pending_login: Option<(String, LoginToken)>,
    pending_password: Option<PasswordToken>,
    current_folder_id: Option<i64>,
    chunk_size: u64,
    encryption_password: Option<String>,
    queue_tx: Option<mpsc::UnboundedSender<QueueRequest>>,
    queue_control: Option<QueueControl>,
    event_tx: mpsc::UnboundedSender<CoreEvent>,
    refresh_tx: mpsc::UnboundedSender<()>,
}

async fn run_worker_loop(
    db_path: PathBuf,
    initial_tg: Option<TelegramConfig>,
    mut cmd_rx: mpsc::UnboundedReceiver<CoreCommand>,
    event_tx: mpsc::UnboundedSender<CoreEvent>,
) {
    let db = match open_worker_db(&db_path).await {
        Ok(db) => db,
        Err(err) => {
            let _ = event_tx.send(CoreEvent::Error(format!(
                "Failed to initialize SQLite database '{}': {err}",
                db_path.display()
            )));
            return;
        }
    };

    let (refresh_tx, mut refresh_rx) = mpsc::unbounded_channel::<()>();
    let mut state = WorkerState {
        db,
        client: None,
        last_session_path: None,
        is_authorized: false,
        pending_login: None,
        pending_password: None,
        current_folder_id: None,
        chunk_size: DEFAULT_CHUNK_SIZE,
        encryption_password: None,
        queue_tx: None,
        queue_control: None,
        event_tx,
        refresh_tx,
    };

    state.emit_snapshot().await;
    state.emit_auth(AuthStatus::Disconnected);

    if let Some(tg_cfg) = initial_tg {
        state.connect_telegram(tg_cfg).await;
    }

    loop {
        tokio::select! {
            maybe_cmd = cmd_rx.recv() => {
                let Some(cmd) = maybe_cmd else {
                    break;
                };
                if matches!(cmd, CoreCommand::Shutdown) {
                    info!("Core worker received shutdown command");
                    break;
                }
                state.handle_command(cmd).await;
            }
            maybe_refresh = refresh_rx.recv() => {
                if maybe_refresh.is_some() {
                    state.emit_snapshot().await;
                }
            }
        }
    }
}

async fn open_worker_db(db_path: &Path) -> Result<Database> {
    if db_path == Path::new(":memory:") {
        Database::connect_in_memory().await
    } else {
        Database::connect(db_path).await
    }
}

impl WorkerState {
    fn emit(&self, event: CoreEvent) {
        let _ = self.event_tx.send(event);
    }

    fn emit_auth(&self, status: AuthStatus) {
        self.emit(CoreEvent::AuthChanged(status));
    }

    fn emit_info(&self, msg: impl Into<String>) {
        self.emit(CoreEvent::Info(msg.into()));
    }

    fn emit_error(&self, msg: impl Into<String>) {
        self.emit(CoreEvent::Error(msg.into()));
    }

    async fn emit_snapshot(&mut self) {
        match self.build_snapshot().await {
            Ok(snapshot) => self.emit(CoreEvent::Snapshot(snapshot)),
            Err(err) => self.emit_error(format!("Failed to load directory snapshot: {err}")),
        }
    }

    async fn build_snapshot(&mut self) -> Result<DirectorySnapshot> {
        let current_folder = match self.current_folder_id {
            Some(id) => match self.db.get_folder(id).await {
                Ok(folder) => Some(folder),
                Err(CoreError::NotFound(_)) => {
                    self.current_folder_id = None;
                    None
                }
                Err(err) => return Err(err),
            },
            None => None,
        };

        let breadcrumbs = self.collect_breadcrumbs(current_folder.as_ref()).await?;
        let all_folders = self.db.list_all_folders().await?;
        let all_files = self.db.list_all_files().await?;
        let folders = self.db.list_folders(self.current_folder_id).await?;
        let files = self.db.list_files(self.current_folder_id).await?;
        let tasks = self.db.list_tasks().await?;

        Ok(DirectorySnapshot {
            current_folder,
            breadcrumbs,
            all_folders,
            all_files,
            folders,
            files,
            tasks,
        })
    }

    async fn collect_breadcrumbs(&self, current: Option<&Folder>) -> Result<Vec<Folder>> {
        let mut chain = Vec::new();
        let mut seen = HashSet::new();
        let mut cursor = current.cloned();

        while let Some(folder) = cursor {
            if !seen.insert(folder.id) {
                break;
            }
            let parent_id = folder.parent_id;
            chain.push(folder);
            cursor = match parent_id {
                Some(pid) => self.db.get_folder(pid).await.ok(),
                None => None,
            };
        }

        chain.reverse();
        Ok(chain)
    }

    async fn handle_command(&mut self, cmd: CoreCommand) {
        match cmd {
            CoreCommand::Connect {
                api_id,
                api_hash,
                session_path,
            } => {
                self.connect_telegram(TelegramConfig {
                    api_id,
                    api_hash,
                    session_path,
                })
                .await;
            }
            CoreCommand::SubmitPhone { phone } => self.submit_phone(phone).await,
            CoreCommand::SubmitCode { code } => self.submit_code(code).await,
            CoreCommand::SubmitPassword { password } => self.submit_password(password).await,
            CoreCommand::OpenFolder { folder_id } => {
                self.current_folder_id = folder_id;
                self.emit_snapshot().await;
            }
            CoreCommand::Refresh => {
                self.emit_snapshot().await;
            }
            CoreCommand::CreateFolder { parent_id, name } => {
                match self.db.create_folder(parent_id, &name).await {
                    Ok(folder) => {
                        self.emit_info(format!("Created folder '{}'", folder.name));
                        self.emit_snapshot().await;
                    }
                    Err(err) => self.emit_error(err.to_string()),
                }
            }
            CoreCommand::RenameFolder { id, new_name } => {
                match self.db.rename_folder(id, &new_name).await {
                    Ok(folder) => {
                        self.emit_info(format!("Renamed folder to '{}'", folder.name));
                        self.emit_snapshot().await;
                    }
                    Err(err) => self.emit_error(err.to_string()),
                }
            }
            CoreCommand::MoveFolder { id, new_parent_id } => {
                match self.db.move_folder(id, new_parent_id).await {
                    Ok(folder) => {
                        self.emit_info(format!("Moved folder '{}'", folder.name));
                        self.emit_snapshot().await;
                    }
                    Err(err) => self.emit_error(err.to_string()),
                }
            }
            CoreCommand::DeleteFolder { id } => match self.db.delete_folder(id).await {
                Ok(()) => {
                    self.emit_info("Folder deleted");
                    self.emit_snapshot().await;
                }
                Err(err) => self.emit_error(err.to_string()),
            },
            CoreCommand::RenameFile { id, new_name } => {
                match self.db.rename_file(id, &new_name).await {
                    Ok(file) => {
                        self.emit_info(format!("Renamed file to '{}'", file.name));
                        self.emit_snapshot().await;
                    }
                    Err(err) => self.emit_error(err.to_string()),
                }
            }
            CoreCommand::MoveFile { id, new_folder_id } => {
                match self.db.move_file(id, new_folder_id).await {
                    Ok(file) => {
                        self.emit_info(format!("Moved file '{}'", file.name));
                        self.emit_snapshot().await;
                    }
                    Err(err) => self.emit_error(err.to_string()),
                }
            }
            CoreCommand::DeleteFile { id } => match self.db.delete_file(id).await {
                Ok(()) => {
                    self.emit_info("File removed from local index");
                    self.emit_snapshot().await;
                }
                Err(err) => self.emit_error(err.to_string()),
            },
            CoreCommand::UploadFiles { paths, folder_id } => {
                self.enqueue_uploads(paths, folder_id);
            }
            CoreCommand::DownloadFile { file_id, dest_path } => {
                self.enqueue_download(file_id, dest_path);
            }
            CoreCommand::PauseTask { task_id } => {
                self.pause_task(task_id).await;
            }
            CoreCommand::ResumeTask { task_id, dest_path } => {
                self.resume_task(task_id, dest_path).await;
            }
            CoreCommand::SetChunkSize { chunk_size } => {
                if let Err(err) = ChunkerConfig::new(chunk_size) {
                    self.emit_error(err.to_string());
                    return;
                }
                self.chunk_size = chunk_size;
                if self.is_authorized {
                    self.restart_queue_worker();
                }
                self.emit_info(format!("Chunk size set to {} bytes", self.chunk_size));
            }
            CoreCommand::SetEncryptionPassword { password } => {
                self.encryption_password = password.filter(|p| !p.is_empty());
                if self.encryption_password.is_some() {
                    self.emit_info("AES-256-GCM encryption key enabled for transfers");
                } else {
                    self.emit_info("Encryption key cleared (unencrypted mode)");
                }
            }
            CoreCommand::BackupIndex { password } => {
                self.handle_backup_index(password).await;
            }
            CoreCommand::RestoreIndex {
                password,
                message_id,
            } => {
                self.handle_restore_index(password, message_id).await;
            }
            CoreCommand::ListChats => {
                let Some(client) = &self.client else {
                    self.emit_error("Connect to Telegram first".to_string());
                    return;
                };
                match client.list_storage_chats().await {
                    Ok(chats) => {
                        let _ = self.event_tx.send(CoreEvent::ChatsListed(chats));
                    }
                    Err(err) => self.emit_error(format!("Failed to list Telegram chats: {err}")),
                }
            }
            CoreCommand::SetTargetChat { chat_id } => {
                if let Some(client) = &self.client {
                    client.set_target_chat_id(chat_id);
                    let _ = self.event_tx.send(CoreEvent::TargetChatChanged(chat_id));
                    match chat_id {
                        Some(id) => self.emit_info(format!(
                            "Storage destination switched to Group/Channel #{id}"
                        )),
                        None => self.emit_info(
                            "Storage destination switched to Saved Messages".to_string(),
                        ),
                    }
                } else {
                    self.emit_error("Connect to Telegram first".to_string());
                }
            }
            CoreCommand::CreateStorageChat { title, kind } => {
                let Some(client) = &self.client else {
                    self.emit_error("Connect to Telegram first".to_string());
                    return;
                };
                match client.create_storage_chat(&title, kind != "channel").await {
                    Ok(created) => {
                        client.set_target_chat_id(Some(created.id));
                        let _ = self
                            .event_tx
                            .send(CoreEvent::StorageChatCreated(created.clone()));
                        let _ = self
                            .event_tx
                            .send(CoreEvent::TargetChatChanged(Some(created.id)));
                    }
                    Err(err) => {
                        self.emit_error(format!("Failed to create Telegram vault: {err}"));
                    }
                }
            }
            CoreCommand::ResetAuthStep => {
                self.pending_login = None;
                self.pending_password = None;
                if self.is_authorized {
                    return;
                }
                if self.client.is_some() {
                    self.emit_auth(AuthStatus::AwaitingPhone);
                } else {
                    self.emit_auth(AuthStatus::Disconnected);
                }
            }
            CoreCommand::Logout => {
                if let Some(client) = self.client.take() {
                    client.delete_stored_session();
                } else if let Some(path) = &self.last_session_path {
                    let key = account_key_from_path(path);
                    let _ = delete_session_from_keyring(&key);
                    let _ = std::fs::remove_file(path);
                }
                self.is_authorized = false;
                self.pending_login = None;
                self.pending_password = None;
                self.queue_tx = None;
                self.queue_control = None;
                self.emit_auth(AuthStatus::Disconnected);
                self.emit_info("Signed out of Telegram");
            }
            CoreCommand::Shutdown => {}
        }
    }

    async fn connect_telegram(&mut self, config: TelegramConfig) {
        self.last_session_path = Some(config.session_path.clone());
        self.emit_auth(AuthStatus::Connecting);
        self.client = None;
        self.is_authorized = false;
        self.pending_login = None;
        self.pending_password = None;
        self.queue_tx = None;
        self.queue_control = None;

        let client = match TelegramClient::connect(config).await {
            Ok(client) => client,
            Err(err) => {
                self.emit_auth(AuthStatus::Disconnected);
                self.emit_error(format!("Telegram connection failed: {err}"));
                return;
            }
        };

        match client.is_authorized().await {
            Ok(true) => match client.get_me().await {
                Ok(me) => {
                    let status = AuthStatus::Authorized {
                        user_id: me.id(),
                        full_name: me.full_name(),
                        username: me.username().map(str::to_string),
                    };
                    self.client = Some(client);
                    self.is_authorized = true;
                    self.restart_queue_worker();
                    self.emit_auth(status);
                    self.emit_info("Connected and authorized with Telegram");
                }
                Err(err) => {
                    self.emit_auth(AuthStatus::Disconnected);
                    self.emit_error(format!("Failed to load Telegram user info: {err}"));
                }
            },
            Ok(false) => {
                self.client = Some(client);
                self.emit_auth(AuthStatus::AwaitingPhone);
                self.emit_info("Connected to Telegram. Enter your phone number to log in.");
            }
            Err(err) => {
                self.emit_auth(AuthStatus::Disconnected);
                self.emit_error(format!("Failed to check authorization state: {err}"));
            }
        }
    }

    async fn submit_phone(&mut self, phone: String) {
        let Some(client) = &self.client else {
            self.emit_error("Connect to Telegram first".to_string());
            return;
        };

        match client.request_login_code(&phone).await {
            Ok(token) => {
                let trimmed = phone.trim().to_string();
                self.pending_login = Some((trimmed.clone(), token));
                self.emit_auth(AuthStatus::AwaitingCode { phone: trimmed });
                self.emit_info("Verification code requested from Telegram");
            }
            Err(err) => self.emit_error(format!("Failed to request login code: {err}")),
        }
    }

    async fn submit_code(&mut self, code: String) {
        let Some(client) = self.client.clone() else {
            self.emit_error("Connect to Telegram first".to_string());
            return;
        };
        let Some((phone, token)) = self.pending_login.take() else {
            self.emit_error("No pending login code request".to_string());
            return;
        };

        match client.sign_in(&token, &code).await {
            Ok(user) => {
                self.is_authorized = true;
                self.restart_queue_worker();
                self.emit_auth(AuthStatus::Authorized {
                    user_id: user.id(),
                    full_name: user.full_name(),
                    username: user.username().map(str::to_string),
                });
                self.emit_info("Signed in to Telegram");
            }
            Err(CoreError::PasswordRequired(pw_token)) => {
                let hint = pw_token
                    .hint()
                    .filter(|h| !h.is_empty())
                    .map(str::to_string);
                self.pending_password = Some(*pw_token);
                self.emit_auth(AuthStatus::AwaitingPassword { hint });
                self.emit_info("Two-factor authentication password required");
            }
            Err(err) => {
                self.pending_login = Some((phone, token));
                self.emit_error(format!("Sign-in failed: {err}"));
            }
        }
    }

    async fn submit_password(&mut self, password: String) {
        let Some(client) = self.client.clone() else {
            self.emit_error("Connect to Telegram first".to_string());
            return;
        };
        let Some(pw_token) = self.pending_password.take() else {
            self.emit_error("No pending 2FA password prompt".to_string());
            return;
        };

        match client.check_password(pw_token.clone(), &password).await {
            Ok(user) => {
                self.is_authorized = true;
                self.restart_queue_worker();
                self.emit_auth(AuthStatus::Authorized {
                    user_id: user.id(),
                    full_name: user.full_name(),
                    username: user.username().map(str::to_string),
                });
                self.emit_info("2FA verified and signed in to Telegram");
            }
            Err(err) => {
                self.pending_password = Some(pw_token);
                self.emit_error(format!("2FA verification failed: {err}"));
            }
        }
    }

    fn restart_queue_worker(&mut self) {
        let Some(client) = self.client.clone() else {
            return;
        };
        let chunker = match ChunkerConfig::new(self.chunk_size) {
            Ok(cfg) => cfg,
            Err(err) => {
                warn!(error = %err, "Invalid chunk_size, falling back to default");
                ChunkerConfig::default()
            }
        };
        let queue_cfg = QueueConfig {
            max_concurrent_tasks: DEFAULT_MAX_CONCURRENT_TASKS,
            chunker,
        };
        let manager = TaskQueueManager::new(self.db.clone(), client, queue_cfg);
        let (req_tx, mut queue_rx, control) = manager.spawn_controlled_worker();
        self.queue_tx = Some(req_tx);
        self.queue_control = Some(control);

        let event_tx = self.event_tx.clone();
        let refresh_tx = self.refresh_tx.clone();
        tokio::spawn(async move {
            while let Some(ev) = queue_rx.recv().await {
                let should_refresh = matches!(
                    ev,
                    QueueEvent::TaskStarted { .. }
                        | QueueEvent::TaskCompleted { .. }
                        | QueueEvent::TaskPaused { .. }
                        | QueueEvent::TaskFailed { .. }
                );
                if event_tx.send(CoreEvent::Queue(ev)).is_err() {
                    break;
                }
                if should_refresh {
                    let _ = refresh_tx.send(());
                }
            }
        });
    }

    fn enqueue_uploads(&self, paths: Vec<PathBuf>, folder_id: Option<i64>) {
        if paths.is_empty() {
            return;
        }
        let Some(queue_tx) = &self.queue_tx else {
            self.emit_error("Log in to Telegram before uploading files".to_string());
            return;
        };
        let count = paths.len();
        for source_path in paths {
            if let Err(err) = queue_tx.send(QueueRequest::Upload {
                source_path,
                folder_id,
                encryption_password: self.encryption_password.clone(),
            }) {
                self.emit_error(format!("Failed to queue upload: {err}"));
                return;
            }
        }
        self.emit_info(format!("Queued {count} file(s) for upload"));
    }

    fn enqueue_download(&self, file_id: i64, dest_path: PathBuf) {
        let Some(queue_tx) = &self.queue_tx else {
            self.emit_error("Log in to Telegram before downloading files".to_string());
            return;
        };
        if let Err(err) = queue_tx.send(QueueRequest::Download {
            file_id,
            dest_path,
            encryption_password: self.encryption_password.clone(),
        }) {
            self.emit_error(format!("Failed to queue download: {err}"));
            return;
        }
        self.emit_info(format!("Queued download for file #{file_id}"));
    }

    async fn pause_task(&mut self, task_id: i64) {
        let task = match self.db.get_task(task_id).await {
            Ok(t) => t,
            Err(err) => {
                self.emit_error(err.to_string());
                return;
            }
        };
        if let Some(ctl) = &self.queue_control {
            ctl.pause_task(task_id);
        }
        if matches!(
            task.state_enum(),
            Ok(TaskState::Queued | TaskState::Running)
        ) {
            let _ = self
                .db
                .update_task_progress(task_id, TaskState::Paused, task.progress, None)
                .await;
            if let Ok(kind) = task.kind_enum() {
                self.emit(CoreEvent::Queue(QueueEvent::TaskPaused {
                    task_id,
                    file_id: task.file_id,
                    kind,
                }));
            }
            self.emit_snapshot().await;
        }
    }

    async fn resume_task(&mut self, task_id: i64, dest_path: Option<PathBuf>) {
        let (Some(queue_tx), Some(control)) =
            (self.queue_tx.clone(), self.queue_control.clone())
        else {
            self.emit_error("Log in to Telegram before resuming transfers".to_string());
            return;
        };
        let task = match self.db.get_task(task_id).await {
            Ok(t) => t,
            Err(err) => {
                self.emit_error(err.to_string());
                return;
            }
        };
        let is_download = matches!(task.kind_enum(), Ok(TaskKind::Download));
        let Some(req) = control.prepare_resume(
            task_id,
            self.encryption_password.clone(),
            task.file_id,
            dest_path,
            is_download,
        ) else {
            self.emit_error(
                "Original source file path is unavailable after restart; re-select the file to resume"
                    .to_string(),
            );
            return;
        };
        if let Err(err) = self
            .db
            .update_task_progress(task_id, TaskState::Queued, task.progress, None)
            .await
        {
            self.emit_error(err.to_string());
            return;
        }
        self.emit_snapshot().await;
        if let Err(err) = queue_tx.send(req) {
            self.emit_error(format!("Failed to resume transfer: {err}"));
        } else {
            self.emit_info("Resuming transfer");
        }
    }

    async fn handle_backup_index(&self, password: String) {
        if !self.is_authorized {
            self.emit_error("Log in to Telegram before backing up the index".to_string());
            return;
        }
        let Some(client) = self.client.as_ref() else {
            self.emit_error("Telegram client is not connected".to_string());
            return;
        };

        match upload_backup_to_telegram(&self.db, client, &password).await {
            Ok(msg_id) => {
                self.emit_info(format!(
                    "Encrypted index backup uploaded to Saved Messages (message_id={msg_id})"
                ));
            }
            Err(err) => self.emit_error(format!("Backup failed: {err}")),
        }
    }

    async fn handle_restore_index(&mut self, password: String, message_id: Option<i32>) {
        if !self.is_authorized {
            self.emit_error("Log in to Telegram before restoring the index".to_string());
            return;
        }
        let Some(client) = self.client.as_ref() else {
            self.emit_error("Telegram client is not connected".to_string());
            return;
        };

        let target_msg_id = match message_id {
            Some(id) => id,
            None => match client.find_latest_backup_message_id().await {
                Ok(Some(id)) => id,
                Ok(None) => {
                    self.emit_error(
                        "No TeleDrive index backup message found in Saved Messages".to_string(),
                    );
                    return;
                }
                Err(err) => {
                    self.emit_error(format!("Failed to search for backup message: {err}"));
                    return;
                }
            },
        };

        match restore_backup_from_telegram(&self.db, client, target_msg_id, &password).await {
            Ok(payload) => {
                self.current_folder_id = None;
                self.emit_info(format!(
                    "Restored {} folder(s) and {} file(s) from backup message_id={target_msg_id}",
                    payload.folders.len(),
                    payload.files.len()
                ));
                self.emit_snapshot().await;
            }
            Err(err) => self.emit_error(format!("Restore failed: {err}")),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;

    async fn recv_snapshot(rx: &mut mpsc::UnboundedReceiver<CoreEvent>) -> DirectorySnapshot {
        let deadline = tokio::time::Instant::now() + Duration::from_secs(3);
        loop {
            let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
            let event = tokio::time::timeout(remaining, rx.recv())
                .await
                .expect("timed out waiting for worker event")
                .expect("worker event channel closed");
            match event {
                CoreEvent::Snapshot(snapshot) => return snapshot,
                CoreEvent::Error(err) => panic!("unexpected core worker error: {err}"),
                _ => {}
            }
        }
    }

    #[tokio::test]
    async fn worker_handles_folder_crud_and_snapshots_over_channels() {
        let mut handle = spawn_core_worker(PathBuf::from(":memory:"), None);

        let initial = recv_snapshot(&mut handle.event_rx).await;
        assert!(initial.folders.is_empty());
        assert!(initial.current_folder.is_none());

        handle
            .send(CoreCommand::CreateFolder {
                parent_id: None,
                name: "Projects".to_string(),
            })
            .unwrap();
        let after_create = recv_snapshot(&mut handle.event_rx).await;
        assert_eq!(after_create.folders.len(), 1);
        let folder_id = after_create.folders[0].id;

        handle
            .send(CoreCommand::OpenFolder {
                folder_id: Some(folder_id),
            })
            .unwrap();
        let inside = recv_snapshot(&mut handle.event_rx).await;
        assert_eq!(inside.current_folder.as_ref().unwrap().id, folder_id);
        assert_eq!(inside.breadcrumbs.len(), 1);

        handle
            .send(CoreCommand::RenameFolder {
                id: folder_id,
                new_name: "Work".to_string(),
            })
            .unwrap();
        let renamed = recv_snapshot(&mut handle.event_rx).await;
        assert_eq!(renamed.current_folder.as_ref().unwrap().name, "Work");

        handle
            .send(CoreCommand::DeleteFolder { id: folder_id })
            .unwrap();
        let after_delete = recv_snapshot(&mut handle.event_rx).await;
        assert!(after_delete.current_folder.is_none());
        assert!(after_delete.all_folders.is_empty());

        handle.send(CoreCommand::Shutdown).unwrap();
    }
}

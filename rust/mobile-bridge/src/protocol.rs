use std::path::PathBuf;

use serde::{Deserialize, Serialize};
use teledrive_core::{
    AuthStatus, CoreCommand, CoreEvent, DirectorySnapshot, FileRecord, Folder, QueueEvent,
    StorageChat, TaskKind, TaskRecord,
};

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SidecarCommand {
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
        #[serde(default = "default_storage_kind")]
        kind: String,
    },
    ResetAuthStep,
    Logout,
    Shutdown,
}

fn default_storage_kind() -> String {
    "group".to_string()
}

impl From<SidecarCommand> for CoreCommand {
    fn from(cmd: SidecarCommand) -> Self {
        match cmd {
            SidecarCommand::Connect {
                api_id,
                api_hash,
                session_path,
            } => Self::Connect {
                api_id,
                api_hash,
                session_path,
            },
            SidecarCommand::SubmitPhone { phone } => Self::SubmitPhone { phone },
            SidecarCommand::SubmitCode { code } => Self::SubmitCode { code },
            SidecarCommand::SubmitPassword { password } => Self::SubmitPassword { password },
            SidecarCommand::OpenFolder { folder_id } => Self::OpenFolder { folder_id },
            SidecarCommand::Refresh => Self::Refresh,
            SidecarCommand::CreateFolder { parent_id, name } => {
                Self::CreateFolder { parent_id, name }
            }
            SidecarCommand::RenameFolder { id, new_name } => Self::RenameFolder { id, new_name },
            SidecarCommand::MoveFolder { id, new_parent_id } => {
                Self::MoveFolder { id, new_parent_id }
            }
            SidecarCommand::DeleteFolder { id } => Self::DeleteFolder { id },
            SidecarCommand::RenameFile { id, new_name } => Self::RenameFile { id, new_name },
            SidecarCommand::MoveFile { id, new_folder_id } => Self::MoveFile { id, new_folder_id },
            SidecarCommand::DeleteFile { id } => Self::DeleteFile { id },
            SidecarCommand::UploadFiles { paths, folder_id } => {
                Self::UploadFiles { paths, folder_id }
            }
            SidecarCommand::DownloadFile { file_id, dest_path } => {
                Self::DownloadFile { file_id, dest_path }
            }
            SidecarCommand::PauseTask { task_id } => Self::PauseTask { task_id },
            SidecarCommand::ResumeTask { task_id, dest_path } => {
                Self::ResumeTask { task_id, dest_path }
            }
            SidecarCommand::SetChunkSize { chunk_size } => Self::SetChunkSize { chunk_size },
            SidecarCommand::SetEncryptionPassword { password } => {
                Self::SetEncryptionPassword { password }
            }
            SidecarCommand::BackupIndex { password } => Self::BackupIndex { password },
            SidecarCommand::RestoreIndex {
                password,
                message_id,
            } => Self::RestoreIndex {
                password,
                message_id,
            },
            SidecarCommand::ListChats => Self::ListChats,
            SidecarCommand::SetTargetChat { chat_id } => Self::SetTargetChat { chat_id },
            SidecarCommand::CreateStorageChat { title, kind } => {
                Self::CreateStorageChat { title, kind }
            }
            SidecarCommand::ResetAuthStep => Self::ResetAuthStep,
            SidecarCommand::Logout => Self::Logout,
            SidecarCommand::Shutdown => Self::Shutdown,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum AuthStatusDto {
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

impl From<AuthStatus> for AuthStatusDto {
    fn from(status: AuthStatus) -> Self {
        match status {
            AuthStatus::Disconnected => Self::Disconnected,
            AuthStatus::Connecting => Self::Connecting,
            AuthStatus::AwaitingPhone => Self::AwaitingPhone,
            AuthStatus::AwaitingCode { phone } => Self::AwaitingCode { phone },
            AuthStatus::AwaitingPassword { hint } => Self::AwaitingPassword { hint },
            AuthStatus::Authorized {
                user_id,
                full_name,
                username,
            } => Self::Authorized {
                user_id,
                full_name,
                username,
            },
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct DirectorySnapshotDto {
    pub current_folder: Option<Folder>,
    pub breadcrumbs: Vec<Folder>,
    pub all_folders: Vec<Folder>,
    pub all_files: Vec<FileRecord>,
    pub folders: Vec<Folder>,
    pub files: Vec<FileRecord>,
    pub tasks: Vec<TaskRecord>,
}

impl From<DirectorySnapshot> for DirectorySnapshotDto {
    fn from(s: DirectorySnapshot) -> Self {
        Self {
            current_folder: s.current_folder,
            breadcrumbs: s.breadcrumbs,
            all_folders: s.all_folders,
            all_files: s.all_files,
            folders: s.folders,
            files: s.files,
            tasks: s.tasks,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[allow(clippy::enum_variant_names)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum QueueEventDto {
    TaskStarted {
        file_label: String,
        kind: &'static str,
    },
    TaskProgress {
        task_id: i64,
        file_id: i64,
        kind: &'static str,
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
        kind: &'static str,
    },
    TaskPaused {
        task_id: i64,
        file_id: i64,
        kind: &'static str,
    },
    TaskFailed {
        file_label: String,
        kind: &'static str,
        error: String,
    },
}

fn kind_str(kind: TaskKind) -> &'static str {
    kind.as_str()
}

impl From<QueueEvent> for QueueEventDto {
    fn from(ev: QueueEvent) -> Self {
        match ev {
            QueueEvent::TaskStarted { file_label, kind } => Self::TaskStarted {
                file_label,
                kind: kind_str(kind),
            },
            QueueEvent::TaskProgress {
                task_id,
                file_id,
                kind,
                progress,
            } => Self::TaskProgress {
                task_id,
                file_id,
                kind: kind_str(kind),
                progress,
            },
            QueueEvent::TaskFloodWait {
                task_id,
                file_id,
                seconds,
                attempt,
            } => Self::TaskFloodWait {
                task_id,
                file_id,
                seconds,
                attempt,
            },
            QueueEvent::TaskCompleted {
                task_id,
                file_id,
                kind,
            } => Self::TaskCompleted {
                task_id,
                file_id,
                kind: kind_str(kind),
            },
            QueueEvent::TaskPaused {
                task_id,
                file_id,
                kind,
            } => Self::TaskPaused {
                task_id,
                file_id,
                kind: kind_str(kind),
            },
            QueueEvent::TaskFailed {
                file_label,
                kind,
                error,
            } => Self::TaskFailed {
                file_label,
                kind: kind_str(kind),
                error,
            },
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct StorageChatDto {
    pub id: i64,
    pub title: String,
    pub kind: String,
    pub is_creator: bool,
    pub is_private: bool,
    pub member_count: Option<i32>,
}

impl From<StorageChat> for StorageChatDto {
    fn from(chat: StorageChat) -> Self {
        Self {
            id: chat.id,
            title: chat.title,
            kind: chat.kind,
            is_creator: chat.is_creator,
            is_private: chat.is_private,
            member_count: chat.member_count,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SidecarEvent {
    Ready {
        db_path: String,
        default_chunk_size: u64,
        has_env_config: bool,
        api_id: Option<i32>,
        session_path: Option<String>,
    },
    AuthChanged {
        auth: AuthStatusDto,
    },
    Snapshot {
        snapshot: DirectorySnapshotDto,
    },
    Queue {
        queue: QueueEventDto,
    },
    ChatsListed {
        chats: Vec<StorageChatDto>,
    },
    StorageChatCreated {
        chat: StorageChatDto,
    },
    TargetChatChanged {
        chat_id: Option<i64>,
    },
    Info {
        message: String,
    },
    Error {
        message: String,
    },
}

impl From<CoreEvent> for SidecarEvent {
    fn from(ev: CoreEvent) -> Self {
        match ev {
            CoreEvent::AuthChanged(status) => Self::AuthChanged {
                auth: status.into(),
            },
            CoreEvent::Snapshot(snapshot) => Self::Snapshot {
                snapshot: snapshot.into(),
            },
            CoreEvent::Queue(queue_ev) => Self::Queue {
                queue: queue_ev.into(),
            },
            CoreEvent::ChatsListed(chats) => Self::ChatsListed {
                chats: chats.into_iter().map(Into::into).collect(),
            },
            CoreEvent::StorageChatCreated(chat) => {
                Self::StorageChatCreated { chat: chat.into() }
            }
            CoreEvent::TargetChatChanged(chat_id) => Self::TargetChatChanged { chat_id },
            CoreEvent::Info(message) => Self::Info { message },
            CoreEvent::Error(message) => Self::Error { message },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn command_deserialization_roundtrip_works() {
        let raw = r#"{"type":"create_folder","parent_id":null,"name":"Work"}"#;
        let cmd: SidecarCommand = serde_json::from_str(raw).expect("valid json command");
        assert!(matches!(
            CoreCommand::from(cmd),
            CoreCommand::CreateFolder {
                parent_id: None,
                ..
            }
        ));

        let upload_raw = r#"{"type":"upload_files","paths":["C:\\tmp\\a.txt"],"folder_id":3}"#;
        let upload_cmd: SidecarCommand = serde_json::from_str(upload_raw).expect("valid upload");
        assert!(matches!(
            CoreCommand::from(upload_cmd),
            CoreCommand::UploadFiles {
                folder_id: Some(3),
                ..
            }
        ));

        let pause_raw = r#"{"type":"pause_task","task_id":42}"#;
        let pause_cmd: SidecarCommand = serde_json::from_str(pause_raw).expect("valid pause");
        assert!(matches!(
            CoreCommand::from(pause_cmd),
            CoreCommand::PauseTask { task_id: 42 }
        ));

        let resume_raw = r#"{"type":"resume_task","task_id":42,"dest_path":null}"#;
        let resume_cmd: SidecarCommand = serde_json::from_str(resume_raw).expect("valid resume");
        assert!(matches!(
            CoreCommand::from(resume_cmd),
            CoreCommand::ResumeTask {
                task_id: 42,
                dest_path: None
            }
        ));

        let reset_raw = r#"{"type":"reset_auth_step"}"#;
        let reset_cmd: SidecarCommand = serde_json::from_str(reset_raw).expect("valid reset_auth_step");
        assert!(matches!(CoreCommand::from(reset_cmd), CoreCommand::ResetAuthStep));

        let logout_raw = r#"{"type":"logout"}"#;
        let logout_cmd: SidecarCommand = serde_json::from_str(logout_raw).expect("valid logout");
        assert!(matches!(CoreCommand::from(logout_cmd), CoreCommand::Logout));

        let create_chat_raw = r#"{"type":"create_storage_chat","title":"Duck Vault","kind":"channel"}"#;
        let create_chat_cmd: SidecarCommand =
            serde_json::from_str(create_chat_raw).expect("valid create_storage_chat");
        assert!(matches!(
            CoreCommand::from(create_chat_cmd),
            CoreCommand::CreateStorageChat { title, kind } if title == "Duck Vault" && kind == "channel"
        ));
    }

    #[test]
    fn event_serialization_produces_tagged_json() {
        let ev = SidecarEvent::from(CoreEvent::AuthChanged(AuthStatus::AwaitingCode {
            phone: "+201000000000".to_string(),
        }));
        let json = serde_json::to_string(&ev).expect("serialize auth event");
        assert!(json.contains(r#""type":"auth_changed""#));
        assert!(json.contains(r#""status":"awaiting_code""#));

        let created = SidecarEvent::from(CoreEvent::StorageChatCreated(StorageChat {
            id: 777,
            title: "Vault".to_string(),
            kind: "group".to_string(),
            is_creator: true,
            is_private: true,
            member_count: Some(1),
        }));
        let created_json = serde_json::to_string(&created).expect("serialize created event");
        assert!(created_json.contains(r#""type":"storage_chat_created""#));
        assert!(created_json.contains(r#""is_creator":true"#));
    }
}

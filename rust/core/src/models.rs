use std::str::FromStr;

use serde::{Deserialize, Serialize};

use crate::error::{CoreError, Result};

/// Virtual folder stored in the local SQLite index.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
pub struct Folder {
    pub id: i64,
    pub parent_id: Option<i64>,
    pub name: String,
    pub created_at: i64,
}

/// Logical file metadata indexed in SQLite and backed by Telegram chunks.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
pub struct FileRecord {
    pub id: i64,
    pub folder_id: Option<i64>,
    pub name: String,
    pub size: i64,
    pub mime_type: String,
    pub sha256: String,
    pub is_encrypted: bool,
    pub created_at: i64,
}

/// Parameters required to insert a new file record into SQLite.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewFile {
    pub folder_id: Option<i64>,
    pub name: String,
    pub size: i64,
    pub mime_type: String,
    pub sha256: String,
    pub is_encrypted: bool,
}

/// Telegram message reference representing a single chunk of a file.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
pub struct FileChunk {
    pub id: i64,
    pub file_id: i64,
    pub chunk_index: i64,
    pub telegram_message_id: i32,
    pub size: i64,
}

/// Parameters required to insert a new file chunk record into SQLite.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewFileChunk {
    pub file_id: i64,
    pub chunk_index: i64,
    pub telegram_message_id: i32,
    pub size: i64,
}

/// Supported background transfer task kinds.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskKind {
    Upload,
    Download,
}

impl TaskKind {
    /// Returns the canonical database string representation.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Upload => "upload",
            Self::Download => "download",
        }
    }
}

impl FromStr for TaskKind {
    type Err = CoreError;

    fn from_str(s: &str) -> Result<Self> {
        match s {
            "upload" => Ok(Self::Upload),
            "download" => Ok(Self::Download),
            other => Err(CoreError::InvalidConfig(format!(
                "unknown task kind '{other}'"
            ))),
        }
    }
}

/// Lifecycle state of a background transfer task.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskState {
    Queued,
    Running,
    Paused,
    Completed,
    Failed,
}

impl TaskState {
    /// Returns the canonical database string representation.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Queued => "queued",
            Self::Running => "running",
            Self::Paused => "paused",
            Self::Completed => "completed",
            Self::Failed => "failed",
        }
    }
}

impl FromStr for TaskState {
    type Err = CoreError;

    fn from_str(s: &str) -> Result<Self> {
        match s {
            "queued" => Ok(Self::Queued),
            "running" => Ok(Self::Running),
            "paused" => Ok(Self::Paused),
            "completed" => Ok(Self::Completed),
            "failed" => Ok(Self::Failed),
            other => Err(CoreError::InvalidConfig(format!(
                "unknown task state '{other}'"
            ))),
        }
    }
}

/// Persistent transfer task record stored in SQLite.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
pub struct TaskRecord {
    pub id: i64,
    pub kind: String,
    pub file_id: i64,
    pub state: String,
    pub progress: f64,
    pub error: Option<String>,
}

impl TaskRecord {
    /// Parses `kind` into a typed [`TaskKind`].
    pub fn kind_enum(&self) -> Result<TaskKind> {
        self.kind.parse()
    }

    /// Parses `state` into a typed [`TaskState`].
    pub fn state_enum(&self) -> Result<TaskState> {
        self.state.parse()
    }
}

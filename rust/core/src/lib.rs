pub mod backup;
pub mod chunker;
pub mod crypto;
pub mod db;
pub mod error;
pub mod keyring_store;
pub mod models;
pub mod queue;
pub mod telegram;
pub mod worker;

pub use backup::{
    export_encrypted_backup, import_encrypted_backup, restore_backup_from_telegram,
    upload_backup_to_telegram, IndexBackupPayload,
};
pub use chunker::{
    compute_file_sha256, plan_chunks, ChunkSpec, ChunkTransport, ChunkerConfig, RetryPolicy,
    TransferEngine, TransferNotice, DEFAULT_CHUNK_SIZE, DEFAULT_MAX_CONCURRENT_CHUNKS,
};
pub use crypto::{decrypt_bytes, derive_key, encrypt_bytes, ENCRYPTED_CHUNK_OVERHEAD};
pub use db::Database;
pub use error::{CoreError, Result};
pub use keyring_store::{
    account_key_from_path, delete_session_from_keyring, load_session_from_keyring,
    save_session_to_keyring,
};
pub use models::{
    FileChunk, FileRecord, Folder, NewFile, NewFileChunk, TaskKind, TaskRecord, TaskState,
};
pub use queue::{
    QueueConfig, QueueControl, QueueEvent, QueueRequest, TaskQueueManager,
    DEFAULT_MAX_CONCURRENT_TASKS,
};
pub use telegram::{
    StorageChat, TelegramClient, TelegramConfig, BACKUP_CAPTION_PREFIX, BACKUP_FILE_NAME,
};
pub use worker::{
    spawn_core_worker, AuthStatus, CoreCommand, CoreEvent, CoreWorkerHandle, DirectorySnapshot,
};

use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};
use tracing::info;

use crate::chunker::ChunkTransport;
use crate::crypto;
use crate::db::Database;
use crate::error::{CoreError, Result};
use crate::models::{FileChunk, FileRecord, Folder, TaskRecord};
use crate::telegram::{BACKUP_CAPTION_PREFIX, BACKUP_FILE_NAME};

const BACKUP_FORMAT_VERSION: u32 = 1;

/// Full serializable snapshot of the local TeleDrive SQLite metadata index.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct IndexBackupPayload {
    pub version: u32,
    pub folders: Vec<Folder>,
    pub files: Vec<FileRecord>,
    pub file_chunks: Vec<FileChunk>,
    pub tasks: Vec<TaskRecord>,
}

/// Exports the entire SQLite metadata index as an AES-256-GCM encrypted payload.
pub async fn export_encrypted_backup(db: &Database, password: &str) -> Result<Vec<u8>> {
    if password.is_empty() {
        return Err(CoreError::Encryption(
            "backup password must not be empty".to_string(),
        ));
    }

    let payload = IndexBackupPayload {
        version: BACKUP_FORMAT_VERSION,
        folders: db.list_all_folders().await?,
        files: db.list_all_files().await?,
        file_chunks: db.list_all_file_chunks().await?,
        tasks: db.list_tasks().await?,
    };

    let json_bytes = serde_json::to_vec(&payload).map_err(|err| {
        CoreError::InvalidConfig(format!("failed to serialize index backup: {err}"))
    })?;
    let pw = password.to_string();

    tokio::task::spawn_blocking(move || crypto::encrypt_bytes(&json_bytes, &pw))
        .await
        .map_err(|err| CoreError::Encryption(format!("backup encryption task panicked: {err}")))?
}

/// Decrypts an encrypted index backup payload and atomically restores it into `db`.
pub async fn import_encrypted_backup(
    db: &Database,
    encrypted_frame: &[u8],
    password: &str,
) -> Result<IndexBackupPayload> {
    if password.is_empty() {
        return Err(CoreError::Encryption(
            "backup password must not be empty".to_string(),
        ));
    }

    let frame = encrypted_frame.to_vec();
    let pw = password.to_string();
    let plaintext = tokio::task::spawn_blocking(move || crypto::decrypt_bytes(&frame, &pw))
        .await
        .map_err(|err| {
            CoreError::Encryption(format!("backup decryption task panicked: {err}"))
        })??;

    let payload: IndexBackupPayload = serde_json::from_slice(&plaintext).map_err(|err| {
        CoreError::InvalidConfig(format!("invalid index backup JSON payload: {err}"))
    })?;

    if payload.version != BACKUP_FORMAT_VERSION {
        return Err(CoreError::InvalidConfig(format!(
            "unsupported index backup version {}",
            payload.version
        )));
    }

    db.replace_all_from_snapshot(
        &payload.folders,
        &payload.files,
        &payload.file_chunks,
        &payload.tasks,
    )
    .await?;

    info!(
        folders = payload.folders.len(),
        files = payload.files.len(),
        chunks = payload.file_chunks.len(),
        "Restored SQLite index from encrypted backup"
    );
    Ok(payload)
}

/// Encrypts the local SQLite index and uploads it to Telegram Saved Messages, returning `message_id`.
pub async fn upload_backup_to_telegram<T: ChunkTransport>(
    db: &Database,
    transport: &T,
    password: &str,
) -> Result<i32> {
    let encrypted = export_encrypted_backup(db, password).await?;
    let msg_id = transport
        .upload_bytes(
            encrypted,
            BACKUP_FILE_NAME.to_string(),
            BACKUP_CAPTION_PREFIX.to_string(),
        )
        .await?;
    info!(
        message_id = msg_id,
        "Uploaded encrypted index backup to Telegram"
    );
    Ok(msg_id)
}

/// Downloads an encrypted index backup from `message_id` and restores it into `db`.
pub async fn restore_backup_from_telegram<T: ChunkTransport>(
    db: &Database,
    transport: &T,
    message_id: i32,
    password: &str,
) -> Result<IndexBackupPayload> {
    let temp_path = unique_temp_backup_path(message_id);
    if let Err(err) = transport.download_chunk(message_id, &temp_path).await {
        let _ = tokio::fs::remove_file(&temp_path).await;
        return Err(err);
    }

    let bytes = match tokio::fs::read(&temp_path).await {
        Ok(data) => {
            let _ = tokio::fs::remove_file(&temp_path).await;
            data
        }
        Err(err) => {
            let _ = tokio::fs::remove_file(&temp_path).await;
            return Err(CoreError::Io(err));
        }
    };

    import_encrypted_backup(db, &bytes, password).await
}

fn unique_temp_backup_path(message_id: i32) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    std::env::temp_dir().join(format!(
        "teledrive_restore_{message_id}_{}_{}.tdrvbak",
        std::process::id(),
        nanos
    ))
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::path::Path;
    use std::sync::atomic::{AtomicI32, Ordering};
    use std::sync::Mutex;

    use crate::models::{NewFile, NewFileChunk, TaskKind, TaskState};

    use super::*;

    struct MockBackupTransport {
        blobs: Mutex<HashMap<i32, Vec<u8>>>,
        next_msg_id: AtomicI32,
    }

    impl MockBackupTransport {
        fn new() -> Self {
            Self {
                blobs: Mutex::new(HashMap::new()),
                next_msg_id: AtomicI32::new(700),
            }
        }
    }

    impl ChunkTransport for MockBackupTransport {
        async fn upload_chunk(
            &self,
            _path: &Path,
            _offset: u64,
            _size: u64,
            _file_name: String,
            _caption: String,
        ) -> Result<i32> {
            unreachable!("not used by backup tests")
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
    async fn encrypted_backup_and_restore_roundtrip_on_new_database() {
        let source_db = Database::connect_in_memory().await.unwrap();
        let parent = source_db.create_folder(None, "Zebra").await.unwrap();
        // Deliberately name child alphabetically before parent ("Alpha" < "Zebra") to test FK topological ordering.
        let child = source_db
            .create_folder(Some(parent.id), "Alpha")
            .await
            .unwrap();

        let file = source_db
            .create_file(&NewFile {
                folder_id: Some(child.id),
                name: "vault.db".to_string(),
                size: 4096,
                mime_type: "application/octet-stream".to_string(),
                sha256: "abcdef1234".to_string(),
                is_encrypted: true,
            })
            .await
            .unwrap();

        source_db
            .insert_file_chunk(&NewFileChunk {
                file_id: file.id,
                chunk_index: 0,
                telegram_message_id: 9001,
                size: 4148,
            })
            .await
            .unwrap();
        let task = source_db
            .create_task(TaskKind::Upload, file.id)
            .await
            .unwrap();
        source_db
            .update_task_progress(task.id, TaskState::Completed, 1.0, None)
            .await
            .unwrap();

        let transport = MockBackupTransport::new();
        let backup_msg_id = upload_backup_to_telegram(&source_db, &transport, "backup-secret")
            .await
            .unwrap();

        // Restore into a fresh database simulating a new device.
        let new_device_db = Database::connect_in_memory().await.unwrap();
        let existing = new_device_db
            .create_folder(None, "KeepOnFailure")
            .await
            .unwrap();

        // Wrong password must fail without erasing existing data on the target DB.
        let wrong =
            restore_backup_from_telegram(&new_device_db, &transport, backup_msg_id, "wrong-pw")
                .await;
        assert!(matches!(wrong, Err(CoreError::Encryption(_))));
        assert!(new_device_db.get_folder(existing.id).await.is_ok());

        // Correct password restores all folders, files, chunks, and tasks cleanly.
        let restored_payload = restore_backup_from_telegram(
            &new_device_db,
            &transport,
            backup_msg_id,
            "backup-secret",
        )
        .await
        .unwrap();
        assert_eq!(restored_payload.folders.len(), 2);
        assert_eq!(restored_payload.files.len(), 1);
        assert_eq!(restored_payload.file_chunks.len(), 1);
        assert_eq!(restored_payload.tasks.len(), 1);

        let restored_child = new_device_db.get_folder(child.id).await.unwrap();
        assert_eq!(restored_child.parent_id, Some(parent.id));
        let restored_file = new_device_db.get_file(file.id).await.unwrap();
        assert_eq!(restored_file.name, "vault.db");
        assert!(restored_file.is_encrypted);
        let restored_chunks = new_device_db.list_file_chunks(file.id).await.unwrap();
        assert_eq!(restored_chunks[0].telegram_message_id, 9001);
        let root_folders = new_device_db.list_folders(None).await.unwrap();
        assert_eq!(root_folders.len(), 1);
        assert_eq!(root_folders[0].name, "Zebra");
        assert!(root_folders.iter().all(|f| f.name != "KeepOnFailure"));
    }
}

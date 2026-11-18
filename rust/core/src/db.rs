use std::collections::HashSet;
use std::path::Path;

use sqlx::sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions};
use sqlx::SqlitePool;
use tracing::{debug, info};

use crate::error::{CoreError, Result};
use crate::models::{
    FileChunk, FileRecord, Folder, NewFile, NewFileChunk, TaskKind, TaskRecord, TaskState,
};

/// Local SQLite database handle backed by an `sqlx::SqlitePool`.
#[derive(Debug, Clone)]
pub struct Database {
    pool: SqlitePool,
}

impl Database {
    /// Opens (or creates) a SQLite database at `db_path`, enables foreign keys and WAL mode,
    /// and executes embedded migrations.
    pub async fn connect(db_path: &Path) -> Result<Self> {
        if db_path.as_os_str().is_empty() {
            return Err(CoreError::InvalidConfig(
                "database path must not be empty".to_string(),
            ));
        }

        if let Some(parent) = db_path.parent().filter(|p| !p.as_os_str().is_empty()) {
            std::fs::create_dir_all(parent)?;
        }

        let options = SqliteConnectOptions::new()
            .filename(db_path)
            .create_if_missing(true)
            .foreign_keys(true)
            .journal_mode(SqliteJournalMode::Wal);

        let pool = SqlitePoolOptions::new()
            .max_connections(5)
            .connect_with(options)
            .await?;

        Self::from_pool_migrated(pool).await
    }

    /// Creates an isolated single-connection in-memory SQLite database with migrations applied.
    pub async fn connect_in_memory() -> Result<Self> {
        let options = SqliteConnectOptions::new()
            .filename(":memory:")
            .foreign_keys(true);

        // Single connection ensures all operations observe the same in-memory database.
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await?;

        Self::from_pool_migrated(pool).await
    }

    async fn from_pool_migrated(pool: SqlitePool) -> Result<Self> {
        debug!("Running SQLite migrations");
        sqlx::migrate!("./migrations").run(&pool).await?;
        info!("SQLite database initialized and migrations applied");
        Ok(Self { pool })
    }

    /// Exposes a reference to the underlying `SqlitePool`.
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }

    // -------------------------------------------------------------------------
    // Folders CRUD
    // -------------------------------------------------------------------------

    /// Creates a new virtual folder under `parent_id` (or root if `None`).
    pub async fn create_folder(&self, parent_id: Option<i64>, name: &str) -> Result<Folder> {
        let name = validate_entry_name(name, "folder name")?;
        if let Some(pid) = parent_id {
            self.get_folder(pid).await?;
        }

        let folder = sqlx::query_as::<_, Folder>(
            "INSERT INTO folders (parent_id, name) VALUES (?, ?)
             RETURNING id, parent_id, name, created_at",
        )
        .bind(parent_id)
        .bind(name)
        .fetch_one(&self.pool)
        .await?;

        Ok(folder)
    }

    /// Fetches a folder by its ID, returning [`CoreError::NotFound`] if it does not exist.
    pub async fn get_folder(&self, id: i64) -> Result<Folder> {
        sqlx::query_as::<_, Folder>(
            "SELECT id, parent_id, name, created_at FROM folders WHERE id = ?",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("folder {id} not found")))
    }

    /// Lists direct child folders under `parent_id` (or root folders when `None`), sorted by name.
    pub async fn list_folders(&self, parent_id: Option<i64>) -> Result<Vec<Folder>> {
        let folders = match parent_id {
            Some(pid) => {
                sqlx::query_as::<_, Folder>(
                    "SELECT id, parent_id, name, created_at
                     FROM folders
                     WHERE parent_id = ?
                     ORDER BY name ASC, id ASC",
                )
                .bind(pid)
                .fetch_all(&self.pool)
                .await?
            }
            None => {
                sqlx::query_as::<_, Folder>(
                    "SELECT id, parent_id, name, created_at
                     FROM folders
                     WHERE parent_id IS NULL
                     ORDER BY name ASC, id ASC",
                )
                .fetch_all(&self.pool)
                .await?
            }
        };
        Ok(folders)
    }

    /// Lists all folders across the entire virtual drive, sorted by name.
    pub async fn list_all_folders(&self) -> Result<Vec<Folder>> {
        let folders = sqlx::query_as::<_, Folder>(
            "SELECT id, parent_id, name, created_at
             FROM folders
             ORDER BY name ASC, id ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(folders)
    }

    /// Renames an existing folder.
    pub async fn rename_folder(&self, id: i64, new_name: &str) -> Result<Folder> {
        let new_name = validate_entry_name(new_name, "folder name")?;
        sqlx::query_as::<_, Folder>(
            "UPDATE folders SET name = ? WHERE id = ?
             RETURNING id, parent_id, name, created_at",
        )
        .bind(new_name)
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("folder {id} not found")))
    }

    /// Moves a folder under `new_parent_id` (or root if `None`), rejecting cycles.
    pub async fn move_folder(&self, id: i64, new_parent_id: Option<i64>) -> Result<Folder> {
        self.get_folder(id).await?;

        if let Some(target_pid) = new_parent_id {
            if target_pid == id {
                return Err(CoreError::InvalidConfig(
                    "cannot move a folder into itself".to_string(),
                ));
            }
            self.ensure_not_descendant(id, target_pid).await?;
        }

        sqlx::query_as::<_, Folder>(
            "UPDATE folders SET parent_id = ? WHERE id = ?
             RETURNING id, parent_id, name, created_at",
        )
        .bind(new_parent_id)
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("folder {id} not found")))
    }

    async fn ensure_not_descendant(&self, ancestor_id: i64, target_id: i64) -> Result<()> {
        let mut cursor = Some(target_id);
        while let Some(current_id) = cursor {
            let folder = self.get_folder(current_id).await?;
            if folder.id == ancestor_id {
                return Err(CoreError::InvalidConfig(format!(
                    "cannot move folder {ancestor_id} into its descendant {target_id}"
                )));
            }
            cursor = folder.parent_id;
        }
        Ok(())
    }

    /// Deletes a folder (and cascades to subfolders, files, chunks, and tasks).
    pub async fn delete_folder(&self, id: i64) -> Result<()> {
        let res = sqlx::query("DELETE FROM folders WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        if res.rows_affected() == 0 {
            return Err(CoreError::NotFound(format!("folder {id} not found")));
        }
        Ok(())
    }

    // -------------------------------------------------------------------------
    // Files CRUD
    // -------------------------------------------------------------------------

    /// Inserts a new logical file record.
    pub async fn create_file(&self, new_file: &NewFile) -> Result<FileRecord> {
        let name = validate_entry_name(&new_file.name, "file name")?;
        if new_file.size < 0 {
            return Err(CoreError::InvalidConfig(
                "file size must be non-negative".to_string(),
            ));
        }
        if let Some(fid) = new_file.folder_id {
            self.get_folder(fid).await?;
        }

        let record = sqlx::query_as::<_, FileRecord>(
            "INSERT INTO files (folder_id, name, size, mime_type, sha256, is_encrypted)
             VALUES (?, ?, ?, ?, ?, ?)
             RETURNING id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at",
        )
        .bind(new_file.folder_id)
        .bind(name)
        .bind(new_file.size)
        .bind(&new_file.mime_type)
        .bind(&new_file.sha256)
        .bind(new_file.is_encrypted)
        .fetch_one(&self.pool)
        .await?;

        Ok(record)
    }

    /// Fetches a file record by its ID.
    pub async fn get_file(&self, id: i64) -> Result<FileRecord> {
        sqlx::query_as::<_, FileRecord>(
            "SELECT id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at
             FROM files
             WHERE id = ?",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("file {id} not found")))
    }

    /// Lists all files inside `folder_id` (or root when `None`), sorted by name.
    pub async fn list_files(&self, folder_id: Option<i64>) -> Result<Vec<FileRecord>> {
        let files =
            match folder_id {
                Some(fid) => sqlx::query_as::<_, FileRecord>(
                    "SELECT id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at
                     FROM files
                     WHERE folder_id = ?
                     ORDER BY name ASC, id ASC",
                )
                .bind(fid)
                .fetch_all(&self.pool)
                .await?,
                None => sqlx::query_as::<_, FileRecord>(
                    "SELECT id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at
                     FROM files
                     WHERE folder_id IS NULL
                     ORDER BY name ASC, id ASC",
                )
                .fetch_all(&self.pool)
                .await?,
            };
        Ok(files)
    }

    /// Renames an existing file record.
    pub async fn rename_file(&self, id: i64, new_name: &str) -> Result<FileRecord> {
        let new_name = validate_entry_name(new_name, "file name")?;
        sqlx::query_as::<_, FileRecord>(
            "UPDATE files SET name = ? WHERE id = ?
             RETURNING id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at",
        )
        .bind(new_name)
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("file {id} not found")))
    }

    /// Moves a file record to `new_folder_id` (or root when `None`).
    pub async fn move_file(&self, id: i64, new_folder_id: Option<i64>) -> Result<FileRecord> {
        if let Some(fid) = new_folder_id {
            self.get_folder(fid).await?;
        }
        sqlx::query_as::<_, FileRecord>(
            "UPDATE files SET folder_id = ? WHERE id = ?
             RETURNING id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at",
        )
        .bind(new_folder_id)
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("file {id} not found")))
    }

    /// Lists all files across all folders, ordered by ID.
    pub async fn list_all_files(&self) -> Result<Vec<FileRecord>> {
        let files = sqlx::query_as::<_, FileRecord>(
            "SELECT id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at
             FROM files
             ORDER BY id ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(files)
    }

    /// Looks up the most recent file record in `folder_id` matching identity and encryption flag.
    pub async fn find_file_by_identity(
        &self,
        folder_id: Option<i64>,
        name: &str,
        size: i64,
        sha256: &str,
        is_encrypted: bool,
    ) -> Result<Option<FileRecord>> {
        let file = sqlx::query_as::<_, FileRecord>(
            "SELECT id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at
             FROM files
             WHERE folder_id IS ? AND name = ? AND size = ? AND sha256 = ? AND is_encrypted = ?
             ORDER BY id DESC
             LIMIT 1",
        )
        .bind(folder_id)
        .bind(name)
        .bind(size)
        .bind(sha256)
        .bind(is_encrypted)
        .fetch_optional(&self.pool)
        .await?;
        Ok(file)
    }

    /// Deletes a file record (and cascades to its chunks and tasks).
    pub async fn delete_file(&self, id: i64) -> Result<()> {
        let res = sqlx::query("DELETE FROM files WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        if res.rows_affected() == 0 {
            return Err(CoreError::NotFound(format!("file {id} not found")));
        }
        Ok(())
    }

    // -------------------------------------------------------------------------
    // File Chunks CRUD
    // -------------------------------------------------------------------------

    /// Inserts a Telegram chunk reference for an indexed file.
    pub async fn insert_file_chunk(&self, chunk: &NewFileChunk) -> Result<FileChunk> {
        if chunk.chunk_index < 0 || chunk.size < 0 {
            return Err(CoreError::InvalidConfig(
                "chunk_index and size must be non-negative".to_string(),
            ));
        }

        let record = sqlx::query_as::<_, FileChunk>(
            "INSERT INTO file_chunks (file_id, chunk_index, telegram_message_id, size)
             VALUES (?, ?, ?, ?)
             RETURNING id, file_id, chunk_index, telegram_message_id, size",
        )
        .bind(chunk.file_id)
        .bind(chunk.chunk_index)
        .bind(chunk.telegram_message_id)
        .bind(chunk.size)
        .fetch_one(&self.pool)
        .await?;

        Ok(record)
    }

    /// Lists all chunks belonging to `file_id`, ordered sequentially by `chunk_index`.
    pub async fn list_file_chunks(&self, file_id: i64) -> Result<Vec<FileChunk>> {
        let chunks = sqlx::query_as::<_, FileChunk>(
            "SELECT id, file_id, chunk_index, telegram_message_id, size
             FROM file_chunks
             WHERE file_id = ?
             ORDER BY chunk_index ASC",
        )
        .bind(file_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(chunks)
    }

    // -------------------------------------------------------------------------
    // Tasks CRUD
    // -------------------------------------------------------------------------

    /// Enqueues a new transfer task in the `queued` state.
    pub async fn create_task(&self, kind: TaskKind, file_id: i64) -> Result<TaskRecord> {
        self.get_file(file_id).await?;
        let task = sqlx::query_as::<_, TaskRecord>(
            "INSERT INTO tasks (kind, file_id, state, progress, error)
             VALUES (?, ?, ?, 0.0, NULL)
             RETURNING id, kind, file_id, state, progress, error",
        )
        .bind(kind.as_str())
        .bind(file_id)
        .bind(TaskState::Queued.as_str())
        .fetch_one(&self.pool)
        .await?;

        Ok(task)
    }

    /// Fetches a task record by its ID.
    pub async fn get_task(&self, id: i64) -> Result<TaskRecord> {
        sqlx::query_as::<_, TaskRecord>(
            "SELECT id, kind, file_id, state, progress, error FROM tasks WHERE id = ?",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("task {id} not found")))
    }

    /// Finds the latest non-completed task of `kind` for `file_id`, if any.
    pub async fn find_active_task_for_file(
        &self,
        file_id: i64,
        kind: TaskKind,
    ) -> Result<Option<TaskRecord>> {
        let task = sqlx::query_as::<_, TaskRecord>(
            "SELECT id, kind, file_id, state, progress, error
             FROM tasks
             WHERE file_id = ? AND kind = ? AND state != 'completed'
             ORDER BY id DESC
             LIMIT 1",
        )
        .bind(file_id)
        .bind(kind.as_str())
        .fetch_optional(&self.pool)
        .await?;
        Ok(task)
    }

    /// Finds the most recent task of `kind` for `file_id` regardless of state.
    pub async fn find_latest_task_for_file(
        &self,
        file_id: i64,
        kind: TaskKind,
    ) -> Result<Option<TaskRecord>> {
        let task = sqlx::query_as::<_, TaskRecord>(
            "SELECT id, kind, file_id, state, progress, error
             FROM tasks
             WHERE file_id = ? AND kind = ?
             ORDER BY id DESC
             LIMIT 1",
        )
        .bind(file_id)
        .bind(kind.as_str())
        .fetch_optional(&self.pool)
        .await?;
        Ok(task)
    }

    /// Lists all tasks ordered by insertion ID.
    pub async fn list_tasks(&self) -> Result<Vec<TaskRecord>> {
        let tasks = sqlx::query_as::<_, TaskRecord>(
            "SELECT id, kind, file_id, state, progress, error FROM tasks ORDER BY id ASC",
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(tasks)
    }

    /// Updates a task's state, fractional progress (`0.0..=1.0`), and optional error message.
    pub async fn update_task_progress(
        &self,
        id: i64,
        state: TaskState,
        progress: f64,
        error: Option<&str>,
    ) -> Result<TaskRecord> {
        if progress.is_nan() || !(0.0..=1.0).contains(&progress) {
            return Err(CoreError::InvalidConfig(
                "task progress must be within 0.0..=1.0".to_string(),
            ));
        }

        sqlx::query_as::<_, TaskRecord>(
            "UPDATE tasks SET state = ?, progress = ?, error = ? WHERE id = ?
             RETURNING id, kind, file_id, state, progress, error",
        )
        .bind(state.as_str())
        .bind(progress)
        .bind(error)
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| CoreError::NotFound(format!("task {id} not found")))
    }

    /// Lists all chunks across the entire index ordered by file and chunk index.
    pub async fn list_all_file_chunks(&self) -> Result<Vec<FileChunk>> {
        let chunks = sqlx::query_as::<_, FileChunk>(
            "SELECT id, file_id, chunk_index, telegram_message_id, size
             FROM file_chunks
             ORDER BY file_id ASC, chunk_index ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(chunks)
    }

    /// Atomically replaces the entire local SQLite index from a backup snapshot.
    pub async fn replace_all_from_snapshot(
        &self,
        folders: &[Folder],
        files: &[FileRecord],
        chunks: &[FileChunk],
        tasks: &[TaskRecord],
    ) -> Result<()> {
        let ordered_folders = order_folders_topologically(folders)?;

        let mut tx = self.pool.begin().await?;
        sqlx::query("DELETE FROM tasks").execute(&mut *tx).await?;
        sqlx::query("DELETE FROM file_chunks")
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM files").execute(&mut *tx).await?;
        sqlx::query("DELETE FROM folders").execute(&mut *tx).await?;

        for folder in ordered_folders {
            sqlx::query(
                "INSERT INTO folders (id, parent_id, name, created_at)
                 VALUES (?, ?, ?, ?)",
            )
            .bind(folder.id)
            .bind(folder.parent_id)
            .bind(&folder.name)
            .bind(folder.created_at)
            .execute(&mut *tx)
            .await?;
        }

        for file in files {
            sqlx::query(
                "INSERT INTO files (id, folder_id, name, size, mime_type, sha256, is_encrypted, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(file.id)
            .bind(file.folder_id)
            .bind(&file.name)
            .bind(file.size)
            .bind(&file.mime_type)
            .bind(&file.sha256)
            .bind(file.is_encrypted)
            .bind(file.created_at)
            .execute(&mut *tx)
            .await?;
        }

        for chunk in chunks {
            sqlx::query(
                "INSERT INTO file_chunks (id, file_id, chunk_index, telegram_message_id, size)
                 VALUES (?, ?, ?, ?, ?)",
            )
            .bind(chunk.id)
            .bind(chunk.file_id)
            .bind(chunk.chunk_index)
            .bind(chunk.telegram_message_id)
            .bind(chunk.size)
            .execute(&mut *tx)
            .await?;
        }

        for task in tasks {
            sqlx::query(
                "INSERT INTO tasks (id, kind, file_id, state, progress, error)
                 VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(task.id)
            .bind(&task.kind)
            .bind(task.file_id)
            .bind(&task.state)
            .bind(task.progress)
            .bind(&task.error)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    /// Deletes a task record by ID.
    pub async fn delete_task(&self, id: i64) -> Result<()> {
        let res = sqlx::query("DELETE FROM tasks WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        if res.rows_affected() == 0 {
            return Err(CoreError::NotFound(format!("task {id} not found")));
        }
        Ok(())
    }
}

fn order_folders_topologically(folders: &[Folder]) -> Result<Vec<&Folder>> {
    let mut ordered = Vec::with_capacity(folders.len());
    let mut inserted_ids = HashSet::with_capacity(folders.len());
    let mut remaining: Vec<&Folder> = folders.iter().collect();

    while !remaining.is_empty() {
        let prev_len = remaining.len();
        let mut next_remaining = Vec::new();

        for folder in remaining {
            let parent_ready = match folder.parent_id {
                None => true,
                Some(pid) => inserted_ids.contains(&pid),
            };
            if parent_ready {
                inserted_ids.insert(folder.id);
                ordered.push(folder);
            } else {
                next_remaining.push(folder);
            }
        }

        if next_remaining.len() == prev_len {
            return Err(CoreError::InvalidConfig(
                "backup contains cyclic or orphaned folder parent references".to_string(),
            ));
        }
        remaining = next_remaining;
    }

    Ok(ordered)
}

fn validate_entry_name<'a>(name: &'a str, label: &str) -> Result<&'a str> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return Err(CoreError::InvalidConfig(format!(
            "{label} must not be empty"
        )));
    }
    Ok(trimmed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn folder_crud_cycle_rejection_and_cascade_delete() {
        let db = Database::connect_in_memory().await.unwrap();

        let root_a = db.create_folder(None, "Documents").await.unwrap();
        let root_b = db.create_folder(None, "Archives").await.unwrap();
        let child = db.create_folder(Some(root_a.id), "Invoices").await.unwrap();
        let grandchild = db.create_folder(Some(child.id), "2026").await.unwrap();

        let roots = db.list_folders(None).await.unwrap();
        assert_eq!(roots.len(), 2);
        assert_eq!(roots[0].name, "Archives");
        assert_eq!(roots[1].name, "Documents");

        let renamed = db.rename_folder(child.id, "Receipts").await.unwrap();
        assert_eq!(renamed.name, "Receipts");

        // Reject moving into self or descendant
        assert!(matches!(
            db.move_folder(root_a.id, Some(root_a.id)).await,
            Err(CoreError::InvalidConfig(_))
        ));
        assert!(matches!(
            db.move_folder(root_a.id, Some(grandchild.id)).await,
            Err(CoreError::InvalidConfig(_))
        ));

        // Valid move under root_b
        let moved = db.move_folder(child.id, Some(root_b.id)).await.unwrap();
        assert_eq!(moved.parent_id, Some(root_b.id));
        assert!(db.list_folders(Some(root_a.id)).await.unwrap().is_empty());

        // Put a file inside grandchild and verify cascade delete when root_b is deleted
        let file = db
            .create_file(&NewFile {
                folder_id: Some(grandchild.id),
                name: "receipt.pdf".to_string(),
                size: 1024,
                mime_type: "application/pdf".to_string(),
                sha256: "deadbeef".to_string(),
                is_encrypted: false,
            })
            .await
            .unwrap();
        db.insert_file_chunk(&NewFileChunk {
            file_id: file.id,
            chunk_index: 0,
            telegram_message_id: 42,
            size: 1024,
        })
        .await
        .unwrap();
        let task = db.create_task(TaskKind::Upload, file.id).await.unwrap();

        db.delete_folder(root_b.id).await.unwrap();
        assert!(matches!(
            db.get_folder(child.id).await,
            Err(CoreError::NotFound(_))
        ));
        assert!(matches!(
            db.get_folder(grandchild.id).await,
            Err(CoreError::NotFound(_))
        ));
        assert!(matches!(
            db.get_file(file.id).await,
            Err(CoreError::NotFound(_))
        ));
        assert!(db.list_file_chunks(file.id).await.unwrap().is_empty());
        assert!(matches!(
            db.get_task(task.id).await,
            Err(CoreError::NotFound(_))
        ));
    }

    #[tokio::test]
    async fn file_chunks_ordering_and_task_updates() {
        let db = Database::connect_in_memory().await.unwrap();

        let file = db
            .create_file(&NewFile {
                folder_id: None,
                name: "backup.tar.zst".to_string(),
                size: 3000,
                mime_type: "application/zstd".to_string(),
                sha256: "0123456789abcdef".to_string(),
                is_encrypted: true,
            })
            .await
            .unwrap();
        assert!(file.is_encrypted);

        // Insert chunks out of order and confirm list_file_chunks returns them sorted.
        db.insert_file_chunk(&NewFileChunk {
            file_id: file.id,
            chunk_index: 2,
            telegram_message_id: 102,
            size: 1000,
        })
        .await
        .unwrap();
        db.insert_file_chunk(&NewFileChunk {
            file_id: file.id,
            chunk_index: 0,
            telegram_message_id: 100,
            size: 1000,
        })
        .await
        .unwrap();
        db.insert_file_chunk(&NewFileChunk {
            file_id: file.id,
            chunk_index: 1,
            telegram_message_id: 101,
            size: 1000,
        })
        .await
        .unwrap();

        let chunks = db.list_file_chunks(file.id).await.unwrap();
        let indices: Vec<i64> = chunks.iter().map(|c| c.chunk_index).collect();
        let msg_ids: Vec<i32> = chunks.iter().map(|c| c.telegram_message_id).collect();
        assert_eq!(indices, vec![0, 1, 2]);
        assert_eq!(msg_ids, vec![100, 101, 102]);

        let task = db.create_task(TaskKind::Download, file.id).await.unwrap();
        assert_eq!(task.kind_enum().unwrap(), TaskKind::Download);
        assert_eq!(task.state_enum().unwrap(), TaskState::Queued);
        assert_eq!(task.progress, 0.0);

        let running = db
            .update_task_progress(task.id, TaskState::Running, 0.5, None)
            .await
            .unwrap();
        assert_eq!(running.state_enum().unwrap(), TaskState::Running);
        assert_eq!(running.progress, 0.5);

        let failed = db
            .update_task_progress(task.id, TaskState::Failed, 0.5, Some("flood wait"))
            .await
            .unwrap();
        assert_eq!(failed.state_enum().unwrap(), TaskState::Failed);
        assert_eq!(failed.error.as_deref(), Some("flood wait"));

        // Invalid progress should be rejected cleanly.
        assert!(matches!(
            db.update_task_progress(task.id, TaskState::Running, 1.5, None)
                .await,
            Err(CoreError::InvalidConfig(_))
        ));
    }
}

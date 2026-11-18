-- Initial TeleDrive SQLite schema

CREATE TABLE IF NOT EXISTS folders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER NULL REFERENCES folders(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    UNIQUE(parent_id, name)
);

-- SQLite treats NULL as distinct in UNIQUE(parent_id, name), so enforce root-level uniqueness separately.
CREATE UNIQUE INDEX IF NOT EXISTS idx_folders_root_name
    ON folders(name)
    WHERE parent_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_folders_parent_id
    ON folders(parent_id);

CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    folder_id INTEGER NULL REFERENCES folders(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    size INTEGER NOT NULL CHECK (size >= 0),
    mime_type TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    is_encrypted INTEGER NOT NULL DEFAULT 0 CHECK (is_encrypted IN (0, 1)),
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_files_folder_id
    ON files(folder_id);

CREATE TABLE IF NOT EXISTS file_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL CHECK (chunk_index >= 0),
    telegram_message_id INTEGER NOT NULL,
    size INTEGER NOT NULL CHECK (size >= 0),
    UNIQUE(file_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_file_chunks_file_id
    ON file_chunks(file_id);

CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL CHECK (kind IN ('upload', 'download')),
    file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    state TEXT NOT NULL CHECK (state IN ('queued', 'running', 'paused', 'completed', 'failed')),
    progress REAL NOT NULL DEFAULT 0.0 CHECK (progress >= 0.0 AND progress <= 1.0),
    error TEXT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_file_state
    ON tasks(file_id, state);

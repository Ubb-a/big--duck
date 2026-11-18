use grammers_client::client::auth::AuthorizationError;
use grammers_client::types::PasswordToken;
use grammers_client::InvocationError;

/// Unified error type for `teledrive-core`.
#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    /// Local filesystem or network I/O failure.
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// Telegram MTProto RPC or transport error.
    #[error("Telegram API error: {0}")]
    Invocation(#[from] InvocationError),

    /// Failure while establishing an MTProto authorization key or requesting login code.
    #[error("Telegram authorization error: {0}")]
    Authorization(#[from] AuthorizationError),

    /// User sign-in failure (invalid code, invalid password, or unregistered account).
    #[error("Sign-in failed: {0}")]
    SignIn(String),

    /// Account has 2FA enabled and requires a cloud password to complete sign-in.
    #[error("Two-factor authentication password required")]
    PasswordRequired(Box<PasswordToken>),

    /// Operation requires an authenticated Telegram session.
    #[error("Telegram client is not authorized; please log in first")]
    NotAuthorized,

    /// Requested message ID could not be found in the target chat.
    #[error("Message {0} was not found")]
    MessageNotFound(i32),

    /// Message exists but contains no downloadable media attachment.
    #[error("Message {0} does not contain downloadable media")]
    MediaMissing(i32),

    /// Invalid client or path configuration provided by the caller.
    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    /// SQLite / SQLx query or connection error.
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    /// Embedded SQLite migration error.
    #[error("Database migration error: {0}")]
    Migration(#[from] sqlx::migrate::MigrateError),

    /// Requested record was not found in the local database.
    #[error("Record not found: {0}")]
    NotFound(String),

    /// Reassembled file SHA-256 digest does not match the expected metadata digest.
    #[error("SHA-256 checksum mismatch: expected {expected}, got {actual}")]
    ChecksumMismatch { expected: String, actual: String },

    /// Stored chunk metadata does not cover the expected file byte length cleanly.
    #[error("File {file_id} has incomplete chunks: expected {expected_bytes} bytes, found {actual_bytes} bytes")]
    IncompleteChunks {
        file_id: i64,
        expected_bytes: u64,
        actual_bytes: u64,
    },

    /// Telegram rate limit (`FLOOD_WAIT` or `SLOWMODE_WAIT`) requiring a cooldown before retry.
    #[error("Telegram rate limit (FLOOD_WAIT): retry after {seconds}s")]
    FloodWait { seconds: u64 },

    /// Background transfer was paused cleanly by user request.
    #[error("Transfer paused")]
    TaskPaused,

    /// AES-256-GCM encryption/decryption or Argon2 key derivation error.
    #[error("Encryption error: {0}")]
    Encryption(String),

    /// OS credential store (`keyring`) read/write error.
    #[error("Keyring error: {0}")]
    Keyring(String),
}

impl CoreError {
    /// Returns the required wait duration in seconds if this error represents a Telegram flood wait.
    pub fn flood_wait_seconds(&self) -> Option<u64> {
        match self {
            Self::FloodWait { seconds } => Some((*seconds).max(1)),
            Self::Invocation(inv) => flood_seconds_from_invocation(inv),
            Self::Io(io_err) => {
                if let Some(inv) = io_err
                    .get_ref()
                    .and_then(|err| err.downcast_ref::<InvocationError>())
                {
                    return flood_seconds_from_invocation(inv);
                }
                parse_flood_seconds_from_message(&io_err.to_string())
            }
            _ => None,
        }
    }
}

fn flood_seconds_from_invocation(inv: &InvocationError) -> Option<u64> {
    match inv {
        InvocationError::Rpc(rpc)
            if rpc.code == 420
                || rpc.name.starts_with("FLOOD_WAIT")
                || rpc.name.starts_with("SLOWMODE_WAIT") =>
        {
            Some(u64::from(rpc.value.unwrap_or(1).max(1)))
        }
        _ => None,
    }
}

fn parse_flood_seconds_from_message(msg: &str) -> Option<u64> {
    for prefix in ["FLOOD_WAIT_", "SLOWMODE_WAIT_"] {
        if let Some(idx) = msg.find(prefix) {
            let rest = &msg[idx + prefix.len()..];
            let digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
            if let Ok(secs) = digits.parse::<u64>() {
                return Some(secs.max(1));
            }
        }
    }
    if msg.contains("FLOOD_WAIT") || msg.contains("SLOWMODE_WAIT") {
        if let Some(idx) = msg.find("value: Some(") {
            let rest = &msg[idx + "value: Some(".len()..];
            let digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
            if let Ok(secs) = digits.parse::<u64>() {
                return Some(secs.max(1));
            }
        }
        return Some(1);
    }
    None
}

/// Convenience `Result` alias for `teledrive-core`.
pub type Result<T> = std::result::Result<T, CoreError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flood_wait_detection_works_across_variants() {
        let direct = CoreError::FloodWait { seconds: 12 };
        assert_eq!(direct.flood_wait_seconds(), Some(12));

        let io_wrapped = CoreError::Io(std::io::Error::other("rpc error 420: FLOOD_WAIT_17"));
        assert_eq!(io_wrapped.flood_wait_seconds(), Some(17));

        let normal_io = CoreError::Io(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            "file not found",
        ));
        assert_eq!(normal_io.flood_wait_seconds(), None);
    }
}

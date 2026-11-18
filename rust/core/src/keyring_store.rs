use std::path::Path;

#[cfg(not(any(target_os = "android", target_os = "ios")))]
use keyring::Entry;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
use tracing::{debug, info};

use crate::error::{CoreError, Result};

#[cfg(not(any(target_os = "android", target_os = "ios")))]
const SERVICE_NAME: &str = "teledrive";

/// Derives a stable OS keyring account key from the configured session path.
pub fn account_key_from_path(session_path: &Path) -> String {
    session_path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .filter(|name| !name.is_empty())
        .unwrap_or_else(|| "default".to_string())
}

/// Loads raw serialized `grammers` session bytes from the OS credential store, if present.
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub fn load_session_from_keyring(account_key: &str) -> Result<Option<Vec<u8>>> {
    let entry = Entry::new(SERVICE_NAME, account_key)
        .map_err(|err| CoreError::Keyring(format!("failed to open keyring entry: {err}")))?;

    match entry.get_secret() {
        Ok(bytes) => {
            debug!(
                account_key,
                bytes = bytes.len(),
                "Loaded session from OS keyring"
            );
            Ok(Some(bytes))
        }
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(err) => Err(CoreError::Keyring(format!(
            "failed to read session from keyring: {err}"
        ))),
    }
}

/// Mobile targets use app-private storage; return `CoreError::Keyring` so callers use `teledrive.session`.
#[cfg(any(target_os = "android", target_os = "ios"))]
pub fn load_session_from_keyring(_account_key: &str) -> Result<Option<Vec<u8>>> {
    Err(CoreError::Keyring(
        "OS keyring backend is bypassed on mobile; using app-private session file".to_string(),
    ))
}

/// Saves raw serialized `grammers` session bytes into the OS credential store.
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub fn save_session_to_keyring(account_key: &str, data: &[u8]) -> Result<()> {
    let entry = Entry::new(SERVICE_NAME, account_key)
        .map_err(|err| CoreError::Keyring(format!("failed to open keyring entry: {err}")))?;

    entry
        .set_secret(data)
        .map_err(|err| CoreError::Keyring(format!("failed to write session to keyring: {err}")))?;
    debug!(
        account_key,
        bytes = data.len(),
        "Saved session to OS keyring"
    );
    Ok(())
}

/// Mobile targets use app-private storage; return `CoreError::Keyring` so callers use `teledrive.session`.
#[cfg(any(target_os = "android", target_os = "ios"))]
pub fn save_session_to_keyring(_account_key: &str, _data: &[u8]) -> Result<()> {
    Err(CoreError::Keyring(
        "OS keyring backend is bypassed on mobile; using app-private session file".to_string(),
    ))
}

/// Deletes the stored session entry from the OS credential store if it exists.
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub fn delete_session_from_keyring(account_key: &str) -> Result<()> {
    let entry = Entry::new(SERVICE_NAME, account_key)
        .map_err(|err| CoreError::Keyring(format!("failed to open keyring entry: {err}")))?;

    match entry.delete_credential() {
        Ok(()) => {
            info!(account_key, "Removed session from OS keyring");
            Ok(())
        }
        Err(keyring::Error::NoEntry) => Ok(()),
        Err(err) => Err(CoreError::Keyring(format!(
            "failed to delete session from keyring: {err}"
        ))),
    }
}

/// Mobile targets delete the app-private session file directly.
#[cfg(any(target_os = "android", target_os = "ios"))]
pub fn delete_session_from_keyring(_account_key: &str) -> Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn account_key_derives_file_name_or_default() {
        assert_eq!(
            account_key_from_path(Path::new("C:\\data\\teledrive.session")),
            "teledrive.session"
        );
        assert_eq!(account_key_from_path(Path::new("")), "default");
    }

    #[test]
    fn keyring_roundtrip_isolated_test_entry() {
        let test_key = format!("teledrive_unit_test_{}", std::process::id());
        let payload = b"teledrive-session-bytes-test";

        match save_session_to_keyring(&test_key, payload) {
            Ok(()) => {
                let loaded = load_session_from_keyring(&test_key).unwrap();
                assert_eq!(loaded.as_deref(), Some(payload.as_slice()));
                delete_session_from_keyring(&test_key).unwrap();
                assert!(load_session_from_keyring(&test_key).unwrap().is_none());
            }
            Err(CoreError::Keyring(_)) => {
                // Skip gracefully on headless environments without an active OS credential daemon.
            }
            Err(other) => panic!("unexpected error: {other}"),
        }
    }
}

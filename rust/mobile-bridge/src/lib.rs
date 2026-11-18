mod protocol;

use std::collections::VecDeque;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::thread;

use teledrive_core::{spawn_core_worker, CoreCommand, DEFAULT_CHUNK_SIZE};
use tokio::sync::mpsc::UnboundedSender;

use crate::protocol::{SidecarCommand, SidecarEvent};

pub struct BigDuckRuntime {
    cmd_tx: UnboundedSender<CoreCommand>,
    events: Arc<Mutex<VecDeque<String>>>,
}

impl BigDuckRuntime {
    pub fn start(db_path: PathBuf) -> Self {
        let worker = spawn_core_worker(db_path.clone(), None);
        let events = Arc::new(Mutex::new(VecDeque::with_capacity(64)));

        let ready_event = SidecarEvent::Ready {
            db_path: db_path.display().to_string(),
            default_chunk_size: DEFAULT_CHUNK_SIZE,
            has_env_config: false,
            api_id: None,
            session_path: None,
        };
        if let Ok(ready_json) = serde_json::to_string(&ready_event) {
            if let Ok(mut guard) = events.lock() {
                guard.push_back(ready_json);
            }
        }

        let events_clone = Arc::clone(&events);
        let mut event_rx = worker.event_rx;
        thread::spawn(move || {
            while let Some(ev) = event_rx.blocking_recv() {
                if let Ok(json) = serde_json::to_string(&SidecarEvent::from(ev)) {
                    if let Ok(mut guard) = events_clone.lock() {
                        guard.push_back(json);
                    }
                }
            }
        });

        Self {
            cmd_tx: worker.cmd_tx,
            events,
        }
    }

    pub fn send_json(&self, json: &str) -> Result<(), String> {
        let cmd: SidecarCommand =
            serde_json::from_str(json).map_err(|err| format!("Invalid command JSON: {err}"))?;
        self.cmd_tx
            .send(CoreCommand::from(cmd))
            .map_err(|err| format!("Failed to send command: {err}"))
    }

    pub fn poll_event_json(&self) -> Option<String> {
        self.events.lock().ok()?.pop_front()
    }
}

/// Starts a BIG DUCK mobile core runtime backed by `db_path_ptr`.
///
/// # Safety
/// `db_path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn bigduck_start(db_path_ptr: *const c_char) -> *mut BigDuckRuntime {
    if db_path_ptr.is_null() {
        return std::ptr::null_mut();
    }
    let c_str = unsafe { CStr::from_ptr(db_path_ptr) };
    let Ok(path_str) = c_str.to_str() else {
        return std::ptr::null_mut();
    };
    let runtime = BigDuckRuntime::start(PathBuf::from(path_str));
    Box::into_raw(Box::new(runtime))
}

/// Sends a JSON command to the BIG DUCK core runtime. Returns `0` on success.
///
/// # Safety
/// `runtime` must be a valid pointer from `bigduck_start`, and `cmd_json_ptr` a valid C string.
#[no_mangle]
pub unsafe extern "C" fn bigduck_send_command(
    runtime: *mut BigDuckRuntime,
    cmd_json_ptr: *const c_char,
) -> i32 {
    if runtime.is_null() || cmd_json_ptr.is_null() {
        return -1;
    }
    let rt = unsafe { &*runtime };
    let c_str = unsafe { CStr::from_ptr(cmd_json_ptr) };
    let Ok(cmd_str) = c_str.to_str() else {
        return -2;
    };
    match rt.send_json(cmd_str) {
        Ok(()) => 0,
        Err(_) => -3,
    }
}

/// Polls the next JSON event string from the queue, or returns NULL if empty.
/// Caller must free non-null strings via `bigduck_free_string`.
///
/// # Safety
/// `runtime` must be a valid pointer from `bigduck_start`.
#[no_mangle]
pub unsafe extern "C" fn bigduck_poll_event(runtime: *mut BigDuckRuntime) -> *mut c_char {
    if runtime.is_null() {
        return std::ptr::null_mut();
    }
    let rt = unsafe { &*runtime };
    match rt.poll_event_json() {
        Some(json) => CString::new(json)
            .map(CString::into_raw)
            .unwrap_or(std::ptr::null_mut()),
        None => std::ptr::null_mut(),
    }
}

/// Frees a C string previously returned by `bigduck_poll_event`.
///
/// # Safety
/// `ptr` must have been returned by `bigduck_poll_event` and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn bigduck_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(unsafe { CString::from_raw(ptr) });
    }
}

/// Shuts down and frees the BIG DUCK core runtime.
///
/// # Safety
/// `runtime` must be a valid pointer from `bigduck_start` and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn bigduck_stop(runtime: *mut BigDuckRuntime) {
    if !runtime.is_null() {
        let rt = unsafe { Box::from_raw(runtime) };
        let _ = rt.cmd_tx.send(CoreCommand::Shutdown);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_mobile_bridge_commands() {
        let cmd: SidecarCommand = serde_json::from_str(
            r#"{"type":"connect","api_id":123,"api_hash":"abc","session_path":"bd.session"}"#,
        )
        .expect("valid connect json");
        match CoreCommand::from(cmd) {
            CoreCommand::Connect {
                api_id,
                api_hash,
                session_path,
            } => {
                assert_eq!(api_id, 123);
                assert_eq!(api_hash, "abc");
                assert_eq!(session_path, PathBuf::from("bd.session"));
            }
            _ => panic!("expected Connect"),
        }
    }
}

use std::collections::{HashMap, HashSet};
use std::io::{Cursor, Write};
use std::ops::ControlFlow;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicI64, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, RwLock};
use std::time::Duration;

use futures_util::stream::{FuturesUnordered, StreamExt};
use grammers_client::grammers_tl_types as tl;
use grammers_client::types::media::Uploaded;
use grammers_client::types::{Chat, Downloadable, LoginToken, PackedChat, PasswordToken, User};
use grammers_client::{
    Client, Config, InitParams, InputMessage, ReconnectionPolicy, SignInError,
};
use grammers_session::Session;
use rand::rngs::OsRng;
use rand::RngCore;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWriteExt};
use tracing::{debug, info, warn};

use crate::error::{CoreError, Result};
use crate::keyring_store::{
    account_key_from_path, delete_session_from_keyring, load_session_from_keyring,
    save_session_to_keyring,
};

/// Caption prefix used to tag encrypted SQLite index backup documents in Saved Messages.
pub const BACKUP_CAPTION_PREFIX: &str = "[TeleDrive Index Backup]";

/// File name assigned to uploaded encrypted SQLite index backups.
pub const BACKUP_FILE_NAME: &str = "teledrive_index.tdrvbak";

/// Configuration needed to establish a Telegram MTProto session.
#[derive(Debug, Clone)]
pub struct TelegramConfig {
    /// Telegram developer API ID from <https://my.telegram.org>.
    pub api_id: i32,
    /// Telegram developer API hash from <https://my.telegram.org>.
    pub api_hash: String,
    /// Session identifier path (mapped to an OS keyring entry; legacy disk files are migrated).
    pub session_path: PathBuf,
}

impl TelegramConfig {
    /// Validates configuration invariants before attempting network calls.
    pub fn validate(&self) -> Result<()> {
        if self.api_id <= 0 {
            return Err(CoreError::InvalidConfig(
                "api_id must be a positive integer".to_string(),
            ));
        }
        if self.api_hash.trim().is_empty() {
            return Err(CoreError::InvalidConfig(
                "api_hash must not be empty".to_string(),
            ));
        }
        if self.session_path.as_os_str().is_empty() {
            return Err(CoreError::InvalidConfig(
                "session_path must not be empty".to_string(),
            ));
        }
        Ok(())
    }
}

/// A Telegram Group or Channel that can be selected as the cloud storage destination.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct StorageChat {
    pub id: i64,
    pub title: String,
    pub kind: String,
    pub is_creator: bool,
    pub is_private: bool,
    pub member_count: Option<i32>,
}

struct MobileReconnectPolicy;

impl ReconnectionPolicy for MobileReconnectPolicy {
    fn should_retry(&self, attempts: usize) -> ControlFlow<(), Duration> {
        match attempts {
            0..=1 => ControlFlow::Continue(Duration::from_millis(250)),
            2..=4 => ControlFlow::Continue(Duration::from_millis(900)),
            5..=8 => ControlFlow::Continue(Duration::from_secs(2)),
            _ => ControlFlow::Break(()),
        }
    }
}

static MOBILE_RECONNECT_POLICY: MobileReconnectPolicy = MobileReconnectPolicy;

macro_rules! with_reconnect {
    ($self:ident, |$client:ident| $body:block) => {{
        let mut _attempt = 0u8;
        loop {
            let _gen = $self.connect_generation.load(Ordering::Acquire);
            let $client = $self.client_handle();
            let _res: Result<_> = async { $body }.await;
            match _res {
                Ok(val) => break Ok(val),
                Err(err) if _attempt == 0 && err.is_transient_network() => {
                    _attempt = 1;
                    warn!(error = %err, "Telegram socket disconnected; reconnecting and retrying");
                    $self.reconnect_if_stale(_gen).await?;
                }
                Err(err) => break Err(err),
            }
        }
    }};
}

const TG_UPLOAD_PART_SIZE: usize = 512 * 1024;
const TG_BIG_FILE_THRESHOLD: usize = 10 * 1024 * 1024;
const UPLOAD_POOL_CONNECTIONS: usize = 4;
const MAX_INFLIGHT_UPLOAD_PARTS: usize = 8;

/// High-level wrapper around `grammers_client::Client` for TeleDrive operations.
#[derive(Clone)]
pub struct TelegramClient {
    config: TelegramConfig,
    client: Arc<RwLock<Client>>,
    account_key: String,
    session_path: PathBuf,
    target_chat_id: Arc<AtomicI64>,
    packed_chats: Arc<Mutex<HashMap<i64, PackedChat>>>,
    connect_generation: Arc<AtomicU64>,
    reconnect_lock: Arc<tokio::sync::Mutex<()>>,
    upload_pool: Arc<tokio::sync::Mutex<Vec<Client>>>,
    upload_pool_rr: Arc<AtomicUsize>,
    upload_part_sem: Arc<tokio::sync::Semaphore>,
}

async fn connect_raw_client(config: &TelegramConfig, account_key: &str) -> Result<Client> {
    let session = load_or_migrate_session(account_key, &config.session_path)?;
    Client::connect(Config {
        session,
        api_id: config.api_id,
        api_hash: config.api_hash.clone(),
        params: InitParams {
            reconnection_policy: &MOBILE_RECONNECT_POLICY,
            ..Default::default()
        },
    })
    .await
    .map_err(CoreError::from)
}

impl TelegramClient {
    /// Connects to Telegram, loading the session from the OS keyring (or migrating a legacy
    /// plaintext `.session` file into the keyring and removing it from disk).
    pub async fn connect(config: TelegramConfig) -> Result<Self> {
        config.validate()?;

        let account_key = account_key_from_path(&config.session_path);
        let client = connect_raw_client(&config, &account_key).await?;

        let wrapper = Self {
            session_path: config.session_path.clone(),
            config,
            client: Arc::new(RwLock::new(client)),
            account_key,
            target_chat_id: Arc::new(AtomicI64::new(0)),
            packed_chats: Arc::new(Mutex::new(HashMap::new())),
            connect_generation: Arc::new(AtomicU64::new(0)),
            reconnect_lock: Arc::new(tokio::sync::Mutex::new(())),
            upload_pool: Arc::new(tokio::sync::Mutex::new(Vec::new())),
            upload_pool_rr: Arc::new(AtomicUsize::new(0)),
            upload_part_sem: Arc::new(tokio::sync::Semaphore::new(MAX_INFLIGHT_UPLOAD_PARTS)),
        };
        // Persist newly generated DC auth keys immediately into the OS keyring (or app-private file on mobile).
        wrapper.save_session()?;
        Ok(wrapper)
    }

    fn client_handle(&self) -> Client {
        self.client.read().unwrap_or_else(|e| e.into_inner()).clone()
    }

    /// Re-establishes a fresh Telegram MTProto TCP socket if `failed_gen` is still current.
    pub async fn reconnect_if_stale(&self, failed_gen: u64) -> Result<()> {
        let _guard = self.reconnect_lock.lock().await;
        if self.connect_generation.load(Ordering::Acquire) != failed_gen {
            return Ok(());
        }
        let _ = self.save_session();
        let fresh = connect_raw_client(&self.config, &self.account_key).await?;
        {
            let mut guard = self.client.write().unwrap_or_else(|e| e.into_inner());
            *guard = fresh;
        }
        self.upload_pool.lock().await.clear();
        self.connect_generation.fetch_add(1, Ordering::Release);
        let _ = self.save_session();
        info!("Re-established Telegram MTProto session socket");
        Ok(())
    }

    async fn connect_upload_worker_client(&self) -> Result<Client> {
        let bytes = self.client_handle().session().save();
        let session = Session::load(&bytes).map_err(|err| {
            CoreError::Keyring(format!("failed to clone active Telegram session: {err}"))
        })?;
        Client::connect(Config {
            session,
            api_id: self.config.api_id,
            api_hash: self.config.api_hash.clone(),
            params: InitParams {
                reconnection_policy: &MOBILE_RECONNECT_POLICY,
                update_queue_limit: Some(0),
                catch_up: false,
                ..Default::default()
            },
        })
        .await
        .map_err(CoreError::from)
    }

    async fn acquire_upload_clients(&self, desired: usize) -> Vec<Client> {
        let mut pool = self.upload_pool.lock().await;
        let needed = desired.saturating_sub(pool.len());
        if needed > 0 {
            let mut futs = FuturesUnordered::new();
            for _ in 0..needed {
                futs.push(self.connect_upload_worker_client());
            }
            while let Some(res) = futs.next().await {
                match res {
                    Ok(client) => pool.push(client),
                    Err(err) => {
                        debug!(error = %err, "Failed to open pooled MTProto upload socket");
                    }
                }
            }
        }
        if pool.is_empty() {
            vec![self.client_handle()]
        } else {
            pool.iter().take(desired).cloned().collect()
        }
    }

    async fn replace_upload_worker(&self, slot: usize) -> Result<Client> {
        let fresh = self.connect_upload_worker_client().await?;
        let mut pool = self.upload_pool.lock().await;
        if slot < pool.len() {
            pool[slot] = fresh.clone();
        }
        Ok(fresh)
    }

    /// Returns the OS keyring account key used to store this session.
    pub fn account_key(&self) -> &str {
        &self.account_key
    }

    /// Returns `true` if the current session is already authenticated as a Telegram user.
    pub async fn is_authorized(&self) -> Result<bool> {
        with_reconnect!(self, |client| { Ok(client.is_authorized().await?) })
    }

    /// Requests a Telegram login code for the given phone number (international format).
    pub async fn request_login_code(&self, phone: &str) -> Result<LoginToken> {
        let trimmed = phone.trim();
        if trimmed.is_empty() {
            return Err(CoreError::InvalidConfig(
                "phone number must not be empty".to_string(),
            ));
        }
        info!("Requesting Telegram login code");
        with_reconnect!(self, |client| {
            Ok(client.request_login_code(trimmed).await?)
        })
    }

    /// Completes login with the received OTP code, or returns `CoreError::PasswordRequired`
    /// if 2FA is enabled on the account.
    pub async fn sign_in(&self, token: &LoginToken, code: &str) -> Result<User> {
        let user = self
            .client_handle()
            .sign_in(token, code.trim())
            .await
            .map_err(map_sign_in_error)?;
        self.save_session()?;
        info!(user_id = user.id(), "Signed in to Telegram");
        Ok(user)
    }

    /// Completes 2FA verification using the `PasswordToken` returned in `CoreError::PasswordRequired`.
    pub async fn check_password(&self, token: PasswordToken, password: &str) -> Result<User> {
        let user = self
            .client_handle()
            .check_password(token, password.as_bytes())
            .await
            .map_err(map_sign_in_error)?;
        self.save_session()?;
        info!(
            user_id = user.id(),
            "2FA verified and signed in to Telegram"
        );
        Ok(user)
    }

    /// Persists the current MTProto session state securely inside the OS keyring,
    /// falling back to the app-private `session_path` file when no OS keyring backend exists (e.g. Android).
    pub fn save_session(&self) -> Result<()> {
        let bytes = self.client_handle().session().save();
        match save_session_to_keyring(&self.account_key, &bytes) {
            Ok(()) => {
                debug!(account_key = %self.account_key, "Saved Telegram session to keyring");
                Ok(())
            }
            Err(CoreError::Keyring(err)) => {
                debug!(
                    path = %self.session_path.display(),
                    reason = %err,
                    "OS keyring unavailable; persisting session to app-private file"
                );
                write_session_file_atomic(&self.session_path, &bytes)?;
                Ok(())
            }
            Err(other) => Err(other),
        }
    }

    /// Removes any persisted Telegram session from keyring and app-private storage.
    pub fn delete_stored_session(&self) {
        if let Ok(mut pool) = self.upload_pool.try_lock() {
            pool.clear();
        }
        let _ = delete_session_from_keyring(&self.account_key);
        let _ = std::fs::remove_file(&self.session_path);
        let tmp_path = self.session_path.with_extension("session.tmp");
        let _ = std::fs::remove_file(tmp_path);
    }

    /// Returns the currently authenticated Telegram user.
    pub async fn get_me(&self) -> Result<User> {
        let user = with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            Ok(client.get_me().await?)
        })?;
        let _ = self.save_session();
        Ok(user)
    }

    /// Uploads a local file as a document to Saved Messages and returns the resulting message ID.
    pub async fn upload_file(&self, path: &Path, caption: &str) -> Result<i32> {
        if !path.is_file() || path.file_name().is_none() {
            return Err(CoreError::InvalidConfig(format!(
                "path '{}' must point to an existing file",
                path.display()
            )));
        }

        info!(path = %path.display(), "Uploading file to Telegram");
        with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            let uploaded = client.upload_file(path).await?;
            self.send_message_on(&client, InputMessage::text(caption).file(uploaded))
                .await
        })
    }

    /// Uploads an in-memory byte buffer as a document and returns the message ID.
    pub async fn upload_bytes(
        &self,
        data: Vec<u8>,
        file_name: String,
        caption: &str,
    ) -> Result<i32> {
        self.upload_bytes_with_progress(data, file_name, caption, |_| {})
            .await
    }

    /// Uploads an in-memory byte buffer while reporting incremental uploaded byte counts.
    pub async fn upload_bytes_with_progress<F>(
        &self,
        data: Vec<u8>,
        file_name: String,
        caption: &str,
        on_progress: F,
    ) -> Result<i32>
    where
        F: Fn(u64) + Send + Sync,
    {
        let size = data.len();
        if size == 0 {
            return Err(CoreError::InvalidConfig(
                "cannot upload a 0-byte stream to Telegram".to_string(),
            ));
        }

        info!(file_name = %file_name, size, "Uploading chunk bytes to Telegram");
        let mut cursor = Cursor::new(data.as_slice());
        self.upload_stream_with_progress(&mut cursor, size, file_name, caption, on_progress)
            .await
    }

    /// Uploads a stream of known byte length as a document and returns the message ID.
    pub async fn upload_stream<S: AsyncRead + Unpin + Send>(
        &self,
        stream: &mut S,
        size: usize,
        file_name: String,
        caption: &str,
    ) -> Result<i32> {
        self.upload_stream_with_progress(stream, size, file_name, caption, |_| {})
            .await
    }

    /// Uploads a stream over pooled MTProto connections in parallel 512 KiB parts and reports live byte progress.
    pub async fn upload_stream_with_progress<S, F>(
        &self,
        stream: &mut S,
        size: usize,
        file_name: String,
        caption: &str,
        on_progress: F,
    ) -> Result<i32>
    where
        S: AsyncRead + Unpin + Send,
        F: Fn(u64) + Send + Sync,
    {
        if size == 0 {
            return Err(CoreError::InvalidConfig(
                "cannot upload a 0-byte stream to Telegram".to_string(),
            ));
        }

        with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            Ok(())
        })?;

        let name = if file_name.is_empty() {
            "a".to_string()
        } else {
            file_name
        };
        let file_id = OsRng.next_u64() as i64;
        let total_parts_usize = size.div_ceil(TG_UPLOAD_PART_SIZE);
        let total_parts = i32::try_from(total_parts_usize).map_err(|_| {
            CoreError::InvalidConfig(format!("chunk part count {total_parts_usize} exceeds i32::MAX"))
        })?;
        let is_big = size > TG_BIG_FILE_THRESHOLD;
        let conn_count = total_parts_usize.clamp(1, UPLOAD_POOL_CONNECTIONS);
        let worker_count = total_parts_usize.clamp(1, MAX_INFLIGHT_UPLOAD_PARTS);

        let clients_init = if conn_count <= 1 {
            vec![self.client_handle()]
        } else {
            self.acquire_upload_clients(conn_count).await
        };
        let clients_len = clients_init.len().max(1);
        let clients = RwLock::new(clients_init);

        info!(
            file_name = %name,
            size,
            total_parts,
            connections = clients_len,
            workers = worker_count,
            "Uploading stream with parallel MTProto part workers"
        );

        let reader_state = tokio::sync::Mutex::new((0i32, stream, size));
        let bytes_done = AtomicU64::new(0);
        let me = self;
        let clients_ref = &clients;
        let reader_ref = &reader_state;
        let done_ref = &bytes_done;
        let progress_cb = &on_progress;

        let mut tasks = FuturesUnordered::new();
        for _ in 0..worker_count {
            tasks.push(async move {
                loop {
                    let (part_idx, part_bytes) = {
                        let mut guard = reader_ref.lock().await;
                        if guard.0 >= total_parts || guard.2 == 0 {
                            break;
                        }
                        let part_len = guard.2.min(TG_UPLOAD_PART_SIZE);
                        let mut buf = vec![0u8; part_len];
                        guard.1.read_exact(&mut buf).await?;
                        let idx = guard.0;
                        guard.0 += 1;
                        guard.2 -= part_len;
                        (idx, buf)
                    };

                    let part_len = part_bytes.len() as u64;
                    let _permit = me.upload_part_sem.acquire().await.map_err(|_| {
                        CoreError::InvalidConfig("upload part semaphore closed".to_string())
                    })?;

                    let mut part_attempt = 0u8;
                    loop {
                        let slot = me.upload_pool_rr.fetch_add(1, Ordering::Relaxed) % clients_len;
                        let gen = me.connect_generation.load(Ordering::Acquire);
                        let handle = {
                            let guard = clients_ref.read().unwrap_or_else(|e| e.into_inner());
                            guard[slot].clone()
                        };

                        let rpc_res = if is_big {
                            handle
                                .invoke(&tl::functions::upload::SaveBigFilePart {
                                    file_id,
                                    file_part: part_idx,
                                    file_total_parts: total_parts,
                                    bytes: part_bytes.clone(),
                                })
                                .await
                        } else {
                            handle
                                .invoke(&tl::functions::upload::SaveFilePart {
                                    file_id,
                                    file_part: part_idx,
                                    bytes: part_bytes.clone(),
                                })
                                .await
                        };

                        match rpc_res {
                            Ok(true) => break,
                            Ok(false) => {
                                return Err(CoreError::InvalidConfig(
                                    "Telegram server rejected uploaded file part".to_string(),
                                ));
                            }
                            Err(inv_err) => {
                                let core_err = CoreError::from(inv_err);
                                if let Some(wait_secs) = core_err.flood_wait_seconds() {
                                    if wait_secs <= 60 && part_attempt < 3 {
                                        part_attempt += 1;
                                        tokio::time::sleep(Duration::from_secs(wait_secs)).await;
                                        continue;
                                    }
                                }
                                if core_err.is_transient_network() && part_attempt < 3 {
                                    part_attempt += 1;
                                    warn!(
                                        part = part_idx,
                                        attempt = part_attempt,
                                        error = %core_err,
                                        "Telegram upload worker socket disconnected; reconnecting worker for part retry"
                                    );
                                    if conn_count <= 1 {
                                        let _ = me.reconnect_if_stale(gen).await;
                                        let fresh = me.client_handle();
                                        let mut guard = clients_ref
                                            .write()
                                            .unwrap_or_else(|e| e.into_inner());
                                        guard[0] = fresh;
                                    } else if let Ok(fresh) = me.replace_upload_worker(slot).await {
                                        let mut guard = clients_ref
                                            .write()
                                            .unwrap_or_else(|e| e.into_inner());
                                        if slot < guard.len() {
                                            guard[slot] = fresh;
                                        }
                                    }
                                    tokio::time::sleep(Duration::from_millis(
                                        250 * u64::from(part_attempt),
                                    ))
                                    .await;
                                    continue;
                                }
                                return Err(core_err);
                            }
                        }
                    }

                    let done = done_ref.fetch_add(part_len, Ordering::Relaxed) + part_len;
                    progress_cb(done);
                }
                Ok::<(), CoreError>(())
            });
        }

        while let Some(res) = tasks.next().await {
            res?;
        }

        let raw: tl::enums::InputFile = if is_big {
            tl::types::InputFileBig {
                id: file_id,
                parts: total_parts,
                name,
            }
            .into()
        } else {
            tl::types::InputFile {
                id: file_id,
                parts: total_parts,
                name,
                md5_checksum: String::new(),
            }
            .into()
        };
        let uploaded = Uploaded::from_raw(raw);

        with_reconnect!(self, |client| {
            self.send_message_on(&client, InputMessage::text(caption).file(uploaded.clone()))
                .await
        })
    }

    /// Selects a Telegram Group/Channel ID (`Some(id)`) or Saved Messages (`None`).
    pub fn set_target_chat_id(&self, chat_id: Option<i64>) {
        self.target_chat_id
            .store(chat_id.unwrap_or(0), Ordering::Relaxed);
    }

    /// Returns the currently selected storage chat ID, or `None` for Saved Messages.
    pub fn target_chat_id(&self) -> Option<i64> {
        let id = self.target_chat_id.load(Ordering::Relaxed);
        if id == 0 {
            None
        } else {
            Some(id)
        }
    }

    /// Lists only Telegram groups and channels where the user is the owner/creator
    /// or has active admin posting rights (never random public subscriptions).
    pub async fn list_storage_chats(&self) -> Result<Vec<StorageChat>> {
        with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            let mut dialogs = client.iter_dialogs();
            let mut chats = Vec::new();
            let mut seen = HashSet::new();
            let mut scanned = 0usize;
            while let Some(dialog) = dialogs.next().await? {
                scanned += 1;
                let chat = dialog.chat();
                if let Some(sc) = storage_chat_from_dialog_chat(chat) {
                    if seen.insert(sc.id) {
                        if let Ok(mut cache) = self.packed_chats.lock() {
                            cache.insert(sc.id, chat.pack());
                        }
                        chats.push(sc);
                    }
                }
                if scanned >= 400 || chats.len() >= 150 {
                    break;
                }
            }
            chats.sort_by_key(|c| (!c.is_creator, !c.is_private, c.title.to_lowercase()));
            Ok(chats)
        })
    }

    /// Creates a new private Telegram supergroup or broadcast channel dedicated to BIG DUCK storage.
    pub async fn create_storage_chat(&self, title: &str, is_megagroup: bool) -> Result<StorageChat> {
        let trimmed = title.trim();
        if trimmed.is_empty() {
            return Err(CoreError::InvalidConfig(
                "vault name must not be empty".to_string(),
            ));
        }
        let updates = with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            Ok(client
                .invoke(&tl::functions::channels::CreateChannel {
                    broadcast: !is_megagroup,
                    megagroup: is_megagroup,
                    for_import: false,
                    forum: false,
                    title: trimmed.to_string(),
                    about: "BIG DUCK Encrypted Vault".to_string(),
                    geo_point: None,
                    address: None,
                    ttl_period: None,
                })
                .await?)
        })?;

        let raw_chats = match updates {
            tl::enums::Updates::Updates(u) => u.chats,
            tl::enums::Updates::Combined(u) => u.chats,
            _ => Vec::new(),
        };

        let Some(raw_chat) = raw_chats.into_iter().find(|c| {
            matches!(
                c,
                tl::enums::Chat::Channel(_) | tl::enums::Chat::Chat(_)
            )
        }) else {
            return Err(CoreError::InvalidConfig(
                "Telegram did not return the created vault chat".to_string(),
            ));
        };

        let chat = Chat::from_raw(raw_chat);
        let id = chat.id();
        let name = chat.name().to_string();
        let packed = chat.pack();
        if let Ok(mut cache) = self.packed_chats.lock() {
            cache.insert(id, packed);
        }
        let _ = self.save_session();
        Ok(StorageChat {
            id,
            title: name,
            kind: if is_megagroup {
                "group".to_string()
            } else {
                "channel".to_string()
            },
            is_creator: true,
            is_private: true,
            member_count: Some(1),
        })
    }

    async fn resolve_target_chat_on(&self, client: &Client) -> Result<PackedChat> {
        if let Some(target_id) = self.target_chat_id() {
            if let Ok(cache) = self.packed_chats.lock() {
                if let Some(packed) = cache.get(&target_id).copied() {
                    return Ok(packed);
                }
            }
            let mut dialogs = client.iter_dialogs();
            while let Some(dialog) = dialogs.next().await? {
                let chat = dialog.chat();
                if chat.id() == target_id {
                    let packed = chat.pack();
                    if let Ok(mut cache) = self.packed_chats.lock() {
                        cache.insert(target_id, packed);
                    }
                    return Ok(packed);
                }
            }
            return Err(CoreError::InvalidConfig(format!(
                "Target Telegram group/channel {target_id} was not found in dialogs"
            )));
        }
        Ok(client.get_me().await?.pack())
    }

    async fn send_message_on(&self, client: &Client, input: InputMessage) -> Result<i32> {
        let target = self.resolve_target_chat_on(client).await?;
        let message = client.send_message(target, input).await?;

        let msg_id = message.id();
        self.save_session()?;
        info!(
            message_id = msg_id,
            target_chat_id = ?self.target_chat_id(),
            "File uploaded and sent to Telegram storage chat"
        );
        Ok(msg_id)
    }

    /// Downloads the media attached to `message_id` from the active storage chat into `dest`.
    pub async fn download_file(&self, message_id: i32, dest: &Path) -> Result<()> {
        self.download_file_with_progress(message_id, dest, |_| {})
            .await
    }

    /// Downloads the media attached to `message_id` while reporting downloaded byte counts.
    pub async fn download_file_with_progress<F>(
        &self,
        message_id: i32,
        dest: &Path,
        on_progress: F,
    ) -> Result<()>
    where
        F: Fn(u64) + Send + Sync,
    {
        if let Some(parent) = dest.parent().filter(|p| !p.as_os_str().is_empty()) {
            tokio::fs::create_dir_all(parent).await?;
        }

        with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            let target = self.resolve_target_chat_on(&client).await?;
            let messages = client.get_messages_by_id(target, &[message_id]).await?;
            let message = messages
                .into_iter()
                .next()
                .flatten()
                .ok_or(CoreError::MessageNotFound(message_id))?;

            let media = message.media().ok_or(CoreError::MediaMissing(message_id))?;

            info!(message_id, dest = %dest.display(), "Downloading file from Telegram");
            let downloadable = Downloadable::Media(media);
            if downloadable.to_raw_input_location().is_some() {
                let mut download = client.iter_download(&downloadable);
                let mut out = tokio::fs::File::create(dest).await?;
                let mut done = 0u64;
                on_progress(0);
                while let Some(chunk) = download.next().await? {
                    out.write_all(&chunk).await?;
                    done += chunk.len() as u64;
                    on_progress(done);
                }
                out.flush().await?;
                out.sync_all().await?;
            } else {
                client.download_media(&downloadable, dest).await?;
            }
            info!(message_id, dest = %dest.display(), "Download completed");
            Ok(())
        })
    }

    /// Searches recent storage chat history for the newest encrypted index backup document.
    pub async fn find_latest_backup_message_id(&self) -> Result<Option<i32>> {
        with_reconnect!(self, |client| {
            Self::ensure_authorized_on(&client).await?;
            let target = self.resolve_target_chat_on(&client).await?;
            let mut messages = client.iter_messages(target).limit(200);

            while let Some(message) = messages.next().await? {
                if message.text().starts_with(BACKUP_CAPTION_PREFIX) && message.media().is_some() {
                    return Ok(Some(message.id()));
                }
            }

            Ok(None)
        })
    }

    async fn ensure_authorized_on(client: &Client) -> Result<()> {
        if !client.is_authorized().await? {
            return Err(CoreError::NotAuthorized);
        }
        Ok(())
    }
}

fn write_session_file_atomic(path: &Path, bytes: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent().filter(|p| !p.as_os_str().is_empty()) {
        std::fs::create_dir_all(parent)?;
    }
    let tmp_path = path.with_extension("session.tmp");
    {
        let mut file = std::fs::File::create(&tmp_path)?;
        file.write_all(bytes)?;
        file.sync_all()?;
    }
    std::fs::rename(&tmp_path, path)?;
    Ok(())
}

fn load_or_migrate_session(account_key: &str, legacy_path: &Path) -> Result<Session> {
    match load_session_from_keyring(account_key) {
        Ok(Some(bytes)) => {
            debug!(account_key, "Using Telegram session stored in OS keyring");
            return Session::load(&bytes).map_err(|err| {
                CoreError::Keyring(format!("stored session in keyring is corrupted: {err}"))
            });
        }
        Ok(None) => {}
        Err(CoreError::Keyring(err)) => {
            debug!(
                path = %legacy_path.display(),
                reason = %err,
                "OS keyring unavailable; loading session from app-private file"
            );
            if legacy_path.is_file() {
                let bytes = std::fs::read(legacy_path)?;
                return Session::load(&bytes).map_err(|load_err| {
                    CoreError::Keyring(format!("stored session file is corrupted: {load_err}"))
                });
            }
            return Ok(Session::new());
        }
        Err(other) => return Err(other),
    }

    if legacy_path.is_file() {
        info!(
            path = %legacy_path.display(),
            account_key,
            "Migrating legacy plaintext session file into OS keyring"
        );
        let session = Session::load_file(legacy_path)?;
        let bytes = session.save();
        if let Err(CoreError::Keyring(err)) = save_session_to_keyring(account_key, &bytes) {
            debug!(
                path = %legacy_path.display(),
                reason = %err,
                "OS keyring unavailable during migration; keeping app-private session file"
            );
            return Ok(session);
        }
        if let Err(err) = std::fs::remove_file(legacy_path) {
            tracing::warn!(
                path = %legacy_path.display(),
                error = %err,
                "Migrated session to keyring, but failed to remove legacy session file"
            );
        }
        return Ok(session);
    }

    debug!(account_key, "Creating new Telegram session for OS keyring");
    Ok(Session::new())
}

fn storage_chat_from_dialog_chat(chat: &Chat) -> Option<StorageChat> {
    match chat {
        Chat::Group(g) => match &g.raw {
            tl::enums::Chat::Chat(c) => {
                if c.left
                    || c.deactivated
                    || c.migrated_to.is_some()
                    || (!c.creator && c.admin_rights.is_none())
                {
                    return None;
                }
                Some(StorageChat {
                    id: c.id,
                    title: c.title.clone(),
                    kind: "group".to_string(),
                    is_creator: c.creator,
                    is_private: true,
                    member_count: Some(c.participants_count),
                })
            }
            tl::enums::Chat::Channel(ch) => {
                if ch.left || ch.restricted || (!ch.creator && ch.admin_rights.is_none()) {
                    return None;
                }
                if !ch.creator {
                    if let Some(tl::enums::ChatBannedRights::Rights(b)) = &ch.banned_rights {
                        if b.send_media || b.send_messages {
                            return None;
                        }
                    }
                }
                let is_private = ch.username.is_none()
                    && ch.usernames.as_deref().map_or(true, |u| u.is_empty());
                Some(StorageChat {
                    id: ch.id,
                    title: ch.title.clone(),
                    kind: "group".to_string(),
                    is_creator: ch.creator,
                    is_private,
                    member_count: ch.participants_count,
                })
            }
            _ => None,
        },
        Chat::Channel(c) => {
            let ch = &c.raw;
            if ch.left || ch.restricted {
                return None;
            }
            if !ch.creator && !c.admin_rights().is_some_and(|r| r.post_messages) {
                return None;
            }
            let is_private = c.username().is_none() && c.usernames().is_empty();
            Some(StorageChat {
                id: ch.id,
                title: ch.title.clone(),
                kind: "channel".to_string(),
                is_creator: ch.creator,
                is_private,
                member_count: ch.participants_count,
            })
        }
        Chat::User(_) => None,
    }
}

fn map_sign_in_error(err: SignInError) -> CoreError {
    match err {
        SignInError::PasswordRequired(token) => CoreError::PasswordRequired(Box::new(token)),
        SignInError::InvalidCode => CoreError::SignIn("invalid verification code".to_string()),
        SignInError::InvalidPassword => CoreError::SignIn("invalid 2FA password".to_string()),
        SignInError::SignUpRequired { .. } => CoreError::SignIn(
            "this phone number is not registered on Telegram; register with an official client first"
                .to_string(),
        ),
        SignInError::Other(inv) => CoreError::Invocation(inv),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_tl_channel(id: i64, title: &str) -> tl::types::Channel {
        tl::types::Channel {
            creator: false,
            left: false,
            broadcast: false,
            verified: false,
            megagroup: false,
            restricted: false,
            signatures: false,
            min: false,
            scam: false,
            has_link: false,
            has_geo: false,
            slowmode_enabled: false,
            call_active: false,
            call_not_empty: false,
            fake: false,
            gigagroup: false,
            noforwards: false,
            join_to_send: false,
            join_request: false,
            forum: false,
            stories_hidden: false,
            stories_hidden_min: false,
            stories_unavailable: true,
            signature_profiles: false,
            id,
            access_hash: Some(12345),
            title: title.to_string(),
            username: None,
            photo: tl::enums::ChatPhoto::Empty,
            date: 1700000000,
            restriction_reason: None,
            admin_rights: None,
            banned_rights: None,
            default_banned_rights: None,
            participants_count: Some(1),
            usernames: None,
            stories_max_id: None,
            color: None,
            profile_color: None,
            emoji_status: None,
            level: None,
            subscription_until_date: None,
        }
    }

    fn sample_admin_rights(post_messages: bool) -> tl::enums::ChatAdminRights {
        tl::enums::ChatAdminRights::Rights(tl::types::ChatAdminRights {
            change_info: false,
            post_messages,
            edit_messages: false,
            delete_messages: false,
            ban_users: false,
            invite_users: false,
            pin_messages: false,
            add_admins: false,
            anonymous: false,
            manage_call: false,
            other: false,
            manage_topics: false,
            post_stories: false,
            edit_stories: false,
            delete_stories: false,
        })
    }

    #[test]
    fn config_rejects_invalid_values() {
        let bad_id = TelegramConfig {
            api_id: 0,
            api_hash: "abc123".to_string(),
            session_path: PathBuf::from("test.session"),
        };
        assert!(matches!(
            bad_id.validate(),
            Err(CoreError::InvalidConfig(_))
        ));

        let bad_hash = TelegramConfig {
            api_id: 12345,
            api_hash: "   ".to_string(),
            session_path: PathBuf::from("test.session"),
        };
        assert!(matches!(
            bad_hash.validate(),
            Err(CoreError::InvalidConfig(_))
        ));

        let bad_session = TelegramConfig {
            api_id: 12345,
            api_hash: "abc123".to_string(),
            session_path: PathBuf::new(),
        };
        assert!(matches!(
            bad_session.validate(),
            Err(CoreError::InvalidConfig(_))
        ));
    }

    #[test]
    fn config_accepts_valid_values() {
        let valid = TelegramConfig {
            api_id: 12345,
            api_hash: "0123456789abcdef".to_string(),
            session_path: PathBuf::from("teledrive.session"),
        };
        assert!(valid.validate().is_ok());
    }

    #[test]
    fn atomic_session_file_roundtrip_persists_session() {
        let dir = std::env::temp_dir().join(format!("teledrive_sess_test_{}", std::process::id()));
        let session_path = dir.join("teledrive.session");
        let bytes = Session::new().save();
        write_session_file_atomic(&session_path, &bytes).expect("write atomic session");
        assert!(session_path.is_file());
        let loaded_bytes = std::fs::read(&session_path).expect("read written session");
        assert!(Session::load(&loaded_bytes).is_ok());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn storage_chat_filter_keeps_owned_and_writable_admins_only() {
        // (a) Subscribed public broadcast channel -> excluded
        let mut subscribed = sample_tl_channel(101, "Public News");
        subscribed.broadcast = true;
        subscribed.username = Some("public_news".to_string());
        assert!(storage_chat_from_dialog_chat(&Chat::from_raw(subscribed.into())).is_none());

        // (b) Admin broadcast channel without post_messages -> excluded
        let mut readonly_admin = sample_tl_channel(102, "Mod Only");
        readonly_admin.broadcast = true;
        readonly_admin.admin_rights = Some(sample_admin_rights(false));
        assert!(storage_chat_from_dialog_chat(&Chat::from_raw(readonly_admin.into())).is_none());

        // (c) Creator private broadcast channel -> included
        let mut owned_channel = sample_tl_channel(103, "My Private Vault Channel");
        owned_channel.broadcast = true;
        owned_channel.creator = true;
        owned_channel.participants_count = Some(1);
        let parsed_channel =
            storage_chat_from_dialog_chat(&Chat::from_raw(owned_channel.into()))
                .expect("owned channel should be included");
        assert_eq!(parsed_channel.kind, "channel");
        assert!(parsed_channel.is_creator);
        assert!(parsed_channel.is_private);
        assert_eq!(parsed_channel.member_count, Some(1));

        // (d) Non-admin regular group -> excluded
        let regular_group = tl::types::Chat {
            creator: false,
            left: false,
            deactivated: false,
            call_active: false,
            call_not_empty: false,
            noforwards: false,
            id: 104,
            title: "Random Chat".to_string(),
            photo: tl::enums::ChatPhoto::Empty,
            participants_count: 15,
            date: 1700000000,
            version: 1,
            migrated_to: None,
            admin_rights: None,
            default_banned_rights: None,
        };
        assert!(storage_chat_from_dialog_chat(&Chat::from_raw(regular_group.into())).is_none());

        // (e) Migrated legacy group -> excluded
        let migrated_group = tl::types::Chat {
            creator: true,
            left: false,
            deactivated: false,
            call_active: false,
            call_not_empty: false,
            noforwards: false,
            id: 105,
            title: "Old Group".to_string(),
            photo: tl::enums::ChatPhoto::Empty,
            participants_count: 3,
            date: 1700000000,
            version: 1,
            migrated_to: Some(tl::enums::InputChannel::Empty),
            admin_rights: None,
            default_banned_rights: None,
        };
        assert!(storage_chat_from_dialog_chat(&Chat::from_raw(migrated_group.into())).is_none());

        // (f) Owned private megagroup -> included
        let mut owned_megagroup = sample_tl_channel(106, "BIG DUCK Archive");
        owned_megagroup.creator = true;
        owned_megagroup.megagroup = true;
        owned_megagroup.participants_count = Some(2);
        let parsed_group =
            storage_chat_from_dialog_chat(&Chat::from_raw(owned_megagroup.into()))
                .expect("owned megagroup should be included");
        assert_eq!(parsed_group.kind, "group");
        assert!(parsed_group.is_creator);
        assert!(parsed_group.is_private);
        assert_eq!(parsed_group.member_count, Some(2));
    }
}

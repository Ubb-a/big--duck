import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_strings.dart';
import '../models/core_models.dart';
import '../services/biometric_service.dart';
import '../services/core_bridge.dart';
import '../services/notification_service.dart';
import '../services/share_receiver_service.dart';
import '../services/thumbnail_service.dart';

enum MobileTab { files, transfers, recent, settings }

const List<Folder> _initialDemoFolders = [
  Folder(id: 1, parentId: null, name: 'Documents', createdAt: 1731600000),
  Folder(id: 2, parentId: null, name: 'Photos & RAW', createdAt: 1731680000),
];

const List<FileRecord> _initialDemoFiles = [
  FileRecord(
    id: 101,
    folderId: null,
    name: 'Passport_Scan_Encrypted.pdf',
    size: 2450120,
    mimeType: 'application/pdf',
    sha256:
        '8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4',
    isEncrypted: true,
    createdAt: 1731700000,
  ),
  FileRecord(
    id: 102,
    folderId: null,
    name: 'Studio_Backup_2026.zip',
    size: 148200450,
    mimeType: 'application/zip',
    sha256:
        '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
    isEncrypted: true,
    createdAt: 1731750000,
  ),
  FileRecord(
    id: 103,
    folderId: 1,
    name: 'Tax_Return_2026.pdf',
    size: 842100,
    mimeType: 'application/pdf',
    sha256:
        '4a756ca07e9487f482465a99e8286abc86ba4dc7d43e4e4a529518a2b36a7a88',
    isEncrypted: true,
    createdAt: 1731780000,
  ),
];

class CacheStats {
  final int fileCount;
  final int totalBytes;

  const CacheStats({required this.fileCount, required this.totalBytes});
}

class AppController extends ChangeNotifier {
  final CoreBridge _bridge;
  final BiometricService biometrics = BiometricService();
  final TransferNotificationService notifications =
      TransferNotificationService();
  final ShareReceiverService _shareReceiver = ShareReceiverService();
  final ThumbnailService thumbnails = ThumbnailService();

  StreamSubscription<BridgeEvent>? _sub;
  Timer? _floodTimer;
  Timer? _toastTimer;
  DateTime? _backgroundedAt;

  bool demoMode = false;
  ThemeMode themeMode = ThemeMode.dark;
  bool isArabic;
  bool isSelecting = false;
  bool isLoadingVault = false;
  bool biometricEnabled = false;
  bool biometricAvailable = false;
  bool isLocked = false;
  int autoLockMinutes = 1;
  bool _biometricPromptActive = false;
  bool hasSavedSession = false;
  bool isReconnecting = false;
  String? cachedFullName;
  String? cachedUsername;
  String? _encryptionPassword;
  bool encryptBeforeUpload = true;
  bool _hasCustomChunkSize = false;
  int? lastBackupAt;
  List<String> _pendingSharedPaths = const [];
  List<String> pendingShareSheetPaths = const [];
  AuthStatus authStatus = const AuthStatus.disconnected();
  String? authError;
  String apiId = '';
  String apiHash = '';
  int chunkSizeMiB = 512;
  bool isLoadingChats = false;
  bool isCreatingVault = false;
  String? cachedTargetChatTitle;
  String? cachedTargetChatKind;
  List<StorageChat> storageChats = const [
    StorageChat(
      id: 9001,
      title: 'BIG DUCK Archive',
      kind: 'group',
      isCreator: true,
      isPrivate: true,
      memberCount: 1,
    ),
    StorageChat(
      id: 9002,
      title: 'Personal Media Vault',
      kind: 'channel',
      isCreator: true,
      isPrivate: true,
      memberCount: 1,
    ),
    StorageChat(
      id: 9003,
      title: 'Shared Studio Admin',
      kind: 'group',
      isCreator: false,
      isPrivate: true,
      memberCount: 6,
    ),
  ];
  int? targetChatId;
  MobileTab activeTab = MobileTab.files;
  DirectorySnapshot snapshot = const DirectorySnapshot(
    currentFolder: null,
    breadcrumbs: [],
    allFolders: _initialDemoFolders,
    folders: _initialDemoFolders,
    files: _initialDemoFiles,
    allFiles: _initialDemoFiles,
    tasks: [],
  );
  List<FileRecord> _demoAllFiles = List<FileRecord>.from(_initialDemoFiles);
  int floodWaitSeconds = 0;
  String? toastMessage;
  bool toastIsError = false;
  final Map<int, String> _localPathsByFileId = {};

  AppController({
    CoreBridge? bridge,
    this.isArabic = true,
  }) : _bridge = bridge ?? CoreBridge() {
    _init();
  }

  AppStrings get strings => AppStrings(isArabic);
  bool get hasNativeCore => _bridge.isNativeAvailable;
  bool get hasEncryptionPassword =>
      _encryptionPassword != null && _encryptionPassword!.isNotEmpty;
  String get displayAccountName =>
      authStatus.fullName ?? cachedFullName ?? 'Telegram Vault';
  String? get displayUsername => authStatus.username ?? cachedUsername;

  String activeDestinationTitle(AppStrings s) {
    if (targetChatId == null) return s.savedMessagesDefault;
    final match = storageChats.where((c) => c.id == targetChatId).firstOrNull;
    return match?.title ?? cachedTargetChatTitle ?? 'Chat #$targetChatId';
  }

  bool get activeDestinationOwnedByMe {
    if (targetChatId == null) return true;
    final match = storageChats.where((c) => c.id == targetChatId).firstOrNull;
    return match?.isCreator ?? true;
  }

  @visibleForTesting
  void debugPrimeSavedSession({
    String fullName = 'Saved User',
    String? username = 'saved_duck',
  }) {
    hasSavedSession = true;
    cachedFullName = fullName;
    cachedUsername = username;
    isReconnecting = true;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetLoadingVault(bool loading) {
    isLoadingVault = loading;
    notifyListeners();
  }

  @visibleForTesting
  void debugStageShareSheet(List<String> paths) {
    pendingShareSheetPaths = List<String>.from(paths);
    notifyListeners();
  }

  int get activeTransferCount => snapshot.tasks
      .where((t) => t.state == TaskState.queued || t.state == TaskState.running)
      .length;

  void setThemeMode(ThemeMode mode) {
    if (themeMode == mode) return;
    themeMode = mode;
    _saveConfig();
    notifyListeners();
  }

  void setArabic(bool value) {
    if (isArabic == value) return;
    isArabic = value;
    _saveConfig();
    notifyListeners();
  }

  void setSelecting(bool value) {
    if (isSelecting == value) return;
    isSelecting = value;
    notifyListeners();
  }

  void setAutoLockMinutes(int minutes) {
    if (autoLockMinutes == minutes) return;
    autoLockMinutes = minutes;
    _saveConfig();
    notifyListeners();
  }

  void setEncryptBeforeUpload(bool value) {
    if (encryptBeforeUpload == value) return;
    encryptBeforeUpload = value;
    _saveConfig();
    notifyListeners();
  }

  Future<File?> _configFile() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return File('${docsDir.path}${Platform.pathSeparator}bigduck_config.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadConfig() async {
    try {
      final file = await _configFile();
      if (file == null || !await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return;
      apiId = raw['api_id'] as String? ?? apiId;
      apiHash = raw['api_hash'] as String? ?? apiHash;
      isArabic = raw['is_arabic'] as bool? ?? isArabic;
      final themeStr = raw['theme_mode'] as String?;
      if (themeStr == 'light') {
        themeMode = ThemeMode.light;
      } else if (themeStr == 'dark') {
        themeMode = ThemeMode.dark;
      } else if (themeStr == 'system') {
        themeMode = ThemeMode.system;
      }
      biometricEnabled = raw['biometric_enabled'] as bool? ?? false;
      autoLockMinutes = (raw['auto_lock_minutes'] as num?)?.toInt() ?? 1;
      lastBackupAt = (raw['last_backup_at'] as num?)?.toInt();
      encryptBeforeUpload = raw['encrypt_before_upload'] as bool? ?? true;
      if (biometricEnabled) {
        isLocked = true;
      }
      cachedFullName = raw['cached_full_name'] as String?;
      cachedUsername = raw['cached_username'] as String?;
      final savedChunk = (raw['chunk_size_mib'] as num?)?.toInt();
      if (savedChunk != null && savedChunk > 0) {
        chunkSizeMiB = savedChunk;
        _hasCustomChunkSize = true;
      }
      targetChatId = (raw['target_chat_id'] as num?)?.toInt();
      cachedTargetChatTitle = raw['cached_target_chat_title'] as String?;
      cachedTargetChatKind = raw['cached_target_chat_kind'] as String?;
      final savedEnc = raw['encryption_password'] as String?;
      if (savedEnc != null && savedEnc.isNotEmpty) {
        _encryptionPassword = savedEnc;
      }
      final savedSessionFlag = raw['has_saved_session'] as bool? ?? false;
      var sessionFileExists = false;
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        sessionFileExists = await File(
                '${docsDir.path}${Platform.pathSeparator}teledrive.session')
            .exists();
      } catch (_) {}
      final hasCreds =
          int.tryParse(apiId.trim()) != null && apiHash.trim().isNotEmpty;
      if (hasCreds && (savedSessionFlag || sessionFileExists)) {
        hasSavedSession = true;
        isReconnecting = hasNativeCore;
      }
      notifyListeners();
    } catch (_) {
      // Ignore malformed config or test environment missing path_provider.
    }
  }

  Future<void> _saveConfig() async {
    try {
      final file = await _configFile();
      if (file == null) return;
      final payload = jsonEncode({
        'api_id': apiId,
        'api_hash': apiHash,
        'is_arabic': isArabic,
        'biometric_enabled': biometricEnabled,
        'auto_lock_minutes': autoLockMinutes,
        'last_backup_at': lastBackupAt,
        'encrypt_before_upload': encryptBeforeUpload,
        'has_saved_session': hasSavedSession,
        'cached_full_name': cachedFullName,
        'cached_username': cachedUsername,
        'chunk_size_mib': _hasCustomChunkSize ? chunkSizeMiB : null,
        'target_chat_id': targetChatId,
        'cached_target_chat_title': cachedTargetChatTitle,
        'cached_target_chat_kind': cachedTargetChatKind,
        'encryption_password': _encryptionPassword,
        'theme_mode': switch (themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      });
      await file.writeAsString(payload);
    } catch (_) {
      // Ignore in test environments.
    }
  }

  Future<void> _init() async {
    await _loadConfig();
    biometricAvailable = await biometrics.isAvailable();
    if (!biometricAvailable && biometricEnabled) {
      isLocked = false;
    }
    notifyListeners();

    await notifications.init();
    _shareReceiver.startListening(_handleSharedFiles);

    if (!_bridge.isNativeAvailable) return;
    await _bridge.start();
    _sub = _bridge.events.listen(_handleEvent);
    if (_hasCustomChunkSize) {
      _bridge.sendCommand({
        'type': 'set_chunk_size',
        'chunk_size': chunkSizeMiB * 1024 * 1024,
      });
    }
    if (_encryptionPassword != null && _encryptionPassword!.isNotEmpty) {
      _bridge.sendCommand({
        'type': 'set_encryption_password',
        'password': _encryptionPassword,
      });
    }
    if (int.tryParse(apiId.trim()) != null && apiHash.trim().isNotEmpty) {
      await connect();
    }
  }

  void _handleSharedFiles(List<String> paths) {
    if (paths.isEmpty) return;
    if ((authStatus.isAuthorized || demoMode) && !isLocked) {
      pendingShareSheetPaths = [...pendingShareSheetPaths, ...paths];
      notifyListeners();
      return;
    }
    _pendingSharedPaths = [..._pendingSharedPaths, ...paths];
    showToast(isArabic
        ? 'سيتم فتح شاشة الحفظ لـ ${paths.length} ملف فور فتح الخزنة'
        : 'Staged ${paths.length} shared file(s) until vault unlock');
    notifyListeners();
  }

  void _flushPendingSharedFiles() {
    if (_pendingSharedPaths.isEmpty ||
        (!authStatus.isAuthorized && !demoMode) ||
        isLocked) {
      return;
    }
    final batch = List<String>.from(_pendingSharedPaths);
    _pendingSharedPaths = const [];
    pendingShareSheetPaths = [...pendingShareSheetPaths, ...batch];
    notifyListeners();
  }

  void confirmPendingShareUpload({
    int? folderId,
    required bool encrypt,
  }) {
    final batch = List<String>.from(pendingShareSheetPaths);
    pendingShareSheetPaths = const [];
    setEncryptBeforeUpload(encrypt);
    if (batch.isNotEmpty) {
      uploadFiles(
        batch,
        targetFolderId: folderId,
        encryptedOverride: encrypt,
      );
    }
    notifyListeners();
  }

  void dismissPendingShareUpload() {
    pendingShareSheetPaths = const [];
    notifyListeners();
  }

  void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
    if (biometricEnabled &&
        biometricAvailable &&
        autoLockMinutes == 0 &&
        (authStatus.isAuthorized || hasSavedSession) &&
        !_biometricPromptActive &&
        !isLocked) {
      isLocked = true;
      notifyListeners();
    }
  }

  void onAppResumed() {
    final bgAt = _backgroundedAt;
    _backgroundedAt = null;
    if (bgAt == null ||
        !biometricEnabled ||
        !biometricAvailable ||
        _biometricPromptActive ||
        isLocked ||
        (!authStatus.isAuthorized && !hasSavedSession)) {
      return;
    }
    if (DateTime.now().difference(bgAt).inMinutes >= autoLockMinutes) {
      isLocked = true;
      notifyListeners();
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (_biometricPromptActive) return false;
    _biometricPromptActive = true;
    try {
      final ok = await biometrics.authenticate(isArabic: isArabic);
      if (ok) {
        isLocked = false;
        notifyListeners();
        _flushPendingSharedFiles();
      }
      return ok;
    } finally {
      _biometricPromptActive = false;
    }
  }

  /// Fallback local unlock used when user confirms device passcode flow.
  void unlockWithPasscodeFallback() {
    isLocked = false;
    notifyListeners();
    _flushPendingSharedFiles();
  }

  Future<bool> setBiometricEnabled(bool enable) async {
    if (enable) {
      final avail = await biometrics.isAvailable();
      biometricAvailable = avail;
      if (!avail) {
        showToast(strings.biometricUnavailable, isError: true);
        notifyListeners();
        return false;
      }
      _biometricPromptActive = true;
      bool ok;
      try {
        ok = await biometrics.authenticate(isArabic: isArabic);
      } finally {
        _biometricPromptActive = false;
      }
      if (!ok) return false;
      biometricEnabled = true;
      isLocked = false;
    } else {
      biometricEnabled = false;
      isLocked = false;
    }
    await _saveConfig();
    notifyListeners();
    return true;
  }

  String _fileNameForId(int fileId) {
    final fromAll = snapshot.allFiles.where((f) => f.id == fileId).firstOrNull;
    if (fromAll != null) return fromAll.name;
    final fromCur = snapshot.files.where((f) => f.id == fileId).firstOrNull;
    return fromCur?.name ?? 'File #$fileId';
  }

  void _handleEvent(BridgeEvent ev) {
    switch (ev) {
      case ReadyEvent(:final defaultChunkSize):
        if (!_hasCustomChunkSize && defaultChunkSize > 0) {
          chunkSizeMiB = (defaultChunkSize / (1024 * 1024)).round();
        }
        notifyListeners();
      case AuthChangedEvent(:final auth):
        authStatus = auth;
        authError = null;
        if (auth.isAuthorized) {
          hasSavedSession = true;
          isReconnecting = false;
          isLoadingVault = snapshot.files.isEmpty && snapshot.folders.isEmpty;
          cachedFullName = auth.fullName;
          cachedUsername = auth.username;
          _saveConfig();
          _bridge.sendCommand({'type': 'list_chats'});
          if (targetChatId != null) {
            _bridge.sendCommand({
              'type': 'set_target_chat',
              'chat_id': targetChatId,
            });
          }
          notifications.requestPermission();
          _flushPendingSharedFiles();
        } else if (auth.kind == AuthStatusKind.connecting) {
          isReconnecting = true;
        } else if (auth.kind == AuthStatusKind.awaitingPhone ||
            auth.kind == AuthStatusKind.awaitingCode ||
            auth.kind == AuthStatusKind.awaitingPassword) {
          hasSavedSession = false;
          isReconnecting = false;
          isLoadingVault = false;
          _saveConfig();
        } else if (auth.kind == AuthStatusKind.disconnected) {
          isReconnecting = false;
          isLoadingVault = false;
        }
        notifyListeners();
      case SnapshotEvent(:final snapshot):
        this.snapshot = snapshot;
        isLoadingVault = false;
        notifyListeners();
      case QueueUpdateEvent(
          :final event,
          :final taskId,
          :final fileId,
          :final kind,
          :final progress,
          :final seconds,
          :final fileLabel,
          :final message
        ):
        final isUpload = kind == 'upload';
        if (event == 'task_flood_wait' && seconds > 0) {
          _startFloodCountdown(seconds);
        } else if (event == 'task_progress') {
          notifications.showProgress(
            taskId: taskId,
            fileName: _fileNameForId(fileId),
            isUpload: isUpload,
            progress: progress,
            isArabic: isArabic,
          );
        } else if (event == 'task_paused') {
          notifications.showPaused(
            taskId: taskId,
            fileName: _fileNameForId(fileId),
            isArabic: isArabic,
          );
        } else if (event == 'task_completed') {
          notifications.showCompleted(
            taskId: taskId,
            fileName: _fileNameForId(fileId),
            isUpload: isUpload,
            isArabic: isArabic,
          );
        } else if (event == 'task_failed' &&
            message != null &&
            message.isNotEmpty) {
          showToast(message, isError: true);
          notifications.showFailed(
            fileLabel: fileLabel ??
                (fileId > 0 ? _fileNameForId(fileId) : 'Transfer'),
            error: message,
            isArabic: isArabic,
          );
        }
      case ChatsListedEvent(:final chats):
        isLoadingChats = false;
        storageChats = chats;
        if (targetChatId != null) {
          final match = chats.where((c) => c.id == targetChatId).firstOrNull;
          if (match != null) {
            cachedTargetChatTitle = match.title;
            cachedTargetChatKind = match.kind;
            _saveConfig();
          }
        }
        notifyListeners();
      case StorageChatCreatedEvent(:final chat):
        isCreatingVault = false;
        storageChats = [
          chat,
          ...storageChats.where((c) => c.id != chat.id),
        ];
        targetChatId = chat.id;
        cachedTargetChatTitle = chat.title;
        cachedTargetChatKind = chat.kind;
        _saveConfig();
        showToast(strings.vaultCreatedToast(chat.title));
        notifyListeners();
      case TargetChatChangedEvent(:final chatId):
        targetChatId = chatId;
        if (chatId == null) {
          cachedTargetChatTitle = null;
          cachedTargetChatKind = null;
        } else {
          final match =
              storageChats.where((c) => c.id == chatId).firstOrNull;
          if (match != null) {
            cachedTargetChatTitle = match.title;
            cachedTargetChatKind = match.kind;
          }
        }
        _saveConfig();
        notifyListeners();
      case InfoEvent(:final message):
        showToast(message);
      case ErrorEvent(:final message):
        isLoadingChats = false;
        isCreatingVault = false;
        isLoadingVault = false;
        if (!authStatus.isAuthorized) {
          authError = message;
          notifyListeners();
        } else {
          showToast(message, isError: true);
        }
    }
  }

  void _startFloodCountdown(int seconds) {
    floodWaitSeconds = seconds;
    _floodTimer?.cancel();
    _floodTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (floodWaitSeconds <= 1) {
        floodWaitSeconds = 0;
        timer.cancel();
      } else {
        floodWaitSeconds -= 1;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void showToast(String message, {bool isError = false}) {
    toastMessage = message;
    toastIsError = isError;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      toastMessage = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void setTab(MobileTab tab) {
    if (activeTab == tab) return;
    activeTab = tab;
    isSelecting = false;
    notifyListeners();
  }

  void enterDemoMode() {
    demoMode = true;
    isLoadingVault = false;
    lastBackupAt ??= 1731780000;
    authStatus = const AuthStatus.authorized(
      userId: 1,
      fullName: 'BIG DUCK Demo',
      username: 'bigduck_demo',
    );
    _demoAllFiles = List<FileRecord>.from(_initialDemoFiles);
    snapshot = DirectorySnapshot(
      currentFolder: null,
      breadcrumbs: const [],
      allFolders: _initialDemoFolders,
      folders: _initialDemoFolders,
      files: _demoAllFiles.where((f) => f.folderId == null).toList(),
      allFiles: List<FileRecord>.from(_demoAllFiles),
      tasks: const [],
    );
    _flushPendingSharedFiles();
    showToast(strings.previewUiActivated);
  }

  void exitDemoMode() {
    demoMode = false;
    hasSavedSession = false;
    isReconnecting = false;
    isLoadingVault = false;
    cachedFullName = null;
    cachedUsername = null;
    authStatus = const AuthStatus.disconnected();
    authError = null;
    notifyListeners();
  }

  void setApiId(String v) => apiId = v;
  void setApiHash(String v) => apiHash = v;

  Future<void> connect() async {
    final parsedId = int.tryParse(apiId.trim());
    if (parsedId == null || apiHash.trim().isEmpty) {
      authError = strings.invalidApiCreds;
      notifyListeners();
      return;
    }
    if (!hasNativeCore) {
      authError = strings.nativeLibUnavailable;
      notifyListeners();
      return;
    }
    authError = null;
    isReconnecting = true;
    authStatus = const AuthStatus.connecting();
    notifyListeners();

    final docsDir = await getApplicationDocumentsDirectory();
    final sessionPath =
        '${docsDir.path}${Platform.pathSeparator}teledrive.session';
    await _saveConfig();
    _bridge.sendCommand({
      'type': 'connect',
      'api_id': parsedId,
      'api_hash': apiHash.trim(),
      'session_path': sessionPath,
    });
  }

  void submitPhone(String phone) {
    _bridge.sendCommand({'type': 'submit_phone', 'phone': phone.trim()});
  }

  void submitCode(String code) {
    _bridge.sendCommand({'type': 'submit_code', 'code': code.trim()});
  }

  void submitPassword(String password) {
    _bridge.sendCommand({'type': 'submit_password', 'password': password});
  }

  void resetAuthStep() {
    authError = null;
    if (!hasNativeCore) {
      authStatus = const AuthStatus.disconnected();
      notifyListeners();
      return;
    }
    _bridge.sendCommand({'type': 'reset_auth_step'});
  }

  Future<void> logout() async {
    if (demoMode) {
      exitDemoMode();
      return;
    }
    if (hasNativeCore) {
      _bridge.sendCommand({'type': 'logout'});
    }
    hasSavedSession = false;
    isReconnecting = false;
    isLoadingChats = false;
    isCreatingVault = false;
    isLoadingVault = false;
    cachedFullName = null;
    cachedUsername = null;
    targetChatId = null;
    cachedTargetChatTitle = null;
    cachedTargetChatKind = null;
    storageChats = const [];
    authStatus = const AuthStatus.disconnected();
    authError = null;
    showToast(strings.signedOutToast);
    notifyListeners();

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final sessionFile =
          File('${docsDir.path}${Platform.pathSeparator}teledrive.session');
      if (await sessionFile.exists()) {
        await sessionFile.delete();
      }
    } catch (_) {}
    await _saveConfig();
  }

  void _refreshDemoView(
    int? folderId, {
    List<Folder>? updatedAllFolders,
    List<TaskRecord>? updatedTasks,
  }) {
    final allFolders = updatedAllFolders ?? snapshot.allFolders;
    final current = folderId == null
        ? null
        : allFolders.where((f) => f.id == folderId).firstOrNull;
    final breadcrumbs = <Folder>[];
    var cursor = current;
    while (cursor != null) {
      breadcrumbs.insert(0, cursor);
      final pid = cursor.parentId;
      cursor = pid == null
          ? null
          : allFolders.where((f) => f.id == pid).firstOrNull;
    }
    final folders =
        allFolders.where((f) => f.parentId == folderId).toList(growable: false);
    final files = _demoAllFiles
        .where((f) => f.folderId == folderId)
        .toList(growable: false);
    snapshot = DirectorySnapshot(
      currentFolder: current,
      breadcrumbs: breadcrumbs,
      allFolders: allFolders,
      folders: folders,
      files: files,
      allFiles: List<FileRecord>.from(_demoAllFiles),
      tasks: updatedTasks ?? snapshot.tasks,
    );
  }

  void openFolder(int? folderId) {
    if (demoMode || !hasNativeCore) {
      _refreshDemoView(folderId);
      notifyListeners();
      return;
    }
    _bridge.sendCommand({'type': 'open_folder', 'folder_id': folderId});
  }

  void createFolder(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final parentId = snapshot.currentFolder?.id;
    if (demoMode || !hasNativeCore) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final created = Folder(
        id: now,
        parentId: parentId,
        name: trimmed,
        createdAt: now ~/ 1000,
      );
      _refreshDemoView(
        parentId,
        updatedAllFolders: [...snapshot.allFolders, created],
      );
      showToast(strings.createdFolderToast(trimmed));
      return;
    }
    _bridge.sendCommand({
      'type': 'create_folder',
      'parent_id': parentId,
      'name': trimmed,
    });
  }

  void renameFolder(int id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    if (demoMode || !hasNativeCore) {
      final updatedAll = snapshot.allFolders
          .map((f) => f.id == id ? f.copyWith(name: trimmed) : f)
          .toList(growable: false);
      _refreshDemoView(snapshot.currentFolder?.id,
          updatedAllFolders: updatedAll);
      showToast(strings.renamedToToast(trimmed));
      return;
    }
    _bridge.sendCommand({
      'type': 'rename_folder',
      'id': id,
      'new_name': trimmed,
    });
  }

  bool isDescendantFolder(int candidateId, int ancestorId) {
    int? cursor = candidateId;
    while (cursor != null) {
      if (cursor == ancestorId) return true;
      cursor = snapshot.allFolders
          .where((f) => f.id == cursor)
          .firstOrNull
          ?.parentId;
    }
    return false;
  }

  void moveFolder(int id, int? newParentId) {
    if (newParentId != null && isDescendantFolder(newParentId, id)) {
      showToast(strings.cannotMoveIntoSelf, isError: true);
      return;
    }
    if (demoMode || !hasNativeCore) {
      final updatedAll = snapshot.allFolders
          .map((f) => f.id == id ? f.copyWith(parentId: newParentId) : f)
          .toList(growable: false);
      _refreshDemoView(snapshot.currentFolder?.id,
          updatedAllFolders: updatedAll);
      showToast(strings.movedToast);
      return;
    }
    _bridge.sendCommand({
      'type': 'move_folder',
      'id': id,
      'new_parent_id': newParentId,
    });
  }

  void deleteFolder(int id) {
    if (demoMode || !hasNativeCore) {
      final updatedAll = snapshot.allFolders
          .where((f) => f.id != id)
          .toList(growable: false);
      _demoAllFiles.removeWhere((f) => f.folderId == id);
      _refreshDemoView(snapshot.currentFolder?.id,
          updatedAllFolders: updatedAll);
      showToast(strings.deletedToast);
      return;
    }
    _bridge.sendCommand({'type': 'delete_folder', 'id': id});
  }

  void renameFile(int id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    if (demoMode || !hasNativeCore) {
      _demoAllFiles = _demoAllFiles
          .map((f) => f.id == id ? f.copyWith(name: trimmed) : f)
          .toList();
      _refreshDemoView(snapshot.currentFolder?.id);
      showToast(strings.renamedToToast(trimmed));
      return;
    }
    _bridge.sendCommand({
      'type': 'rename_file',
      'id': id,
      'new_name': trimmed,
    });
  }

  void moveFile(int id, int? newFolderId) {
    if (demoMode || !hasNativeCore) {
      _demoAllFiles = _demoAllFiles
          .map((f) => f.id == id ? f.copyWith(folderId: newFolderId) : f)
          .toList();
      _refreshDemoView(snapshot.currentFolder?.id);
      showToast(strings.movedToast);
      return;
    }
    _bridge.sendCommand({
      'type': 'move_file',
      'id': id,
      'new_folder_id': newFolderId,
    });
  }

  void deleteFile(int id) {
    if (demoMode || !hasNativeCore) {
      _demoAllFiles.removeWhere((f) => f.id == id);
      _refreshDemoView(snapshot.currentFolder?.id);
      showToast(strings.deletedToast);
      return;
    }
    _bridge.sendCommand({'type': 'delete_file', 'id': id});
  }

  void moveMany({
    List<int> folderIds = const [],
    List<int> fileIds = const [],
    int? targetFolderId,
  }) {
    if (demoMode || !hasNativeCore) {
      var updatedAll = snapshot.allFolders;
      for (final id in folderIds) {
        if (targetFolderId != null && isDescendantFolder(targetFolderId, id)) {
          continue;
        }
        updatedAll = updatedAll
            .map((f) => f.id == id ? f.copyWith(parentId: targetFolderId) : f)
            .toList(growable: false);
      }
      _demoAllFiles = _demoAllFiles
          .map((f) =>
              fileIds.contains(f.id) ? f.copyWith(folderId: targetFolderId) : f)
          .toList();
      _refreshDemoView(snapshot.currentFolder?.id,
          updatedAllFolders: updatedAll);
      showToast(strings.movedManyToast(folderIds.length + fileIds.length));
      return;
    }
    for (final id in folderIds) {
      if (targetFolderId != null && isDescendantFolder(targetFolderId, id)) {
        continue;
      }
      _bridge.sendCommand({
        'type': 'move_folder',
        'id': id,
        'new_parent_id': targetFolderId,
      });
    }
    for (final id in fileIds) {
      _bridge.sendCommand({
        'type': 'move_file',
        'id': id,
        'new_folder_id': targetFolderId,
      });
    }
    showToast(strings.movedManyToast(folderIds.length + fileIds.length));
  }

  void deleteMany({
    List<int> folderIds = const [],
    List<int> fileIds = const [],
  }) {
    if (demoMode || !hasNativeCore) {
      final updatedAll = snapshot.allFolders
          .where((f) => !folderIds.contains(f.id))
          .toList(growable: false);
      _demoAllFiles.removeWhere(
          (f) => fileIds.contains(f.id) || folderIds.contains(f.folderId));
      _refreshDemoView(snapshot.currentFolder?.id,
          updatedAllFolders: updatedAll);
      showToast(strings.deletedManyToast(folderIds.length + fileIds.length));
      return;
    }
    for (final id in folderIds) {
      _bridge.sendCommand({'type': 'delete_folder', 'id': id});
    }
    for (final id in fileIds) {
      _bridge.sendCommand({'type': 'delete_file', 'id': id});
    }
    showToast(strings.deletedManyToast(folderIds.length + fileIds.length));
  }

  Future<void> downloadMany(List<FileRecord> files) async {
    for (final f in files) {
      await downloadFile(f);
    }
  }

  void uploadFiles(
    List<String> paths, {
    int? targetFolderId,
    bool? encryptedOverride,
  }) {
    if (paths.isEmpty) return;
    final folderId = targetFolderId ?? snapshot.currentFolder?.id;
    final encrypted = encryptedOverride ??
        (encryptBeforeUpload || hasEncryptionPassword);
    if (demoMode || !hasNativeCore) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final added = <FileRecord>[];
      for (var i = 0; i < paths.length; i++) {
        final name = paths[i].split(RegExp(r'[/\\]')).last;
        final id = now + i;
        _localPathsByFileId[id] = paths[i];
        final lower = name.toLowerCase();
        final String mime;
        if (lower.endsWith('.pdf')) {
          mime = 'application/pdf';
        } else if (lower.endsWith('.png')) {
          mime = 'image/png';
        } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          mime = 'image/jpeg';
        } else if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
          mime = 'video/mp4';
        } else if (lower.endsWith('.mp3') ||
            lower.endsWith('.m4a') ||
            lower.endsWith('.wav') ||
            lower.endsWith('.flac')) {
          mime = 'audio/mpeg';
        } else {
          mime = 'application/octet-stream';
        }
        added.add(FileRecord(
          id: id,
          folderId: folderId,
          name: name.isEmpty ? 'file_${i + 1}' : name,
          size: File(paths[i]).existsSync()
              ? File(paths[i]).lengthSync()
              : 1024 * 512,
          mimeType: mime,
          sha256:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          isEncrypted: encrypted,
          createdAt: now ~/ 1000,
        ));
      }
      _demoAllFiles = [...added, ..._demoAllFiles];
      _refreshDemoView(snapshot.currentFolder?.id);
      showToast(strings.queuedUploadToast(added.length));
      return;
    }
    _bridge.sendCommand({
      'type': 'upload_files',
      'paths': paths,
      'folder_id': folderId,
    });
    showToast(strings.queuedUploadToast(paths.length));
  }

  Future<String?> resolveLocalPath(FileRecord file) async {
    final cached = _localPathsByFileId[file.id];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final candidate =
        '${docsDir.path}${Platform.pathSeparator}downloads${Platform.pathSeparator}${file.name}';
    if (await File(candidate).exists()) {
      _localPathsByFileId[file.id] = candidate;
      return candidate;
    }
    return null;
  }

  TaskRecord? latestDownloadTaskFor(int fileId) {
    for (final t in snapshot.tasks.reversed) {
      if (t.fileId == fileId && t.kind == TaskKind.download) {
        return t;
      }
    }
    return null;
  }

  TaskRecord? latestTaskFor(int fileId) {
    for (final t in snapshot.tasks.reversed) {
      if (t.fileId == fileId) {
        return t;
      }
    }
    return null;
  }

  Future<String?> downloadFile(FileRecord file) async {
    if (demoMode || !hasNativeCore) {
      showToast(strings.demoDownloadToast(file.name));
      return null;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final destDir =
        Directory('${docsDir.path}${Platform.pathSeparator}downloads');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = '${destDir.path}${Platform.pathSeparator}${file.name}';
    _bridge.sendCommand({
      'type': 'download_file',
      'file_id': file.id,
      'dest_path': destPath,
    });
    showToast(strings.downloadingToast(file.name));
    return destPath;
  }

  void pauseTask(int taskId) {
    if (demoMode || !hasNativeCore) {
      final updatedTasks = snapshot.tasks
          .map((t) => t.id == taskId
              ? TaskRecord(
                  id: t.id,
                  kind: t.kind,
                  fileId: t.fileId,
                  state: TaskState.paused,
                  progress: t.progress,
                  error: t.error,
                )
              : t)
          .toList(growable: false);
      _refreshDemoView(snapshot.currentFolder?.id, updatedTasks: updatedTasks);
      notifyListeners();
      return;
    }
    _bridge.sendCommand({'type': 'pause_task', 'task_id': taskId});
  }

  Future<void> resumeTask(TaskRecord task) async {
    if (demoMode || !hasNativeCore) {
      final updatedTasks = snapshot.tasks
          .map((t) => t.id == task.id
              ? TaskRecord(
                  id: t.id,
                  kind: t.kind,
                  fileId: t.fileId,
                  state: TaskState.running,
                  progress: t.progress,
                  error: null,
                )
              : t)
          .toList(growable: false);
      _refreshDemoView(snapshot.currentFolder?.id, updatedTasks: updatedTasks);
      notifyListeners();
      return;
    }
    String? destPath;
    if (task.kind == TaskKind.download) {
      final docsDir = await getApplicationDocumentsDirectory();
      final name = _fileNameForId(task.fileId);
      destPath =
          '${docsDir.path}${Platform.pathSeparator}downloads${Platform.pathSeparator}$name';
    }
    _bridge.sendCommand({
      'type': 'resume_task',
      'task_id': task.id,
      'dest_path': destPath,
    });
  }

  Future<void> retryTask(TaskRecord task) => resumeTask(task);

  Future<CacheStats> getDownloadCacheStats() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir =
          Directory('${docsDir.path}${Platform.pathSeparator}downloads');
      if (!await dir.exists()) {
        return const CacheStats(fileCount: 0, totalBytes: 0);
      }
      var count = 0;
      var bytes = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          count++;
          bytes += await entity.length();
        }
      }
      return CacheStats(fileCount: count, totalBytes: bytes);
    } catch (_) {
      return const CacheStats(fileCount: 0, totalBytes: 0);
    }
  }

  Future<void> clearDownloadCache() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir =
          Directory('${docsDir.path}${Platform.pathSeparator}downloads');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _localPathsByFileId.clear();
      await thumbnails.clearCache();
      showToast(isArabic ? 'تم مسح الكاش المحلي' : 'Cleared local download cache');
    } catch (e) {
      showToast('Failed to clear cache: $e', isError: true);
    }
  }

  void refreshChats() {
    if (demoMode || !hasNativeCore) {
      showToast(strings.loadedGroupsToast);
      return;
    }
    isLoadingChats = true;
    notifyListeners();
    _bridge.sendCommand({'type': 'list_chats'});
  }

  void setTargetChat(int? chatId) {
    final picked = chatId == null
        ? null
        : storageChats.where((c) => c.id == chatId).firstOrNull;
    targetChatId = chatId;
    cachedTargetChatTitle = picked?.title;
    cachedTargetChatKind = picked?.kind;
    _saveConfig();
    if (demoMode || !hasNativeCore) {
      showToast(
        chatId == null
            ? strings.storageChangedToast(true)
            : strings.storageSetToChatToast(picked?.title ?? '#$chatId'),
      );
      notifyListeners();
      return;
    }
    _bridge.sendCommand({'type': 'set_target_chat', 'chat_id': chatId});
    showToast(
      chatId == null
          ? strings.storageChangedToast(true)
          : strings.storageSetToChatToast(picked?.title ?? '#$chatId'),
    );
    notifyListeners();
  }

  void createStorageVault({
    required String title,
    String kind = 'group',
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final normalizedKind = kind == 'channel' ? 'channel' : 'group';
    if (demoMode || !hasNativeCore) {
      final created = StorageChat(
        id: DateTime.now().millisecondsSinceEpoch,
        title: trimmed,
        kind: normalizedKind,
        isCreator: true,
        isPrivate: true,
        memberCount: 1,
      );
      storageChats = [created, ...storageChats];
      targetChatId = created.id;
      cachedTargetChatTitle = created.title;
      cachedTargetChatKind = created.kind;
      _saveConfig();
      showToast(strings.vaultCreatedToast(created.title));
      notifyListeners();
      return;
    }
    isCreatingVault = true;
    notifyListeners();
    _bridge.sendCommand({
      'type': 'create_storage_chat',
      'title': trimmed,
      'kind': normalizedKind,
    });
  }

  void setChunkSizeMiB(int mib) {
    chunkSizeMiB = mib;
    _hasCustomChunkSize = true;
    _saveConfig();
    if (demoMode || !hasNativeCore) {
      showToast(strings.chunkSizeSetToast(mib));
      notifyListeners();
      return;
    }
    _bridge.sendCommand({
      'type': 'set_chunk_size',
      'chunk_size': mib * 1024 * 1024,
    });
    notifyListeners();
  }

  void setEncryptionPassword(String? password) {
    final trimmed = password?.trim();
    _encryptionPassword = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _saveConfig();
    if (demoMode || !hasNativeCore) {
      showToast(strings.encryptionUpdatedToast(_encryptionPassword != null));
      notifyListeners();
      return;
    }
    _bridge.sendCommand({
      'type': 'set_encryption_password',
      'password': _encryptionPassword,
    });
    notifyListeners();
  }

  void backupIndex(String password) {
    if (password.isEmpty) return;
    lastBackupAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _saveConfig();
    if (demoMode || !hasNativeCore) {
      showToast(strings.demoBackupToast);
      notifyListeners();
      return;
    }
    _bridge.sendCommand({'type': 'backup_index', 'password': password});
    notifyListeners();
  }

  void restoreIndex(String password, int? messageId) {
    if (password.isEmpty) return;
    if (demoMode || !hasNativeCore) {
      showToast(strings.demoRestoreToast);
      return;
    }
    _bridge.sendCommand({
      'type': 'restore_index',
      'password': password,
      'message_id': messageId,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _floodTimer?.cancel();
    _toastTimer?.cancel();
    _shareReceiver.dispose();
    _bridge.dispose();
    super.dispose();
  }
}

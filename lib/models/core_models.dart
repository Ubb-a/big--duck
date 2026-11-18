import 'dart:convert';

const _unset = Object();

class Folder {
  final int id;
  final int? parentId;
  final String name;
  final int createdAt;

  const Folder({
    required this.id,
    required this.parentId,
    required this.name,
    required this.createdAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: (json['id'] as num).toInt(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  Folder copyWith({String? name, Object? parentId = _unset}) {
    return Folder(
      id: id,
      parentId: identical(parentId, _unset) ? this.parentId : parentId as int?,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }
}

class FileRecord {
  final int id;
  final int? folderId;
  final String name;
  final int size;
  final String mimeType;
  final String sha256;
  final bool isEncrypted;
  final int createdAt;

  const FileRecord({
    required this.id,
    required this.folderId,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.sha256,
    required this.isEncrypted,
    required this.createdAt,
  });

  factory FileRecord.fromJson(Map<String, dynamic> json) {
    return FileRecord(
      id: (json['id'] as num).toInt(),
      folderId: (json['folder_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sha256: json['sha256'] as String? ?? '',
      isEncrypted: json['is_encrypted'] as bool? ?? false,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  FileRecord copyWith({String? name, Object? folderId = _unset}) {
    return FileRecord(
      id: id,
      folderId: identical(folderId, _unset) ? this.folderId : folderId as int?,
      name: name ?? this.name,
      size: size,
      mimeType: mimeType,
      sha256: sha256,
      isEncrypted: isEncrypted,
      createdAt: createdAt,
    );
  }
}

enum TaskKind {
  upload,
  download;

  static TaskKind fromString(String? raw) =>
      raw == 'download' ? TaskKind.download : TaskKind.upload;
}

enum TaskState {
  queued,
  running,
  paused,
  completed,
  failed;

  static TaskState fromString(String? raw) {
    switch (raw) {
      case 'running':
        return TaskState.running;
      case 'paused':
        return TaskState.paused;
      case 'completed':
        return TaskState.completed;
      case 'failed':
        return TaskState.failed;
      default:
        return TaskState.queued;
    }
  }
}

class TaskRecord {
  final int id;
  final TaskKind kind;
  final int fileId;
  final TaskState state;
  final double progress;
  final String? error;

  const TaskRecord({
    required this.id,
    required this.kind,
    required this.fileId,
    required this.state,
    required this.progress,
    this.error,
  });

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      id: (json['id'] as num).toInt(),
      kind: TaskKind.fromString(json['kind'] as String?),
      fileId: (json['file_id'] as num).toInt(),
      state: TaskState.fromString(json['state'] as String?),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }
}

class DirectorySnapshot {
  final Folder? currentFolder;
  final List<Folder> breadcrumbs;
  final List<Folder> allFolders;
  final List<Folder> folders;
  final List<FileRecord> files;
  final List<FileRecord> allFiles;
  final List<TaskRecord> tasks;

  const DirectorySnapshot({
    this.currentFolder,
    this.breadcrumbs = const [],
    this.allFolders = const [],
    this.folders = const [],
    this.files = const [],
    this.allFiles = const [],
    this.tasks = const [],
  });

  factory DirectorySnapshot.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) mapper) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(mapper)
          .toList(growable: false);
    }

    final currentRaw = json['current_folder'];
    final folderFiles = parseList('files', FileRecord.fromJson);
    final rawAllFiles = json['all_files'];
    final parsedAllFiles = rawAllFiles is List
        ? parseList('all_files', FileRecord.fromJson)
        : folderFiles;
    return DirectorySnapshot(
      currentFolder: currentRaw is Map<String, dynamic>
          ? Folder.fromJson(currentRaw)
          : null,
      breadcrumbs: parseList('breadcrumbs', Folder.fromJson),
      allFolders: parseList('all_folders', Folder.fromJson),
      folders: parseList('folders', Folder.fromJson),
      files: folderFiles,
      allFiles: parsedAllFiles,
      tasks: parseList('tasks', TaskRecord.fromJson),
    );
  }

  DirectorySnapshot copyWith({
    Folder? currentFolder,
    List<Folder>? breadcrumbs,
    List<Folder>? allFolders,
    List<Folder>? folders,
    List<FileRecord>? files,
    List<FileRecord>? allFiles,
    List<TaskRecord>? tasks,
  }) {
    return DirectorySnapshot(
      currentFolder: currentFolder ?? this.currentFolder,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      allFolders: allFolders ?? this.allFolders,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      allFiles: allFiles ?? this.allFiles,
      tasks: tasks ?? this.tasks,
    );
  }
}

enum AuthStatusKind {
  disconnected,
  connecting,
  awaitingPhone,
  awaitingCode,
  awaitingPassword,
  authorized,
}

class AuthStatus {
  final AuthStatusKind kind;
  final String? phone;
  final String? hint;
  final int? userId;
  final String? fullName;
  final String? username;

  const AuthStatus._({
    required this.kind,
    this.phone,
    this.hint,
    this.userId,
    this.fullName,
    this.username,
  });

  const AuthStatus.disconnected() : this._(kind: AuthStatusKind.disconnected);
  const AuthStatus.connecting() : this._(kind: AuthStatusKind.connecting);
  const AuthStatus.awaitingPhone() : this._(kind: AuthStatusKind.awaitingPhone);
  const AuthStatus.awaitingCode(String phone)
      : this._(kind: AuthStatusKind.awaitingCode, phone: phone);
  const AuthStatus.awaitingPassword(String? hint)
      : this._(kind: AuthStatusKind.awaitingPassword, hint: hint);
  const AuthStatus.authorized({
    required int userId,
    required String fullName,
    String? username,
  }) : this._(
          kind: AuthStatusKind.authorized,
          userId: userId,
          fullName: fullName,
          username: username,
        );

  bool get isAuthorized => kind == AuthStatusKind.authorized;

  factory AuthStatus.fromJson(Map<String, dynamic> json) {
    switch (json['status']) {
      case 'connecting':
        return const AuthStatus.connecting();
      case 'awaiting_phone':
        return const AuthStatus.awaitingPhone();
      case 'awaiting_code':
        return AuthStatus.awaitingCode(json['phone'] as String? ?? '');
      case 'awaiting_password':
        return AuthStatus.awaitingPassword(json['hint'] as String?);
      case 'authorized':
        return AuthStatus.authorized(
          userId: (json['user_id'] as num?)?.toInt() ?? 0,
          fullName: json['full_name'] as String? ?? 'Telegram User',
          username: json['username'] as String?,
        );
      default:
        return const AuthStatus.disconnected();
    }
  }
}

class StorageChat {
  final int id;
  final String title;
  final String kind;
  final bool isCreator;
  final bool isPrivate;
  final int? memberCount;

  const StorageChat({
    required this.id,
    required this.title,
    required this.kind,
    this.isCreator = true,
    this.isPrivate = true,
    this.memberCount,
  });

  factory StorageChat.fromJson(Map<String, dynamic> json) {
    return StorageChat(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Chat',
      kind: json['kind'] as String? ?? 'group',
      isCreator: json['is_creator'] as bool? ?? true,
      isPrivate: json['is_private'] as bool? ?? true,
      memberCount: (json['member_count'] as num?)?.toInt(),
    );
  }
}

sealed class BridgeEvent {
  const BridgeEvent();

  static BridgeEvent? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      switch (decoded['type']) {
        case 'ready':
          return ReadyEvent(
            dbPath: decoded['db_path'] as String? ?? '',
            defaultChunkSize:
                (decoded['default_chunk_size'] as num?)?.toInt() ?? 0,
          );
        case 'auth_changed':
          final auth = decoded['auth'];
          if (auth is Map<String, dynamic>) {
            return AuthChangedEvent(AuthStatus.fromJson(auth));
          }
          return null;
        case 'snapshot':
          final snap = decoded['snapshot'];
          if (snap is Map<String, dynamic>) {
            return SnapshotEvent(DirectorySnapshot.fromJson(snap));
          }
          return null;
        case 'queue':
          final q = decoded['queue'];
          if (q is Map<String, dynamic>) {
            return QueueUpdateEvent(
              event: q['event'] as String? ?? '',
              taskId: (q['task_id'] as num?)?.toInt() ?? 0,
              fileId: (q['file_id'] as num?)?.toInt() ?? 0,
              kind: q['kind'] as String? ?? '',
              progress: (q['progress'] as num?)?.toDouble() ?? 0.0,
              seconds: (q['seconds'] as num?)?.toInt() ?? 0,
              fileLabel: q['file_label'] as String?,
              message: q['error'] as String? ?? q['file_label'] as String?,
            );
          }
          return null;
        case 'chats_listed':
          final chats = decoded['chats'];
          if (chats is List) {
            return ChatsListedEvent(
              chats
                  .whereType<Map<String, dynamic>>()
                  .map(StorageChat.fromJson)
                  .toList(growable: false),
            );
          }
          return null;
        case 'storage_chat_created':
          final chat = decoded['chat'];
          if (chat is Map<String, dynamic>) {
            return StorageChatCreatedEvent(StorageChat.fromJson(chat));
          }
          return null;
        case 'target_chat_changed':
          return TargetChatChangedEvent(
            (decoded['chat_id'] as num?)?.toInt(),
          );
        case 'info':
          return InfoEvent(decoded['message'] as String? ?? '');
        case 'error':
          return ErrorEvent(decoded['message'] as String? ?? 'Unknown error');
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

class ReadyEvent extends BridgeEvent {
  final String dbPath;
  final int defaultChunkSize;
  const ReadyEvent({required this.dbPath, required this.defaultChunkSize});
}

class AuthChangedEvent extends BridgeEvent {
  final AuthStatus auth;
  const AuthChangedEvent(this.auth);
}

class SnapshotEvent extends BridgeEvent {
  final DirectorySnapshot snapshot;
  const SnapshotEvent(this.snapshot);
}

class QueueUpdateEvent extends BridgeEvent {
  final String event;
  final int taskId;
  final int fileId;
  final String kind;
  final double progress;
  final int seconds;
  final String? fileLabel;
  final String? message;
  const QueueUpdateEvent({
    required this.event,
    this.taskId = 0,
    this.fileId = 0,
    this.kind = '',
    this.progress = 0.0,
    this.seconds = 0,
    this.fileLabel,
    this.message,
  });
}

class ChatsListedEvent extends BridgeEvent {
  final List<StorageChat> chats;
  const ChatsListedEvent(this.chats);
}

class StorageChatCreatedEvent extends BridgeEvent {
  final StorageChat chat;
  const StorageChatCreatedEvent(this.chat);
}

class TargetChatChangedEvent extends BridgeEvent {
  final int? chatId;
  const TargetChatChangedEvent(this.chatId);
}

class InfoEvent extends BridgeEvent {
  final String message;
  const InfoEvent(this.message);
}

class ErrorEvent extends BridgeEvent {
  final String message;
  const ErrorEvent(this.message);
}

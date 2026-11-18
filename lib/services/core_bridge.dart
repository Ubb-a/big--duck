import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import '../models/core_models.dart';

typedef _StartNative = Pointer<Void> Function(Pointer<Utf8> dbPath);
typedef _StartDart = Pointer<Void> Function(Pointer<Utf8> dbPath);

typedef _SendCommandNative = Int32 Function(
    Pointer<Void> runtime, Pointer<Utf8> cmdJson);
typedef _SendCommandDart = int Function(
    Pointer<Void> runtime, Pointer<Utf8> cmdJson);

typedef _PollEventNative = Pointer<Utf8> Function(Pointer<Void> runtime);
typedef _PollEventDart = Pointer<Utf8> Function(Pointer<Void> runtime);

typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

typedef _StopNative = Void Function(Pointer<Void> runtime);
typedef _StopDart = void Function(Pointer<Void> runtime);

class CoreBridge {
  DynamicLibrary? _lib;
  _StartDart? _start;
  _SendCommandDart? _sendCommand;
  _PollEventDart? _pollEvent;
  _FreeStringDart? _freeString;
  _StopDart? _stop;

  Pointer<Void>? _runtime;
  Timer? _pollTimer;
  final _eventsController = StreamController<BridgeEvent>.broadcast();

  Stream<BridgeEvent> get events => _eventsController.stream;

  bool get isNativeAvailable => _lib != null;
  bool get isStarted => _runtime != null && _runtime != nullptr;

  CoreBridge() {
    _tryLoadNative();
  }

  void _tryLoadNative() {
    try {
      final DynamicLibrary lib;
      if (Platform.isAndroid) {
        lib = DynamicLibrary.open('libteledrive_mobile_bridge.so');
      } else if (Platform.isIOS) {
        lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        lib = DynamicLibrary.open('teledrive_mobile_bridge.dll');
      } else if (Platform.isMacOS) {
        lib = DynamicLibrary.open('libteledrive_mobile_bridge.dylib');
      } else {
        lib = DynamicLibrary.open('libteledrive_mobile_bridge.so');
      }

      // Verify all required C-ABI symbols exist before marking available.
      _start = lib.lookupFunction<_StartNative, _StartDart>('bigduck_start');
      _sendCommand = lib.lookupFunction<_SendCommandNative, _SendCommandDart>(
          'bigduck_send_command');
      _pollEvent =
          lib.lookupFunction<_PollEventNative, _PollEventDart>('bigduck_poll_event');
      _freeString = lib.lookupFunction<_FreeStringNative, _FreeStringDart>(
          'bigduck_free_string');
      _stop = lib.lookupFunction<_StopNative, _StopDart>('bigduck_stop');
      _lib = lib;
    } catch (_) {
      _lib = null;
    }
  }

  Future<bool> start() async {
    if (!isNativeAvailable || isStarted) return isStarted;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = '${docsDir.path}${Platform.pathSeparator}bigduck.db';
    final pathPtr = dbPath.toNativeUtf8();
    try {
      _runtime = _start!(pathPtr);
    } finally {
      calloc.free(pathPtr);
    }

    if (_runtime == null || _runtime == nullptr) {
      _runtime = null;
      return false;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _drainEvents();
    });
    return true;
  }

  void _drainEvents() {
    final rt = _runtime;
    if (rt == null || rt == nullptr) return;
    // Drain up to 32 queued events per tick to keep UI responsive.
    for (var i = 0; i < 32; i++) {
      final ptr = _pollEvent!(rt);
      if (ptr == nullptr) break;
      try {
        final raw = ptr.toDartString();
        final parsed = BridgeEvent.tryParse(raw);
        if (parsed != null && !_eventsController.isClosed) {
          _eventsController.add(parsed);
        }
      } finally {
        _freeString!(ptr);
      }
    }
  }

  bool sendCommand(Map<String, dynamic> command) {
    final rt = _runtime;
    if (rt == null || rt == nullptr || _sendCommand == null) return false;
    final jsonStr = jsonEncode(command);
    final ptr = jsonStr.toNativeUtf8();
    try {
      return _sendCommand!(rt, ptr) == 0;
    } finally {
      calloc.free(ptr);
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    final rt = _runtime;
    if (rt != null && rt != nullptr && _stop != null) {
      _stop!(rt);
    }
    _runtime = null;
    _eventsController.close();
  }
}

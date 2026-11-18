import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareReceiverService {
  static const MethodChannel _method = MethodChannel('com.example.big_duck/share');
  static const EventChannel _events = EventChannel('com.example.big_duck/share_events');

  StreamSubscription<dynamic>? _sub;

  void startListening(void Function(List<String> paths) onFilesReceived) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _fetchInitial(onFilesReceived);
    try {
      _sub = _events.receiveBroadcastStream().listen((event) {
        final paths = _parsePaths(event);
        if (paths.isNotEmpty) {
          onFilesReceived(paths);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _fetchInitial(void Function(List<String> paths) onFilesReceived) async {
    try {
      final raw = await _method.invokeMethod<dynamic>('getInitialSharedFiles');
      final paths = _parsePaths(raw);
      if (paths.isNotEmpty) {
        onFilesReceived(paths);
      }
    } catch (_) {}
  }

  List<String> _parsePaths(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().where((p) => p.isNotEmpty).toList(growable: false);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

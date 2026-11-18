import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TransferNotificationService {
  static const String _progressChannelId = 'bigduck_transfers_progress';
  static const String _statusChannelId = 'bigduck_transfers_status';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Map<int, DateTime> _lastSentAt = {};
  final Map<int, int> _lastPct = {};

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_initialized || !_isMobilePlatform) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
        ),
      );
      _initialized = true;
    } catch (_) {
      // Safe no-op in tests or unsupported environments.
    }
  }

  Future<void> requestPermission() async {
    if (!_isMobilePlatform) return;
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: false, sound: false);
      }
    } catch (_) {}
  }

  Future<void> showProgress({
    required int taskId,
    required String fileName,
    required bool isUpload,
    required double progress,
    required bool isArabic,
  }) async {
    if (!_isMobilePlatform || taskId <= 0) return;
    await init();
    final pct = (progress * 100).clamp(0, 100).round();
    final now = DateTime.now();
    final prevAt = _lastSentAt[taskId];
    final prevPct = _lastPct[taskId] ?? -1;
    if (prevAt != null &&
        now.difference(prevAt).inMilliseconds < 500 &&
        (pct - prevPct).abs() < 4 &&
        pct < 100) {
      return;
    }
    _lastSentAt[taskId] = now;
    _lastPct[taskId] = pct;

    final title = isUpload
        ? (isArabic ? 'جاري التشفير والرفع ($pct%)' : 'Encrypting & uploading ($pct%)')
        : (isArabic ? 'جاري التنزيل وفك التشفير ($pct%)' : 'Downloading & decrypting ($pct%)');

    try {
      await _plugin.show(
        id: 10000 + taskId,
        title: title,
        body: fileName,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _progressChannelId,
            isArabic ? 'تقدم التحويلات' : 'Transfer progress',
            channelDescription: isArabic
                ? 'إشعارات الرفع والتنزيل المباشرة'
                : 'Live encrypted upload and download progress',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            ongoing: true,
            autoCancel: false,
            showProgress: true,
            maxProgress: 100,
            progress: pct,
            silent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBanner: false,
            presentSound: false,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> showPaused({
    required int taskId,
    required String fileName,
    required bool isArabic,
  }) async {
    if (!_isMobilePlatform || taskId <= 0) return;
    await init();
    _lastSentAt.remove(taskId);
    _lastPct.remove(taskId);
    try {
      await _plugin.show(
        id: 10000 + taskId,
        title: isArabic ? 'تم إيقاف التحويل مؤقتاً' : 'Transfer paused',
        body: fileName,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _progressChannelId,
            isArabic ? 'تقدم التحويلات' : 'Transfer progress',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            ongoing: false,
            autoCancel: true,
            silent: true,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> showCompleted({
    required int taskId,
    required String fileName,
    required bool isUpload,
    required bool isArabic,
  }) async {
    if (!_isMobilePlatform) return;
    await init();
    final nid = taskId > 0 ? 10000 + taskId : DateTime.now().millisecondsSinceEpoch % 100000;
    _lastSentAt.remove(taskId);
    _lastPct.remove(taskId);

    final title = isUpload
        ? (isArabic ? 'اكتمل الرفع المشفّر' : 'Encrypted upload complete')
        : (isArabic ? 'اكتمل التنزيل وفك التشفير' : 'Download & decrypt complete');

    try {
      await _plugin.show(
        id: nid,
        title: title,
        body: fileName,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _statusChannelId,
            isArabic ? 'حالة التحويلات' : 'Transfer status',
            channelDescription: isArabic
                ? 'تنبيهات اكتمال أو فشل التحويل'
                : 'Completion and failure alerts for transfers',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            onlyAlertOnce: false,
            ongoing: false,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> showFailed({
    required String fileLabel,
    required String error,
    required bool isArabic,
  }) async {
    if (!_isMobilePlatform) return;
    await init();
    final nid = 50000 + (fileLabel.hashCode.abs() % 10000);
    try {
      await _plugin.show(
        id: nid,
        title: isArabic ? 'فشل التحويل: $fileLabel' : 'Transfer failed: $fileLabel',
        body: error,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _statusChannelId,
            isArabic ? 'حالة التحويلات' : 'Transfer status',
            importance: Importance.high,
            priority: Priority.high,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
  }
}

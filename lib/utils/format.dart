import 'package:material_ui/material_ui.dart';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var idx = 0;
  while (value >= 1024 && idx < units.length - 1) {
    value /= 1024;
    idx++;
  }
  final decimals = idx == 0 ? 0 : (value >= 100 ? 0 : 1);
  return '${value.toStringAsFixed(decimals)} ${units[idx]}';
}

String formatSpeed(double bytesPerSec) {
  if (bytesPerSec <= 0 || !bytesPerSec.isFinite) return '';
  return '${formatBytes(bytesPerSec.round())}/s';
}

String formatEta(int seconds, {required bool ar}) {
  if (seconds <= 0) return '';
  if (seconds < 60) {
    return ar ? 'متبقي $secondsث' : '${seconds}s left';
  }
  if (seconds < 3600) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return ar ? 'متبقي $mد' : '${m}m left';
    return ar ? 'متبقي $mد $sث' : '${m}m ${s}s left';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return ar ? 'متبقي $hس $mد' : '${h}h ${m}m left';
}

String formatTimestamp(int unixSeconds) {
  if (unixSeconds <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

bool isImageFile(String mimeType, String name) {
  final lower = name.toLowerCase();
  return mimeType.startsWith('image/') ||
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.heic');
}

bool isPdfFile(String mimeType, String name) {
  final lower = name.toLowerCase();
  return mimeType == 'application/pdf' || lower.endsWith('.pdf');
}

bool isVideoFile(String mimeType, String name) {
  final lower = name.toLowerCase();
  return mimeType.startsWith('video/') ||
      lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm');
}

bool isAudioFile(String mimeType, String name) {
  final lower = name.toLowerCase();
  return mimeType.startsWith('audio/') ||
      lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.flac') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.aac') ||
      lower.endsWith('.ogg') ||
      lower.endsWith('.opus');
}

bool isPreviewableFile(String mimeType, String name) =>
    isImageFile(mimeType, name) ||
    isPdfFile(mimeType, name) ||
    isVideoFile(mimeType, name) ||
    isAudioFile(mimeType, name);

IconData iconForMimeOrName(String mimeType, String name) {
  final lower = name.toLowerCase();
  if (isImageFile(mimeType, name)) {
    return Icons.image_outlined;
  }
  if (mimeType.startsWith('video/') ||
      lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.mkv')) {
    return Icons.videocam_outlined;
  }
  if (mimeType.startsWith('audio/') ||
      lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.flac') ||
      lower.endsWith('.m4a')) {
    return Icons.audiotrack_outlined;
  }
  if (mimeType == 'application/pdf' || lower.endsWith('.pdf')) {
    return Icons.picture_as_pdf_outlined;
  }
  if (mimeType.contains('zip') ||
      mimeType.contains('archive') ||
      lower.endsWith('.zip') ||
      lower.endsWith('.tar') ||
      lower.endsWith('.gz') ||
      lower.endsWith('.7z') ||
      lower.endsWith('.rar')) {
    return Icons.folder_zip_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

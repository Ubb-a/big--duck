import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../models/core_models.dart';
import '../utils/format.dart';

class ThumbnailService {
  final Map<int, String?> _cachedPaths = {};
  final Map<int, Future<String?>> _pending = {};
  Future<void> _pdfLock = Future.value();

  String? peek(int fileId) => _cachedPaths[fileId];

  Future<T> _serializedPdf<T>(Future<T> Function() action) {
    final prev = _pdfLock;
    final current = prev.then((_) => action());
    _pdfLock = current.then((_) {}, onError: (_) {});
    return current;
  }

  Future<String?> resolveThumbnailPath({
    required FileRecord file,
    required Future<String?> Function(FileRecord) resolveLocalFile,
  }) {
    if (_cachedPaths.containsKey(file.id)) {
      return Future.value(_cachedPaths[file.id]);
    }
    return _pending.putIfAbsent(file.id, () async {
      try {
        final localPath = await resolveLocalFile(file);
        if (localPath == null) return null;

        if (isImageFile(file.mimeType, file.name)) {
          _cachedPaths[file.id] = localPath;
          return localPath;
        }

        if (isPdfFile(file.mimeType, file.name)) {
          final docsDir = await getApplicationDocumentsDirectory();
          final thumbDir =
              Directory('${docsDir.path}${Platform.pathSeparator}thumbnails');
          if (!await thumbDir.exists()) {
            await thumbDir.create(recursive: true);
          }
          final thumbFile = File(
            '${thumbDir.path}${Platform.pathSeparator}pdf_${file.id}_${file.size}.png',
          );
          if (await thumbFile.exists() && await thumbFile.length() > 0) {
            _cachedPaths[file.id] = thumbFile.path;
            return thumbFile.path;
          }

          final thumbPath = await _serializedPdf(() async {
            PdfDocument? doc;
            PdfPage? page;
            try {
              doc = await PdfDocument.openFile(localPath);
              if (doc.pagesCount < 1) return null;
              page = await doc.getPage(1);
              const targetW = 320.0;
              final ratio = page.width > 0 ? (page.height / page.width) : 1.35;
              final rendered = await page.render(
                width: targetW,
                height: (targetW * ratio).clamp(160.0, 520.0),
                format: PdfPageImageFormat.png,
                backgroundColor: '#FFFFFF',
              );
              if (rendered != null && rendered.bytes.isNotEmpty) {
                await thumbFile.writeAsBytes(rendered.bytes, flush: true);
                return thumbFile.path;
              }
              return null;
            } finally {
              await page?.close();
              await doc?.close();
            }
          });
          if (thumbPath != null) {
            _cachedPaths[file.id] = thumbPath;
            return thumbPath;
          }
        }
        return null;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(file.id);
      }
    });
  }

  Future<void> clearCache() async {
    _cachedPaths.clear();
    _pending.clear();
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final thumbDir =
          Directory('${docsDir.path}${Platform.pathSeparator}thumbnails');
      if (await thumbDir.exists()) {
        await thumbDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

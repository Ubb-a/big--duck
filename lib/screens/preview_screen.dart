import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/vault_surface.dart';

enum _ImageBackdrop { dark, grid, paper }

class PreviewScreen extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;
  final FileRecord file;
  final String? initialLocalPath;

  const PreviewScreen({
    super.key,
    required this.palette,
    required this.controller,
    required this.file,
    this.initialLocalPath,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  String? _localPath;
  String? _expectedDownloadPath;
  bool _checking = true;
  bool _isDemoSample = false;
  bool _awaitingFreshTask = false;
  PdfControllerPinch? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;

  // Image darkroom viewer state
  late final TransformationController _transformController;
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _doubleTapLocalPosition;
  double _currentScale = 1.0;
  int _quarterTurns = 0;
  bool _showChrome = true;
  _ImageBackdrop _backdrop = _ImageBackdrop.dark;

  // Image pixel dimensions resolved from local file
  int? _imageWidth;
  int? _imageHeight;
  ImageStream? _metadataStream;
  ImageStreamListener? _metadataListener;

  // Video & Audio darkroom playback state
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoMuted = false;
  double _mediaSpeed = 1.0;

  AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _audioPosSub;
  StreamSubscription<Duration?>? _audioDurSub;
  StreamSubscription<PlayerState>? _audioStateSub;
  Duration _audioPos = Duration.zero;
  Duration _audioDur = Duration.zero;
  bool _audioPlaying = false;
  String? _mediaError;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController()
      ..addListener(_onTransformChanged);
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final anim = _zoomAnimation;
        if (anim != null) {
          _transformController.value = anim.value;
        }
      });
    widget.controller.addListener(_onControllerUpdate);
    final preset = widget.initialLocalPath;
    if (preset != null && File(preset).existsSync()) {
      _localPath = preset;
      _checking = false;
      _initMediaForPath(preset);
    } else {
      _preparePreview();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _clearMetadataListener();
    _pdfController?.dispose();
    _videoController?.dispose();
    _audioPosSub?.cancel();
    _audioDurSub?.cancel();
    _audioStateSub?.cancel();
    _audioPlayer?.dispose();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _zoomAnimController.dispose();
    super.dispose();
  }

  void _clearMetadataListener() {
    if (_metadataStream != null && _metadataListener != null) {
      _metadataStream!.removeListener(_metadataListener!);
    }
    _metadataStream = null;
    _metadataListener = null;
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01 && mounted) {
      setState(() => _currentScale = scale);
    }
  }

  Future<void> _preparePreview() async {
    if (mounted) {
      setState(() {
        _checking = true;
        _awaitingFreshTask = false;
      });
    }

    final existing = await widget.controller.resolveLocalPath(widget.file);
    if (!mounted) return;
    if (existing != null) {
      _openLocalFile(existing);
      return;
    }

    if (widget.controller.demoMode || !widget.controller.hasNativeCore) {
      setState(() {
        _checking = false;
        _isDemoSample = true;
      });
      return;
    }

    final dest = await widget.controller.downloadFile(widget.file);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _awaitingFreshTask = true;
      _expectedDownloadPath = dest;
    });
  }

  void _initMediaForPath(String path) {
    if (isPdfFile(widget.file.mimeType, widget.file.name)) {
      _pdfController?.dispose();
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(path),
      );
    } else if (isImageFile(widget.file.mimeType, widget.file.name)) {
      _resolveImageMetadata(path);
    } else if (isVideoFile(widget.file.mimeType, widget.file.name)) {
      _initVideo(path);
    } else if (isAudioFile(widget.file.mimeType, widget.file.name)) {
      _initAudio(path);
    }
  }

  Future<void> _initVideo(String path) async {
    _videoController?.dispose();
    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;
    _videoReady = false;
    _mediaError = null;
    try {
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      await controller.play();
      if (mounted) {
        setState(() => _videoReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mediaError = '$e');
      }
    }
  }

  Future<void> _initAudio(String path) async {
    await _audioPosSub?.cancel();
    await _audioDurSub?.cancel();
    await _audioStateSub?.cancel();
    await _audioPlayer?.dispose();
    final player = AudioPlayer();
    _audioPlayer = player;
    _mediaError = null;
    try {
      _audioDurSub = player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _audioDur = d);
      });
      _audioPosSub = player.positionStream.listen((pos) {
        if (mounted) setState(() => _audioPos = pos);
      });
      _audioStateSub = player.playerStateStream.listen((st) {
        if (mounted) {
          setState(() {
            _audioPlaying = st.playing &&
                st.processingState != ProcessingState.completed;
          });
        }
      });
      final loadedDur = await player.setFilePath(path);
      if (mounted && loadedDur != null) {
        setState(() => _audioDur = loadedDur);
      }
      await player.play();
    } catch (e) {
      if (mounted) {
        setState(() => _mediaError = '$e');
      }
    }
  }

  void _openLocalFile(String path) {
    _initMediaForPath(path);
    setState(() {
      _checking = false;
      _isDemoSample = false;
      _awaitingFreshTask = false;
      _localPath = path;
    });
  }

  void _resolveImageMetadata(String path) {
    _clearMetadataListener();
    final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageWidth = info.image.width;
            _imageHeight = info.image.height;
          });
        }
        stream.removeListener(listener);
        if (identical(_metadataStream, stream)) {
          _metadataStream = null;
          _metadataListener = null;
        }
      },
      onError: (Object _, StackTrace? _) {
        stream.removeListener(listener);
        if (identical(_metadataStream, stream)) {
          _metadataStream = null;
          _metadataListener = null;
        }
      },
    );
    _metadataStream = stream;
    _metadataListener = listener;
    stream.addListener(listener);
  }

  void _onControllerUpdate() {
    if (_localPath != null) return;
    final task = widget.controller.latestDownloadTaskFor(widget.file.id);
    if (_awaitingFreshTask &&
        task != null &&
        (task.state == TaskState.queued || task.state == TaskState.running)) {
      _awaitingFreshTask = false;
    }
    if (task != null && task.state == TaskState.completed) {
      final path = _expectedDownloadPath;
      if (path != null && File(path).existsSync()) {
        _openLocalFile(path);
      } else {
        widget.controller.resolveLocalPath(widget.file).then((resolved) {
          if (mounted && resolved != null) {
            _openLocalFile(resolved);
          }
        });
      }
    }
  }

  Future<void> _shareFile() async {
    final path = _localPath;
    if (path == null) return;
    HapticFeedback.selectionClick();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: widget.file.name),
    );
  }

  Matrix4 _clampedZoomMatrix(Offset focalPoint, double scale, Size viewport) {
    var dx = -focalPoint.dx * (scale - 1.0);
    var dy = -focalPoint.dy * (scale - 1.0);
    if (viewport.width > 0 && viewport.height > 0 && scale > 1.0) {
      dx = dx.clamp(-(scale - 1.0) * viewport.width, 0.0);
      dy = dy.clamp(-(scale - 1.0) * viewport.height, 0.0);
    }
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  void _animateTransformTo(Matrix4 target) {
    final duration = vaultMotion(context, 180);
    if (duration == Duration.zero) {
      _transformController.value = target;
      return;
    }
    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _zoomAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _zoomAnimController.forward(from: 0.0);
  }

  void _handleDoubleTap(Size viewport) {
    HapticFeedback.selectionClick();
    if (_currentScale > 1.05) {
      _animateTransformTo(Matrix4.identity());
      return;
    }
    final focal = _doubleTapLocalPosition ??
        Offset(viewport.width / 2, viewport.height / 2);
    _animateTransformTo(_clampedZoomMatrix(focal, 2.5, viewport));
  }

  void _toggleZoomPill(Size viewport) {
    HapticFeedback.selectionClick();
    if ((_currentScale - 1.0).abs() > 0.03) {
      _animateTransformTo(Matrix4.identity());
    } else {
      final center = Offset(viewport.width / 2, viewport.height / 2);
      _animateTransformTo(_clampedZoomMatrix(center, 2.0, viewport));
    }
  }

  void _rotateImage() {
    HapticFeedback.selectionClick();
    _transformController.value = Matrix4.identity();
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  void _cycleBackdrop() {
    HapticFeedback.selectionClick();
    setState(() {
      _backdrop = switch (_backdrop) {
        _ImageBackdrop.dark => _ImageBackdrop.grid,
        _ImageBackdrop.grid => _ImageBackdrop.paper,
        _ImageBackdrop.paper => _ImageBackdrop.dark,
      };
    });
  }

  void _showInspectorSheet(AppPalette v, bool isAr) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VaultSheetShell(
        palette: v,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  iconForMimeOrName(widget.file.mimeType, widget.file.name),
                  size: 22,
                  color: v.cobalt,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.heading(v, isAr, size: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAr ? 'بيانات الملف الأرشيفية' : 'Archival file manifest',
                        style: VaultText.body(v, isAr, size: 12, color: v.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            VaultSurface(
              palette: v,
              borderRadius: VaultRadii.sm,
              backgroundColor: v.surfaceAlt,
              child: Column(
                children: [
                  _InspectorRow(
                    palette: v,
                    isArabic: isAr,
                    label: isAr ? 'النوع' : 'MIME type',
                    value: widget.file.mimeType,
                    showDivider: false,
                  ),
                  if (_imageWidth != null && _imageHeight != null)
                    _InspectorRow(
                      palette: v,
                      isArabic: isAr,
                      label: isAr ? 'الأبعاد' : 'Dimensions',
                      value: '$_imageWidth × $_imageHeight px',
                    ),
                  _InspectorRow(
                    palette: v,
                    isArabic: isAr,
                    label: isAr ? 'الحجم' : 'Size',
                    value: '${formatBytes(widget.file.size)} (${widget.file.size} B)',
                  ),
                  if (widget.file.createdAt > 0)
                    _InspectorRow(
                      palette: v,
                      isArabic: isAr,
                      label: isAr ? 'تاريخ الحفظ' : 'Stored',
                      value: formatTimestamp(widget.file.createdAt),
                    ),
                  _InspectorRow(
                    palette: v,
                    isArabic: isAr,
                    label: isAr ? 'التشفير' : 'Encryption',
                    value: widget.file.isEncrypted
                        ? 'Argon2id + AES-256-GCM'
                        : (isAr ? 'غير مشفر' : 'Unencrypted'),
                    valueColor: widget.file.isEncrypted ? v.signal : v.muted,
                  ),
                ],
              ),
            ),
            if (widget.file.sha256.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: v.surfaceAlt,
                  borderRadius: BorderRadius.circular(VaultRadii.xs),
                  border: Border.all(color: v.rule),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHA-256',
                          style: VaultText.mono(v, size: 11, color: v.muted),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.file.sha256),
                            );
                            HapticFeedback.selectionClick();
                            widget.controller.showToast(
                              isAr ? 'تم نسخ بصمة SHA-256' : 'Copied SHA-256 hash',
                            );
                            Navigator.pop(ctx);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_all_outlined,
                                  size: 14, color: v.cobalt),
                              const SizedBox(width: 4),
                              Text(
                                isAr ? 'نسخ' : 'Copy',
                                style: VaultText.body(
                                  v,
                                  isAr,
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: v.cobalt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      widget.file.sha256,
                      style: VaultText.mono(v, size: 11.5, color: v.ink),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = AppPalette.resolve(Brightness.dark);
    final isAr = widget.controller.isArabic;
    final isPdf = isPdfFile(widget.file.mimeType, widget.file.name);
    final isImage = isImageFile(widget.file.mimeType, widget.file.name);
    final isVideo = isVideoFile(widget.file.mimeType, widget.file.name);
    final isAudio = isAudioFile(widget.file.mimeType, widget.file.name);
    final task = widget.controller.latestDownloadTaskFor(widget.file.id);
    final motion = vaultMotion(context, 180);
    final hasBottomDockMedia =
        _localPath != null && (isImage || isVideo) && !_checking && !_isDemoSample;
    final canHideChrome = _localPath != null && (isImage || isVideo);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: v.ground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Positioned.fill(
                  child: _buildBody(
                    v,
                    isAr,
                    isPdf,
                    isImage,
                    isVideo,
                    isAudio,
                    task,
                    viewport,
                  ),
                ),

                // Top archival darkroom header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: canHideChrome && !_showChrome,
                    child: AnimatedSlide(
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      offset: (canHideChrome && !_showChrome)
                          ? const Offset(0, -1.0)
                          : Offset.zero,
                      child: AnimatedOpacity(
                        duration: motion,
                        opacity: (canHideChrome && !_showChrome) ? 0.0 : 1.0,
                        child: _PreviewHeaderBar(
                          palette: v,
                          isArabic: isAr,
                          file: widget.file,
                          isPdf: isPdf,
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          imageWidth: _imageWidth,
                          imageHeight: _imageHeight,
                          onBack: () => Navigator.pop(context),
                          onInspect: () => _showInspectorSheet(v, isAr),
                          onShare: (_localPath != null && !isImage && !isVideo)
                              ? _shareFile
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Signal Vault Image or Video Control Dock
                if (hasBottomDockMedia)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !_showChrome,
                      child: AnimatedSlide(
                        duration: motion,
                        curve: Curves.easeOutCubic,
                        offset: _showChrome
                            ? Offset.zero
                            : const Offset(0, 1.0),
                        child: AnimatedOpacity(
                          duration: motion,
                          opacity: _showChrome ? 1.0 : 0.0,
                          child: isImage
                              ? _ImageControlDock(
                                  palette: v,
                                  isArabic: isAr,
                                  scale: _currentScale,
                                  backdrop: _backdrop,
                                  quarterTurns: _quarterTurns,
                                  onToggleZoom: () => _toggleZoomPill(viewport),
                                  onRotate: _rotateImage,
                                  onCycleBackdrop: _cycleBackdrop,
                                  onShare: _shareFile,
                                )
                              : _VideoControlDock(
                                  palette: v,
                                  isArabic: isAr,
                                  controller: _videoController,
                                  muted: _videoMuted,
                                  speed: _mediaSpeed,
                                  onTogglePlay: _toggleVideoPlay,
                                  onToggleMute: _toggleVideoMute,
                                  onCycleSpeed: _cycleVideoSpeed,
                                  onShare: _shareFile,
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleVideoPlay() {
    final vc = _videoController;
    if (vc == null || !_videoReady) return;
    HapticFeedback.selectionClick();
    if (vc.value.isPlaying) {
      vc.pause();
    } else {
      vc.play();
    }
    setState(() {});
  }

  void _toggleVideoMute() {
    final vc = _videoController;
    if (vc == null) return;
    HapticFeedback.selectionClick();
    final nextMuted = !_videoMuted;
    vc.setVolume(nextMuted ? 0.0 : 1.0);
    setState(() => _videoMuted = nextMuted);
  }

  void _cycleVideoSpeed() {
    final vc = _videoController;
    if (vc == null) return;
    HapticFeedback.selectionClick();
    const speeds = [1.0, 1.25, 1.5, 2.0];
    final next = speeds[(speeds.indexOf(_mediaSpeed) + 1) % speeds.length];
    vc.setPlaybackSpeed(next);
    setState(() => _mediaSpeed = next);
  }

  void _cycleAudioSpeed() {
    final ap = _audioPlayer;
    if (ap == null) return;
    HapticFeedback.selectionClick();
    const speeds = [1.0, 1.25, 1.5, 2.0];
    final next = speeds[(speeds.indexOf(_mediaSpeed) + 1) % speeds.length];
    ap.setSpeed(next);
    setState(() => _mediaSpeed = next);
  }

  Widget _buildBody(
    AppPalette v,
    bool isAr,
    bool isPdf,
    bool isImage,
    bool isVideo,
    bool isAudio,
    TaskRecord? task,
    Size viewport,
  ) {
    if (_checking) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: v.signal),
            const SizedBox(height: 14),
            Text(
              isAr ? 'جاري التحقق من الملف...' : 'Preparing encrypted file...',
              style: VaultText.body(v, isAr, size: 13.5, color: v.muted),
            ),
          ],
        ),
      );
    }

    if (_localPath != null) {
      if (isImage) {
        return _buildImageStage(v, isAr, viewport);
      }

      if (isVideo) {
        return _buildVideoStage(v, isAr);
      }

      if (isAudio) {
        return _buildAudioStage(v, isAr);
      }

      if (isPdf && _pdfController != null) {
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 64),
            child: PdfViewPinch(
              controller: _pdfController!,
              onDocumentLoaded: (doc) {
                if (mounted) {
                  setState(() => _totalPages = doc.pagesCount);
                }
              },
              onPageChanged: (page) {
                if (mounted) {
                  setState(() => _currentPage = page);
                }
              },
            ),
          ),
        );
      }
    }

    if (_isDemoSample) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: VaultSurface(
            palette: v,
            borderRadius: VaultRadii.md,
            elevated: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  size: 28,
                  color: v.signal,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.file.name,
                  textAlign: TextAlign.center,
                  style: VaultText.heading(v, isAr, size: 15.5),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'ملف تجريبي للعرض. ارفع أي ملف PDF أو صورة حقيقية من جهازك لمعاينتها مباشرة داخل التطبيق.'
                      : 'Demo placeholder file. Upload any real PDF or photo from your device to preview it natively.',
                  textAlign: TextAlign.center,
                  style: VaultText.body(v, isAr, size: 13, color: v.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = _awaitingFreshTask
        ? 0.0
        : (task?.progress ?? 0.0).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final failed = !_awaitingFreshTask && task?.state == TaskState.failed;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: VaultSurface(
          palette: v,
          borderRadius: VaultRadii.md,
          elevated: true,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failed ? Icons.error_outline : Icons.lock_open_outlined,
                size: 26,
                color: failed ? v.danger : v.signal,
              ),
              const SizedBox(height: 12),
              Text(
                failed
                    ? (isAr ? 'فشل التنزيل' : 'Download failed')
                    : (isAr
                        ? 'جاري التنزيل وفك التشفير'
                        : 'Downloading and decrypting'),
                style: VaultText.heading(v, isAr, size: 15.5),
              ),
              if (!failed) ...[
                const SizedBox(height: 4),
                Text(
                  '$pct%',
                  style: VaultText.tabular(
                    v,
                    isAr,
                    size: 13,
                    color: v.signal,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(VaultRadii.pill),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 5,
                    backgroundColor: v.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(v.signal),
                  ),
                ),
              ] else ...[
                if (task?.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    task!.error!,
                    textAlign: TextAlign.center,
                    style: VaultText.body(v, isAr, size: 12.5, color: v.danger),
                  ),
                ],
                const SizedBox(height: 16),
                VaultTap(
                  onTap: _preparePreview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: v.signal,
                      borderRadius: BorderRadius.circular(VaultRadii.sm),
                    ),
                    child: Text(
                      isAr ? 'إعادة المحاولة' : 'Retry',
                      style: VaultText.body(
                        v,
                        isAr,
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: v.signalInk,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageStage(AppPalette v, bool isAr, Size viewport) {
    final isZoomed = _currentScale > 1.03;
    final framePadding = (_showChrome && !isZoomed)
        ? EdgeInsets.fromLTRB(
            14,
            MediaQuery.paddingOf(context).top + 74,
            14,
            MediaQuery.paddingOf(context).bottom + 92,
          )
        : EdgeInsets.zero;

    final stageColor = switch (_backdrop) {
      _ImageBackdrop.dark => v.ground,
      _ImageBackdrop.grid => v.surface,
      _ImageBackdrop.paper => const Color(0xFFECEFF4),
    };

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _showChrome = !_showChrome),
      onDoubleTapDown: (details) =>
          _doubleTapLocalPosition = details.localPosition,
      onDoubleTap: () => _handleDoubleTap(viewport),
      child: AnimatedContainer(
        duration: vaultMotion(context, 180),
        color: stageColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_backdrop == _ImageBackdrop.grid)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CheckerboardPainter(
                    lightTile: v.surfaceAlt,
                    darkTile: v.surface,
                  ),
                ),
              ),
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.85,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(24),
              child: AnimatedPadding(
                duration: vaultMotion(context, 180),
                curve: Curves.easeOutCubic,
                padding: framePadding,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: _quarterTurns,
                    child: Container(
                      decoration: _backdrop == _ImageBackdrop.paper
                          ? BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD3D9E3),
                                width: 1,
                              ),
                            )
                          : BoxDecoration(
                              border: Border.all(
                                color: v.rule.withValues(alpha: 0.55),
                                width: 1,
                              ),
                            ),
                      child: Image.file(
                        File(_localPath!),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, error, _) => Container(
                          padding: const EdgeInsets.all(20),
                          color: v.surface,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined,
                                  size: 36, color: v.danger),
                              const SizedBox(height: 10),
                              Text(
                                isAr
                                    ? 'تعذر عرض الصورة'
                                    : 'Could not render image',
                                style: VaultText.heading(v, isAr, size: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$error',
                                style: VaultText.body(v, isAr,
                                    size: 12, color: v.muted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoStage(AppPalette v, bool isAr) {
    final vc = _videoController;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showChrome = !_showChrome),
      onDoubleTap: _toggleVideoPlay,
      child: Container(
        color: v.ground,
        alignment: Alignment.center,
        padding: EdgeInsets.fromLTRB(
          12,
          _showChrome ? MediaQuery.paddingOf(context).top + 74 : 12,
          12,
          _showChrome ? MediaQuery.paddingOf(context).bottom + 116 : 12,
        ),
        child: _mediaError != null
            ? VaultSurface(
                palette: v,
                borderRadius: VaultRadii.md,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_outlined,
                        size: 36, color: v.danger),
                    const SizedBox(height: 10),
                    Text(
                      isAr ? 'تعذر تشغيل الفيديو' : 'Could not play video',
                      style: VaultText.heading(v, isAr, size: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mediaError!,
                      textAlign: TextAlign.center,
                      style: VaultText.body(v, isAr, size: 12, color: v.muted),
                    ),
                  ],
                ),
              )
            : (vc == null || !_videoReady)
                ? CircularProgressIndicator(color: v.signal)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: v.rule, width: 1),
                        ),
                        child: AspectRatio(
                          aspectRatio: vc.value.aspectRatio > 0
                              ? vc.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(vc),
                        ),
                      ),
                      if (!vc.value.isPlaying)
                        GestureDetector(
                          onTap: _toggleVideoPlay,
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: v.signal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: v.surface, width: 2),
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              size: 34,
                              color: v.signalInk,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAudioStage(AppPalette v, bool isAr) {
    final totalMs = _audioDur.inMilliseconds;
    final posMs =
        totalMs > 0 ? _audioPos.inMilliseconds.clamp(0, totalMs) : 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: VaultSurface(
            palette: v,
            borderRadius: VaultRadii.md,
            elevated: true,
            padding: const EdgeInsets.all(24),
            child: _mediaError != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_off_outlined,
                          size: 38, color: v.danger),
                      const SizedBox(height: 12),
                      Text(
                        isAr ? 'تعذر تشغيل الملف الصوتي' : 'Could not play audio',
                        style: VaultText.heading(v, isAr, size: 15.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _mediaError!,
                        textAlign: TextAlign.center,
                        style: VaultText.body(v, isAr, size: 12, color: v.muted),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _audioPlaying ? v.signalSoft : v.cobaltSoft,
                          borderRadius: BorderRadius.circular(VaultRadii.md),
                          border: Border.all(
                            color: (_audioPlaying ? v.signal : v.cobalt)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          _audioPlaying
                              ? Icons.graphic_eq
                              : Icons.audiotrack_outlined,
                          size: 34,
                          color: _audioPlaying ? v.signal : v.cobalt,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.file.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.heading(v, isAr, size: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.file.isEncrypted
                            ? (isAr
                                ? 'تشغيل مشفر محلياً'
                                : 'Locally decrypted audio')
                            : (isAr ? 'ملف صوتي' : 'Audio track'),
                        style: VaultText.body(v, isAr, size: 12.5, color: v.muted),
                      ),
                      const SizedBox(height: 18),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          activeTrackColor: v.signal,
                          inactiveTrackColor: v.surfaceAlt,
                          thumbColor: v.signal,
                        ),
                        child: Slider(
                          value: totalMs > 0 ? posMs / totalMs : 0.0,
                          onChanged: totalMs > 0
                              ? (ratio) {
                                  _audioPlayer?.seek(
                                    Duration(
                                      milliseconds: (ratio * totalMs).round(),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatMediaDuration(_audioPos),
                              style: VaultText.tabular(v, isAr, size: 12),
                            ),
                            Text(
                              _formatMediaDuration(_audioDur),
                              style: VaultText.tabular(v, isAr, size: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DockIconButton(
                            palette: v,
                            icon: Icons.replay_10,
                            active: false,
                            tooltip: '-10s',
                            onTap: () {
                              final next = _audioPos - const Duration(seconds: 10);
                              _audioPlayer?.seek(
                                next < Duration.zero ? Duration.zero : next,
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          VaultTap(
                            onTap: () {
                              final ap = _audioPlayer;
                              if (ap == null) return;
                              HapticFeedback.selectionClick();
                              if (_audioPlaying) {
                                ap.pause();
                              } else {
                                ap.play();
                              }
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: v.signal,
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.md),
                              ),
                              child: Icon(
                                _audioPlaying ? Icons.pause : Icons.play_arrow,
                                size: 30,
                                color: v.signalInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          _DockIconButton(
                            palette: v,
                            icon: Icons.forward_10,
                            active: false,
                            tooltip: '+10s',
                            onTap: () {
                              final next = _audioPos + const Duration(seconds: 10);
                              _audioPlayer?.seek(
                                next > _audioDur ? _audioDur : next,
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          VaultTap(
                            onTap: _cycleAudioSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: v.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.sm),
                                border: Border.all(color: v.rule),
                              ),
                              child: Text(
                                '${_mediaSpeed == _mediaSpeed.roundToDouble() ? _mediaSpeed.toInt() : _mediaSpeed}x',
                                style: VaultText.tabular(v, isAr,
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: v.ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

String _formatMediaDuration(Duration d) {
  final totalSecs = d.inSeconds.clamp(0, 359999);
  final hours = totalSecs ~/ 3600;
  final mins = (totalSecs % 3600) ~/ 60;
  final secs = totalSecs % 60;
  final mStr = mins.toString().padLeft(2, '0');
  final sStr = secs.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mStr:$sStr' : '$mStr:$sStr';
}

class _PreviewHeaderBar extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final FileRecord file;
  final bool isPdf;
  final int currentPage;
  final int totalPages;
  final int? imageWidth;
  final int? imageHeight;
  final VoidCallback onBack;
  final VoidCallback onInspect;
  final VoidCallback? onShare;

  const _PreviewHeaderBar({
    required this.palette,
    required this.isArabic,
    required this.file,
    required this.isPdf,
    required this.currentPage,
    required this.totalPages,
    required this.imageWidth,
    required this.imageHeight,
    required this.onBack,
    required this.onInspect,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    return Container(
      decoration: BoxDecoration(
        color: v.surface.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: v.rule, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back, color: v.ink, size: 22),
                tooltip: isArabic ? 'رجوع' : 'Back',
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.heading(v, isArabic, size: 14.5),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (file.isEncrypted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: v.signalSoft,
                              borderRadius:
                                  BorderRadius.circular(VaultRadii.xs),
                              border: Border.all(
                                color: v.signal.withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 10.5, color: v.signal),
                                const SizedBox(width: 4),
                                Text(
                                  isArabic ? 'مشفّر' : 'AES-256',
                                  style: VaultText.body(
                                    v,
                                    isArabic,
                                    size: 10.5,
                                    weight: FontWeight.w600,
                                    color: v.signal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (imageWidth != null && imageHeight != null) ...[
                          Text(
                            '$imageWidth×$imageHeight',
                            style: VaultText.tabular(v, isArabic, size: 11.5),
                          ),
                          const SizedBox(width: 8),
                        ] else if (isPdf && totalPages > 0) ...[
                          Text(
                            '$currentPage / $totalPages',
                            style: VaultText.tabular(v, isArabic, size: 11.5),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            formatBytes(file.size),
                            overflow: TextOverflow.ellipsis,
                            style: VaultText.tabular(v, isArabic, size: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onInspect,
                icon: Icon(Icons.info_outline, color: v.muted, size: 21),
                tooltip: isArabic ? 'تفاصيل الملف' : 'File details',
              ),
              if (onShare != null)
                IconButton(
                  onPressed: onShare,
                  icon: Icon(Icons.ios_share, color: v.cobalt, size: 20),
                  tooltip: isArabic ? 'مشاركة' : 'Share',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageControlDock extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final double scale;
  final _ImageBackdrop backdrop;
  final int quarterTurns;
  final VoidCallback onToggleZoom;
  final VoidCallback onRotate;
  final VoidCallback onCycleBackdrop;
  final VoidCallback onShare;

  const _ImageControlDock({
    required this.palette,
    required this.isArabic,
    required this.scale,
    required this.backdrop,
    required this.quarterTurns,
    required this.onToggleZoom,
    required this.onRotate,
    required this.onCycleBackdrop,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    final zoomPct = (scale * 100).round();
    final zoomed = (scale - 1.0).abs() > 0.03;

    final backdropIcon = switch (backdrop) {
      _ImageBackdrop.dark => Icons.dark_mode_outlined,
      _ImageBackdrop.grid => Icons.grid_on_outlined,
      _ImageBackdrop.paper => Icons.light_mode_outlined,
    };
    final backdropTooltip = switch (backdrop) {
      _ImageBackdrop.dark => isArabic ? 'خلفية داكنة' : 'Dark canvas',
      _ImageBackdrop.grid => isArabic ? 'شبكة الشفافية' : 'Transparency grid',
      _ImageBackdrop.paper => isArabic ? 'ورق فاتح' : 'Light paper',
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: VaultSurface(
          palette: v,
          borderRadius: VaultRadii.dock,
          elevated: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Zoom indicator / quick reset or 2x toggle
              VaultTap(
                onTap: onToggleZoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: zoomed ? v.signalSoft : v.surfaceAlt,
                    borderRadius: BorderRadius.circular(VaultRadii.sm),
                    border: Border.all(
                      color: zoomed ? v.signal.withValues(alpha: 0.65) : v.rule,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        zoomed ? Icons.zoom_out_map : Icons.zoom_in_outlined,
                        size: 16,
                        color: zoomed ? v.signal : v.ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$zoomPct%',
                        style: VaultText.tabular(
                          v,
                          isArabic,
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: zoomed ? v.signal : v.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Rotate 90 degrees
              _DockIconButton(
                palette: v,
                icon: Icons.rotate_90_degrees_cw_outlined,
                active: quarterTurns != 0,
                tooltip: isArabic ? 'تدوير 90°' : 'Rotate 90°',
                onTap: onRotate,
              ),
              const SizedBox(width: 6),

              // Canvas backdrop cycle (darkroom / transparency grid / paper)
              _DockIconButton(
                palette: v,
                icon: backdropIcon,
                active: backdrop != _ImageBackdrop.dark,
                tooltip: backdropTooltip,
                onTap: onCycleBackdrop,
              ),

              const Spacer(),

              // Primary share / export action
              VaultTap(
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: v.cobaltSoft,
                    borderRadius: BorderRadius.circular(VaultRadii.sm),
                    border: Border.all(
                      color: v.cobalt.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share, size: 16, color: v.cobalt),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'مشاركة' : 'Share',
                        style: VaultText.body(
                          v,
                          isArabic,
                          size: 13,
                          weight: FontWeight.w600,
                          color: v.cobalt,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _DockIconButton({
    required this.palette,
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    return Tooltip(
      message: tooltip,
      child: VaultTap(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 36,
          decoration: BoxDecoration(
            color: active ? v.cobaltSoft : v.surfaceAlt,
            borderRadius: BorderRadius.circular(VaultRadii.sm),
            border: Border.all(
              color: active ? v.cobalt.withValues(alpha: 0.5) : v.rule,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? v.cobalt : v.ink,
          ),
        ),
      ),
    );
  }
}

class _InspectorRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  const _InspectorRow({
    required this.palette,
    required this.isArabic,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: v.rule, width: 1))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: VaultText.body(v, isArabic, size: 12.5, color: v.muted),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VaultText.tabular(
                v,
                isArabic,
                size: 12.5,
                weight: FontWeight.w600,
                color: valueColor ?? v.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  final Color lightTile;
  final Color darkTile;

  const _CheckerboardPainter({
    required this.lightTile,
    required this.darkTile,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tile = 18.0;
    final darkPaint = Paint()..color = darkTile;
    final lightPaint = Paint()..color = lightTile;
    canvas.drawRect(Offset.zero & size, darkPaint);

    final cols = (size.width / tile).ceil();
    final rows = (size.height / tile).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(c * tile, r * tile, tile, tile),
            lightPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) =>
      oldDelegate.lightTile != lightTile || oldDelegate.darkTile != darkTile;
}

class _VideoControlDock extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final VideoPlayerController? controller;
  final bool muted;
  final double speed;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onCycleSpeed;
  final VoidCallback onShare;

  const _VideoControlDock({
    required this.palette,
    required this.isArabic,
    required this.controller,
    required this.muted,
    required this.speed,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onCycleSpeed,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    final vc = controller;
    final initialized = vc != null && vc.value.isInitialized;
    final dur = initialized ? vc.value.duration : Duration.zero;
    final pos = initialized ? vc.value.position : Duration.zero;
    final playing = initialized && vc.value.isPlaying;
    final totalMs = dur.inMilliseconds;
    final posMs = totalMs > 0 ? pos.inMilliseconds.clamp(0, totalMs) : 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: VaultSurface(
          palette: v,
          borderRadius: VaultRadii.dock,
          elevated: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _formatMediaDuration(pos),
                    style: VaultText.tabular(v, isArabic, size: 11.5),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.5),
                        activeTrackColor: v.signal,
                        inactiveTrackColor: v.surfaceAlt,
                        thumbColor: v.signal,
                      ),
                      child: Slider(
                        value: totalMs > 0 ? posMs / totalMs : 0.0,
                        onChanged: totalMs > 0
                            ? (ratio) {
                                vc?.seekTo(Duration(
                                  milliseconds: (ratio * totalMs).round(),
                                ));
                              }
                            : null,
                      ),
                    ),
                  ),
                  Text(
                    _formatMediaDuration(dur),
                    style: VaultText.tabular(v, isArabic, size: 11.5),
                  ),
                ],
              ),
              Row(
                children: [
                  VaultTap(
                    onTap: onTogglePlay,
                    child: Container(
                      width: 38,
                      height: 36,
                      decoration: BoxDecoration(
                        color: v.signal,
                        borderRadius: BorderRadius.circular(VaultRadii.sm),
                      ),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        size: 20,
                        color: v.signalInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DockIconButton(
                    palette: v,
                    icon: muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                    active: muted,
                    tooltip: isArabic ? 'كتم الصوت' : 'Mute',
                    onTap: onToggleMute,
                  ),
                  const SizedBox(width: 8),
                  VaultTap(
                    onTap: onCycleSpeed,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v.surfaceAlt,
                        borderRadius: BorderRadius.circular(VaultRadii.sm),
                        border: Border.all(color: v.rule),
                      ),
                      child: Text(
                        '${speed == speed.roundToDouble() ? speed.toInt() : speed}x',
                        style: VaultText.tabular(
                          v,
                          isArabic,
                          size: 12,
                          weight: FontWeight.w700,
                          color: v.ink,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  VaultTap(
                    onTap: onShare,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: v.cobaltSoft,
                        borderRadius: BorderRadius.circular(VaultRadii.sm),
                        border: Border.all(
                          color: v.cobalt.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ios_share, size: 16, color: v.cobalt),
                          const SizedBox(width: 6),
                          Text(
                            isArabic ? 'مشاركة' : 'Share',
                            style: VaultText.body(
                              v,
                              isArabic,
                              size: 13,
                              weight: FontWeight.w600,
                              color: v.cobalt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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

  late final TransformationController _transformController;
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _doubleTapLocalPosition;
  double _currentScale = 1.0;
  int _quarterTurns = 0;
  bool _showChrome = true;
  _ImageBackdrop _backdrop = _ImageBackdrop.dark;

  int? _imageWidth;
  int? _imageHeight;
  ImageStream? _metadataStream;
  ImageStreamListener? _metadataListener;

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
      duration: const Duration(milliseconds: 220),
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
    if (path == null) {
      widget.controller.downloadFile(widget.file);
      return;
    }
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
    final duration = vaultMotion(context, 250);
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
        curve: Curves.easeOut,
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

  void _showDarkroomMenu(AppPalette v, bool isAr, Size viewport) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: VaultSheetShell(
          palette: v,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isImageFile(widget.file.mimeType, widget.file.name)) ...[
                _DarkMenuTile(
                  palette: v,
                  isArabic: isAr,
                  icon: Icons.rotate_90_degrees_cw_outlined,
                  title: isAr ? 'تدوير 90°' : 'Rotate 90°',
                  onTap: () {
                    Navigator.pop(ctx);
                    _rotateImage();
                  },
                ),
                const SizedBox(height: 8),
                _DarkMenuTile(
                  palette: v,
                  isArabic: isAr,
                  icon: Icons.layers_outlined,
                  title: isAr ? 'تغيير خلفية المعاينة' : 'Cycle canvas backdrop',
                  onTap: () {
                    Navigator.pop(ctx);
                    _cycleBackdrop();
                  },
                ),
                const SizedBox(height: 8),
                _DarkMenuTile(
                  palette: v,
                  isArabic: isAr,
                  icon: Icons.zoom_in_rounded,
                  title: isAr ? 'تبديل التكبير' : 'Toggle 100% / 200% zoom',
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleZoomPill(viewport);
                  },
                ),
                const SizedBox(height: 8),
              ],
              _DarkMenuTile(
                palette: v,
                isArabic: isAr,
                icon: Icons.info_outline_rounded,
                title: isAr ? 'بيانات الملف المشفر' : 'Encrypted file info',
                onTap: () {
                  Navigator.pop(ctx);
                  _showInfoSheet(v, isAr);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(AppPalette v, bool isAr) {
    final s = widget.controller.strings;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: VaultDialogShell(
          palette: v,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.deleteConfirmTitle,
                  style: VaultText.heading(v, isAr, size: 18)),
              const SizedBox(height: 10),
              Text(
                s.deleteConfirmDesc(1),
                style: VaultText.body(v, isAr, size: 13.5, color: v.secondary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: VaultPillButton(
                      palette: v,
                      isArabic: isAr,
                      variant: VaultPillVariant.secondary,
                      height: 44,
                      label: s.cancel,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VaultPillButton(
                      palette: v,
                      isArabic: isAr,
                      variant: VaultPillVariant.danger,
                      height: 44,
                      label: s.deleteAction,
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.controller.deleteFile(widget.file.id);
                        Navigator.pop(context);
                      },
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

  void _showInfoSheet(AppPalette v, bool isAr) {
    HapticFeedback.lightImpact();
    final s = widget.controller.strings;
    final chunkBytes = widget.controller.chunkSizeMiB * 1024 * 1024;
    final chunkCount = widget.file.size <= 0
        ? 1
        : (widget.file.size / chunkBytes).ceil().clamp(1, 9999);
    final sha = widget.file.sha256;
    final truncatedSha =
        sha.length > 22 ? '${sha.substring(0, 12)}…${sha.substring(sha.length - 10)}' : sha;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: VaultSheetShell(
          palette: v,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: v.glassFill,
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                      border: Border.all(color: v.glassBorder),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      iconForMimeOrName(widget.file.mimeType, widget.file.name),
                      size: 20,
                      color: v.champagne,
                    ),
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
                          style: VaultText.heading(v, isAr, size: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.file.mimeType,
                          style: VaultText.mono(v, size: 11, color: v.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              VaultSurface(
                palette: v,
                borderRadius: VaultRadii.md,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _InspectorRow(
                      palette: v,
                      isArabic: isAr,
                      label: isAr ? 'الحجم' : 'File size',
                      value: formatBytes(widget.file.size),
                      showDivider: false,
                    ),
                    if (_imageWidth != null && _imageHeight != null)
                      _InspectorRow(
                        palette: v,
                        isArabic: isAr,
                        label: isAr ? 'الأبعاد' : 'Dimensions',
                        value: '$_imageWidth×$_imageHeight px',
                      ),
                    _InspectorRow(
                      palette: v,
                      isArabic: isAr,
                      label: s.chunkCountLabel,
                      value: '$chunkCount',
                    ),
                    _InspectorRow(
                      palette: v,
                      isArabic: isAr,
                      label: s.encryptionStatusLabel,
                      value: widget.file.isEncrypted
                          ? s.aesVerifiedLabel
                          : s.keyUnsetBadge,
                      valueColor:
                          widget.file.isEncrypted ? v.signalGreen : v.secondary,
                      leadingIcon: widget.file.isEncrypted
                          ? Icons.verified_outlined
                          : null,
                    ),
                    if (widget.file.createdAt > 0)
                      _InspectorRow(
                        palette: v,
                        isArabic: isAr,
                        label: s.uploadDateLabel,
                        value: formatTimestamp(widget.file.createdAt),
                      ),
                  ],
                ),
              ),
              if (sha.isNotEmpty) ...[
                const SizedBox(height: 12),
                VaultSurface(
                  palette: v,
                  borderRadius: VaultRadii.md,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHA-256',
                              style: VaultText.mono(v,
                                  size: 10.5, color: v.secondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              truncatedSha,
                              style: VaultText.mono(v, size: 12, color: v.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      VaultMonoChip(
                        palette: v,
                        label: isAr ? 'نسخ' : 'Copy',
                        icon: Icons.copy_rounded,
                        textColor: v.champagne,
                        borderColor: v.champagne.withValues(alpha: 0.4),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: sha));
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          widget.controller.showToast(
                            isAr ? 'تم نسخ بصمة SHA-256' : 'Copied SHA-256 hash',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always deep Obsidian Darkroom even when app is in Ivory Luxury light mode.
    final v = AppPalette.darkroom();
    final isAr = widget.controller.isArabic;
    final s = widget.controller.strings;
    final isPdf = isPdfFile(widget.file.mimeType, widget.file.name);
    final isImage = isImageFile(widget.file.mimeType, widget.file.name);
    final isVideo = isVideoFile(widget.file.mimeType, widget.file.name);
    final isAudio = isAudioFile(widget.file.mimeType, widget.file.name);
    final task = widget.controller.latestDownloadTaskFor(widget.file.id);
    final motion = vaultMotion(context, 250);
    final isDecrypting = _checking || (_localPath == null && !_isDemoSample);
    final canHideChrome = _localPath != null && (isImage || isVideo);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: v.canvas,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = Size(constraints.maxWidth, constraints.maxHeight);
              final progressVal = _awaitingFreshTask
                  ? 0.0
                  : (task?.progress ?? 0.0).clamp(0.0, 1.0);

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

                  // Thin champagne decrypting progress line at the very top
                  if (isDecrypting &&
                      !(!_awaitingFreshTask && task?.state == TaskState.failed))
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VaultProgressBar(
                              palette: v,
                              progress: progressVal > 0 ? progressVal : 0.35,
                              tone: VaultProgressTone.champagne,
                              height: 3,
                            ),
                            const SizedBox(height: 68),
                            VaultMonoChip(
                              palette: v,
                              label: s.decryptingMono,
                              dotColor: v.champagne,
                              textColor: v.champagne,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Floating PDF page indicator pill ("3 / 24")
                  if (isPdf && _totalPages > 0 && _showChrome)
                    Positioned(
                      bottom: 94,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: VaultMonoChip(
                          palette: v,
                          label: '$_currentPage / $_totalPages',
                          textColor: v.ink,
                          backgroundColor: v.scrim,
                          borderColor: v.glassTopLeftBorder,
                        ),
                      ),
                    ),

                  // Top liquid-glass bar (Back · File Name · Menu)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: canHideChrome && !_showChrome,
                      child: AnimatedSlide(
                        duration: motion,
                        curve: Curves.easeOut,
                        offset: (canHideChrome && !_showChrome)
                            ? const Offset(0, -1.0)
                            : Offset.zero,
                        child: AnimatedOpacity(
                          duration: motion,
                          opacity: (canHideChrome && !_showChrome) ? 0.0 : 1.0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: VaultSurface(
                                palette: v,
                                borderRadius: VaultRadii.pill,
                                elevated: true,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: Icon(Icons.arrow_back_rounded,
                                          color: v.ink, size: 20),
                                      tooltip: isAr ? 'رجوع' : 'Back',
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            widget.file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: VaultText.body(
                                              v,
                                              isAr,
                                              size: 14,
                                              weight: FontWeight.w600,
                                              applyArabicScale: false,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (widget.file.isEncrypted) ...[
                                                Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 10.5,
                                                  color: v.signalGreen,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'AES-256',
                                                  style: VaultText.mono(
                                                    v,
                                                    size: 10,
                                                    color: v.signalGreen,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                formatBytes(widget.file.size),
                                                style: VaultText.mono(v,
                                                    size: 10,
                                                    color: v.secondary),
                                              ),
                                              if (isImage &&
                                                  _localPath != null) ...[
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _toggleZoomPill(viewport),
                                                  child: Text(
                                                    '${(_currentScale * 100).round()}%',
                                                    style: VaultText.mono(
                                                      v,
                                                      size: 10,
                                                      color: v.champagne,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _showDarkroomMenu(v, isAr, viewport),
                                      icon: Icon(Icons.more_horiz_rounded,
                                          color: v.ink, size: 21),
                                      tooltip: isAr ? 'خيارات' : 'Menu',
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

                  // Bottom liquid-glass bar (Info · Download · Share · Delete) + swipe-up trigger
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: canHideChrome && !_showChrome,
                      child: AnimatedSlide(
                        duration: motion,
                        curve: Curves.easeOut,
                        offset: (canHideChrome && !_showChrome)
                            ? const Offset(0, 1.0)
                            : Offset.zero,
                        child: AnimatedOpacity(
                          duration: motion,
                          opacity: (canHideChrome && !_showChrome) ? 0.0 : 1.0,
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              child: GestureDetector(
                                onVerticalDragEnd: (details) {
                                  if ((details.primaryVelocity ?? 0) < -180) {
                                    _showInfoSheet(v, isAr);
                                  }
                                },
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 340),
                                    child: VaultSurface(
                                      palette: v,
                                      borderRadius: VaultRadii.pill,
                                      elevated: true,
                                      borderColor: v.glassTopLeftBorder,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          VaultQuickActionCircle(
                                            palette: v,
                                            tone: VaultQuickTone.champagne,
                                            icon: Icons.info_outline_rounded,
                                            tooltip: s.infoLabel,
                                            onTap: () =>
                                                _showInfoSheet(v, isAr),
                                          ),
                                          VaultQuickActionCircle(
                                            palette: v,
                                            tone: VaultQuickTone.slate,
                                            icon: Icons.download_outlined,
                                            tooltip: s.downloadAction,
                                            onTap: () => widget.controller
                                                .downloadFile(widget.file),
                                          ),
                                          VaultQuickActionCircle(
                                            palette: v,
                                            tone: VaultQuickTone.mint,
                                            icon: Icons.ios_share_rounded,
                                            tooltip: s.shareLabel,
                                            onTap: _shareFile,
                                          ),
                                          VaultQuickActionCircle(
                                            palette: v,
                                            tone: VaultQuickTone.coral,
                                            icon: Icons.delete_outline_rounded,
                                            tooltip: s.deleteAction,
                                            onTap: () =>
                                                _showDeleteConfirm(v, isAr),
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
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
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
      return const SizedBox.expand();
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 78, 16, 90),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(VaultRadii.tile),
              child: Container(
                color: Colors.white,
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
            borderRadius: VaultRadii.card,
            elevated: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconForMimeOrName(widget.file.mimeType, widget.file.name),
                  size: 32,
                  color: v.champagne,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.file.name,
                  textAlign: TextAlign.center,
                  style: VaultText.heading(v, isAr, size: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'ملف تجريبي للعرض. ارفع ملفاً حقيقياً لمعاينته مباشرة بعد فك التشفير.'
                      : 'Demo vault placeholder. Upload a real file to preview it directly after local decryption.',
                  textAlign: TextAlign.center,
                  style: VaultText.body(v, isAr, size: 13.5, color: v.secondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final failed = !_awaitingFreshTask && task?.state == TaskState.failed;
    if (failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: VaultSurface(
            palette: v,
            borderRadius: VaultRadii.card,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 30, color: v.coral),
                const SizedBox(height: 12),
                Text(
                  isAr ? 'فشل فك التشفير والتنزيل' : 'Decryption failed',
                  style: VaultText.heading(v, isAr, size: 17),
                ),
                if (task?.error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    task!.error!,
                    textAlign: TextAlign.center,
                    style: VaultText.body(v, isAr, size: 13, color: v.coral),
                  ),
                ],
                const SizedBox(height: 18),
                VaultPillButton(
                  palette: v,
                  isArabic: isAr,
                  expand: false,
                  height: 44,
                  label: widget.controller.strings.retryAction,
                  onPressed: _preparePreview,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.expand();
  }

  Widget _buildImageStage(AppPalette v, bool isAr, Size viewport) {
    final stageColor = switch (_backdrop) {
      _ImageBackdrop.dark => v.canvas,
      _ImageBackdrop.grid => v.cardSolid,
      _ImageBackdrop.paper => const Color(0xFFF7F6F3),
    };

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _showChrome = !_showChrome),
      onDoubleTapDown: (details) =>
          _doubleTapLocalPosition = details.localPosition,
      onDoubleTap: () => _handleDoubleTap(viewport),
      child: AnimatedContainer(
        duration: vaultMotion(context, 250),
        color: stageColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_backdrop == _ImageBackdrop.grid)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CheckerboardPainter(
                    lightTile: const Color(0xFF222226),
                    darkTile: v.cardSolid,
                  ),
                ),
              ),
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.85,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(24),
              child: Center(
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.file(
                    File(_localPath!),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, error, _) => Container(
                      padding: const EdgeInsets.all(20),
                      color: v.cardSolid,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 36, color: v.coral),
                          const SizedBox(height: 10),
                          Text(
                            isAr ? 'تعذر عرض الصورة' : 'Could not render image',
                            style: VaultText.heading(v, isAr, size: 15),
                          ),
                        ],
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
    final initialized = vc != null && vc.value.isInitialized && _videoReady;
    final dur = initialized ? vc.value.duration : Duration.zero;
    final pos = initialized ? vc.value.position : Duration.zero;
    final totalMs = dur.inMilliseconds;
    final posMs = totalMs > 0 ? pos.inMilliseconds.clamp(0, totalMs) : 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showChrome = !_showChrome),
      onDoubleTap: _toggleVideoPlay,
      child: Container(
        color: v.canvas,
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(12, 82, 12, 110),
        child: _mediaError != null
            ? VaultSurface(
                palette: v,
                borderRadius: VaultRadii.card,
                padding: const EdgeInsets.all(20),
                child: Text(
                  _mediaError!,
                  textAlign: TextAlign.center,
                  style: VaultText.body(v, isAr, size: 13, color: v.coral),
                ),
              )
            : !initialized
                ? CircularProgressIndicator(color: v.champagne, strokeWidth: 2)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(VaultRadii.md),
                        child: AspectRatio(
                          aspectRatio: vc.value.aspectRatio > 0
                              ? vc.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(vc),
                        ),
                      ),
                      // Minimal glass play button
                      if (!vc.value.isPlaying || _showChrome)
                        VaultTap(
                          onTap: _toggleVideoPlay,
                          child: VaultSurface(
                            palette: v,
                            borderRadius: VaultRadii.pill,
                            padding: const EdgeInsets.all(18),
                            child: Icon(
                              vc.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 34,
                              color: v.champagne,
                            ),
                          ),
                        ),
                      if (_showChrome)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: VaultSurface(
                            palette: v,
                            borderRadius: VaultRadii.pill,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  _formatMediaDuration(pos),
                                  style: VaultText.mono(v,
                                      size: 11, color: v.ink),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.5,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5.5),
                                      activeTrackColor: v.champagne,
                                      inactiveTrackColor: v.glassBorder,
                                      thumbColor: v.champagne,
                                    ),
                                    child: Slider(
                                      value: totalMs > 0 ? posMs / totalMs : 0.0,
                                      onChanged: totalMs > 0
                                          ? (ratio) {
                                              vc.seekTo(Duration(
                                                milliseconds:
                                                    (ratio * totalMs).round(),
                                              ));
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatMediaDuration(dur),
                                  style: VaultText.mono(v,
                                      size: 11, color: v.secondary),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _toggleVideoMute,
                                  child: Icon(
                                    _videoMuted
                                        ? Icons.volume_off_outlined
                                        : Icons.volume_up_outlined,
                                    size: 17,
                                    color: v.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _cycleVideoSpeed,
                                  child: Text(
                                    '${_mediaSpeed == _mediaSpeed.roundToDouble() ? _mediaSpeed.toInt() : _mediaSpeed}x',
                                    style: VaultText.mono(v,
                                        size: 11, color: v.champagne),
                                  ),
                                ),
                              ],
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
    final progressRatio = totalMs > 0 ? posMs / totalMs : 0.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: VaultSurface(
            palette: v,
            borderRadius: VaultRadii.card,
            elevated: true,
            padding: const EdgeInsets.all(24),
            child: _mediaError != null
                ? Text(
                    _mediaError!,
                    textAlign: TextAlign.center,
                    style: VaultText.body(v, isAr, size: 13, color: v.coral),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: v.glassFill,
                          borderRadius: BorderRadius.circular(VaultRadii.tile),
                          border: Border.all(color: v.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.audiotrack_rounded,
                          size: 30,
                          color: v.champagne,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.file.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.heading(v, isAr, size: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.file.isEncrypted
                            ? 'AES-256-GCM'
                            : (isAr ? 'ملف صوتي' : 'Audio'),
                        style: VaultText.mono(v,
                            size: 11, color: v.signalGreen),
                      ),
                      const SizedBox(height: 22),

                      // Calm waveform visualization
                      SizedBox(
                        height: 46,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _CalmWaveformPainter(
                            progress: progressRatio,
                            activeColor: v.champagne,
                            inactiveColor: v.glassBorder,
                          ),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5.5),
                          activeTrackColor: v.champagne,
                          inactiveTrackColor: v.glassBorder,
                          thumbColor: v.champagne,
                        ),
                        child: Slider(
                          value: progressRatio,
                          onChanged: totalMs > 0
                              ? (ratio) {
                                  _audioPlayer?.seek(Duration(
                                    milliseconds: (ratio * totalMs).round(),
                                  ));
                                }
                              : null,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatMediaDuration(_audioPos),
                            style: VaultText.mono(v, size: 11, color: v.secondary),
                          ),
                          Text(
                            _formatMediaDuration(_audioDur),
                            style: VaultText.mono(v, size: 11, color: v.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VaultQuickActionCircle(
                            palette: v,
                            tone: VaultQuickTone.slate,
                            icon: Icons.replay_10_rounded,
                            onTap: () {
                              final next =
                                  _audioPos - const Duration(seconds: 10);
                              _audioPlayer?.seek(
                                  next < Duration.zero ? Duration.zero : next);
                            },
                          ),
                          const SizedBox(width: 16),
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
                                color: v.primaryBtnFill,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _audioPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 28,
                                color: v.primaryBtnInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          VaultQuickActionCircle(
                            palette: v,
                            tone: VaultQuickTone.champagne,
                            icon: Icons.forward_10_rounded,
                            onTap: () {
                              final next =
                                  _audioPos + const Duration(seconds: 10);
                              _audioPlayer?.seek(
                                  next > _audioDur ? _audioDur : next);
                            },
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
}

class _DarkMenuTile extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DarkMenuTile({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    return VaultTap(
      onTap: onTap,
      child: VaultSurface(
        palette: v,
        borderRadius: VaultRadii.md,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: v.champagne),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: VaultText.body(v, isArabic,
                    size: 14, weight: FontWeight.w500, applyArabicScale: false),
              ),
            ),
          ],
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
  final IconData? leadingIcon;
  final bool showDivider;

  const _InspectorRow({
    required this.palette,
    required this.isArabic,
    required this.label,
    required this.value,
    this.valueColor,
    this.leadingIcon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: v.glassBorder, width: 1))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: VaultText.body(v, isArabic,
                size: 13, color: v.secondary, applyArabicScale: false),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon,
                      size: 15, color: valueColor ?? v.signalGreen),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.monoText(
                      v,
                      value,
                      size: 12,
                      weight: FontWeight.w600,
                      color: valueColor ?? v.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalmWaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _CalmWaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 36;
    final barW = size.width / (barCount * 1.8);
    final gap = barW * 0.8;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final norm = i / barCount;
      final amp = 0.25 +
          0.65 *
              ((math.sin(i * 0.72).abs() * 0.65) +
                  (math.cos(i * 1.35).abs() * 0.35));
      final barH = (size.height * amp).clamp(6.0, size.height);
      final x = i * (barW + gap);
      final y = (size.height - barH) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, barH),
        const Radius.circular(3),
      );
      canvas.drawRRect(
          rect, norm <= progress ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(_CalmWaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor;
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

String _formatMediaDuration(Duration d) {
  final totalSecs = d.inSeconds.clamp(0, 359999);
  final hours = totalSecs ~/ 3600;
  final mins = (totalSecs % 3600) ~/ 60;
  final secs = totalSecs % 60;
  final mStr = mins.toString().padLeft(2, '0');
  final sStr = secs.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mStr:$sStr' : '$mStr:$sStr';
}

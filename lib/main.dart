import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import 'screens/auth_screen.dart';
import 'screens/files_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfers_screen.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';
import 'widgets/floating_tab_bar.dart';
import 'widgets/vault_motion_widgets.dart';
import 'widgets/vault_surface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BigDuckApp());
}

class BigDuckApp extends StatefulWidget {
  final AppController? controller;

  const BigDuckApp({super.key, this.controller});

  @override
  State<BigDuckApp> createState() => _BigDuckAppState();
}

class _BigDuckAppState extends State<BigDuckApp>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final bool _ownsController;
  late final AppController _controller;
  late final AnimationController _themeRevealCtrl;
  late final AnimationController _langFadeCtrl;
  int _lastThemeChangeId = 0;
  bool _lastArabic = true;
  Brightness? _prevRevealBrightness;
  Offset _revealOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController();
    _lastThemeChangeId = _controller.themeChangeId;
    _lastArabic = _controller.isArabic;
    _themeRevealCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.slow,
    );
    _langFadeCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.base,
    );
    _controller.addListener(_onControllerTick);
  }

  void _onControllerTick() {
    if (!mounted) return;
    if (_controller.themeChangeId != _lastThemeChangeId) {
      _lastThemeChangeId = _controller.themeChangeId;
      final origin = _controller.themeRevealOrigin;
      if (origin != null && !vaultMotion.isReduced(context)) {
        _revealOrigin = origin;
        _themeRevealCtrl.forward(from: 0.0).then((_) {
          if (mounted) setState(() => _prevRevealBrightness = null);
        });
      }
    }
    if (_controller.isArabic != _lastArabic) {
      _lastArabic = _controller.isArabic;
      if (!vaultMotion.isReduced(context)) {
        _langFadeCtrl.forward(from: 0.0);
      }
    }
  }

  Brightness _resolveBrightness(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _controller.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerTick);
    _themeRevealCtrl.dispose();
    _langFadeCtrl.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final fontFamily = VaultText.fontFamily(_controller.isArabic);
        return MaterialApp(
          title: 'BIG DUCK',
          debugShowCheckedModeBanner: false,
          themeMode: _controller.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            fontFamily: fontFamily,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: fontFamily,
            useMaterial3: true,
          ),
          home: Builder(
            builder: (innerCtx) {
              final currentBrightness =
                  _resolveBrightness(innerCtx, _controller.themeMode);
              if (!_themeRevealCtrl.isAnimating &&
                  _prevRevealBrightness == null) {
                _prevRevealBrightness = currentBrightness;
              }

              final currentPalette = AppPalette.resolve(currentBrightness);
              final prevBrightness = _prevRevealBrightness ?? currentBrightness;

              final activeRoot = Directionality(
                textDirection: _controller.isArabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: AnimatedBuilder(
                  animation: _langFadeCtrl,
                  builder: (_, child) {
                    final op = _langFadeCtrl.isAnimating
                        ? 1.0 - (math.sin(_langFadeCtrl.value * math.pi) * 0.22)
                        : 1.0;
                    return Opacity(opacity: op, child: child);
                  },
                  child: _RootShell(
                    key: const ValueKey('vault_root_shell'),
                    palette: currentPalette,
                    controller: _controller,
                  ),
                ),
              );

              if (_themeRevealCtrl.isAnimating &&
                  !vaultMotion.isReduced(innerCtx) &&
                  prevBrightness != currentBrightness) {
                final oldPalette = AppPalette.resolve(prevBrightness);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: HeroMode(
                        enabled: false,
                        child: Directionality(
                          textDirection: _controller.isArabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: _RootShell(
                            palette: oldPalette,
                            controller: _controller,
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _themeRevealCtrl,
                      builder: (context, child) {
                        final t = vaultMotion.emphasized
                            .transform(_themeRevealCtrl.value);
                        return ClipPath(
                          clipper: VaultCircularRevealClipper(
                            origin: _revealOrigin,
                            fraction: t,
                          ),
                          child: child,
                        );
                      },
                      child: activeRoot,
                    ),
                  ],
                );
              }

              _prevRevealBrightness = currentBrightness;
              return activeRoot;
            },
          ),
        );
      },
    );
  }
}

class _RootShell extends StatelessWidget {
  final AppPalette palette;
  final AppController controller;

  const _RootShell({
    super.key,
    required this.palette,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final strings = controller.strings;
    final reduced = vaultMotion.isReduced(context);

    final isAuthView = !controller.authStatus.isAuthorized &&
        !controller.hasSavedSession &&
        !controller.demoMode;
    final isLockView = !isAuthView && controller.isLocked;

    Widget stage;
    if (isAuthView) {
      stage = AuthScreen(
        key: const ValueKey('route_auth'),
        palette: palette,
        controller: controller,
      );
    } else if (isLockView) {
      stage = Stack(
        key: const ValueKey('route_lock'),
        fit: StackFit.expand,
        children: [
          if (controller.lockWithBlurBackdrop)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 24),
              duration: vaultMotion.duration(context, vaultMotion.base),
              curve: vaultMotion.standard,
              builder: (context, sigma, _) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: Container(
                  color: palette.canvas.withValues(alpha: 0.45),
                ),
              ),
            ),
          LockScreen(palette: palette, controller: controller),
        ],
      );
    } else {
      stage = _VaultMainStage(
        key: const ValueKey('route_vault'),
        palette: palette,
        controller: controller,
        strings: strings,
      );
    }

    return AnimatedSwitcher(
      duration: vaultMotion.duration(context, vaultMotion.slow),
      switchInCurve: vaultMotion.emphasized,
      switchOutCurve: vaultMotion.exit,
      transitionBuilder: (child, animation) {
        if (reduced) {
          return FadeTransition(opacity: animation, child: child);
        }
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: stage,
    );
  }
}

class _VaultMainStage extends StatelessWidget {
  final AppPalette palette;
  final AppController controller;
  final dynamic strings;

  const _VaultMainStage({
    super.key,
    required this.palette,
    required this.controller,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final catalogFiles = controller.snapshot.allFiles.isNotEmpty
        ? controller.snapshot.allFiles
        : controller.snapshot.files;
    final fileNamesById = <int, String>{
      for (final f in catalogFiles) f.id: f.name,
    };
    final fileSizesById = <int, int>{
      for (final f in catalogFiles) f.id: f.size,
    };
    for (final t in controller.snapshot.tasks) {
      final name = fileNamesById.putIfAbsent(
        t.fileId,
        () => controller.fileNameForId(t.fileId),
      );
      fileSizesById.putIfAbsent(
        t.fileId,
        () => controller.fileSizeForId(t.fileId, fallbackName: name),
      );
    }

    const bottomPad = 96.0;
    final pages = [
      FilesScreen(
        key: const ValueKey(MobileTab.files),
        palette: palette,
        controller: controller,
        isRecent: false,
        bottomPadding: bottomPad,
      ),
      TransfersScreen(
        key: const ValueKey(MobileTab.transfers),
        palette: palette,
        strings: strings,
        tasks: controller.snapshot.tasks,
        fileNamesById: fileNamesById,
        fileSizesById: fileSizesById,
        taskSpeedsById: controller.taskSpeedsById,
        chunkSizeMiB: controller.chunkSizeMiB,
        floodWaitSeconds: controller.floodWaitSeconds,
        bottomPadding: bottomPad,
        onPauseTask: controller.pauseTask,
        onResumeTask: controller.resumeTask,
        onRetryTask: controller.retryTask,
      ),
      FilesScreen(
        key: const ValueKey(MobileTab.recent),
        palette: palette,
        controller: controller,
        isRecent: true,
        bottomPadding: bottomPad,
      ),
      SettingsScreen(
        key: const ValueKey(MobileTab.settings),
        palette: palette,
        controller: controller,
        bottomPadding: bottomPad,
      ),
    ];

    final navHidden = controller.navHiddenByScroll && !controller.isSelecting;
    final navDur = vaultMotion.duration(context, vaultMotion.fast);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: VaultCanvasBackdrop(
        palette: palette,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              RepaintBoundary(
                child: IndexedStack(
                  index: controller.activeTab.index,
                  children: [
                    for (int i = 0; i < pages.length; i++)
                      HeroMode(
                        enabled: controller.activeTab.index == i,
                        child: pages[i],
                      ),
                  ],
                ),
              ),

              // Floating bottom nav: hides downward 24px on scroll down, always visible during multi-select
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedSlide(
                    offset: (navHidden && !vaultMotion.isReduced(context))
                        ? const Offset(0, 0.45)
                        : Offset.zero,
                    duration: navDur,
                    curve: vaultMotion.standard,
                    child: AnimatedOpacity(
                      opacity: navHidden ? 0.0 : 1.0,
                      duration: navDur,
                      child: IgnorePointer(
                        ignoring: navHidden,
                        child: FloatingTabBar(
                          palette: palette,
                          strings: strings,
                          activeTab: controller.activeTab,
                          activeTransferCount: controller.activeTransferCount,
                          dimmed: controller.isSelecting,
                          onSelect: controller.setTab,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Liquid-glass floating Toast: slide 16px emphasized in, dot pulse, stay 2.5s, 180ms exit fade
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: _VaultToastBanner(
                  palette: palette,
                  controller: controller,
                ),
              ),

              // Share-Sheet Receive ("Save to Vault" / "احفظ في الخزنة") modal
              if (controller.pendingShareSheetPaths.isNotEmpty)
                Positioned.fill(
                  child: _ShareSheetReceiveOverlay(
                    palette: palette,
                    controller: controller,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultToastBanner extends StatelessWidget {
  final AppPalette palette;
  final AppController controller;

  const _VaultToastBanner({
    required this.palette,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final visible = controller.toastMessage != null;
    final enterDur = vaultMotion.duration(context, vaultMotion.base);
    final exitDur = vaultMotion.duration(context, vaultMotion.fast);
    final reduced = vaultMotion.isReduced(context);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: (visible || reduced) ? Offset.zero : const Offset(0, -0.4),
        duration: visible ? enterDur : exitDur,
        curve: visible ? vaultMotion.emphasized : vaultMotion.exit,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: visible ? enterDur : exitDur,
          curve: visible ? vaultMotion.emphasized : vaultMotion.exit,
          child: Center(
            child: VaultSurface(
              palette: palette,
              borderRadius: VaultRadii.pill,
              elevated: true,
              borderColor: palette.glassTopLeftBorder,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SingleEntryPulseDot(
                    color: controller.toastIsError
                        ? palette.coral
                        : palette.signalGreen,
                    triggerKey: controller.toastMessage,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      controller.toastMessage ?? '',
                      textAlign: TextAlign.center,
                      style: VaultText.body(
                        palette,
                        controller.isArabic,
                        size: 13,
                        weight: FontWeight.w500,
                        applyArabicScale: false,
                      ),
                    ),
                  ),
                  if (controller.toastActionLabel != null &&
                      controller.onToastAction != null) ...[
                    const SizedBox(width: 10),
                    VaultTap(
                      onTap: controller.triggerToastAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.champagneSoft,
                          borderRadius:
                              BorderRadius.circular(VaultRadii.pill),
                          border: Border.all(
                            color: palette.champagne.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          controller.toastActionLabel!,
                          style: VaultText.monoText(
                            palette,
                            controller.toastActionLabel!,
                            size: 11,
                            weight: FontWeight.w600,
                            color: palette.champagne,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleEntryPulseDot extends StatefulWidget {
  final Color color;
  final String? triggerKey;

  const _SingleEntryPulseDot({
    required this.color,
    required this.triggerKey,
  });

  @override
  State<_SingleEntryPulseDot> createState() => _SingleEntryPulseDotState();
}

class _SingleEntryPulseDotState extends State<_SingleEntryPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: vaultMotion.slow,
    );
    if (widget.triggerKey != null) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _SingleEntryPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerKey != null &&
        widget.triggerKey != oldWidget.triggerKey &&
        !vaultMotion.isReduced(context)) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (vaultMotion.isReduced(context)) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final s = 1.0 + math.sin(_ctrl.value * math.pi) * 0.5;
        return Transform.scale(scale: s, child: child);
      },
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ShareSheetReceiveOverlay extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;

  const _ShareSheetReceiveOverlay({
    required this.palette,
    required this.controller,
  });

  @override
  State<_ShareSheetReceiveOverlay> createState() =>
      _ShareSheetReceiveOverlayState();
}

class _ShareSheetReceiveOverlayState extends State<_ShareSheetReceiveOverlay>
    with SingleTickerProviderStateMixin {
  late bool _encrypt = widget.controller.encryptBeforeUpload;
  late final AnimationController _enterCtrl;
  bool _saving = false;
  bool _savedDone = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.slow,
    )..forward();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving || _savedDone) return;
    setState(() => _saving = true);
    VaultHaptics.medium();
    final delay = vaultMotion.isReduced(context)
        ? vaultMotion.reducedFade
        : vaultMotion.fast;
    _closeTimer?.cancel();
    _closeTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedDone = true;
      });
      VaultHaptics.success();
      _closeTimer = Timer(vaultMotion.base, () async {
        if (!mounted) return;
        await _enterCtrl.reverse();
        if (!mounted) return;
        widget.controller.confirmPendingShareUpload(
          folderId: widget.controller.snapshot.currentFolder?.id,
          encrypt: _encrypt,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final paths = ctrl.pendingShareSheetPaths;
    final firstPath = paths.first;
    final fileName = firstPath.split(RegExp(r'[/\\]')).last;
    final fileObj = File(firstPath);
    final sizeText =
        fileObj.existsSync() ? formatBytes(fileObj.lengthSync()) : '';
    final reduced = vaultMotion.isReduced(context);

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (context, child) {
        final t = vaultMotion.emphasized.transform(_enterCtrl.value);
        final dy = reduced ? 0.0 : (1.0 - t) * 240.0;
        return Container(
          color: p.scrim.withValues(alpha: t * 0.85),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, dy), child: child),
          ),
        );
      },
      child: VaultSurface(
        palette: p,
        borderRadius: VaultRadii.sheet,
        elevated: true,
        borderColor: p.glassTopLeftBorder,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.shareSaveTitle, style: VaultText.heading(p, s.ar, size: 20)),
            const SizedBox(height: 4),
            Text(
              s.shareSaveSub,
              style: VaultText.body(p, s.ar, size: 13, color: p.secondary),
            ),
            const SizedBox(height: 16),
            VaultSurface(
              palette: p,
              borderRadius: VaultRadii.md,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.champagneSoft,
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      iconForMimeOrName('', fileName),
                      size: 20,
                      color: p.champagne,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paths.length == 1
                              ? fileName
                              : '${paths.length} ${s.ar ? "ملفات" : "files"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VaultText.body(p, s.ar,
                              size: 14.5,
                              weight: FontWeight.w600,
                              applyArabicScale: false),
                        ),
                        if (sizeText.isNotEmpty)
                          Text(
                            sizeText,
                            style: VaultText.mono(p,
                                size: 11, color: p.secondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: VaultMonoChip(
                palette: p,
                label: ctrl.activeDestinationTitle(s),
                dotColor: p.signalGreen,
                textColor: p.ink,
              ),
            ),
            const SizedBox(height: 12),
            VaultSurface(
              palette: p,
              borderRadius: VaultRadii.md,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 18,
                      color: _encrypt ? p.signalGreen : p.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.encryptBeforeUpload,
                      style: VaultText.body(p, s.ar,
                          size: 14,
                          weight: FontWeight.w500,
                          applyArabicScale: false),
                    ),
                  ),
                  VaultToggle(
                    palette: p,
                    value: _encrypt,
                    onChanged: (v) => setState(() => _encrypt = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: VaultPillButton(
                    palette: p,
                    isArabic: s.ar,
                    variant: VaultPillVariant.secondary,
                    height: 46,
                    label: s.cancel,
                    onPressed: _saving ? null : ctrl.dismissPendingShareUpload,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: VaultPillButton(
                    palette: p,
                    isArabic: s.ar,
                    height: 46,
                    loading: _saving,
                    completed: _savedDone,
                    label: s.shareSaveCta,
                    onPressed: _handleSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

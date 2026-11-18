import 'dart:io';

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

class _BigDuckAppState extends State<BigDuckApp> with WidgetsBindingObserver {
  late final bool _ownsController;
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController();
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
          home: Directionality(
            textDirection:
                _controller.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: _RootShell(controller: _controller),
          ),
        );
      },
    );
  }
}

class _RootShell extends StatelessWidget {
  final AppController controller;

  const _RootShell({required this.controller});

  @override
  Widget build(BuildContext context) {
    final brightness = switch (controller.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final palette = AppPalette.resolve(brightness);
    final strings = controller.strings;
    final motion = vaultMotion(context, 250);

    if (!controller.authStatus.isAuthorized &&
        !controller.hasSavedSession &&
        !controller.demoMode) {
      return AuthScreen(palette: palette, controller: controller);
    }

    if (controller.isLocked) {
      return LockScreen(palette: palette, controller: controller);
    }

    final catalogFiles = controller.snapshot.allFiles.isNotEmpty
        ? controller.snapshot.allFiles
        : controller.snapshot.files;
    final fileNamesById = <int, String>{
      for (final f in catalogFiles) f.id: f.name,
    };
    final fileSizesById = <int, int>{
      for (final f in catalogFiles) f.id: f.size,
    };

    const bottomPad = 96.0;
    // Order matches MobileTab: files, transfers, recent, settings
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
                  children: pages,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedSlide(
                    offset: controller.isSelecting
                        ? const Offset(0, 1.5)
                        : Offset.zero,
                    duration: motion,
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      ignoring: controller.isSelecting,
                      child: FloatingTabBar(
                        palette: palette,
                        strings: strings,
                        activeTab: controller.activeTab,
                        activeTransferCount: controller.activeTransferCount,
                        onSelect: controller.setTab,
                      ),
                    ),
                  ),
                ),
              ),
              // Liquid-glass floating Toast (success = green dot, error = coral dot)
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: controller.toastMessage != null
                        ? Offset.zero
                        : const Offset(0, -1.2),
                    duration: motion,
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: controller.toastMessage != null ? 1.0 : 0.0,
                      duration: motion,
                      child: Center(
                        child: VaultSurface(
                          palette: palette,
                          borderRadius: VaultRadii.pill,
                          elevated: true,
                          borderColor: palette.glassTopLeftBorder,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: controller.toastIsError
                                      ? palette.coral
                                      : palette.signalGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  controller.toastMessage ?? '',
                                  textAlign: TextAlign.center,
                                  style: VaultText.body(
                                    palette,
                                    strings.ar,
                                    size: 13,
                                    weight: FontWeight.w500,
                                    applyArabicScale: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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

class _ShareSheetReceiveOverlayState extends State<_ShareSheetReceiveOverlay> {
  late bool _encrypt = widget.controller.encryptBeforeUpload;

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

    return Container(
      color: p.scrim,
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
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
                    onPressed: ctrl.dismissPendingShareUpload,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: VaultPillButton(
                    palette: p,
                    isArabic: s.ar,
                    height: 46,
                    label: s.shareSaveCta,
                    onPressed: () => ctrl.confirmPendingShareUpload(
                      folderId: ctrl.snapshot.currentFolder?.id,
                      encrypt: _encrypt,
                    ),
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

import 'package:material_ui/material_ui.dart';

import 'screens/auth_screen.dart';
import 'screens/files_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfers_screen.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
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
    final motion = vaultMotion(context, 180);

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
    final pages = [
      FilesScreen(
        key: const ValueKey(MobileTab.files),
        palette: palette,
        controller: controller,
        isRecent: false,
        bottomPadding: bottomPad,
      ),
      FilesScreen(
        key: const ValueKey(MobileTab.recent),
        palette: palette,
        controller: controller,
        isRecent: true,
        bottomPadding: bottomPad,
      ),
      TransfersScreen(
        key: const ValueKey(MobileTab.transfers),
        palette: palette,
        strings: strings,
        tasks: controller.snapshot.tasks,
        fileNamesById: fileNamesById,
        fileSizesById: fileSizesById,
        floodWaitSeconds: controller.floodWaitSeconds,
        bottomPadding: bottomPad,
        onPauseTask: controller.pauseTask,
        onResumeTask: controller.resumeTask,
      ),
      SettingsScreen(
        key: const ValueKey(MobileTab.settings),
        palette: palette,
        controller: controller,
        bottomPadding: bottomPad,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.ground,
      body: SafeArea(
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
                  curve: Curves.easeOutCubic,
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
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: AnimatedSlide(
                  offset: controller.toastMessage != null
                      ? Offset.zero
                      : const Offset(0, -1.2),
                  duration: motion,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: controller.toastMessage != null ? 1.0 : 0.0,
                    duration: motion,
                    child: Center(
                      child: VaultSurface(
                        palette: palette,
                        borderRadius: VaultRadii.sm,
                        elevated: true,
                        backgroundColor: palette.ink,
                        borderColor: palette.ink,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        child: Text(
                          controller.toastMessage ?? '',
                          textAlign: TextAlign.center,
                          style: VaultText.body(
                            palette,
                            strings.ar,
                            size: 13,
                            weight: FontWeight.w600,
                            color: palette.ground,
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
}

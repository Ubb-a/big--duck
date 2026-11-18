import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:big_duck/l10n/app_strings.dart';
import 'package:big_duck/main.dart';
import 'package:big_duck/models/core_models.dart';
import 'package:big_duck/screens/lock_screen.dart';
import 'package:big_duck/screens/preview_screen.dart';
import 'package:big_duck/screens/settings_screen.dart';
import 'package:big_duck/screens/transfers_screen.dart';
import 'package:big_duck/state/app_controller.dart';
import 'package:big_duck/theme/app_theme.dart';
import 'package:big_duck/widgets/vault_surface.dart';

void main() {
  testWidgets(
      'Obsidian & Ivory Signal Vault boots Arabic RTL, searches globally, toggles grid, and switches to English LTR',
      (WidgetTester tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(BigDuckApp(controller: controller));
    await tester.pumpAndSettle();

    // Primary layout starts in Arabic RTL on AuthScreen without Preview UI button in production
    expect(find.text('ربط تيليجرام'), findsOneWidget);
    expect(find.text('معاينة الواجهة'), findsNothing);
    expect(find.text('Preview UI'), findsNothing);

    controller.enterDemoMode(silent: true);
    await tester.pumpAndSettle();

    // Files screen in Arabic RTL
    expect(find.text('الخزنة'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Passport_Scan_Encrypted.pdf'), findsOneWidget);
    expect(find.text('مملوكة لي'), findsOneWidget);

    // Global search across nested folders finds Tax_Return_2026.pdf inside Documents
    await tester.enterText(find.byType(TextField).first, 'Tax');
    await tester.pumpAndSettle();
    expect(find.text('Tax_Return_2026.pdf'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // Grid view toggle
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('ZIP'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();

    // Transfers tab via floating circular nav button
    await tester.tap(find.byKey(const ValueKey('nav_transfers')));
    await tester.pumpAndSettle();
    expect(find.text('التحويلات'), findsOneWidget);
    expect(find.text('لا توجد تحويلات'), findsOneWidget);

    // Settings tab via floating circular nav button
    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('الحساب والأمان'), findsOneWidget);

    // Scroll to Appearance & Language miniature theme previews and switch to English
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('فاتح'), findsOneWidget);
    expect(find.text('داكن'), findsOneWidget);
    expect(find.text('تلقائي'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE & LANGUAGE'), findsOneWidget);

    // Verify mirrored LTR Files tab header
    await tester.tap(find.byKey(const ValueKey('nav_files')));
    await tester.pumpAndSettle();
    expect(find.text('Vault'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'Preview darkroom stays pure obsidian black in light mode, zooms, rotates, and opens Info sheet',
      (WidgetTester tester) async {
    final controller = AppController(isArabic: false);
    addTearDown(controller.dispose);

    // Intentionally pass light palette to verify Darkroom stays #050506 black
    final lightPalette = AppPalette.resolve(Brightness.light);
    final imagePath = File('assets/icon.png').absolute.path;
    const file = FileRecord(
      id: 77,
      folderId: null,
      name: 'w3.jpg',
      size: 397521,
      mimeType: 'image/jpeg',
      sha256:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      isEncrypted: true,
      createdAt: 1731700000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PreviewScreen(
          palette: lightPalette,
          controller: controller,
          file: file,
          initialLocalPath: imagePath,
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF050506));
    expect(find.text('w3.jpg'), findsOneWidget);
    expect(find.text('AES-256'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // Zoom pill 100% -> 200% -> 100%
    await tester.tap(find.text('100%'));
    await tester.pumpAndSettle();
    expect(find.text('200%'), findsOneWidget);

    await tester.tap(find.text('200%'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    // Rotate 90° via Menu sheet
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotate 90°'));
    await tester.pumpAndSettle();
    final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotatedBox.quarterTurns, 1);

    // Info sheet
    await tester.tap(find.byTooltip('Info'));
    await tester.pumpAndSettle();
    expect(find.text('AES-256-GCM'), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);
  });

  testWidgets(
      'Transfers segments (Active/Completed/Failed), FLOOD_WAIT chip, Pause/Resume/Retry, and LockScreen failed state',
      (WidgetTester tester) async {
    final controller = AppController(isArabic: false);
    addTearDown(controller.dispose);
    final palette = AppPalette.resolve(Brightness.dark);
    int? pausedId;
    int? resumedId;
    int? retriedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransfersScreen(
            palette: palette,
            strings: const AppStrings(false),
            tasks: const [
              TaskRecord(
                id: 11,
                kind: TaskKind.upload,
                fileId: 101,
                state: TaskState.running,
                progress: 0.45,
              ),
              TaskRecord(
                id: 12,
                kind: TaskKind.download,
                fileId: 102,
                state: TaskState.paused,
                progress: 0.5,
              ),
              TaskRecord(
                id: 13,
                kind: TaskKind.upload,
                fileId: 103,
                state: TaskState.completed,
                progress: 1.0,
              ),
              TaskRecord(
                id: 14,
                kind: TaskKind.download,
                fileId: 104,
                state: TaskState.failed,
                progress: 0.25,
                error: 'Timeout waiting for MTProto DC',
              ),
            ],
            fileNamesById: const {
              101: 'clip.mp4',
              102: 'track.mp3',
              103: 'archive.zip',
              104: 'raw_photo.dng',
            },
            fileSizesById: const {
              101: 1200 * 1024 * 1024,
              102: 500 * 1024 * 1024,
              103: 100 * 1024 * 1024,
              104: 800 * 1024 * 1024,
            },
            floodWaitSeconds: 24,
            bottomPadding: 24,
            onPauseTask: (id) => pausedId = id,
            onResumeTask: (task) => resumedId = task.id,
            onRetryTask: (task) => retriedId = task.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram asked us to wait 24s'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.text('track.mp3'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    expect(pausedId, 11);

    await tester.tap(find.byTooltip('Resume'));
    expect(resumedId, 12);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('archive.zip'), findsOneWidget);

    await tester.tap(find.text('Failed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('raw_photo.dng'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retriedId, 14);

    // LockScreen failed state
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          palette: palette,
          controller: controller,
          initialFailed: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('BIG DUCK'), findsOneWidget);
    expect(find.text('Unlock your vault'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Use passcode'), findsOneWidget);

    final viewWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getSize(find.byType(VaultCanvasBackdrop)).width, viewWidth);
    expect(
      tester.getCenter(find.byIcon(Icons.fingerprint_rounded)).dx,
      closeTo(viewWidth / 2, 1.0),
    );
  });

  testWidgets(
      'Saved session mounts Vault directly, shows Share Save-to-Vault modal, and Log out dialog confirms reset',
      (WidgetTester tester) async {
    final controller = AppController(isArabic: false);
    addTearDown(controller.dispose);

    controller.debugPrimeSavedSession(
      fullName: 'Duck Keeper',
      username: 'duck_keeper',
    );

    await tester.pumpWidget(BigDuckApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Connect Telegram'), findsNothing);
    expect(find.text('Documents'), findsOneWidget);

    // Simulate receiving file from OS Share sheet
    controller.debugStageShareSheet(['/tmp/contract.pdf']);
    await tester.pumpAndSettle();
    expect(find.text('Save to Vault'), findsOneWidget);
    expect(find.text('contract.pdf'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save to Vault'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();
    expect(find.text('Duck Keeper'), findsOneWidget);

    await tester.drag(find.byType(SettingsScreen), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears before disconnecting session
    expect(find.text('Log out of Telegram?'), findsOneWidget);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Connect Telegram'), findsOneWidget);
  });

  testWidgets(
      'Storage destination sheet filters Owned vs Admin chats, searches, and creates private vault group',
      (WidgetTester tester) async {
    final controller = AppController(isArabic: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(BigDuckApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Preview UI'), findsNothing);
    controller.enterDemoMode(silent: true);
    await tester.pumpAndSettle();

    // Tapping destination chip directly on FilesScreen opens the storage sheet
    await tester.tap(find.text('Saved Messages'));
    await tester.pumpAndSettle();

    // Owned by me default: lists creator chats, excludes Shared Studio Admin
    expect(find.text('BIG DUCK Archive'), findsOneWidget);
    expect(find.text('Personal Media Vault'), findsOneWidget);
    expect(find.text('Shared Studio Admin'), findsNothing);

    await tester.tap(find.text('Admin (3)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Shared Studio Admin'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Shared Studio Admin'), findsOneWidget);

    await tester.tap(find.text('Owned by me (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Shared Studio Admin'), findsNothing);

    final searchField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Search owned chats...',
    );
    await tester.enterText(searchField, 'Personal');
    await tester.pumpAndSettle();
    expect(find.text('Personal Media Vault'), findsOneWidget);
    expect(find.text('BIG DUCK Archive'), findsNothing);

    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create private vault group'));
    await tester.pumpAndSettle();

    final createNameField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Vault name (e.g. Private Vault)',
    );
    await tester.enterText(createNameField, 'Secret Duck Vault');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create & select'));
    await tester.pumpAndSettle();

    expect(find.text('Secret Duck Vault'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'Motion engine honors Reduce Motion 150ms fallback, fans out + FAB, restores Undo delete, and cross-fades chunk notes',
      (WidgetTester tester) async {
    late bool reducedFlag;
    late Duration reducedSlow;
    late bool loopsAllowed;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              reducedFlag = vaultMotion.isReduced(ctx);
              reducedSlow = vaultMotion.duration(ctx, vaultMotion.slow);
              loopsAllowed = vaultMotion.allowLoops(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(reducedFlag, isTrue);
    expect(reducedSlow, const Duration(milliseconds: 150));
    expect(loopsAllowed, isFalse);

    final controller = AppController(isArabic: false)
      ..debugPrimeSavedSession(fullName: 'Vault Tester');
    addTearDown(controller.dispose);

    await tester.pumpWidget(BigDuckApp(controller: controller));
    await tester.pumpAndSettle();

    // + FAB fan-out
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Upload file'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);

    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Long-press multi-select -> Delete -> Undo toast restore
    await tester.drag(find.text('Documents'), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Passport_Scan_Encrypted.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Passport_Scan_Encrypted.pdf'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Passport_Scan_Encrypted.pdf'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.drag(find.text('Passport_Scan_Encrypted.pdf'), const Offset(0, 220));
    await tester.pumpAndSettle();
    expect(controller.navHiddenByScroll, isFalse);

    // Settings chunk caption cross-fade & circular reveal origin
    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.tap(find.text('512 MiB'));
    await tester.pumpAndSettle();
    expect(find.text('Higher throughput for large files on Wi-Fi'),
        findsOneWidget);

    await tester.drag(find.byType(SettingsScreen), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);
    expect(controller.themeRevealOrigin, isNotNull);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'Transfers screen updates live progress %, MB/s speed, and ETA from QueueUpdateEvent stream',
      (WidgetTester tester) async {
    var clockNow = DateTime(2026, 11, 18, 12, 0, 0);
    final controller = AppController(isArabic: false)
      ..debugPrimeSavedSession(fullName: 'Transfer Tester')
      ..debugSetClock(() => clockNow);
    addTearDown(controller.dispose);

    await tester.pumpWidget(BigDuckApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav_transfers')));
    await tester.pumpAndSettle();

    // Initial 0% progress event seeds running transfer card with preparing label.
    controller.debugApplyBridgeEvent(
      const QueueUpdateEvent(
        event: 'task_progress',
        taskId: 77,
        fileId: 102,
        kind: 'upload',
        progress: 0.0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.text('Studio_Backup_2026.zip'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.textContaining('Preparing & encrypting...'), findsOneWidget);

    // Intermediate intra-chunk progress computes live speed (MB/s) and ETA.
    clockNow = clockNow.add(const Duration(seconds: 2));
    controller.debugApplyBridgeEvent(
      const QueueUpdateEvent(
        event: 'task_progress',
        taskId: 77,
        fileId: 102,
        kind: 'upload',
        progress: 0.25,
      ),
    );
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.text('25%'), findsOneWidget);
    expect(find.textContaining('MB/s'), findsOneWidget);
    expect(find.textContaining('left'), findsOneWidget);

    clockNow = clockNow.add(const Duration(seconds: 2));
    controller.debugApplyBridgeEvent(
      const QueueUpdateEvent(
        event: 'task_progress',
        taskId: 77,
        fileId: 102,
        kind: 'upload',
        progress: 0.60,
      ),
    );
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.text('60%'), findsOneWidget);
    expect(find.textContaining('chunk 2 of 3'), findsOneWidget);
  });
}

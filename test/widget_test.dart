import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:big_duck/main.dart';
import 'package:big_duck/l10n/app_strings.dart';
import 'package:big_duck/models/core_models.dart';
import 'package:big_duck/screens/lock_screen.dart';
import 'package:big_duck/screens/preview_screen.dart';
import 'package:big_duck/screens/settings_screen.dart';
import 'package:big_duck/screens/transfers_screen.dart';
import 'package:big_duck/state/app_controller.dart';
import 'package:big_duck/theme/app_theme.dart';

void main() {
  testWidgets('Signal Vault UI renders, filters, switches language, and scrolls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BigDuckApp());
    await tester.pumpAndSettle();

    expect(find.text('BIG DUCK'), findsOneWidget);
    expect(find.text('Preview UI'), findsOneWidget);

    await tester.tap(find.text('Preview UI'));
    await tester.pumpAndSettle();

    expect(find.text('BIG DUCK'), findsOneWidget);
    expect(find.text('2 folders, 2 files'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Passport_Scan_Encrypted.pdf'), findsOneWidget);

    // Filter by PDF
    await tester.tap(find.text('PDF').first);
    await tester.pumpAndSettle();
    expect(find.text('Passport_Scan_Encrypted.pdf'), findsOneWidget);
    expect(find.text('Studio_Backup_2026.zip'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Global search across folders finds nested demo file in Documents
    await tester.enterText(find.byType(TextField).first, 'Tax');
    await tester.pumpAndSettle();
    expect(find.text('Tax_Return_2026.pdf'), findsOneWidget);
    expect(find.text('Vault search results (1)'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // Toggle Grid view and verify archival extension chips
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text('ZIP'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfers'));
    await tester.pumpAndSettle();
    expect(find.text('No active transfers'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account and security'), findsOneWidget);
    expect(find.text('Biometric / Face ID lock'), findsOneWidget);
    expect(find.text('AES-256-GCM encryption'), findsOneWidget);

    // Scroll to Display and storage ledger
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Display and storage'), findsOneWidget);
    expect(find.text('Appearance and language'), findsOneWidget);
    expect(find.text('Vault storage'), findsOneWidget);

    // Switch to Arabic & verify RTL localized strings, then back to English
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('المظهر واللغة'), findsOneWidget);
    expect(find.text('إحصائيات المساحة'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance and language'), findsOneWidget);

    // Scroll further down to verify Cache & Index backup ledgers
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Local download cache'), findsOneWidget);
    expect(find.text('Index backup and restore'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Image preview darkroom renders controls, zooms, rotates, and inspects',
      (WidgetTester tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    final palette = AppPalette.resolve(Brightness.light);
    final imagePath = File('assets/icon.png').absolute.path;
    const file = FileRecord(
      id: 77,
      folderId: null,
      name: 'w3.jpg',
      size: 397521,
      mimeType: 'image/jpeg',
      sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      isEncrypted: true,
      createdAt: 1731700000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PreviewScreen(
          palette: palette,
          controller: controller,
          file: file,
          initialLocalPath: imagePath,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('w3.jpg'), findsOneWidget);
    expect(find.text('AES-256'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Toggle zoom pill from 100% -> 200%, then back to 100%
    await tester.tap(find.text('100%'));
    await tester.pumpAndSettle();
    expect(find.text('200%'), findsOneWidget);

    await tester.tap(find.text('200%'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    // Rotate 90 degrees
    await tester.tap(find.byTooltip('Rotate 90°'));
    await tester.pump();
    final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotatedBox.quarterTurns, 1);

    // Cycle darkroom backdrop (dark -> transparency grid -> light paper)
    await tester.tap(find.byTooltip('Dark canvas'));
    await tester.pump();
    expect(find.byTooltip('Transparency grid'), findsOneWidget);

    await tester.tap(find.byTooltip('Transparency grid'));
    await tester.pump();
    expect(find.byTooltip('Light paper'), findsOneWidget);

    // Open archival file inspector sheet
    await tester.tap(find.byTooltip('File details'));
    await tester.pumpAndSettle();
    expect(find.text('Archival file manifest'), findsOneWidget);
    expect(find.text('Argon2id + AES-256-GCM'), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);
  });

  testWidgets('Transfers screen shows Pause/Resume and LockScreen renders',
      (WidgetTester tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final palette = AppPalette.resolve(Brightness.light);
    int? pausedId;
    int? resumedId;

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
            ],
            fileNamesById: const {101: 'clip.mp4', 102: 'track.mp3'},
            fileSizesById: const {101: 1000000, 102: 500000},
            floodWaitSeconds: 0,
            bottomPadding: 24,
            onPauseTask: (id) => pausedId = id,
            onResumeTask: (task) => resumedId = task.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.text('track.mp3'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    expect(pausedId, 11);

    await tester.tap(find.text('Resume'));
    expect(resumedId, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(palette: palette, controller: controller),
      ),
    );
    await tester.pump();
    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.text('Unlock vault'), findsOneWidget);
  });

  testWidgets(
      'Saved Telegram session mounts vault directly without AuthScreen and Sign out resets',
      (WidgetTester tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    controller.debugPrimeSavedSession(
      fullName: 'Duck Keeper',
      username: 'duck_keeper',
    );

    await tester.pumpWidget(BigDuckApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Mount your Telegram vault'), findsNothing);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Connecting...'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Duck Keeper'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Mount your Telegram vault'), findsOneWidget);
  });

  testWidgets(
      'Storage destination sheet filters owned vs admin groups, searches, and creates private vault',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BigDuckApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview UI'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SettingsScreen), const Offset(0, -550));
    await tester.pumpAndSettle();

    expect(find.text('Storage destination'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    // Owned by me tab active by default: excludes Shared Studio Admin
    expect(find.text('BIG DUCK Archive'), findsOneWidget);
    expect(find.text('Personal Media Vault'), findsOneWidget);
    expect(find.text('Shared Studio Admin'), findsNothing);

    await tester.tap(find.text('Admin access'));
    await tester.pumpAndSettle();
    expect(find.text('Shared Studio Admin'), findsOneWidget);

    await tester.tap(find.text('Owned by me'));
    await tester.pumpAndSettle();
    expect(find.text('Shared Studio Admin'), findsNothing);

    final searchField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Search owned groups or channels',
    );
    await tester.enterText(searchField, 'Personal');
    await tester.pumpAndSettle();
    expect(find.text('Personal Media Vault'), findsOneWidget);
    expect(find.text('BIG DUCK Archive'), findsNothing);

    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('New private vault'));
    await tester.pumpAndSettle();

    final createNameField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Vault name (e.g. BIG DUCK Vault)',
    );
    await tester.enterText(createNameField, 'Secret Duck Vault');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create and select'));
    await tester.pumpAndSettle();

    expect(find.text('Secret Duck Vault'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

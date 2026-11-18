import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/storage_destination_sheet.dart';
import '../widgets/vault_surface.dart';

class SettingsScreen extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;
  final double bottomPadding;

  const SettingsScreen({
    super.key,
    required this.palette,
    required this.controller,
    required this.bottomPadding,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _chunks = [64, 256, 512, 1024];
  static const _autoLockOptions = [0, 1, 5, 15];

  CacheStats _cacheStats = const CacheStats(fileCount: 0, totalBytes: 0);

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    final stats = await widget.controller.getDownloadCacheStats();
    if (mounted) {
      setState(() => _cacheStats = stats);
    }
  }

  void _showVaultPasswordDialog() {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final passCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultDialogShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.encryptionTitle,
                  style: VaultText.heading(p, s.ar, size: 19)),
              const SizedBox(height: 6),
              Text(
                s.encryptionSub,
                style: VaultText.body(p, s.ar, size: 13, color: p.secondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: true,
                autofocus: true,
                style: VaultText.body(p, s.ar,
                    size: 14, applyArabicScale: false),
                decoration: InputDecoration(
                  hintText: s.encPassHint,
                  hintStyle: VaultText.monoText(p, s.encPassHint,
                      size: 11.5, color: p.secondary),
                  filled: true,
                  fillColor: p.glassFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.champagne),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      variant: VaultPillVariant.secondary,
                      height: 44,
                      label: s.cancel,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      height: 44,
                      label: s.applyPassword,
                      onPressed: () {
                        if (passCtrl.text.trim().isNotEmpty) {
                          ctrl.setEncryptionPassword(passCtrl.text);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(passCtrl.dispose);
  }

  void _showBackupDialog({required bool isRestore}) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final passCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultDialogShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isRestore ? s.restoreIndex : s.backupIndex,
                style: VaultText.heading(p, s.ar, size: 19),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: true,
                autofocus: true,
                style: VaultText.body(p, s.ar,
                    size: 14, applyArabicScale: false),
                decoration: InputDecoration(
                  hintText: s.backupPassHint,
                  hintStyle: VaultText.monoText(p, s.backupPassHint,
                      size: 11.5, color: p.secondary),
                  filled: true,
                  fillColor: p.glassFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.champagne),
                  ),
                ),
              ),
              if (isRestore) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  keyboardType: TextInputType.number,
                  style: VaultText.mono(p, size: 13, color: p.ink),
                  decoration: InputDecoration(
                    hintText: s.msgIdHint,
                    hintStyle: VaultText.monoText(p, s.msgIdHint,
                        size: 11.5, color: p.secondary),
                    filled: true,
                    fillColor: p.glassFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                      borderSide: BorderSide(color: p.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                      borderSide: BorderSide(color: p.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                      borderSide: BorderSide(color: p.champagne),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      variant: VaultPillVariant.secondary,
                      height: 44,
                      label: s.cancel,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      height: 44,
                      label: isRestore ? s.restoreIndex : s.backupIndex,
                      onPressed: () {
                        if (passCtrl.text.isEmpty) return;
                        if (isRestore) {
                          ctrl.restoreIndex(
                              passCtrl.text, int.tryParse(msgCtrl.text.trim()));
                        } else {
                          ctrl.backupIndex(passCtrl.text);
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      passCtrl.dispose();
      msgCtrl.dispose();
    });
  }

  void _showLogoutConfirmDialog() {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultDialogShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  VaultQuickActionCircle(
                    palette: p,
                    tone: VaultQuickTone.coral,
                    icon: Icons.logout_rounded,
                    onTap: null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.logOutConfirmTitle,
                      style: VaultText.heading(p, s.ar, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.logOutConfirmDesc,
                style: VaultText.body(p, s.ar, size: 13.5, color: p.secondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      variant: VaultPillVariant.secondary,
                      height: 44,
                      label: s.cancel,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      variant: VaultPillVariant.danger,
                      height: 44,
                      label: ctrl.demoMode ? s.exitPreview : s.logOut,
                      onPressed: () {
                        Navigator.pop(ctx);
                        ctrl.logout();
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

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;

    final selectedChat = ctrl.storageChats
        .where((c) => c.id == ctrl.targetChatId)
        .firstOrNull;
    final effectiveKind =
        selectedChat?.kind ?? ctrl.cachedTargetChatKind ?? 'group';
    final activeDestTitle = ctrl.activeDestinationTitle(s);
    final activeDestSub = ctrl.targetChatId == null
        ? s.vaultSealLabel
        : '${effectiveKind == 'channel' ? s.channelKindLabel : s.groupKindLabel} · ${selectedChat != null ? (selectedChat.isCreator ? s.roleOwnerBadge : s.roleAdminBadge) : s.privateBadge}';

    final lastBackupLabel = ctrl.lastBackupAt != null
        ? formatTimestamp(ctrl.lastBackupAt!)
        : s.neverLabel;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        VaultSpacing.screenHorizontal,
        16,
        VaultSpacing.screenHorizontal,
        widget.bottomPadding + 24,
      ),
      children: [
        Text(
          s.settingsTitle,
          style: VaultText.display(p, s.ar, size: 34),
        ),
        const SizedBox(height: 4),
        Text(
          s.settingsSub,
          style: VaultText.body(p, s.ar, size: 13.5, color: p.secondary),
        ),
        const SizedBox(height: 24),

        // 1. Account & Security
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.sectionAccountSecurity,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: p.champagneSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: p.champagne.withValues(alpha: 0.45)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _accountInitials(ctrl.displayAccountName),
                      style: VaultText.mono(
                        p,
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.champagne,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctrl.displayAccountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VaultText.heading(p, s.ar, size: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (ctrl.displayUsername != null &&
                                ctrl.displayUsername!.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  '@${ctrl.displayUsername}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: VaultText.mono(p,
                                      size: 11.5, color: p.secondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            VaultStatusDot(
                              palette: p,
                              isArabic: s.ar,
                              dotColor: ctrl.authStatus.isAuthorized ||
                                      ctrl.demoMode
                                  ? p.signalGreen
                                  : (ctrl.isReconnecting
                                      ? p.champagne
                                      : p.coral),
                              label: ctrl.authStatus.isAuthorized ||
                                      ctrl.demoMode
                                  ? s.statusSynced
                                  : (ctrl.isReconnecting
                                      ? s.statusConnecting
                                      : s.statusOfflineTap),
                              onTap: (!ctrl.authStatus.isAuthorized &&
                                      !ctrl.isReconnecting &&
                                      ctrl.hasSavedSession)
                                  ? ctrl.connect
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: p.glassBorder),
              ),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.glassElevatedFill,
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 19,
                      color: ctrl.biometricEnabled
                          ? p.signalGreen
                          : p.champagne,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.biometricLockTitle,
                          style: VaultText.body(
                            p,
                            s.ar,
                            size: 14.5,
                            weight: FontWeight.w500,
                            applyArabicScale: false,
                          ),
                        ),
                        Text(
                          ctrl.biometricAvailable
                              ? s.biometricLockSub
                              : s.biometricUnavailable,
                          style: VaultText.body(
                            p,
                            s.ar,
                            size: 12,
                            color: p.secondary,
                            applyArabicScale: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  VaultToggle(
                    palette: p,
                    value: ctrl.biometricEnabled,
                    onChanged: (value) async {
                      await ctrl.setBiometricEnabled(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                s.autoLockTitle,
                style: VaultText.monoText(p, s.autoLockTitle,
                    size: 11, color: p.secondary),
              ),
              const SizedBox(height: 8),
              VaultSegmentedControl<int>(
                palette: p,
                isArabic: s.ar,
                mono: true,
                value: ctrl.autoLockMinutes,
                onChanged: ctrl.setAutoLockMinutes,
                options: [
                  for (final m in _autoLockOptions)
                    VaultSegmentOption(
                      value: m,
                      label: s.autoLockOptionLabel(m),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Storage Destination
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.sectionStorageDest,
        ),
        VaultTap(
          onTap: () => showStorageDestinationSheet(
            context,
            palette: p,
            controller: ctrl,
          ),
          child: VaultSurface(
            palette: p,
            borderRadius: VaultRadii.card,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.champagneSoft,
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    ctrl.targetChatId == null
                        ? Icons.bookmark_border_rounded
                        : (effectiveKind == 'channel'
                            ? Icons.campaign_outlined
                            : Icons.folder_shared_outlined),
                    size: 19,
                    color: p.champagne,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeDestTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.body(
                          p,
                          s.ar,
                          size: 14.5,
                          weight: FontWeight.w600,
                          applyArabicScale: false,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeDestSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.monoText(p, activeDestSub,
                            size: 11, color: p.secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                VaultMonoChip(
                  palette: p,
                  label: s.changeDestination,
                  textColor: p.champagne,
                  borderColor: p.champagne.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 3. Encryption
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.sectionEncryption,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showVaultPasswordDialog,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.encryptionTitle,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 14.5,
                              weight: FontWeight.w600,
                              applyArabicScale: false,
                            ),
                          ),
                          Text(
                            s.encryptionSub,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 12,
                              color: p.secondary,
                              applyArabicScale: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  VaultToggle(
                    palette: p,
                    value: ctrl.hasEncryptionPassword,
                    onChanged: (enable) {
                      if (enable) {
                        _showVaultPasswordDialog();
                      } else {
                        ctrl.setEncryptionPassword(null);
                      }
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: p.glassBorder),
              ),
              Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: ctrl.hasEncryptionPassword
                        ? p.signalGreen
                        : p.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.encryptionAlgoRow,
                      style: VaultText.mono(p, size: 12, color: p.ink),
                    ),
                  ),
                  VaultMonoChip(
                    palette: p,
                    label: ctrl.hasEncryptionPassword
                        ? s.keyActiveBadge
                        : s.keyUnsetBadge,
                    dotColor: ctrl.hasEncryptionPassword
                        ? p.signalGreen
                        : p.secondary,
                    textColor: ctrl.hasEncryptionPassword
                        ? p.signalGreen
                        : p.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                s.uploadChunkSize,
                style: VaultText.monoText(p, s.uploadChunkSize,
                    size: 11, color: p.secondary),
              ),
              const SizedBox(height: 8),
              VaultSegmentedControl<int>(
                palette: p,
                isArabic: s.ar,
                mono: true,
                value: ctrl.chunkSizeMiB,
                onChanged: ctrl.setChunkSizeMiB,
                options: [
                  for (final mib in _chunks)
                    VaultSegmentOption(value: mib, label: '$mib MiB'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 4. Backup
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.sectionBackup,
          trailing: Text(
            '${s.lastBackupLabel}: $lastBackupLabel',
            style: VaultText.monoText(
              p,
              '${s.lastBackupLabel}: $lastBackupLabel',
              size: 10.5,
              color: p.secondary,
            ),
          ),
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.card,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _SettingsActionRow(
                palette: p,
                isArabic: s.ar,
                icon: Icons.cloud_upload_outlined,
                title: s.backupIndex,
                tone: p.champagne,
                onTap: () => _showBackupDialog(isRestore: false),
              ),
              Divider(height: 1, thickness: 1, color: p.glassBorder),
              _SettingsActionRow(
                palette: p,
                isArabic: s.ar,
                icon: Icons.cloud_download_outlined,
                title: s.restoreIndex,
                tone: p.ink,
                onTap: () => _showBackupDialog(isRestore: true),
              ),
              Divider(height: 1, thickness: 1, color: p.glassBorder),
              _SettingsActionRow(
                palette: p,
                isArabic: s.ar,
                icon: Icons.cleaning_services_outlined,
                title: s.cacheTitle,
                trailingMono: formatBytes(_cacheStats.totalBytes),
                tone: _cacheStats.fileCount > 0 ? p.coral : p.secondary,
                onTap: _cacheStats.fileCount == 0
                    ? _loadCacheStats
                    : () async {
                        await ctrl.clearDownloadCache();
                        await _loadCacheStats();
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 5. Appearance & Language (Light / Dark / Auto miniature theme preview tiles + AR/EN)
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.sectionAppearanceLang,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.appearanceTitle,
                style: VaultText.monoText(p, s.appearanceTitle,
                    size: 11, color: p.secondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ThemePreviewTile(
                      palette: p,
                      isArabic: s.ar,
                      label: s.themeLight,
                      mode: ThemeMode.light,
                      selected: ctrl.themeMode == ThemeMode.light,
                      onTap: () => ctrl.setThemeMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemePreviewTile(
                      palette: p,
                      isArabic: s.ar,
                      label: s.themeDark,
                      mode: ThemeMode.dark,
                      selected: ctrl.themeMode == ThemeMode.dark,
                      onTap: () => ctrl.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemePreviewTile(
                      palette: p,
                      isArabic: s.ar,
                      label: s.themeSystem,
                      mode: ThemeMode.system,
                      selected: ctrl.themeMode == ThemeMode.system,
                      onTap: () => ctrl.setThemeMode(ThemeMode.system),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                s.languageLabel,
                style: VaultText.monoText(p, s.languageLabel,
                    size: 11, color: p.secondary),
              ),
              const SizedBox(height: 8),
              VaultSegmentedControl<bool>(
                palette: p,
                isArabic: s.ar,
                value: ctrl.isArabic,
                onChanged: ctrl.setArabic,
                options: const [
                  VaultSegmentOption(value: true, label: 'العربية'),
                  VaultSegmentOption(value: false, label: 'English'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 6. About
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.sectionAbout,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.card,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icon.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.appTitle,
                          style: VaultText.heading(p, s.ar, size: 15),
                        ),
                        Text(
                          'v1.0.0+1',
                          style: VaultText.mono(p,
                              size: 11, color: p.champagne),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.aboutFooterText,
                      style: VaultText.body(
                        p,
                        s.ar,
                        size: 12,
                        color: p.secondary,
                        applyArabicScale: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 7. Log out in coral with confirmation dialog
        VaultPillButton(
          palette: p,
          isArabic: s.ar,
          variant: VaultPillVariant.danger,
          icon: Icons.logout_rounded,
          label: ctrl.demoMode ? s.exitPreview : s.logOut,
          onPressed: _showLogoutConfirmDialog,
        ),
      ],
    );
  }

  String _accountInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'BD';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _SettingsActionRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final IconData icon;
  final String title;
  final String? trailingMono;
  final Color tone;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.title,
    this.trailingMono,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return VaultTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: VaultText.body(
                  p,
                  isArabic,
                  size: 14,
                  weight: FontWeight.w500,
                  applyArabicScale: false,
                ),
              ),
            ),
            if (trailingMono != null) ...[
              Text(
                trailingMono!,
                style: VaultText.mono(p, size: 11.5, color: p.secondary),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              isArabic
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: p.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewTile extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePreviewTile({
    required this.palette,
    required this.isArabic,
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return VaultTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: vaultMotion(context, 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? p.champagneSoft : p.glassFill,
          borderRadius: BorderRadius.circular(VaultRadii.md),
          border: Border.all(
            color: selected ? p.champagne : p.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildMiniThemeCanvas(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VaultText.body(
                p,
                isArabic,
                size: 12,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? p.ink : p.secondary,
                applyArabicScale: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniThemeCanvas() {
    if (mode == ThemeMode.light) {
      return Container(
        color: const Color(0xFFF7F6F3),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF17181C),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0x18000000)),
              ),
            ),
          ],
        ),
      );
    }
    if (mode == ThemeMode.dark) {
      return Container(
        color: const Color(0xFF050506),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D6CF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1C),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
            ),
          ],
        ),
      );
    }
    // System Auto split preview
    return Row(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFFF7F6F3),
            padding: const EdgeInsets.all(5),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF050506),
            padding: const EdgeInsets.all(5),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1C),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

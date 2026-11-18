import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_icon.dart';
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

  final _encPassCtrl = TextEditingController();
  final _backupPassCtrl = TextEditingController();
  final _restoreMsgIdCtrl = TextEditingController();
  CacheStats _cacheStats = const CacheStats(fileCount: 0, totalBytes: 0);

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  @override
  void dispose() {
    _encPassCtrl.dispose();
    _backupPassCtrl.dispose();
    _restoreMsgIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCacheStats() async {
    final stats = await widget.controller.getDownloadCacheStats();
    if (mounted) {
      setState(() => _cacheStats = stats);
    }
  }

  void _showStorageDestinationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StorageDestinationSheet(
        palette: widget.palette,
        controller: widget.controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final motion = vaultMotion(context, 180);
    final selectedChat = ctrl.storageChats
        .where((c) => c.id == ctrl.targetChatId)
        .firstOrNull;
    final effectiveKind =
        selectedChat?.kind ?? ctrl.cachedTargetChatKind ?? 'group';
    final activeDestTitle = ctrl.targetChatId == null
        ? s.savedMessagesDefault
        : (selectedChat?.title ??
            ctrl.cachedTargetChatTitle ??
            'Chat #${ctrl.targetChatId}');
    final sep = s.ar ? '، ' : ', ';
    final activeDestSub = ctrl.targetChatId == null
        ? s.vaultSealLabel
        : '${effectiveKind == 'channel' ? s.channelKindLabel : s.groupKindLabel}$sep${selectedChat != null ? (selectedChat.isCreator ? s.roleOwnerBadge : s.roleAdminBadge) : s.privateBadge}';

    final files = ctrl.snapshot.allFiles.isNotEmpty
        ? ctrl.snapshot.allFiles
        : ctrl.snapshot.files;
    var totalBytes = 0;
    var imgBytes = 0;
    var pdfBytes = 0;
    var videoBytes = 0;
    var otherBytes = 0;
    for (final f in files) {
      totalBytes += f.size;
      if (isImageFile(f.mimeType, f.name)) {
        imgBytes += f.size;
      } else if (isPdfFile(f.mimeType, f.name)) {
        pdfBytes += f.size;
      } else if (isVideoFile(f.mimeType, f.name) ||
          isAudioFile(f.mimeType, f.name)) {
        videoBytes += f.size;
      } else {
        otherBytes += f.size;
      }
    }

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(VaultRadii.sm),
      borderSide: BorderSide(color: p.rule),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(VaultRadii.sm),
      borderSide: BorderSide(color: p.cobalt, width: 1.5),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          s.settingsTitle,
          style: VaultText.display(p, s.ar, size: 26),
        ),
        const SizedBox(height: 4),
        Text(
          s.settingsSub,
          style: VaultText.body(p, s.ar, size: 13.5, color: p.muted),
        ),
        const SizedBox(height: 20),

        // 1. Account & Security Ledger
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.accountSectionTitle,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connected Telegram account + Sign out
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.displayAccountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VaultText.heading(p, s.ar, size: 15),
                          ),
                          if (ctrl.displayUsername != null &&
                              ctrl.displayUsername!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@${ctrl.displayUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VaultText.mono(p, size: 12, color: p.muted),
                            ),
                          ],
                          const SizedBox(height: 6),
                          VaultStatusDot(
                            palette: p,
                            isArabic: s.ar,
                            dotColor: ctrl.authStatus.isAuthorized
                                ? p.cobalt
                                : (ctrl.isReconnecting
                                    ? p.signal
                                    : p.danger),
                            label: ctrl.authStatus.isAuthorized
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
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: ctrl.logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.danger,
                        side: BorderSide(color: p.rule),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VaultRadii.sm),
                        ),
                      ),
                      child: Text(ctrl.demoMode ? s.exitPreview : s.signOut),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: p.rule),

              // Biometric / Face ID Lock
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 22,
                      color: ctrl.biometricEnabled ? p.signal : p.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.biometricLockTitle,
                            style: VaultText.heading(p, s.ar, size: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ctrl.biometricAvailable
                                ? s.biometricLockSub
                                : s.biometricUnavailable,
                            style: VaultText.body(p, s.ar,
                                size: 12, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: ctrl.biometricEnabled,
                      activeTrackColor: p.signal,
                      onChanged: (value) async {
                        HapticFeedback.selectionClick();
                        await ctrl.setBiometricEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: p.rule),

              // Client-Side Encryption
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 18, color: p.signal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.encryptionTitle,
                            style: VaultText.heading(p, s.ar, size: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ctrl.hasEncryptionPassword
                                ? p.signalSoft
                                : p.surfaceAlt,
                            borderRadius: BorderRadius.circular(VaultRadii.xs),
                            border: Border.all(
                              color: ctrl.hasEncryptionPassword
                                  ? p.signal.withValues(alpha: 0.45)
                                  : p.rule,
                            ),
                          ),
                          child: Text(
                            ctrl.hasEncryptionPassword
                                ? s.keyActiveBadge
                                : s.keyUnsetBadge,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 11,
                              weight: FontWeight.w700,
                              color:
                                  ctrl.hasEncryptionPassword ? p.ink : p.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.encryptionSub,
                      style: VaultText.body(p, s.ar, size: 12.5, color: p.muted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _encPassCtrl,
                      obscureText: true,
                      style: VaultText.body(p, s.ar, size: 14),
                      decoration: InputDecoration(
                        hintText: s.encPassHint,
                        hintStyle:
                            VaultText.body(p, s.ar, size: 14, color: p.muted),
                        filled: true,
                        fillColor: p.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedInputBorder,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              ctrl.setEncryptionPassword(_encPassCtrl.text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.signal,
                              foregroundColor: p.signalInk,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.sm),
                              ),
                            ),
                            child: Text(
                              s.applyPassword,
                              style: VaultText.body(
                                p,
                                s.ar,
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: p.signalInk,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            _encPassCtrl.clear();
                            ctrl.setEncryptionPassword(null);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.muted,
                            side: BorderSide(color: p.rule),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VaultRadii.sm),
                            ),
                          ),
                          child: Text(s.clear),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Display & Storage Ledger
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.displayAndStorageTitle,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Appearance & Language
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.appearanceTitle,
                        style: VaultText.heading(p, s.ar, size: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SegmentedPill(
                          palette: p,
                          isArabic: s.ar,
                          label: s.themeSystem,
                          active: ctrl.themeMode == ThemeMode.system,
                          onTap: () => ctrl.setThemeMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 8),
                        _SegmentedPill(
                          palette: p,
                          isArabic: s.ar,
                          label: s.themeLight,
                          active: ctrl.themeMode == ThemeMode.light,
                          onTap: () => ctrl.setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _SegmentedPill(
                          palette: p,
                          isArabic: s.ar,
                          label: s.themeDark,
                          active: ctrl.themeMode == ThemeMode.dark,
                          onTap: () => ctrl.setThemeMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SegmentedPill(
                          palette: p,
                          isArabic: s.ar,
                          label: 'English',
                          active: !ctrl.isArabic,
                          onTap: () => ctrl.setArabic(false),
                        ),
                        const SizedBox(width: 8),
                        _SegmentedPill(
                          palette: p,
                          isArabic: s.ar,
                          label: 'العربية',
                          active: ctrl.isArabic,
                          onTap: () => ctrl.setArabic(true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: p.rule),

              // Vault Storage Stats
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.storageStatsTitle,
                            style: VaultText.heading(p, s.ar, size: 15)),
                        Text(
                          formatBytes(totalBytes),
                          style: VaultText.tabular(
                            p,
                            s.ar,
                            size: 14,
                            weight: FontWeight.w700,
                            color: p.cobalt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.foldersAndFiles(
                          ctrl.snapshot.allFolders.length, files.length),
                      style: VaultText.tabular(p, s.ar, size: 12),
                    ),
                    const SizedBox(height: 12),
                    VaultProportionalTape(
                      palette: p,
                      imageBytes: imgBytes,
                      pdfBytes: pdfBytes,
                      videoAudioBytes: videoBytes,
                      otherBytes: otherBytes,
                      height: 6,
                      borderRadius: VaultRadii.pill,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _LegendDot(
                            palette: p,
                            isArabic: s.ar,
                            color: p.signal,
                            label: '${s.filterImages}: ${formatBytes(imgBytes)}'),
                        _LegendDot(
                            palette: p,
                            isArabic: s.ar,
                            color: p.danger,
                            label: 'PDF: ${formatBytes(pdfBytes)}'),
                        _LegendDot(
                            palette: p,
                            isArabic: s.ar,
                            color: p.cobalt,
                            label: '${s.filterVideo}: ${formatBytes(videoBytes)}'),
                        _LegendDot(
                            palette: p,
                            isArabic: s.ar,
                            color: p.ink,
                            label:
                                '${s.filterOther}: ${formatBytes(otherBytes)}'),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: p.rule),

              // Chunk Size (RTL-safe directional padding)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.uploadChunkSize,
                        style: VaultText.heading(p, s.ar, size: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: _chunks.map((mib) {
                        final active = ctrl.chunkSizeMiB == mib;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                                end: mib == _chunks.last ? 0 : 8),
                            child: VaultTap(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ctrl.setChunkSizeMiB(mib);
                              },
                              child: AnimatedContainer(
                                duration: motion,
                                curve: Curves.easeOutCubic,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: active ? p.cobalt : p.surfaceAlt,
                                  borderRadius:
                                      BorderRadius.circular(VaultRadii.sm),
                                  border: Border.all(
                                      color: active ? p.cobalt : p.rule),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$mib MiB',
                                  style: VaultText.tabular(
                                    p,
                                    s.ar,
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: active ? p.accentInk : p.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: p.rule),

              // Storage Destination
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.storageDestination,
                      style: VaultText.heading(p, s.ar, size: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.storageDestSub,
                      style: VaultText.body(p, s.ar, size: 12, color: p.muted),
                    ),
                    const SizedBox(height: 12),
                    VaultTap(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showStorageDestinationSheet(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          borderRadius: BorderRadius.circular(VaultRadii.sm),
                          border: Border.all(color: p.rule),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              ctrl.targetChatId == null
                                  ? Icons.bookmark_outline
                                  : (effectiveKind == 'channel'
                                      ? Icons.campaign_outlined
                                      : Icons.folder_shared_outlined),
                              size: 20,
                              color: p.cobalt,
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
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeDestSub,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: VaultText.body(
                                      p,
                                      s.ar,
                                      size: 12,
                                      color: p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              s.changeDestination,
                              style: VaultText.body(
                                p,
                                s.ar,
                                size: 13,
                                weight: FontWeight.w700,
                                color: p.cobalt,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: p.rule),

              // Local Cache Management
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.cacheTitle,
                            style: VaultText.heading(p, s.ar, size: 15)),
                        GestureDetector(
                          onTap: _loadCacheStats,
                          child: Text(
                            s.refresh,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: p.cobalt,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_cacheStats.fileCount} ${s.ar ? "ملف" : "files"}, ${formatBytes(_cacheStats.totalBytes)}',
                      style: VaultText.tabular(p, s.ar, size: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _cacheStats.fileCount == 0
                          ? null
                          : () async {
                              await ctrl.clearDownloadCache();
                              await _loadCacheStats();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.danger,
                        side: BorderSide(color: p.rule),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VaultRadii.sm),
                        ),
                      ),
                      child: Text(s.clearCache),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Encrypted Index Backup & Restore
        VaultSectionHeader(
          palette: p,
          isArabic: s.ar,
          title: s.backupRestoreTitle,
        ),
        VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _backupPassCtrl,
                obscureText: true,
                style: VaultText.body(p, s.ar, size: 14),
                decoration: InputDecoration(
                  hintText: s.backupPassHint,
                  hintStyle: VaultText.body(p, s.ar, size: 14, color: p.muted),
                  filled: true,
                  fillColor: p.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedInputBorder,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _restoreMsgIdCtrl,
                keyboardType: TextInputType.number,
                style: VaultText.body(p, s.ar, size: 14),
                decoration: InputDecoration(
                  hintText: s.msgIdHint,
                  hintStyle: VaultText.body(p, s.ar, size: 14, color: p.muted),
                  filled: true,
                  fillColor: p.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedInputBorder,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_backupPassCtrl.text.isEmpty) return;
                        ctrl.backupIndex(_backupPassCtrl.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.cobalt,
                        foregroundColor: p.accentInk,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VaultRadii.sm),
                        ),
                      ),
                      child: Text(s.backupIndex),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (_backupPassCtrl.text.isEmpty) return;
                        final msgId =
                            int.tryParse(_restoreMsgIdCtrl.text.trim());
                        ctrl.restoreIndex(_backupPassCtrl.text, msgId);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.ink,
                        side: BorderSide(color: p.rule),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VaultRadii.sm),
                        ),
                      ),
                      child: Text(s.restoreIndex),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentedPill extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentedPill({
    required this.palette,
    required this.isArabic,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final motion = vaultMotion(context, 160);
    return Expanded(
      child: VaultTap(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: motion,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? palette.cobalt : palette.surfaceAlt,
            borderRadius: BorderRadius.circular(VaultRadii.sm),
            border: Border.all(
                color: active ? palette.cobalt : palette.rule),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: VaultText.body(
              palette,
              isArabic,
              size: 12.5,
              weight: FontWeight.w700,
              color: active ? palette.accentInk : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final Color color;
  final String label;

  const _LegendDot({
    required this.palette,
    required this.isArabic,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: VaultText.tabular(palette, isArabic,
              size: 11.5, weight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _StorageDestinationSheet extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;

  const _StorageDestinationSheet({
    required this.palette,
    required this.controller,
  });

  @override
  State<_StorageDestinationSheet> createState() =>
      _StorageDestinationSheetState();
}

class _StorageDestinationSheetState extends State<_StorageDestinationSheet> {
  final _searchCtrl = TextEditingController();
  final _newVaultCtrl = TextEditingController();
  late bool _ownedOnly;
  bool _showCreateForm = false;
  String _newVaultKind = 'group';
  bool _awaitingCreatedVault = false;

  @override
  void initState() {
    super.initState();
    final ctrl = widget.controller;
    final selected = ctrl.storageChats
        .where((c) => c.id == ctrl.targetChatId)
        .firstOrNull;
    _ownedOnly = selected == null || selected.isCreator;
    ctrl.addListener(_onControllerChanged);
    if (ctrl.hasNativeCore && !ctrl.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ctrl.refreshChats();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchCtrl.dispose();
    _newVaultCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_awaitingCreatedVault && !widget.controller.isCreatingVault) {
      _awaitingCreatedVault = false;
      if (mounted && widget.controller.targetChatId != null) {
        Navigator.pop(context);
      }
    }
  }

  void _submitNewVault() {
    final name = _newVaultCtrl.text.trim();
    final ctrl = widget.controller;
    if (name.isEmpty || ctrl.isCreatingVault) return;
    HapticFeedback.mediumImpact();
    if (ctrl.demoMode || !ctrl.hasNativeCore) {
      ctrl.createStorageVault(title: name, kind: _newVaultKind);
      if (mounted) Navigator.pop(context);
      return;
    }
    _awaitingCreatedVault = true;
    ctrl.createStorageVault(title: name, kind: _newVaultKind);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final s = ctrl.strings;
        final motion = vaultMotion(context, 180);
        final query = _searchCtrl.text.trim().toLowerCase();
        final ownedChats = ctrl.storageChats.where((c) => c.isCreator).toList();
        final sourceChats = _ownedOnly ? ownedChats : ctrl.storageChats;
        final filteredChats = query.isEmpty
            ? sourceChats
            : sourceChats
                .where((c) => c.title.toLowerCase().contains(query))
                .toList();
        final showSavedMessages = query.isEmpty ||
            s.savedMessagesDefault.toLowerCase().contains(query) ||
            'saved messages'.contains(query);

        final inputBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(VaultRadii.sm),
          borderSide: BorderSide(color: p.rule),
        );
        final focusedInputBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(VaultRadii.sm),
          borderSide: BorderSide(color: p.cobalt, width: 1.5),
        );

        return Directionality(
          textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
          child: VaultSheetShell(
            palette: p,
            outerPadding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          s.storageDestination,
                          style: VaultText.heading(p, s.ar, size: 17),
                        ),
                      ),
                      const SizedBox(width: 8),
                      VaultTap(
                        onTap: ctrl.isLoadingChats
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ctrl.refreshChats();
                              },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ctrl.isLoadingChats)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.cobalt,
                                ),
                              )
                            else
                              AppSvgIcon(
                                AppIcons.refresh,
                                size: 14,
                                color: p.cobalt,
                              ),
                            const SizedBox(width: 5),
                            Text(
                              s.refresh,
                              style: VaultText.body(
                                p,
                                s.ar,
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: p.cobalt,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.storageDestSub,
                    style: VaultText.body(p, s.ar, size: 12.5, color: p.muted),
                  ),
                  const SizedBox(height: 12),

                  // Toggle inline New Private Vault form
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showCreateForm = !_showCreateForm);
                    },
                    icon: Icon(
                      _showCreateForm ? Icons.close : Icons.add,
                      size: 16,
                      color: p.cobalt,
                    ),
                    label: Text(s.newPrivateVaultBtn),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.cobalt,
                      side: BorderSide(
                        color: _showCreateForm ? p.cobalt : p.rule,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VaultRadii.sm),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: motion,
                    curve: Curves.easeOutCubic,
                    child: _showCreateForm
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.surfaceAlt,
                              borderRadius:
                                  BorderRadius.circular(VaultRadii.sm),
                              border: Border.all(color: p.rule),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _newVaultCtrl,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submitNewVault(),
                                  style: VaultText.body(p, s.ar, size: 14),
                                  decoration: InputDecoration(
                                    hintText: s.newVaultNameHint,
                                    hintStyle: VaultText.body(p, s.ar,
                                        size: 13.5, color: p.muted),
                                    filled: true,
                                    fillColor: p.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: inputBorder,
                                    enabledBorder: inputBorder,
                                    focusedBorder: focusedInputBorder,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _SegmentedPill(
                                      palette: p,
                                      isArabic: s.ar,
                                      label: s.privateGroupOption,
                                      active: _newVaultKind == 'group',
                                      onTap: () => setState(
                                          () => _newVaultKind = 'group'),
                                    ),
                                    const SizedBox(width: 8),
                                    _SegmentedPill(
                                      palette: p,
                                      isArabic: s.ar,
                                      label: s.privateChannelOption,
                                      active: _newVaultKind == 'channel',
                                      onTap: () => setState(
                                          () => _newVaultKind = 'channel'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: ctrl.isCreatingVault
                                      ? null
                                      : _submitNewVault,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: p.signal,
                                    foregroundColor: p.signalInk,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(VaultRadii.sm),
                                    ),
                                  ),
                                  child: Text(
                                    ctrl.isCreatingVault
                                        ? s.creatingVaultLabel
                                        : s.createAndSelectVault,
                                    style: VaultText.body(
                                      p,
                                      s.ar,
                                      size: 13.5,
                                      weight: FontWeight.w700,
                                      color: p.signalInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),

                  // Recessed Search Bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(VaultRadii.sm),
                      border: Border.all(color: p.rule),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 17, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            style: VaultText.body(p, s.ar, size: 14),
                            decoration: InputDecoration(
                              hintText: s.searchVaultChatsHint,
                              hintStyle: VaultText.body(p, s.ar,
                                  size: 13.5, color: p.muted),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchCtrl.clear()),
                            child: Icon(Icons.close, size: 16, color: p.muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Baseline-indexed ownership filter tabs
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: p.rule, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        _SheetFilterTab(
                          palette: p,
                          isArabic: s.ar,
                          label: s.filterOwnedByMe,
                          count: ownedChats.length,
                          active: _ownedOnly,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _ownedOnly = true);
                          },
                        ),
                        const SizedBox(width: 8),
                        _SheetFilterTab(
                          palette: p,
                          isArabic: s.ar,
                          label: s.filterAdminAccess,
                          count: ctrl.storageChats.length,
                          active: !_ownedOnly,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _ownedOnly = false);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Scrollable Destination Ledger
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (showSavedMessages)
                          _DestinationLedgerRow(
                            palette: p,
                            isArabic: s.ar,
                            icon: Icons.bookmark_outline,
                            title: s.savedMessagesDefault,
                            subtitle: s.vaultSealLabel,
                            selected: ctrl.targetChatId == null,
                            showTopBorder: false,
                            onTap: () {
                              ctrl.setTargetChat(null);
                              Navigator.pop(context);
                            },
                          ),
                        for (var i = 0; i < filteredChats.length; i++)
                          _DestinationLedgerRow(
                            palette: p,
                            isArabic: s.ar,
                            icon: filteredChats[i].kind == 'channel'
                                ? Icons.campaign_outlined
                                : Icons.folder_shared_outlined,
                            title: filteredChats[i].title,
                            subtitle: _formatChatMeta(filteredChats[i], s),
                            selected: ctrl.targetChatId == filteredChats[i].id,
                            showTopBorder: showSavedMessages || i > 0,
                            onTap: () {
                              ctrl.setTargetChat(filteredChats[i].id);
                              Navigator.pop(context);
                            },
                          ),
                        if (filteredChats.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 18),
                            child: Text(
                              s.noOwnedChatsFound,
                              textAlign: TextAlign.center,
                              style: VaultText.body(p, s.ar,
                                  size: 13, color: p.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatChatMeta(StorageChat chat, AppStrings s) {
    final sep = s.ar ? '، ' : ', ';
    final parts = <String>[
      chat.kind == 'channel' ? s.channelKindLabel : s.groupKindLabel,
      chat.isCreator ? s.roleOwnerBadge : s.roleAdminBadge,
      if (chat.isPrivate) s.privateBadge,
      if (chat.memberCount != null) s.membersCountLabel(chat.memberCount!),
    ];
    return parts.join(sep);
  }
}

class _SheetFilterTab extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _SheetFilterTab({
    required this.palette,
    required this.isArabic,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VaultTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? palette.cobalt : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: VaultText.body(
                palette,
                isArabic,
                size: 12.5,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? palette.ink : palette.muted,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: VaultText.tabular(
                palette,
                isArabic,
                size: 11.5,
                weight: FontWeight.w600,
                color: active ? palette.cobalt : palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationLedgerRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool showTopBorder;
  final VoidCallback onTap;

  const _DestinationLedgerRow({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.showTopBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.cobaltSoft : Colors.transparent,
          border: showTopBorder
              ? Border(top: BorderSide(color: palette.rule, width: 1))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? palette.cobalt : palette.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.body(
                      palette,
                      isArabic,
                      size: 14,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? palette.cobalt : palette.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.body(
                      palette,
                      isArabic,
                      size: 11.5,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: palette.cobalt),
          ],
        ),
      ),
    );
  }
}

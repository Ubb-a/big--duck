import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'vault_surface.dart';

Future<void> showStorageDestinationSheet(
  BuildContext context, {
  required AppPalette palette,
  required AppController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _StorageDestinationSheet(
      palette: palette,
      controller: controller,
    ),
  );
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
        final motion = vaultMotion(context, 250);
        final query = _searchCtrl.text.trim().toLowerCase();
        final ownedChats =
            ctrl.storageChats.where((c) => c.isCreator).toList(growable: false);
        final sourceChats = _ownedOnly ? ownedChats : ctrl.storageChats;
        final filteredChats = query.isEmpty
            ? sourceChats
            : sourceChats
                .where((c) => c.title.toLowerCase().contains(query))
                .toList(growable: false);
        final showSavedMessages = query.isEmpty ||
            s.savedMessagesDefault.toLowerCase().contains(query) ||
            'saved messages'.contains(query);

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
                maxHeight: MediaQuery.of(context).size.height * 0.80,
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
                          style: VaultText.heading(p, s.ar, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      VaultMonoChip(
                        palette: p,
                        label: s.refresh,
                        icon: ctrl.isLoadingChats ? null : Icons.refresh_rounded,
                        dotColor: ctrl.isLoadingChats ? p.champagne : null,
                        onTap: ctrl.isLoadingChats
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ctrl.refreshChats();
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.storageDestSub,
                    style: VaultText.body(p, s.ar, size: 13, color: p.secondary),
                  ),
                  const SizedBox(height: 14),

                  VaultGlassSearchField(
                    palette: p,
                    isArabic: s.ar,
                    controller: _searchCtrl,
                    hintText: s.searchVaultChatsHint,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),

                  VaultSegmentedControl<bool>(
                    palette: p,
                    isArabic: s.ar,
                    value: _ownedOnly,
                    onChanged: (owned) => setState(() => _ownedOnly = owned),
                    options: [
                      VaultSegmentOption(
                        value: true,
                        label: '${s.filterOwnedByMe} (${ownedChats.length})',
                      ),
                      VaultSegmentOption(
                        value: false,
                        label:
                            '${s.filterAdminAccess} (${ctrl.storageChats.length})',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (showSavedMessages)
                          _ChatRow(
                            palette: p,
                            isArabic: s.ar,
                            initials: 'SM',
                            isSavedMessages: true,
                            title: s.savedMessagesDefault,
                            kindLabel: s.privateBadge,
                            roleLabel: s.roleOwnerBadge,
                            isOwner: true,
                            selected: ctrl.targetChatId == null,
                            onTap: () {
                              ctrl.setTargetChat(null);
                              Navigator.pop(context);
                            },
                          ),
                        for (final chat in filteredChats)
                          _ChatRow(
                            palette: p,
                            isArabic: s.ar,
                            initials: _initialsForTitle(chat.title),
                            isSavedMessages: false,
                            title: chat.title,
                            kindLabel: chat.kind == 'channel'
                                ? s.channelKindLabel
                                : s.groupKindLabel,
                            roleLabel: chat.isCreator
                                ? s.roleOwnerBadge
                                : s.roleAdminBadge,
                            isOwner: chat.isCreator,
                            selected: ctrl.targetChatId == chat.id,
                            onTap: () {
                              ctrl.setTargetChat(chat.id);
                              Navigator.pop(context);
                            },
                          ),
                        if (filteredChats.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 20),
                            child: Text(
                              s.noOwnedChatsFound,
                              textAlign: TextAlign.center,
                              style: VaultText.body(p, s.ar,
                                  size: 13, color: p.secondary),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  AnimatedSize(
                    duration: motion,
                    curve: Curves.easeOut,
                    child: _showCreateForm
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VaultSurface(
                              palette: p,
                              borderRadius: VaultRadii.md,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _newVaultCtrl,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submitNewVault(),
                                    style: VaultText.body(p, s.ar,
                                        size: 14, applyArabicScale: false),
                                    decoration: InputDecoration(
                                      hintText: s.newVaultNameHint,
                                      hintStyle: VaultText.monoText(
                                        p,
                                        s.newVaultNameHint,
                                        size: 12,
                                        color: p.secondary,
                                      ),
                                      filled: true,
                                      fillColor: p.glassFill,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 11),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            VaultRadii.tile),
                                        borderSide:
                                            BorderSide(color: p.glassBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            VaultRadii.tile),
                                        borderSide:
                                            BorderSide(color: p.glassBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            VaultRadii.tile),
                                        borderSide:
                                            BorderSide(color: p.champagne),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  VaultSegmentedControl<String>(
                                    palette: p,
                                    isArabic: s.ar,
                                    value: _newVaultKind,
                                    onChanged: (v) =>
                                        setState(() => _newVaultKind = v),
                                    options: [
                                      VaultSegmentOption(
                                        value: 'group',
                                        label: s.privateGroupOption,
                                      ),
                                      VaultSegmentOption(
                                        value: 'channel',
                                        label: s.privateChannelOption,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: VaultPillButton(
                                          palette: p,
                                          isArabic: s.ar,
                                          variant: VaultPillVariant.secondary,
                                          height: 44,
                                          label: s.cancel,
                                          onPressed: () => setState(
                                              () => _showCreateForm = false),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: VaultPillButton(
                                          palette: p,
                                          isArabic: s.ar,
                                          height: 44,
                                          loading: ctrl.isCreatingVault,
                                          label: ctrl.isCreatingVault
                                              ? s.creatingVaultLabel
                                              : s.createAndSelectVault,
                                          onPressed: _submitNewVault,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  if (!_showCreateForm)
                    VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      variant: VaultPillVariant.primary,
                      icon: Icons.add_rounded,
                      label: s.newPrivateVaultBtn,
                      onPressed: () => setState(() => _showCreateForm = true),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _initialsForTitle(String title) {
    final parts = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'VA';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _ChatRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String initials;
  final bool isSavedMessages;
  final String title;
  final String kindLabel;
  final String roleLabel;
  final bool isOwner;
  final bool selected;
  final VoidCallback onTap;

  const _ChatRow({
    required this.palette,
    required this.isArabic,
    required this.initials,
    required this.isSavedMessages,
    required this.title,
    required this.kindLabel,
    required this.roleLabel,
    required this.isOwner,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VaultTap(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          backgroundColor: selected ? p.champagneSoft : p.glassFill,
          borderColor: selected ? p.champagne : p.glassBorder,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? p.primaryBtnFill : p.glassElevatedFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.glassBorder),
                ),
                alignment: Alignment.center,
                child: isSavedMessages
                    ? Icon(
                        Icons.bookmark_border_rounded,
                        size: 18,
                        color: selected ? p.primaryBtnInk : p.champagne,
                      )
                    : Text(
                        initials,
                        style: VaultText.mono(
                          p,
                          size: 12,
                          weight: FontWeight.w600,
                          color: selected ? p.primaryBtnInk : p.ink,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.body(
                        p,
                        isArabic,
                        size: 14,
                        weight: FontWeight.w600,
                        applyArabicScale: false,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        VaultMonoChip(
                          palette: p,
                          label: kindLabel,
                        ),
                        VaultMonoChip(
                          palette: p,
                          label: roleLabel,
                          dotColor: isOwner ? p.signalGreen : p.champagne,
                          textColor: isOwner ? p.signalGreen : p.secondary,
                          backgroundColor:
                              isOwner ? p.signalGreenSoft : p.glassFill,
                          borderColor: isOwner
                              ? p.signalGreen.withValues(alpha: 0.35)
                              : p.glassBorder,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 20, color: p.signalGreen),
            ],
          ),
        ),
      ),
    );
  }
}

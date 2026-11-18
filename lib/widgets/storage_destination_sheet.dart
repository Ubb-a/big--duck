import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'vault_motion_widgets.dart';
import 'vault_surface.dart';

Future<void> showStorageDestinationSheet(
  BuildContext context, {
  required AppPalette palette,
  required AppController controller,
}) {
  return showVaultBottomSheet<void>(
    context: context,
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

class _StorageDestinationSheetState extends State<_StorageDestinationSheet>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _newVaultCtrl = TextEditingController();
  late final AnimationController _feedbackCtrl;
  late bool _ownedOnly;
  bool _showCreateForm = false;
  String _newVaultKind = 'group';
  bool _awaitingCreatedVault = false;
  bool _vaultCreateCompleted = false;
  int? _justCreatedChatId;

  @override
  void initState() {
    super.initState();
    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
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
    _feedbackCtrl.dispose();
    _searchCtrl.dispose();
    _newVaultCtrl.dispose();
    super.dispose();
  }

  void _finishAndClose() {
    if (!mounted) return;
    if (vaultMotion.isReduced(context)) {
      Navigator.pop(context);
      return;
    }
    _feedbackCtrl.duration = vaultMotion.duration(
      context,
      const Duration(milliseconds: 220),
    );
    _feedbackCtrl.forward(from: 0).whenComplete(() {
      if (mounted) Navigator.pop(context);
    });
  }

  void _onControllerChanged() {
    if (_awaitingCreatedVault && !widget.controller.isCreatingVault) {
      _awaitingCreatedVault = false;
      if (mounted && widget.controller.targetChatId != null) {
        setState(() {
          _vaultCreateCompleted = true;
          _justCreatedChatId = widget.controller.targetChatId;
        });
        _finishAndClose();
      }
    }
  }

  void _submitNewVault() {
    final name = _newVaultCtrl.text.trim();
    final ctrl = widget.controller;
    if (name.isEmpty || ctrl.isCreatingVault || _vaultCreateCompleted) return;
    VaultHaptics.medium();
    if (ctrl.demoMode || !ctrl.hasNativeCore) {
      ctrl.createStorageVault(title: name, kind: _newVaultKind);
      setState(() {
        _vaultCreateCompleted = true;
        _justCreatedChatId = ctrl.targetChatId;
      });
      VaultHaptics.success();
      _finishAndClose();
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
                                VaultHaptics.selection();
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
                          VaultStaggeredSlideFade(
                            index: 0,
                            dy: 8,
                            child: _ChatRow(
                              palette: p,
                              isArabic: s.ar,
                              initials: 'SM',
                              isSavedMessages: true,
                              title: s.savedMessagesDefault,
                              kindLabel: s.privateBadge,
                              roleLabel: s.roleOwnerBadge,
                              isOwner: true,
                              selected: ctrl.targetChatId == null,
                              highlighted: false,
                              onTap: () {
                                ctrl.setTargetChat(null);
                                _finishAndClose();
                              },
                            ),
                          ),
                        for (int i = 0; i < filteredChats.length; i++)
                          VaultStaggeredSlideFade(
                            index: i + (showSavedMessages ? 1 : 0),
                            dy: 8,
                            child: _ChatRow(
                              palette: p,
                              isArabic: s.ar,
                              initials: _initialsForTitle(filteredChats[i].title),
                              isSavedMessages: false,
                              title: filteredChats[i].title,
                              kindLabel: filteredChats[i].kind == 'channel'
                                  ? s.channelKindLabel
                                  : s.groupKindLabel,
                              roleLabel: filteredChats[i].isCreator
                                  ? s.roleOwnerBadge
                                  : s.roleAdminBadge,
                              isOwner: filteredChats[i].isCreator,
                              selected: ctrl.targetChatId == filteredChats[i].id,
                              highlighted:
                                  _justCreatedChatId == filteredChats[i].id,
                              onTap: () {
                                ctrl.setTargetChat(filteredChats[i].id);
                                _finishAndClose();
                              },
                            ),
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
                    curve: vaultMotion.standard,
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
                                  VaultGlassInputContainer(
                                    palette: p,
                                    borderRadius: VaultRadii.tile,
                                    builder: (context, focusNode) => TextField(
                                      controller: _newVaultCtrl,
                                      focusNode: focusNode,
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
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 11),
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
                                          completed: _vaultCreateCompleted,
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
  final bool highlighted;
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
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fast = vaultMotion.duration(context, vaultMotion.fast);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VaultTap(
        onTap: () {
          VaultHaptics.selection();
          onTap();
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: highlighted ? 1.0 : 0.0, end: 0.0),
          duration: vaultMotion.duration(
              context, const Duration(milliseconds: 600)),
          curve: vaultMotion.standard,
          builder: (_, glowT, child) => AnimatedContainer(
            duration: fast,
            curve: vaultMotion.standard,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VaultRadii.md),
              boxShadow: glowT > 0.02 || highlighted
                  ? [
                      BoxShadow(
                        color: p.champagne.withValues(
                            alpha: 0.28 * glowT.clamp(0.15, 1.0)),
                        blurRadius: 16,
                      ),
                    ]
                  : const [],
            ),
            child: child,
          ),
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
                          AnimatedScale(
                            scale: selected ? 1.0 : 0.96,
                            duration: fast,
                            curve: vaultMotion.standard,
                            child: VaultMonoChip(
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: p.signalGreenSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: VaultAnimatedDrawCheck(
                      color: p.signalGreen,
                      size: 16,
                      strokeWidth: 2.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/storage_destination_sheet.dart';
import '../widgets/vault_motion_widgets.dart';
import '../widgets/vault_surface.dart';
import 'preview_screen.dart';

enum _SortBy { date, name, size }

enum _FileFilter { all, folders, images, pdf, video, other }

class FilesScreen extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;
  final bool isRecent;
  final double bottomPadding;

  const FilesScreen({
    super.key,
    required this.palette,
    required this.controller,
    required this.isRecent,
    required this.bottomPadding,
  });

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  final ValueNotifier<double> _parallaxShift = ValueNotifier<double>(0.0);

  late final AnimationController _enterCtrl;
  late final AnimationController _plusMenuCtrl;

  bool _gridMode = false;
  bool _showFilters = false;
  bool _searchFocused = false;
  bool _plusMenuOpen = false;
  _SortBy _sortBy = _SortBy.date;
  bool _sortAsc = false;
  _FileFilter _filter = _FileFilter.all;

  double _scrollOffset = 0.0;
  int _navDirection = 1; // +1 into folder, -1 up to ancestor
  int? _lastFolderId;

  bool _selectionMode = false;
  final Set<int> _selectedFolderIds = {};
  final Set<int> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _lastFolderId = widget.controller.snapshot.currentFolder?.id;
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
    _plusMenuCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.base,
    );
    _scrollCtrl.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (mounted && _searchFocused != _searchFocus.hasFocus) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset.clamp(0.0, 240.0);
    _parallaxShift.value = ((offset % 120.0) / 120.0) * 12.0;
    if ((offset - _scrollOffset).abs() > 1.5 && mounted) {
      setState(() => _scrollOffset = offset);
    }
    final dir = _scrollCtrl.position.userScrollDirection;
    if (offset <= 8.0 || _scrollCtrl.position.maxScrollExtent <= 8.0) {
      widget.controller.setNavHiddenByScroll(false);
    } else if (dir == ScrollDirection.reverse) {
      widget.controller.setNavHiddenByScroll(true);
    } else if (dir == ScrollDirection.forward) {
      widget.controller.setNavHiddenByScroll(false);
    }
  }

  @override
  void didUpdateWidget(covariant FilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newFolderId = widget.controller.snapshot.currentFolder?.id;
    if (newFolderId != _lastFolderId) {
      _lastFolderId = newFolderId;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _parallaxShift.dispose();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    _enterCtrl.dispose();
    _plusMenuCtrl.dispose();
    super.dispose();
  }

  int get _totalSelected =>
      _selectedFolderIds.length + _selectedFileIds.length;

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedFolderIds.clear();
      _selectedFileIds.clear();
    });
    widget.controller.setSelecting(false);
  }

  void _navigateToFolder(int? folderId, {bool isBack = false}) {
    if (_selectionMode ||
        _selectedFolderIds.isNotEmpty ||
        _selectedFileIds.isNotEmpty) {
      _exitSelectionMode();
    }
    setState(() => _navDirection = isBack ? -1 : 1);
    VaultHaptics.selection();
    widget.controller.openFolder(folderId);
  }

  void _toggleFolderSelection(int id, {bool viaLongPress = false}) {
    if (viaLongPress) {
      VaultHaptics.medium();
    } else {
      VaultHaptics.selection();
    }
    setState(() {
      _selectionMode = true;
      if (!_selectedFolderIds.add(id)) {
        _selectedFolderIds.remove(id);
      }
      if (_totalSelected == 0) _selectionMode = false;
    });
    widget.controller.setSelecting(_selectionMode);
  }

  void _toggleFileSelection(int id, {bool viaLongPress = false}) {
    if (viaLongPress) {
      VaultHaptics.medium();
    } else {
      VaultHaptics.selection();
    }
    setState(() {
      _selectionMode = true;
      if (!_selectedFileIds.add(id)) {
        _selectedFileIds.remove(id);
      }
      if (_totalSelected == 0) _selectionMode = false;
    });
    widget.controller.setSelecting(_selectionMode);
  }

  void _togglePlusMenu() {
    VaultHaptics.medium();
    final opening = !_plusMenuOpen;
    setState(() => _plusMenuOpen = opening);
    if (opening) {
      _plusMenuCtrl.forward();
    } else {
      _plusMenuCtrl.reverse();
    }
  }

  void _closePlusMenu() {
    if (!_plusMenuOpen) return;
    setState(() => _plusMenuOpen = false);
    _plusMenuCtrl.reverse();
  }

  Future<List<String>> _pickDocuments() async {
    try {
      final files = await FilePicker.pickFiles();
      return files.map((f) => f.path).whereType<String>().toList();
    } catch (e) {
      if (mounted) widget.controller.showToast('$e', isError: true);
      return const [];
    }
  }

  Future<List<String>> _pickMedia() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultipleMedia();
      return files.map((x) => x.path).toList();
    } catch (e) {
      if (mounted) widget.controller.showToast('$e', isError: true);
      return const [];
    }
  }

  void _showUploadBottomSheet() {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    int? chosenFolderId = ctrl.snapshot.currentFolder?.id;
    var encryptUpload = ctrl.encryptBeforeUpload;
    var chosenPaths = <String>[];

    showVaultBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final folderName = chosenFolderId == null
              ? s.rootFolderLabel
              : (ctrl.snapshot.allFolders
                      .where((f) => f.id == chosenFolderId)
                      .firstOrNull
                      ?.name ??
                  s.rootFolderLabel);
          return Directionality(
            textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
            child: VaultSheetShell(
              palette: p,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.encryptAndUpload,
                    style: VaultText.heading(p, s.ar, size: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.uploadDesc,
                    style:
                        VaultText.body(p, s.ar, size: 13, color: p.secondary),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _MenuGlassTile(
                          palette: p,
                          isArabic: s.ar,
                          icon: Icons.description_outlined,
                          title: s.uploadDocs,
                          subtitle: s.uploadDocsSub,
                          tone: p.champagne,
                          onTap: () async {
                            final paths = await _pickDocuments();
                            if (paths.isNotEmpty) {
                              setSheetState(() => chosenPaths = paths);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MenuGlassTile(
                          palette: p,
                          isArabic: s.ar,
                          icon: Icons.photo_library_outlined,
                          title: s.uploadMedia,
                          subtitle: s.uploadMediaSub,
                          tone: p.champagne,
                          onTap: () async {
                            final paths = await _pickMedia();
                            if (paths.isNotEmpty) {
                              setSheetState(() => chosenPaths = paths);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  if (chosenPaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    VaultSurface(
                      palette: p,
                      borderRadius: VaultRadii.tile,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          VaultAnimatedDrawCheck(
                            color: p.signalGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chosenPaths.length == 1
                                  ? chosenPaths.first.split(RegExp(r'[/\\]')).last
                                  : '${chosenPaths.length} ${s.ar ? "ملفات محددة" : "files selected"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VaultText.monoText(
                                p,
                                chosenPaths.first,
                                size: 11.5,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  VaultTap(
                    onTap: () async {
                      await _showMoveFolderPickerSheet(
                        initialSelectedId: chosenFolderId,
                        confirmLabel: s.save,
                        onPickTarget: (picked) =>
                            setSheetState(() => chosenFolderId = picked),
                      );
                    },
                    child: VaultSurface(
                      palette: p,
                      borderRadius: VaultRadii.md,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined,
                              size: 18, color: p.champagne),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.destinationFolderLabel,
                                  style: VaultText.monoText(
                                    p,
                                    s.destinationFolderLabel,
                                    size: 10.5,
                                    color: p.secondary,
                                  ),
                                ),
                                Text(
                                  folderName,
                                  style: VaultText.body(p, s.ar,
                                      size: 14,
                                      weight: FontWeight.w500,
                                      applyArabicScale: false),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            s.ar
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                            color: p.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  VaultSurface(
                    palette: p,
                    borderRadius: VaultRadii.md,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color:
                              encryptUpload ? p.signalGreen : p.secondary,
                        ),
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
                          value: encryptUpload,
                          onChanged: (v) =>
                              setSheetState(() => encryptUpload = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  VaultPillButton(
                    palette: p,
                    isArabic: s.ar,
                    label: s.upload,
                    icon: Icons.arrow_upward_rounded,
                    onPressed: () async {
                      List<String> toUpload = chosenPaths;
                      if (toUpload.isEmpty) {
                        toUpload = await _pickDocuments();
                      }
                      if (toUpload.isNotEmpty) {
                        ctrl.setEncryptBeforeUpload(encryptUpload);
                        ctrl.uploadFiles(
                          toUpload,
                          targetFolderId: chosenFolderId,
                          encryptedOverride: encryptUpload,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNewFolderDialog() {
    final p = widget.palette;
    final s = widget.controller.strings;
    showVaultDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: _PromptDialogForm(
          palette: p,
          isArabic: s.ar,
          title: s.newFolder,
          hintText: s.folderNameHint,
          cancelLabel: s.cancel,
          confirmLabel: s.create,
          onSubmit: widget.controller.createFolder,
        ),
      ),
    );
  }

  void _showRenameDialog({
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) {
    final p = widget.palette;
    final s = widget.controller.strings;
    showVaultDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: _PromptDialogForm(
          palette: p,
          isArabic: s.ar,
          title: title,
          initialText: initial,
          cancelLabel: s.cancel,
          confirmLabel: s.save,
          useSquareConfirm: true,
          onSubmit: onSave,
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog({
    required int count,
    required VoidCallback onConfirm,
  }) {
    final p = widget.palette;
    final s = widget.controller.strings;
    showVaultDialog<void>(
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
                    icon: Icons.delete_outline_rounded,
                    onTap: null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.deleteConfirmTitle,
                      style: VaultText.heading(p, s.ar, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.deleteConfirmDesc(count),
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
                      label: s.deleteAction,
                      onPressed: () {
                        VaultHaptics.error();
                        Navigator.pop(ctx);
                        onConfirm();
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

  Future<void> _showMoveFolderPickerSheet({
    List<int> excludedFolderIds = const [],
    int? initialSelectedId,
    String? confirmLabel,
    required ValueChanged<int?> onPickTarget,
  }) async {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final validFolders = ctrl.snapshot.allFolders.where((f) {
      for (final ex in excludedFolderIds) {
        if (ctrl.isDescendantFolder(f.id, ex)) return false;
      }
      return true;
    }).toList();

    final expandedIds = <int>{};
    int? selectedTarget = initialSelectedId ?? ctrl.snapshot.currentFolder?.id;

    List<Folder> childrenOf(int? parentId) =>
        validFolders.where((f) => f.parentId == parentId).toList();

    await showVaultBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Widget buildBranch(Folder folder, int depth) {
            final kids = childrenOf(folder.id);
            final expanded = expandedIds.contains(folder.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TreePickerRow(
                  palette: p,
                  isArabic: s.ar,
                  icon: Icons.folder_outlined,
                  title: folder.name,
                  depth: depth,
                  selected: selectedTarget == folder.id,
                  hasChildren: kids.isNotEmpty,
                  expanded: expanded,
                  onToggleExpand: kids.isNotEmpty
                      ? () {
                          VaultHaptics.selection();
                          setSheetState(() {
                            if (!expandedIds.add(folder.id)) {
                              expandedIds.remove(folder.id);
                            }
                          });
                        }
                      : null,
                  onTap: () {
                    VaultHaptics.selection();
                    setSheetState(() => selectedTarget = folder.id);
                  },
                ),
                AnimatedSize(
                  duration: vaultMotion.duration(context, vaultMotion.base),
                  curve: vaultMotion.standard,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Column(
                          children: [
                            for (final kid in kids) buildBranch(kid, depth + 1),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }

          final rootFolders = childrenOf(null);
          return Directionality(
            textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
            child: VaultSheetShell(
              palette: p,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.moveToTitle,
                        style: VaultText.heading(p, s.ar, size: 20)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _TreePickerRow(
                              palette: p,
                              isArabic: s.ar,
                              icon: Icons.home_outlined,
                              title: s.rootFolderLabel,
                              depth: 0,
                              selected: selectedTarget == null,
                              hasChildren: false,
                              expanded: true,
                              onTap: () =>
                                  setSheetState(() => selectedTarget = null),
                            ),
                            for (final folder in rootFolders)
                              buildBranch(folder, 1),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    VaultPillButton(
                      palette: p,
                      isArabic: s.ar,
                      label: confirmLabel ?? s.moveHereCta,
                      onPressed: () {
                        Navigator.pop(ctx);
                        onPickTarget(selectedTarget);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPreview(FileRecord file) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: vaultMotion.duration(context, vaultMotion.slow),
        reverseTransitionDuration:
            vaultMotion.duration(context, vaultMotion.base),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: vaultMotion.emphasized,
          ),
          child: PreviewScreen(
            palette: widget.palette,
            controller: widget.controller,
            file: file,
            heroTag: _gridMode
                ? 'grid_vault_item_${file.id}'
                : 'list_vault_item_${file.id}',
          ),
        ),
      ),
    );
  }

  void _showFileInspector(FileRecord file) {
    VaultHaptics.light();
    final p = widget.palette;
    final s = widget.controller.strings;
    showVaultBottomSheet<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultSheetShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.glassFill,
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
                      border: Border.all(color: p.glassBorder),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      iconForMimeOrName(file.mimeType, file.name),
                      color: p.champagne,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: VaultText.heading(p, s.ar, size: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatBytes(file.size)} · ${file.isEncrypted ? s.aesVerifiedLabel : s.keyUnsetBadge}',
                          style: VaultText.monoText(
                            p,
                            s.aesVerifiedLabel,
                            size: 11.5,
                            color: p.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (file.sha256.isNotEmpty) ...[
                const SizedBox(height: 12),
                VaultSurface(
                  palette: p,
                  borderRadius: VaultRadii.tile,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'SHA-256  ${file.sha256}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.mono(p, size: 11, color: p.secondary),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (isPreviewableFile(file.mimeType, file.name)) ...[
                _MenuGlassTile(
                  palette: p,
                  isArabic: s.ar,
                  icon: Icons.visibility_outlined,
                  title: isPdfFile(file.mimeType, file.name)
                      ? s.previewPdf
                      : (isVideoFile(file.mimeType, file.name)
                          ? s.previewVideo
                          : (isAudioFile(file.mimeType, file.name)
                              ? s.previewAudio
                              : s.previewImage)),
                  tone: p.champagne,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPreview(file);
                  },
                ),
                const SizedBox(height: 8),
              ],
              _MenuGlassTile(
                palette: p,
                isArabic: s.ar,
                icon: Icons.download_outlined,
                title: s.downloadAndDecrypt,
                tone: p.ink,
                onTap: () {
                  Navigator.pop(ctx);
                  widget.controller.downloadFile(file);
                },
              ),
              const SizedBox(height: 8),
              _MenuGlassTile(
                palette: p,
                isArabic: s.ar,
                icon: Icons.drive_file_rename_outline,
                title: s.renameFile,
                tone: p.ink,
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(
                    title: s.renameFile,
                    initial: file.name,
                    onSave: (val) =>
                        widget.controller.renameFile(file.id, val),
                  );
                },
              ),
              const SizedBox(height: 8),
              _MenuGlassTile(
                palette: p,
                isArabic: s.ar,
                icon: Icons.drive_file_move_outlined,
                title: s.moveFile,
                tone: p.ink,
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveFolderPickerSheet(
                    onPickTarget: (targetId) =>
                        widget.controller.moveFile(file.id, targetId),
                  );
                },
              ),
              const SizedBox(height: 8),
              _MenuGlassTile(
                palette: p,
                isArabic: s.ar,
                icon: Icons.delete_outline_rounded,
                title: s.deleteFile,
                tone: p.coral,
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(
                    count: 1,
                    onConfirm: () => widget.controller.deleteFile(file.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortAndFilterSheet() {
    VaultHaptics.selection();
    final p = widget.palette;
    final s = widget.controller.strings;
    final options = <(_SortBy, String, IconData)>[
      (_SortBy.date, s.sortDate, Icons.schedule_rounded),
      (_SortBy.name, s.sortName, Icons.sort_by_alpha_rounded),
      (_SortBy.size, s.sortSize, Icons.data_usage_rounded),
    ];

    showVaultBottomSheet<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultSheetShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.sortByTitle,
                      style: VaultText.heading(p, s.ar, size: 18)),
                  VaultMonoChip(
                    palette: p,
                    label: s.filterTitle,
                    dotColor: _showFilters ? p.champagne : null,
                    onTap: () {
                      setState(() => _showFilters = !_showFilters);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final opt in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MenuGlassTile(
                    palette: p,
                    isArabic: s.ar,
                    icon: opt.$3,
                    title: opt.$2,
                    trailingText: _sortBy == opt.$1
                        ? (_sortAsc ? '↑' : '↓')
                        : null,
                    tone: _sortBy == opt.$1 ? p.champagne : p.ink,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (_sortBy == opt.$1) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sortBy = opt.$1;
                          _sortAsc = opt.$1 == _SortBy.name;
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(FileRecord file) {
    return switch (_filter) {
      _FileFilter.all => true,
      _FileFilter.folders => false,
      _FileFilter.images => isImageFile(file.mimeType, file.name),
      _FileFilter.pdf => isPdfFile(file.mimeType, file.name),
      _FileFilter.video => isVideoFile(file.mimeType, file.name),
      _FileFilter.other => !isImageFile(file.mimeType, file.name) &&
          !isPdfFile(file.mimeType, file.name) &&
          !isVideoFile(file.mimeType, file.name),
    };
  }

  int _compareFolders(Folder a, Folder b) {
    final cmp = switch (_sortBy) {
      _SortBy.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _SortBy.date => a.createdAt.compareTo(b.createdAt),
      _SortBy.size => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    return _sortAsc ? cmp : -cmp;
  }

  int _compareFiles(FileRecord a, FileRecord b) {
    final cmp = switch (_sortBy) {
      _SortBy.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _SortBy.date => a.createdAt.compareTo(b.createdAt),
      _SortBy.size => a.size.compareTo(b.size),
    };
    return _sortAsc ? cmp : -cmp;
  }

  Map<int, String> _buildFolderPaths(List<Folder> allFolders) {
    final byId = <int, Folder>{for (final f in allFolders) f.id: f};
    final paths = <int, String>{};
    for (final folder in allFolders) {
      final segments = <String>[];
      var cursor = folder as Folder?;
      var guard = 0;
      while (cursor != null && guard < 16) {
        segments.insert(0, cursor.name);
        final pid = cursor.parentId;
        cursor = pid == null ? null : byId[pid];
        guard++;
      }
      paths[folder.id] = segments.join(' / ');
    }
    return paths;
  }

  Color _statusDotColorForFile(AppPalette p, FileRecord file) {
    final task = widget.controller.latestTaskFor(file.id);
    if (task == null) return p.signalGreen;
    return switch (task.state) {
      TaskState.running => p.champagne,
      TaskState.paused || TaskState.queued => p.secondary,
      TaskState.failed => p.coral,
      TaskState.completed => p.signalGreen,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final snap = ctrl.snapshot;
    final query = _searchCtrl.text.trim().toLowerCase();
    final isGlobalSearch = query.isNotEmpty;
    final allVaultFiles = snap.allFiles.isNotEmpty ? snap.allFiles : snap.files;
    final folderPaths = _buildFolderPaths(snap.allFolders);

    final showFolders = !widget.isRecent &&
        (_filter == _FileFilter.all || _filter == _FileFilter.folders);
    final folderSource = isGlobalSearch ? snap.allFolders : snap.folders;
    final folders = showFolders
        ? (query.isEmpty
            ? List<Folder>.from(folderSource)
            : folderSource
                .where((f) => f.name.toLowerCase().contains(query))
                .toList())
        : <Folder>[];
    folders.sort(_compareFolders);

    final fileSource =
        (isGlobalSearch || widget.isRecent) ? allVaultFiles : snap.files;
    final files = fileSource.where((f) {
      if (!_matchesFilter(f)) return false;
      if (query.isNotEmpty && !f.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    if (widget.isRecent && _sortBy == _SortBy.date) {
      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      files.sort(_compareFiles);
    }

    final filterEntries = <(_FileFilter, String)>[
      (_FileFilter.all, s.filterAll),
      if (!widget.isRecent) (_FileFilter.folders, s.filterFolders),
      (_FileFilter.images, s.filterImages),
      (_FileFilter.pdf, s.filterPdf),
      (_FileFilter.video, s.filterVideo),
      (_FileFilter.other, s.filterOther),
    ];

    final childCounts = <int, int>{};
    for (final f in snap.allFolders) {
      final pid = f.parentId;
      if (pid != null) {
        childCounts[pid] = (childCounts[pid] ?? 0) + 1;
      }
    }
    for (final f in allVaultFiles) {
      final fid = f.folderId;
      if (fid != null) {
        childCounts[fid] = (childCounts[fid] ?? 0) + 1;
      }
    }

    final headerTitle = _selectionMode
        ? s.selectedCount(_totalSelected)
        : (widget.isRecent
            ? s.recentTitle
            : (snap.currentFolder?.name ?? s.filesTitle));

    final destTitle = ctrl.activeDestinationTitle(s);
    final destOwned = ctrl.activeDestinationOwnedByMe;

    // Scroll collapse progress (0.0 -> 1.0 over first 56px of scroll)
    final collapseT = (_scrollOffset / 56.0).clamp(0.0, 1.0);
    final fastDur = vaultMotion.duration(context, vaultMotion.fast);
    final baseDur = vaultMotion.duration(context, vaultMotion.base);
    final slowDur = vaultMotion.duration(context, vaultMotion.slow);
    final reduced = vaultMotion.isReduced(context);
    final isSearchingActive = _searchFocused || query.isNotEmpty;

    return VaultScrollParallax(
      notifier: _parallaxShift,
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              if (ctrl.navHiddenByScroll &&
                  (n.metrics.pixels <= 8.0 ||
                      n.metrics.maxScrollExtent <= 8.0)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) ctrl.setNavHiddenByScroll(false);
                });
              }
              return false;
            },
            child: RefreshIndicator(
              color: p.champagne,
            backgroundColor: p.cardSolid,
            strokeWidth: 1.8,
            onRefresh: () async {
              VaultHaptics.light();
              ctrl.openFolder(snap.currentFolder?.id);
              ctrl.showToast(s.loadedGroupsToast);
            },
            child: ListView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                VaultSpacing.screenHorizontal,
                16,
                VaultSpacing.screenHorizontal,
                _selectionMode
                    ? widget.bottomPadding + 92
                    : widget.bottomPadding + 52,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // 1. Title row (rises 8px on enter, collapses smoothly)
                VaultStaggeredSlideFade(
                  index: 0,
                  dy: vaultMotion.shiftSmall,
                  parentAnimation: _enterCtrl,
                  child: AnimatedOpacity(
                    duration: fastDur,
                    opacity: (1.0 - collapseT * 0.9).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: reduced ? 1.0 : (1.0 - collapseT * 0.28),
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: [
                          Expanded(
                            child: _selectionMode
                                ? VaultRollingText(
                                    headerTitle,
                                    style: VaultText.display(p, s.ar, size: 34),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      headerTitle,
                                      maxLines: 1,
                                      softWrap: false,
                                      style:
                                          VaultText.display(p, s.ar, size: 34),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          _HeaderGlassIcon(
                            palette: p,
                            active: _selectionMode,
                            tooltip:
                                _selectionMode ? s.clearSelection : s.selectAll,
                            onTap: () {
                              VaultHaptics.selection();
                              if (_selectionMode) {
                                _exitSelectionMode();
                              } else {
                                setState(() => _selectionMode = true);
                                ctrl.setSelecting(true);
                              }
                            },
                            icon: _selectionMode
                                ? Icons.close_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                          const SizedBox(width: 8),
                          _HeaderGlassIcon(
                            palette: p,
                            active: _gridMode,
                            tooltip: _gridMode ? 'List view' : 'Grid view',
                            onTap: () {
                              VaultHaptics.selection();
                              setState(() => _gridMode = !_gridMode);
                            },
                            icon: _gridMode
                                ? Icons.view_list_rounded
                                : Icons.grid_view_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Destination chip fades out cleanly (180ms) while searching
                if (!widget.isRecent)
                  AnimatedSize(
                    duration: fastDur,
                    curve: vaultMotion.standard,
                    child: AnimatedOpacity(
                      duration: fastDur,
                      opacity: isSearchingActive ? 0.0 : 1.0,
                      child: isSearchingActive
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: VaultTap(
                                      onTap: () => showStorageDestinationSheet(
                                        context,
                                        palette: p,
                                        controller: ctrl,
                                      ),
                                      child: VaultSurface(
                                        palette: p,
                                        borderRadius: VaultRadii.pill,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            VaultStatusDotAnimated(
                                              color: ctrl.authStatus
                                                          .isAuthorized ||
                                                      ctrl.demoMode
                                                  ? p.signalGreen
                                                  : p.champagne,
                                              isSynced: ctrl.authStatus
                                                      .isAuthorized ||
                                                  ctrl.demoMode,
                                              isBreathing: !ctrl.authStatus
                                                      .isAuthorized &&
                                                  !ctrl.demoMode,
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                destTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: VaultText.monoText(
                                                  p,
                                                  destTitle,
                                                  size: 11.5,
                                                  weight: FontWeight.w500,
                                                  color: p.ink,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: p.glassElevatedFill,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        VaultRadii.pill),
                                                border: Border.all(
                                                    color: p.glassBorder),
                                              ),
                                              child: Text(
                                                destOwned
                                                    ? s.ownedByMeChip
                                                    : s.adminChip,
                                                style: VaultText.monoText(
                                                  p,
                                                  destOwned
                                                      ? s.ownedByMeChip
                                                      : s.adminChip,
                                                  size: 10,
                                                  color: p.secondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 14),

                // 2. Search Bar (+60ms stagger) with filter button fade-out on focus
                VaultStaggeredSlideFade(
                  index: 2,
                  dy: vaultMotion.shiftSmall,
                  parentAnimation: _enterCtrl,
                  child: VaultGlassSearchField(
                    palette: p,
                    isArabic: s.ar,
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    hintText: s.searchHint,
                    onChanged: (_) => setState(() {}),
                    trailingAction: AnimatedOpacity(
                      duration: fastDur,
                      opacity: isSearchingActive ? 0.0 : 1.0,
                      child: IgnorePointer(
                        ignoring: isSearchingActive,
                        child: IconButton(
                          onPressed: () {
                            VaultHaptics.selection();
                            setState(() => _showFilters = !_showFilters);
                          },
                          onLongPress: _showSortAndFilterSheet,
                          tooltip: s.filterTitle,
                          icon: Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: (_showFilters || _filter != _FileFilter.all)
                                ? p.champagne
                                : p.secondary,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                ),

                if (_showFilters || _filter != _FileFilter.all) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in filterEntries)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: VaultMonoChip(
                              palette: p,
                              label: entry.$2,
                              dotColor:
                                  _filter == entry.$1 ? p.champagne : null,
                              textColor:
                                  _filter == entry.$1 ? p.ink : p.secondary,
                              backgroundColor: _filter == entry.$1
                                  ? p.champagneSoft
                                  : p.glassFill,
                              borderColor: _filter == entry.$1
                                  ? p.champagne
                                  : p.glassBorder,
                              onTap: () {
                                VaultHaptics.selection();
                                setState(() => _filter = entry.$1);
                              },
                            ),
                          ),
                        VaultMonoChip(
                          palette: p,
                          label: s.sortByTitle,
                          icon: _sortAsc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          onTap: _showSortAndFilterSheet,
                        ),
                      ],
                    ),
                  ),
                ],

                // 3. Breadcrumbs (+120ms stagger, new pill scales 0.9 -> 1.0)
                if (!widget.isRecent && snap.breadcrumbs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  VaultStaggeredSlideFade(
                    index: 4,
                    dy: vaultMotion.shiftSmall,
                    parentAnimation: _enterCtrl,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          VaultMonoChip(
                            palette: p,
                            label: s.myFiles,
                            icon: Icons.home_outlined,
                            onTap: () => _navigateToFolder(null, isBack: true),
                          ),
                          for (var i = 0; i < snap.breadcrumbs.length; i++) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                s.ar
                                    ? Icons.chevron_left_rounded
                                    : Icons.chevron_right_rounded,
                                size: 16,
                                color: p.muted,
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              key: ValueKey('bc_${snap.breadcrumbs[i].id}'),
                              tween: Tween<double>(
                                begin: vaultMotion.scale(context, 0.9),
                                end: 1.0,
                              ),
                              duration: fastDur,
                              curve: vaultMotion.standard,
                              builder: (context, sc, child) =>
                                  Transform.scale(scale: sc, child: child),
                              child: VaultMonoChip(
                                palette: p,
                                label: snap.breadcrumbs[i].name,
                                textColor: i == snap.breadcrumbs.length - 1
                                    ? p.champagne
                                    : p.secondary,
                                backgroundColor:
                                    i == snap.breadcrumbs.length - 1
                                        ? p.champagneSoft
                                        : p.glassFill,
                                borderColor: i == snap.breadcrumbs.length - 1
                                    ? p.champagne
                                    : p.glassBorder,
                                onTap: () => _navigateToFolder(
                                  snap.breadcrumbs[i].id,
                                  isBack: i < snap.breadcrumbs.length - 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Content (Folder navigation cross-slide 24px directional + List/Grid 250ms cross-fade)
                AnimatedSwitcher(
                  duration: baseDur,
                  switchInCurve: vaultMotion.standard,
                  switchOutCurve: vaultMotion.exit,
                  transitionBuilder: (child, animation) {
                    if (reduced) {
                      return FadeTransition(opacity: animation, child: child);
                    }
                    final rtl =
                        Directionality.of(context) == TextDirection.rtl;
                    final dirFactor = (rtl ? -1.0 : 1.0) * _navDirection;
                    final slide = Tween<Offset>(
                      begin: Offset(0.06 * dirFactor, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                        'view_${snap.currentFolder?.id ?? "root"}_${_gridMode}_${isGlobalSearch}_${ctrl.isLoadingVault}'),
                    child: ctrl.isLoadingVault
                        ? _GlassSkeletonList(palette: p)
                        : (folders.isEmpty && files.isEmpty)
                            ? VaultSurface(
                                palette: p,
                                borderRadius: VaultRadii.card,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 36),
                                child: Column(
                                  children: [
                                    VaultEmptyDoorIllustration(
                                      strokeColor: p.champagne,
                                      mutedColor: p.glassBorder,
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      query.isNotEmpty
                                          ? s.noMatching
                                          : s.folderEmpty,
                                      textAlign: TextAlign.center,
                                      style: VaultText.heading(p, s.ar,
                                          size: 19),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      query.isNotEmpty
                                          ? s.nothingMatched(_searchCtrl.text)
                                          : s.emptyDesc,
                                      textAlign: TextAlign.center,
                                      style: VaultText.body(p, s.ar,
                                          size: 13.5, color: p.secondary),
                                    ),
                                    if (query.isEmpty) ...[
                                      const SizedBox(height: 20),
                                      VaultPillButton(
                                        palette: p,
                                        isArabic: s.ar,
                                        expand: false,
                                        height: 46,
                                        icon: Icons.add_rounded,
                                        label: s.uploadFileAction,
                                        onPressed: _showUploadBottomSheet,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : _gridMode
                                ? GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: folders.length + files.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.92,
                                    ),
                                    itemBuilder: (ctx, index) {
                                      if (index < folders.length) {
                                        final folder = folders[index];
                                        final selected = _selectedFolderIds
                                            .contains(folder.id);
                                        final itemCount =
                                            childCounts[folder.id] ?? 0;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 5),
                                          child: VaultTap(
                                            onTap: () => _selectionMode
                                                ? _toggleFolderSelection(
                                                    folder.id)
                                                : _navigateToFolder(folder.id),
                                            onLongPress: () =>
                                                _toggleFolderSelection(
                                                    folder.id,
                                                    viaLongPress: true),
                                            child: VaultStackedGlassCard(
                                              palette: p,
                                              borderRadius: VaultRadii.md,
                                              child: VaultSurface(
                                                palette: p,
                                                borderRadius: VaultRadii.md,
                                                backgroundColor: selected
                                                    ? p.champagneSoft
                                                    : p.glassFill,
                                                borderColor: selected
                                                    ? p.champagne
                                                    : p.glassBorder,
                                                padding:
                                                    const EdgeInsets.all(14),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                p.champagneSoft,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        VaultRadii
                                                                            .tile),
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: Icon(
                                                              Icons
                                                                  .folder_outlined,
                                                              size: 20,
                                                              color:
                                                                  p.champagne),
                                                        ),
                                                        AnimatedOpacity(
                                                          duration: fastDur,
                                                          opacity:
                                                              _selectionMode
                                                                  ? 1.0
                                                                  : 0.0,
                                                          child: _selectionMode
                                                              ? _CircularCheck(
                                                                  palette: p,
                                                                  selected:
                                                                      selected,
                                                                )
                                                              : const SizedBox
                                                                  .shrink(),
                                                        ),
                                                      ],
                                                    ),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        _HighlightedNameText(
                                                          text: folder.name,
                                                          query: query,
                                                          style: VaultText.body(
                                                            p,
                                                            s.ar,
                                                            size: 15,
                                                            weight:
                                                                FontWeight.w600,
                                                            applyArabicScale:
                                                                false,
                                                          ),
                                                          highlightColor:
                                                              p.champagne,
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          s.itemsCountLabel(
                                                              itemCount),
                                                          style: VaultText
                                                              .monoText(
                                                            p,
                                                            s.itemsCountLabel(
                                                                itemCount),
                                                            size: 11,
                                                            color: p.secondary,
                                                          ),
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
                                      final file =
                                          files[index - folders.length];
                                      final previewable = isPreviewableFile(
                                          file.mimeType, file.name);
                                      final selected =
                                          _selectedFileIds.contains(file.id);
                                      final locationLabel = (isGlobalSearch ||
                                              widget.isRecent)
                                          ? (file.folderId == null
                                              ? s.myFiles
                                              : (folderPaths[file.folderId] ??
                                                  s.folderWord))
                                          : null;
                                      return _GridFileCard(
                                        palette: p,
                                        controller: ctrl,
                                        isArabic: s.ar,
                                        file: file,
                                        query: query,
                                        selected: selected,
                                        selectionMode: _selectionMode,
                                        locationLabel: locationLabel,
                                        statusDotColor:
                                            _statusDotColorForFile(p, file),
                                        taskState: ctrl.latestTaskFor(file.id)?.state,
                                        onTap: () => _selectionMode
                                            ? _toggleFileSelection(file.id)
                                            : (previewable
                                                ? _openPreview(file)
                                                : _showFileInspector(file)),
                                        onLongPress: () => _toggleFileSelection(
                                            file.id,
                                            viaLongPress: true),
                                      );
                                    },
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (isGlobalSearch && !widget.isRecent)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: VaultSectionHeader(
                                            palette: p,
                                            isArabic: s.ar,
                                            title: s.searchResultsLabel(
                                                folders.length + files.length),
                                          ),
                                        ),
                                      for (var i = 0;
                                          i < folders.length;
                                          i++)
                                        VaultStaggeredSlideFade(
                                          index: i + 3,
                                          dy: 12,
                                          parentAnimation: _enterCtrl,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                top: 5, bottom: 10),
                                            child: _FolderGlassRow(
                                              palette: p,
                                              isArabic: s.ar,
                                              itemsLabel: s.itemsCountLabel(
                                                  childCounts[folders[i].id] ??
                                                      0),
                                              folder: folders[i],
                                              query: query,
                                              selectionMode: _selectionMode,
                                              selected: _selectedFolderIds
                                                  .contains(folders[i].id),
                                              onTap: () => _selectionMode
                                                  ? _toggleFolderSelection(
                                                      folders[i].id)
                                                  : _navigateToFolder(
                                                      folders[i].id),
                                              onLongPress: () =>
                                                  _toggleFolderSelection(
                                                      folders[i].id,
                                                      viaLongPress: true),
                                            ),
                                          ),
                                        ),
                                      for (var i = 0; i < files.length; i++)
                                        VaultStaggeredSlideFade(
                                          index: folders.length + i + 3,
                                          dy: 12,
                                          parentAnimation: _enterCtrl,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _FileGlassRow(
                                              palette: p,
                                              isArabic: s.ar,
                                              file: files[i],
                                              query: query,
                                              folderPathLabel: (isGlobalSearch ||
                                                      widget.isRecent)
                                                  ? (files[i].folderId == null
                                                      ? s.myFiles
                                                      : folderPaths[
                                                          files[i].folderId])
                                                  : null,
                                              statusDotColor:
                                                  _statusDotColorForFile(
                                                      p, files[i]),
                                              taskState: ctrl
                                                  .latestTaskFor(files[i].id)
                                                  ?.state,
                                              selectionMode: _selectionMode,
                                              selected: _selectedFileIds
                                                  .contains(files[i].id),
                                              onTap: () => _selectionMode
                                                  ? _toggleFileSelection(
                                                      files[i].id)
                                                  : (isPreviewableFile(
                                                          files[i].mimeType,
                                                          files[i].name)
                                                      ? _openPreview(files[i])
                                                      : _showFileInspector(
                                                          files[i])),
                                              onLongPress: () =>
                                                  _toggleFileSelection(
                                                      files[i].id,
                                                      viaLongPress: true),
                                              onInspect: () =>
                                                  _showFileInspector(files[i]),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                  ),
                ),
              ],
            ),
            ),
          ),

          // Collapsing Frosted Top Glass Bar (appears smoothly as title scrolls out)
          if (collapseT > 0.05)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: collapseT < 0.35,
                child: Opacity(
                  opacity: collapseT,
                  child: VaultSurface(
                    palette: p,
                    borderRadius: 0,
                    blurSigma: reduced ? 0 : (collapseT * 24.0),
                    borderColor: p.glassBorder.withValues(alpha: collapseT),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VaultText.heading(p, s.ar, size: 17),
                          ),
                        ),
                        VaultMonoChip(
                          palette: p,
                          label: s.itemsCountLabel(folders.length + files.length),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Soft 40% black scrim when floating "+" menu is fanned open
          if (_plusMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePlusMenu,
                child: AnimatedBuilder(
                  animation: _plusMenuCtrl,
                  builder: (context, _) => Container(
                    color: Colors.black.withValues(
                        alpha: 0.40 * _plusMenuCtrl.value),
                  ),
                ),
              ),
            ),

          // Fanned-upward speed-dial glass pills (40ms stagger, 12px rise + fade) + 45° rotating "+" FAB
          if (!_selectionMode)
            PositionedDirectional(
              end: 20,
              bottom: widget.bottomPadding - 4,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_plusMenuOpen) ...[
                      if (!widget.isRecent)
                        _FannedActionPill(
                          palette: p,
                          isArabic: s.ar,
                          animation: _plusMenuCtrl,
                          delayFraction: 0.25,
                          icon: Icons.create_new_folder_outlined,
                          label: s.newFolder,
                          onTap: () {
                            _closePlusMenu();
                            _showNewFolderDialog();
                          },
                        ),
                      const SizedBox(height: 10),
                      _FannedActionPill(
                        palette: p,
                        isArabic: s.ar,
                        animation: _plusMenuCtrl,
                        delayFraction: 0.0,
                        icon: Icons.cloud_upload_outlined,
                        label: s.uploadFileAction,
                        onTap: () {
                          _closePlusMenu();
                          _showUploadBottomSheet();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    VaultTap(
                      onTap: _togglePlusMenu,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: p.primaryBtnFill,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.shadowColor,
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: AnimatedRotation(
                          turns: _plusMenuOpen ? 0.125 : 0.0, // 45° to "×"
                          duration: baseDur,
                          curve: vaultMotion.standard,
                          child: Icon(Icons.add_rounded,
                              size: 26, color: p.primaryBtnInk),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Multi-Select Floating Bar rising smoothly above the visible dimmed FloatingTabBar
          Positioned(
            left: 20,
            right: 20,
            bottom: 84,
            child: IgnorePointer(
              ignoring: !_selectionMode,
              child: AnimatedSlide(
                duration: slowDur,
                curve: vaultMotion.emphasized,
                offset: (_selectionMode || reduced)
                    ? Offset.zero
                    : const Offset(0, 0.55),
                child: AnimatedOpacity(
                  duration: baseDur,
                  opacity: _selectionMode ? 1.0 : 0.0,
                  child: SafeArea(
                    top: false,
                    child: VaultSurface(
                      palette: p,
                      borderRadius: VaultRadii.pill,
                      elevated: true,
                      borderColor: p.glassTopLeftBorder,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _BulkActionBtn(
                            palette: p,
                            isArabic: s.ar,
                            icon: Icons.select_all_rounded,
                            label: s.selectAll,
                            onTap: () {
                              setState(() {
                                for (final f in folders) {
                                  _selectedFolderIds.add(f.id);
                                }
                                for (final f in files) {
                                  _selectedFileIds.add(f.id);
                                }
                              });
                            },
                          ),
                          _BulkActionBtn(
                            palette: p,
                            isArabic: s.ar,
                            icon: Icons.drive_file_move_outlined,
                            label: s.moveAction,
                            enabled: _totalSelected > 0,
                            onTap: () {
                              final fIds = _selectedFolderIds.toList();
                              final fileIds = _selectedFileIds.toList();
                              _showMoveFolderPickerSheet(
                                excludedFolderIds: fIds,
                                onPickTarget: (targetId) {
                                  ctrl.moveMany(
                                    folderIds: fIds,
                                    fileIds: fileIds,
                                    targetFolderId: targetId,
                                  );
                                  _exitSelectionMode();
                                },
                              );
                            },
                          ),
                          _BulkActionBtn(
                            palette: p,
                            isArabic: s.ar,
                            icon: Icons.drive_file_rename_outline_rounded,
                            label: s.renameAction,
                            enabled: _totalSelected == 1,
                            onTap: () {
                              if (_selectedFolderIds.length == 1) {
                                final folderId = _selectedFolderIds.first;
                                final folder = folders
                                    .where((f) => f.id == folderId)
                                    .firstOrNull;
                                if (folder == null) return;
                                _showRenameDialog(
                                  title: s.renameFolder,
                                  initial: folder.name,
                                  onSave: (val) {
                                    ctrl.renameFolder(folder.id, val);
                                    _exitSelectionMode();
                                  },
                                );
                              } else if (_selectedFileIds.length == 1) {
                                final fileId = _selectedFileIds.first;
                                final file = files
                                    .where((f) => f.id == fileId)
                                    .firstOrNull;
                                if (file == null) return;
                                _showRenameDialog(
                                  title: s.renameFile,
                                  initial: file.name,
                                  onSave: (val) {
                                    ctrl.renameFile(file.id, val);
                                    _exitSelectionMode();
                                  },
                                );
                              }
                            },
                          ),
                          _BulkActionBtn(
                            palette: p,
                            isArabic: s.ar,
                            icon: Icons.download_outlined,
                            label: s.downloadAction,
                            enabled: _selectedFileIds.isNotEmpty,
                            onTap: () {
                              final selectedFiles = files
                                  .where((f) => _selectedFileIds.contains(f.id))
                                  .toList();
                              ctrl.downloadMany(selectedFiles);
                              _exitSelectionMode();
                            },
                          ),
                          _BulkActionBtn(
                            palette: p,
                            isArabic: s.ar,
                            icon: Icons.delete_outline_rounded,
                            label: s.deleteAction,
                            isDanger: true,
                            enabled: _totalSelected > 0,
                            onTap: () {
                              final fIds = _selectedFolderIds.toList();
                              final fileIds = _selectedFileIds.toList();
                              _showDeleteConfirmDialog(
                                count: fIds.length + fileIds.length,
                                onConfirm: () {
                                  ctrl.deleteMany(
                                    folderIds: fIds,
                                    fileIds: fileIds,
                                  );
                                  _exitSelectionMode();
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FannedActionPill extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final Animation<double> animation;
  final double delayFraction;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FannedActionPill({
    required this.palette,
    required this.isArabic,
    required this.animation,
    required this.delayFraction,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final reduced = vaultMotion.isReduced(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Interval(
          delayFraction,
          1.0,
          curve: vaultMotion.emphasized,
        ).transform(animation.value);
        final dy = reduced ? 0.0 : (1.0 - t) * 12.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: VaultTap(
        onTap: onTap,
        child: VaultSurface(
          palette: p,
          borderRadius: VaultRadii.pill,
          elevated: true,
          borderColor: p.glassTopLeftBorder,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: p.champagne),
              const SizedBox(width: 8),
              Text(
                label,
                style: VaultText.body(
                  p,
                  isArabic,
                  size: 13.5,
                  weight: FontWeight.w600,
                  applyArabicScale: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedNameText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  const _HighlightedNameText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: style.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HeaderGlassIcon extends StatelessWidget {
  final AppPalette palette;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;

  const _HeaderGlassIcon({
    required this.palette,
    required this.active,
    required this.tooltip,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Tooltip(
      message: tooltip,
      child: VaultTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: vaultMotion.duration(context, vaultMotion.fast),
          curve: vaultMotion.standard,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active ? p.champagneSoft : p.glassFill,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? p.champagne : p.glassBorder,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 19,
            color: active ? p.champagne : p.ink,
          ),
        ),
      ),
    );
  }
}

class _CircularCheck extends StatelessWidget {
  final AppPalette palette;
  final bool selected;

  const _CircularCheck({required this.palette, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: vaultMotion.duration(context, vaultMotion.fast),
      curve: vaultMotion.standard,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? palette.champagne : palette.glassFill,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.champagne : palette.secondary,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? VaultAnimatedDrawCheck(
              color: palette.isDark
                  ? const Color(0xFF050506)
                  : const Color(0xFFF7F6F3),
              size: 13,
              strokeWidth: 2,
            )
          : null,
    );
  }
}

class _FolderGlassRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String itemsLabel;
  final Folder folder;
  final String query;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderGlassRow({
    required this.palette,
    required this.isArabic,
    required this.itemsLabel,
    required this.folder,
    required this.query,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final reduced = vaultMotion.isReduced(context);
    return AnimatedScale(
      scale: (!reduced && selected) ? 1.02 : 1.0,
      duration: vaultMotion.duration(context, vaultMotion.instant),
      curve: vaultMotion.standard,
      child: VaultTap(
        onTap: onTap,
        onLongPress: onLongPress,
        child: VaultStackedGlassCard(
          palette: p,
          borderRadius: VaultRadii.md,
          child: VaultSurface(
            palette: p,
            borderRadius: VaultRadii.md,
            elevated: selected,
            backgroundColor: selected ? p.champagneSoft : p.glassFill,
            borderColor: selected ? p.champagne : p.glassBorder,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                AnimatedSize(
                  duration: vaultMotion.duration(context, vaultMotion.fast),
                  curve: vaultMotion.standard,
                  child: selectionMode
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: _CircularCheck(palette: p, selected: selected),
                        )
                      : const SizedBox.shrink(),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.champagneSoft,
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.folder_outlined,
                      size: 20, color: p.champagne),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedNameText(
                        text: folder.name,
                        query: query,
                        style: VaultText.body(
                          p,
                          isArabic,
                          size: 15,
                          weight: FontWeight.w600,
                          applyArabicScale: false,
                        ),
                        highlightColor: p.champagne,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        itemsLabel,
                        style: VaultText.monoText(
                          p,
                          itemsLabel,
                          size: 11,
                          color: p.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
        ),
      ),
    );
  }
}

class _FileGlassRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final FileRecord file;
  final String query;
  final String? folderPathLabel;
  final Color statusDotColor;
  final TaskState? taskState;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInspect;

  const _FileGlassRow({
    required this.palette,
    required this.isArabic,
    required this.file,
    required this.query,
    this.folderPathLabel,
    required this.statusDotColor,
    this.taskState,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final dateStr = formatTimestamp(file.createdAt);
    final sizeStr = formatBytes(file.size);
    final metaLine = dateStr.isNotEmpty ? '$sizeStr · $dateStr' : sizeStr;
    final reduced = vaultMotion.isReduced(context);

    return AnimatedScale(
      scale: (!reduced && selected) ? 1.02 : 1.0,
      duration: vaultMotion.duration(context, vaultMotion.instant),
      curve: vaultMotion.standard,
      child: VaultTap(
        onTap: onTap,
        onLongPress: onLongPress,
        child: VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          elevated: selected,
          backgroundColor: selected ? p.champagneSoft : p.glassFill,
          borderColor: selected ? p.champagne : p.glassBorder,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AnimatedSize(
                duration: vaultMotion.duration(context, vaultMotion.fast),
                curve: vaultMotion.standard,
                child: selectionMode
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: _CircularCheck(palette: p, selected: selected),
                      )
                    : const SizedBox.shrink(),
              ),
              Hero(
                tag: 'list_vault_item_${file.id}',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.glassElevatedFill,
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    border: Border.all(color: p.glassBorder),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    iconForMimeOrName(file.mimeType, file.name),
                    size: 19,
                    color: p.champagne,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedNameText(
                      text: file.name,
                      query: query,
                      style: VaultText.body(
                        p,
                        isArabic,
                        size: 14.5,
                        weight: FontWeight.w500,
                        applyArabicScale: false,
                      ),
                      highlightColor: p.champagne,
                    ),
                    const SizedBox(height: 3),
                    if (folderPathLabel != null && folderPathLabel!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.folder_outlined,
                                size: 12, color: p.champagne),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                folderPathLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VaultText.monoText(
                                  p,
                                  folderPathLabel!,
                                  size: 11,
                                  color: p.champagne,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.mono(p, size: 11, color: p.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (file.isEncrypted) ...[
                    Icon(Icons.lock_outline_rounded,
                        size: 13, color: p.secondary),
                    const SizedBox(width: 6),
                  ],
                  VaultStatusDotAnimated(
                    color: statusDotColor,
                    isBreathing: taskState == TaskState.running,
                    isSynced: taskState == null ||
                        taskState == TaskState.completed,
                  ),
                  if (!selectionMode) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onInspect,
                      icon: Icon(Icons.more_horiz_rounded,
                          size: 18, color: p.secondary),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridFileCard extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;
  final bool isArabic;
  final FileRecord file;
  final String query;
  final bool selected;
  final bool selectionMode;
  final String? locationLabel;
  final Color statusDotColor;
  final TaskState? taskState;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridFileCard({
    required this.palette,
    required this.controller,
    required this.isArabic,
    required this.file,
    required this.query,
    required this.selected,
    required this.selectionMode,
    this.locationLabel,
    required this.statusDotColor,
    this.taskState,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_GridFileCard> createState() => _GridFileCardState();
}

class _GridFileCardState extends State<_GridFileCard> {
  String? _thumbPath;

  @override
  void initState() {
    super.initState();
    _thumbPath = widget.controller.thumbnails.peek(widget.file.id);
    _loadThumb();
  }

  @override
  void didUpdateWidget(covariant _GridFileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id ||
        oldWidget.file.size != widget.file.size) {
      _thumbPath = widget.controller.thumbnails.peek(widget.file.id);
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    final file = widget.file;
    if (!isImageFile(file.mimeType, file.name) &&
        !isPdfFile(file.mimeType, file.name)) {
      return;
    }
    final resolved = await widget.controller.thumbnails.resolveThumbnailPath(
      file: file,
      resolveLocalFile: widget.controller.resolveLocalPath,
    );
    if (mounted && resolved != null && resolved != _thumbPath) {
      setState(() => _thumbPath = resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final file = widget.file;
    final hasThumb = _thumbPath != null && File(_thumbPath!).existsSync();
    final ext = _fileExtensionTag(file);
    final reduced = vaultMotion.isReduced(context);

    return AnimatedScale(
      scale: (!reduced && widget.selected) ? 1.02 : 1.0,
      duration: vaultMotion.duration(context, vaultMotion.instant),
      child: VaultTap(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          backgroundColor: widget.selected ? p.champagneSoft : p.glassFill,
          borderColor: widget.selected ? p.champagne : p.glassBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'grid_vault_item_${file.id}',
                child: AnimatedSwitcher(
                  duration: vaultMotion.duration(context, vaultMotion.base),
                  child: hasThumb
                      ? Image.file(
                          File(_thumbPath!),
                          key: ValueKey('thumb_${file.id}'),
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              iconForMimeOrName(file.mimeType, file.name),
                              size: 32,
                              color: p.champagne,
                            ),
                          ),
                        )
                      : Container(
                          key: ValueKey('ph_${file.id}'),
                          color: p.cardSolid
                              .withValues(alpha: p.isDark ? 0.65 : 0.45),
                          padding: const EdgeInsets.only(bottom: 44),
                          child: Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: p.glassFill,
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.tile),
                                border: Border.all(color: p.glassBorder),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                iconForMimeOrName(file.mimeType, file.name),
                                size: 24,
                                color: p.champagne,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.scrim,
                    borderRadius: BorderRadius.circular(VaultRadii.pill),
                    border: Border.all(color: p.glassBorder),
                  ),
                  child: Text(
                    ext,
                    style: VaultText.mono(p, size: 10, color: p.ink),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 10,
                end: 10,
                child: widget.selectionMode
                    ? _CircularCheck(palette: p, selected: widget.selected)
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.scrim,
                          borderRadius: BorderRadius.circular(VaultRadii.pill),
                          border: Border.all(color: p.glassBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (file.isEncrypted) ...[
                              Icon(Icons.lock_outline_rounded,
                                  size: 11, color: p.ink),
                              const SizedBox(width: 4),
                            ],
                            VaultStatusDotAnimated(
                              color: widget.statusDotColor,
                              isBreathing:
                                  widget.taskState == TaskState.running,
                              isSynced: widget.taskState == null ||
                                  widget.taskState == TaskState.completed,
                              size: 6,
                            ),
                          ],
                        ),
                      ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: p.scrim,
                    border: Border(
                        top: BorderSide(color: p.glassBorder, width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HighlightedNameText(
                        text: file.name,
                        query: widget.query,
                        style: VaultText.body(
                          p,
                          widget.isArabic,
                          size: 13,
                          weight: FontWeight.w600,
                          applyArabicScale: false,
                        ),
                        highlightColor: p.champagne,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatBytes(file.size),
                            style: VaultText.mono(p, size: 10.5),
                          ),
                          if (widget.locationLabel != null)
                            Expanded(
                              child: Text(
                                widget.locationLabel!,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VaultText.monoText(
                                  p,
                                  widget.locationLabel!,
                                  size: 10,
                                  color: p.champagne,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkActionBtn extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final IconData icon;
  final String label;
  final bool isDanger;
  final bool enabled;
  final VoidCallback onTap;

  const _BulkActionBtn({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.label,
    this.isDanger = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final color = !enabled
        ? p.muted.withValues(alpha: 0.45)
        : (isDanger ? p.coral : p.champagne);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: VaultText.body(
                p,
                isArabic,
                size: 11,
                weight: FontWeight.w600,
                color: color,
                applyArabicScale: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGlassTile extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color tone;
  final VoidCallback onTap;

  const _MenuGlassTile({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return VaultTap(
      onTap: onTap,
      child: VaultSurface(
        palette: p,
        borderRadius: VaultRadii.md,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(VaultRadii.tile),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: tone),
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
                      color: tone == p.coral ? p.coral : p.ink,
                      applyArabicScale: false,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.body(
                        p,
                        isArabic,
                        size: 12,
                        color: p.secondary,
                        applyArabicScale: false,
                      ),
                    ),
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: VaultText.mono(p, size: 14, color: p.champagne),
              ),
          ],
        ),
      ),
    );
  }
}

class _TreePickerRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final IconData icon;
  final String title;
  final int depth;
  final bool selected;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback onTap;

  const _TreePickerRow({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.title,
    required this.depth,
    required this.selected,
    required this.hasChildren,
    required this.expanded,
    this.onToggleExpand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final chevronTurns = expanded ? (isArabic ? -0.25 : 0.25) : 0.0;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: (depth * 14.0).clamp(0.0, 56.0),
        bottom: 6,
      ),
      child: VaultTap(
        onTap: onTap,
        child: VaultSurface(
          palette: p,
          borderRadius: VaultRadii.tile,
          backgroundColor: selected ? p.champagneSoft : p.glassFill,
          borderColor: selected ? p.champagne : p.glassBorder,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              if (hasChildren && onToggleExpand != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleExpand,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: AnimatedRotation(
                      turns: chevronTurns,
                      duration: vaultMotion.duration(context, vaultMotion.base),
                      curve: vaultMotion.standard,
                      child: Icon(
                        isArabic
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: p.secondary,
                      ),
                    ),
                  ),
                ),
              Icon(icon,
                  size: 18, color: selected ? p.champagne : p.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VaultText.body(
                    p,
                    isArabic,
                    size: 14,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                    applyArabicScale: false,
                  ),
                ),
              ),
              if (selected)
                VaultAnimatedDrawCheck(color: p.signalGreen, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptDialogForm extends StatefulWidget {
  final AppPalette palette;
  final bool isArabic;
  final String title;
  final String initialText;
  final String? hintText;
  final String cancelLabel;
  final String confirmLabel;
  final bool useSquareConfirm;
  final ValueChanged<String> onSubmit;

  const _PromptDialogForm({
    required this.palette,
    required this.isArabic,
    required this.title,
    this.initialText = '',
    this.hintText,
    required this.cancelLabel,
    required this.confirmLabel,
    this.useSquareConfirm = false,
    required this.onSubmit,
  });

  @override
  State<_PromptDialogForm> createState() => _PromptDialogFormState();
}

class _PromptDialogFormState extends State<_PromptDialogForm> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final value = _ctrl.text.trim();
    if (value.isNotEmpty) {
      widget.onSubmit(value);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isAr = widget.isArabic;
    return VaultDialogShell(
      palette: p,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: VaultText.heading(p, isAr, size: 19)),
          const SizedBox(height: 14),
          VaultGlassInputContainer(
            palette: p,
            borderRadius: VaultRadii.tile,
            builder: (context, focusNode) => TextField(
              focusNode: focusNode,
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
              style: VaultText.body(p, isAr,
                  size: 14.5, applyArabicScale: false),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: widget.hintText != null
                    ? VaultText.monoText(p, widget.hintText!,
                        size: 12, color: p.secondary)
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: VaultPillButton(
                  palette: p,
                  isArabic: isAr,
                  variant: VaultPillVariant.secondary,
                  height: 44,
                  label: widget.cancelLabel,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              if (widget.useSquareConfirm)
                VaultConfirmSquareButton(
                  palette: p,
                  tooltip: widget.confirmLabel,
                  size: 44,
                  onTap: _handleSubmit,
                )
              else
                Expanded(
                  child: VaultPillButton(
                    palette: p,
                    isArabic: isAr,
                    height: 44,
                    label: widget.confirmLabel,
                    onPressed: _handleSubmit,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Linear 1.4s RTL/LTR directional shimmer skeleton cards.
class _GlassSkeletonList extends StatefulWidget {
  final AppPalette palette;
  const _GlassSkeletonList({required this.palette});

  @override
  State<_GlassSkeletonList> createState() => _GlassSkeletonListState();
}

class _GlassSkeletonListState extends State<_GlassSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allow = vaultMotion.allowLoops(context);
    if (allow && !_running) {
      _running = true;
      _shimmerCtrl.repeat();
    } else if (!allow && _running) {
      _running = false;
      _shimmerCtrl.stop();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final sweepPos = rtl
            ? (1.0 - _shimmerCtrl.value) * 2.4 - 1.2
            : _shimmerCtrl.value * 2.4 - 1.2;
        final shimmerShader = LinearGradient(
          begin: Alignment(sweepPos - 0.5, 0),
          end: Alignment(sweepPos + 0.5, 0),
          colors: [
            p.secondary.withValues(alpha: 0.14),
            p.secondary.withValues(alpha: _running ? 0.34 : 0.18),
            p.secondary.withValues(alpha: 0.14),
          ],
        );

        return Column(
          children: List.generate(4, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VaultSurface(
                palette: p,
                borderRadius: VaultRadii.md,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: shimmerShader,
                        borderRadius: BorderRadius.circular(VaultRadii.tile),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: i.isEven ? 0.68 : 0.52,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: shimmerShader,
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.pill),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.36,
                            child: Container(
                              height: 9,
                              decoration: BoxDecoration(
                                gradient: shimmerShader,
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.pill),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

String _fileExtensionTag(FileRecord file) {
  final dot = file.name.lastIndexOf('.');
  if (dot >= 0 && dot < file.name.length - 1) {
    final ext = file.name.substring(dot + 1).toUpperCase();
    if (ext.length <= 4) return ext;
  }
  if (isImageFile(file.mimeType, file.name)) return 'IMG';
  if (isPdfFile(file.mimeType, file.name)) return 'PDF';
  if (isVideoFile(file.mimeType, file.name)) return 'VID';
  if (isAudioFile(file.mimeType, file.name)) return 'AUD';
  return 'FILE';
}

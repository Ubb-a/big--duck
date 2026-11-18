import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/storage_destination_sheet.dart';
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

class _FilesScreenState extends State<FilesScreen> {
  final _searchCtrl = TextEditingController();
  bool _gridMode = false;
  bool _showFilters = false;
  _SortBy _sortBy = _SortBy.date;
  bool _sortAsc = false;
  _FileFilter _filter = _FileFilter.all;

  bool _selectionMode = false;
  final Set<int> _selectedFolderIds = {};
  final Set<int> _selectedFileIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  void _navigateToFolder(int? folderId) {
    if (_selectionMode ||
        _selectedFolderIds.isNotEmpty ||
        _selectedFileIds.isNotEmpty) {
      _exitSelectionMode();
    }
    widget.controller.openFolder(folderId);
  }

  void _toggleFolderSelection(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = true;
      if (!_selectedFolderIds.add(id)) {
        _selectedFolderIds.remove(id);
      }
      if (_totalSelected == 0) _selectionMode = false;
    });
    widget.controller.setSelecting(_selectionMode);
  }

  void _toggleFileSelection(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = true;
      if (!_selectedFileIds.add(id)) {
        _selectedFileIds.remove(id);
      }
      if (_totalSelected == 0) _selectionMode = false;
    });
    widget.controller.setSelecting(_selectionMode);
  }

  Future<List<String>> _pickDocuments() async {
    final files = await FilePicker.pickFiles();
    return files.map((f) => f.path).whereType<String>().toList();
  }

  Future<List<String>> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia();
    return files.map((x) => x.path).toList();
  }

  void _showPlusActionMenu() {
    final p = widget.palette;
    final s = widget.controller.strings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultSheetShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuGlassTile(
                palette: p,
                isArabic: s.ar,
                icon: Icons.cloud_upload_outlined,
                title: s.uploadFileAction,
                subtitle: s.uploadDesc,
                tone: p.champagne,
                onTap: () {
                  Navigator.pop(ctx);
                  _showUploadBottomSheet();
                },
              ),
              if (!widget.isRecent) ...[
                const SizedBox(height: 10),
                _MenuGlassTile(
                  palette: p,
                  isArabic: s.ar,
                  icon: Icons.create_new_folder_outlined,
                  title: s.newFolder,
                  subtitle: s.folderNameHint,
                  tone: p.secondary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showNewFolderDialog();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadBottomSheet() {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    int? chosenFolderId = ctrl.snapshot.currentFolder?.id;
    var encryptUpload = ctrl.encryptBeforeUpload;
    var chosenPaths = <String>[];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                          Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: p.signalGreen),
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
    showDialog<void>(
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
    showDialog<void>(
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

    final depthMap = _computeFolderDepths(validFolders);
    int? selectedTarget = initialSelectedId ?? ctrl.snapshot.currentFolder?.id;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
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
                            onTap: () =>
                                setSheetState(() => selectedTarget = null),
                          ),
                          for (final folder in validFolders)
                            _TreePickerRow(
                              palette: p,
                              isArabic: s.ar,
                              icon: Icons.folder_outlined,
                              title: folder.name,
                              depth: depthMap[folder.id] ?? 1,
                              selected: selectedTarget == folder.id,
                              onTap: () =>
                                  setSheetState(() => selectedTarget = folder.id),
                            ),
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
        ),
      ),
    );
  }

  Map<int, int> _computeFolderDepths(List<Folder> folders) {
    final byId = <int, Folder>{for (final f in folders) f.id: f};
    final depths = <int, int>{};
    for (final folder in folders) {
      var d = 1;
      var cursor = folder.parentId;
      var guard = 0;
      while (cursor != null && guard < 8) {
        d++;
        cursor = byId[cursor]?.parentId;
        guard++;
      }
      depths[folder.id] = d;
    }
    return depths;
  }

  void _openPreview(FileRecord file) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(
          palette: widget.palette,
          controller: widget.controller,
          file: file,
        ),
      ),
    );
  }

  void _showFileInspector(FileRecord file) {
    HapticFeedback.lightImpact();
    final p = widget.palette;
    final s = widget.controller.strings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
    HapticFeedback.selectionClick();
    final p = widget.palette;
    final s = widget.controller.strings;
    final options = <(_SortBy, String, IconData)>[
      (_SortBy.date, s.sortDate, Icons.schedule_rounded),
      (_SortBy.name, s.sortName, Icons.sort_by_alpha_rounded),
      (_SortBy.size, s.sortSize, Icons.data_usage_rounded),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
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

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            VaultSpacing.screenHorizontal,
            16,
            VaultSpacing.screenHorizontal,
            _selectionMode ? widget.bottomPadding + 36 : widget.bottomPadding + 52,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // Header: large title "Vault" / "الخزنة" + List/Grid & Select controls
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      headerTitle,
                      maxLines: 1,
                      softWrap: false,
                      style: VaultText.display(p, s.ar, size: 34),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HeaderGlassIcon(
                  palette: p,
                  active: _selectionMode,
                  tooltip: _selectionMode ? s.clearSelection : s.selectAll,
                  onTap: () {
                    HapticFeedback.selectionClick();
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
                    HapticFeedback.selectionClick();
                    setState(() => _gridMode = !_gridMode);
                  },
                  icon: _gridMode
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Storage destination chip + "Owned by me" green dot badge + item count
            if (!widget.isRecent)
              Row(
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
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: ctrl.authStatus.isAuthorized || ctrl.demoMode
                                    ? p.signalGreen
                                    : p.champagne,
                                shape: BoxShape.circle,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.glassElevatedFill,
                                borderRadius:
                                    BorderRadius.circular(VaultRadii.pill),
                                border: Border.all(color: p.glassBorder),
                              ),
                              child: Text(
                                destOwned ? s.ownedByMeChip : s.adminChip,
                                style: VaultText.monoText(
                                  p,
                                  destOwned ? s.ownedByMeChip : s.adminChip,
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
            const SizedBox(height: 14),

            // Glass Search Bar + Filter Button
            VaultGlassSearchField(
              palette: p,
              isArabic: s.ar,
              controller: _searchCtrl,
              hintText: s.searchHint,
              onChanged: (_) => setState(() {}),
              trailingAction: IconButton(
                onPressed: () {
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
                          dotColor: _filter == entry.$1 ? p.champagne : null,
                          textColor:
                              _filter == entry.$1 ? p.ink : p.secondary,
                          backgroundColor: _filter == entry.$1
                              ? p.champagneSoft
                              : p.glassFill,
                          borderColor: _filter == entry.$1
                              ? p.champagne
                              : p.glassBorder,
                          onTap: () {
                            HapticFeedback.selectionClick();
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

            // Horizontal Glass Pill Breadcrumbs (RTL-aware)
            if (!widget.isRecent && snap.breadcrumbs.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    VaultMonoChip(
                      palette: p,
                      label: s.myFiles,
                      icon: Icons.home_outlined,
                      onTap: () => _navigateToFolder(null),
                    ),
                    for (var i = 0; i < snap.breadcrumbs.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          s.ar
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          size: 16,
                          color: p.muted,
                        ),
                      ),
                      VaultMonoChip(
                        palette: p,
                        label: snap.breadcrumbs[i].name,
                        textColor: i == snap.breadcrumbs.length - 1
                            ? p.champagne
                            : p.secondary,
                        backgroundColor: i == snap.breadcrumbs.length - 1
                            ? p.champagneSoft
                            : p.glassFill,
                        borderColor: i == snap.breadcrumbs.length - 1
                            ? p.champagne
                            : p.glassBorder,
                        onTap: () => _navigateToFolder(snap.breadcrumbs[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Loading Skeleton State
            if (ctrl.isLoadingVault)
              _GlassSkeletonList(palette: p)
            // Empty Vault / Empty Search State
            else if (folders.isEmpty && files.isEmpty)
              VaultSurface(
                palette: p,
                borderRadius: VaultRadii.card,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CustomPaint(
                        painter: _VaultDoorPainter(
                          strokeColor: p.champagne,
                          mutedColor: p.glassBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      query.isNotEmpty ? s.noMatching : s.folderEmpty,
                      textAlign: TextAlign.center,
                      style: VaultText.heading(p, s.ar, size: 19),
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
            // Grid View (thumbnails of images & PDF first pages with glass caption overlays)
            else if (_gridMode)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: folders.length + files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (ctx, index) {
                  if (index < folders.length) {
                    final folder = folders[index];
                    final selected = _selectedFolderIds.contains(folder.id);
                    final itemCount = childCounts[folder.id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: VaultTap(
                        onTap: () => _selectionMode
                            ? _toggleFolderSelection(folder.id)
                            : _navigateToFolder(folder.id),
                        onLongPress: () => _toggleFolderSelection(folder.id),
                        child: VaultStackedGlassCard(
                          palette: p,
                          borderRadius: VaultRadii.md,
                          child: VaultSurface(
                            palette: p,
                            borderRadius: VaultRadii.md,
                            backgroundColor:
                                selected ? p.champagneSoft : p.glassFill,
                            borderColor:
                                selected ? p.champagne : p.glassBorder,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: p.champagneSoft,
                                        borderRadius: BorderRadius.circular(
                                            VaultRadii.tile),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.folder_outlined,
                                          size: 20, color: p.champagne),
                                    ),
                                    if (_selectionMode)
                                      _CircularCheck(
                                          palette: p, selected: selected),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      folder.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: VaultText.body(
                                        p,
                                        s.ar,
                                        size: 15,
                                        weight: FontWeight.w600,
                                        applyArabicScale: false,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.itemsCountLabel(itemCount),
                                      style: VaultText.monoText(
                                        p,
                                        s.itemsCountLabel(itemCount),
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
                  final file = files[index - folders.length];
                  final previewable = isPreviewableFile(file.mimeType, file.name);
                  final selected = _selectedFileIds.contains(file.id);
                  final locationLabel = (isGlobalSearch || widget.isRecent)
                      ? (file.folderId == null
                          ? s.myFiles
                          : (folderPaths[file.folderId] ?? s.folderWord))
                      : null;
                  return _GridFileCard(
                    palette: p,
                    controller: ctrl,
                    isArabic: s.ar,
                    file: file,
                    selected: selected,
                    selectionMode: _selectionMode,
                    locationLabel: locationLabel,
                    statusDotColor: _statusDotColorForFile(p, file),
                    onTap: () => _selectionMode
                        ? _toggleFileSelection(file.id)
                        : (previewable
                            ? _openPreview(file)
                            : _showFileInspector(file)),
                    onLongPress: () => _toggleFileSelection(file.id),
                  );
                },
              )
            // List View (individual glass cards with generous breathing room)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isGlobalSearch && !widget.isRecent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: VaultSectionHeader(
                        palette: p,
                        isArabic: s.ar,
                        title: s.searchResultsLabel(
                            folders.length + files.length),
                      ),
                    ),
                  for (final folder in folders)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 10),
                      child: _FolderGlassRow(
                        palette: p,
                        isArabic: s.ar,
                        itemsLabel:
                            s.itemsCountLabel(childCounts[folder.id] ?? 0),
                        folder: folder,
                        selectionMode: _selectionMode,
                        selected: _selectedFolderIds.contains(folder.id),
                        onTap: () => _selectionMode
                            ? _toggleFolderSelection(folder.id)
                            : _navigateToFolder(folder.id),
                        onLongPress: () => _toggleFolderSelection(folder.id),
                      ),
                    ),
                  for (final file in files)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileGlassRow(
                        palette: p,
                        isArabic: s.ar,
                        file: file,
                        folderPathLabel: (isGlobalSearch || widget.isRecent)
                            ? (file.folderId == null
                                ? s.myFiles
                                : folderPaths[file.folderId])
                            : null,
                        statusDotColor: _statusDotColorForFile(p, file),
                        selectionMode: _selectionMode,
                        selected: _selectedFileIds.contains(file.id),
                        onTap: () => _selectionMode
                            ? _toggleFileSelection(file.id)
                            : (isPreviewableFile(
                                    file.mimeType, file.name)
                                ? _openPreview(file)
                                : _showFileInspector(file)),
                        onLongPress: () => _toggleFileSelection(file.id),
                        onInspect: () => _showFileInspector(file),
                      ),
                    ),
                ],
              ),
          ],
        ),

        // Floating primary "+" glass button above nav bar
        if (!_selectionMode)
          PositionedDirectional(
            end: 20,
            bottom: widget.bottomPadding - 4,
            child: SafeArea(
              top: false,
              child: VaultTap(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _showPlusActionMenu();
                },
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
                  child: Icon(Icons.add_rounded,
                      size: 26, color: p.primaryBtnInk),
                ),
              ),
            ),
          ),

        // Multi-Select Floating Liquid-Glass Action Bar
        if (_selectionMode)
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: VaultSurface(
                  palette: p,
                  borderRadius: VaultRadii.pill,
                  elevated: true,
                  borderColor: p.glassTopLeftBorder,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      ],
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
        child: Container(
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
    return Container(
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
          ? Icon(
              Icons.check_rounded,
              size: 14,
              color: palette.isDark
                  ? const Color(0xFF050506)
                  : const Color(0xFFF7F6F3),
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
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderGlassRow({
    required this.palette,
    required this.isArabic,
    required this.itemsLabel,
    required this.folder,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return VaultTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: VaultStackedGlassCard(
        palette: p,
        borderRadius: VaultRadii.md,
        child: VaultSurface(
          palette: p,
          borderRadius: VaultRadii.md,
          backgroundColor: selected ? p.champagneSoft : p.glassFill,
          borderColor: selected ? p.champagne : p.glassBorder,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              if (selectionMode) ...[
                _CircularCheck(palette: p, selected: selected),
                const SizedBox(width: 12),
              ],
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
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.body(
                        p,
                        isArabic,
                        size: 15,
                        weight: FontWeight.w600,
                        applyArabicScale: false,
                      ),
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
    );
  }
}

class _FileGlassRow extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final FileRecord file;
  final String? folderPathLabel;
  final Color statusDotColor;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInspect;

  const _FileGlassRow({
    required this.palette,
    required this.isArabic,
    required this.file,
    this.folderPathLabel,
    required this.statusDotColor,
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

    return VaultTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: VaultSurface(
        palette: p,
        borderRadius: VaultRadii.md,
        backgroundColor: selected ? p.champagneSoft : p.glassFill,
        borderColor: selected ? p.champagne : p.glassBorder,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (selectionMode) ...[
              _CircularCheck(palette: p, selected: selected),
              const SizedBox(width: 12),
            ],
            Container(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.body(
                      p,
                      isArabic,
                      size: 14.5,
                      weight: FontWeight.w500,
                      applyArabicScale: false,
                    ),
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
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusDotColor,
                    shape: BoxShape.circle,
                  ),
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
    );
  }
}

class _GridFileCard extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;
  final bool isArabic;
  final FileRecord file;
  final bool selected;
  final bool selectionMode;
  final String? locationLabel;
  final Color statusDotColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridFileCard({
    required this.palette,
    required this.controller,
    required this.isArabic,
    required this.file,
    required this.selected,
    required this.selectionMode,
    this.locationLabel,
    required this.statusDotColor,
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

    return VaultTap(
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
            if (hasThumb)
              Image.file(
                File(_thumbPath!),
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    iconForMimeOrName(file.mimeType, file.name),
                    size: 32,
                    color: p.champagne,
                  ),
                ),
              )
            else
              Container(
                color: p.cardSolid.withValues(alpha: p.isDark ? 0.65 : 0.45),
                padding: const EdgeInsets.only(bottom: 44),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.glassFill,
                      borderRadius: BorderRadius.circular(VaultRadii.tile),
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

            // Top corner badges with WCAG AA scrim
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
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: widget.statusDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Bottom glass caption overlay with solid scrim for contrast
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: p.scrim,
                  border:
                      Border(top: BorderSide(color: p.glassBorder, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.body(
                        p,
                        widget.isArabic,
                        size: 13,
                        weight: FontWeight.w600,
                        applyArabicScale: false,
                      ),
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
  final VoidCallback onTap;

  const _TreePickerRow({
    required this.palette,
    required this.isArabic,
    required this.icon,
    required this.title,
    required this.depth,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
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
                Icon(Icons.check_circle_rounded,
                    size: 18, color: p.signalGreen),
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
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSubmit(),
            style: VaultText.body(p, isAr, size: 14.5, applyArabicScale: false),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: widget.hintText != null
                  ? VaultText.monoText(p, widget.hintText!,
                      size: 12, color: p.secondary)
                  : null,
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
                borderSide: BorderSide(color: p.champagne, width: 1.2),
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

class _VaultDoorPainter extends CustomPainter {
  final Color strokeColor;
  final Color mutedColor;

  const _VaultDoorPainter({
    required this.strokeColor,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pMain = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pSub = Paint()
      ..color = mutedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, pMain);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.22, pSub);
    canvas.drawCircle(center, size.width * 0.11, pMain);

    // 4 subtle lock spokes
    for (final offset in const [
      Offset(0, -14),
      Offset(0, 14),
      Offset(-14, 0),
      Offset(14, 0),
    ]) {
      canvas.drawLine(
        center + offset * 0.55,
        center + offset,
        pMain,
      );
    }
  }

  @override
  bool shouldRepaint(_VaultDoorPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.mutedColor != mutedColor;
}

class _GlassSkeletonList extends StatefulWidget {
  final AppPalette palette;
  const _GlassSkeletonList({required this.palette});

  @override
  State<_GlassSkeletonList> createState() => _GlassSkeletonListState();
}

class _GlassSkeletonListState extends State<_GlassSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _shimmerCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final alpha = 0.25 + (_shimmerCtrl.value * 0.35);
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
                        color: p.secondary.withValues(alpha: alpha * 0.45),
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
                                color: p.secondary.withValues(alpha: alpha * 0.5),
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
                                color: p.secondary.withValues(alpha: alpha * 0.3),
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

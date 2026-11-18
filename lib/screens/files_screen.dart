import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_icon.dart';
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

  Future<void> _pickDocuments() async {
    final files = await FilePicker.pickFiles();
    final paths = files.map((f) => f.path).whereType<String>().toList();
    if (paths.isNotEmpty) {
      widget.controller.uploadFiles(paths);
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia();
    if (files.isEmpty) return;
    widget.controller.uploadFiles(files.map((x) => x.path).toList());
  }

  void _showUploadSheet() {
    final p = widget.palette;
    final s = widget.controller.strings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultSheetShell(
        palette: p,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.encryptAndUpload,
              style: VaultText.heading(p, s.ar, size: 17),
            ),
            const SizedBox(height: 4),
            Text(
              s.uploadDesc,
              style: VaultText.body(p, s.ar, size: 13, color: p.muted),
            ),
            const SizedBox(height: 16),
            _SheetActionList(
              palette: p,
              isArabic: s.ar,
              items: [
                _SheetActionItem(
                  icon: Icons.description_outlined,
                  title: s.uploadDocs,
                  subtitle: s.uploadDocsSub,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocuments();
                  },
                ),
                _SheetActionItem(
                  icon: Icons.photo_library_outlined,
                  title: s.uploadMedia,
                  subtitle: s.uploadMediaSub,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMedia();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNewFolderSheet() {
    final p = widget.palette;
    final s = widget.controller.strings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PromptSheetForm(
        palette: p,
        isArabic: s.ar,
        title: s.newFolder,
        hintText: s.folderNameHint,
        cancelLabel: s.cancel,
        confirmLabel: s.create,
        onSubmit: widget.controller.createFolder,
      ),
    );
  }

  void _showMoveTargetSheet({
    List<int> excludedFolderIds = const [],
    required ValueChanged<int?> onPickTarget,
  }) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final validFolders = ctrl.snapshot.allFolders.where((f) {
      for (final ex in excludedFolderIds) {
        if (ctrl.isDescendantFolder(f.id, ex)) return false;
      }
      return true;
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VaultSheetShell(
        palette: p,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.moveToTitle, style: VaultText.heading(p, s.ar, size: 17)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: _SheetActionList(
                    palette: p,
                    isArabic: s.ar,
                    items: [
                      _SheetActionItem(
                        icon: Icons.home_outlined,
                        title: s.rootFolderLabel,
                        onTap: () {
                          Navigator.pop(ctx);
                          onPickTarget(null);
                        },
                      ),
                      for (final folder in validFolders)
                        _SheetActionItem(
                          icon: Icons.folder_outlined,
                          title: folder.name,
                          onTap: () {
                            Navigator.pop(ctx);
                            onPickTarget(folder.id);
                          },
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
      builder: (ctx) => VaultSheetShell(
        palette: p,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(iconForMimeOrName(file.mimeType, file.name),
                    color: p.cobalt, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.heading(p, s.ar, size: 15.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatBytes(file.size)}, ${file.isEncrypted ? "AES-256-GCM" : "Unencrypted"}',
                        style: VaultText.tabular(p, s.ar, size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (file.sha256.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(VaultRadii.xs),
                  border: Border.all(color: p.rule),
                ),
                child: Text(
                  'SHA-256  ${file.sha256}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VaultText.mono(p, size: 11),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _SheetActionList(
              palette: p,
              isArabic: s.ar,
              items: [
                if (isPreviewableFile(file.mimeType, file.name))
                  _SheetActionItem(
                    icon: Icons.visibility_outlined,
                    title: isPdfFile(file.mimeType, file.name)
                        ? s.previewPdf
                        : (isVideoFile(file.mimeType, file.name)
                            ? s.previewVideo
                            : (isAudioFile(file.mimeType, file.name)
                                ? s.previewAudio
                                : s.previewImage)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openPreview(file);
                    },
                  ),
                _SheetActionItem(
                  icon: Icons.download_outlined,
                  title: s.downloadAndDecrypt,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.controller.downloadFile(file);
                  },
                ),
                _SheetActionItem(
                  icon: Icons.drive_file_rename_outline,
                  title: s.renameFile,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameSheet(
                      title: s.renameFile,
                      initial: file.name,
                      onSave: (val) =>
                          widget.controller.renameFile(file.id, val),
                    );
                  },
                ),
                _SheetActionItem(
                  icon: Icons.drive_file_move_outlined,
                  title: s.moveFile,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMoveTargetSheet(
                      onPickTarget: (targetId) =>
                          widget.controller.moveFile(file.id, targetId),
                    );
                  },
                ),
                _SheetActionItem(
                  icon: Icons.delete_outline,
                  title: s.deleteFile,
                  isDanger: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.controller.deleteFile(file.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSheet({
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) {
    final p = widget.palette;
    final s = widget.controller.strings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PromptSheetForm(
        palette: p,
        isArabic: s.ar,
        title: title,
        initialText: initial,
        cancelLabel: s.cancel,
        confirmLabel: s.save,
        onSubmit: onSave,
      ),
    );
  }

  void _showSortSheet() {
    HapticFeedback.selectionClick();
    final p = widget.palette;
    final s = widget.controller.strings;
    final options = <(_SortBy, String, IconData)>[
      (_SortBy.date, s.sortDate, Icons.schedule_outlined),
      (_SortBy.name, s.sortName, Icons.sort_by_alpha_outlined),
      (_SortBy.size, s.sortSize, Icons.data_usage_outlined),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultSheetShell(
        palette: p,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.sortByTitle, style: VaultText.heading(p, s.ar, size: 17)),
            const SizedBox(height: 12),
            _SheetActionList(
              palette: p,
              isArabic: s.ar,
              items: [
                for (final opt in options)
                  _SheetActionItem(
                    icon: opt.$3,
                    title: opt.$2,
                    trailingText: _sortBy == opt.$1
                        ? (_sortAsc ? '↑' : '↓')
                        : null,
                    isActive: _sortBy == opt.$1,
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
              ],
            ),
          ],
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

  String _sortLabel(AppStrings s) => switch (_sortBy) {
        _SortBy.date => s.sortDate,
        _SortBy.name => s.sortName,
        _SortBy.size => s.sortSize,
      };

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

    var totalVaultBytes = 0;
    var imgBytes = 0;
    var pdfBytes = 0;
    var videoAudioBytes = 0;
    var otherBytes = 0;
    for (final f in allVaultFiles) {
      totalVaultBytes += f.size;
      if (isImageFile(f.mimeType, f.name)) {
        imgBytes += f.size;
      } else if (isPdfFile(f.mimeType, f.name)) {
        pdfBytes += f.size;
      } else if (isVideoFile(f.mimeType, f.name) ||
          isAudioFile(f.mimeType, f.name)) {
        videoAudioBytes += f.size;
      } else {
        otherBytes += f.size;
      }
    }

    final showStatusDot = !_selectionMode &&
        (ctrl.authStatus.isAuthorized ||
            ctrl.isReconnecting ||
            ctrl.hasSavedSession);
    final statusColor = ctrl.authStatus.isAuthorized
        ? p.cobalt
        : (ctrl.isReconnecting ? p.signal : p.danger);
    final statusLabel = ctrl.authStatus.isAuthorized
        ? s.statusSynced
        : (ctrl.isReconnecting ? s.statusConnecting : s.statusOfflineTap);
    final statusOnTap = (!ctrl.authStatus.isAuthorized &&
            !ctrl.isReconnecting &&
            ctrl.hasSavedSession)
        ? ctrl.connect
        : null;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            _selectionMode ? widget.bottomPadding + 20 : widget.bottomPadding,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // Archival Masthead (large unobstructed display title + borderless actions)
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _selectionMode
                          ? s.selectedCount(_totalSelected)
                          : (widget.isRecent
                              ? s.recentTitle
                              : (snap.currentFolder?.name ?? s.appTitle)),
                      maxLines: 1,
                      softWrap: false,
                      style: VaultText.display(p, s.ar, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _MastheadIconButton(
                  palette: p,
                  active: _selectionMode,
                  tooltip: _selectionMode ? s.clearSelection : s.selectAll,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_selectionMode) {
                      _exitSelectionMode();
                    } else {
                      setState(() => _selectionMode = true);
                      widget.controller.setSelecting(true);
                    }
                  },
                  icon: Icon(
                    _selectionMode ? Icons.close : Icons.checklist_rounded,
                    size: 20,
                    color: _selectionMode ? p.cobalt : p.ink,
                  ),
                ),
                _MastheadIconButton(
                  palette: p,
                  tooltip: _gridMode ? 'List view' : 'Grid view',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _gridMode = !_gridMode);
                  },
                  icon: Icon(
                    _gridMode
                        ? Icons.view_list_outlined
                        : Icons.grid_view_outlined,
                    size: 20,
                    color: p.ink,
                  ),
                ),
                if (!widget.isRecent)
                  _MastheadIconButton(
                    palette: p,
                    tooltip: s.newFolder,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showNewFolderSheet();
                    },
                    icon: AppSvgIcon(AppIcons.addFolder, size: 19, color: p.ink),
                  ),
                const SizedBox(width: 6),
                VaultTap(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showUploadSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: p.signal,
                      borderRadius: BorderRadius.circular(VaultRadii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSvgIcon(AppIcons.cloudUpload,
                            size: 17, color: p.signalInk),
                        const SizedBox(width: 5),
                        Text(
                          s.upload,
                          style: VaultText.body(
                            p,
                            s.ar,
                            size: 13,
                            weight: FontWeight.w700,
                            color: p.signalInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (showStatusDot) ...[
                  VaultStatusDot(
                    palette: p,
                    isArabic: s.ar,
                    dotColor: statusColor,
                    label: statusLabel,
                    onTap: statusOnTap,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    s.foldersAndFiles(folders.length, files.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.tabular(p, s.ar, size: 12.5),
                  ),
                ),
              ],
            ),

            if (!widget.isRecent &&
                snap.currentFolder == null &&
                allVaultFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.totalVaultLabel,
                    style: VaultText.body(p, s.ar, size: 11.5, color: p.muted),
                  ),
                  Text(
                    formatBytes(totalVaultBytes),
                    style: VaultText.tabular(
                      p,
                      s.ar,
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              VaultProportionalTape(
                palette: p,
                imageBytes: imgBytes,
                pdfBytes: pdfBytes,
                videoAudioBytes: videoAudioBytes,
                otherBytes: otherBytes,
                height: 3,
                borderRadius: VaultRadii.pill,
              ),
            ],
            const SizedBox(height: 12),

            // Recessed Search Field
            VaultSurface(
              palette: p,
              borderRadius: VaultRadii.sm,
              backgroundColor: p.surfaceAlt,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: p.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: VaultText.body(p, s.ar, size: 14),
                      decoration: InputDecoration(
                        hintText: s.searchHint,
                        hintStyle:
                            VaultText.body(p, s.ar, size: 14, color: p.muted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchCtrl.clear()),
                      child: Icon(Icons.close, size: 17, color: p.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Baseline-Indexed Sort & Filter Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.rule, width: 1)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    VaultTap(
                      onTap: _showSortSheet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sortAsc
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 13,
                              color: p.cobalt,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortLabel(s),
                              style: VaultText.body(
                                p,
                                s.ar,
                                size: 12.5,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: p.rule,
                    ),
                    for (final entry in filterEntries)
                      VaultTap(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = entry.$1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _filter == entry.$1
                                    ? p.cobalt
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            entry.$2,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 12.5,
                              weight: _filter == entry.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _filter == entry.$1 ? p.ink : p.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Inline Typographic Breadcrumbs
            if (!widget.isRecent && snap.breadcrumbs.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    VaultTap(
                      onTap: () => _navigateToFolder(null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Text(
                          s.myFiles,
                          style: VaultText.body(
                            p,
                            s.ar,
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < snap.breadcrumbs.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          s.ar ? Icons.chevron_left : Icons.chevron_right,
                          size: 15,
                          color: p.muted,
                        ),
                      ),
                      VaultTap(
                        onTap: () => _navigateToFolder(snap.breadcrumbs[i].id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Text(
                            snap.breadcrumbs[i].name,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 12.5,
                              weight: i == snap.breadcrumbs.length - 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == snap.breadcrumbs.length - 1
                                  ? p.cobalt
                                  : p.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Content
            if (folders.isEmpty && files.isEmpty)
              VaultSurface(
                palette: p,
                borderRadius: VaultRadii.md,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
                child: Column(
                  children: [
                    AppSvgIcon(AppIcons.folderOpen, size: 34, color: p.muted),
                    const SizedBox(height: 10),
                    Text(
                      query.isNotEmpty ? s.noMatching : s.folderEmpty,
                      style: VaultText.heading(p, s.ar, size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      query.isNotEmpty
                          ? s.nothingMatched(_searchCtrl.text)
                          : s.emptyDesc,
                      textAlign: TextAlign.center,
                      style: VaultText.body(p, s.ar, size: 13, color: p.muted),
                    ),
                  ],
                ),
              )
            else if (_gridMode)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: folders.length + files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.96,
                ),
                itemBuilder: (ctx, index) {
                  if (index < folders.length) {
                    final folder = folders[index];
                    final selected = _selectedFolderIds.contains(folder.id);
                    final itemCount = childCounts[folder.id] ?? 0;
                    return VaultTap(
                      onTap: () => _selectionMode
                          ? _toggleFolderSelection(folder.id)
                          : _navigateToFolder(folder.id),
                      onLongPress: () => _toggleFolderSelection(folder.id),
                      child: VaultSurface(
                        palette: p,
                        borderRadius: VaultRadii.md,
                        backgroundColor: selected ? p.cobaltSoft : p.surface,
                        borderColor: selected ? p.cobalt : p.rule,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppSvgIcon(AppIcons.folderOpen,
                                    size: 26, color: p.cobalt),
                                if (_selectionMode)
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 19,
                                    color: selected ? p.cobalt : p.muted,
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: VaultText.body(p, s.ar,
                                      size: 14, weight: FontWeight.w600),
                                ),
                                Text(
                                  s.itemsCountLabel(itemCount),
                                  style: VaultText.tabular(p, s.ar, size: 12),
                                ),
                              ],
                            ),
                          ],
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
                    onTap: () => _selectionMode
                        ? _toggleFileSelection(file.id)
                        : (previewable
                            ? _openPreview(file)
                            : _showFileInspector(file)),
                    onLongPress: () => _toggleFileSelection(file.id),
                  );
                },
              )
            else
              VaultSurface(
                palette: p,
                borderRadius: VaultRadii.md,
                child: Column(
                  children: [
                    if (isGlobalSearch && !widget.isRecent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          border:
                              Border(bottom: BorderSide(color: p.rule, width: 1)),
                        ),
                        child: Text(
                          s.searchResultsLabel(folders.length + files.length),
                          style: VaultText.body(p, s.ar,
                              size: 12, weight: FontWeight.w600, color: p.muted),
                        ),
                      ),
                    for (var i = 0; i < folders.length; i++)
                      _FolderListTile(
                        palette: p,
                        isArabic: s.ar,
                        itemsLabel:
                            s.itemsCountLabel(childCounts[folders[i].id] ?? 0),
                        folder: folders[i],
                        showDivider: i > 0,
                        selectionMode: _selectionMode,
                        selected: _selectedFolderIds.contains(folders[i].id),
                        onTap: () => _selectionMode
                            ? _toggleFolderSelection(folders[i].id)
                            : _navigateToFolder(folders[i].id),
                        onLongPress: () =>
                            _toggleFolderSelection(folders[i].id),
                      ),
                    for (var i = 0; i < files.length; i++)
                      _FileListTile(
                        palette: p,
                        isArabic: s.ar,
                        file: files[i],
                        subtitleOverride: (isGlobalSearch || widget.isRecent)
                            ? (files[i].folderId == null
                                ? s.myFiles
                                : folderPaths[files[i].folderId])
                            : null,
                        showDivider: folders.isNotEmpty || i > 0,
                        selectionMode: _selectionMode,
                        selected: _selectedFileIds.contains(files[i].id),
                        onTap: () => _selectionMode
                            ? _toggleFileSelection(files[i].id)
                            : (isPreviewableFile(
                                    files[i].mimeType, files[i].name)
                                ? _openPreview(files[i])
                                : _showFileInspector(files[i])),
                        onLongPress: () => _toggleFileSelection(files[i].id),
                      ),
                  ],
                ),
              ),
          ],
        ),

        // Multi-Select Dock (replaces VaultDock smoothly)
        if (_selectionMode)
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VaultSurface(
                  palette: p,
                  borderRadius: VaultRadii.dock,
                  elevated: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BulkActionBtn(
                        palette: p,
                        isArabic: s.ar,
                        icon: Icons.select_all,
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
                          _showMoveTargetSheet(
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
                        icon: Icons.drive_file_rename_outline,
                        label: s.renameAction,
                        enabled: _totalSelected == 1,
                        onTap: () {
                          if (_selectedFolderIds.length == 1) {
                            final folderId = _selectedFolderIds.first;
                            final folder = folders
                                .where((f) => f.id == folderId)
                                .firstOrNull;
                            if (folder == null) return;
                            _showRenameSheet(
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
                            _showRenameSheet(
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
                        icon: Icons.delete_outline,
                        label: s.deleteAction,
                        isDanger: true,
                        enabled: _totalSelected > 0,
                        onTap: () {
                          ctrl.deleteMany(
                            folderIds: _selectedFolderIds.toList(),
                            fileIds: _selectedFileIds.toList(),
                          );
                          _exitSelectionMode();
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
    final color = !enabled
        ? palette.muted.withValues(alpha: 0.45)
        : (isDanger ? palette.danger : palette.cobalt);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: VaultText.body(
                palette,
                isArabic,
                size: 11,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
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

class _MastheadIconButton extends StatelessWidget {
  final AppPalette palette;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;

  const _MastheadIconButton({
    required this.palette,
    this.active = false,
    required this.tooltip,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: VaultTap(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? palette.cobaltSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(VaultRadii.sm),
          ),
          child: icon,
        ),
      ),
    );
  }
}

class _PromptSheetForm extends StatefulWidget {
  final AppPalette palette;
  final bool isArabic;
  final String title;
  final String initialText;
  final String? hintText;
  final String cancelLabel;
  final String confirmLabel;
  final ValueChanged<String> onSubmit;

  const _PromptSheetForm({
    required this.palette,
    required this.isArabic,
    required this.title,
    this.initialText = '',
    this.hintText,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onSubmit,
  });

  @override
  State<_PromptSheetForm> createState() => _PromptSheetFormState();
}

class _PromptSheetFormState extends State<_PromptSheetForm> {
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
    return VaultSheetShell(
      palette: p,
      outerPadding: EdgeInsets.fromLTRB(
          12, 0, 12, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: VaultText.heading(p, isAr, size: 17)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSubmit(),
            style: VaultText.body(p, isAr, size: 14.5),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: widget.hintText != null
                  ? VaultText.body(p, isAr, size: 14, color: p.muted)
                  : null,
              filled: true,
              fillColor: p.surfaceAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VaultRadii.sm),
                borderSide: BorderSide(color: p.rule),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VaultRadii.sm),
                borderSide: BorderSide(color: p.cobalt, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  widget.cancelLabel,
                  style: VaultText.body(p, isAr,
                      size: 14, weight: FontWeight.w600, color: p.muted),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.signal,
                  foregroundColor: p.signalInk,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.sm),
                  ),
                ),
                child: Text(
                  widget.confirmLabel,
                  style: VaultText.body(p, isAr,
                      size: 14, weight: FontWeight.w700, color: p.signalInk),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderListTile extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String itemsLabel;
  final Folder folder;
  final bool showDivider;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderListTile({
    required this.palette,
    required this.isArabic,
    required this.itemsLabel,
    required this.folder,
    required this.showDivider,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 13, 14, 13),
        decoration: BoxDecoration(
          color: selected ? palette.cobaltSoft : null,
          border: BorderDirectional(
            start: BorderSide(color: palette.cobalt, width: 3),
            top: showDivider
                ? BorderSide(color: palette.rule, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? palette.cobalt : palette.muted,
              ),
              const SizedBox(width: 10),
            ],
            AppSvgIcon(AppIcons.folderOpen, size: 20, color: palette.cobalt),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VaultText.body(
                  palette,
                  isArabic,
                  size: 14.5,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              itemsLabel,
              style: VaultText.tabular(palette, isArabic, size: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final FileRecord file;
  final String? subtitleOverride;
  final bool showDivider;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileListTile({
    required this.palette,
    required this.isArabic,
    required this.file,
    this.subtitleOverride,
    required this.showDivider,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleText = (subtitleOverride != null && subtitleOverride!.isNotEmpty)
        ? subtitleOverride!
        : formatTimestamp(file.createdAt);
    final extTag = _fileExtensionTag(file);
    final extColor = isPdfFile(file.mimeType, file.name)
        ? palette.danger
        : ((isVideoFile(file.mimeType, file.name) ||
                isAudioFile(file.mimeType, file.name))
            ? palette.cobalt
            : palette.ink);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.cobaltSoft : null,
          border: showDivider
              ? Border(top: BorderSide(color: palette.rule, width: 1))
              : null,
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? palette.cobalt : palette.muted,
              ),
              const SizedBox(width: 10),
            ],
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(VaultRadii.xs),
                border: Border.all(color: palette.rule),
              ),
              alignment: Alignment.center,
              child: Text(
                extTag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VaultText.mono(palette, size: 10, color: extColor),
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
                    style: VaultText.body(palette, isArabic,
                        size: 14.5, weight: FontWeight.w600),
                  ),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VaultText.tabular(palette, isArabic, size: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatBytes(file.size),
                  style: VaultText.tabular(
                    palette,
                    isArabic,
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                if (file.isEncrypted)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.lock, size: 12, color: palette.signal),
                  ),
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
        backgroundColor: widget.selected ? p.cobaltSoft : p.surface,
        borderColor: widget.selected ? p.cobalt : p.rule,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: p.surfaceAlt,
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
                            size: 30,
                            color: p.muted,
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          iconForMimeOrName(file.mimeType, file.name),
                          size: 32,
                          color: isPdfFile(file.mimeType, file.name)
                              ? p.danger
                              : (isVideoFile(file.mimeType, file.name) ||
                                      isAudioFile(file.mimeType, file.name)
                                  ? p.cobalt
                                  : p.muted),
                        ),
                      ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasThumb
                              ? p.ground.withValues(alpha: 0.88)
                              : p.surface,
                          borderRadius: BorderRadius.circular(VaultRadii.xs),
                          border: Border.all(color: p.rule),
                        ),
                        child: Text(
                          ext,
                          style: VaultText.mono(p, size: 10, color: p.ink),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: widget.selectionMode
                          ? Icon(
                              widget.selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: widget.selected ? p.cobalt : p.muted,
                            )
                          : (file.isEncrypted
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: hasThumb
                                        ? p.ground.withValues(alpha: 0.88)
                                        : p.signalSoft,
                                    borderRadius:
                                        BorderRadius.circular(VaultRadii.xs),
                                    border: Border.all(
                                      color: p.signal.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Icon(Icons.lock,
                                      size: 11, color: p.signal),
                                )
                              : const SizedBox.shrink()),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.rule, width: 1)),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatBytes(file.size),
                        style: VaultText.tabular(p, widget.isArabic, size: 11.5),
                      ),
                      if (widget.locationLabel != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.locationLabel!,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VaultText.body(
                              p,
                              widget.isArabic,
                              size: 11,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool isDanger;
  final bool isActive;
  final VoidCallback onTap;

  const _SheetActionItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.isDanger = false,
    this.isActive = false,
    required this.onTap,
  });
}

class _SheetActionList extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final List<_SheetActionItem> items;

  const _SheetActionList({
    required this.palette,
    required this.isArabic,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(VaultRadii.md),
        border: Border.all(color: palette.rule),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: items[i].onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: items[i].isActive ? palette.cobaltSoft : null,
                  border: i > 0
                      ? Border(top: BorderSide(color: palette.rule, width: 1))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      items[i].icon,
                      size: 19,
                      color: items[i].isDanger
                          ? palette.danger
                          : (items[i].isActive ? palette.cobalt : palette.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].title,
                            style: VaultText.body(
                              palette,
                              isArabic,
                              size: 14,
                              weight: FontWeight.w600,
                              color: items[i].isDanger
                                  ? palette.danger
                                  : (items[i].isActive
                                      ? palette.cobalt
                                      : palette.ink),
                            ),
                          ),
                          if (items[i].subtitle != null)
                            Text(
                              items[i].subtitle!,
                              style: VaultText.body(
                                palette,
                                isArabic,
                                size: 12,
                                color: palette.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (items[i].trailingText != null)
                      Text(
                        items[i].trailingText!,
                        style: VaultText.body(
                          palette,
                          isArabic,
                          size: 14,
                          weight: FontWeight.w700,
                          color: palette.cobalt,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

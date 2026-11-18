import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/core_models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/vault_surface.dart';

enum _TransferSegment { active, completed, failed }

class TransfersScreen extends StatefulWidget {
  final AppPalette palette;
  final AppStrings strings;
  final List<TaskRecord> tasks;
  final Map<int, String> fileNamesById;
  final Map<int, int> fileSizesById;
  final int chunkSizeMiB;
  final int floodWaitSeconds;
  final double bottomPadding;
  final ValueChanged<int>? onPauseTask;
  final ValueChanged<TaskRecord>? onResumeTask;
  final ValueChanged<TaskRecord>? onRetryTask;

  const TransfersScreen({
    super.key,
    required this.palette,
    required this.strings,
    required this.tasks,
    required this.fileNamesById,
    required this.fileSizesById,
    this.chunkSizeMiB = 512,
    required this.floodWaitSeconds,
    required this.bottomPadding,
    this.onPauseTask,
    this.onResumeTask,
    this.onRetryTask,
  });

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  _TransferSegment _segment = _TransferSegment.active;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.strings;
    final tasks = widget.tasks;

    final activeTasks = <TaskRecord>[];
    final completedTasks = <TaskRecord>[];
    final failedTasks = <TaskRecord>[];

    for (final t in tasks) {
      if (t.state == TaskState.completed) {
        completedTasks.add(t);
      } else if (t.state == TaskState.failed) {
        failedTasks.add(t);
      } else {
        activeTasks.add(t);
      }
    }

    final visibleTasks = switch (_segment) {
      _TransferSegment.active => activeTasks,
      _TransferSegment.completed => completedTasks,
      _TransferSegment.failed => failedTasks,
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        VaultSpacing.screenHorizontal,
        16,
        VaultSpacing.screenHorizontal,
        widget.bottomPadding + 20,
      ),
      children: [
        Text(
          s.transfersTitle,
          style: VaultText.display(p, s.ar, size: 34),
        ),
        const SizedBox(height: 4),
        Text(
          s.transfersSub,
          style: VaultText.body(p, s.ar, size: 13.5, color: p.secondary),
        ),
        const SizedBox(height: 16),

        VaultSegmentedControl<_TransferSegment>(
          palette: p,
          isArabic: s.ar,
          value: _segment,
          onChanged: (seg) => setState(() => _segment = seg),
          options: [
            VaultSegmentOption(
              value: _TransferSegment.active,
              label: activeTasks.isEmpty
                  ? s.segmentActive
                  : '${s.segmentActive} (${activeTasks.length})',
            ),
            VaultSegmentOption(
              value: _TransferSegment.completed,
              label: completedTasks.isEmpty
                  ? s.segmentCompleted
                  : '${s.segmentCompleted} (${completedTasks.length})',
            ),
            VaultSegmentOption(
              value: _TransferSegment.failed,
              label: failedTasks.isEmpty
                  ? s.segmentFailed
                  : '${s.segmentFailed} (${failedTasks.length})',
            ),
          ],
        ),

        if (widget.floodWaitSeconds > 0) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: VaultMonoChip(
              palette: p,
              label: s.floodWaitMessage(widget.floodWaitSeconds),
              icon: Icons.hourglass_top_rounded,
              textColor: p.floodAmber,
              backgroundColor: p.floodSoft,
              borderColor: p.floodAmber.withValues(alpha: 0.45),
            ),
          ),
        ],

        const SizedBox(height: 18),

        if (visibleTasks.isEmpty)
          VaultSurface(
            palette: p,
            borderRadius: VaultRadii.card,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
            child: Column(
              children: [
                Icon(Icons.swap_vert_rounded, size: 34, color: p.secondary),
                const SizedBox(height: 12),
                Text(
                  s.noTransfers,
                  textAlign: TextAlign.center,
                  style: VaultText.heading(p, s.ar, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  s.noTransfersDesc,
                  textAlign: TextAlign.center,
                  style: VaultText.body(p, s.ar, size: 13.5, color: p.secondary),
                ),
              ],
            ),
          )
        else
          for (final task in visibleTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransferGlassCard(
                palette: p,
                strings: s,
                task: task,
                fileName: widget.fileNamesById[task.fileId] ??
                    'File #${task.fileId}',
                totalBytes: widget.fileSizesById[task.fileId] ?? 0,
                chunkSizeMiB: widget.chunkSizeMiB,
                onPause: widget.onPauseTask != null
                    ? () => widget.onPauseTask!(task.id)
                    : null,
                onResume: widget.onResumeTask != null
                    ? () => widget.onResumeTask!(task)
                    : null,
                onRetry: widget.onRetryTask != null
                    ? () => widget.onRetryTask!(task)
                    : (widget.onResumeTask != null
                        ? () => widget.onResumeTask!(task)
                        : null),
              ),
            ),
      ],
    );
  }
}

class _TransferGlassCard extends StatelessWidget {
  final AppPalette palette;
  final AppStrings strings;
  final TaskRecord task;
  final String fileName;
  final int totalBytes;
  final int chunkSizeMiB;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;

  const _TransferGlassCard({
    required this.palette,
    required this.strings,
    required this.task,
    required this.fileName,
    required this.totalBytes,
    required this.chunkSizeMiB,
    this.onPause,
    this.onResume,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final progress = task.progress.clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    final tone = switch (task.state) {
      TaskState.running => VaultProgressTone.champagne,
      TaskState.queued || TaskState.paused => VaultProgressTone.slate,
      TaskState.completed => VaultProgressTone.signalGreen,
      TaskState.failed => VaultProgressTone.coral,
    };

    final chunkBytes = (chunkSizeMiB * 1024 * 1024).clamp(1, 1 << 30);
    final totalChunks = totalBytes <= 0
        ? 4
        : (totalBytes / chunkBytes).ceil().clamp(2, 16);
    final currentChunk = task.state == TaskState.completed
        ? totalChunks
        : (progress * totalChunks).ceil().clamp(1, totalChunks);
    final doneChunks = task.state == TaskState.completed
        ? totalChunks
        : (progress * totalChunks).floor().clamp(0, totalChunks);

    final stateText = switch (task.state) {
      TaskState.queued => strings.ar ? 'في الطابور' : 'QUEUED',
      TaskState.running =>
        task.kind == TaskKind.upload ? strings.uploadLabel : strings.downloadLabel,
      TaskState.paused => strings.ar ? 'متوقف مؤقتاً' : 'PAUSED',
      TaskState.completed => strings.ar ? 'مكتمل' : 'SYNCED',
      TaskState.failed => strings.ar ? 'تعذّر' : 'FAILED',
    };

    final bytesMeta = totalBytes > 0
        ? '${formatBytes((totalBytes * progress).round())} / ${formatBytes(totalBytes)}'
        : stateText;

    return VaultSurface(
      palette: p,
      borderRadius: VaultRadii.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                  task.kind == TaskKind.upload
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: task.state == TaskState.completed
                      ? p.signalGreen
                      : (task.state == TaskState.failed
                          ? p.coral
                          : p.champagne),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.body(
                        p,
                        strings.ar,
                        size: 14.5,
                        weight: FontWeight.w600,
                        applyArabicScale: false,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pct% · $bytesMeta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VaultText.monoText(
                        p,
                        '$pct% · $bytesMeta',
                        size: 11,
                        color: p.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (task.state == TaskState.completed)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.signalGreenSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.check_rounded,
                      size: 18, color: p.signalGreen),
                )
              else if (task.state == TaskState.failed && onRetry != null)
                VaultPillButton(
                  palette: p,
                  isArabic: strings.ar,
                  expand: false,
                  height: 36,
                  variant: VaultPillVariant.danger,
                  icon: Icons.refresh_rounded,
                  label: strings.retryAction,
                  onPressed: onRetry,
                )
              else if ((task.state == TaskState.running ||
                      task.state == TaskState.queued) &&
                  onPause != null)
                Tooltip(
                  message: strings.pauseAction,
                  child: VaultTap(
                    onTap: onPause,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.glassElevatedFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.glassBorder),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.pause_rounded, size: 18, color: p.ink),
                    ),
                  ),
                )
              else if (task.state == TaskState.paused && onResume != null)
                Tooltip(
                  message: strings.resumeAction,
                  child: VaultTap(
                    onTap: onResume,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.champagneSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.champagne),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.play_arrow_rounded,
                          size: 20, color: p.champagne),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          VaultProgressBar(
            palette: p,
            progress: progress,
            tone: tone,
            height: 4,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: VaultChunkTape(
                  palette: p,
                  totalChunks: totalChunks,
                  completedChunks: doneChunks,
                  activeTone: tone,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strings.chunkProgressLabel(currentChunk, totalChunks),
                style: VaultText.monoText(
                  p,
                  strings.chunkProgressLabel(currentChunk, totalChunks),
                  size: 10.5,
                  color: p.secondary,
                ),
              ),
            ],
          ),
          if (task.error != null && task.error!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.coralSoft,
                borderRadius: BorderRadius.circular(VaultRadii.tile),
              ),
              child: Text(
                task.error!,
                style: VaultText.body(
                  p,
                  strings.ar,
                  size: 12,
                  color: p.coral,
                  applyArabicScale: false,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

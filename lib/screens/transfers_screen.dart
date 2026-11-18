import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/core_models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/vault_surface.dart';

class TransfersScreen extends StatelessWidget {
  final AppPalette palette;
  final AppStrings strings;
  final List<TaskRecord> tasks;
  final Map<int, String> fileNamesById;
  final Map<int, int> fileSizesById;
  final int floodWaitSeconds;
  final double bottomPadding;
  final ValueChanged<int>? onPauseTask;
  final ValueChanged<TaskRecord>? onResumeTask;

  const TransfersScreen({
    super.key,
    required this.palette,
    required this.strings,
    required this.tasks,
    required this.fileNamesById,
    required this.fileSizesById,
    required this.floodWaitSeconds,
    required this.bottomPadding,
    this.onPauseTask,
    this.onResumeTask,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final s = strings;
    var activeCount = 0;
    var pausedCount = 0;
    var doneCount = 0;
    for (final t in tasks) {
      if (t.state == TaskState.queued || t.state == TaskState.running) {
        activeCount++;
      } else if (t.state == TaskState.paused) {
        pausedCount++;
      } else if (t.state == TaskState.completed) {
        doneCount++;
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      children: [
        Text(
          s.transfersTitle,
          style: VaultText.display(p, s.ar, size: 26),
        ),
        const SizedBox(height: 4),
        Text(
          s.transfersSub,
          style: VaultText.body(p, s.ar, size: 13.5, color: p.muted),
        ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SummaryTag(
                palette: p,
                isArabic: s.ar,
                accentColor: p.signal,
                label: s.activeCountLabel(activeCount),
              ),
              _SummaryTag(
                palette: p,
                isArabic: s.ar,
                accentColor: p.muted,
                label: s.pausedCountLabel(pausedCount),
              ),
              _SummaryTag(
                palette: p,
                isArabic: s.ar,
                accentColor: p.cobalt,
                label: s.completedCountLabel(doneCount),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (floodWaitSeconds > 0) ...[
          VaultSurface(
            palette: p,
            borderRadius: VaultRadii.sm,
            backgroundColor: p.signalSoft,
            borderColor: p.signal,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, size: 18, color: p.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.ar
                        ? 'حد الطلبات من تليجرام نشط. الاستكمال خلال $floodWaitSecondsث.'
                        : 'Telegram rate limit active. Resuming in ${floodWaitSeconds}s.',
                    style: VaultText.body(
                      p,
                      s.ar,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (tasks.isEmpty)
          VaultSurface(
            palette: p,
            borderRadius: VaultRadii.md,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Icon(Icons.swap_vert_circle_outlined, size: 34, color: p.muted),
                const SizedBox(height: 10),
                Text(
                  s.noTransfers,
                  style: VaultText.heading(p, s.ar, size: 15.5),
                ),
                const SizedBox(height: 4),
                Text(
                  s.noTransfersDesc,
                  textAlign: TextAlign.center,
                  style: VaultText.body(p, s.ar, size: 13, color: p.muted),
                ),
              ],
            ),
          )
        else
          VaultSurface(
            palette: p,
            borderRadius: VaultRadii.md,
            child: Column(
              children: [
                for (var i = 0; i < tasks.length; i++)
                  _TransferManifestRow(
                    palette: p,
                    strings: s,
                    task: tasks[i],
                    fileName: fileNamesById[tasks[i].fileId] ??
                        'File #${tasks[i].fileId}',
                    totalBytes: fileSizesById[tasks[i].fileId] ?? 0,
                    showTopRule: i > 0,
                    onPause: onPauseTask != null
                        ? () => onPauseTask!(tasks[i].id)
                        : null,
                    onResume: onResumeTask != null
                        ? () => onResumeTask!(tasks[i])
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TransferManifestRow extends StatelessWidget {
  final AppPalette palette;
  final AppStrings strings;
  final TaskRecord task;
  final String fileName;
  final int totalBytes;
  final bool showTopRule;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const _TransferManifestRow({
    required this.palette,
    required this.strings,
    required this.task,
    required this.fileName,
    required this.totalBytes,
    required this.showTopRule,
    this.onPause,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final pct = (task.progress * 100).clamp(0, 100).round();
    final barColor = switch (task.state) {
      TaskState.failed => p.danger,
      TaskState.completed => p.cobalt,
      _ => task.kind == TaskKind.upload ? p.signal : p.cobalt,
    };

    final stateLabel = switch (task.state) {
      TaskState.queued => strings.ar ? 'في الانتظار' : 'Queued',
      TaskState.running => strings.ar ? 'جاري التنفيذ' : 'Active',
      TaskState.paused => strings.ar ? 'متوقف' : 'Paused',
      TaskState.completed => strings.ar ? 'مكتمل' : 'Done',
      TaskState.failed => strings.ar ? 'فشل' : 'Failed',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: showTopRule
            ? Border(top: BorderSide(color: p.rule, width: 1))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.kind == TaskKind.upload
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: task.kind == TaskKind.upload ? p.signal : p.cobalt,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VaultText.body(
                    p,
                    strings.ar,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$pct%',
                style: VaultText.tabular(
                  p,
                  strings.ar,
                  size: 13,
                  weight: FontWeight.w700,
                  color: barColor == p.signal ? p.ink : barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(VaultRadii.pill),
            child: LinearProgressIndicator(
              value: task.progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.kind == TaskKind.upload
                          ? strings.uploadLabel
                          : strings.downloadLabel,
                      style: VaultText.body(
                        p,
                        strings.ar,
                        size: 12,
                        weight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        stateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VaultText.body(
                          p,
                          strings.ar,
                          size: 12,
                          color: task.state == TaskState.failed
                              ? p.danger
                              : p.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (totalBytes > 0) ...[
                const SizedBox(width: 12),
                Text(
                  '${formatBytes((totalBytes * task.progress).round())} / ${formatBytes(totalBytes)}',
                  style: VaultText.tabular(p, strings.ar, size: 12),
                ),
              ],
            ],
          ),
          if ((task.state == TaskState.queued ||
                  task.state == TaskState.running) &&
              onPause != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: VaultTap(
                onTap: onPause,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(VaultRadii.xs),
                    border: Border.all(color: p.rule),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause, size: 14, color: p.ink),
                      const SizedBox(width: 5),
                      Text(
                        strings.pauseAction,
                        style: VaultText.body(p, strings.ar,
                            size: 12, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (task.state == TaskState.paused && onResume != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: VaultTap(
                onTap: onResume,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.signalSoft,
                    borderRadius: BorderRadius.circular(VaultRadii.xs),
                    border: Border.all(
                      color: p.signal.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 14, color: p.ink),
                      const SizedBox(width: 5),
                      Text(
                        strings.resumeAction,
                        style: VaultText.body(p, strings.ar,
                            size: 12, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (task.error != null && task.error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.error!,
              style: VaultText.body(p, strings.ar, size: 12, color: p.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTag extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final Color accentColor;
  final String label;

  const _SummaryTag({
    required this.palette,
    required this.isArabic,
    required this.accentColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(VaultRadii.xs),
        border: Border.all(color: palette.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: VaultText.tabular(
              palette,
              isArabic,
              size: 11.5,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

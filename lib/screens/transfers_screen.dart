import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/core_models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/vault_motion_widgets.dart';
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
  int _tabSlideDir = 1;
  int _initialFloodSeconds = 1;

  @override
  void initState() {
    super.initState();
    if (widget.floodWaitSeconds > 0) {
      _initialFloodSeconds = widget.floodWaitSeconds;
    }
  }

  @override
  void didUpdateWidget(covariant TransfersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.floodWaitSeconds > oldWidget.floodWaitSeconds &&
        widget.floodWaitSeconds > 0) {
      _initialFloodSeconds = widget.floodWaitSeconds;
    } else if (widget.floodWaitSeconds == 0) {
      _initialFloodSeconds = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.strings;
    final tasks = widget.tasks;
    final reduced = vaultMotion.isReduced(context);

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
          onChanged: (seg) {
            if (seg == _segment) return;
            setState(() {
              _tabSlideDir = seg.index > _segment.index ? 1 : -1;
              _segment = seg;
            });
          },
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

        AnimatedSize(
          duration: vaultMotion.duration(context, vaultMotion.fast),
          curve: vaultMotion.standard,
          child: widget.floodWaitSeconds > 0
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _FloodWaitDepletingChip(
                      palette: p,
                      label: s.floodWaitMessage(widget.floodWaitSeconds),
                      fraction: (widget.floodWaitSeconds /
                              math.max(1, _initialFloodSeconds))
                          .clamp(0.0, 1.0),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 18),

        AnimatedSwitcher(
          duration: vaultMotion.duration(context, vaultMotion.base),
          switchInCurve: vaultMotion.standard,
          switchOutCurve: vaultMotion.exit,
          transitionBuilder: (child, animation) {
            if (reduced) {
              return FadeTransition(opacity: animation, child: child);
            }
            final rtl = Directionality.of(context) == TextDirection.rtl;
            final dir = (rtl ? -1.0 : 1.0) * _tabSlideDir;
            final slide = Tween<Offset>(
              begin: Offset(0.04 * dir, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_segment),
            child: visibleTasks.isEmpty
                ? _TransfersEmptyCard(palette: p, strings: s)
                : Column(
                    children: [
                      for (var i = 0; i < visibleTasks.length; i++)
                        VaultStaggeredSlideFade(
                          key: ValueKey('tx_${visibleTasks[i].id}'),
                          index: i,
                          dy: -16,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TransferGlassCard(
                              palette: p,
                              strings: s,
                              task: visibleTasks[i],
                              fileName:
                                  widget.fileNamesById[visibleTasks[i].fileId] ??
                                      'File #${visibleTasks[i].fileId}',
                              totalBytes: widget
                                      .fileSizesById[visibleTasks[i].fileId] ??
                                  0,
                              chunkSizeMiB: widget.chunkSizeMiB,
                              onPause: widget.onPauseTask != null
                                  ? () {
                                      VaultHaptics.medium();
                                      widget.onPauseTask!(visibleTasks[i].id);
                                    }
                                  : null,
                              onResume: widget.onResumeTask != null
                                  ? () {
                                      VaultHaptics.medium();
                                      widget.onResumeTask!(visibleTasks[i]);
                                    }
                                  : null,
                              onRetry: widget.onRetryTask != null
                                  ? () {
                                      VaultHaptics.medium();
                                      widget.onRetryTask!(visibleTasks[i]);
                                    }
                                  : (widget.onResumeTask != null
                                      ? () {
                                          VaultHaptics.medium();
                                          widget.onResumeTask!(visibleTasks[i]);
                                        }
                                      : null),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _FloodWaitDepletingChip extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final double fraction;

  const _FloodWaitDepletingChip({
    required this.palette,
    required this.label,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.floodSoft,
        borderRadius: BorderRadius.circular(VaultRadii.pill),
        border: Border.all(color: p.floodAmber.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: fraction),
              duration: vaultMotion.duration(context, vaultMotion.base),
              builder: (context, val, _) => CircularProgressIndicator(
                value: val,
                strokeWidth: 1.5,
                backgroundColor: p.glassBorder,
                color: p.floodAmber,
              ),
            ),
          ),
          const SizedBox(width: 8),
          VaultRollingText(
            label,
            style: VaultText.monoText(
              p,
              label,
              size: 11,
              weight: FontWeight.w500,
              color: p.floodAmber,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransfersEmptyCard extends StatefulWidget {
  final AppPalette palette;
  final AppStrings strings;

  const _TransfersEmptyCard({required this.palette, required this.strings});

  @override
  State<_TransfersEmptyCard> createState() => _TransfersEmptyCardState();
}

class _TransfersEmptyCardState extends State<_TransfersEmptyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allow = vaultMotion.allowLoops(context);
    if (allow && !_running) {
      _running = true;
      _pulseCtrl.repeat(reverse: true);
    } else if (!allow && _running) {
      _running = false;
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.strings;
    return VaultSurface(
      palette: p,
      borderRadius: VaultRadii.card,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final sc = _running ? (1.0 + 0.08 * _pulseCtrl.value) : 1.0;
              return Transform.scale(scale: sc, child: child);
            },
            child: Icon(Icons.swap_vert_rounded, size: 34, color: p.secondary),
          ),
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
    );
  }
}

class _TransferGlassCard extends StatefulWidget {
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
  State<_TransferGlassCard> createState() => _TransferGlassCardState();
}

class _TransferGlassCardState extends State<_TransferGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pausePlayCtrl;
  int _failShakeCount = 0;

  @override
  void initState() {
    super.initState();
    _pausePlayCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.fast,
      value: widget.task.state == TaskState.paused ? 0.0 : 1.0,
    );
    if (widget.task.state == TaskState.failed) {
      _failShakeCount = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _TransferGlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.state != widget.task.state) {
      if (widget.task.state == TaskState.paused) {
        _pausePlayCtrl.reverse();
      } else {
        _pausePlayCtrl.forward();
      }
      if (widget.task.state == TaskState.failed) {
        _failShakeCount++;
        VaultHaptics.error();
      } else if (widget.task.state == TaskState.completed) {
        VaultHaptics.success();
      }
    }
  }

  @override
  void dispose() {
    _pausePlayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final task = widget.task;
    final strings = widget.strings;
    final progress = task.progress.clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    final tone = switch (task.state) {
      TaskState.running => VaultProgressTone.champagne,
      TaskState.queued || TaskState.paused => VaultProgressTone.slate,
      TaskState.completed => VaultProgressTone.signalGreen,
      TaskState.failed => VaultProgressTone.coral,
    };

    final chunkBytes = (widget.chunkSizeMiB * 1024 * 1024).clamp(1, 1 << 30);
    final totalChunks = widget.totalBytes <= 0
        ? 4
        : (widget.totalBytes / chunkBytes).ceil().clamp(2, 16);
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

    final bytesMeta = widget.totalBytes > 0
        ? '${formatBytes((widget.totalBytes * progress).round())} / ${formatBytes(widget.totalBytes)}'
        : stateText;

    return VaultHorizontalShake(
      triggerCount: _failShakeCount,
      amplitude: 4,
      cycles: 2,
      duration: const Duration(milliseconds: 200),
      child: VaultSurface(
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
                        widget.fileName,
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
                      Row(
                        children: [
                          VaultRollingText(
                            '$pct%',
                            style: VaultText.mono(
                              p,
                              size: 11,
                              weight: FontWeight.w600,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 120),
                              child: Text(
                                '· $bytesMeta',
                                key: ValueKey(bytesMeta),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VaultText.monoText(
                                  p,
                                  '· $bytesMeta',
                                  size: 11,
                                  color: p.secondary,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                    child: VaultAnimatedDrawCheck(
                      color: p.signalGreen,
                      size: 18,
                    ),
                  )
                else if (task.state == TaskState.failed &&
                    widget.onRetry != null)
                  VaultPillButton(
                    palette: p,
                    isArabic: strings.ar,
                    expand: false,
                    height: 36,
                    variant: VaultPillVariant.danger,
                    icon: Icons.refresh_rounded,
                    label: strings.retryAction,
                    onPressed: widget.onRetry,
                  )
                else if ((task.state == TaskState.running ||
                        task.state == TaskState.queued) &&
                    widget.onPause != null)
                  Tooltip(
                    message: strings.pauseAction,
                    child: VaultTap(
                      onTap: widget.onPause,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.glassElevatedFill,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedIcon(
                          icon: AnimatedIcons.play_pause,
                          progress: _pausePlayCtrl,
                          size: 18,
                          color: p.ink,
                        ),
                      ),
                    ),
                  )
                else if (task.state == TaskState.paused &&
                    widget.onResume != null)
                  Tooltip(
                    message: strings.resumeAction,
                    child: VaultTap(
                      onTap: widget.onResume,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.champagneSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.champagne),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedIcon(
                          icon: AnimatedIcons.play_pause,
                          progress: _pausePlayCtrl,
                          size: 19,
                          color: p.champagne,
                        ),
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
              showSweep: task.state == TaskState.running,
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
                    isActive: task.state == TaskState.running,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      ),
    );
  }
}

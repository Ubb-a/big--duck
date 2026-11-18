import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PathMetric;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Broadcasts horizontal specular highlight shift (0..12px) driven by vertical scroll offset.
class VaultScrollParallax extends InheritedNotifier<ValueNotifier<double>> {
  const VaultScrollParallax({
    super.key,
    required ValueNotifier<double> super.notifier,
    required super.child,
  });

  static double of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<VaultScrollParallax>();
    return widget?.notifier?.value ?? 0.0;
  }
}

/// Staggered entrance (opacity + upward translate). Collapses to 150ms fade under Reduce Motion.
class VaultStaggeredSlideFade extends StatefulWidget {
  final int index;
  final double dy;
  final Duration baseDelay;
  final Animation<double>? parentAnimation;
  final Widget child;

  const VaultStaggeredSlideFade({
    super.key,
    this.index = 0,
    this.dy = 12,
    this.baseDelay = Duration.zero,
    this.parentAnimation,
    required this.child,
  });

  @override
  State<VaultStaggeredSlideFade> createState() =>
      _VaultStaggeredSlideFadeState();
}

class _VaultStaggeredSlideFadeState extends State<VaultStaggeredSlideFade>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.parentAnimation == null) {
      final capped = widget.index.clamp(0, vaultMotion.maxStaggerItems);
      final totalMs =
          widget.baseDelay.inMilliseconds + (capped * 30) + 250;
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: totalMs.clamp(150, 900)),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl?.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = vaultMotion.isReduced(context);
    final anim = widget.parentAnimation ?? _ctrl!;
    final capped = widget.index.clamp(0, vaultMotion.maxStaggerItems);
    final delayMs = widget.baseDelay.inMilliseconds + (capped * 30);
    final totalMs = (_ctrl?.duration?.inMilliseconds ?? 560).clamp(250, 900);
    final start = reduced ? 0.0 : (delayMs / totalMs).clamp(0.0, 0.72);
    final end = reduced ? 1.0 : ((delayMs + 250) / totalMs).clamp(start + 0.1, 1.0);

    return AnimatedBuilder(
      animation: anim,
      child: widget.child,
      builder: (context, child) {
        final raw = anim.value;
        final t = Interval(
          start,
          end,
          curve: vaultMotion.standard,
        ).transform(raw.clamp(0.0, 1.0));
        final dy = reduced ? 0.0 : widget.dy * (1.0 - t);
        return Opacity(
          opacity: t,
          child: dy == 0.0
              ? child
              : Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}

/// Vertical rolling digit/text switcher (180ms standard, 150ms fade under Reduce Motion).
class VaultRollingText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const VaultRollingText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = vaultMotion.isReduced(context);
    final duration = vaultMotion.duration(context, vaultMotion.fast);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: vaultMotion.standard,
        switchOutCurve: vaultMotion.exit,
        transitionBuilder: (child, animation) {
          if (reduced) {
            return FadeTransition(opacity: animation, child: child);
          }
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.45),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

/// Self-drawing signal-green check path (250ms ease-out).
class VaultAnimatedDrawCheck extends StatefulWidget {
  final Color color;
  final double size;
  final double strokeWidth;

  const VaultAnimatedDrawCheck({
    super.key,
    required this.color,
    this.size = 18,
    this.strokeWidth = 2.0,
  });

  @override
  State<VaultAnimatedDrawCheck> createState() => _VaultAnimatedDrawCheckState();
}

class _VaultAnimatedDrawCheckState extends State<VaultAnimatedDrawCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: vaultMotion.base,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (vaultMotion.isReduced(context)) {
      return Icon(Icons.check_rounded, size: widget.size, color: widget.color);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = vaultMotion.standard.transform(_ctrl.value);
          return CustomPaint(
            painter: _DrawCheckPainter(
              progress: t,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _DrawCheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _DrawCheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.82, size.height * 0.28);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DrawCheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Animated semantic file/transfer status dot:
/// - Synced (green): single 400ms scale 1.0 -> 1.6 -> 1.0 pulse + ring fade when entering synced
/// - Active (champagne): 1.6s opacity 0.5 -> 1.0 breathing loop (gated by allowLoops)
/// - Paused/queued (slate): static
/// - Failed (coral): coral dot
class VaultStatusDotAnimated extends StatefulWidget {
  final Color color;
  final bool isBreathing;
  final bool isSynced;
  final double size;

  const VaultStatusDotAnimated({
    super.key,
    required this.color,
    this.isBreathing = false,
    this.isSynced = true,
    this.size = 7,
  });

  @override
  State<VaultStatusDotAnimated> createState() => _VaultStatusDotAnimatedState();
}

class _VaultStatusDotAnimatedState extends State<VaultStatusDotAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _runningLoop = false;
  bool _runningPulse = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState(justSynced: false);
  }

  @override
  void didUpdateWidget(covariant VaultStatusDotAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameSynced = !oldWidget.isSynced && widget.isSynced;
    if (becameSynced || oldWidget.isBreathing != widget.isBreathing) {
      _syncAnimationState(justSynced: becameSynced);
    }
  }

  void _syncAnimationState({required bool justSynced}) {
    final allowLoops = vaultMotion.allowLoops(context);
    final reduced = vaultMotion.isReduced(context);
    if (justSynced && !reduced) {
      _runningLoop = false;
      _runningPulse = true;
      _ctrl.duration = vaultMotion.slow;
      _ctrl.forward(from: 0).then((_) {
        if (mounted) {
          _runningPulse = false;
          _syncAnimationState(justSynced: false);
        }
      });
      return;
    }

    if (widget.isBreathing && allowLoops) {
      if (!_runningLoop) {
        _runningLoop = true;
        _runningPulse = false;
        _ctrl.duration = const Duration(milliseconds: 1600);
        _ctrl.repeat(reverse: true);
      }
    } else if (_runningLoop) {
      _runningLoop = false;
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (_runningPulse) {
          final v = _ctrl.value;
          final dotScale = 1.0 + math.sin(v * math.pi) * 0.6;
          final ringScale = 1.0 + v * 1.4;
          return SizedBox(
            width: widget.size * 2.2,
            height: widget.size * 2.2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: ringScale,
                  child: Opacity(
                    opacity: (1.0 - v).clamp(0.0, 1.0),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.color, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: dotScale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final opacity =
            _runningLoop ? (0.5 + 0.5 * _ctrl.value) : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Triggers a crisp damped horizontal shake whenever `triggerCount` increments.
class VaultHorizontalShake extends StatefulWidget {
  final int triggerCount;
  final double amplitude;
  final int cycles;
  final Duration duration;
  final Widget child;

  const VaultHorizontalShake({
    super.key,
    required this.triggerCount,
    this.amplitude = 6,
    this.cycles = 3,
    this.duration = const Duration(milliseconds: 300),
    required this.child,
  });

  @override
  State<VaultHorizontalShake> createState() => _VaultHorizontalShakeState();
}

class _VaultHorizontalShakeState extends State<VaultHorizontalShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant VaultHorizontalShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerCount > oldWidget.triggerCount &&
        !vaultMotion.isReduced(context)) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (vaultMotion.isReduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        if (!_ctrl.isAnimating) return child!;
        final dx = math.sin(_ctrl.value * math.pi * 2 * widget.cycles) *
            widget.amplitude *
            (1.0 - _ctrl.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

class VaultCircularRevealClipper extends CustomClipper<Path> {
  final Offset origin;
  final double fraction;

  const VaultCircularRevealClipper({
    required this.origin,
    required this.fraction,
  });

  @override
  Path getClip(Size size) {
    final maxRadius = math.sqrt(
      math.pow(math.max(origin.dx, size.width - origin.dx), 2) +
          math.pow(math.max(origin.dy, size.height - origin.dy), 2),
    );
    return Path()
      ..addOval(Rect.fromCircle(center: origin, radius: maxRadius * fraction));
  }

  @override
  bool shouldReclip(VaultCircularRevealClipper oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.origin != origin;
}

/// Modal bottom sheet helper using vaultMotion.slow emphasized curve (400ms in, 250ms exit).
Future<T?> showVaultBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    isScrollControlled: isScrollControlled,
    sheetAnimationStyle: AnimationStyle(
      duration: vaultMotion.duration(context, vaultMotion.slow),
      reverseDuration: vaultMotion.duration(context, vaultMotion.base),
      curve: vaultMotion.emphasized,
      reverseCurve: vaultMotion.exit,
    ),
    builder: builder,
  );
}

/// Centered liquid-glass dialog with scale 0.94 -> 1.0, fade, and background blur sigma 0 -> 16.
Future<T?> showVaultDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final reduced = vaultMotion.isReduced(context);
  final enterDuration = vaultMotion.duration(context, vaultMotion.base);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: enterDuration,
    pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final isReversing = animation.status == AnimationStatus.reverse;
      final curved = CurvedAnimation(
        parent: animation,
        curve: vaultMotion.emphasized,
        reverseCurve: vaultMotion.exit,
      );
      if (reduced) {
        return FadeTransition(opacity: curved, child: child);
      }
      final sigma = (curved.value * 16.0).clamp(0.0, 16.0);
      final scale = Tween<double>(
        begin: isReversing ? 0.96 : 0.94,
        end: 1.0,
      ).evaluate(curved);
      return Stack(
        fit: StackFit.expand,
        children: [
          if (sigma > 0.25)
            IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),
          FadeTransition(
            opacity: curved,
            child: Transform.scale(scale: scale, child: child),
          ),
        ],
      );
    },
  );
}

/// Thin-line Vault Door empty-state illustration supporting 1.2s stroke draw-on and periodic handle hint.
class VaultEmptyDoorIllustration extends StatefulWidget {
  final Color strokeColor;
  final Color mutedColor;

  const VaultEmptyDoorIllustration({
    super.key,
    required this.strokeColor,
    required this.mutedColor,
  });

  @override
  State<VaultEmptyDoorIllustration> createState() =>
      _VaultEmptyDoorIllustrationState();
}

class _VaultEmptyDoorIllustrationState
    extends State<VaultEmptyDoorIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drawCtrl;

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drawCtrl.forward();
    });
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = vaultMotion.isReduced(context);
    return SizedBox(
      width: 68,
      height: 68,
      child: AnimatedBuilder(
        animation: _drawCtrl,
        builder: (context, _) {
          final p = reduced ? 1.0 : vaultMotion.standard.transform(_drawCtrl.value);
          return CustomPaint(
            painter: _AnimatedVaultDoorPainter(
              progress: p,
              strokeColor: widget.strokeColor,
              mutedColor: widget.mutedColor,
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedVaultDoorPainter extends CustomPainter {
  final double progress;
  final Color strokeColor;
  final Color mutedColor;

  const _AnimatedVaultDoorPainter({
    required this.progress,
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

    final center = Offset(size.width / 2, size.height / 2);

    final doorPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
        const Radius.circular(14),
      ));
    final ringPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: size.width * 0.22));
    final hubPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: size.width * 0.11));

    for (final metric in doorPath.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * (progress * 1.35).clamp(0.0, 1.0)),
        pMain,
      );
    }

    final innerP = ((progress - 0.2) / 0.8).clamp(0.0, 1.0);
    if (innerP > 0) {
      for (final metric in ringPath.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * innerP), pSub);
      }
      for (final metric in hubPath.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * innerP), pMain);
      }
    }

    final spokeP = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (spokeP > 0) {
      for (final offset in const [
        Offset(0, -14),
        Offset(0, 14),
        Offset(-14, 0),
        Offset(14, 0),
      ]) {
        final start = center + offset * 0.55;
        final end = Offset.lerp(start, center + offset, spokeP)!;
        canvas.drawLine(start, end, pMain);
      }
    }
  }

  @override
  bool shouldRepaint(_AnimatedVaultDoorPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.mutedColor != mutedColor;
}

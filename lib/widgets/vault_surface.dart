import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'vault_motion_widgets.dart';

class _VaultPressScope extends InheritedWidget {
  final bool pressed;

  const _VaultPressScope({required this.pressed, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_VaultPressScope>()?.pressed ??
      false;

  @override
  bool updateShouldNotify(_VaultPressScope oldWidget) =>
      oldWidget.pressed != pressed;
}

/// Ambient obsidian graphite glow (Dark) or warm pearl gradient (Light)
/// giving liquid-glass cards subtle depth to refract without loud orbs.
class VaultCanvasBackdrop extends StatelessWidget {
  final AppPalette palette;
  final Widget child;

  const VaultCanvasBackdrop({
    super.key,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.canvas,
        gradient: palette.isDark
            ? RadialGradient(
                center: const Alignment(0.0, -0.35),
                radius: 1.05,
                colors: [
                  palette.radialGlow,
                  palette.canvas,
                ],
                stops: const [0.0, 0.85],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.radialGlow,
                  palette.canvas,
                  const Color(0xFFEEECE6),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
      ),
      child: child,
    );
  }
}

/// Frosted / Liquid-Glass architectural container reacting to press brightness and scroll specular parallax.
class VaultSurface extends StatelessWidget {
  final AppPalette palette;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool elevated;
  final bool glass;
  final double blurSigma;
  final Widget child;

  const VaultSurface({
    super.key,
    required this.palette,
    this.borderRadius = VaultRadii.card,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.elevated = false,
    this.glass = true,
    this.blurSigma = 28,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final pressed = _VaultPressScope.of(context);
    final parallaxShift = VaultScrollParallax.of(context);
    final fillColor = backgroundColor ??
        (elevated ? palette.glassElevatedFill : palette.glassFill);
    final effectiveFill = pressed
        ? Color.alphaBlend(
            (palette.isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.06),
            fillColor,
          )
        : fillColor;

    final baseBorder = borderColor ?? palette.glassBorder;
    final innerBorder = pressed && borderColor == null
        ? (palette.isDark
            ? const Color(0x38FFFFFF) // 0.12 -> 0.22 opacity on press
            : const Color(0x2E000000))
        : baseBorder;

    final parallaxNorm = ((parallaxShift / 12.0) * 1.4 - 0.7).clamp(-1.0, 1.0);

    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: radius,
        gradient: backgroundColor == null
            ? LinearGradient(
                begin: Alignment(parallaxNorm, -1.0),
                end: Alignment(-parallaxNorm, 1.0),
                colors: palette.isDark
                    ? [
                        Color.alphaBlend(
                          Color.fromRGBO(255, 255, 255, pressed ? 0.16 : 0.10),
                          effectiveFill,
                        ),
                        effectiveFill,
                        Color.alphaBlend(
                          const Color(0x14050506),
                          effectiveFill,
                        ),
                      ]
                    : [
                        Color.alphaBlend(
                          Color.fromRGBO(255, 255, 255, pressed ? 0.34 : 0.25),
                          effectiveFill,
                        ),
                        effectiveFill,
                      ],
              )
            : null,
        border: Border.all(color: innerBorder, width: 1.0),
      ),
      child: child,
    );

    final content = ClipRRect(
      borderRadius: radius,
      child: glass
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: decorated,
            )
          : decorated,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(
              alpha: elevated
                  ? (palette.isDark ? 0.50 : 0.09)
                  : (palette.isDark ? 0.32 : 0.06),
            ),
            blurRadius: elevated ? (palette.isDark ? 48 : 36) : 28,
            offset: Offset(0, elevated ? 24 : 12),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// Stacked-glass wrapper giving Folders a subtle layered vault card depth.
class VaultStackedGlassCard extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  final double borderRadius;

  const VaultStackedGlassCard({
    super.key,
    required this.palette,
    required this.child,
    this.borderRadius = VaultRadii.md,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 10,
          right: 10,
          top: -5,
          height: 16,
          child: Container(
            decoration: BoxDecoration(
              color: palette.isDark
                  ? const Color(0x1C787C87)
                  : const Color(0x88FFFFFF),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: palette.glassBorder, width: 1),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Press interaction: 90ms scale to 0.97 + +6% glass brightness, 180ms standard release.
class VaultTap extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const VaultTap({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.child,
  });

  @override
  State<VaultTap> createState() => _VaultTapState();
}

class _VaultTapState extends State<VaultTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduced = vaultMotion.isReduced(context);
    final duration = _pressed
        ? vaultMotion.duration(context, vaultMotion.instant)
        : vaultMotion.duration(context, vaultMotion.fast);
    final curve = vaultMotion.standard;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (widget.onTap != null || widget.onLongPress != null) {
          setState(() => _pressed = true);
        }
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: _VaultPressScope(
        pressed: _pressed,
        child: reduced
            ? AnimatedOpacity(
                opacity: _pressed ? 0.78 : 1.0,
                duration: vaultMotion.reducedFade,
                child: widget.child,
              )
            : AnimatedScale(
                scale: _pressed ? 0.97 : 1.0,
                duration: duration,
                curve: curve,
                child: AnimatedOpacity(
                  opacity: _pressed ? 0.92 : 1.0,
                  duration: duration,
                  curve: curve,
                  child: widget.child,
                ),
              ),
      ),
    );
  }
}

enum VaultPillVariant { primary, secondary, inverted, outlined, danger }

/// Style-board pill CTA (`999` radius) with press dim (8%), 180ms loading ring swap, and optional green check.
class VaultPillButton extends StatefulWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VaultPillVariant variant;
  final bool loading;
  final bool completed;
  final bool expand;
  final double height;

  const VaultPillButton({
    super.key,
    required this.palette,
    required this.isArabic,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = VaultPillVariant.primary,
    this.loading = false,
    this.completed = false,
    this.expand = true,
    this.height = 50,
  });

  @override
  State<VaultPillButton> createState() => _VaultPillButtonState();
}

class _VaultPillButtonState extends State<VaultPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final reduced = vaultMotion.isReduced(context);
    final enabled =
        widget.onPressed != null && !widget.loading && !widget.completed;

    Color bg;
    final Color fg;
    final Color bd;

    switch (widget.variant) {
      case VaultPillVariant.primary:
        bg = _pressed
            ? Color.lerp(p.primaryBtnFill, Colors.black, 0.08)!
            : p.primaryBtnFill;
        fg = p.primaryBtnInk;
        bd = p.primaryBtnFill;
      case VaultPillVariant.secondary:
        bg = _pressed
            ? Color.alphaBlend(const Color(0x0FFFFFFF), p.glassFill)
            : p.glassFill;
        fg = p.ink;
        bd = _pressed ? p.glassTopLeftBorder : p.glassBorder;
      case VaultPillVariant.inverted:
        bg = _pressed
            ? Color.lerp(p.invertedBtnFill, Colors.black, 0.08)!
            : p.invertedBtnFill;
        fg = p.invertedBtnInk;
        bd = p.invertedBtnFill;
      case VaultPillVariant.outlined:
        bg = Colors.transparent;
        fg = p.champagne;
        bd = p.champagne;
      case VaultPillVariant.danger:
        bg = p.coralSoft;
        fg = p.coral;
        bd = p.coral.withValues(alpha: 0.4);
    }

    final textStyle = widget.variant == VaultPillVariant.outlined
        ? VaultText.monoText(
            p,
            widget.label,
            size: 12,
            weight: FontWeight.w600,
            color: enabled ? fg : fg.withValues(alpha: 0.45),
          )
        : VaultText.body(
            p,
            widget.isArabic,
            size: 14.5,
            weight: FontWeight.w600,
            color: enabled ? fg : fg.withValues(alpha: 0.45),
            applyArabicScale: false,
          );

    final duration = _pressed
        ? vaultMotion.duration(context, vaultMotion.instant)
        : vaultMotion.duration(context, vaultMotion.fast);

    final Widget stateContent;
    if (widget.completed) {
      stateContent = VaultAnimatedDrawCheck(
        key: const ValueKey('btn_done'),
        color: p.signalGreen,
        size: 20,
        strokeWidth: 2.2,
      );
    } else if (widget.loading) {
      stateContent = SizedBox(
        key: const ValueKey('btn_loading'),
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: widget.variant == VaultPillVariant.primary
              ? p.primaryBtnInk
              : p.champagne,
        ),
      );
    } else {
      stateContent = Row(
        key: ValueKey('btn_label_${widget.label}'),
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon,
                size: 18,
                color: enabled ? fg : fg.withValues(alpha: 0.45)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (enabled) setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: enabled
          ? () {
              VaultHaptics.selection();
              widget.onPressed?.call();
            }
          : null,
      child: AnimatedScale(
        scale: (reduced || !_pressed) ? 1.0 : 0.97,
        duration: duration,
        curve: vaultMotion.standard,
        child: AnimatedContainer(
          duration: duration,
          curve: vaultMotion.standard,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: (enabled || widget.loading || widget.completed)
                ? bg
                : bg.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(VaultRadii.pill),
            border: Border.all(
              color: (enabled || widget.loading || widget.completed)
                  ? bd
                  : bd.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: vaultMotion.duration(context, vaultMotion.fast),
            switchInCurve: vaultMotion.standard,
            switchOutCurve: vaultMotion.exit,
            child: stateContent,
          ),
        ),
      ),
    );
  }
}

/// Input wrapper providing animated 1px slate -> 1.5px champagne focus ring + 12px blur glow (20% opacity).
class VaultGlassInputContainer extends StatefulWidget {
  final AppPalette palette;
  final double borderRadius;
  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  const VaultGlassInputContainer({
    super.key,
    required this.palette,
    this.borderRadius = VaultRadii.tile,
    required this.builder,
  });

  @override
  State<VaultGlassInputContainer> createState() =>
      _VaultGlassInputContainerState();
}

class _VaultGlassInputContainerState extends State<VaultGlassInputContainer> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final duration = vaultMotion.duration(context, vaultMotion.fast);
    return AnimatedContainer(
      duration: duration,
      curve: vaultMotion.standard,
      decoration: BoxDecoration(
        color: p.glassFill,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: _focused ? p.champagne : p.glassBorder,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: p.champagne.withValues(alpha: _focused ? 0.20 : 0.0),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: widget.builder(context, _focusNode),
    );
  }
}

/// Primary confirm/edit square icon button (`14px` tile radius, signal green).
class VaultConfirmSquareButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final double size;

  const VaultConfirmSquareButton({
    super.key,
    required this.palette,
    this.icon = Icons.check_rounded,
    this.tooltip,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final btn = VaultTap(
      onTap: onTap != null
          ? () {
              VaultHaptics.medium();
              onTap?.call();
            }
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.signalGreen,
          borderRadius: BorderRadius.circular(VaultRadii.tile),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: palette.signalGreenInk),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

enum VaultQuickTone { champagne, slate, mint, coral }

/// Small circular colored action button from the component sheet.
class VaultQuickActionCircle extends StatelessWidget {
  final AppPalette palette;
  final VaultQuickTone tone;
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final double size;

  const VaultQuickActionCircle({
    super.key,
    required this.palette,
    required this.tone,
    required this.icon,
    this.tooltip,
    required this.onTap,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final (bg, fg, bd) = switch (tone) {
      VaultQuickTone.champagne => (
          p.champagneSoft,
          p.champagne,
          p.champagne.withValues(alpha: 0.45),
        ),
      VaultQuickTone.slate => (
          p.glassFill,
          p.secondary,
          p.glassBorder,
        ),
      VaultQuickTone.mint => (
          p.signalGreenSoft,
          p.signalGreen,
          p.signalGreen.withValues(alpha: 0.45),
        ),
      VaultQuickTone.coral => (
          p.coralSoft,
          p.coral,
          p.coral.withValues(alpha: 0.45),
        ),
    };

    final circle = VaultTap(
      onTap: onTap != null
          ? () {
              VaultHaptics.selection();
              onTap?.call();
            }
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: bd, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: fg),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: circle) : circle;
  }
}

/// Liquid-glass search field with animated champagne focus ring, magnifier, and IBM Plex Mono placeholder.
class VaultGlassSearchField extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChange;
  final Widget? trailingAction;

  const VaultGlassSearchField({
    super.key,
    required this.palette,
    required this.isArabic,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onFocusChange,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Focus(
      onFocusChange: onFocusChange,
      child: VaultGlassInputContainer(
        palette: p,
        borderRadius: VaultRadii.md,
        builder: (context, internalFocus) {
          final activeNode = focusNode ?? internalFocus;
          return ClipRRect(
            borderRadius: BorderRadius.circular(VaultRadii.md),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 8, 2),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: p.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        focusNode: activeNode,
                        controller: controller,
                        onChanged: onChanged,
                        style: VaultText.body(p, isArabic,
                            size: 14, applyArabicScale: false),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: VaultText.monoText(
                            p,
                            hintText,
                            size: 12,
                            color: p.secondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    if (controller.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          controller.clear();
                          onChanged?.call('');
                        },
                        icon: Icon(Icons.close_rounded,
                            size: 17, color: p.secondary),
                        visualDensity: VisualDensity.compact,
                        tooltip: isArabic ? 'مسح' : 'Clear',
                      ),
                    ?trailingAction,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum VaultProgressTone { champagne, slate, signalGreen, coral }

/// Smoothly interpolating RTL-aware progress track (250ms glide, optional 1.8s linear sweep when active).
class VaultProgressBar extends StatefulWidget {
  final AppPalette palette;
  final double progress;
  final VaultProgressTone tone;
  final double height;
  final bool showSweep;

  const VaultProgressBar({
    super.key,
    required this.palette,
    required this.progress,
    this.tone = VaultProgressTone.champagne,
    this.height = 4,
    this.showSweep = false,
  });

  @override
  State<VaultProgressBar> createState() => _VaultProgressBarState();
}

class _VaultProgressBarState extends State<VaultProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  bool _sweeping = false;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(covariant VaultProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSweep != widget.showSweep) {
      _syncSweep();
    }
  }

  void _syncSweep() {
    final shouldSweep = widget.showSweep && vaultMotion.allowLoops(context);
    if (shouldSweep && !_sweeping) {
      _sweeping = true;
      _sweepCtrl.repeat();
    } else if (!shouldSweep && _sweeping) {
      _sweeping = false;
      _sweepCtrl.stop();
    }
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final clamped = widget.progress.clamp(0.0, 1.0);
    final fillColor = switch (widget.tone) {
      VaultProgressTone.champagne => p.champagne,
      VaultProgressTone.slate => p.secondary,
      VaultProgressTone.signalGreen => p.signalGreen,
      VaultProgressTone.coral => p.coral,
    };

    final duration = vaultMotion.duration(context, vaultMotion.base);

    return ClipRRect(
      borderRadius: BorderRadius.circular(VaultRadii.pill),
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: p.glassBorder,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: clamped),
          duration: duration,
          curve: vaultMotion.standard,
          builder: (context, animValue, _) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: animValue <= 0 ? 0.02 : animValue,
                heightFactor: 1.0,
                child: AnimatedContainer(
                  duration: vaultMotion.duration(context, vaultMotion.fast),
                  curve: vaultMotion.standard,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(VaultRadii.pill),
                  ),
                  child: _sweeping
                      ? AnimatedBuilder(
                          animation: _sweepCtrl,
                          builder: (context, _) {
                            final rtl =
                                Directionality.of(context) == TextDirection.rtl;
                            final pos = rtl
                                ? (1.0 - _sweepCtrl.value) * 2.4 - 1.2
                                : _sweepCtrl.value * 2.4 - 1.2;
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(pos - 0.5, 0),
                                  end: Alignment(pos + 0.5, 0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.42),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Segmented chunk tape with 1.2s breathing active chunk and 180ms green flip on completion.
class VaultChunkTape extends StatefulWidget {
  final AppPalette palette;
  final int totalChunks;
  final int completedChunks;
  final VaultProgressTone activeTone;
  final bool isActive;
  final double height;

  const VaultChunkTape({
    super.key,
    required this.palette,
    required this.totalChunks,
    required this.completedChunks,
    this.activeTone = VaultProgressTone.champagne,
    this.isActive = false,
    this.height = 3.5,
  });

  @override
  State<VaultChunkTape> createState() => _VaultChunkTapeState();
}

class _VaultChunkTapeState extends State<VaultChunkTape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheCtrl;
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant VaultChunkTape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncLoop();
    }
  }

  void _syncLoop() {
    final should = widget.isActive && vaultMotion.allowLoops(context);
    if (should && !_looping) {
      _looping = true;
      _breatheCtrl.repeat(reverse: true);
    } else if (!should && _looping) {
      _looping = false;
      _breatheCtrl.stop();
    }
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final count = widget.totalChunks.clamp(1, 24);
    final done = widget.completedChunks.clamp(0, count);
    final activeColor = switch (widget.activeTone) {
      VaultProgressTone.champagne => p.champagne,
      VaultProgressTone.slate => p.secondary,
      VaultProgressTone.signalGreen => p.signalGreen,
      VaultProgressTone.coral => p.coral,
    };

    return Row(
      children: List.generate(count, (idx) {
        final filled = idx < done;
        final isActiveChunk = idx == done && done < count;
        final color = filled
            ? p.signalGreen
            : (isActiveChunk ? activeColor : p.glassBorder);

        Widget bar = AnimatedContainer(
          duration: vaultMotion.duration(context, vaultMotion.fast),
          curve: vaultMotion.standard,
          height: widget.height,
          margin: EdgeInsetsDirectional.only(end: idx == count - 1 ? 0 : 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(VaultRadii.pill),
          ),
        );

        if (isActiveChunk && _looping) {
          bar = AnimatedBuilder(
            animation: _breatheCtrl,
            child: bar,
            builder: (context, child) => Opacity(
              opacity: 0.4 + 0.6 * _breatheCtrl.value,
              child: child,
            ),
          );
        } else if (isActiveChunk && !filled) {
          bar = Opacity(opacity: 0.65, child: bar);
        }

        return Expanded(child: bar);
      }),
    );
  }
}

/// Glass toggle switch: 180ms standard slide + champagne fill + 1.0 -> 1.06 -> 1.0 knob scale pulse.
class VaultToggle extends StatefulWidget {
  final AppPalette palette;
  final bool value;
  final ValueChanged<bool> onChanged;

  const VaultToggle({
    super.key,
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  @override
  State<VaultToggle> createState() => _VaultToggleState();
}

class _VaultToggleState extends State<VaultToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.fast,
    );
  }

  @override
  void didUpdateWidget(covariant VaultToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !vaultMotion.isReduced(context)) {
      _pulseCtrl.forward(from: 0.0);
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
    final motion = vaultMotion.duration(context, vaultMotion.fast);
    final reduced = vaultMotion.isReduced(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        VaultHaptics.light();
        widget.onChanged(!widget.value);
      },
      child: AnimatedContainer(
        duration: motion,
        curve: vaultMotion.standard,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: widget.value ? p.champagneSoft : p.glassFill,
          borderRadius: BorderRadius.circular(VaultRadii.pill),
          border: Border.all(
            color: widget.value ? p.champagne : p.glassBorder,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: motion,
          curve: vaultMotion.standard,
          alignment: widget.value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final s = reduced
                  ? 1.0
                  : 1.0 +
                      0.06 *
                          (1.0 - (2.0 * _pulseCtrl.value - 1.0).abs())
                              .clamp(0.0, 1.0);
              return Transform.scale(scale: s, child: child);
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.value ? p.champagne : p.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small glass pill with IBM Plex Mono text, optional status dot, and 180ms pop-in entrance.
class VaultMonoChip extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final Color? dotColor;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const VaultMonoChip({
    super.key,
    required this.palette,
    required this.label,
    this.dotColor,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final chip = AnimatedContainer(
      duration: vaultMotion.duration(context, vaultMotion.fast),
      curve: vaultMotion.standard,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? p.glassFill,
        borderRadius: BorderRadius.circular(VaultRadii.pill),
        border: Border.all(color: borderColor ?? p.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: textColor ?? p.secondary),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VaultText.monoText(
                p,
                label,
                size: 11,
                weight: FontWeight.w500,
                color: textColor ?? p.secondary,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return VaultTap(onTap: onTap, child: chip);
  }
}

class VaultSegmentOption<T> {
  final T value;
  final String label;

  const VaultSegmentOption({required this.value, required this.label});
}

/// Liquid-glass segmented control with sliding capsule (250ms emphasized, RTL-mirrored) + 180ms label cross-fade.
class VaultSegmentedControl<T> extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final List<VaultSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool mono;

  const VaultSegmentedControl({
    super.key,
    required this.palette,
    required this.isArabic,
    required this.options,
    required this.value,
    required this.onChanged,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final count = options.length.clamp(1, 8);
    final selectedIdx =
        options.indexWhere((o) => o.value == value).clamp(0, count - 1);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final capsuleDur = vaultMotion.duration(context, vaultMotion.base);
    final textDur = vaultMotion.duration(context, vaultMotion.fast);

    return VaultSurface(
      palette: p,
      borderRadius: VaultRadii.pill,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / count;
          final visualIdx = rtl ? (count - 1 - selectedIdx) : selectedIdx;
          return SizedBox(
            height: 36,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: capsuleDur,
                  curve: vaultMotion.emphasized,
                  left: visualIdx * segW,
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.glassElevatedFill,
                      borderRadius: BorderRadius.circular(VaultRadii.pill),
                      border: Border.all(
                        color: p.champagne.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: options.map((opt) {
                    final active = opt.value == value;
                    final style = mono
                        ? VaultText.monoText(
                            p,
                            opt.label,
                            size: 11,
                            weight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? p.champagne : p.secondary,
                          )
                        : VaultText.body(
                            p,
                            isArabic,
                            size: 12.5,
                            weight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active
                                ? (p.isDark ? p.champagne : p.ink)
                                : p.secondary,
                            applyArabicScale: false,
                          );
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          VaultHaptics.selection();
                          onChanged(opt.value);
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: AnimatedDefaultTextStyle(
                              duration: textDur,
                              curve: vaultMotion.standard,
                              style: style,
                              child: Text(
                                opt.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 32px radius liquid-glass bottom sheet container.
class VaultSheetShell extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  final EdgeInsetsGeometry? outerPadding;

  const VaultSheetShell({
    super.key,
    required this.palette,
    required this.child,
    this.outerPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: outerPadding ?? const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: VaultSurface(
        palette: palette,
        borderRadius: VaultRadii.sheet,
        elevated: true,
        backgroundColor: palette.isDark
            ? const Color(0xCC1A1A1C)
            : const Color(0xEBF7F6F3),
        borderColor: palette.glassTopLeftBorder,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.secondary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(VaultRadii.pill),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Centered liquid-glass modal dialog (`26px` radius).
class VaultDialogShell extends StatelessWidget {
  final AppPalette palette;
  final Widget child;

  const VaultDialogShell({
    super.key,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: VaultSurface(
          palette: palette,
          borderRadius: VaultRadii.card,
          elevated: true,
          backgroundColor: palette.isDark
              ? const Color(0xDE1A1A1C)
              : const Color(0xF5FFFFFF),
          borderColor: palette.glassTopLeftBorder,
          padding: const EdgeInsets.all(22),
          child: child,
        ),
      ),
    );
  }
}

/// Small-caps IBM Plex Mono section label.
class VaultSectionHeader extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String title;
  final Widget? trailing;

  const VaultSectionHeader({
    super.key,
    required this.palette,
    required this.isArabic,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = isArabic ? title : title.toUpperCase();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              formatted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VaultText.monoText(
                palette,
                formatted,
                size: 11.5,
                weight: FontWeight.w500,
                color: palette.secondary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Compact inline dot + mono label indicator for live Telegram sync status.
class VaultStatusDot extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final Color dotColor;
  final String label;
  final VoidCallback? onTap;

  const VaultStatusDot({
    super.key,
    required this.palette,
    required this.isArabic,
    required this.dotColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VaultStatusDotAnimated(
          color: dotColor,
          isSynced: dotColor == palette.signalGreen,
          isBreathing: dotColor == palette.champagne,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VaultText.monoText(
              palette,
              label,
              size: 11.5,
              weight: FontWeight.w500,
              color: onTap != null ? palette.champagne : palette.secondary,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

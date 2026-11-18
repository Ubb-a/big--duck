import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

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

/// Frosted / Liquid-Glass architectural container.
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
    final fillColor = backgroundColor ??
        (elevated ? palette.glassElevatedFill : palette.glassFill);
    final innerBorder = borderColor ?? palette.glassBorder;

    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: radius,
        gradient: backgroundColor == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.isDark
                    ? [
                        Color.alphaBlend(
                          const Color(0x18FFFFFF),
                          fillColor,
                        ),
                        fillColor,
                        Color.alphaBlend(
                          const Color(0x14050506),
                          fillColor,
                        ),
                      ]
                    : [
                        Color.alphaBlend(
                          const Color(0x40FFFFFF),
                          fillColor,
                        ),
                        fillColor,
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

    if (!elevated) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor.withValues(
                alpha: palette.isDark ? 0.34 : 0.06,
              ),
              blurRadius: palette.isDark ? 32 : 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: palette.isDark ? 48 : 36,
            offset: const Offset(0, 24),
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

/// Tactile press feedback respecting reduced motion.
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
    final duration = vaultMotion(context, 120);
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
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: duration,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.84 : 1.0,
          duration: duration,
          child: widget.child,
        ),
      ),
    );
  }
}

enum VaultPillVariant { primary, secondary, inverted, outlined, danger }

/// Style-board pill CTA (`999` radius) with default, pressed, disabled, and loading states.
class VaultPillButton extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VaultPillVariant variant;
  final bool loading;
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
    this.expand = true,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final enabled = onPressed != null && !loading;

    final Color bg;
    final Color fg;
    final Color bd;

    switch (variant) {
      case VaultPillVariant.primary:
        bg = p.primaryBtnFill;
        fg = p.primaryBtnInk;
        bd = p.primaryBtnFill;
      case VaultPillVariant.secondary:
        bg = p.glassFill;
        fg = p.ink;
        bd = p.glassBorder;
      case VaultPillVariant.inverted:
        bg = p.invertedBtnFill;
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

    final textStyle = variant == VaultPillVariant.outlined
        ? VaultText.monoText(
            p,
            label,
            size: 12,
            weight: FontWeight.w600,
            color: enabled ? fg : fg.withValues(alpha: 0.45),
          )
        : VaultText.body(
            p,
            isArabic,
            size: 14.5,
            weight: FontWeight.w600,
            color: enabled ? fg : fg.withValues(alpha: 0.45),
            applyArabicScale: false,
          );

    final inner = AnimatedContainer(
      duration: vaultMotion(context, 250),
      curve: Curves.easeOut,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: enabled ? bg : bg.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(VaultRadii.pill),
        border: Border.all(
          color: enabled ? bd : bd.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            ),
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: enabled ? fg : fg.withValues(alpha: 0.45)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );

    return VaultTap(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed?.call();
            }
          : null,
      child: inner,
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
              HapticFeedback.mediumImpact();
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
              HapticFeedback.selectionClick();
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

/// Liquid-glass search field with magnifier and IBM Plex Mono placeholder.
class VaultGlassSearchField extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Widget? trailingAction;

  const VaultGlassSearchField({
    super.key,
    required this.palette,
    required this.isArabic,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return VaultSurface(
      palette: p,
      borderRadius: VaultRadii.md,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 8, 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: p.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: VaultText.body(p, isArabic, size: 14, applyArabicScale: false),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              icon: Icon(Icons.close_rounded, size: 17, color: p.secondary),
              visualDensity: VisualDensity.compact,
              tooltip: isArabic ? 'مسح' : 'Clear',
            ),
          ?trailingAction,
        ],
      ),
    );
  }
}

enum VaultProgressTone { champagne, slate, signalGreen, coral }

/// Thin RTL-aware progress track (`champagne` in progress, `slate` queued/paused, `signalGreen` complete).
class VaultProgressBar extends StatelessWidget {
  final AppPalette palette;
  final double progress;
  final VaultProgressTone tone;
  final double height;

  const VaultProgressBar({
    super.key,
    required this.palette,
    required this.progress,
    this.tone = VaultProgressTone.champagne,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final clamped = progress.clamp(0.0, 1.0);
    final fillColor = switch (tone) {
      VaultProgressTone.champagne => p.champagne,
      VaultProgressTone.slate => p.secondary,
      VaultProgressTone.signalGreen => p.signalGreen,
      VaultProgressTone.coral => p.coral,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(VaultRadii.pill),
      child: Container(
        height: height,
        width: double.infinity,
        color: p.glassBorder,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: clamped <= 0 ? 0.02 : clamped,
            heightFactor: 1.0,
            child: AnimatedContainer(
              duration: vaultMotion(context, 250),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(VaultRadii.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented chunk progress tape showing current encrypted chunk index.
class VaultChunkTape extends StatelessWidget {
  final AppPalette palette;
  final int totalChunks;
  final int completedChunks;
  final VaultProgressTone activeTone;
  final double height;

  const VaultChunkTape({
    super.key,
    required this.palette,
    required this.totalChunks,
    required this.completedChunks,
    this.activeTone = VaultProgressTone.champagne,
    this.height = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final count = totalChunks.clamp(1, 24);
    final done = completedChunks.clamp(0, count);
    final activeColor = switch (activeTone) {
      VaultProgressTone.champagne => p.champagne,
      VaultProgressTone.slate => p.secondary,
      VaultProgressTone.signalGreen => p.signalGreen,
      VaultProgressTone.coral => p.coral,
    };

    return Row(
      children: List.generate(count, (idx) {
        final filled = idx < done;
        final isActive = idx == done && done < count;
        final color = filled
            ? (activeTone == VaultProgressTone.signalGreen
                ? p.signalGreen
                : p.champagne)
            : (isActive ? activeColor.withValues(alpha: 0.45) : p.glassBorder);
        return Expanded(
          child: AnimatedContainer(
            duration: vaultMotion(context, 250),
            curve: Curves.easeOut,
            height: height,
            margin: EdgeInsetsDirectional.only(end: idx == count - 1 ? 0 : 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(VaultRadii.pill),
            ),
          ),
        );
      }),
    );
  }
}

/// Glass toggle switch with champagne knob when on.
class VaultToggle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = palette;
    final motion = vaultMotion(context, 250);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: motion,
        curve: Curves.easeOut,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? p.champagneSoft : p.glassFill,
          borderRadius: BorderRadius.circular(VaultRadii.pill),
          border: Border.all(
            color: value ? p.champagne : p.glassBorder,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: motion,
          curve: Curves.easeOut,
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? p.champagne : p.secondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small glass pill with IBM Plex Mono text and optional status dot.
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
    final chip = Container(
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

/// Liquid-glass segmented control with brighter capsule active indicator.
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
    final motion = vaultMotion(context, 250);
    return VaultSurface(
      palette: p,
      borderRadius: VaultRadii.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((opt) {
          final active = opt.value == value;
          return Expanded(
            child: VaultTap(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(opt.value);
              },
              child: AnimatedContainer(
                duration: motion,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: BoxDecoration(
                  color: active ? p.glassElevatedFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(VaultRadii.pill),
                  border: active
                      ? Border.all(
                          color: p.champagne.withValues(alpha: 0.35),
                          width: 1,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono
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
                        ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
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
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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

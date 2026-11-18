import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';

/// Matte architectural container defined by a 1px hairline border.
/// Elevation is reserved strictly for floating chrome (dock, toast, sheets).
class VaultSurface extends StatelessWidget {
  final AppPalette palette;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool elevated;
  final Widget child;

  const VaultSurface({
    super.key,
    required this.palette,
    this.borderRadius = VaultRadii.md,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.elevated = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? palette.surface,
          borderRadius: radius,
          border: Border.all(
            color: borderColor ?? palette.rule,
            width: 1.0,
          ),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: palette.isDark ? 0.42 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// Crisp tactile press feedback with no bounce easing and full reduced-motion support.
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
    final duration = vaultMotion(context, 90);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: duration,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: duration,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Consistent sheet header with drag handle and flush-aligned title.
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
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: palette.rule,
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

/// Typographic section opener separating unified ledgers by whitespace rather than stacked cards.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VaultText.heading(palette, isArabic, size: 15),
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

/// Compact inline dot + label indicator for live Telegram connection / sync state.
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
            style: VaultText.body(
              palette,
              isArabic,
              size: 12,
              weight: FontWeight.w500,
              color: onTap != null ? palette.cobalt : palette.muted,
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

/// Signature 3px/6px proportional manifest tape visualizing encrypted vault composition.
class VaultProportionalTape extends StatelessWidget {
  final AppPalette palette;
  final int imageBytes;
  final int pdfBytes;
  final int videoAudioBytes;
  final int otherBytes;
  final double height;
  final double borderRadius;

  const VaultProportionalTape({
    super.key,
    required this.palette,
    required this.imageBytes,
    required this.pdfBytes,
    required this.videoAudioBytes,
    required this.otherBytes,
    this.height = 3,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final total = imageBytes + pdfBytes + videoAudioBytes + otherBytes;
    final bar = SizedBox(
      height: height,
      child: total <= 0
          ? Container(color: palette.rule)
          : Row(
              children: [
                if (imageBytes > 0)
                  Expanded(
                    flex: imageBytes,
                    child: Container(color: palette.signal),
                  ),
                if (pdfBytes > 0)
                  Expanded(
                    flex: pdfBytes,
                    child: Container(color: palette.danger),
                  ),
                if (videoAudioBytes > 0)
                  Expanded(
                    flex: videoAudioBytes,
                    child: Container(color: palette.cobalt),
                  ),
                if (otherBytes > 0)
                  Expanded(
                    flex: otherBytes,
                    child: Container(color: palette.ink),
                  ),
              ],
            ),
    );
    if (borderRadius <= 0) return bar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: bar,
    );
  }
}

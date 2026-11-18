import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'vault_motion_widgets.dart';
import 'vault_surface.dart';

class FloatingTabBar extends StatelessWidget {
  final AppPalette palette;
  final AppStrings strings;
  final MobileTab activeTab;
  final int activeTransferCount;
  final bool dimmed;
  final ValueChanged<MobileTab> onSelect;

  const FloatingTabBar({
    super.key,
    required this.palette,
    required this.strings,
    required this.activeTab,
    required this.activeTransferCount,
    this.dimmed = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final items = [
      (
        tab: MobileTab.files,
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
        label: strings.tabFiles,
        badge: 0,
      ),
      (
        tab: MobileTab.transfers,
        icon: Icons.swap_vert_rounded,
        activeIcon: Icons.swap_vert_rounded,
        label: strings.tabTransfers,
        badge: activeTransferCount,
      ),
      (
        tab: MobileTab.recent,
        icon: Icons.schedule_rounded,
        activeIcon: Icons.schedule_rounded,
        label: strings.tabRecent,
        badge: 0,
      ),
      (
        tab: MobileTab.settings,
        icon: Icons.tune_rounded,
        activeIcon: Icons.tune_rounded,
        label: strings.tabSettings,
        badge: 0,
      ),
    ];

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final activeIdx = activeTab.index.clamp(0, 3);
    final visualIdx = rtl ? (3 - activeIdx) : activeIdx;
    final slideDur = vaultMotion.duration(context, vaultMotion.base);
    final iconDur = vaultMotion.duration(context, vaultMotion.fast);

    return RepaintBoundary(
      child: AnimatedOpacity(
        duration: iconDur,
        curve: vaultMotion.standard,
        opacity: dimmed ? 0.55 : 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: VaultSurface(
                palette: p,
                borderRadius: VaultRadii.pill,
                elevated: true,
                borderColor: p.glassTopLeftBorder,
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slotWidth = constraints.maxWidth / 4;
                    final capsuleLeft =
                        (visualIdx * slotWidth) + ((slotWidth - 48) / 2);

                    return SizedBox(
                      height: 50,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Sliding active champagne/graphite circular capsule (250ms emphasized, RTL-mirrored)
                          AnimatedPositioned(
                            duration: slideDur,
                            curve: vaultMotion.emphasized,
                            left: capsuleLeft,
                            top: 1,
                            width: 48,
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                color: p.primaryBtnFill,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (final item in items)
                                Expanded(
                                  child: _NavCircleButton(
                                    key: ValueKey('nav_${item.tab.name}'),
                                    palette: p,
                                    icon: item.tab == activeTab
                                        ? item.activeIcon
                                        : item.icon,
                                    label: item.label,
                                    selected: item.tab == activeTab,
                                    badgeCount: item.badge,
                                    onTap: () {
                                      VaultHaptics.light();
                                      onSelect(item.tab);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavCircleButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fastDur = vaultMotion.duration(context, vaultMotion.fast);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: VaultTap(
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: selected ? p.primaryBtnInk : p.secondary,
                      ),
                      duration: fastDur,
                      curve: vaultMotion.standard,
                      builder: (context, color, _) => Icon(
                        icon,
                        size: 20,
                        color: color ?? p.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedOpacity(
                      duration: fastDur,
                      opacity: selected ? 1.0 : 0.0,
                      child: Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: selected ? p.primaryBtnInk : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                PositionedDirectional(
                  top: 3,
                  end: 6,
                  child: AnimatedScale(
                    scale: badgeCount > 0
                        ? 1.0
                        : vaultMotion.scale(context, 0.8),
                    duration: fastDur,
                    curve: vaultMotion.emphasized,
                    child: AnimatedOpacity(
                      duration: fastDur,
                      opacity: badgeCount > 0 ? 1.0 : 0.0,
                      child: badgeCount > 0
                          ? _TransfersLiveBadge(
                              palette: p,
                              count: badgeCount,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransfersLiveBadge extends StatelessWidget {
  final AppPalette palette;
  final int count;

  const _TransfersLiveBadge({
    required this.palette,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final text = count > 9 ? '9+' : '$count';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VaultStatusDotAnimated(
          color: p.signalGreen,
          isBreathing: true,
          isSynced: false,
          size: 5,
        ),
        const SizedBox(width: 2),
        Container(
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: p.signalGreen,
            borderRadius: BorderRadius.circular(VaultRadii.pill),
            border: Border.all(color: p.canvas, width: 1.5),
          ),
          alignment: Alignment.center,
          child: VaultRollingText(
            text,
            style: VaultText.mono(
              p,
              size: 9,
              weight: FontWeight.w700,
              color: p.signalGreenInk,
            ),
          ),
        ),
      ],
    );
  }
}

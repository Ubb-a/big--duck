import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'vault_surface.dart';

class FloatingTabBar extends StatelessWidget {
  final AppPalette palette;
  final AppStrings strings;
  final MobileTab activeTab;
  final int activeTransferCount;
  final ValueChanged<MobileTab> onSelect;

  const FloatingTabBar({
    super.key,
    required this.palette,
    required this.strings,
    required this.activeTab,
    required this.activeTransferCount,
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

    return RepaintBoundary(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final item in items)
                    _NavCircleButton(
                      key: ValueKey('nav_${item.tab.name}'),
                      palette: p,
                      icon: item.tab == activeTab
                          ? item.activeIcon
                          : item.icon,
                      label: item.label,
                      selected: item.tab == activeTab,
                      badgeCount: item.badge,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(item.tab);
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
    final motion = vaultMotion(context, 250);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: VaultTap(
          onTap: onTap,
          child: SizedBox(
            width: 54,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: motion,
                  curve: Curves.easeOut,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? p.primaryBtnFill : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected ? p.primaryBtnInk : p.secondary,
                  ),
                ),
                if (badgeCount > 0)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: p.signalGreen,
                        borderRadius: BorderRadius.circular(VaultRadii.pill),
                        border: Border.all(color: p.canvas, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: VaultText.mono(
                          p,
                          size: 9,
                          weight: FontWeight.w700,
                          color: p.signalGreenInk,
                        ),
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

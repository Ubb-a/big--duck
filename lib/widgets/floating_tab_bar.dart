import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
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
    final activeIndex = activeTab.index;
    final motion = vaultMotion(context, 200);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: VaultSurface(
          palette: palette,
          borderRadius: VaultRadii.dock,
          elevated: true,
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 4;
              final isRtl = Directionality.of(context) == TextDirection.rtl;
              final pillLeft =
                  isRtl ? (3 - activeIndex) * tabWidth : activeIndex * tabWidth;
              return SizedBox(
                height: 54,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      left: pillLeft,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.cobaltSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 24,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: palette.signal,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _TabItem(
                          palette: palette,
                          isArabic: strings.ar,
                          svgAsset: AppIcons.folderOpen,
                          label: strings.tabFiles,
                          selected: activeTab == MobileTab.files,
                          onTap: () => _tap(MobileTab.files),
                        ),
                        _TabItem(
                          palette: palette,
                          isArabic: strings.ar,
                          svgAsset: AppIcons.refresh,
                          label: strings.tabRecent,
                          selected: activeTab == MobileTab.recent,
                          onTap: () => _tap(MobileTab.recent),
                        ),
                        _TabItem(
                          palette: palette,
                          isArabic: strings.ar,
                          svgAsset: AppIcons.priorityArrows,
                          label: strings.tabTransfers,
                          badgeCount: activeTransferCount,
                          selected: activeTab == MobileTab.transfers,
                          onTap: () => _tap(MobileTab.transfers),
                        ),
                        _TabItem(
                          palette: palette,
                          isArabic: strings.ar,
                          svgAsset: AppIcons.settings,
                          label: strings.tabSettings,
                          selected: activeTab == MobileTab.settings,
                          onTap: () => _tap(MobileTab.settings),
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
    );
  }

  void _tap(MobileTab tab) {
    HapticFeedback.selectionClick();
    onSelect(tab);
  }
}

class _TabItem extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String svgAsset;
  final String label;
  final int badgeCount;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.palette,
    required this.isArabic,
    required this.svgAsset,
    required this.label,
    this.badgeCount = 0,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.cobalt : palette.muted;
    final motion = vaultMotion(context, 160);
    return Expanded(
      child: VaultTap(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppSvgIcon(
                    svgAsset,
                    size: 19,
                    color: color,
                  ),
                  if (badgeCount > 0)
                    PositionedDirectional(
                      end: -10,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: palette.signal,
                          borderRadius: BorderRadius.circular(VaultRadii.pill),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: VaultText.tabular(
                            palette,
                            isArabic,
                            size: 9,
                            weight: FontWeight.w700,
                            color: palette.signalInk,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: motion,
                style: TextStyle(
                  fontFamily: VaultText.fontFamily(isArabic),
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class AppIcons {
  static const String addFolder = 'assets/icons/add-folder.svg';
  static const String cloudUpload = 'assets/icons/cloud-upload-alt.svg';
  static const String document = 'assets/icons/document.svg';
  static const String folderOpen = 'assets/icons/folder-open.svg';
  static const String priorityArrows = 'assets/icons/priority-arrows.svg';
  static const String refresh = 'assets/icons/refresh.svg';
  static const String settings = 'assets/icons/settings.svg';
}

class AppSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;

  const AppSvgIcon(
    this.asset, {
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

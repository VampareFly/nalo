// 统一应用内返回按钮的点击区域、图标尺寸和可选背景样式。

import 'package:flutter/material.dart';

/// 提供 44×44 点击区域的统一返回按钮。
class NaloBackButton extends StatelessWidget {
  const NaloBackButton({
    required this.onPressed,
    this.color = const Color(0xFF008BC7),
    this.backgroundColor,
    this.icon,
    super.key,
  });

  final VoidCallback? onPressed;
  final Color color;
  final Color? backgroundColor;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: color,
        overlayColor: Colors.transparent,
      ),
      icon: icon ?? const Icon(Icons.arrow_back, size: 24),
    ),
  );
}

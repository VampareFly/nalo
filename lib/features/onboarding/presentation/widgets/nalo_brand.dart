// 提供登录注册流程复用的 Nalo 品牌标识。

import 'package:flutter/material.dart';

/// 展示 Figma 导出的 Nalo Symbol 和 Wordmark。
class NaloBrand extends StatelessWidget {
  const NaloBrand({this.onBlue = true, super.key});

  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final color = onBlue ? Colors.white : const Color(0xFF008BC7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/nalo_logo_temp.png',
          width: 80,
          height: 64,
          fit: BoxFit.contain,
          color: onBlue ? const Color(0xFFFDDA7C) : color,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(height: 12),
        Text(
          'nalo',
          style: TextStyle(
            color: color,
            fontSize: 37,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

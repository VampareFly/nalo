// 提供登录注册流程复用的 Nalo 品牌标识。

import 'package:flutter/material.dart';

/// 根据页面背景展示对应颜色的 Nalo Symbol 和 Wordmark。
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
          onBlue
              ? 'assets/images/nalo_logo_white.png'
              : 'assets/images/nalo_logo_blue.png',
          width: 80,
          height: 64,
          fit: BoxFit.contain,
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

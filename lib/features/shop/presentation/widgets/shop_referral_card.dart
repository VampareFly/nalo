// 展示新版 Shop 底部的动态 Referral 入口。
// 文案和链接来自 user/info 保存的当前用户快照。

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';

/// 展示好友优惠信息及分享入口。
class ShopReferralCard extends StatelessWidget {
  const ShopReferralCard({
    super.key,
    required this.offer,
    required this.onSharePressed,
  });

  final HomeReferralOffer offer;
  final VoidCallback onSharePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDDA7C),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SvgPicture.asset(
              'assets/icons/home_referral.svg',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  style: const TextStyle(
                    color: Color(0xFF1A2433),
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.description,
                  style: const TextStyle(
                    color: Color(0xB31A2433),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onSharePressed,
                  child: Text(
                    offer.buttonText,
                    style: const TextStyle(
                      color: Color(0xFF1A2433),
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 首页与检测结果页共用的邀请卡片：由页面提供活动数据和点击回调。
// 卡片仅负责展示；分享与曝光分别由各自页面处理。
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';

/// 展示首页和检测结果页一致的 Referral 活动入口。
class HomeReferralCard extends StatelessWidget {
  const HomeReferralCard({
    required this.offer,
    required this.onPressed,
    super.key,
  });

  final HomeReferralOffer offer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFDDA7C),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/home_referral.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      color: Color(0xFF1A2433),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.description,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    offer.buttonText,
                    style: const TextStyle(
                      color: Color(0xFF1A2433),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              'assets/icons/home_referral_chevron.svg',
              width: 18,
              height: 18,
            ),
          ],
        ),
      ),
    ),
  );
}

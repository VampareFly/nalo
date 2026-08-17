// 渲染主页面固定底部导航。
// Home/Shop 切换持久 Tab，中间 Scan 仅派发检测入口事件。

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 首页容器使用的 Home、Scan、Shop 底部导航。
class HomeBottomTabs extends StatelessWidget {
  const HomeBottomTabs({
    super.key,
    required this.selectedIndex,
    required this.homeIndex,
    required this.shopIndex,
    required this.onTabSelected,
    required this.onCreatePressed,
  });

  static const _blue = Color(0xFF008BC7);
  static const _inactive = Color(0xFF9FA89E);

  final int selectedIndex;
  final int homeIndex;
  final int shopIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x1A1A2433))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                child: _TabItem(
                  asset: 'assets/icons/home_tab.svg',
                  label: 'Home',
                  color: selectedIndex == homeIndex ? _blue : _inactive,
                  onTap: () => onTabSelected(homeIndex),
                ),
              ),
              Expanded(child: _ScanItem(onTap: onCreatePressed)),
              Expanded(
                child: _TabItem(
                  asset: 'assets/icons/shop_tab.svg',
                  label: 'Shop',
                  color: selectedIndex == shopIndex ? _blue : _inactive,
                  onTap: () => onTabSelected(shopIndex),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.asset, required this.label, required this.color, required this.onTap});
  final String asset;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(asset, width: 22, height: 22, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ScanItem extends StatelessWidget {
  const _ScanItem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, -12),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: HomeBottomTabs._blue,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x33008BC7), blurRadius: 14, offset: Offset(0, 6))],
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/icons/scan_tab.svg',
                width: 26,
                height: 26,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -9),
            child: Text(
              'Scan',
              style: TextStyle(color: HomeBottomTabs._blue, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

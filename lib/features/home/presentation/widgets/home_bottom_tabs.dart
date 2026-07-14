import 'package:flutter/material.dart';

class HomeBottomTabs extends StatelessWidget {
  const HomeBottomTabs({
    super.key,
    required this.selectedIndex,
    required this.homeIndex,
    required this.shopIndex,
    required this.onTabSelected,
    required this.onCreatePressed,
  });

  static const _homeIcon = 'assets/icons/home_tab_icon.png';
  static const _shopIcon = 'assets/icons/shop_tab_icon.png';

  final int selectedIndex;
  final int homeIndex;
  final int shopIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(43),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 13))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomTabItem(
                      iconAsset: _homeIcon,
                      label: 'Home',
                      isSelected: selectedIndex == homeIndex,
                      onTap: () => onTabSelected(homeIndex),
                    ),
                  ),
                  const SizedBox(width: 88),
                  Expanded(
                    child: _BottomTabItem(
                      iconAsset: _shopIcon,
                      label: 'Shop',
                      isSelected: selectedIndex == shopIndex,
                      onTap: () => onTabSelected(shopIndex),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 0, child: _CreateButton(onPressed: onCreatePressed)),
        ],
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({required this.iconAsset, required this.label, required this.isSelected, required this.onTap});

  final String iconAsset;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF050505) : const Color(0xFF6E6E6E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Material(
        color: isSelected ? const Color(0xFFF4F5FC) : Colors.transparent,
        borderRadius: BorderRadius.circular(27),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(27),
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(iconAsset, width: 20, height: 20, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 16, height: 1, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 63,
            height: 63,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F5),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(color: Color(0xFF050505), shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

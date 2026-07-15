import 'package:flutter/material.dart';

class MainPageHeader extends StatelessWidget {
  const MainPageHeader({super.key, required this.headline, required this.onMinePressed});

  final String headline;
  final VoidCallback onMinePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NBG TEST KIT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF717174),
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF050505),
                  fontSize: 24,
                  height: 1,
                  fontFamily: 'Times New Roman',
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _MineButton(onPressed: onMinePressed),
      ],
    );
  }
}

class _MineButton extends StatelessWidget {
  const _MineButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: const Icon(Icons.person_outline, color: Color(0xFF050505), size: 24),
              ),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFA9B5F4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

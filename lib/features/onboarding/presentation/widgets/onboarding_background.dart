import 'package:flutter/material.dart';

class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F2CE), Color(0xFFD9DCE2), Color(0xFFBCC4F5)],
          stops: [0, 0.42, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: 16,
            right: -18,
            child: _Glow(size: 100, color: Color(0x66F4B6D1)),
          ),
          const Positioned(
            top: 4,
            right: 66,
            child: _Glow(size: 54, color: Color(0x66F2E367)),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 34, spreadRadius: 8)],
      ),
    );
  }
}

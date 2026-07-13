import 'package:flutter/material.dart';

class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isPrimary ? Colors.black : Colors.white,
          foregroundColor: isPrimary ? Colors.white : Colors.black,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSubpageScaffold extends StatelessWidget {
  const ProfileSubpageScaffold({super.key, required this.title, required this.children, this.titleFontSize = 28});

  final String title;
  final List<Widget> children;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 44),
              sliver: SliverList.list(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF606064),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      icon: const Icon(Icons.chevron_left, size: 22),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF050505),
                      fontFamily: 'Times New Roman',
                      fontSize: titleFontSize,
                      height: 1,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 13),
              child: Text(
                title!,
                style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.5),
              ),
            ),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0 || title != null) const Divider(height: 1, color: Color(0xFFE8E8E8)),
            children[index],
          ],
        ],
      ),
    );
  }
}

class ProfileSettingRow extends StatelessWidget {
  const ProfileSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onPressed,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(subtitle!, style: const TextStyle(color: Color(0xFF77777A), fontSize: 12, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

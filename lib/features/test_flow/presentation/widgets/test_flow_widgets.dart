// 检测流程共享 UI：集中维护颜色、顶部栏、步骤标识、按钮、卡片和选择项样式。
import 'package:flutter/material.dart';
import 'package:nalo/core/widgets/nalo_back_button.dart';

/// 检测流程使用的页面背景色。
const flowPaper = Color(0xFFEDE8E0);

/// 检测流程使用的主文字色。
const flowInk = Color(0xFF1A2433);

/// 检测流程使用的品牌主色。
const flowBlue = Color(0xFF008BC7);

/// 检测流程使用的强调色。
const flowYellow = Color(0xFFFDDA7C);

/// 检测流程使用的次要文字色。
const flowMuted = Color(0xFF9FA89E);

/// 检测流程使用的浅蓝辅助色。
const flowSoftBlue = Color(0xFFB6D0DF);

/// 在检测页面中展示 Nalo 标识；占位图可按背景传入着色。
class FlowNaloMark extends StatelessWidget {
  const FlowNaloMark({this.width = 40, this.color, super.key});
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/nalo_logo_blue.png',
    width: width,
    height: width * .75,
    fit: BoxFit.contain,
    color: color,
    colorBlendMode: color == null ? null : BlendMode.srcIn,
  );
}

/// 检测页面顶部导航栏，支持返回、左右关闭位置和自定义中间内容。
class FlowTopBar extends StatelessWidget {
  const FlowTopBar({
    this.title,
    this.titleColor,
    this.onBack,
    this.onClose,
    this.center,
    this.dark = false,
    this.closeOnRight = false,
    this.plainRightClose = false,
    super.key,
  });
  final String? title;
  final Color? titleColor;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final Widget? center;
  final bool dark;
  final bool closeOnRight;
  final bool plainRightClose;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : flowBlue;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null && (onClose == null || closeOnRight)
                ? null
                : Transform.translate(
                    offset: const Offset(-6, 0),
                    child: NaloBackButton(
                      onPressed: onBack ?? onClose,
                      color: color,
                      icon: Icon(
                        onBack != null ? Icons.arrow_back : Icons.close,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child:
                (center == null ? null : Center(child: center)) ??
                Text(
                  title ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor ?? (dark ? Colors.white : flowInk),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
          SizedBox(
            width: 44,
            child: onClose == null || (onBack == null && !closeOnRight)
                ? null
                : plainRightClose
                ? IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: flowBlue, size: 28),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0x14000000),
                          shape: BoxShape.circle,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onClose,
                        icon: const Icon(Icons.close, color: flowInk, size: 18),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 显示 Swab、Test、Learn 三阶段及当前阶段。
class FlowStepPills extends StatelessWidget {
  const FlowStepPills({required this.activeIndex, super.key});
  final int activeIndex;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < 3; index++) ...[
        if (index > 0) const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: index == activeIndex ? flowBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: flowBlue, width: 1.5),
          ),
          child: Text(
            const ['Swab.', 'Test.', 'Learn.'][index],
            style: TextStyle(
              color: index == activeIndex ? Colors.white : flowBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ],
  );
}

/// 检测流程的主操作按钮。
class FlowPrimaryButton extends StatelessWidget {
  const FlowPrimaryButton({
    required this.label,
    required this.onPressed,
    this.yellow = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool yellow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: yellow ? flowYellow : flowBlue,
        disabledBackgroundColor: flowMuted.withValues(alpha: .45),
        foregroundColor: yellow ? flowInk : Colors.white,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

/// 检测流程的次级描边按钮。
class FlowOutlineButton extends StatelessWidget {
  const FlowOutlineButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: flowBlue,
        side: const BorderSide(color: flowBlue, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

/// 检测页面通用白色圆角内容卡片。
class FlowCard extends StatelessWidget {
  const FlowCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

/// 检测卡片内统一使用的大写分区标题。
class FlowSectionLabel extends StatelessWidget {
  const FlowSectionLabel(this.text, {this.uppercase = true, super.key});
  final String text;
  final bool uppercase;
  @override
  Widget build(BuildContext context) => Text(
    uppercase ? text.toUpperCase() : text,
    style: const TextStyle(
      color: flowMuted,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w800,
      letterSpacing: .8,
    ),
  );
}

/// 可选结果区间或时间段使用的单选卡片。
class FlowChoiceTile extends StatelessWidget {
  const FlowChoiceTile({
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? flowBlue : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? flowBlue : const Color(0x14000000),
        width: 1.5,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? flowYellow : Colors.transparent,
                border: Border.all(color: selected ? flowYellow : flowMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: selected ? Colors.white : flowInk),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

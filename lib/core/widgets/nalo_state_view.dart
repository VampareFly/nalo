// 提供列表页复用的空数据与错误状态视图。
// 页面传入业务文案和插画，组件统一处理布局、按钮与视觉样式。

import 'package:flutter/material.dart';

/// 状态页插画资源，供无数据和网络错误场景统一使用。
abstract final class NaloStateIllustration {
  static const shopEmpty = 'assets/images/state_shop_empty.png';
  static const testHistoryEmpty =
      'assets/images/state_test_history_empty.png';
  static const networkError = 'assets/images/state_network_error.png';
}

/// 展示空数据或加载错误，并按需提供一个操作按钮。
class NaloStateView extends StatelessWidget {
  const NaloStateView({
    required this.illustrationAsset,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.usePrimaryAction = false,
    super.key,
  });

  /// 当前业务状态对应的插画资源。
  final String illustrationAsset;

  /// 状态标题。
  final String title;

  /// 帮助用户理解状态或下一步操作的说明。
  final String description;

  /// 操作按钮文案；为空时不展示按钮。
  final String? actionLabel;

  /// 操作按钮回调；为空时不展示按钮。
  final VoidCallback? onAction;

  /// 是否使用蓝色主按钮，否则使用描边按钮。
  final bool usePrimaryAction;

  @override
  Widget build(BuildContext context) {
    final showAction = actionLabel != null && onAction != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            illustrationAsset,
            width: 160,
            height: 160,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A2433),
              fontSize: 18,
              height: 24 / 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9FA89E),
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
          if (showAction) ...[
            const SizedBox(height: 20),
            if (usePrimaryAction)
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(148, 44),
                  backgroundColor: const Color(0xFF008BC7),
                  shape: const StadiumBorder(),
                ),
                child: Text(actionLabel!),
              )
            else
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(148, 44),
                  foregroundColor: const Color(0xFF008BC7),
                  side: const BorderSide(color: Color(0xFF008BC7)),
                  shape: const StadiumBorder(),
                ),
                child: Text(actionLabel!),
              ),
          ],
        ],
      ),
    );
  }
}

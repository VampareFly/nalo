// 记录冷启动分流后的首个业务页面是否已完成首帧。
// 页面只发布准备完成信号，外部入口据此决定何时消费冷启动意图。

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 提供首个业务页面的冷启动就绪状态。
final initialPageReadyProvider =
    NotifierProvider<InitialPageReadyNotifier, bool>(
      InitialPageReadyNotifier.new,
    );

/// 接收首个业务页面完成首帧的单向通知。
class InitialPageReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 由冷启动分流后的首个页面在首帧完成时调用。
  void markReady() {
    if (!state) state = true;
  }
}

// 定义 Riverpod Provider 对网络层异常的统一重试策略。
// 网络与业务协议失败交给页面处理，其他 Provider 异常保留 Riverpod 默认行为。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_client.dart';

/// 遇到网络层已分类异常时停止 Provider 隐式重试。
Duration? appProviderRetry(int retryCount, Object error) {
  if (error is NetworkException ||
      error is ApiException ||
      error is ResponseFormatException ||
      error is SessionExpiredException) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

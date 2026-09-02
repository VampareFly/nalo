// 统一管理 Shop 列表、购买链接状态和链接请求结果埋点。
// ShopPage 只监听本 Provider，并在获得 URL 后负责打开外部浏览器。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/repositories/shop_repository.dart';

/// Shop 商品列表及当前交互状态。
@immutable
class ShopState {
  const ShopState({
    required this.products,
    required this.currentPage,
    required this.hasMore,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadingProductId,
    this.loadMoreError,
  });

  final List<TestKitProduct> products;
  final int currentPage;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final int? loadingProductId;
  final String? loadMoreError;

  /// 创建更新后的页面状态，支持显式清理可空字段。
  ShopState copyWith({
    List<TestKitProduct>? products,
    int? currentPage,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    int? loadingProductId,
    String? loadMoreError,
    bool clearLoadingProductId = false,
    bool clearLoadMoreError = false,
  }) {
    return ShopState(
      products: products ?? this.products,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingProductId: clearLoadingProductId
          ? null
          : loadingProductId ?? this.loadingProductId,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

/// 生成购买链接后返回给页面的结果。
@immutable
class ShopPurchaseResult {
  const ShopPurchaseResult._({this.url, this.errorMessage});

  final Uri? url;
  final String? errorMessage;

  /// 创建可供页面打开的成功结果。
  factory ShopPurchaseResult.success(Uri url) => ShopPurchaseResult._(url: url);

  /// 创建需要页面提示的失败结果。
  factory ShopPurchaseResult.failure(String message) =>
      ShopPurchaseResult._(errorMessage: message);
}

/// 编排 Shop 列表分页和单商品购买请求。
class ShopViewModel extends AsyncNotifier<ShopState> {
  static const _pageSize = 10;
  bool _isListRequestRunning = false;

  @override
  Future<ShopState> build() async {
    try {
      final repository = await ref.watch(shopRepositoryProvider.future);
      return _loadFirstPage(repository);
    } catch (error, stackTrace) {
      _logInitialLoadError(error, stackTrace);
      rethrow;
    }
  }

  /// 初始加载失败后，显式进入 Loading 并重新请求第一页。
  Future<void> retryInitialLoad() async {
    if (_isListRequestRunning) return;
    _isListRequestRunning = true;
    state = const AsyncLoading();
    try {
      if (ref.read(shopRepositoryProvider).hasError) {
        if (ref.read(businessApiClientProvider).hasError) {
          ref.invalidate(businessApiClientProvider);
        }
        ref.invalidate(shopRepositoryProvider);
      }
      final repository = await ref.read(shopRepositoryProvider.future);
      state = AsyncData(await _loadFirstPage(repository));
    } catch (error, stackTrace) {
      _logInitialLoadError(error, stackTrace);
      state = AsyncError(error, stackTrace);
    } finally {
      _isListRequestRunning = false;
    }
  }

  /// 下拉刷新时重新加载第一页并重置分页状态。
  Future<void> refreshProducts() async {
    final current = state.asData?.value;
    if (current == null || _isListRequestRunning) return;
    _isListRequestRunning = true;
    state = AsyncData(
      current.copyWith(isRefreshing: true, clearLoadMoreError: true),
    );
    try {
      final repository = await ref.read(shopRepositoryProvider.future);
      final page = await repository.getProducts(page: 1, pageSize: _pageSize);
      state = AsyncData(
        ShopState(
          products: page.products,
          currentPage: page.page,
          hasMore: page.hasMore,
        ),
      );
    } catch (error, stackTrace) {
      ref
          .read(loggerProvider)
          .e(
            'Shop products refresh failed.',
            error: error,
            stackTrace: stackTrace,
          );
      state = AsyncData(current.copyWith(isRefreshing: false));
      rethrow;
    } finally {
      _isListRequestRunning = false;
    }
  }

  /// 滚动至底部时根据 has_more 追加下一页。
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.isRefreshing ||
        _isListRequestRunning) {
      return;
    }
    _isListRequestRunning = true;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final nextPage = current.currentPage + 1;
      final repository = await ref.read(shopRepositoryProvider.future);
      final page = await repository.getProducts(
        page: nextPage,
        pageSize: _pageSize,
      );
      state = AsyncData(
        current.copyWith(
          products: [...current.products, ...page.products],
          currentPage: page.page,
          hasMore: page.hasMore,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error, stackTrace) {
      ref
          .read(loggerProvider)
          .e(
            'Shop products load-more failed.',
            error: error,
            stackTrace: stackTrace,
          );
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: _messageFor(error),
        ),
      );
    } finally {
      _isListRequestRunning = false;
    }
  }

  /// 点击 Get kit 时生成一次性 Shopify 购买 URL。
  Future<ShopPurchaseResult> createPurchaseLink(TestKitProduct product) async {
    final current = state.asData?.value;
    if (current == null || current.loadingProductId != null) {
      return ShopPurchaseResult.failure('A shop request is already running.');
    }
    state = AsyncData(current.copyWith(loadingProductId: product.productId));
    try {
      final repository = await ref.read(shopRepositoryProvider.future);
      final link = await repository.createPurchaseLink(product);
      await _reportPurchaseLinkResult(
        product,
        url: link.url.toString(),
        isSuccess: true,
      );
      return ShopPurchaseResult.success(link.url);
    } catch (error, stackTrace) {
      ref
          .read(loggerProvider)
          .e(
            'Shop purchase-link request failed.',
            error: error,
            stackTrace: stackTrace,
          );
      await _reportPurchaseLinkResult(
        product,
        isSuccess: false,
        failReason: _analyticsFailReason(error),
      );
      return ShopPurchaseResult.failure(_messageFor(error));
    } finally {
      final latest = state.asData?.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(clearLoadingProductId: true));
      }
    }
  }

  Future<void> _reportPurchaseLinkResult(
    TestKitProduct product, {
    required bool isSuccess,
    String url = '',
    String failReason = '',
  }) {
    return ref
        .read(analyticsProvider)
        .report(
          AnalyticsEvent.shopShopifyUrlRequest,
          properties: {
            AnalyticsEventProperty.pageName: AnalyticsPageName.tabShop.value,
            AnalyticsEventProperty.productId: product.productId.toString(),
            AnalyticsEventProperty.variantId: product.variantId.toString(),
            AnalyticsEventProperty.url: url,
            AnalyticsEventProperty.isSuccess: isSuccess ? 1 : 0,
            AnalyticsEventProperty.failReason: failReason,
          },
        );
  }

  String _analyticsFailReason(Object error) {
    return switch (error) {
      ApiException(:final code, :final message) => '$code: $message',
      NetworkException(:final type, :final message) => '${type.name}: $message',
      SessionExpiredException(:final message) => 'session_expired: $message',
      ResponseFormatException(:final message) =>
        'response_format_error: $message',
      _ => 'unknown_error: Something went wrong. Please try again.',
    };
  }

  Future<ShopState> _loadFirstPage(ShopRepository repository) async {
    final page = await repository.getProducts(page: 1, pageSize: _pageSize);
    return ShopState(
      products: page.products,
      currentPage: page.page,
      hasMore: page.hasMore,
    );
  }

  void _logInitialLoadError(Object error, StackTrace stackTrace) {
    ref
        .read(loggerProvider)
        .e(
          'Shop products initial load failed before the page could render.',
          error: error,
          stackTrace: stackTrace,
        );
  }

  String _messageFor(Object error) {
    return switch (error) {
      ApiException(:final message) => message,
      NetworkException(:final message) => message,
      ResponseFormatException(:final message) => message,
      SessionExpiredException(:final message) => message,
      _ => 'Something went wrong. Please try again.',
    };
  }
}

/// 提供 Shop 列表、分页与购买交互的单一状态入口。
final shopViewModelProvider = AsyncNotifierProvider<ShopViewModel, ShopState>(
  ShopViewModel.new,
);

// 展示 Shop 商品并协调曝光、点击、分页和购买跳转。
// 商品达到 10% 可视比例时按单次页面可见周期去重，点击在请求链接前上报。

import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/sharing/platform_share_service.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/presentation/widgets/shop_referral_card.dart';
import 'package:nalo/features/shop/presentation/widgets/test_kit_purchase_card.dart';
import 'package:nalo/features/shop/view_models/shop_view_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _blue = Color(0xFF008BC7);
const _ink = Color(0xFF1A2433);
const _muted = Color(0xFF9FA89E);
const _pageBackground = Color(0xFFEDE8E0);
const _skuVisibleFraction = 0.1;
const _productBackgrounds = [
  Color(0xFFB6D0DF),
  Color(0xFFFDDA7C),
  Color(0xFFECAD46),
];

/// Home 容器中的 Shop Tab，保留滚动位置并在接近底部时加载更多。
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({
    super.key,
    required this.isActive,
    required this.exposureCycle,
    required this.onMinePressed,
  });

  /// 当前 Shop Tab 是否实际可见。
  final bool isActive;

  /// Shop 每次重新可见时递增，用于开启新一轮商品曝光。
  final int exposureCycle;
  final VoidCallback onMinePressed;

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  late final ScrollController _scrollController;
  final Set<String> _viewedSkuKeys = {};
  bool _referralViewReported = false;
  bool _ownsLoadingToast = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    if (_ownsLoadingToast) EasyLoading.dismiss();
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exposureCycle != widget.exposureCycle ||
        (oldWidget.isActive && !widget.isActive)) {
      _viewedSkuKeys.clear();
      _referralViewReported = false;
    }
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 240) {
      ref.read(shopViewModelProvider.notifier).loadMore();
    }
  }

  Future<void> _refreshProducts() async {
    try {
      await ref.read(shopViewModelProvider.notifier).refreshProducts();
    } catch (_) {
      BotToast.showText(
        text: 'Unable to refresh products. Please try again.',
        align: Alignment.center,
      );
    }
  }

  Future<void> _purchase(TestKitProduct product) async {
    unawaited(
      ref.report(AnalyticsEvent.skuClick, properties: _skuProperties(product)),
    );
    final result = await ref
        .read(shopViewModelProvider.notifier)
        .createPurchaseLink(product);
    if (!mounted) return;
    final uri = result.url;
    if (uri == null) {
      BotToast.showText(
        text: result.errorMessage ?? 'Unable to open the shop.',
        align: Alignment.center,
      );
      return;
    }
    final didOpen = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didOpen) {
      BotToast.showText(
        text: 'Unable to open the shop.',
        align: Alignment.center,
      );
    }
  }

  void _handleSkuVisibility(TestKitProduct product, double visibleFraction) {
    if (!widget.isActive || visibleFraction < _skuVisibleFraction) return;
    final skuKey = '${product.productId}:${product.variantId}';
    if (!_viewedSkuKeys.add(skuKey)) return;
    unawaited(
      ref.report(AnalyticsEvent.skuView, properties: _skuProperties(product)),
    );
  }

  Map<AnalyticsEventProperty, Object> _skuProperties(TestKitProduct product) {
    return skuAnalyticsProperties(
      productId: product.productId,
      variantId: product.variantId,
      title: product.title,
      description: product.description,
      imageUrl: product.imageUrl,
      price: product.price,
      compareAtPrice: product.compareAtPrice,
      currency: product.currency,
    );
  }

  void _reportReferralView(HomeReferralOffer offer, double visibleFraction) {
    if (!widget.isActive ||
        _referralViewReported ||
        visibleFraction < _skuVisibleFraction) {
      return;
    }
    _referralViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.referralView,
        properties: _referralProperties(offer),
      ),
    );
  }

  Future<void> _shareReferral(HomeReferralOffer offer) async {
    unawaited(
      ref.report(
        AnalyticsEvent.referralClick,
        properties: _referralProperties(offer),
      ),
    );
    try {
      await ref
          .read(platformShareServiceProvider)
          .shareLink(offer.actionUrl, message: offer.shareText);
    } on Object {
      if (!mounted) return;
      BotToast.showText(
        text: 'Unable to share referral link',
        align: Alignment.center,
      );
    }
  }

  Map<AnalyticsEventProperty, Object> _referralProperties(
    HomeReferralOffer offer,
  ) => referralAnalyticsProperties(
    pageName: AnalyticsPageName.tabShop,
    url: offer.actionUrl,
    advocateRewardType: offer.advocateRewardType,
    advocateRewardValue: offer.advocateRewardValue,
    advocateRewardUnit: offer.advocateRewardUnit,
    friendRewardType: offer.friendRewardType,
    friendRewardValue: offer.friendRewardValue,
    friendRewardUnit: offer.friendRewardUnit,
  );

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(shopViewModelProvider);
    final dashboard = ref.watch(homeDashboardProvider);
    final initial = dashboard.asData?.value.userInitial ?? 'N';
    final referralOffer = dashboard.asData?.value.referralOffer;
    ref.listen(
      shopViewModelProvider.select(
        (value) => value.asData?.value.loadingProductId != null,
      ),
      (previous, next) {
        if (next) {
          _ownsLoadingToast = true;
          EasyLoading.show();
        } else if (_ownsLoadingToast) {
          _ownsLoadingToast = false;
          EasyLoading.dismiss();
        }
      },
    );

    return ColoredBox(
      color: _pageBackground,
      child: Column(
        children: [
          _ShopTopBar(initial: initial, onProfilePressed: widget.onMinePressed),
          Expanded(
            child: products.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _blue)),
              error: (_, _) => _ShopLoadError(
                onRetry: () =>
                    ref.read(shopViewModelProvider.notifier).retryInitialLoad(),
              ),
              data: (state) => RefreshIndicator(
                color: _blue,
                onRefresh: _refreshProducts,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      sliver: SliverList.list(
                        children: [
                          const _ShopHeading(),
                          const SizedBox(height: 20),
                          if (state.products.isEmpty)
                            const _EmptyShop()
                          else
                            for (
                              var index = 0;
                              index < state.products.length;
                              index++
                            ) ...[
                              VisibilityDetector(
                                key: ValueKey<String>(
                                  'shop-sku-${widget.exposureCycle}-'
                                  '${state.products[index].productId}-'
                                  '${state.products[index].variantId}',
                                ),
                                onVisibilityChanged: (info) =>
                                    _handleSkuVisibility(
                                      state.products[index],
                                      info.visibleFraction,
                                    ),
                                child: TestKitPurchaseCard(
                                  product: state.products[index],
                                  imageBackgroundColor:
                                      _productBackgrounds[index %
                                          _productBackgrounds.length],
                                  isPurchaseEnabled:
                                      state.loadingProductId == null,
                                  onPurchasePressed: () =>
                                      _purchase(state.products[index]),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          if (referralOffer != null)
                            VisibilityDetector(
                              key: ValueKey(
                                'shop-referral-${widget.exposureCycle}',
                              ),
                              onVisibilityChanged: (info) =>
                                  _reportReferralView(
                                    referralOffer,
                                    info.visibleFraction,
                                  ),
                              child: ShopReferralCard(
                                offer: referralOffer,
                                onSharePressed: () =>
                                    _shareReferral(referralOffer),
                              ),
                            ),
                          if (state.isLoadingMore) ...[
                            const SizedBox(height: 20),
                            const Center(
                              child: CircularProgressIndicator(
                                color: _blue,
                                strokeWidth: 2,
                              ),
                            ),
                          ] else if (state.loadMoreError != null) ...[
                            const SizedBox(height: 12),
                            _LoadMoreError(
                              message: state.loadMoreError!,
                              onRetry: () => ref
                                  .read(shopViewModelProvider.notifier)
                                  .loadMore(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({required this.initial, required this.onProfilePressed});

  final String initial;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xE6EDE8E0),
        border: Border(bottom: BorderSide(color: Color(0x1A1A2433))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'nalo',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Material(
                color: _blue,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onProfilePressed,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Center(
                      child: Text(
                        initial,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopHeading extends StatelessWidget {
  const _ShopHeading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shop',
          style: TextStyle(color: _muted, fontSize: 14, height: 20 / 14),
        ),
        Text(
          'Get your kit.',
          style: TextStyle(
            color: _ink,
            fontSize: 30,
            height: 36 / 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Lab-grade science, translated into plain English.',
          style: TextStyle(color: _muted, fontSize: 14, height: 20 / 14),
        ),
      ],
    );
  }
}

class _EmptyShop extends StatelessWidget {
  const _EmptyShop();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Text(
          'No kits are available right now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      ),
    );
  }
}

class _ShopLoadError extends StatelessWidget {
  const _ShopLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load products.',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                shape: const StadiumBorder(),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

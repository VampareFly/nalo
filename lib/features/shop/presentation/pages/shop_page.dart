// 展示新版 Shop 页并协调列表刷新、分页、购买跳转与 Referral 入口。
// 页面通过 ShopViewModel 获取数据，只在获得服务端 URL 后调用系统外部浏览器。

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/presentation/widgets/shop_referral_card.dart';
import 'package:nalo/features/shop/presentation/widgets/test_kit_purchase_card.dart';
import 'package:nalo/features/shop/view_models/shop_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

const _blue = Color(0xFF008BC7);
const _ink = Color(0xFF1A2433);
const _muted = Color(0xFF9FA89E);
const _pageBackground = Color(0xFFEDE8E0);
const _productBackgrounds = [
  Color(0xFFB6D0DF),
  Color(0xFFFDDA7C),
  Color(0xFFECAD46),
];

/// Home 容器中的 Shop Tab，保留滚动位置并在接近底部时加载更多。
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key, required this.onMinePressed});

  final VoidCallback onMinePressed;

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
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
    final didOpen = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didOpen) {
      BotToast.showText(
        text: 'Unable to open the shop.',
        align: Alignment.center,
      );
    }
  }

  void _shareReferral() {
    // TODO: <pf> Referral 接口提供分享链接后接入系统分享。
    BotToast.showText(
      text: 'Referral sharing is coming soon.',
      align: Alignment.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(shopViewModelProvider);
    final dashboard = ref.watch(homeDashboardProvider);
    final initial = dashboard.asData?.value.userInitial ?? 'N';

    return ColoredBox(
      color: _pageBackground,
      child: Column(
        children: [
          _ShopTopBar(
            initial: initial,
            onProfilePressed: widget.onMinePressed,
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _blue),
              ),
              error: (_, _) => _ShopLoadError(
                onRetry: () => ref
                    .read(shopViewModelProvider.notifier)
                    .retryInitialLoad(),
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
                              TestKitPurchaseCard(
                                product: state.products[index],
                                imageBackgroundColor:
                                    _productBackgrounds[index %
                                        _productBackgrounds.length],
                                isPurchasing:
                                    state.loadingProductId ==
                                    state.products[index].productId,
                                isPurchaseEnabled:
                                    state.loadingProductId == null,
                                onPurchasePressed: () =>
                                    _purchase(state.products[index]),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ShopReferralCard(onSharePressed: _shareReferral),
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
  const _ShopTopBar({
    required this.initial,
    required this.onProfilePressed,
  });

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

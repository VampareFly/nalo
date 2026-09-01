// 按新版 Shop Figma 展示单个服务端商品。
// 卡片只负责响应式布局和按钮状态，购买请求由 ShopViewModel 处理。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';

const _blue = Color(0xFF008BC7);
const _ink = Color(0xFF1A2433);
const _muted = Color(0xFF9FA89E);

/// 展示商品图片、文案、价格与 Get kit 操作。
class TestKitPurchaseCard extends StatelessWidget {
  const TestKitPurchaseCard({
    super.key,
    required this.product,
    required this.imageBackgroundColor,
    required this.isPurchaseEnabled,
    required this.onPurchasePressed,
  });

  final TestKitProduct product;
  final Color imageBackgroundColor;
  final bool isPurchaseEnabled;
  final VoidCallback onPurchasePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(
            imageUrl: product.imageUrl,
            backgroundColor: imageBackgroundColor,
          ),
          const SizedBox(height: 16),
          Text(
            product.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              height: 28 / 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (product.description case final description?) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 20 / 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _ProductPrice(product: product)),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: isPurchaseEnabled ? onPurchasePressed : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(104, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Get kit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl, required this.backgroundColor});

  final String? imageUrl;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 323 / 128,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: backgroundColor,
          child: imageUrl == null
              ? _ProductImageFallback(color: backgroundColor)
              : CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      _ProductImageFallback(color: backgroundColor),
                  errorWidget: (_, _, _) =>
                      _ProductImageFallback(color: backgroundColor),
                ),
        ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = Color.lerp(color, Colors.white, 0.35) ?? Colors.white;
    return Center(
      child: SvgPicture.asset(
        'assets/images/nalo_symbol_white.svg',
        width: 52,
        height: 39,
        colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
      ),
    );
  }
}

class _ProductPrice extends StatelessWidget {
  const _ProductPrice({required this.product});

  final TestKitProduct product;

  @override
  Widget build(BuildContext context) {
    final currentPrice = _formatPrice(product.price, product.currency);
    final compareAtPrice = product.compareAtPrice == null
        ? null
        : _formatPrice(product.compareAtPrice!, product.currency);
    return Wrap(
      spacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (compareAtPrice != null)
          Text(
            compareAtPrice,
            style: const TextStyle(
              color: _muted,
              fontSize: 16,
              height: 24 / 16,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          currentPrice,
          style: const TextStyle(
            color: _blue,
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _formatPrice(String value, String currency) {
    final amount = num.tryParse(value);
    if (amount == null) return '$currency $value';
    final decimalDigits = amount == amount.roundToDouble() ? 0 : 2;
    return NumberFormat.simpleCurrency(
      name: currency,
      decimalDigits: decimalDigits,
    ).format(amount);
  }
}

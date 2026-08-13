import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/widgets/main_page_header.dart';
import 'package:nalo/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/presentation/pages/subscription_details_page.dart';
import 'package:nalo/features/shop/presentation/widgets/monthly_subscription_offer_card.dart';
import 'package:nalo/features/shop/presentation/widgets/referral_discount_card.dart';
import 'package:nalo/features/shop/presentation/widgets/test_kit_purchase_card.dart';
import 'package:nalo/features/shop/providers/test_kit_products_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key, required this.onMinePressed});

  static const _referralCode = '7XY212AS0W0H';
  static final _shareLink = Uri.parse(
    'https://test-store-001-55rykspg.myshopify.com/discount/7XY212AS0W0H?redirect=%2Fcollections%2F%E5%95%86%E5%93%81%E6%A0%87%E9%A2%98-01',
  );

  final VoidCallback onMinePressed;

  Future<void> _openProduct(TestKitProduct product) async {
    final didOpen = await launchUrl(Uri.parse(product.productUrl), mode: LaunchMode.externalApplication);
    if (!didOpen) {
      BotToast.showText(text: 'Unable to open the shop', align: Alignment.center);
    }
  }

  Future<void> _copyReferralCode() async {
    await Clipboard.setData(const ClipboardData(text: _referralCode));
    BotToast.showText(text: 'Referral code copied', align: Alignment.center);
  }

  Future<void> _openShareLink() async {
    final opened = await launchUrl(_shareLink, mode: LaunchMode.externalApplication);
    if (!opened) BotToast.showText(text: 'Unable to open share link', align: Alignment.center);
  }

  void _showMessageToast() {
    // TODO: <pf> Open the prefilled message composer when referral messaging is implemented.
    BotToast.showText(text: 'Message sharing is coming soon', align: Alignment.center);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(testKitProductsProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          sliver: SliverList.list(
            children: [
              MainPageHeader(headline: 'Shop', onMinePressed: onMinePressed),
              const SizedBox(height: 34),
              for (var index = 0; index < products.length; index++) ...[
                TestKitPurchaseCard(product: products[index], onOrderPressed: () => _openProduct(products[index])),
                if (index < products.length - 1) const SizedBox(height: 18),
              ],
              const SizedBox(height: 18),
              MonthlySubscriptionOfferCard(
                onSubscribePressed: () => context.push(SubscriptionDetailsPage.path),
              ),
              const SizedBox(height: 20),
              ReferralDiscountCard(
                referralCode: _referralCode,
                onCopyPressed: _copyReferralCode,
                onShareLinkPressed: _openShareLink,
                onMessagePressed: _showMessageToast,
              ),
              const SizedBox(height: 38),
              const MedicalDisclaimerFooter(),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

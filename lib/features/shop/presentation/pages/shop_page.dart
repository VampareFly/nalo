import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/home/presentation/widgets/main_page_header.dart';
import 'package:tester_kit/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:tester_kit/features/shop/models/test_kit_product.dart';
import 'package:tester_kit/features/shop/presentation/widgets/monthly_subscription_offer_card.dart';
import 'package:tester_kit/features/shop/presentation/widgets/referral_discount_card.dart';
import 'package:tester_kit/features/shop/presentation/widgets/test_kit_purchase_card.dart';
import 'package:tester_kit/features/shop/providers/test_kit_products_provider.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key, required this.onMinePressed});

  static const _referralCode = 'KNOW-15';

  final VoidCallback onMinePressed;

  void _showOrderToast(TestKitProduct product) {
    // TODO: <pf> Open the selected test kit purchase flow after checkout is implemented.
    BotToast.showText(text: '${product.name} ordering is coming soon', align: Alignment.center);
  }

  void _showSubscribeToast() {
    // TODO: <pf> Open the monthly subscription checkout after subscriptions are implemented.
    BotToast.showText(text: 'Subscriptions are coming soon', align: Alignment.center);
  }

  Future<void> _copyReferralCode() async {
    await Clipboard.setData(const ClipboardData(text: _referralCode));
    BotToast.showText(text: 'Referral code copied', align: Alignment.center);
  }

  void _showShareLinkToast() {
    // TODO: <pf> Open the system share sheet when referral sharing is implemented.
    BotToast.showText(text: 'Share link is coming soon', align: Alignment.center);
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
                TestKitPurchaseCard(product: products[index], onOrderPressed: () => _showOrderToast(products[index])),
                if (index < products.length - 1) const SizedBox(height: 18),
              ],
              const SizedBox(height: 18),
              MonthlySubscriptionOfferCard(onSubscribePressed: _showSubscribeToast),
              const SizedBox(height: 20),
              ReferralDiscountCard(
                referralCode: _referralCode,
                onCopyPressed: _copyReferralCode,
                onShareLinkPressed: _showShareLinkToast,
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

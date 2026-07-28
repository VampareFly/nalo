import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:tester_kit/features/shop/providers/test_kit_products_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionDetailsPage extends ConsumerWidget {
  const SubscriptionDetailsPage({super.key});

  static const path = '/shop/subscription';

  Future<void> _openSubscription(BuildContext context, WidgetRef ref) async {
    final products = ref.read(testKitProductsProvider);
    final subscriptionProduct = products.firstWhere((product) => product.id == 'testosterone');
    final didOpen = await launchUrl(
      Uri.parse(subscriptionProduct.productUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!didOpen) {
      BotToast.showText(text: 'Unable to open the shop', align: Alignment.center);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F2),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverList.list(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF68686B),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text('Back', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Subscribe & save',
                    style: TextStyle(
                      color: Color(0xFF111113),
                      fontFamily: 'Times New Roman',
                      fontSize: 24,
                      height: 1,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SubscriptionSummaryCard(
                    onSubscribePressed: () => _openSubscription(context, ref),
                  ),
                  const SizedBox(height: 18),
                  const _SubscriptionBenefitsCard(),
                  const SizedBox(height: 34),
                  const MedicalDisclaimerFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({required this.onSubscribePressed});

  final VoidCallback onSubscribePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ELI PRO',
            style: TextStyle(
              color: Color(0xFF9BADF1),
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r'$13.50',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontSize: 38,
                  height: 0.95,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 3, bottom: 3),
                child: Text(
                  '/month',
                  style: TextStyle(color: Color(0xFF6F6F72), fontSize: 14, height: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            r'vs $15 per kit · save 10% · cancel any time',
            style: TextStyle(color: Color(0xFF6F6F72), fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: onSubscribePressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF050505),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Subscribe now'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBenefitsCard extends StatelessWidget {
  const _SubscriptionBenefitsCard();

  static const _benefits = [
    '3 cortisol strips per month',
    'Priority AI analysis (same day)',
    'Monthly PDF hormone report',
    '10% off all kit add-ons',
    'Access to Eli coach insights',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WHAT'S INCLUDED",
            style: TextStyle(
              color: Color(0xFF77777A),
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 17),
          for (var index = 0; index < _benefits.length; index++) ...[
            _BenefitRow(label: _benefits[index]),
            if (index < _benefits.length - 1) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF20A75B), size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF202023), fontSize: 14, height: 1.2),
          ),
        ),
      ],
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(26),
  boxShadow: const [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 14,
      offset: Offset(0, 5),
    ),
  ],
);

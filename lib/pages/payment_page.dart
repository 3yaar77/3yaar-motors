import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/providers/plate_provider.dart';
import 'package:autoreel/providers/reel_provider.dart';
import 'package:autoreel/providers/listings_provider.dart';
import 'package:autoreel/services/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Payment/Upgrade screen with package + method selection
/// Applies upgrade locally (no backend) and navigates back to details page
class PaymentPage extends StatefulWidget {
  final String listingId;
  final String listingType; // car | plate | image | reel | new (pre-publish flow)
  final String? initialPackage; // Optional preselected package: featured | vip | urgent | topBoost
  const PaymentPage({super.key, required this.listingId, required this.listingType, this.initialPackage});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? _selectedPackage; // featured | vip | urgent | topBoost
  String? _selectedMethod; // card | apple_pay

  void _togglePackage(String value) => setState(() => _selectedPackage = value);
  void _toggleMethod(String value) => setState(() => _selectedMethod = value);

  @override
  void initState() {
    super.initState();
    // Preselect a package if provided (used by pre-publish flow from New Listing pages)
    if (widget.initialPackage != null && widget.initialPackage!.isNotEmpty) {
      _selectedPackage = widget.initialPackage;
    }
  }

  Future<void> _applyUpgradeLocally() async {
    // Disabled: Do not activate VIP/Featured/Urgent locally. Real activation must happen
    // only after verified payment updates Firestore via backend.
  }

  void _onPayNow() async {
    if (_selectedPackage == null || _selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select package and payment method')),
      );
      return;
    }

    // Start real checkout via Firebase Function (Stripe Checkout)
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      final service = PaymentService();
      final res = await service.startStripeCheckout(listingId: widget.listingId, selectedPlan: _selectedPackage!, userId: uid);
      if (!res.success || (res.checkoutUrl ?? '').isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? 'Payment start failed')));
        return;
      }

      final url = res.checkoutUrl!;
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open payment page')));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete payment in the opened page...')));

      // Poll listing until webhook marks it paid
      final paid = await service.waitUntilPaid(listingId: widget.listingId, timeout: const Duration(minutes: 5));
      if (!mounted) return;
      if (paid) {
        // Close and indicate success
        context.pop(true);
      } else {
        // Still unpaid; remain pending
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment not confirmed yet. Listing stays pending.')));
        context.pop(false);
      }
    } catch (e) {
      debugPrint('PaymentPage _onPayNow error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MarketplaceColors.upgradeGold),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Upgrade Listing'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Packages
            Text('Choose an upgrade package', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            _PackageCard(
              title: 'Featured Listing',
              priceLabel: 'AED 50',
              description: 'Show listing in Featured section',
              value: 'featured',
              selected: _selectedPackage == 'featured',
              onTap: () => _togglePackage('featured'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PackageCard(
              title: 'VIP Listing',
              priceLabel: 'AED 100',
              description: 'Add VIP badge and priority visibility',
              value: 'vip',
              selected: _selectedPackage == 'vip',
              onTap: () => _togglePackage('vip'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PackageCard(
              title: 'Urgent Listing',
              priceLabel: 'AED 30',
              description: 'Add Urgent badge',
              value: 'urgent',
              selected: _selectedPackage == 'urgent',
              onTap: () => _togglePackage('urgent'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PackageCard(
              title: 'Top Boost',
              priceLabel: 'AED 75',
              description: 'Move listing to the top',
              value: 'topBoost',
              selected: _selectedPackage == 'topBoost',
              onTap: () => _togglePackage('topBoost'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Payment methods
            Text('Payment method', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.credit_card,
                  label: 'Card',
                  value: 'card',
                  selected: _selectedMethod == 'card',
                  onTap: () => _toggleMethod('card'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MethodCard(
                  icon: Icons.phone_iphone,
                  label: 'Apple Pay',
                  value: 'apple_pay',
                  selected: _selectedMethod == 'apple_pay',
                  onTap: () => _toggleMethod('apple_pay'),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xl),

            // Pay button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onPayNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketplaceColors.upgradeGold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  elevation: 0,
                ).copyWith(splashFactory: NoSplash.splashFactory),
                child: const Text('Pay Now'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Info note (local-only)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: MarketplaceColors.luxBorder)),
              child: Text('You will be redirected to a secure checkout. Apple Pay and cards are supported.', style: t.labelSmall?.copyWith(color: Colors.white70)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final String description;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _PackageCard({required this.title, required this.priceLabel, required this.description, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final borderColor = selected ? MarketplaceColors.upgradeGold : MarketplaceColors.luxBorder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(description, style: t.bodyMedium?.copyWith(color: Colors.white70)),
            ]),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Text(priceLabel, style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({required this.icon, required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final borderColor = selected ? MarketplaceColors.upgradeGold : MarketplaceColors.luxBorder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

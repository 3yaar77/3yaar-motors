import 'package:flutter/material.dart';
import 'package:autoreel/theme.dart';

class UpgradesPage extends StatefulWidget {
  const UpgradesPage({super.key});

  @override
  State<UpgradesPage> createState() => _UpgradesPageState();
}

class _UpgradesPageState extends State<UpgradesPage> {
  void _handleSelectPlan(String title, int price) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a listing to upgrade')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrades', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PlanCard(
            title: 'Free Listing',
            price: 0,
            benefits: const ['Standard placement', 'Visible in search'],
            accent: Colors.white,
            busy: false,
            onSelect: () => _handleSelectPlan('Free listing', 0),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanCard(
            title: 'Urgent Listing',
            price: 19,
            benefits: const ['Urgent badge', 'Attention-grabbing label'],
            accent: MarketplaceColors.upgradeGold,
            busy: false,
            onSelect: () => _handleSelectPlan('Urgent listing', 19),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanCard(
            title: 'VIP Listing',
            price: 29,
            benefits: const ['VIP badge', 'Priority exposure'],
            accent: MarketplaceColors.upgradeGold,
            busy: false,
            onSelect: () => _handleSelectPlan('VIP listing', 29),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanCard(
            title: 'Featured Listing',
            price: 49,
            benefits: const ['Featured placement', 'Boosted visibility'],
            accent: MarketplaceColors.upgradeGold,
            busy: false,
            onSelect: () => _handleSelectPlan('Featured listing', 49),
          ),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final int price;
  final List<String> benefits;
  final Color accent;
  final VoidCallback onSelect;
  final bool busy;
  const _PlanCard({required this.title, required this.price, required this.benefits, required this.accent, required this.onSelect, required this.busy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFree = price <= 0; // kept for potential styling logic, label is unified
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.workspace_premium, color: Colors.black),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 6, children: benefits.map((b) => _BenefitChip(label: b)).toList()),
          ])),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
            child: Text('AED $price', style: context.textStyles.labelSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: busy ? null : onSelect,
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceColors.upgradeGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              elevation: 0,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: Text('Select Plan', style: context.textStyles.titleSmall?.bold.withColor(Colors.black)),
          ),
        ),
      ]),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;
  const _BenefitChip({required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

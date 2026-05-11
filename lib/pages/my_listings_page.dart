import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/providers/notification_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/pages/feed_page.dart';

class MyListingsPage extends StatelessWidget {
  const MyListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.currentUser?.uid;
    final cars = context.select<CarProvider, List<Car>>((p) => p.cars.where((c) => c.ownerId == uid).toList());
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 90),
        itemCount: cars.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (ctx, i) {
          final car = cars[i];
          return Card(
            color: scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: scheme.outline.withValues(alpha: 0.18))),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: scheme.surface, child: const Icon(Icons.directions_car)),
              title: Text('${car.make} ${car.model}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('AED ${car.price} • ${car.location} • ${car.status}'),
              onTap: () => context.pushNamed('car_details', pathParameters: {'id': car.id}, extra: car),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => _onAction(context, v, car),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'upgrade', child: Text('Upgrade')),
                  if (car.status != 'sold') const PopupMenuItem(value: 'sold', child: Text('Mark as Sold')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onAction(BuildContext context, String action, Car car) async {
    final provider = context.read<CarProvider>();
    switch (action) {
      case 'edit':
        _showEditSheet(context, car);
        break;
      case 'upgrade':
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).colorScheme.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
          builder: (_) => UpgradeListingSheet(car: car),
        );
        break;
      case 'sold':
        await provider.markSold(car.id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as sold')));
        break;
      case 'delete':
        await provider.deleteCar(car.id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
        break;
    }
  }

  void _showEditSheet(BuildContext context, Car car) {
    final priceCtrl = TextEditingController(text: car.price.toString());
    final mileageCtrl = TextEditingController(text: car.mileage.toString());
    final descCtrl = TextEditingController(text: car.description);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => Padding(
        padding: MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Edit Listing', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (AED)')),
          const SizedBox(height: 8),
          TextField(controller: mileageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mileage (km)')),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async {
            final p = int.tryParse(priceCtrl.text.replaceAll(',', '')) ?? car.price;
            final m = int.tryParse(mileageCtrl.text.replaceAll(',', '')) ?? car.mileage;
            final updated = car.copyWith(price: p, mileage: m, description: descCtrl.text.trim());
            await context.read<CarProvider>().updateCar(car.id, updated);
            if (context.mounted) Navigator.of(ctx).pop();
          }, icon: const Icon(Icons.save, color: Colors.white), label: const Text('Save Changes'))),
        ]),
      ),
    );
  }
}

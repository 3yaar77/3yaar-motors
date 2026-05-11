import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/theme.dart';

class AdminReviewPage extends StatelessWidget {
  const AdminReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final scheme = Theme.of(context).colorScheme;
    final pending = context.select<CarProvider, List<Car>>((p) => p.cars.where((c) => c.status == 'pending_review').toList());
    if (!isAdmin) {
      return Scaffold(appBar: AppBar(title: const Text('Admin Review')), body: const Center(child: Text('Admin access required')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Review')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (ctx, i) {
          final car = pending[i];
          return Card(
            color: scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: scheme.outline.withValues(alpha: 0.18))),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: scheme.surface, child: const Icon(Icons.pending_actions)),
              title: Text('${car.make} ${car.model}'),
              subtitle: Text('AED ${car.price} • ${car.location}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Approve', onPressed: () => _setStatus(ctx, car, 'active'), icon: const Icon(Icons.check_circle, color: Colors.green)),
                IconButton(tooltip: 'Reject', onPressed: () => _setStatus(ctx, car, 'rejected'), icon: const Icon(Icons.cancel, color: Colors.redAccent)),
                IconButton(tooltip: 'Delete', onPressed: () => _delete(ctx, car), icon: const Icon(Icons.delete_outline)),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _setStatus(BuildContext context, Car car, String status) async {
    await context.read<CarProvider>().setStatus(car.id, status);
    // Optionally notify owner here via Firestore in the future
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Listing ${status == 'active' ? 'approved' : 'rejected'}')));
  }

  void _delete(BuildContext context, Car car) async {
    await context.read<CarProvider>().deleteCar(car.id);
    // Optionally notify owner here via Firestore in the future
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
  }
}

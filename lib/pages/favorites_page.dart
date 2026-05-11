import 'package:autoreel/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/pages/feed_page.dart';
import 'package:autoreel/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/nav.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Require login to view Favorites
    final isLoggedIn = context.select<AuthProvider, bool>((p) => p.isLoggedIn);
    if (!isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.goNamed('login', queryParameters: {'redirect': AppRoutes.favorites});
        }
      });
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<CarProvider>(
        builder: (context, provider, _) {
          final favs = provider.favoriteCars;
          if (favs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 48, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text('No favorites yet', style: context.textStyles.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Tap the heart on a car to add it here.', style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.68,
            ),
            itemCount: favs.length,
            itemBuilder: (context, index) => CarGridCard(car: favs[index]),
          );
        },
      ),
    );
  }
}

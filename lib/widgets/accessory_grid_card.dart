import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/accessory_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/utils/image_url_utils.dart';

class AccessoryGridCard extends StatelessWidget {
  final Accessory accessory;
  const AccessoryGridCard({super.key, required this.accessory});

  @override
  Widget build(BuildContext context) {
    final raw = accessory.images.isNotEmpty ? accessory.images.first : '';
    final img = ImageUrlUtils.isValidFirebaseDownload(raw) ? raw : '';
    return GestureDetector(
      onTap: () => context.pushNamed('accessory_details', pathParameters: {'id': accessory.id}),
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              child: img.isEmpty
                  ? Container(
                      color: Colors.black.withValues(alpha: 0.2),
                      child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white54)),
                    )
                  : Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black.withValues(alpha: 0.2),
                        child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54)),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                accessory.title.isNotEmpty ? accessory.title : 'Accessory',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Text(
                  accessory.price > 0 ? 'AED ${accessory.price}' : 'AED -',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: MarketplaceColors.accentYellow,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 8),
                _Chip(text: accessory.condition.isNotEmpty ? accessory.condition : '—'),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    accessory.location.isNotEmpty ? accessory.location : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
    );
  }
}

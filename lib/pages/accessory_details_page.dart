import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/accessory_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/services/accessory_service.dart';
import 'package:autoreel/services/image_storage_service.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/utils/image_url_utils.dart';

class AccessoryDetailsPage extends StatelessWidget {
  final String accessoryId;
  const AccessoryDetailsPage({super.key, required this.accessoryId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccessoryProvider>();
    final acc = provider.items.firstWhere((e) => e.id == accessoryId,
        orElse: () => Accessory(
              id: '',
              title: '',
              price: 0,
              condition: '',
              category: '',
              description: '',
              images: const [],
              location: '',
              sellerPhone: '',
              ownerId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));

    if (acc.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accessory')),
        body: const Center(
            child: Text('Accessory not found',
                style: TextStyle(color: Colors.white70))),
      );
    }

    final isOwner =
        context.read<AuthProvider>().currentUser?.uid == acc.ownerId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(acc.title.isNotEmpty ? acc.title : 'Accessory'),
        actions: [
          if (isOwner)
            IconButton(
              icon:
                  const Icon(Icons.edit, color: MarketplaceColors.accentYellow),
              onPressed: () => context
                  .pushNamed('new_accessory', queryParameters: {'id': acc.id}),
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete listing?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    ) ??
                    false;
                if (!ok) return;
                try {
                  // delete storage files best-effort
                  for (final u in acc.images) {
                    await ImageStorageService.deleteByUrl(u);
                  }
                  await AccessoryService().delete(acc.id);
                  if (context.mounted) context.pop();
                } catch (e) {
                  debugPrint('Delete accessory error: $e');
                }
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 280,
            child: PageView.builder(
              itemCount: acc.images.isEmpty ? 1 : acc.images.length,
              itemBuilder: (context, index) {
                final raw = acc.images.isEmpty ? '' : acc.images[index];
                final img = ImageUrlUtils.isValidFirebaseDownload(raw) ? raw : '';
                return img.isEmpty
                    ? Container(
                        color: Colors.black,
                        child: const Center(
                            child: Icon(Icons.image,
                                color: Colors.white54, size: 48)),
                      )
                    : Image.network(img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: Colors.black,
                              child: const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white54, size: 48)),
                            ));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(acc.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('AED ${acc.price}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: MarketplaceColors.accentYellow,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _Chip(text: acc.condition.isNotEmpty ? acc.condition : '—'),
                const SizedBox(width: 8),
                _Chip(text: acc.category.isNotEmpty ? acc.category : '—'),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.place, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(acc.location.isNotEmpty ? acc.location : '—',
                    style: const TextStyle(color: Colors.white70)),
              ]),
              const SizedBox(height: 12),
              Text(
                  acc.description.isNotEmpty
                      ? acc.description
                      : 'No description',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.phone, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(acc.sellerPhone.isNotEmpty ? acc.sellerPhone : '—',
                    style: const TextStyle(color: Colors.white70)),
              ]),
            ]),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

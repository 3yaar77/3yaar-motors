import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:autoreel/nav.dart';

class PublicProfilePage extends StatelessWidget {
  final String sellerId;
  final String? sellerName;
  final String? sellerPhone;
  final String? listingId;
  final String? listingTitle;
  const PublicProfilePage({super.key, required this.sellerId, this.sellerName, this.sellerPhone, this.listingId, this.listingTitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final display = (sellerName != null && sellerName!.trim().isNotEmpty) ? sellerName!.trim() : '@$sellerId';

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Profile'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 12),
            CircleAvatar(radius: 44, backgroundColor: MarketplaceColors.accentYellow, child: const Icon(Icons.person, color: Colors.black, size: 44)),
            const SizedBox(height: AppSpacing.md),
            Text(display, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            if (sellerPhone != null && sellerPhone!.isNotEmpty)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone, size: 16),
                const SizedBox(width: 6),
                Text(sellerPhone!, style: Theme.of(context).textTheme.bodyMedium),
              ]),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isLoggedIn) {
                    context.goNamed('login', queryParameters: {'redirect': AppRoutes.userProfile.replaceFirst(':id', sellerId)});
                    return;
                  }
                  final me = auth.currentUser!.uid;
                  final chat = context.read<LocalChatProvider>();
                  final conv = chat.ensureConversation(
                    listingId: listingId ?? 'reel-$sellerId',
                    listingTitle: (listingTitle == null || listingTitle!.isEmpty) ? 'Listing' : listingTitle!,
                    sellerId: sellerId,
                    sellerName: sellerName ?? (sellerId.isNotEmpty ? '@$sellerId' : 'Seller'),
                    sellerPhone: sellerPhone ?? '',
                    buyerId: me,
                  );
                  context.pushNamed('chat', pathParameters: {'id': conv.id});
                },
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text('Message'),
                style: FilledButton.styleFrom(backgroundColor: MarketplaceColors.accentYellow, foregroundColor: Colors.black, padding: AppSpacing.paddingMd, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

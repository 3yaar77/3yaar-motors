import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/messages_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = context.select<MessagesProvider, int>((p) => p.unreadCount);
    final uid = context.select<AuthProvider, String?>((p) => p.currentUser?.uid);
    final convs = context.select<LocalChatProvider, List<Conversation>>((p) => p.conversationsForUser(uid ?? 'guest'));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [MarketplaceColors.luxBgGradientStart, MarketplaceColors.luxBgGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: convs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: MarketplaceColors.accentYellow, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))]),
                      child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 16),
                    Text('No messages yet', style: context.textStyles.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Contact sellers from listing pages', textAlign: TextAlign.center, style: context.textStyles.bodyMedium?.copyWith(color: Colors.white70, height: 1.5)),
                    if (unread > 0) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                        child: Text('$unread unread', style: context.textStyles.labelMedium?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.w800)),
                      )
                    ]
                  ]),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: convs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = convs[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.pushNamed('chat', pathParameters: {'id': c.id}),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                        child: Row(children: [
                          Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.white)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(c.lastMessage ?? 'Tap to chat', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.labelSmall?.copyWith(color: Colors.white70)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

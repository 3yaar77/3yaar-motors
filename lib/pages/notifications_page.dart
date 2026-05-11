import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/notification_provider.dart';
import 'package:autoreel/theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.items;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(onPressed: provider.unreadCount > 0 ? provider.markAllRead : null, child: const Text('Mark all read')),
      ]),
      body: items.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (ctx, i) {
                final n = items[i];
                final isLike = (n.type == 'like');
                final icon = isLike ? Icons.favorite : Icons.mode_comment_outlined;
                return ListTile(
                  onTap: () {
                    if (n.listingId.isEmpty) return;
                    context.pushNamed('car_details', pathParameters: {'id': n.listingId});
                  },
                  leading: Icon(icon, color: isLike ? Colors.red : Colors.white),
                  title: Text(n.message),
                  trailing: Text(_fmt(n.createdAt), style: Theme.of(ctx).textTheme.labelSmall),
                );
              },
            ),
    );
  }

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

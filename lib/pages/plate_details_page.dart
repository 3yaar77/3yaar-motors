import 'package:flutter/material.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/plate_provider.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/utils/launch_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/widgets/real_uae_plate.dart';
import 'package:autoreel/utils/format_utils.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlateDetailsPage extends StatelessWidget {
  final String plateId;
  final Plate? initialPlate;

  const PlateDetailsPage({super.key, required this.plateId, this.initialPlate});

  String _formatPrice(int price) {
    if (price <= 0) return 'Call for price';
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w ago';
  }

  int _viewsEstimate(Plate p) {
    final days = DateTime.now().difference(p.createdAt).inDays;
    final seed = p.id.hashCode.abs() % 40;
    final v = days * 12 + seed;
    return v < 0 ? 0 : v;
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 7) {
      final keep = digits.length >= 3 ? 3 : 1;
      final end = digits.length >= 2 ? 2 : 1;
      final start = digits.substring(0, keep);
      final tail = digits.substring(digits.length - end);
      return '${start}xxx${tail}';
    }
    final start = digits.substring(0, 3);
    final tail = digits.substring(digits.length - 4);
    return '${start}xxx${tail}';
  }

  @override
  Widget build(BuildContext context) {
    final plate =
        context.select<PlateProvider, Plate?>((p) => p.byId(plateId)) ??
            initialPlate;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Plate Details'),
        actions: [
          if (plate != null)
            IconButton(
              onPressed: () =>
                  context.read<PlateProvider>().toggleLike(plate.id),
              icon: Icon(plate.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: plate.isLiked ? Colors.red : Colors.white),
              tooltip: 'Favorite',
            ),
        ],
      ),
      body: plate == null
          ? Center(
              child: Text('Plate not found',
                  style: context.textStyles.titleMedium))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Large plate display with SOLD badge if applicable
                    Center(
                      child: Stack(alignment: Alignment.topLeft, children: [
                        SizedBox(
                          height: 95,
                          child: RealUaePlate(
                            emirate: plate.emirate,
                            plateNumber: plate.plateNumber,
                            height: 95,
                          ),
                        ),
                        if (plate.description.toLowerCase().contains('sold'))
                          Positioned(
                            top: -4,
                            left: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: DarkModeColors.darkError,
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('SOLD',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                          ),
                        if (plate.isVip || plate.isFeatured || plate.isUrgent)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                              child: Text(
                                plate.isVip
                                    ? 'VIP'
                                    : plate.isFeatured
                                        ? 'Featured'
                                        : 'Urgent',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Price
                    Text(
                      _formatPrice(plate.price),
                      style: context.textStyles.headlineSmall?.copyWith(
                          color: MarketplaceColors.accentYellow,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Info rows
                    _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'Emirate',
                        value: plate.emirate),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Plate',
                        value: plate.plateNumber),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                        icon: Icons.remove_red_eye_outlined,
                        label: 'Views',
                        value: formatCompactCount(plate.viewsCount)),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                        icon: Icons.schedule,
                        label: 'Posted',
                        value: _timeAgo(plate.createdAt)),
                    const SizedBox(height: AppSpacing.lg),
                    // Description
                    if (plate.description.trim().isNotEmpty) ...[
                      Text('Description',
                          style: context.textStyles.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(plate.description,
                          style: context.textStyles.bodyMedium),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    // Seller section
                    Text('Seller',
                        style: context.textStyles.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person,
                                color: Colors.black.withValues(alpha: 0.8))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('Private seller',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  if (plate.sellerVerified) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.verified,
                                        color: MarketplaceColors.accentYellow,
                                        size: 16),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(_maskPhone(plate.sellerPhone),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                              ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Action buttons: Call (yellow), WhatsApp (green), Message (optional)
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final cleaned = cleanUaePhone(plate.sellerPhone);
                            if (cleaned.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Seller phone number is not available')));
                              }
                              return;
                            }
                            final ok = await openPhoneCall(plate.sellerPhone);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Could not start call.')));
                            }
                          },
                          icon: const Icon(Icons.call, color: Colors.black),
                          label: const Text('Call Seller'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MarketplaceColors.accentYellow,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg)),
                          ).copyWith(splashFactory: NoSplash.splashFactory),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final cleaned = cleanUaePhone(plate.sellerPhone);
                            if (cleaned.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Seller phone number is not available')));
                              }
                              return;
                            }
                            final ok = await openWhatsAppWaMe(
                              plate.sellerPhone,
                              message: 'Hi, I am interested in your listing',
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Could not open WhatsApp.')));
                            }
                          },
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg)),
                          ).copyWith(splashFactory: NoSplash.splashFactory),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final loggedIn = context.read<AuthProvider>().isLoggedIn;
                          if (!loggedIn) {
                            context.pushNamed('login', queryParameters: {'redirect': '/plate/${plate.id}'});
                            return;
                          }
                          final uid = context.read<AuthProvider>().currentUser?.uid ?? 'guest';
                          final sellerId = plate.sellerPhone.isNotEmpty ? plate.sellerPhone : 'seller-${plate.id}';
                          final listingTitle = 'Plate ${plate.plateNumber}';
                          final conv = context.read<LocalChatProvider>().ensureConversation(
                                listingId: plate.id,
                                listingTitle: listingTitle,
                                sellerId: sellerId,
                                sellerName: 'Seller',
                                sellerPhone: plate.sellerPhone,
                                buyerId: uid,
                              );
                          context.pushNamed('chat', pathParameters: {'id': conv.id});
                          // Optional: auto-reply once for UX
                          context.read<LocalChatProvider>().maybeAutoReply(conv.id, 'Thanks for your message! The seller will respond soon.');
                        },
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12)),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg)),
                        ).copyWith(splashFactory: NoSplash.splashFactory),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Upgrade button visible only when local ownerId == current user
                    if ((context.read<AuthProvider>().currentUser?.uid ?? '') == plate.ownerId)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.pushNamed('payment', queryParameters: {'id': plate.id, 'type': 'plate'}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MarketplaceColors.upgradeGold,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ).copyWith(splashFactory: NoSplash.splashFactory),
                          child: const Text('Upgrade Listing'),
                        ),
                      ),
                  ]),
            ),
    );
  }
}

class _PlateVisual extends StatelessWidget {
  final String emirate;
  final String plateNumber;
  const _PlateVisual({required this.emirate, required this.plateNumber});

  (String code, String number) _split(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts.first, parts.sublist(1).join(' '));
    return ('', s.trim());
  }

  @override
  Widget build(BuildContext context) {
    final (code, number) = _split(plateNumber);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Left: UAE + Emirate small box
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('UAE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1)),
              SizedBox(height: 2),
            ]),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emirate,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        const SizedBox(height: 4),
        Row(children: [
          if (code.isNotEmpty)
            Text(code,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black)),
          if (code.isNotEmpty) const SizedBox(width: 8),
          Text(number,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.black)),
        ]),
      ]),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

class _PlateUpgradeSheet extends StatelessWidget {
  final VoidCallback onClose;
  const _PlateUpgradeSheet({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upgrade Listing',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            _UpgradeOption(
                title: '🔥 VIP - 70 AED',
                subtitle: 'Promote for 7 days',
                onTap: onClose),
            _UpgradeOption(
                title: '⭐ Featured - 20 AED',
                subtitle: 'Promote for 3 days',
                onTap: onClose),
            _UpgradeOption(
                title: '📌 Pin - 10 AED',
                subtitle: 'Pin for 1 day',
                onTap: onClose),
            const SizedBox(height: AppSpacing.sm),
          ]),
    );
  }
}

class _UpgradeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _UpgradeOption(
      {required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.15))),
      child: ListTile(
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: const Text('Upgrade Now'),
        ),
      ),
    );
  }
}

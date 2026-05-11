import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/providers/notification_provider.dart';
import 'package:autoreel/utils/launch_utils.dart';
import 'package:flutter/services.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:autoreel/utils/image_url_utils.dart';

class CarDetailsPage extends StatelessWidget {
  final String carId;
  final Car? initialCar;
  final List<String>? imageUrls;
  const CarDetailsPage({super.key, required this.carId, this.initialCar, this.imageUrls});

  String _formatPrice(int price) {
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  String _formatMileage(int mileage) {
    final s = mileage.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final provided = initialCar;
    final car = provided ?? context.select<CarProvider, Car?>(
      (p) {
        try {
          return p.byId(carId);
        } catch (_) {
          return null;
        }
      },
    );

    if (car == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Details')),
        body: const Center(child: Text('Car not found')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final imgs = (imageUrls ?? const <String>[]);
    final primaryUrl = imgs.isNotEmpty ? imgs.first : (car.images.isNotEmpty ? car.images.first : '');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
            actions: [
              IconButton(
                icon: Icon(car.isLiked ? Icons.favorite : Icons.favorite_border, color: car.isLiked ? Colors.red : colorScheme.onSurface),
                onPressed: () async {
                  final loggedIn = context.read<AuthProvider>().isLoggedIn;
                  if (!loggedIn) {
                    context.pushNamed('login', queryParameters: {'redirect': '/car/${car.id}'});
                    return;
                  }
                  final wasLiked = car.isLiked;
                  await context.read<CarProvider>().toggleLike(car.id);
                  // If this action resulted in a like, create a notification for the seller
                  if (!wasLiked) {
                    try {
                      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
                      final snap = await FirebaseFirestore.instance.collection('listings').doc(carId).get();
                      final data = snap.data() ?? <String, dynamic>{};
                      final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
                      if (ownerId.isNotEmpty && ownerId != uid) {
                        final title = '${car.make} ${car.model}'.trim();
                        await context.read<NotificationProvider>().createLike(
                              userId: ownerId,
                              listingId: car.id,
                              message: 'Someone liked your listing: $title',
                            );
                      }
                    } catch (e) {
                      debugPrint('Like notification error: $e');
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () async {
                  final url = 'https://uae-cars.example/car/$carId';
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                  }
                },
              ),
              // Delete icon only visible for the owner of the listing
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('listings').doc(carId).get(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final data = snap.data!.data() ?? <String, dynamic>{};
                  final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
                  final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
                  final canDelete = ownerId.isNotEmpty && uid.isNotEmpty && ownerId == uid;
                  if (!canDelete) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete listing?'),
                          content: const Text('Are you sure you want to delete this listing?'),
                          actions: [
                            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
                            TextButton(onPressed: () => ctx.pop(true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        // Fetch doc to collect all image URLs
                        final doc = await FirebaseFirestore.instance.collection('listings').doc(carId).get();
                        final dd = doc.data() ?? <String, dynamic>{};
                        final Set<String> urls = <String>{};
                        void addUrl(dynamic v) {
                          final s = (v ?? '').toString().trim();
                          if (s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://'))) urls.add(s);
                        }
                        addUrl(dd['coverImageUrl']);
                        addUrl(dd['image']);
                        addUrl(dd['imageUrl']);
                        final iu = dd['imageUrls'];
                        if (iu is List) {
                          for (final e in iu) addUrl(e);
                        }
                        final im = dd['images'];
                        if (im is List) {
                          for (final e in im) addUrl(e);
                        }
                        // Try delete all storage files in parallel
                        final storage = FirebaseStorage.instance;
                        await Future.wait(urls.map((u) async {
                          try {
                            await storage.refFromURL(u).delete();
                          } catch (e) {
                            debugPrint('Storage delete failed for $u: $e');
                          }
                        }));
                        // Finally delete the document
                        await FirebaseFirestore.instance.collection('listings').doc(carId).delete();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
                        context.go(AppRoutes.home);
                      } catch (e) {
                        debugPrint('Delete listing error: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                        }
                      }
                    },
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('listings').doc(carId).get(),
                builder: (context, snap) {
                  // New rule: use images[0] only; ignore legacy fields
                  List<String> urls = <String>[];
                  String? videoUrl;
                  final fallbackImgs = (imageUrls ?? const <String>[]);
                  if (snap.hasData) {
                    final data = snap.data!.data() ?? <String, dynamic>{};
                    String san(dynamic v) => ImageUrlUtils.sanitize((v ?? '').toString());
                    List<String> sanAll(dynamic v) => v is List ? ImageUrlUtils.sanitizeAll(v) : <String>[];
                    final listImages = sanAll(data['images']);
                    bool isHttp(String u) => u.toLowerCase().startsWith('http');
                    void addIfHttp(String u) {
                      final t = ImageUrlUtils.sanitize(u);
                      if (t.isEmpty) return;
                      if (!isHttp(t)) return;
                      if (!urls.contains(t)) urls.add(t);
                    }
                    bool addIfValid(String u) {
                      final t = ImageUrlUtils.sanitize(u);
                      if (ImageUrlUtils.isValidFirebaseDownload(t) && !urls.contains(t)) { urls.add(t); return true; }
                      return false;
                    }
                    for (final u in listImages) { addIfValid(u); }
                    for (final u in fallbackImgs) { addIfValid(u); }
                    final vu = data['videoUrls'];
                    if (vu is List && vu.isNotEmpty) {
                      videoUrl = vu.first?.toString();
                    }
                  } else {
                    for (final u in fallbackImgs) {
                      final t = ImageUrlUtils.sanitize(u);
                      if (t.toLowerCase().startsWith('http') && !urls.contains(t)) urls.add(t);
                    }
                  }

                  // Quick diagnostics to verify resolved header image(s)
                  try { debugPrint('CarDetails header urls: count=${urls.length} first=${urls.isNotEmpty ? urls.first : '(none)'}'); } catch (_) {}

                  return Stack(fit: StackFit.expand, children: [
                    if (urls.length <= 1)
                      Builder(builder: (context) {
                        if (urls.isEmpty) {
                          // Placeholder only when empty; no icons
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          );
                        }
                        final first = urls.first;
                        if (ImageUrlUtils.isValidFirebaseDownload(first)) {
                          return Image.network(
                            first,
                            key: ValueKey(first),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                          );
                        }
                        // Non-https → neutral placeholder
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        );
                      })
                    else
                      PageView.builder(
                        itemCount: urls.length,
                        itemBuilder: (_, i) {
                          final u = urls[i];
                          if (ImageUrlUtils.isValidFirebaseDownload(u)) {
                            return Image.network(
                              u,
                              key: ValueKey(u),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                            );
                          }
                          // Non-https → neutral placeholder
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          );
                        },
                      ),
                    // Gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54, Colors.black87], stops: [0.4, 0.8, 1.0]),
                      ),
                    ),
                    // Photo count badge (bottom-right)
                    if (urls.isNotEmpty)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                          child: Text('${urls.length} photos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    // Play button if video exists
                    if ((videoUrl ?? '').isNotEmpty)
                      Positioned(
                        right: 10,
                        top: MediaQuery.paddingOf(context).top + 56,
                        child: GestureDetector(
                          onTap: () {
                            final url = videoUrl!;
                            context.push(AppRoutes.listingVideos); // reuse existing full-screen videos page
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow, color: Colors.white),
                          ),
                        ),
                      ),
                    // Bottom title/price overlay
                    Positioned(
                      left: AppSpacing.md,
                      bottom: AppSpacing.lg,
                      right: AppSpacing.md,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.inversePrimary])),
                                child: Text(_formatPrice(car.price), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance.collection('listings').doc(carId).get(),
                                builder: (context, snap) {
                                  if (!snap.hasData) return const SizedBox.shrink();
                                  final d = snap.data!.data() ?? <String, dynamic>{};
                                  final isVip = (d['isVip'] as bool?) ?? false;
                                  final isFeatured = (d['isFeatured'] as bool?) ?? false;
                                  final isUrgent = (d['isUrgent'] as bool?) ?? false;
                                  if (!(isVip || isFeatured || isUrgent)) return const SizedBox.shrink();
                                  final label = isVip ? 'VIP' : isFeatured ? 'Featured' : 'Urgent';
                                  final Color bg = isVip ? MarketplaceColors.upgradeGold : isFeatured ? MarketplaceColors.featured : MarketplaceColors.urgent;
                                  final Color fg = isVip ? Colors.black : Colors.white;
                                  return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)));
                                },
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text('${car.make} ${car.model}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ]),
                    ),
                  ]);
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                
                Row(children: [
                  _SpecChip(icon: Icons.calendar_today, label: car.year.toString()),
                  const SizedBox(width: AppSpacing.sm),
                  _SpecChip(icon: Icons.speed, label: _formatMileage(car.mileage)),
                  const SizedBox(width: AppSpacing.sm),
                  _SpecChip(icon: Icons.location_on, label: car.location),
                ]),
                const SizedBox(height: AppSpacing.lg),
                Text('Overview', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(label: 'Make', value: car.make),
                _DetailRow(label: 'Model', value: car.model),
                _DetailRow(label: 'Year', value: car.year.toString()),
                _DetailRow(label: 'Mileage', value: _formatMileage(car.mileage)),
                _DetailRow(label: 'Location', value: car.location),
                const SizedBox(height: AppSpacing.lg),
                Text('Description', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                Text(car.description, style: context.textStyles.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                Row(children: [
                  const Icon(Icons.phone, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(car.sellerPhone, style: context.textStyles.titleMedium),
                ]),
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final cleaned = cleanUaePhone(car.sellerPhone);
                        if (cleaned.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller phone number is not available')));
                          }
                          return;
                        }
                        final ok = await openPhoneCall(car.sellerPhone);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start call.')));
                        }
                      },
                      icon: const Icon(Icons.call, color: Colors.black),
                      label: Text('Call Seller', style: context.textStyles.titleMedium?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MarketplaceColors.accentYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final cleaned = cleanUaePhone(car.sellerPhone);
                        if (cleaned.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller phone number is not available')));
                          }
                          return;
                        }
                        final ok = await openWhatsAppWaMe(
                          car.sellerPhone,
                          message: 'Hi, I am interested in your listing',
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
                        }
                      },
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: Text('WhatsApp', style: context.textStyles.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
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
                        context.pushNamed('login', queryParameters: {'redirect': '/car/${car.id}'});
                        return;
                      }
                      final uid = context.read<AuthProvider>().currentUser?.uid ?? 'guest';
                      final sellerId = car.ownerId.isNotEmpty ? car.ownerId : (car.sellerPhone.isNotEmpty ? car.sellerPhone : 'seller-${car.id}');
                      final listingTitle = '${car.make} ${car.model}'.trim();
                      final conv = context.read<LocalChatProvider>().ensureConversation(
                            listingId: car.id,
                            listingTitle: listingTitle,
                            sellerId: sellerId,
                            sellerName: 'Seller',
                            sellerPhone: car.sellerPhone,
                            buyerId: uid,
                          );
                      context.pushNamed('chat', pathParameters: {'id': conv.id});
                      context.read<LocalChatProvider>().maybeAutoReply(conv.id, 'Thanks for your message! The seller will respond soon.');
                    },
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ).copyWith(splashFactory: NoSplash.splashFactory),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Owner-only actions: Edit, Delete, Upgrade/Promote (below info)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('listings').doc(carId).get(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final data = snap.data!.data() ?? <String, dynamic>{};
                    final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
                    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
                    final isOwner = ownerId.isNotEmpty && uid.isNotEmpty && ownerId == uid;
                    if (!isOwner) return const SizedBox.shrink();
                    return Column(children: [
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Navigate to the new listing page for editing (prefill flow can be added later)
                              context.pushNamed('new_listing', queryParameters: {'editId': car.id});
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Listing'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                            ).copyWith(splashFactory: NoSplash.splashFactory),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Open upgrade sheet to toggle VIP/Featured/Urgent and save to Firestore
                              final docRef = FirebaseFirestore.instance.collection('listings').doc(carId);
                              final latest = await docRef.get();
                              bool isVip = (latest.data()?['isVip'] as bool?) ?? false;
                              bool isFeatured = (latest.data()?['isFeatured'] as bool?) ?? false;
                              bool isUrgent = (latest.data()?['isUrgent'] as bool?) ?? false;
                              final bool origVip = isVip, origFeatured = isFeatured, origUrgent = isUrgent;
                              if (!context.mounted) return;
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
                                builder: (ctx) {
                                  return StatefulBuilder(builder: (ctx, setSt) {
                                    return SafeArea(
                                      child: Padding(
                                        padding: AppSpacing.paddingLg,
                                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('Upgrade / Promote Listing', style: context.textStyles.titleLarge?.bold),
                                          const SizedBox(height: AppSpacing.md),
                                          SwitchListTile(
                                            title: const Text('VIP', style: TextStyle(color: Colors.white)),
                                            value: isVip,
                                            onChanged: (v) => setSt(() => isVip = v),
                                            contentPadding: EdgeInsets.zero,
                                            activeColor: Colors.black,
                                            activeTrackColor: MarketplaceColors.upgradeGold,
                                          ),
                                          SwitchListTile(
                                            title: const Text('Featured', style: TextStyle(color: Colors.white)),
                                            value: isFeatured,
                                            onChanged: (v) => setSt(() => isFeatured = v),
                                            contentPadding: EdgeInsets.zero,
                                            activeColor: Colors.black,
                                            activeTrackColor: MarketplaceColors.featured,
                                          ),
                                          SwitchListTile(
                                            title: const Text('Urgent', style: TextStyle(color: Colors.white)),
                                            value: isUrgent,
                                            onChanged: (v) => setSt(() => isUrgent = v),
                                            contentPadding: EdgeInsets.zero,
                                            activeColor: Colors.black,
                                            activeTrackColor: MarketplaceColors.urgent,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                              onPressed: () async {
                                                try {
                                                  // Determine if a paid flag was enabled; allow turning flags off immediately
                                                  String? plan;
                                                  if (!origVip && isVip) plan = 'vip';
                                                  else if (!origFeatured && isFeatured) plan = 'featured';
                                                  else if (!origUrgent && isUrgent) plan = 'urgent';

                                                  // Persist any toggles that turned OFF without payment
                                                  if (origVip && !isVip || origFeatured && !isFeatured || origUrgent && !isUrgent) {
                                                    await docRef.update({'isVip': isVip, 'isFeatured': isFeatured, 'isUrgent': isUrgent});
                                                  }

                                                  if (plan != null) {
                                                    // Start payment for the newly enabled plan
                                                    await docRef.set({'selectedPlan': plan, 'paymentStatus': 'unpaid'}, SetOptions(merge: true));
                                                    if (context.mounted) {
                                                      Navigator.of(ctx).pop();
                                                      final ok = await context.pushNamed('payment', queryParameters: {'id': carId, 'type': 'car', 'pkg': plan});
                                                      if (ok == true) {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade activated after payment.')));
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment not completed. Upgrade not applied.')));
                                                      }
                                                    }
                                                  } else {
                                                    if (context.mounted) {
                                                      Navigator.of(ctx).pop();
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved')));
                                                    }
                                                  }
                                                } catch (e) {
                                                  debugPrint('Upgrade save error: $e');
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                                                  }
                                                }
                                              },
                                              style: FilledButton.styleFrom(
                                                backgroundColor: MarketplaceColors.accentYellow,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                                              ),
                                              child: const Text('Save'),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                        ]),
                                      ),
                                    );
                                  });
                                },
                              );
                            },
                            icon: const Icon(Icons.campaign, color: Colors.black),
                            label: Text('Upgrade / Promote', style: context.textStyles.titleMedium?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MarketplaceColors.upgradeGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete listing?'),
                                content: const Text('Are you sure you want to delete this listing?'),
                                actions: [
                                  TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => ctx.pop(true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            try {
                              final doc = await FirebaseFirestore.instance.collection('listings').doc(carId).get();
                              final dd = doc.data() ?? <String, dynamic>{};
                              final Set<String> urls = <String>{};
                              void addUrl(dynamic v) {
                                final s = (v ?? '').toString().trim();
                                if (s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://'))) urls.add(s);
                              }
                              addUrl(dd['coverImageUrl']);
                              addUrl(dd['image']);
                              addUrl(dd['imageUrl']);
                              final iu = dd['imageUrls'];
                              if (iu is List) {
                                for (final e in iu) addUrl(e);
                              }
                              final im = dd['images'];
                              if (im is List) {
                                for (final e in im) addUrl(e);
                              }
                              final storage = FirebaseStorage.instance;
                              await Future.wait(urls.map((u) async {
                                try {
                                  await storage.refFromURL(u).delete();
                                } catch (e) {
                                  debugPrint('Storage delete failed for $u: $e');
                                }
                              }));
                              await FirebaseFirestore.instance.collection('listings').doc(carId).delete();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
                              context.go(AppRoutes.home);
                            } catch (e) {
                              debugPrint('Delete listing error: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          label: const Text('Delete Listing'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ]);
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await context.read<CarProvider>().reportListing(car.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your report.')));
                      }
                    },
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report listing'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon; final String label;
  const _SpecChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.white70), const SizedBox(width: 6), Text(label, style: context.textStyles.labelMedium?.copyWith(color: Colors.white))]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label; final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Text(label, style: context.textStyles.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _UpgradeBottomSheet extends StatelessWidget {
  const _UpgradeBottomSheet();
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upgrade Listing', style: context.textStyles.titleLarge?.bold),
            const SizedBox(height: AppSpacing.sm),
            Text('Boost visibility with premium placements', style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            _UpgradeOptionCard(
              title: 'VIP',
              price: '50 AED',
              duration: '7 days',
              accentColor: MarketplaceColors.vip,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            _UpgradeOptionCard(
              title: 'Featured',
              price: '15 AED',
              duration: '3 days',
              accentColor: MarketplaceColors.featured,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            _UpgradeOptionCard(
              title: 'Pin',
              price: '5 AED',
              duration: '1 day',
              accentColor: MarketplaceColors.pinned,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeOptionCard extends StatelessWidget {
  final String title; final String price; final String duration; final Color accentColor; final VoidCallback onPressed;
  const _UpgradeOptionCard({required this.title, required this.price, required this.duration, required this.accentColor, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(children: [
          Container(width: 8, height: 48, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(999))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.textStyles.titleLarge?.bold),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(duration, style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price, style: context.textStyles.titleMedium?.bold),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                elevation: 0,
              ),
              child: const Text('Upgrade Now'),
            ),
          ]),
        ]),
      ),
    );
  }
}

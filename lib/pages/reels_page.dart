import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/providers/reel_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/utils/launch_utils.dart';
import 'package:autoreel/utils/format_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

// Force a known-good video URL to debug loading issues
const bool kForceTestVideoUrl = false;
const String kTestVideoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;
  final Set<String> _counted = <String>{};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelProvider>();
    final reels = provider.reels;
    final error = provider.errorMessage;

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (error != null && error.isNotEmpty) {
      // Explicit error state per requirements
      debugPrint('Reels load error (UI): $error');
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 64),
                const SizedBox(height: 12),
                const Text('Failed to load reels', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(error, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
    }

    if (reels.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.video_collection_outlined, color: Colors.white70, size: 64),
                  const SizedBox(height: 12),
                  const Text('No reels yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Upload the first reel to get started', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.uploadReel),
                    icon: const Icon(Icons.upload, color: Colors.black),
                    label: const Text('Upload first reel', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(backgroundColor: MarketplaceColors.accentYellow),
                  )
                ]),
              ),
              // Top-left floating back button (always visible)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: GestureDetector(
                      onTap: () {
                        try {
                          if (GoRouter.of(context).canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.home);
                          }
                        } catch (e) {
                          debugPrint('ReelsPage empty-state back nav error: $e');
                          context.go(AppRoutes.home);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                        child: const Center(child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(children: [
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (i) {
              setState(() => _activeIndex = i);
              if (i >= 0 && i < reels.length) {
                final r = reels[i];
                if (!_counted.contains(r.id)) {
                  _counted.add(r.id);
                  context.read<ReelProvider>().incrementViews(r.id);
                }
              }
            },
            itemBuilder: (context, index) {
              final reel = reels[index];
              // Increment view when page becomes visible the first time
              if (index == _activeIndex && !_counted.contains(reel.id)) {
                _counted.add(reel.id);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.read<ReelProvider>().incrementViews(reel.id);
                });
              }
              return Stack(children: [
                // Video fills the screen
                const Positioned.fill(child: _Surface()),
                Positioned.fill(
                  child: ReelsVideoPlayer(
                    url: kForceTestVideoUrl ? kTestVideoUrl : reel.videoUrl,
                    isActive: index == _activeIndex,
                  ),
                ),
                // Owner-only delete button (bottom-left)
                Builder(builder: (context) {
                  final auth = context.read<AuthProvider>();
                  final String uid = (auth.currentUser?.uid ?? '').toString();
                  final bool isOwner = reel.userId == uid && uid.isNotEmpty;
                  if (!isOwner) return const SizedBox.shrink();
                  final double bottom = 100 + MediaQuery.viewPaddingOf(context).bottom;
                  return Positioned(
                    left: 12,
                    bottom: bottom,
                    child: GestureDetector(
                      onTap: () => _confirmDelete(context, reel),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      ),
                    ),
                  );
                }),
                // Top-right badge for VIP/Featured/Urgent
                if (reel.isVip || reel.isFeatured || reel.isUrgent)
                  Positioned(
                    right: 12,
                    top: 12 + MediaQuery.viewPaddingOf(context).top,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: MarketplaceColors.accentYellow, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        reel.isVip ? 'VIP' : reel.isFeatured ? 'Featured' : 'Urgent',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                // Bottom gradient for readability
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.6),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Right-side actions (like, comments, share, WhatsApp)
                Positioned(
                  right: 12,
                  bottom: 100 + MediaQuery.viewPaddingOf(context).bottom,
                  child: _RightActions(
                    reel: reel,
                    liked: provider.isLiked(reel.id),
                    onLike: () async {
                      final auth = context.read<AuthProvider>();
                      if (!auth.isLoggedIn) {
                        context.pushNamed('login', queryParameters: {'redirect': AppRoutes.reels});
                        return;
                      }
                      await context.read<ReelProvider>().toggleLike(reel.id);
                    },
                    onComment: () => _openCommentsSheet(context, reel),
                    onShare: () async {
                      try {
                        final link = (reel.videoUrl.trim().isNotEmpty) ? reel.videoUrl.trim() : '';
                        final text = link.isNotEmpty ? 'Check this listing on Motix\n$link' : 'Check this listing on Motix';
                        await Share.share(text, subject: 'Motix Reel');
                      } catch (e) {
                        debugPrint('Share error: $e');
                      }
                    },
                    onMore: () => _openMoreMenu(context, reel),
                  ),
                ),
                // Overlay info
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReelInfo(
                        sellerUsername: reel.sellerUsername,
                        userId: reel.userId,
                        title: reel.title,
                        price: reel.price,
                        location: reel.location,
                        description: reel.description,
                        viewsCount: reel.viewsCount,
                        onSellerTap: () {
                          final sellerId = reel.userId.isNotEmpty ? reel.userId : 'seller';
                          final title = (reel.brand.isNotEmpty || reel.model.isNotEmpty)
                              ? '${reel.brand} ${reel.model}'.trim()
                              : (reel.title.isNotEmpty ? reel.title : 'Listing');
                          final sellerName = '@' + ((reel.sellerUsername.trim().isNotEmpty) ? reel.sellerUsername.trim() : 'user');
                          context.pushNamed(
                            'user_profile',
                            pathParameters: {'id': sellerId},
                            queryParameters: {
                              'listingId': reel.id,
                              'listingTitle': title,
                              'sellerPhone': reel.sellerPhone,
                              'sellerName': sellerName,
                            },
                          );
                        },
                        onDetailsTap: () => _openDetailsSheet(context, reel),
                      ),
                      const SizedBox(height: 10),
                      // Removed the old left overlay more button to reduce clutter
                      const SizedBox(height: 14),
                      const _MusicTicker(text: 'Motix • car listing'),
                    ],
                  ),
                ),
              ]);
            },
          ),
        ),
        // Top-left floating back button (fixed, safe area)
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: GestureDetector(
                onTap: () {
                  try {
                    if (GoRouter.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  } catch (e) {
                    debugPrint('ReelsPage back nav error: $e');
                    context.go(AppRoutes.home);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _openCommentsSheet(BuildContext context, ReelItem reel) {
    final provider = context.read<ReelProvider>();
    final auth = context.read<AuthProvider>();
    final TextEditingController input = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketplaceColors.luxCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(children: [
                Container(height: 4, width: 40, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Comments', style: Theme.of(ctx).textTheme.titleMedium?.withColor(Colors.white)),
                    Text('${reel.commentsCount}', style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer<ReelProvider>(
                    builder: (context, p, _) {
                      final list = p.commentsFor(reel.id);
                      if (list.isEmpty) {
                        return const Center(child: Text('No comments yet', style: TextStyle(color: Colors.white60)));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (c, i) {
                          final cm = list[i];
                          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const CircleAvatar(radius: 14, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 14, color: Colors.white)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(cm.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(cm.text, style: const TextStyle(color: Colors.white70)),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Text(_timeAgo(cm.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ]);
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: list.length,
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final text = input.text.trim();
                        if (text.isEmpty) return;
                        if (!auth.isLoggedIn) {
                          if (mounted) Navigator.of(ctx).pop();
                          context.pushNamed('login', queryParameters: {'redirect': AppRoutes.reels});
                          return;
                        }
                        final user = auth.currentUser!;
                        final comment = ReelComment(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          reelId: reel.id,
                          userId: user.uid,
                          userName: user.displayName ?? '@${user.uid}',
                          text: text,
                          createdAt: DateTime.now(),
                        );
                        await provider.addComment(reel.id, comment);
                        input.clear();
                      },
                      icon: const Icon(Icons.send, color: MarketplaceColors.accentYellow),
                    )
                  ]),
                )
              ]),
            ),
          ),
        );
      },
    );
  }

  void _openDetailsSheet(BuildContext context, ReelItem reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketplaceColors.luxCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        Widget row(String label, String value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 110, child: Text(label, style: (t.labelLarge ?? const TextStyle()).withColor(Colors.white70))),
                const SizedBox(width: 8),
                Expanded(child: Text(value, style: (t.bodyMedium ?? const TextStyle()).withColor(Colors.white), softWrap: true)),
              ]),
            );
        final mileageStr = reel.mileageKm != null ? '${reel.mileageKm} km' : '';
        final yearStr = reel.year?.toString() ?? '';
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  Text('Listing details', style: t.titleLarge?.withColor(Colors.white) ?? const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (reel.title.trim().isNotEmpty) row('Title', reel.title.trim()),
                  if (reel.brand.trim().isNotEmpty) row('Brand / Make', reel.brand.trim()),
                  if (reel.model.trim().isNotEmpty) row('Model', reel.model.trim()),
                  if (yearStr.isNotEmpty) row('Year', yearStr),
                  if (mileageStr.isNotEmpty) row('Mileage', mileageStr),
                  row('Price', 'AED ${reel.price}'),
                  if (reel.location.trim().isNotEmpty) row('Location', reel.location.trim()),
                  if (reel.description.trim().isNotEmpty) row('Description', reel.description.trim()),
                  // Seller username (prefer reel.sellerUsername, else fetch by userId)
                  if (reel.sellerUsername.trim().isNotEmpty)
                    row('Seller username', '@${reel.sellerUsername.trim()}')
                  else if (reel.userId.trim().isNotEmpty)
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('users').doc(reel.userId).get(),
                      builder: (c, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return row('Seller username', '@');
                        }
                        String uname = '';
                        try {
                          uname = (snap.data?.data()?['username'] as String?)?.trim() ?? '';
                          if (uname.isEmpty) {
                            uname = (snap.data?.data()?['displayName'] as String?)?.trim() ?? '';
                          }
                        } catch (e) {
                          debugPrint('details username fetch error: $e');
                        }
                        if (uname.isEmpty) {
                          return row('Seller username', '@user');
                        }
                        return row('Seller username', '@$uname');
                      },
                    )
                  else
                    row('Seller username', '@user'),
                  if (reel.sellerPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    row('Seller phone', reel.sellerPhone.trim()),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => openPhoneCall(reel.sellerPhone),
                          icon: const Icon(Icons.phone, color: Colors.black),
                          label: const Text('Call', style: TextStyle(color: Colors.black)),
                          style: FilledButton.styleFrom(backgroundColor: MarketplaceColors.accentYellow, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => openWhatsAppWaMe(reel.sellerPhone, message: "Hello, I'm interested in this listing"),
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                          label: const Text('WhatsApp'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, ReelItem reel) async {
    final provider = context.read<ReelProvider>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: MarketplaceColors.luxCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                Text('Delete reel?', style: t.titleLarge?.withColor(Colors.white)),
                const SizedBox(height: 8),
                const Text('Are you sure you want to delete this reel?', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await provider.deleteReel(reel.id);
                        } catch (e) {
                          debugPrint('Delete reel error: $e');
                        } finally {
                          if (mounted) Navigator.of(ctx).pop();
                        }
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMoreMenu(BuildContext context, ReelItem reel) {
    final auth = context.read<AuthProvider>();
    final String uid = (auth.currentUser?.uid ?? '').toString();
    final bool isOwner = reel.userId == uid && uid.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: MarketplaceColors.luxCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 10, bottom: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text('Edit', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // Navigate to upload reel (edit flow not altering any logic)
                    try {
                      context.pushNamed('upload_reel', queryParameters: {'edit': reel.id});
                    } catch (e) {
                      debugPrint('Edit navigation error: $e');
                      context.pushNamed('upload_reel');
                    }
                  },
                ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDelete(context, reel);
                  },
                ),
              if (!isOwner)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text('Report', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks, we\'ll review this reel.')));
                    } catch (e) {
                      debugPrint('Report snackbar error: $e');
                    }
                  },
                ),
              if (!isOwner)
                ListTile(
                  leading: const Icon(Icons.ios_share, color: Colors.white),
                  title: const Text('Share', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await Clipboard.setData(ClipboardData(text: reel.videoUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                      }
                    } catch (e) {
                      debugPrint('More->Share error: $e');
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white70),
                title: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _Surface extends StatelessWidget {
  const _Surface();
  @override
  Widget build(BuildContext context) => Container(color: Theme.of(context).colorScheme.surface);
}

class _ReelInfo extends StatelessWidget {
  final String sellerUsername;
  final String userId;
  final String title;
  final String location;
  final int price;
  final String description;
  final int viewsCount;
  final VoidCallback? onSellerTap;
  final VoidCallback? onDetailsTap;
  const _ReelInfo({required this.sellerUsername, required this.userId, required this.title, required this.price, required this.location, required this.description, required this.viewsCount, this.onSellerTap, this.onDetailsTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        GestureDetector(onTap: onSellerTap, child: const CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 14, color: Colors.white))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSellerTap,
          child: _SellerUsernameText(initialUsername: sellerUsername, userId: userId, style: t.labelLarge?.withColor(Colors.white) ?? const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
      const SizedBox(height: 6),
      Text(title, style: t.titleLarge?.withColor(Colors.white) ?? const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600), softWrap: true, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Text('AED $price', style: (t.titleMedium ?? const TextStyle()).withColor(MarketplaceColors.accentYellow).bold, maxLines: 1, overflow: TextOverflow.ellipsis)),
        // Removed duplicate views text; views are shown once on the right-side actions
      ]),
      const SizedBox(height: 2),
      Text(location, style: (t.bodyMedium ?? const TextStyle()).withColor(Colors.white.withValues(alpha: 0.8))),
      if (description.trim().isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(description, style: (t.bodySmall ?? const TextStyle()).withColor(Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
      const SizedBox(height: 8),
      if (onDetailsTap != null)
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onDetailsTap,
            child: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(child: Icon(Icons.more_horiz, color: Colors.white, size: 18)),
            ),
          ),
        ),
    ]);
  }

  // uses formatCompactCount from utils
}

class _SellerUsernameText extends StatelessWidget {
  final String initialUsername;
  final String userId;
  final TextStyle style;
  const _SellerUsernameText({required this.initialUsername, required this.userId, required this.style});

  @override
  Widget build(BuildContext context) {
    final uname = initialUsername.trim();
    if (uname.isNotEmpty) {
      return Text('@$uname', style: style);
    }
    if (userId.trim().isEmpty) {
      return Text('@user', style: style);
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Text('@', style: style);
        }
        String resolved = '';
        try {
          resolved = (snap.data?.data()?['username'] as String?)?.trim() ?? '';
          if (resolved.isEmpty) {
            resolved = (snap.data?.data()?['displayName'] as String?)?.trim() ?? '';
          }
        } catch (e) {
          debugPrint('overlay username fetch error: $e');
        }
        if (resolved.isEmpty) {
          return Text('@user', style: style);
        }
        return Text('@$resolved', style: style);
      },
    );
  }
}

class _RightActions extends StatelessWidget {
  final ReelItem reel;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;
  const _RightActions({required this.reel, required this.liked, required this.onLike, required this.onComment, required this.onShare, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const double kIconSize = 18; // icon size per spec
    const double kBtnSize = 42; // circle size per spec
    const double kTextSize = 14;
    const double kItemSpacing = 16;
    Widget _action(IconData icon, String label, {Color color = Colors.white, VoidCallback? onTap, TextStyle? labelStyle}) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
           GestureDetector(
             behavior: HitTestBehavior.opaque,
             onTap: onTap,
             child: Container(
               width: kBtnSize,
               height: kBtnSize,
               decoration: BoxDecoration(
                 color: Colors.black.withValues(alpha: 0.35),
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
               ),
               child: Center(child: Icon(icon, color: color, size: kIconSize)),
             ),
           ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: labelStyle ?? const TextStyle(color: Colors.white, fontSize: kTextSize),
          ),
          const SizedBox(height: kItemSpacing),
        ]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _action(
          liked ? Icons.favorite : Icons.favorite_border,
          formatCompactCount(reel.likesCount),
          color: liked ? Colors.red : Colors.white,
          onTap: onLike,
        ),
        _action(
          Icons.mode_comment_outlined,
          formatCompactCount(reel.commentsCount),
          onTap: onComment,
        ),
        _action(
          Icons.ios_share,
          'Share',
          onTap: onShare,
        ),
        _action(
          Icons.remove_red_eye,
          '👁 ${formatCompactCount(reel.viewsCount)}',
          color: Colors.white,
          onTap: null,
        ),
        _action(
          Icons.more_horiz,
          'More',
          onTap: onMore,
        ),
      ],
    );
  }
}

class _MusicTicker extends StatefulWidget {
  final String text;
  const _MusicTicker({required this.text});

  @override
  State<_MusicTicker> createState() => _MusicTickerState();
}

class _MusicTickerState extends State<_MusicTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), border: Border.all(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(999)),
        child: LayoutBuilder(builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final width = constraints.maxWidth;
              final dx = -(_controller.value * (width + 60));
              return Stack(children: [
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: Row(children: [
                    const Icon(Icons.music_note, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(widget.text, style: t.labelLarge?.withColor(Colors.white70)),
                    const SizedBox(width: 60),
                    const Icon(Icons.music_note, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(widget.text, style: t.labelLarge?.withColor(Colors.white70)),
                  ]),
                ),
              ]);
            },
          );
        }),
      ),
    );
  }
}

class ReelsVideoPlayer extends StatefulWidget {
  final String url;
  final bool isActive;
  const ReelsVideoPlayer({super.key, required this.url, this.isActive = true});

  @override
  State<ReelsVideoPlayer> createState() => _ReelsVideoPlayerState();
}

class _ReelsVideoPlayerState extends State<ReelsVideoPlayer> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _usePlaceholder = false;
  Size? _videoSize;

  bool get _hasUrl => widget.url.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant ReelsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      debugPrint('ReelsVideoPlayer URL changed: ${oldWidget.url} -> ${widget.url}');
      _setup();
      return;
    }
    if (oldWidget.isActive != widget.isActive && _initialized && _controller != null) {
      if (widget.isActive) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
      setState(() {});
    }
  }

  Future<void> _setup() async {
    await _disposeController();
    _initialized = false;
    _error = false;
    _usePlaceholder = false;

    final url = widget.url.trim();
    debugPrint('ReelsVideoPlayer initializing with url: $url');
    if (url.isEmpty) {
      setState(() => _usePlaceholder = true);
      return;
    }

    try {
      final uri = Uri.parse(url);
      _controller = VideoPlayerController.networkUrl(uri);
      await _controller!.setLooping(true);
      await _controller!.setVolume(1.0); // mute false
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _videoSize = _controller!.value.size;
      });
      if (widget.isActive) await _controller!.play(); // auto play
    } catch (e) {
      debugPrint('Video init error for ${widget.url}: $e');
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  Future<void> _disposeController() async {
    try {
      await _controller?.dispose();
    } catch (e) {
      debugPrint('Video dispose error: $e');
    } finally {
      _controller = null;
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Placeholder image for empty URL
    if (_usePlaceholder) {
      return FittedBox(
        fit: BoxFit.cover,
        child: Image.asset('assets/images/luxury_car_gray_1777063456696.jpg'),
      );
    }

    // Error state with retry
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Video failed to load', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _setup,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: MarketplaceColors.accentYellow),
            ),
          ],
        ),
      );
    }

    // Loading while initializing
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final size = _videoSize ?? const Size(9, 16);

    return GestureDetector(
      onTap: () {
        final c = _controller;
        if (c == null || !c.value.isInitialized) return;
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(fit: BoxFit.cover, child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(_controller!))),
        if (!(_controller?.value.isPlaying ?? false))
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
            ),
          ),
      ]),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

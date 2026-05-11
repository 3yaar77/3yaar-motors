import 'dart:convert';
import 'dart:typed_data';
import 'package:autoreel/utils/image_url_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:autoreel/providers/listings_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/pages/profile_avatar_crop_page.dart';
import 'package:autoreel/pages/notifications_page.dart';
import 'package:autoreel/pages/reels_page.dart' show ReelsVideoPlayer;
import 'package:autoreel/utils/blob_url.dart';
import 'package:autoreel/services/image_storage_service.dart';
import 'package:autoreel/utils/image_upload_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Edit profile controllers
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Avatar state
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;
  Uint8List? _avatarBytes;
  AuthProvider? _authRef; // listen to logout to clear local avatar bytes
  VoidCallback? _authListener;

  // Stats
  int _myListingsCount = 0;
  int _activeListingsCount = 0;
  int _viewsCount = 0; // Not tracked yet

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Clear any temporary avatar bytes when user logs out so we always rely on Firestore photoUrl
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ap = context.read<AuthProvider>();
      _authRef = ap;
      _authListener = () {
        if (!mounted) return;
        if (ap.currentUser == null) {
          setState(() => _avatarBytes = null);
        }
      };
      ap.addListener(_authListener!);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    if (_authRef != null && _authListener != null) {
      _authRef!.removeListener(_authListener!);
    }
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      final col = FirebaseFirestore.instance.collection('listings');
      // Total by owner
      final my = await col.where('ownerId', isEqualTo: uid).get();
      // Active by owner
      final act = await col.where('ownerId', isEqualTo: uid).where('status', isEqualTo: 'active').get();
      if (!mounted) return;
      setState(() {
        _myListingsCount = my.docs.length;
        _activeListingsCount = act.docs.length;
        _viewsCount = 0; // No views metric yet for cars
      });
    } catch (e) {
      debugPrint('Profile stats error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final u = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
        centerTitle: true,
      ),
      body: u == null
          ? _buildLoggedOut(cs)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('Profile stream error: ${snapshot.error}');
                  return Center(child: Text('Failed to load profile', style: context.textStyles.bodyMedium?.copyWith(color: cs.error)));
                }
                final data = snapshot.data?.data() ?? {};
                // Global diagnostics: log loaded user document
                try {
                  debugPrint('LOADED DOC: ' + jsonEncode(data));
                  debugPrint('User: ' + jsonEncode(data));
                } catch (_) {
                  debugPrint('LOADED DOC: ' + data.toString());
                  debugPrint('User: ' + data.toString());
                }
                final username = (data['username'] as String?)?.trim();
                final phone = (data['phone'] as String?)?.trim() ?? '';
                final docPhotoUrl = (data['photoUrl'] as String?)?.trim();
                final authPhotoUrl = (fb.FirebaseAuth.instance.currentUser?.photoURL ?? '').trim();
                final effectivePhotoUrl = (docPhotoUrl != null && docPhotoUrl.isNotEmpty) ? docPhotoUrl : (authPhotoUrl.isNotEmpty ? authPhotoUrl : null);
                // Logging as requested
                debugPrint('profile photoUrl (doc): ${docPhotoUrl == null || docPhotoUrl.isEmpty ? '(empty)' : docPhotoUrl}');
                debugPrint('profile photoURL (auth): ${authPhotoUrl.isEmpty ? '(empty)' : authPhotoUrl}');
                debugPrint('local preview: ${_avatarBytes != null ? 'bytes(' + _avatarBytes!.lengthInBytes.toString() + ')' : '(null)'}');
                final createdAtRaw = data['createdAt'];
                final createdAt = () {
                  try {
                    if (createdAtRaw is Timestamp) return createdAtRaw.toDate();
                    if (createdAtRaw is DateTime) return createdAtRaw;
                    if (createdAtRaw is int) return DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
                    if (createdAtRaw is String) return DateTime.tryParse(createdAtRaw) ?? u.createdAt;
                  } catch (e) {
                    debugPrint('createdAt parse error: $e');
                  }
                  return u.createdAt;
                }();
                return RefreshIndicator(
                  onRefresh: () async {
                    await _loadStats();
                    setState(() {});
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _HeaderCard(
                        name: (username == null || username.isEmpty) ? (u.displayName ?? 'Your Name') : username,
                        phone: phone.isNotEmpty ? phone : (u.phoneNumber ?? ''),
                        memberSince: createdAt,
                        avatarBytes: _avatarBytes,
                        photoUrl: effectivePhotoUrl,
                        onEdit: _openEditSheet,
                        onAvatarTap: _pickAvatar,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _StatsRow(
                        myListings: _myListingsCount,
                        activeListings: _activeListingsCount,
                        views: _viewsCount,
                        favorites: context.select<CarProvider, int>((p) => p.favoriteCars.length),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _MainButtons(onTapMyListings: () => context.push(AppRoutes.myListings), onTapFavorites: () => context.push(AppRoutes.favorites), onTapUpgradeHistory: () {
                        context.push(AppRoutes.upgrades);
                      }, onTapSettings: () {
                        context.push(AppRoutes.settings);
                      }),
                      const SizedBox(height: AppSpacing.lg),
                      _LogoutCard(onLogout: _logout),
                      const SizedBox(height: AppSpacing.xl),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLoggedOut(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_outline, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text('Please log in to view your profile', style: context.textStyles.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(onPressed: () => context.goNamed('login', queryParameters: {'redirect': AppRoutes.profile}), icon: const Icon(Icons.login, color: Colors.white), label: const Text('Log in')),
          ]),
        ),
      );

  Future<void> _openEditSheet() async {
    final cs = Theme.of(context).colorScheme;
    // Pre-fill controllers with latest Firestore values
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = snap.data() ?? {};
        _nameCtrl.text = (data['username'] as String?)?.trim() ?? (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : '');
        _phoneCtrl.text = (data['phone'] as String?)?.trim() ?? (_phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : '');
        _cityCtrl.text = (data['city'] as String?)?.trim() ?? (_cityCtrl.text.isNotEmpty ? _cityCtrl.text : '');
      }
    } catch (e) {
      debugPrint('Prefill edit sheet error: $e');
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                GestureDetector(onTap: _pickAvatar, child: _buildAvatar(size: 64)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Edit Profile', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Phone', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _cityCtrl,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: 'City', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(onPressed: _onSave, icon: const Icon(Icons.save, color: Colors.white), label: const Text('Save changes')),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('Logout')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      try {
        context.read<LocalChatProvider>().clear();
      } catch (_) {}
      try {
        context.read<ListingsProvider>().clearAll();
      } catch (_) {}
      await context.read<AuthProvider>().signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  Future<void> _onSave() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    if (phone.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter your phone number')));
      return;
    }
    try {
      // Persist to Firestore via AuthProvider (users/{uid})
      await context.read<AuthProvider>().updateProfile(displayName: name, city: city, phone: phone);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
      setState(() {});
    } catch (e) {
      debugPrint('Profile save error: $e');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Failed to save profile')));
    }
  }

  Future<void> _pickAvatar() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null) return; // user canceled picker

      // Read bytes then open in-app cropper (1:1, circular preview). Upload only after confirm.
      final originalBytes = await file.readAsBytes();
      // On web, if the image is HEIC/HEIF, skip cropper (browser can't render it) and upload directly
      if (kIsWeb && ImageUploadHelper.isLikelyHeic(originalBytes)) {
        await _uploadCroppedAvatar(originalBytes);
      } else {
        final Uint8List? cropped = await showDialog<Uint8List?> (
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ProfileAvatarCropPage(initialBytes: originalBytes),
        );
        if (cropped == null) return; // user canceled crop
        await _uploadCroppedAvatar(cropped);
      }
    } catch (e) {
      debugPrint('Pick/crop avatar error: ' + e.toString());
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _uploadCroppedAvatar(Uint8List bytes) async {
    try {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to update your photo')));
        return;
      }
      final isHeicOnWeb = kIsWeb && ImageUploadHelper.isLikelyHeic(bytes);
      // For renderable formats, show immediate preview. For HEIC on web, skip preview (not renderable).
      if (!isHeicOnWeb) {
        if (mounted) setState(() => _avatarBytes = bytes);
        debugPrint('local preview: bytes(${bytes.lengthInBytes})');
      } else {
        debugPrint('HEIC avatar selected on web; skipping preview and enabling background conversion.');
      }

      // Upload via unified helper (unique filename to avoid cache issues)
      final url = await ImageStorageService.uploadUserAvatar(uid: uid, bytes: bytes);
      if (!mounted) return;
      // Persist to Firestore and Firebase Auth via provider
      await context.read<AuthProvider>().updatePhotoUrl(url);

      // If HEIC on web, a Cloud Function will create a JPEG and update Firestore.
      // Wait briefly for Firestore to reflect a non-HEIC URL before clearing preview and showing success.
      if (isHeicOnWeb) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(const SnackBar(content: Text('Processing photo...')));
        try {
          final ref = FirebaseFirestore.instance.collection('users').doc(uid);
          final snapshot = await ref.snapshots().firstWhere((s) {
            final data = s.data() as Map<String, dynamic>? ?? const {};
            final u = (data['photoUrl'] as String?)?.trim() ?? '';
            return u.startsWith('http') && !u.toLowerCase().contains('.heic') && !u.toLowerCase().contains('image%2Fheic');
          }).timeout(const Duration(seconds: 25));
          debugPrint('Avatar JPEG available: ${(snapshot.data()?["photoUrl"] ?? '')}');
          if (mounted) {
            setState(() => _avatarBytes = null);
            messenger.showSnackBar(const SnackBar(content: Text('Profile photo updated')));
          }
        } catch (e) {
          debugPrint('Waiting for JPEG conversion timed out or failed: $e');
          // Even if conversion is delayed, clear local state; UI will pick up Firestore change when ready.
          if (mounted) setState(() => _avatarBytes = null);
        }
      } else {
        // Clear temporary bytes ONLY after verification succeeded so UI uses Firestore URL
        if (mounted) setState(() => _avatarBytes = null);
        debugPrint('local preview: (null)');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      debugPrint('Upload avatar error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildAvatar({double size = 80}) {
    final bgColor = MarketplaceColors.accentYellow;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _avatarBytes == null ? bgColor : null,
      backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
      child: _avatarBytes == null ? const Icon(Icons.person, color: Colors.black, size: 40) : null,
    );
  }

}

class CropperPresentStyle {
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String phone;
  final DateTime memberSince;
  final Uint8List? avatarBytes;
  final String? photoUrl;
  final VoidCallback onEdit;
  final VoidCallback onAvatarTap;
  const _HeaderCard({required this.name, required this.phone, required this.memberSince, required this.avatarBytes, required this.photoUrl, required this.onEdit, required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(colors: [cs.surfaceContainerHighest, cs.surfaceContainer]),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(
            onTap: onAvatarTap,
            child: Builder(builder: (context) {
              final hasBytes = avatarBytes != null;
              ImageProvider<Object>? foreground;
              if (hasBytes) {
                foreground = MemoryImage(avatarBytes!);
              } else if (photoUrl != null && photoUrl!.isNotEmpty) {
                foreground = NetworkImage(ImageUrlUtils.sanitize(photoUrl!));
              }
              return CircleAvatar(
                radius: 44,
                backgroundColor: MarketplaceColors.accentYellow,
                foregroundImage: foreground,
                child: const Icon(Icons.person, color: Colors.black, size: 44),
              );
            })),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 6), Flexible(child: Text(phone, style: context.textStyles.bodyMedium))]),
            ],
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.verified_user, size: 16),
              const SizedBox(width: 6),
              Text('Member since ${memberSince.year}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ]),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.white), label: const Text('Edit')),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int myListings;
  final int activeListings;
  final int views;
  final int favorites;
  const _StatsRow({required this.myListings, required this.activeListings, required this.views, required this.favorites});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(child: _StatTile(icon: Icons.list_alt, label: 'My listings', value: myListings.toString(), cs: cs)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _StatTile(icon: Icons.check_circle, label: 'Active', value: activeListings.toString(), cs: cs)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _StatTile(icon: Icons.remove_red_eye_outlined, label: 'Views', value: views.toString(), cs: cs)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _StatTile(icon: Icons.favorite, label: 'Favorites', value: favorites.toString(), cs: cs)),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon; final String label; final String value; final ColorScheme cs;
  const _StatTile({required this.icon, required this.label, required this.value, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, color: MarketplaceColors.accentYellow),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: context.textStyles.labelSmall),
        ]),
      );
}

class _MainButtons extends StatelessWidget {
  final VoidCallback onTapMyListings; final VoidCallback onTapFavorites; final VoidCallback onTapUpgradeHistory; final VoidCallback onTapSettings;
  const _MainButtons({required this.onTapMyListings, required this.onTapFavorites, required this.onTapUpgradeHistory, required this.onTapSettings});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: AppSpacing.md, crossAxisSpacing: AppSpacing.md, childAspectRatio: 1),
      children: [
        _ActionTile(icon: Icons.directions_car, label: 'My Listings', onTap: onTapMyListings, cs: cs),
        _ActionTile(icon: Icons.favorite, label: 'Saved', onTap: onTapFavorites, cs: cs),
        _ActionTile(icon: Icons.workspace_premium, label: 'Upgrades', onTap: onTapUpgradeHistory, cs: cs),
        _ActionTile(icon: Icons.settings, label: 'Settings', onTap: onTapSettings, cs: cs),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final ColorScheme cs;
  const _ActionTile({required this.icon, required this.label, required this.onTap, required this.cs});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: MarketplaceColors.accentYellow),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: context.textStyles.labelSmall),
          ]),
        ),
      );
}

class _LogoutCard extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutCard({required this.onLogout});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Session', style: context.textStyles.titleSmall?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ]),
    );
  }
}

class _MyListingsSection extends StatelessWidget {
  final String currentUid; final Future<void> Function() onDeleted;
  const _MyListingsSection({required this.currentUid, required this.onDeleted});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = FirebaseFirestore.instance
        .collection('listings')
        .where('ownerId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'active')
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          debugPrint('My listings stream error: ${snap.error}');
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load listings', style: context.textStyles.bodyMedium?.copyWith(color: cs.error)),
          );
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _EmptyListings();
        }
        return ListView.separated(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final _vids = _readStringList(data['videoUrls']);
            final _primaryVideoUrl = _vids.isNotEmpty ? _vids.first : ((data['video_url'] ?? data['videoUrl'] ?? '')?.toString() ?? '');
            // Derive basic stats with safe fallbacks
            final int likesCount = (data['likesCount'] is int)
                ? (data['likesCount'] as int)
                : (data['likes'] is List)
                    ? (data['likes'] as List).length
                    : ((data['favoritesCount'] is int) ? (data['favoritesCount'] as int) : 0);
            final int viewsCount = (data['viewsCount'] is int)
                ? (data['viewsCount'] as int)
                : ((data['views'] is int) ? (data['views'] as int) : 0);
            final List<String> imageUrls = _readStringList(data['images']);
            return _ListingCard(
              id: d.id,
              ownerId: (data['ownerId'] ?? '') as String,
              title: _composeTitle(data),
              price: _readPrice(data),
              category: (data['category'] ?? '') as String? ?? 'Cars',
              imageUrls: imageUrls,
              videoUrl: _primaryVideoUrl,
              listingType: (data['listingType'] ?? '') as String? ?? '',
              isVip: (data['isVip'] as bool?) ?? false,
              isFeatured: (data['isFeatured'] as bool?) ?? false,
              isUrgent: (data['isUrgent'] as bool?) ?? false,
              viewsCount: viewsCount,
              likesCount: likesCount,
              mediaCount: imageUrls.length,
              onEdit: () {
                // TODO: Implement edit listing. No-op for now.
              },
              onDelete: () async {
                final ok = await _confirmDelete(context);
                if (ok != true) return;
                try {
                  await FirebaseFirestore.instance.collection('listings').doc(d.id).update({
                    'status': 'deleted',
                    'deletedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
                  }
                  await onDeleted();
                } catch (e) {
                  debugPrint('Delete listing error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  List<String> _readStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).cast<String>().toList();
    }
    return const <String>[];
  }

  String _composeTitle(Map<String, dynamic> data) {
    final b = (data['brand'] ?? data['make'] ?? '')?.toString() ?? '';
    final m = (data['model'] ?? '')?.toString() ?? '';
    final title = '$b $m'.trim();
    return title.isEmpty ? (data['title']?.toString() ?? 'Untitled') : title;
  }

  String _readPrice(Map<String, dynamic> data) {
    final v = data['price'];
    if (v == null) return '';
    if (v is int) return 'AED $v';
    if (v is double) return 'AED ${v.round()}';
    if (v is String) return 'AED ${v.replaceAll(RegExp(r'[^0-9]'), '')}';
    return '';
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete listing?'),
          content: const Text('Are you sure you want to delete this listing?'),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => ctx.pop(true), child: const Text('Delete')),
          ],
        ),
      );
}

class _ListingCard extends StatelessWidget {
  final String id;
  final String ownerId;
  final String title;
  final String price;
  final String category;
  final List<String> imageUrls;
  final String? videoUrl;
  final String listingType;
  final bool isVip;
  final bool isFeatured;
  final bool isUrgent;
  final int viewsCount;
  final int likesCount;
  final int mediaCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ListingCard({required this.id, required this.ownerId, required this.title, required this.price, required this.category, required this.imageUrls, this.videoUrl, required this.listingType, required this.isVip, required this.isFeatured, required this.isUrgent, required this.viewsCount, required this.likesCount, required this.mediaCount, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUid = context.read<AuthProvider>().currentUser?.uid;
    final canDelete = (currentUid != null && currentUid == ownerId);

    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Media with overlays (stats + upgrade + type)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(children: [
            Positioned.fill(child: _buildImage()),
            // Top-left: media indicator (photo count or play icon)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    category.trim().toLowerCase() == 'reels' ? Icons.play_arrow : Icons.photo,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    category.trim().toLowerCase() == 'reels' ? 'Video' : '${mediaCount.clamp(1, 999)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ),
            // Top-right: views and likes chips
            Positioned(
              right: 8,
              top: 8,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.remove_red_eye, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$viewsCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_border, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$likesCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
            // Top-left: VIP/Featured/Urgent badge below media indicator
            if (isVip || isFeatured || isUrgent)
              Positioned(
                left: 8,
                top: 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: MarketplaceColors.accentYellow, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    isVip ? 'VIP' : isFeatured ? 'Featured' : 'Urgent',
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            // Bottom-right: Upgrade button (gold)
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.upgrades),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: MarketplaceColors.accentYellow, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Upgrade', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  _Badge(listingType: listingType, isVip: isVip, isFeatured: isFeatured, isUrgent: isUrgent),
                ]),
                const SizedBox(height: 4),
                Text(price, style: context.textStyles.titleSmall?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(category, style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(children: [
              // Provide an inline Upgrade action too for consistency
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.upgrades),
                icon: const Icon(Icons.workspace_premium, size: 16, color: Colors.black),
                label: const Text('Upgrade', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(backgroundColor: MarketplaceColors.accentYellow, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)).copyWith(splashFactory: NoSplash.splashFactory),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 16), label: const Text('Edit')),
              const SizedBox(height: 8),
              if (canDelete) FilledButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete, size: 16, color: Colors.white), label: const Text('Delete')),
            ]),
          ]),
        )
      ]),
    );
  }

  Widget _buildImage() {
    // If this is a Reels listing and we have a video URL, show the video player preview
    if (category.trim().toLowerCase() == 'reels') {
      final url = (videoUrl ?? '').trim();
      if (url.isNotEmpty) {
        return ReelsVideoPlayer(url: url, isActive: false);
      }
      // Fallback placeholder for reels without a video URL
      return Stack(children: [
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.35))),
        const Center(child: CircleAvatar(radius: 18, backgroundColor: Colors.black, child: Icon(Icons.play_arrow, color: Colors.white))),
      ]);
    }
    final has = imageUrls.isNotEmpty ? imageUrls.first.trim() : '';
    if (has.startsWith('http')) return Image.network(has, fit: BoxFit.cover);
    if (has.startsWith('assets/')) return Image.asset(has, fit: BoxFit.cover);
    return const Center(child: Icon(Icons.directions_car, size: 48));
  }
}

class _Badge extends StatelessWidget {
  final String listingType; final bool isVip; final bool isFeatured; final bool isUrgent;
  const _Badge({required this.listingType, required this.isVip, required this.isFeatured, required this.isUrgent});
  @override
  Widget build(BuildContext context) {
    final String? label = () {
      if (listingType.trim().isNotEmpty) return listingType;
      if (isVip) return 'VIP listing';
      if (isFeatured) return 'Featured listing';
      if (isUrgent) return 'Urgent listing';
      return null;
    }();
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: MarketplaceColors.accentYellow, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyListings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text('No listings yet', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Post your first listing for free', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(onPressed: () => context.go(AppRoutes.newListing), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Add Listing')),
      ]),
    );
  }
}

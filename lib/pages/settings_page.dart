import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:url_launcher/url_launcher.dart';
import 'package:autoreel/utils/launch_utils.dart' as launch_utils;
import 'package:autoreel/services/image_storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _updatingPhoto = false;
  bool _saving = false;

  // Support contacts (replace with your real support info when available)
  static const String _supportEmail = 'support@autoreel.app';
  static const String _supportPhone = '+971501234567';

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().currentUser;
    _nameCtrl.text = u?.displayName ?? '';
    _phoneCtrl.text = u?.phoneNumber ?? '';
    _emailCtrl.text = u?.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter name and phone')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateProfile(displayName: name, phone: phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      debugPrint('Settings save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    if (_updatingPhoto) return;
    setState(() => _updatingPhoto = true);
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final url = await ImageStorageService.uploadUserAvatar(uid: user.uid, bytes: bytes);
      await context.read<AuthProvider>().updatePhotoUrl(url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      debugPrint('Change photo error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  Future<void> _openChangePasswordDialog() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null || (user.email?.isNotEmpty != true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password change is available for email accounts only')));
      return;
    }
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password')),
              const SizedBox(height: 8),
              TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password')),
              const SizedBox(height: 8),
              TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm New Password')),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => ctx.pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final current = currentCtrl.text.trim();
                      final np = newCtrl.text.trim();
                      final cp = confirmCtrl.text.trim();
                      if (current.isEmpty || np.isEmpty || cp.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                        return;
                      }
                      if (np != cp) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match')));
                        return;
                      }
                      setS(() => saving = true);
                      try {
                        final cred = fb.EmailAuthProvider.credential(email: user.email!, password: current);
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(np);
                        await user.reload();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                        if (ctx.mounted) ctx.pop();
                      } on fb.FirebaseAuthException catch (e) {
                        debugPrint('changePassword auth error: ${e.code} ${e.message}');
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to update password')));
                      } catch (e) {
                        debugPrint('changePassword error: $e');
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update password')));
                      } finally {
                        setS(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Update'),
            ),
          ],
        );
      }),
    );
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _openNotificationSettings() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    bool push = false, email = false, messages = true;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = doc.data() ?? {};
      push = (d['pushNotifications'] as bool?) ?? false;
      email = (d['emailNotifications'] as bool?) ?? false;
      messages = (d['messageNotifications'] as bool?) ?? true;
    } catch (e) {
      debugPrint('Load notification settings error: $e');
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(title: const Text('Push Notifications'), value: push, onChanged: (v) => setS(() => push = v)),
              SwitchListTile(title: const Text('Email Notifications'), value: email, onChanged: (v) => setS(() => email = v)),
              SwitchListTile(title: const Text('Messages Notifications'), value: messages, onChanged: (v) => setS(() => messages = v)),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(uid).set({
                      'pushNotifications': push,
                      'emailNotifications': email,
                      'messageNotifications': messages,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings saved')));
                    if (ctx.mounted) ctx.pop();
                  } catch (e) {
                    debugPrint('Save notification settings error: $e');
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save')));
                  }
                },
                label: const Text('Save'),
              ),
            ]),
          );
        });
      },
    );
  }

  Future<void> _openLanguageDialog() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    String current = 'en';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      current = (doc.data()?['language'] as String?)?.toLowerCase() == 'ar' ? 'ar' : 'en';
    } catch (e) {
      debugPrint('Load language error: $e');
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile<String>(value: 'en', groupValue: current, onChanged: (v) => ctx.pop(v), title: const Text('English')),
          RadioListTile<String>(value: 'ar', groupValue: current, onChanged: (v) => ctx.pop(v), title: const Text('Arabic')),
        ]),
        actions: [TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel'))],
      ),
    ).then((value) async {
      final sel = value as String?;
      if (sel == null) return;
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'language': sel, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language saved')));
      } catch (e) {
        debugPrint('Save language error: $e');
      }
    });
  }

  Future<void> _openPrivacySettings() async {
    if (!mounted) return;
    context.push(AppRoutes.privacySettings);
  }

  Future<void> _contactSupport() async {
    // Offer WhatsApp or Email
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.chat_outlined), title: const Text('WhatsApp'), onTap: () => ctx.pop('wa')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), onTap: () => ctx.pop('mail')),
        ]),
      ),
    );
    if (choice == 'wa') {
      final ok = await launch_utils.openWhatsAppWaMe(_supportPhone, message: 'Hi, I need support');
      if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    } else if (choice == 'mail') {
      final uri = Uri(scheme: 'mailto', path: _supportEmail, queryParameters: {'subject': 'Support Request'});
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app')));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This will permanently delete your account. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final ap = context.read<AuthProvider>();
      final uid = ap.currentUser?.uid;
      if (uid == null) return;
      // Best-effort delete user document
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint('Delete user doc error: $e');
      }
      try {
        await fb.FirebaseAuth.instance.currentUser?.delete();
      } catch (e) {
        debugPrint('Delete auth user error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please re-login to delete your account')));
        }
        return;
      }
      await ap.signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('Delete account error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Profile Information
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Profile Information', style: context.textStyles.titleSmall?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Builder(builder: (context) {
                  final photoUrl = context.watch<AuthProvider>().currentUser?.photoUrl;
                  ImageProvider? p;
                  if (photoUrl != null && photoUrl.trim().isNotEmpty && photoUrl.startsWith('http')) {
                    p = NetworkImage(photoUrl);
                  }
                  return CircleAvatar(radius: 28, backgroundColor: MarketplaceColors.accentYellow, foregroundImage: p, child: const Icon(Icons.person, color: Colors.black));
                }),
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(onPressed: _updatingPhoto ? null : _changePhoto, icon: const Icon(Icons.photo_camera, color: Colors.white), label: Text(_updatingPhoto ? 'Updating...' : 'Change photo')),
              ]),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: cs.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Phone', filled: true, fillColor: cs.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailCtrl,
                enabled: false,
                decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: cs.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save, color: Colors.white), label: Text(_saving ? 'Saving...' : 'Save Changes')),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Account
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Account', style: context.textStyles.titleSmall?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Change Password'), trailing: const Icon(Icons.chevron_right), onTap: _openChangePasswordDialog),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('Notification Settings'), trailing: const Icon(Icons.chevron_right), onTap: _openNotificationSettings),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.language), title: const Text('Language'), trailing: const Icon(Icons.chevron_right), onTap: _openLanguageDialog),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy'), trailing: const Icon(Icons.chevron_right), onTap: _openPrivacySettings),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Support
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Support', style: context.textStyles.titleSmall?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              ListTile(leading: const Icon(Icons.support_agent), title: const Text('Contact Support'), trailing: const Icon(Icons.chevron_right), onTap: _contactSupport),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Terms & Conditions'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.terms)),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('Privacy Policy'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.privacyPolicy)),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Danger Zone
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Danger Zone', style: context.textStyles.titleSmall?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text('Delete Account'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

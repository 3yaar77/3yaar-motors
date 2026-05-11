import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/theme.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _loading = true;
  bool _saving = false;
  bool _showPhone = false;
  bool _showEmail = false;
  bool _allowMessages = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = doc.data() ?? {};
      setState(() {
        _showPhone = (d['showPhoneNumber'] as bool?) ?? false;
        _showEmail = (d['showEmail'] as bool?) ?? false;
        _allowMessages = (d['allowMessages'] as bool?) ?? true;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load privacy settings error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'showPhoneNumber': _showPhone,
        'showEmail': _showEmail,
        'allowMessages': _allowMessages,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privacy settings saved')));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Save privacy settings error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Privacy Settings', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 24),
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
                  child: Column(children: [
                    SwitchListTile(title: const Text('Show phone number'), value: _showPhone, onChanged: (v) => setState(() => _showPhone = v)),
                    const Divider(height: 1),
                    SwitchListTile(title: const Text('Show email'), value: _showEmail, onChanged: (v) => setState(() => _showEmail = v)),
                    const Divider(height: 1),
                    SwitchListTile(title: const Text('Allow messages'), value: _allowMessages, onChanged: (v) => setState(() => _allowMessages = v)),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save, color: Colors.white), label: Text(_saving ? 'Saving...' : 'Save')),
                )
              ]),
            ),
    );
  }
}

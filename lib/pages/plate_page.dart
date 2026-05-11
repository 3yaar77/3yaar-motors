import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/providers/auth_provider.dart';

class PlatePage extends StatefulWidget {
  const PlatePage({super.key});

  @override
  State<PlatePage> createState() => _PlatePageState();
}

class _PlatePageState extends State<PlatePage> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _emirates = const [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Ajman',
    'Fujairah',
    'Ras Al Khaimah',
    'Umm Al Quwain',
  ];

  String? _selectedEmirate;
  final _plateCodeCtrl = TextEditingController();
  final _plateNumberCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  bool _submitting = false;
  bool _upgradeEnabled = false;
  String? _selectedPackage; // featured | vip | urgent | topBoost

  @override
  void dispose() {
    _plateCodeCtrl.dispose();
    _plateNumberCtrl.dispose();
    _priceCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: MarketplaceColors.luxCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: MarketplaceColors.accentYellow, width: 1.5)),
      );

  Future<void> _publish() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final emirate = _selectedEmirate ?? 'Dubai';
      final code = _plateCodeCtrl.text.trim().toUpperCase();
      final number = _plateNumberCtrl.text.trim();
      final title = [emirate, if (code.isNotEmpty) code, number].where((e) => e.isNotEmpty).join(' ');
      final normalizedPhone = _ownerPhoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final price = int.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final docRef = FirebaseFirestore.instance.collection('listings').doc();
      final me = context.read<AuthProvider>().currentUser;
      final data = <String, dynamic>{
        'title': title,
        'brand': '',
        'model': '',
        'year': null,
        'price': price,
        'mileage': null,
        'location': emirate,
        'condition': '',
        'transmission': '',
        'category': 'Plates',
        'imageUrls': <String>[],
        'videoUrls': <String>[],
        'ownerId': me?.uid ?? '',
        'ownerName': (me?.displayName?.trim().isNotEmpty == true) ? me!.displayName!.trim() : 'Seller',
        'ownerPhone': normalizedPhone,
        'sellerPhone': normalizedPhone, // added for display compatibility
        'isVip': false,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        // Plate-specific fields to help UI layers (optional)
        'emirate': emirate,
        'plateCode': code,
        'plateNumber': number,
        'description': _descriptionCtrl.text.trim(),
      };
      await docRef.set(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plate published')));
      context.go(AppRoutes.home);
    } catch (e) {
      debugPrint('Publish plate failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish plate')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onPublishPressed() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    // If upgrade flow is enabled, require a package and take user to payment page first
    if (_upgradeEnabled) {
      if (_selectedPackage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an upgrade package')));
        return;
      }

      final pkg = _selectedPackage!;
      final paid = await context.push<bool>(
        '${AppRoutes.payment}?id=&type=plate&pkg=$pkg',
      );
      if (paid != true) return; // Payment cancelled or failed
    }

    await _publish();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Plate Number'), centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [MarketplaceColors.luxBgGradientStart, MarketplaceColors.luxBgGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String>(
                value: _selectedEmirate,
                items: _emirates.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedEmirate = v),
                decoration: _dec('Emirate'),
                style: const TextStyle(color: Colors.white),
                dropdownColor: MarketplaceColors.luxCard,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                validator: (v) => (v == null || v.isEmpty) ? 'Select emirate' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _plateCodeCtrl,
                decoration: _dec('Plate code').copyWith(hintText: 'e.g. A'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _plateNumberCtrl,
                decoration: _dec('Plate number').copyWith(hintText: 'e.g. 12345'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isEmpty) return 'Enter digits only';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _priceCtrl,
                decoration: _dec('Price (AED)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ownerPhoneCtrl,
                decoration: _dec('Owner phone / WhatsApp'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 6) return 'Enter a valid phone';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: _dec('Description (optional)'),
                maxLines: 4,
              ),

              const SizedBox(height: AppSpacing.lg),
              // Upgrade toggle
              Container(
                decoration: BoxDecoration(
                  color: MarketplaceColors.luxCard,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  title: const Text('Upgrade this listing', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Enable to choose a paid package', style: TextStyle(color: Colors.white70)),
                  value: _upgradeEnabled,
                  activeColor: Colors.black,
                  activeTrackColor: MarketplaceColors.accentYellow,
                  onChanged: (v) => setState(() {
                    _upgradeEnabled = v;
                    if (!v) _selectedPackage = null;
                  }),
                ),
              ),

              if (_upgradeEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                _PackageChoiceCard(
                  title: 'VIP Listing',
                  priceLabel: 'AED 100',
                  value: 'vip',
                  selected: _selectedPackage == 'vip',
                  onTap: () => setState(() => _selectedPackage = 'vip'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _PackageChoiceCard(
                  title: 'Featured Listing',
                  priceLabel: 'AED 50',
                  value: 'featured',
                  selected: _selectedPackage == 'featured',
                  onTap: () => setState(() => _selectedPackage = 'featured'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _PackageChoiceCard(
                  title: 'Urgent Listing',
                  priceLabel: 'AED 30',
                  value: 'urgent',
                  selected: _selectedPackage == 'urgent',
                  onTap: () => setState(() => _selectedPackage = 'urgent'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _PackageChoiceCard(
                  title: 'Top Boost',
                  priceLabel: 'AED 75',
                  value: 'topBoost',
                  selected: _selectedPackage == 'topBoost',
                  onTap: () => setState(() => _selectedPackage = 'topBoost'),
                ),
              ],
            ]),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _onPublishPressed,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                  : const Icon(Icons.publish, color: Colors.black),
              label: Text(_submitting ? 'Publishing…' : 'Publish', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceColors.accentYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ).copyWith(splashFactory: NoSplash.splashFactory),
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageChoiceCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PackageChoiceCard({required this.title, required this.priceLabel, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final Color borderColor = selected ? MarketplaceColors.upgradeGold : Colors.white.withOpacity(0.06);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MarketplaceColors.luxCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              const SizedBox(height: 4),
              Text(priceLabel, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: MarketplaceColors.upgradeGold)
          else
            Icon(Icons.radio_button_unchecked, color: Theme.of(context).iconTheme.color),
        ]),
      ),
    );
  }
}

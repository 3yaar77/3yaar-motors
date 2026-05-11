import 'package:autoreel/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/plate_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadPlatePage extends StatefulWidget {
  const UploadPlatePage({super.key});
  @override
  State<UploadPlatePage> createState() => _UploadPlatePageState();
}

class _UploadPlatePageState extends State<UploadPlatePage> {
  final _formKey = GlobalKey<FormState>();
  String _plateNumber = '';
  String _emirate = 'Dubai';
  String _price = '';
  String _sellerPhone = '';
  String _description = '';
  String _listingType = 'Free listing'; // derived at submit
  bool _upgradeEnabled = false;
  String? _paidPackage; // vip | featured | urgent | topBoost

  int _upgradePriceForType(String t) {
    switch (t) {
      case 'VIP listing':
        return 29;
      case 'Featured listing':
        return 49;
      case 'Urgent listing':
        return 19;
      default:
        return 0;
    }
  }

  final List<String> _emirates = const ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Fujairah', 'Ras Al Khaimah', 'Umm Al Quwain'];

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final price = int.parse(_price.trim());
    final normalizedPhone = (_sellerPhone.isNotEmpty ? _sellerPhone : '971500000000').replaceAll(RegExp(r'[^0-9]'), '');

    // Upgrade toggle flow for plates
    if (_upgradeEnabled) {
      if (_paidPackage == null || _paidPackage!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a paid package')));
        return;
      }
      final ok = await context.pushNamed('payment', queryParameters: {'id': '', 'type': 'new', 'pkg': _paidPackage!});
      if (ok != true) return;
    }

    // Derive listing type
    String finalListingType = 'Free listing';
    bool isVip = false, isFeatured = false, isUrgent = false;
    bool isPinned = false;
    if (_upgradeEnabled) {
      switch (_paidPackage) {
        case 'vip': finalListingType = 'VIP listing'; isVip = true; break;
        case 'featured': finalListingType = 'Featured listing'; isFeatured = true; break;
        case 'urgent': finalListingType = 'Urgent listing'; isUrgent = true; break;
        case 'topBoost': finalListingType = 'Top Boost'; isPinned = true; break;
      }
    }

    final plate = Plate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      plateNumber: _plateNumber.trim(),
      emirate: _emirate,
      price: price,
      sellerPhone: normalizedPhone,
      description: _description.trim(),
      createdAt: DateTime.now(),
      listingType: finalListingType,
      isVip: isVip,
      isFeatured: isFeatured,
      isUrgent: isUrgent,
      isPinned: isPinned,
      paymentStatus: _upgradeEnabled ? 'paid' : null,
      upgradePrice: null,
      ownerId: context.read<AuthProvider>().currentUser?.uid ?? '',
    );

    // Persist minimal required fields to Firestore for shared backend
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      final parts = _plateNumber.trim().split(RegExp(r"\s+"));
      final code = parts.isNotEmpty ? parts.first : '';
      final number = parts.length > 1 ? parts.sublist(1).join(' ') : (parts.isNotEmpty ? parts.first : '');
      await FirebaseFirestore.instance.collection('plates').doc(plate.id).set({
        'emirate': _emirate,
        'plateCode': code,
        'plateNumber': number,
        'price': price,
        'sellerPhone': normalizedPhone,
        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save plate to Firestore: $e');
    }

    // Removed local/global in-memory listings injection to enforce Firestore-only source

    await context.read<PlateProvider>().addPlate(plate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing Added')));
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Plate Listing'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Plate Details', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            // Upgrade toggle
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: SwitchListTile(
                title: const Text('Upgrade this listing'),
                subtitle: const Text('Enable to choose a paid package'),
                value: _upgradeEnabled,
                onChanged: (v) => setState(() { _upgradeEnabled = v; if (!v) _paidPackage = null; }),
                activeColor: Colors.black,
                activeTrackColor: MarketplaceColors.accentYellow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            if (_upgradeEnabled) ...[
              const SizedBox(height: 6),
              Text('Choose an upgrade package', style: context.textStyles.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              _paidTile(cs, label: 'VIP listing', value: 'vip'),
              _paidTile(cs, label: 'Featured listing', value: 'featured'),
              _paidTile(cs, label: 'Urgent listing', value: 'urgent'),
              _paidTile(cs, label: 'Top Boost', value: 'topBoost', customPrice: 75),
            ],
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              label: 'Plate Number (e.g. A 12345)',
              onSaved: (v) => _plateNumber = v?.trim() ?? '',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _emirate,
              decoration: InputDecoration(
                labelText: 'Emirate',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
              items: _emirates.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _emirate = v ?? 'Dubai'),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              label: 'Price (AED)',
              keyboardType: TextInputType.number,
              onSaved: (v) => _price = v?.trim() ?? '',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null) return 'Enter a valid number';
                if (n <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              label: 'Seller Phone (WhatsApp, e.g. 971501234567)',
              keyboardType: TextInputType.phone,
              onSaved: (v) => _sellerPhone = v?.trim() ?? '',
              validator: (v) => null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
              onSaved: (v) => _description = v?.trim() ?? '',
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: AppSpacing.paddingMd,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ).copyWith(splashFactory: NoSplash.splashFactory),
              child: Text('Post Plate Listing', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onPrimary)),
            ),
            const SizedBox(height: AppSpacing.xl),
          ]),
        ),
      ),
    );
  }

  Widget _listingTile(ColorScheme cs, {required String label}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: RadioListTile<String>(
        value: label,
        groupValue: _listingType,
        onChanged: (v) => setState(() => _listingType = v ?? 'Free listing'),
        title: Text(label),
        subtitle: (_listingType == label) ? Text('AED ${_upgradePriceForType(label)}') : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _paidTile(ColorScheme cs, {required String label, required String value, int? customPrice}) {
    final price = customPrice ?? _upgradePriceForType(label);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _paidPackage,
        onChanged: (v) => setState(() => _paidPackage = v),
        title: Text(label),
        subtitle: (_paidPackage == value) ? Text('AED $price') : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildTextField({required String label, TextInputType keyboardType = TextInputType.text, required FormFieldSetter<String> onSaved, required FormFieldValidator<String> validator}) {
    return TextFormField(
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}
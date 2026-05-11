import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/utils/pick_media.dart';
import 'package:autoreel/services/image_storage_service.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/accessory_provider.dart';
import 'package:autoreel/nav.dart';

class AddAccessoryListingPage extends StatefulWidget {
  const AddAccessoryListingPage({super.key});

  @override
  State<AddAccessoryListingPage> createState() => _AddAccessoryListingPageState();
}

class _AddAccessoryListingPageState extends State<AddAccessoryListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _condition = 'New';
  String _category = 'Accessories';
  bool _submitting = false;
  final List<Uint8List> _images = <Uint8List>[];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picks = await pickMultipleMediaWeb(accept: 'image/*');
      if (picks.isEmpty) return;
      final imgs = picks.where((p) => p.isVideo == false).toList();
      if (imgs.isEmpty) return;
      setState(() {
        _images.addAll(imgs.map((e) => Uint8List.fromList(e.bytes)));
      });
    } catch (e) {
      debugPrint('pickImages error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one image')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final col = FirebaseFirestore.instance.collection('accessories');
      final doc = col.doc();
      final id = doc.id;

      // Upload images first
      final urls = await ImageStorageService.uploadAccessoryImages(accessoryId: id, images: _images);
      if (urls.isEmpty || !urls.every(ImageStorageService.isValidDownloadUrl)) {
        throw Exception('Image upload failed');
      }

      final int price = int.tryParse(_priceCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'price': price,
        'condition': _condition,
        'category': _category,
        'description': _descCtrl.text.trim(),
        // Save only validated Firebase HTTPS download URLs
        'images': urls,
        'location': _locationCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'ownerId': user.uid,
        'ownerName': (user.displayName ?? '').trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isFeatured': false,
        'isVip': false,
        'isUrgent': false,
        'listingType': 'accessory',
      };

      await doc.set(data);

      // Force-refresh accessories so images[0] appears instantly in grid/details
      try {
        if (mounted) await context.read<AccessoryProvider>().refresh();
      } catch (e) {
        debugPrint('Accessory post-save refresh error: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accessory listing published ✔')));
      context.go(AppRoutes.home);
    } catch (e) {
      debugPrint('AddAccessory submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Accessory Listing'),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [MarketplaceColors.luxBgGradientStart, MarketplaceColors.luxBgGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Images
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Images', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    Text('${_images.length} selected', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._images.map((img) => ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.memory(img, width: 90, height: 90, fit: BoxFit.cover),
                        )),
                    InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: MarketplaceColors.luxOuterBorder, width: 1),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_a_photo, color: MarketplaceColors.accentYellow),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDecoration('Title'),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter title' : null,
                ),
                const SizedBox(height: 12),

                // Price
                TextFormField(
                  controller: _priceCtrl,
                  decoration: _inputDecoration('Price (AED)'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter price' : null,
                ),
                const SizedBox(height: 12),

                // Condition & Category
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _condition,
                      items: const [
                        DropdownMenuItem(value: 'New', child: Text('New')),
                        DropdownMenuItem(value: 'Used', child: Text('Used')),
                      ],
                      onChanged: (v) => setState(() => _condition = v ?? 'New'),
                      decoration: _inputDecoration('Condition'),
                      dropdownColor: MarketplaceColors.luxItemCard,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      items: const [
                        DropdownMenuItem(value: 'Wheels & Tires', child: Text('Wheels & Tires')),
                        DropdownMenuItem(value: 'Screens & Audio', child: Text('Screens & Audio')),
                        DropdownMenuItem(value: 'Lights', child: Text('Lights')),
                        DropdownMenuItem(value: 'Interior Parts', child: Text('Interior Parts')),
                        DropdownMenuItem(value: 'Exterior Parts', child: Text('Exterior Parts')),
                        DropdownMenuItem(value: 'Cleaning & Care', child: Text('Cleaning & Care')),
                        DropdownMenuItem(value: 'Performance Parts', child: Text('Performance Parts')),
                        DropdownMenuItem(value: 'Accessories', child: Text('Accessories')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? 'Accessories'),
                      decoration: _inputDecoration('Category'),
                      dropdownColor: MarketplaceColors.luxItemCard,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // City / Location
                TextFormField(
                  controller: _locationCtrl,
                  decoration: _inputDecoration('City / Location'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: _inputDecoration('Description'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Seller phone number
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: _inputDecoration('Seller phone number'),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.check_circle, color: Colors.black),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MarketplaceColors.accentYellow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    label: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Publish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                  ),
                )
              ]),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

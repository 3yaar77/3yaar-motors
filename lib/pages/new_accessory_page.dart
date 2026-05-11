import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/providers/accessory_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/services/image_storage_service.dart';
import 'package:autoreel/utils/pick_media.dart';
import 'package:autoreel/theme.dart';

class NewAccessoryPage extends StatefulWidget {
  final String? accessoryId; // if provided -> edit mode
  const NewAccessoryPage({super.key, this.accessoryId});

  @override
  State<NewAccessoryPage> createState() => _NewAccessoryPageState();
}

class _NewAccessoryPageState extends State<NewAccessoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _condition = 'New';
  String _category = 'Accessories';
  bool _submitting = false;

  final List<_LocalImage> _images = [];
  // Existing images already saved in Firestore (HTTPS URLs)
  List<String> _existingImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.accessoryId != null) {
      final p = context.read<AccessoryProvider>();
      final existing = p.items.firstWhere(
        (e) => e.id == widget.accessoryId,
        orElse: () => Accessory(
            id: '',
            title: '',
            price: 0,
            condition: '',
            category: '',
            description: '',
            images: const [],
            location: '',
            sellerPhone: '',
            ownerId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
      );
      if (existing.id.isNotEmpty) {
        _titleCtrl.text = existing.title;
        _priceCtrl.text = existing.price.toString();
        _descCtrl.text = existing.description;
        _phoneCtrl.text = existing.sellerPhone;
        _locationCtrl.text = existing.location;
        _condition = existing.condition.isNotEmpty ? existing.condition : 'New';
        _category =
            existing.category.isNotEmpty ? existing.category : 'Accessories';
        _existingImages = List<String>.from(existing.images);
      }
      // Fallback: ensure freshest data directly from Firestore
      _ensureFreshAccessory();
    }
  }

  Future<void> _ensureFreshAccessory() async {
    try {
      final id = widget.accessoryId;
      if (id == null || id.isEmpty) return;
      final snap = await FirebaseFirestore.instance
          .collection('accessories')
          .doc(id)
          .get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final imgs =
          (data['images'] as List?)?.whereType<String>().toList() ?? const [];
      if (mounted) setState(() => _existingImages = imgs);
    } catch (e) {
      debugPrint('Load existing accessory error: $e');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picked = await pickMultipleMediaWeb(accept: 'image/*');
      for (final m in picked) {
        final bytes = Uint8List.fromList(m.bytes);
        _images
            .add(_LocalImage(name: m.name, mimeType: m.mimeType, bytes: bytes));
      }
      setState(() {});
    } catch (e) {
      debugPrint('Pick images error: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? '';
    try {
      final col = FirebaseFirestore.instance.collection('accessories');
      String id = widget.accessoryId ?? '';
      final now = FieldValue.serverTimestamp();
      if (id.isEmpty) {
        final doc = col.doc();
        id = doc.id;
        // Upload images first
        final urls = await ImageStorageService.uploadAccessoryImages(
            accessoryId: id, images: _images.map((e) => e.bytes).toList());
        if (urls.isEmpty ||
            !urls.every(ImageStorageService.isValidDownloadUrl)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Upload failed: invalid image URLs')));
          }
          return;
        }
        final data = {
          'title': _titleCtrl.text.trim(),
          'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
          'condition': _condition,
          'category': _category,
          'description': _descCtrl.text.trim(),
          'images': urls, // only valid HTTPS URLs
          'location': _locationCtrl.text.trim(),
          'sellerPhone': _phoneCtrl.text.trim(),
          'ownerId': uid,
          'createdAt': now,
          'updatedAt': now,
        };
        await doc.set(data);
      } else {
        // Edit: append any new images and update fields
        List<String> urls = [];
        if (_images.isNotEmpty) {
          urls = await ImageStorageService.uploadAccessoryImages(
              accessoryId: id, images: _images.map((e) => e.bytes).toList());
          // Keep existing images unchanged if upload produced invalid URLs
          urls = urls.where(ImageStorageService.isValidDownloadUrl).toList();
        }
        final update = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
          'condition': _condition,
          'category': _category,
          'description': _descCtrl.text.trim(),
          // If new images picked, save existing + new in order; otherwise keep existing untouched
          if (urls.isNotEmpty) 'images': [..._existingImages, ...urls],
          'location': _locationCtrl.text.trim(),
          'sellerPhone': _phoneCtrl.text.trim(),
          'updatedAt': now,
        };
        await col.doc(id).update(update);
      }
      // Force-refresh accessories so images[0] appears instantly in grid/details
      try {
        if (mounted) await context.read<AccessoryProvider>().refresh();
      } catch (e) {
        debugPrint('Accessory post-save refresh error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
        context.pop();
      }
    } catch (e) {
      debugPrint('Save accessory error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.accessoryId == null ? 'New Accessory' : 'Edit Accessory')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _LabeledField(
              label: 'Title',
              child: TextFormField(
                controller: _titleCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: _decoration(context, 'Title'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _LabeledField(
                  label: 'Price (AED)',
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _decoration(context, 'Price'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'Condition',
                  child: DropdownButtonFormField<String>(
                    value: _condition,
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New')),
                      DropdownMenuItem(value: 'Used', child: Text('Used')),
                    ],
                    onChanged: (v) => setState(() => _condition = v ?? 'New'),
                    decoration: _decoration(context, 'Condition'),
                    dropdownColor: MarketplaceColors.luxItemCard,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Category',
              child: DropdownButtonFormField<String>(
                value: _category,
                items: const [
                  DropdownMenuItem(
                      value: 'Wheels & Tires', child: Text('Wheels & Tires')),
                  DropdownMenuItem(
                      value: 'Screens & Audio', child: Text('Screens & Audio')),
                  DropdownMenuItem(value: 'Lights', child: Text('Lights')),
                  DropdownMenuItem(
                      value: 'Interior Parts', child: Text('Interior Parts')),
                  DropdownMenuItem(
                      value: 'Exterior Parts', child: Text('Exterior Parts')),
                  DropdownMenuItem(
                      value: 'Cleaning & Care', child: Text('Cleaning & Care')),
                  DropdownMenuItem(
                      value: 'Performance Parts',
                      child: Text('Performance Parts')),
                  DropdownMenuItem(
                      value: 'Accessories', child: Text('Accessories')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setState(() => _category = v ?? 'Accessories'),
                decoration: _decoration(context, 'Category'),
                dropdownColor: MarketplaceColors.luxItemCard,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'City / Location',
              child: TextFormField(
                controller: _locationCtrl,
                decoration: _decoration(context, 'City'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Seller phone number',
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: _decoration(context, '+9715...'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Description',
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: _decoration(context, 'Describe your item'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library, color: Colors.black),
                  label: const Text('Add photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MarketplaceColors.accentYellow,
                    foregroundColor: Colors.black,
                  ).copyWith(splashFactory: NoSplash.splashFactory),
                ),
                const SizedBox(width: 12),
                Text('${_existingImages.length + _images.length} selected',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            if (_existingImages.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _existingImages.map((u) => _NetworkThumb(url: u)).toList(),
              ),
            if (_existingImages.isNotEmpty && _images.isNotEmpty)
              const SizedBox(height: 8),
            if (_images.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images.map((e) => _ThumbnailTile(img: e)).toList(),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketplaceColors.accentYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ).copyWith(splashFactory: NoSplash.splashFactory),
                child: Text(_submitting ? 'Saving...' : 'Save'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  InputDecoration _decoration(BuildContext context, String hint) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.white54),
      );
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: cs.onSurfaceVariant)),
      ),
      child,
    ]);
  }
}

class _LocalImage {
  final String name;
  final String mimeType;
  final Uint8List bytes;
  _LocalImage(
      {required this.name, required this.mimeType, required this.bytes});
}

class _ThumbnailTile extends StatelessWidget {
  final _LocalImage img;
  const _ThumbnailTile({required this.img});
  bool get _renderable =>
      img.mimeType.contains('jpeg') ||
      img.mimeType.contains('jpg') ||
      img.mimeType.contains('png') ||
      img.mimeType.contains('webp') ||
      img.mimeType.contains('gif');
  @override
  Widget build(BuildContext context) {
    if (_renderable) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            Image.memory(img.bytes, width: 96, height: 96, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      alignment: Alignment.center,
      child: const Icon(Icons.insert_photo, color: Colors.white70, size: 20),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String url;
  const _NetworkThumb({required this.url});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 96,
          height: 96,
          color: Colors.black.withValues(alpha: 0.2),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

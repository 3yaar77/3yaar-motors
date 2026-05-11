import 'dart:async';
import 'dart:typed_data';
import 'dart:io' if (dart.library.html) 'dart:html' as platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/pages/image_crop_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  // Controllers (as requested)
  final TextEditingController makeController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController mileageController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController locationController = TextEditingController(text: 'Dubai');
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;
  final PageController _pageController = PageController();
  List<Uint8List> _imageBytes = [];

  // Upgrade toggle for image listings
  bool _upgradeEnabled = false;
  String? _paidPackage; // vip | featured | urgent | topBoost

  // Car conditions (multi-select chips)
  final List<String> _conditionOptions = const ['New', 'Used', 'Agency warranty', 'GCC specs'];
  final Set<String> _selectedConditions = <String>{};

  @override
  void initState() {
    super.initState();
    // Rebuild overlay details as user types
    for (final c in [
      makeController,
      modelController,
      yearController,
      mileageController,
      priceController,
      locationController,
      phoneController,
      descriptionController,
    ]) {
      c.addListener(() => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    mileageController.dispose();
    priceController.dispose();
    locationController.dispose();
    phoneController.dispose();
    descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final List<XFile> picked = await _picker.pickMultiImage(maxWidth: 2000, imageQuality: 85);
      if (picked.isEmpty) return;
      List<XFile> limited = picked;
      if (picked.length > 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 10 images allowed.')));
        }
        limited = picked.take(10).toList();
      }
      debugPrint('Picked images: ${picked.length}, using: ${limited.length}');
      final List<Uint8List> croppedList = [];
      for (final x in limited) {
        try {
          final bytes = await x.readAsBytes();
          final cropped = await showImageCropper(context, bytes, aspectRatio: 4 / 3);
          if (cropped != null) croppedList.add(cropped);
        } catch (e) {
          debugPrint('crop error: $e');
        }
      }
      if (!mounted) return;
      setState(() => _imageBytes = croppedList);
    } catch (e) {
      debugPrint('pickImages error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _toggleCondition(String label) {
    setState(() {
      if (_selectedConditions.contains(label)) {
        _selectedConditions.remove(label);
      } else {
        _selectedConditions.add(label);
      }
    });
  }

  // Banned words filter (Arabic-aware normalization)
  static const List<String> _bannedWords = [
    'شقة', 'بيت', 'غرفة', 'ايفون', 'لابتوب', 'وظيفة', 'عطر', 'سماعات', 'ساعة',
    // English equivalents (optional)
    'apartment', 'house', 'room', 'iphone', 'laptop', 'job', 'perfume', 'headphones', 'watch',
  ];

  String _normalizeArabic(String input) {
    var s = input;
    // Remove diacritics and tatweel
    s = s.replaceAll(RegExp('[\u064B-\u0652\u0640]'), '');
    // Unify alef variants and ya/teh marbuta
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    return s;
  }

  bool _hasBannedWords(String text) {
    final normalized = _normalizeArabic(text.toLowerCase());
    for (final w in _bannedWords) {
      final nw = _normalizeArabic(w.toLowerCase());
      if (nw.isEmpty) continue;
      if (normalized.contains(nw)) {
        debugPrint('Banned word detected: $w');
        return true;
      }
    }
    return false;
  }

  void _publish() {
    // Validations per requirements
    if (_imageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least one image')));
      return;
    }
    if (makeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Make is required')));
      return;
    }
    if (modelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model is required')));
      return;
    }
    if (priceController.text.trim().isEmpty) {
      // Keep required, but no amount/range validation per new rules
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price is required')));
      return;
    }

    // Banned-words filter for non-car ads
    final moderationText = '${makeController.text} ${modelController.text} ${descriptionController.text}';
    if (_hasBannedWords(moderationText)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يسمح فقط بإعلانات السيارات')));
      return;
    }

    // Upgrade flow: require paid option and simulate payment
    if (_upgradeEnabled) {
      if (_paidPackage == null || _paidPackage!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a paid package')));
        return;
      }
    }

    Future<void> proceed() async {
      // For now, only show success message (no backend connection)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo Reel Published Successfully')));
    }

    if (_upgradeEnabled) {
      context.pushNamed('payment', queryParameters: {'id': '', 'type': 'new', 'pkg': _paidPackage!}).then((ok) {
        if (ok == true) proceed();
      });
      return;
    }

    proceed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Photo Reel'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // go_router back to keep app navigation intact (Navigator.pop equivalent)
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Reels-style vertical preview
            _PreviewReel(
              imageBytes: _imageBytes,
              controller: _pageController,
              overlay: _OverlayDetails(
                make: makeController.text,
                model: modelController.text,
                year: yearController.text,
                mileage: mileageController.text,
                price: priceController.text,
                location: locationController.text,
                phone: phoneController.text,
                description: descriptionController.text,
                conditions: _selectedConditions.toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Upgrade toggle + packages
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
              const SizedBox(height: AppSpacing.sm),
              _PaidTile(label: 'VIP listing', value: 'vip', groupValue: _paidPackage, onChanged: (v) => setState(() => _paidPackage = v), price: 100),
              _PaidTile(label: 'Featured listing', value: 'featured', groupValue: _paidPackage, onChanged: (v) => setState(() => _paidPackage = v), price: 50),
              _PaidTile(label: 'Urgent listing', value: 'urgent', groupValue: _paidPackage, onChanged: (v) => setState(() => _paidPackage = v), price: 30),
              _PaidTile(label: 'Top Boost', value: 'topBoost', groupValue: _paidPackage, onChanged: (v) => setState(() => _paidPackage = v), price: 75),
              const SizedBox(height: AppSpacing.md),
            ],

            // Upload + Publish buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPicking ? null : _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_isPicking ? 'Picking…' : 'Upload Images'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary, width: 1.5),
                    padding: AppSpacing.paddingMd,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _publish,
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Publish Photo Reel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: AppSpacing.paddingMd,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.xl),
            Text('Car Details', style: text.titleLarge?.bold),
            const SizedBox(height: AppSpacing.md),

            _LabeledField(controller: makeController, label: 'Make', hint: 'e.g., Mercedes-Benz', keyboardType: TextInputType.text, requiredField: true),
            const SizedBox(height: AppSpacing.md),
            _LabeledField(controller: modelController, label: 'Model', hint: 'e.g., G-Class G63 AMG', keyboardType: TextInputType.text, requiredField: true),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: _LabeledField(controller: yearController, label: 'Year', hint: 'e.g., 2022', keyboardType: TextInputType.number)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _LabeledField(controller: mileageController, label: 'Mileage KM', hint: 'e.g., 15000', keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: _LabeledField(controller: priceController, label: 'Price AED', hint: 'e.g., 850000', keyboardType: TextInputType.number, requiredField: true)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _LabeledField(controller: locationController, label: 'Location', hint: 'e.g., Dubai', keyboardType: TextInputType.text)),
            ]),
            const SizedBox(height: AppSpacing.md),
            _LabeledField(controller: descriptionController, label: 'Description', hint: 'e.g., Full options, dealer maintained…', maxLines: 4, keyboardType: TextInputType.multiline),

            const SizedBox(height: AppSpacing.lg),
            const SizedBox(height: AppSpacing.xxl),
          ]),
        ),
      ),
    );
  }
}

class _PreviewReel extends StatelessWidget {
  const _PreviewReel({required this.imageBytes, required this.controller, required this.overlay});
  final List<Uint8List> imageBytes;
  final PageController controller;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;
    final previewHeight = height * 0.58; // Tall, reels-like window

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: previewHeight,
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, border: Border.all(color: cs.outline.withValues(alpha: 0.2))),
        child: imageBytes.isEmpty
            ? _EmptyPreview()
            : Stack(children: [
                PageView.builder(
                  controller: controller,
                  scrollDirection: Axis.vertical,
                  itemCount: imageBytes.length,
                  itemBuilder: (context, index) => SizedBox.expand(
                    child: Image.memory(imageBytes[index], fit: BoxFit.cover),
                  ),
                ),
                // Dark gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Details overlay
                Positioned(left: 16, right: 16, bottom: 16, child: overlay),
              ]),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.photo_library_outlined, size: 56, color: cs.primary),
        const SizedBox(height: AppSpacing.sm),
        Text('Add photos to preview your reel', style: text.titleMedium?.withColor(cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _OverlayDetails extends StatelessWidget {
  const _OverlayDetails({
    required this.make,
    required this.model,
    required this.year,
    required this.mileage,
    required this.price,
    required this.location,
    required this.phone,
    required this.description,
    required this.conditions,
  });

  final String make;
  final String model;
  final String year;
  final String mileage;
  final String price;
  final String location;
  final String phone;
  final String description;
  final List<String> conditions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    final title = [make, model, if (year.trim().isNotEmpty) year.trim()].where((e) => e.trim().isNotEmpty).join(' ');
    final meta1 = [
      if (mileage.trim().isNotEmpty) '${mileage.trim()} km',
      if (price.trim().isNotEmpty) 'AED ${price.trim()}',
    ].join(' • ');
    final meta2 = [
      if (location.trim().isNotEmpty) location.trim(),
      if (phone.trim().isNotEmpty) phone.trim(),
    ].join(' • ');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (conditions.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: conditions.map((c) => _Badge(label: c)).toList()),
      if (conditions.isNotEmpty) const SizedBox(height: AppSpacing.sm),
      Text(
        title.isEmpty ? 'Your car title' : title,
        style: text.headlineSmall?.bold.withColor(Colors.white),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 6),
      if (meta1.isNotEmpty)
        Text(meta1, style: text.titleMedium?.semiBold.withColor(Colors.white.withValues(alpha: 0.9))),
      if (meta2.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(meta2, style: text.titleSmall?.withColor(Colors.white.withValues(alpha: 0.9))),
      ],
      if (description.trim().isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(description.trim(), style: text.bodyMedium?.withColor(Colors.white.withValues(alpha: 0.85)), maxLines: 3, overflow: TextOverflow.ellipsis),
      ],
    ]);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(24), border: Border.all(color: cs.primary, width: 1)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.withColor(cs.primary)),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.controller, required this.label, this.hint, this.maxLines = 1, this.keyboardType = TextInputType.text, this.requiredField = false});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      ),
      validator: (val) {
        if (!requiredField) return null;
        if (val == null || val.trim().isEmpty) return 'Required';
        return null;
      },
    );
  }
}

class _PaidTile extends StatelessWidget {
  const _PaidTile({required this.label, required this.value, required this.groupValue, required this.onChanged, required this.price});
  final String label; final String value; final String? groupValue; final ValueChanged<String?> onChanged; final int price;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: cs.outline.withValues(alpha: 0.2))),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(label),
        subtitle: (groupValue == value) ? Text('AED $price') : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}


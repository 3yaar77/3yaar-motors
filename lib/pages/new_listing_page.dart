import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
// car_data dropdowns removed; free-text fields to match Upload Reel
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/utils/pick_media.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/listings_provider.dart';
import 'package:autoreel/data/car_data.dart';
import 'package:autoreel/pages/image_crop_page.dart';
import 'package:autoreel/utils/blob_url.dart';
import 'dart:convert';
import 'package:autoreel/services/image_storage_service.dart';

class NewListingPage extends StatefulWidget {
  const NewListingPage({super.key});

  @override
  State<NewListingPage> createState() => _NewListingPageState();
}

class _NewListingPageState extends State<NewListingPage> {
  final _formKey = GlobalKey<FormState>();
  // Fields (match Upload Reel)
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  final _scrollCtrl = ScrollController();

  // Media picker state
  final ImagePicker _picker = ImagePicker();
  // renamed to selectedImages to make intent explicit and avoid local-shadowing
  final List<_LocalImage> selectedImages = [];
  bool _picking = false;
  bool _submitting = false;
  // Listing type state
  String _listingType = 'Free listing'; // derived at publish
  // Upgrade flow toggle and selection
  bool _upgradeEnabled = false;
  String? _paidPackage; // vip | featured | urgent | topBoost
  // Condition (chips)
  // final List<String> _conditions = const ['New', 'Used', 'Agency warranty', 'GCC specs'];
  // String? _selectedCondition;

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

  @override
  void dispose() {
    // _titleCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _mileageCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _descriptionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Processing moved to ImageUploadHelper

  Future<void> _pickImages() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      if (kIsWeb) {
        final picked = await pickMultipleMediaWeb(accept: 'image/*');
        if (picked.isNotEmpty) {
          final List<_LocalImage> toAdd = [];
          for (final e in picked) {
            // Keep all types, including HEIC/HEIF, but cropping preview will only apply to decodable formats
            final mt = (e.mimeType).toLowerCase();
            final isRenderable = mt.contains('jpeg') || mt.contains('jpg') || mt.contains('png') || mt.contains('webp') || mt.contains('gif');
            Uint8List? finalBytes;
            String? preview;
            if (isRenderable) {
              // Open cropper; if canceled, skip this file
              final cropped = await showImageCropper(context, Uint8List.fromList(e.bytes), aspectRatio: 4 / 3);
              if (cropped == null) continue;
              finalBytes = Uint8List.fromList(cropped);
              // Use an object URL for efficient preview on web
              preview = createObjectUrlFromBytes(cropped, mimeType: 'image/png') ?? e.objectUrl;
            } else {
              // Non-renderable in web (e.g., HEIC): keep original bytes; preview stays null and UI will show a placeholder tile
              finalBytes = Uint8List.fromList(e.bytes);
              preview = null;
            }
            toAdd.add(_LocalImage(
              name: e.name,
              mimeType: mt.isEmpty ? 'application/octet-stream' : mt,
              bytes: finalBytes,
              previewUrl: preview,
            ));
          }
          if (mounted && toAdd.isNotEmpty) {
            setState(() => selectedImages.addAll(toAdd));
          }
        }
      } else {
        final List<XFile> files = await _picker.pickMultiImage(maxWidth: 2000, imageQuality: 90);
        if (files.isNotEmpty) {
          final List<_LocalImage> toAdd = [];
          for (final f in files) {
            try {
              final original = await f.readAsBytes();
              final cropped = await showImageCropper(context, original, aspectRatio: 4 / 3);
              if (cropped == null) continue;
              toAdd.add(_LocalImage(
                name: f.name,
                mimeType: 'image/jpeg',
                bytes: Uint8List.fromList(cropped),
                previewUrl: null,
              ));
            } catch (e) {
              debugPrint('Read/crop picked image failed: $e');
            }
          }
          if (mounted && toAdd.isNotEmpty) setState(() => selectedImages.addAll(toAdd));
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to select images')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // Video picking removed — this page is images-only

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
        ),
        title: Text('Motix',
            style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Title
                  Text('New Listing',
                      style: context.textStyles.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.lg),

                  // Images section
                  _LabeledField(
                    label: 'Add car images',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: MarketplaceColors.luxCard,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: selectedImages.isEmpty
                              ? Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.photo_library_rounded, size: 36, color: Colors.white70),
                                    const SizedBox(height: 8),
                                    Text('Tap to add images (multiple)', style: context.textStyles.labelLarge?.copyWith(color: Colors.white70)),
                                  ]),
                                )
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(children: [
                                      ...selectedImages.asMap().entries.map((e) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Stack(children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: _ThumbnailTile(img: e.value),
                                              ),
                                              Positioned(
                                                right: 4,
                                                top: 4,
                                                child: InkWell(
                                                  onTap: () => setState(() => selectedImages.removeAt(e.key)),
                                                  child: Container(
                                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                                                    padding: const EdgeInsets.all(2),
                                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                              )
                                            ]),
                                          )),
                                      GestureDetector(
                                        onTap: _pickImages,
                                        child: Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            color: MarketplaceColors.luxCard,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                          ),
                                          child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white70),
                                        ),
                                      )
                                    ]),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${selectedImages.length} image(s) selected', style: context.textStyles.labelSmall?.copyWith(color: Colors.white70)),
                    ]),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Upgrade toggle + paid options visibility
                  Container(
                    decoration: BoxDecoration(color: MarketplaceColors.luxCard, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                    child: SwitchListTile(
                      title: const Text('Upgrade this listing', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Enable to choose a paid package', style: TextStyle(color: Colors.white70)),
                      value: _upgradeEnabled,
                      onChanged: (v) => setState(() {
                        _upgradeEnabled = v;
                        if (!v) _paidPackage = null; // reset selection on OFF
                      }),
                      activeColor: Colors.black,
                      activeTrackColor: MarketplaceColors.accentYellow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  if (_upgradeEnabled) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _LabeledField(
                      label: 'Choose an upgrade package',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _RadioTile<String>(
                          value: 'vip',
                          groupValue: _paidPackage ?? '',
                          label: 'VIP listing',
                          selectedSubtitle: 'AED ${_upgradePriceForType('VIP listing')}',
                          onChanged: (v) => setState(() => _paidPackage = v),
                        ),
                        _RadioTile<String>(
                          value: 'featured',
                          groupValue: _paidPackage ?? '',
                          label: 'Featured listing',
                          selectedSubtitle: 'AED ${_upgradePriceForType('Featured listing')}',
                          onChanged: (v) => setState(() => _paidPackage = v),
                        ),
                        _RadioTile<String>(
                          value: 'urgent',
                          groupValue: _paidPackage ?? '',
                          label: 'Urgent listing',
                          selectedSubtitle: 'AED ${_upgradePriceForType('Urgent listing')}',
                          onChanged: (v) => setState(() => _paidPackage = v),
                        ),
                        _RadioTile<String>(
                          value: 'topBoost',
                          groupValue: _paidPackage ?? '',
                          label: 'Top Boost',
                          selectedSubtitle: 'AED 75',
                          onChanged: (v) => setState(() => _paidPackage = v),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // Brand / Make (text)
                  _LabeledField(
                    label: 'Brand / Make',
                    child: TextFormField(
                      controller: _brandCtrl,
                      readOnly: true,
                      onTap: () async {
                        final brands = getAllBrands(includeOther: false);
                        final sel = await _showSearchablePicker(title: 'Select Brand', options: brands);
                        if (sel != null && mounted) {
                          setState(() {
                            _brandCtrl.text = sel;
                            _modelCtrl.clear();
                          });
                        }
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(hint: 'Select brand').copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Model (text)
                  _LabeledField(
                    label: 'Model',
                    child: TextFormField(
                      controller: _modelCtrl,
                      readOnly: true,
                      onTap: () async {
                        final brand = _brandCtrl.text.trim();
                        if (brand.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a brand first')));
                          return;
                        }
                        final models = getModelsForBrand(brand).where((m) => m != kOtherOption).toList();
                        final sel = await _showSearchablePicker(title: 'Select Model', options: models);
                        if (sel != null && mounted) {
                          setState(() => _modelCtrl.text = sel);
                        }
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(hint: 'Select model').copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Year',
                      child: _input(_yearCtrl,
                          hint: 'e.g. 2022',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: _validateYear)),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Mileage (KM)',
                      child: _input(_mileageCtrl,
                          hint: 'e.g. 15000',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: _validateInt)),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Price (AED)',
                      child: _input(_priceCtrl,
                          hint: 'e.g. 850000',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: _validatePrice)),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Location',
                      child: _input(_locationCtrl,
                          hint: 'e.g. Dubai',
                          textInputAction: TextInputAction.next)),
                  const SizedBox(height: AppSpacing.md),
                  // removed separate urgent switch to avoid mixed states
                  _LabeledField(
                      label: 'Seller WhatsApp number',
                      child: _input(_phoneCtrl,
                          hint: 'e.g. 971501234567',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: _validatePhone)),
                  const SizedBox(height: AppSpacing.md),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                    label: 'Description',
                    child: TextFormField(
                      controller: _descriptionCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(hint: 'Describe the car'),
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl + 8),
                ]),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('Publish Listing'),
              onPressed: _submitting ? null : _onPublish,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                  : const Icon(Icons.publish, color: Colors.black),
              label: Text(_submitting ? 'Publishing...' : 'Publish Listing', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceColors.accentYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ).copyWith(splashFactory: NoSplash.splashFactory),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: MarketplaceColors.luxCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: MarketplaceColors.accentYellow, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    );
  }

  Widget _input(TextEditingController controller,
      {String? hint,
      TextInputType? keyboardType,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint: hint ?? ''),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Future<String?> _showSearchablePicker({required String title, required List<String> options}) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      builder: (ctx) {
        String query = '';
        List<String> filtered = List<String>.from(options);
        return StatefulBuilder(builder: (context, setSt) {
          void applyFilter(String q) {
            setSt(() {
              query = q;
              filtered = options.where((e) => e.toLowerCase().contains(q.toLowerCase())).toList();
            });
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white70))
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: applyFilter,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: MarketplaceColors.luxCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (context, index) {
                      final value = filtered[index];
                      return ListTile(
                        title: Text(value, style: const TextStyle(color: Colors.white)),
                        onTap: () => Navigator.of(context).pop(value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          );
        });
      },
    );
  }

  String? _validateYear(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final y = int.tryParse(v.trim());
    if (y == null || y < 1970 || y > DateTime.now().year + 1)
      return 'Enter a valid year';
    return null;
  }

  String? _validateInt(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a valid price';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Enter a valid phone (e.g. 9715...)';
    return null;
  }

  Future<void> _onPublish() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);

    // Field-level validation with explicit SnackBars
    final missing = <String>[];
    // if (_titleCtrl.text.trim().isEmpty) missing.add('title');
    if (_brandCtrl.text.trim().isEmpty) missing.add('brand');
    if (_modelCtrl.text.trim().isEmpty) missing.add('model');
    if (_yearCtrl.text.trim().isEmpty) missing.add('year');
    if (_mileageCtrl.text.trim().isEmpty) missing.add('mileage');
    if (_priceCtrl.text.trim().isEmpty) missing.add('price');
    if (_phoneCtrl.text.trim().isEmpty) missing.add('phone');
    // Require at least one image
    if (selectedImages.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please add at least one image')));
      return;
    }

    final formOk = _formKey.currentState?.validate() ?? false;
    if (missing.isNotEmpty || !formOk) {
      final first = missing.isNotEmpty ? missing.first : 'form';
      messenger.showSnackBar(SnackBar(content: Text('Missing: $first')));
      return;
    }

    // Resolve values early for summary/payment check (no network yet)
    final selectedBrand = _brandCtrl.text.trim();
    final selectedModel = _modelCtrl.text.trim();
    final year = int.parse(_yearCtrl.text.trim());
    final mileage = int.parse(_mileageCtrl.text.trim());
    final price = int.parse(_priceCtrl.text.trim());
    final location = _locationCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final user = context.read<AuthProvider>().currentUser;
    final ownerId = user?.uid ?? '';
    final ownerName = (user?.displayName?.trim().isNotEmpty == true) ? user!.displayName!.trim() : 'Seller';

    // Note: We will handle payment after creating the draft listing below.

    setState(() => _submitting = true);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Publishing started')));

      // Create a new doc ID first so we can reference it in storage paths
      final col = FirebaseFirestore.instance.collection('listings');
      final docRef = col.doc();

      // Upload selected images (if any) to Firebase Storage and collect URLs
      List<String> uploadedUrls = <String>[];
      if (selectedImages.isNotEmpty) {
        try {
          final bytesList = selectedImages.map((e) => e.bytes).toList();
          uploadedUrls = await ImageStorageService.uploadListingImages(listingId: docRef.id, images: bytesList);
          uploadedUrls = uploadedUrls.where(ImageStorageService.isValidDownloadUrl).toList();
          if (uploadedUrls.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload images')));
            }
            // Abort publishing if images were selected but none uploaded
            return;
          }
        } catch (e) {
          debugPrint('Listing images upload error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
          }
          return;
        }
      }

      // Determine initial status based on whether a paid upgrade was selected
      final bool isPaidFlow = _upgradeEnabled && (_paidPackage != null && _paidPackage!.isNotEmpty);
      String finalListingType = isPaidFlow ? '${(_paidPackage!)} listing' : 'Free listing';
      bool isVip = false, isFeatured = false, isUrgent = false; // never set at publish time

      final payload = <String, dynamic>{
        // 'title': _titleCtrl.text.trim(),
        'brand': selectedBrand,
        'make': selectedBrand, // back-compat
        'model': selectedModel,
        'year': year,
        'mileage': mileage,
        'price': price,
        'location': location,
        // 'condition': (_selectedCondition ?? '').trim(),
        'ownerPhone': phone,
        'sellerPhone': phone, // add sellerPhone for compatibility with feed/reels
        'ownerId': ownerId,
        'ownerName': ownerName,
        'description': description,
        'category': 'Cars',
        'status': isPaidFlow ? 'pending_payment' : 'active',
        'paymentStatus': isPaidFlow ? 'unpaid' : null,
        'selectedPlan': isPaidFlow ? _paidPackage : null,
        'images': uploadedUrls, // Save only validated HTTPS URLs
        'videoUrls': <String>[],
        'listingType': finalListingType,
        'isVip': isVip,
        'isFeatured': isFeatured,
        'isUrgent': isUrgent,
        'createdAt': FieldValue.serverTimestamp(),
        'mediaCount': uploadedUrls.length,
      };

      await docRef.set(payload);
      // Log the published document ID as requested
      debugPrint('Published listing id: ${docRef.id}');
      try {
        debugPrint('Saved listing: ${jsonEncode(payload)}');
      } catch (e) {
        debugPrint('Saved listing: (json encode failed) $payload');
      }

      // Force-refresh Featured Listings so the new images[0] appears immediately
      try {
        if (mounted) await context.read<ListingsProvider>().refresh();
      } catch (e) {
        debugPrint('Post-save refresh error: $e');
      }

      if (!mounted) return;
      if (isPaidFlow) {
        // Redirect to payment page; listing remains hidden until webhook marks as paid
        final ok = await context.pushNamed('payment', queryParameters: {
          'id': docRef.id,
          'type': 'new',
          'pkg': _paidPackage!,
        });
        if (ok == true) {
          messenger.showSnackBar(const SnackBar(content: Text('Payment completed. Listing is now active.')));
        } else {
          messenger.showSnackBar(const SnackBar(content: Text('Listing is pending payment. You can complete payment later from My Listings.')));
        }
        context.go(AppRoutes.home);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Listing published')));
        context.go(AppRoutes.home);
      }
    } catch (e) {
      debugPrint('Publish flow unexpected error: $e');
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
            style: context.textStyles.titleSmall
                ?.copyWith(color: cs.onSurfaceVariant)),
      ),
      child,
    ]);
  }
}

class _RadioTile<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final String label;
  final String? selectedSubtitle;
  final ValueChanged<T?> onChanged;
  const _RadioTile({required this.value, required this.groupValue, required this.label, this.selectedSubtitle, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MarketplaceColors.luxCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: RadioListTile<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: value == groupValue && selectedSubtitle != null ? Text(selectedSubtitle!, style: const TextStyle(color: Colors.white70)) : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _LocalImage {
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? previewUrl; // web-only convenience
  _LocalImage({required this.name, required this.mimeType, required this.bytes, required this.previewUrl});
}

class _ThumbnailTile extends StatelessWidget {
  final _LocalImage img;
  const _ThumbnailTile({required this.img});
  bool get _renderable => img.mimeType.contains('jpeg') || img.mimeType.contains('jpg') || img.mimeType.contains('png') || img.mimeType.contains('webp') || img.mimeType.contains('gif');
  String get _extLabel {
    final n = img.name.toLowerCase();
    final i = n.lastIndexOf('.');
    return i != -1 ? n.substring(i + 1) : (img.mimeType.split('/').last);
  }
  @override
  Widget build(BuildContext context) {
    if (_renderable) {
      return Image.memory(img.bytes, width: 96, height: 96, fit: BoxFit.cover);
    }
    // Non-renderable: show a neutral placeholder with the file extension
    return Container(
      width: 96,
      height: 96,
      color: Colors.black.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insert_photo, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(_extLabel.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// Removed _LocalVideo — not needed on images-only page

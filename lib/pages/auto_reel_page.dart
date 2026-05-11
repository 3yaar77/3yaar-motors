import 'dart:typed_data';
import 'package:autoreel/services/image_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autoreel/theme.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AutoReelPage extends StatefulWidget {
  const AutoReelPage({super.key});

  @override
  State<AutoReelPage> createState() => _AutoReelPageState();
}

class _AutoReelPageState extends State<AutoReelPage> {
  final ImagePicker picker = ImagePicker();

  // Keep XFiles and decoded bytes for cross-platform rendering
  List<XFile> images = [];
  List<Uint8List> imageBytes = [];

  final makeController = TextEditingController();
  final modelController = TextEditingController();
  final yearController = TextEditingController();
  final mileageController = TextEditingController();
  final priceController = TextEditingController();
  final locationController = TextEditingController();
  final phoneController = TextEditingController();
  final descriptionController = TextEditingController();

  String carCondition = 'Used';
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> pickImages() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final List<XFile> selected = await picker.pickMultiImage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (selected.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      // Enforce max 10, but keep first 10 instead of discarding all
      List<XFile> capped = selected.length > 10 ? selected.take(10).toList() : selected;
      if (selected.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 images allowed.')),
        );
      }

      // Decode bytes for cross-platform Image.memory rendering
      final List<Uint8List> decoded = [];
      for (final xf in capped) {
        try {
          final bytes = await xf.readAsBytes();
          decoded.add(bytes);
        } catch (e) {
          debugPrint('Failed to read image bytes: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        images = capped;
        imageBytes = decoded;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('pickImages error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick images. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  bool hasBannedWords() {
    // Simple banned words filter (Arabic + variants)
    final List<String> bannedWords = [
      'شقة', 'بيت', 'غرفة', 'ايفون', 'آيفون', 'لابتوب', 'عطر', 'ساعة', 'سماعات', 'وظيفة', 'ارض', 'أرض', 'فيلا',
    ];

    final String text = (
      '${makeController.text}\n'
      '${modelController.text}\n'
      '${yearController.text}\n'
      '${mileageController.text}\n'
      '${priceController.text}\n'
      '${locationController.text}\n'
      '${phoneController.text}\n'
      '${descriptionController.text}'
    ).toLowerCase();

    for (final word in bannedWords) {
      if (text.contains(word.toLowerCase())) return true;
    }
    return false;
  }

  Future<void> publishPhotoReel() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 1 image')));
      return;
    }
    if (makeController.text.trim().isEmpty || modelController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required car details')));
      return;
    }
    if (images.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 10 images allowed.')));
      return;
    }
    if (hasBannedWords()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يسمح فقط بإعلانات السيارات')));
      return;
    }

    try {
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      final displayName = context.read<AuthProvider>().currentUser?.displayName ?? 'Seller';
      final price = int.tryParse(priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final year = int.tryParse(yearController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? DateTime.now().year;
      final mileage = int.tryParse(mileageController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final location = (locationController.text.trim().isEmpty) ? 'Dubai' : locationController.text.trim();
      final phone = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

      // Create Firestore doc ref first
      final col = FirebaseFirestore.instance.collection('listings');
      final docRef = col.doc();

      // Upload images to storage and collect download URLs using unified service
      final List<String> uploadedUrls = await ImageStorageService.uploadListingImages(listingId: docRef.id, images: imageBytes);
      if (uploadedUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. No images uploaded.')));
        return;
      }

      final data = <String, dynamic>{
        'brand': makeController.text.trim(),
        'make': makeController.text.trim(),
        'model': modelController.text.trim(),
        'year': year,
        'mileage': mileage,
        'price': price,
        'location': location,
        'ownerPhone': phone,
        'sellerPhone': phone,
        'ownerId': uid,
        'ownerName': displayName,
        'description': descriptionController.text.trim(),
        'category': 'Cars',
        'status': 'active',
        'coverImageUrl': uploadedUrls.first,
        'imageUrls': uploadedUrls,
        'images': uploadedUrls,
        'image': uploadedUrls.first,
        'imageUrl': uploadedUrls.first,
        'videoUrls': <String>[],
        'listingType': carCondition.isNotEmpty ? carCondition : 'Free listing',
        'isVip': false,
        'isFeatured': false,
        'isUrgent': false,
        'createdAt': FieldValue.serverTimestamp(),
        'mediaCount': uploadedUrls.length,
      };

      await docRef.set(data);
      try {
        debugPrint('Saved listing: ' + jsonEncode(data));
      } catch (_) {
        debugPrint('Saved listing: $data');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Car listing published successfully')));
      context.go('/home');
    } catch (e) {
      debugPrint('Publish car error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish listing. Please try again.')));
      }
    }
  }

  Widget inputField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: MarketplaceColors.luxCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget conditionButton(String title) {
    final bool selected = carCondition == title;

    return GestureDetector(
      onTap: () => setState(() => carCondition = title),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? MarketplaceColors.accentYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MarketplaceColors.accentYellow),
        ),
        child: Text(
          title,
          style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget imageReelPreview() {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageBytes.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              Image.memory(imageBytes[index], fit: BoxFit.cover),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                  child: Text('${index + 1}/${images.length}', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          );
        },
      ),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkModeColors.darkSurface,
      appBar: AppBar(
        backgroundColor: DarkModeColors.darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MarketplaceColors.accentYellow),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Add Car Listing',
          style: TextStyle(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImages,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: MarketplaceColors.luxCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MarketplaceColors.accentYellow),
                ),
                child: images.isEmpty
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, color: MarketplaceColors.accentYellow, size: 45),
                          SizedBox(height: 8),
                          Text('Upload Car Images', style: TextStyle(color: Colors.white)),
                          SizedBox(height: 4),
                          Text('Minimum 1 image - Maximum 10 images', style: TextStyle(color: Colors.white54)),
                        ],
                      )
                    : Center(
                        child: Text(
                          '${images.length} Images Selected',
                          style: const TextStyle(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (images.isNotEmpty) imageReelPreview(),
            inputField('Car Make / Brand *', makeController),
            inputField('Model *', modelController),
            inputField('Year', yearController, keyboardType: TextInputType.number),
            inputField('Mileage KM', mileageController, keyboardType: TextInputType.number),
            inputField('Price AED', priceController, keyboardType: TextInputType.number),
            inputField('Location', locationController),
            inputField('WhatsApp / Phone Number *', phoneController, keyboardType: TextInputType.phone),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                children: [
                  conditionButton('New'),
                  conditionButton('Used'),
                  conditionButton('Agency warranty'),
                  conditionButton('GCC specs'),
                ],
              ),
            ),
            inputField('Description', descriptionController, maxLines: 4),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: publishPhotoReel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketplaceColors.accentYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Publish Car Listing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

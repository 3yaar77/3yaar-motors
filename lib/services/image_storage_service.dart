import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:autoreel/utils/image_upload_helper.dart';

/// Centralized image storage service.
///
/// Responsibilities:
/// - Process images (convert/resize/compress) using ImageUploadHelper
/// - Upload to Firebase Storage under deterministic directories
/// - Return HTTPS download URLs only (never gs:// or fullPath)
/// - Provide high-level APIs for common app flows
class ImageStorageService {
  const ImageStorageService._();

  static const String kFirebaseHttpsPrefix = 'https://firebasestorage.googleapis.com/';
  static bool isValidDownloadUrl(String url) => url.trim().toLowerCase().startsWith(kFirebaseHttpsPrefix);

  /// Upload a single avatar image for a user and return the HTTPS URL.
  static Future<String> uploadUserAvatar({required String uid, required Uint8List bytes}) async {
    if (uid.isEmpty) throw Exception('Missing uid');
    if (bytes.isEmpty) throw Exception('Empty avatar bytes');
    final url = await ImageUploadHelper.uploadJpeg(
      inputBytes: bytes,
      storageDir: 'users',
      fileBaseName: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      targetMaxWidth: 1200,
      jpegQuality: 80,
      customMetadata: <String, String>{
        'firestoreDocPath': 'users/$uid',
        'firestoreField': 'photoUrl',
        'op': 'set',
        'entity': 'user',
        'uid': uid,
      },
    );
    if (url.isEmpty || !isValidDownloadUrl(url)) {
      throw Exception('Invalid avatar URL');
    }
    return url;
  }

  /// Upload multiple listing images and return the list of HTTPS URLs in order.
  /// - All images are processed consistently (JPG @ quality 80 or web PNG/JPG pass-through)
  static Future<List<String>> uploadListingImages({required String listingId, required List<Uint8List> images}) async {
    if (listingId.isEmpty) throw Exception('Missing listingId');
    if (images.isEmpty) return const <String>[];
    final List<String> urls = <String>[];
    int i = 0;
    for (final bytes in List<Uint8List>.from(images)) {
      i += 1;
      if (bytes.isEmpty) continue;
      try {
        final url = await ImageUploadHelper.uploadJpeg(
          inputBytes: bytes,
          storageDir: 'listings/images',
          fileBaseName: '${DateTime.now().millisecondsSinceEpoch}_$i',
          targetMaxWidth: 1200,
          jpegQuality: 80,
          customMetadata: <String, String>{
            'firestoreDocPath': 'listings/$listingId',
            'firestoreField': 'images',
            'op': 'arrayUnion',
            'entity': 'listing',
            'listingId': listingId,
          },
        );
        if (url.isNotEmpty && isValidDownloadUrl(url)) {
          if (!urls.contains(url)) urls.add(url);
        }
      } catch (e) {
        debugPrint('uploadListingImages[$i] error: $e');
        // Continue others; we want best-effort list
      }
    }
    return urls;
  }

  /// Best-effort deletion of a storage file by HTTPS URL.
  /// Safe to call even if the file was already deleted.
  static Future<void> deleteByUrl(String httpsUrl) async {
    try {
      final u = (httpsUrl).trim();
      if (u.isEmpty) return;
      if (!isValidDownloadUrl(u)) return; // only our HTTPS URLs are handled
      final ref = FirebaseStorage.instance.refFromURL(u);
      await ref.delete();
    } catch (e) {
      debugPrint('ImageStorageService.deleteByUrl error: $e');
    }
  }

  /// Upload multiple accessory images and return the list of HTTPS URLs in order.
  static Future<List<String>> uploadAccessoryImages({required String accessoryId, required List<Uint8List> images}) async {
    if (accessoryId.isEmpty) throw Exception('Missing accessoryId');
    if (images.isEmpty) return const <String>[];
    final List<String> urls = <String>[];
    int i = 0;
    for (final bytes in List<Uint8List>.from(images)) {
      i += 1;
      if (bytes.isEmpty) continue;
      try {
        final url = await ImageUploadHelper.uploadJpeg(
          inputBytes: bytes,
          storageDir: 'accessories',
          fileBaseName: '${DateTime.now().millisecondsSinceEpoch}_$i',
          targetMaxWidth: 1200,
          jpegQuality: 80,
          customMetadata: <String, String>{
            'firestoreDocPath': 'accessories/$accessoryId',
            'firestoreField': 'images',
            'op': 'arrayUnion',
            'entity': 'accessory',
            'accessoryId': accessoryId,
          },
        );
        if (url.isNotEmpty && isValidDownloadUrl(url)) {
          if (!urls.contains(url)) urls.add(url);
        }
      } catch (e) {
        debugPrint('uploadAccessoryImages[$i] error: $e');
      }
    }
    return urls;
  }

  /// Try to convert legacy/broken URLs to valid Firebase HTTPS download URLs.
  /// Rules:
  /// - Keep entries that already start with https://firebasestorage.googleapis.com/
  /// - For entries starting with gs://, resolve via refFromURL(url).getDownloadURL()
  /// - Drop all other schemes (blob:, data:, file:, http(s) to other hosts)
  static Future<List<String>> repairImageUrls(List<String> urls) async {
    final List<String> out = [];
    for (final raw in urls) {
      final u = (raw).trim();
      if (u.isEmpty) continue;
      final lower = u.toLowerCase();
      try {
        if (isValidDownloadUrl(u)) {
          if (!out.contains(u)) out.add(u);
        } else if (lower.startsWith('gs://')) {
          final ref = FirebaseStorage.instance.refFromURL(u);
          final https = await ref.getDownloadURL();
          if (https.isNotEmpty && isValidDownloadUrl(https)) {
            if (!out.contains(https)) out.add(https);
          }
        } else {
          // skip other
        }
      } catch (e) {
        debugPrint('repairImageUrls: failed to repair "$u": $e');
      }
    }
    return out;
  }
}

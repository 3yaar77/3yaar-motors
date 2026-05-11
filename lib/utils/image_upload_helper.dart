import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// A unified helper to process and upload images to Firebase Storage.
///
/// - Accepts JPG/PNG/HEIC input bytes (HEIC supported on iOS/Android; web HEIC typically not supported).
/// - Converts everything to JPEG on mobile/desktop. On web, uploads original PNG/JPEG bytes to avoid plugin issues.
/// - Resizes to [targetMaxWidth] while keeping aspect ratio (mobile/desktop), JPEG quality [jpegQuality].
/// - Uploads to Firebase Storage under [storageDir]/[fileName].
/// - Returns the full HTTPS download URL. No local paths, no blobs.
class ImageUploadHelper {
  static const String requiredPrefix = 'https://firebasestorage.googleapis.com/';

  /// Simple MIME sniffers from magic bytes
  static bool _isPng(Uint8List bytes) => bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
  static bool _isJpeg(Uint8List bytes) => bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[bytes.length - 2] == 0xFF && bytes[bytes.length - 1] == 0xD9;
  static bool _isWebp(Uint8List b) => b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && // RIFF
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50; // WEBP
  static bool _isGif(Uint8List b) => b.length > 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38 && (b[4] == 0x37 || b[4] == 0x39) && b[5] == 0x61; // GIF87a/89a

  /// Process image bytes to a web-friendly format and upload to Firebase Storage.
  ///
  /// storageDir example:
  ///  - users/<uid>
  ///  - listings/images/<listingId>
  static Future<String> uploadJpeg({
    required Uint8List inputBytes,
    required String storageDir,
    String? fileBaseName,
    int targetMaxWidth = 1200,
    int jpegQuality = 80,
    Map<String, String>? customMetadata,
  }) async {
    if (inputBytes.isEmpty) {
      throw Exception('Empty image data');
    }

    // Note: We no longer block HEIC on web. We'll upload original bytes with correct content-type
    // and let a Cloud Function transcode to JPEG, then write back the HTTPS URL to Firestore.

    // 1) Process to web-safe bytes and determine content-type + extension
    Uint8List toUpload;
    String contentType;
    String extension;
    if (kIsWeb) {
      // On web, skip flutter_image_compress (not reliable). Upload original PNG/JPEG bytes.
      if (_isJpeg(inputBytes)) {
        toUpload = inputBytes;
        contentType = 'image/jpeg';
        extension = '.jpg';
      } else if (_isPng(inputBytes)) {
        toUpload = inputBytes;
        contentType = 'image/png';
        extension = '.png';
      } else if (_isWebp(inputBytes)) {
        toUpload = inputBytes;
        contentType = 'image/webp';
        extension = '.webp';
      } else if (_isGif(inputBytes)) {
        toUpload = inputBytes;
        contentType = 'image/gif';
        extension = '.gif';
      } else if (isLikelyHeic(inputBytes)) {
        // Allow HEIC uploads on web; conversion handled by Cloud Functions
        toUpload = inputBytes;
        contentType = 'image/heic';
        extension = '.heic';
      } else {
        // Unknown format — upload as octet-stream with .bin extension. A backend job may handle it.
        toUpload = inputBytes;
        contentType = 'application/octet-stream';
        extension = '.bin';
      }
    } else {
      // Mobile/desktop: convert to JPEG to reduce size and ensure compatibility
      final processed = await _toJpeg(inputBytes, targetMaxWidth: targetMaxWidth, jpegQuality: jpegQuality);
      toUpload = processed;
      contentType = 'image/jpeg';
      extension = '.jpg';
    }

    // 2) Build a safe file name
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(99999).toString().padLeft(5, '0');
    final safeBase = ((fileBaseName?.trim().isNotEmpty ?? false) ? fileBaseName!.trim() : 'img_${ts}_$rnd');
    final fileName = safeBase + extension;

    // 3) Upload to Firebase Storage
    final ref = FirebaseStorage.instance.ref().child(storageDir).child(fileName);
    final meta = SettableMetadata(contentType: contentType, customMetadata: customMetadata);
    await ref.putData(toUpload, meta);

    // 4) Resolve download URL
    final url = await ref.getDownloadURL();
    debugPrint('IMAGE DOWNLOAD URL: $url');

    // 5) Validate we only ever return full HTTPS URL from Firebase CDN
    if (url.isEmpty || !url.startsWith(requiredPrefix)) {
      throw Exception('Invalid download URL (must start with https://firebasestorage.googleapis.com/)');
    }
    return url;
  }

  // Quick HEIC detector by magic bytes. Looks for 'ftyp' then 'heic'/'heif' variants at header.
  static bool isLikelyHeic(Uint8List bytes) {
    try {
      if (bytes.length < 12) return false;
      // ISO Base Media File Format starts with something then 'ftyp' at offset 4
      final tag = String.fromCharCodes(bytes.sublist(4, 8));
      if (tag != 'ftyp') return false;
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      return brand.startsWith('heic') || brand.startsWith('heif') || brand.startsWith('hevc') || brand.startsWith('heim') || brand.startsWith('heis');
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> _toJpeg(Uint8List input, {required int targetMaxWidth, required int jpegQuality}) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        input,
        minWidth: targetMaxWidth,
        quality: jpegQuality.clamp(1, 100),
        format: CompressFormat.jpeg,
      );
      if (out.isEmpty) throw Exception('JPEG encoder returned empty output');
      return Uint8List.fromList(out);
    } catch (e) {
      debugPrint('ImageUploadHelper: JPEG conversion failed: $e');
      // Fail fast to avoid uploading non-JPEG bytes with JPEG content-type, which breaks rendering in browsers.
      rethrow;
    }
  }
}

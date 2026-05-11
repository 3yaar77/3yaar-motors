import 'package:flutter/foundation.dart';

class ImageUrlUtils {
  static const String firebaseHttpsPrefix = 'https://firebasestorage.googleapis.com/';

  static String sanitize(String url) {
    var u = (url).trim();
    if (u.isEmpty) return u;
    // Accept only http(s). If http, force https
    if (u.startsWith('http://')) u = 'https://${u.substring(7)}';
    final lower = u.toLowerCase();
    if (!(lower.startsWith('http://') || lower.startsWith('https://'))) {
      // Drop unsupported schemes like gs://, blob:, data:, file:, etc.
      return '';
    }

    // Note: We do not rewrite Firebase Storage hosts here. Use isValidFirebaseDownload
    // to strictly validate listing image URLs before rendering.
    return u;
  }

  static List<String> sanitizeAll(Iterable<dynamic> urls) => urls
      .map((e) => e?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .map(sanitize)
      .where((e) => e.isNotEmpty)
      .toList();

  static bool isValidFirebaseDownload(String url) => url.trim().toLowerCase().startsWith(firebaseHttpsPrefix);
}

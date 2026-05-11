import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cleans and normalizes a phone number for UAE usage.
/// - Removes spaces, '+', '-', brackets and any non-digits
/// - If starts with '00', drop the prefix (e.g., 00971 -> 971)
/// - If starts with '0', convert to UAE international format: 0XXXXXXXXX -> 971XXXXXXXXX
/// - Leaves numbers starting with '971' as-is
String cleanUaePhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '971${digits.substring(1)}';
  return digits;
}

/// Opens a WhatsApp chat using wa.me link format, externally (not in-app).
/// Returns true if the URL could be launched, false otherwise.
Future<bool> openWhatsAppWaMe(String phone, {String? message}) async {
  try {
    // Sanitize per requirements
    final digits = cleanUaePhone(phone);
    if (digits.isEmpty) return false;

    // Base: https://wa.me/PHONE_NUMBER
    // Append encoded text when provided (or use a sensible default).
    final text = (message == null || message.trim().isEmpty)
        ? 'Hi, I am interested in your listing'
        : message.trim();

    final base = Uri.parse('https://wa.me/$digits');
    final url = base.replace(queryParameters: {'text': text});

    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) debugPrint('Failed to launch WhatsApp URL: $url');
    return ok;
  } catch (e) {
    debugPrint('Error launching WhatsApp: $e');
    return false;
  }
}

/// Starts a phone call with the given number using the tel: scheme.
/// Returns true if the dialer could be opened.
Future<bool> openPhoneCall(String phone) async {
  try {
    final digits = cleanUaePhone(phone);
    if (digits.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: '+$digits');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) debugPrint('Failed to launch phone dialer: $uri');
    return ok;
  } catch (e) {
    debugPrint('Error launching phone dialer: $e');
    return false;
  }
}

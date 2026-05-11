import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents a purchasable promotion package
class PromotionPackage {
  final String type; // 'featured' | 'pin' | 'vip'
  final int amountAed; // price in AED
  final int durationDays; // fixed duration per package
  const PromotionPackage({required this.type, required this.amountAed, required this.durationDays});

  static const featured = PromotionPackage(type: 'featured', amountAed: 15, durationDays: 3);
  static const pin = PromotionPackage(type: 'pin', amountAed: 5, durationDays: 1);
  static const vip = PromotionPackage(type: 'vip', amountAed: 50, durationDays: 7);
}

class PaymentResult {
  final bool success;
  final String? paymentId; // Stripe payment intent id or checkout session id
  final String? checkoutUrl; // For hosted checkout flows
  final String? error;
  const PaymentResult.success(this.paymentId, {this.checkoutUrl})
      : success = true,
        error = null;
  const PaymentResult.failure(this.error)
      : success = false,
        paymentId = null,
        checkoutUrl = null;
}

/// PaymentService orchestrates starting a Stripe Checkout session via backend
/// and returning a verified success result. In local-only mode, this is disabled
/// to prevent client-side fake promotions.
class PaymentService {
  // When backend is wired, expose as configured
  bool get isConfigured => true;

  Uri get _checkoutEndpoint => Uri.parse('https://us-central1-yaar-motors.cloudfunctions.net/create_checkout_session');

  Future<PaymentResult> startStripeCheckout({
    required String listingId,
    required String selectedPlan, // featured | vip | urgent | topBoost
    String? userId,
  }) async {
    if (!isConfigured) {
      return const PaymentResult.failure('Payments are not configured.');
    }
    try {
      final res = await http.post(
        _checkoutEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'listingId': listingId,
          'selectedPlan': selectedPlan,
          'userId': userId ?? '',
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('create_checkout_session failed: ${res.statusCode} ${res.body}');
        return PaymentResult.failure('Failed to start checkout');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final url = (data['checkoutUrl'] ?? '').toString();
      final sessionId = (data['sessionId'] ?? '').toString();
      if (url.isEmpty) return const PaymentResult.failure('Checkout URL not returned');
      return PaymentResult.success(sessionId.isNotEmpty ? sessionId : url, checkoutUrl: url);
    } catch (e) {
      debugPrint('startStripeCheckout error: $e');
      return PaymentResult.failure('Payment error: $e');
    }
  }

  /// Polls Firestore listing until paymentStatus == 'paid' or timeout (in seconds)
  Future<bool> waitUntilPaid({required String listingId, Duration timeout = const Duration(minutes: 3)}) async {
    final ref = FirebaseFirestore.instance.collection('listings').doc(listingId);
    final completer = Completer<bool>();
    late final StreamSubscription sub;
    final timer = Timer(timeout, () {
      try { sub.cancel(); } catch (_) {}
      if (!completer.isCompleted) completer.complete(false);
    });
    sub = ref.snapshots().listen((snap) {
      final data = snap.data();
      final status = (data?['paymentStatus'] ?? '').toString();
      if (status == 'paid') {
        try { sub.cancel(); } catch (_) {}
        timer.cancel();
        if (!completer.isCompleted) completer.complete(true);
      }
    }, onError: (e) {
      debugPrint('waitUntilPaid stream error: $e');
    });
    return completer.future;
  }
}

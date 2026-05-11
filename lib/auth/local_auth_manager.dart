import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autoreel/auth/auth_manager.dart';
import 'package:autoreel/auth/user_model.dart';

/// LocalAuthManager implements a minimal, device-only auth flow for MVP.
/// - Phone "login": instantly signs in with a provided phone number (no SMS)
/// - Email login: accepts any email/password and signs in locally
/// - Anonymous: supported for quick entry
/// Data persists in SharedPreferences until a real backend is connected.
class LocalAuthManager extends AuthManager
    with EmailSignInManager, PhoneSignInManager, AnonymousSignInManager {
  static const _kUserKey = 'current_user_v1';

  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUserKey);
      if (raw == null) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return User.fromJson(map);
      if (map is Map) return User.fromJson(map.cast<String, dynamic>());
      return null;
    } catch (e) {
      debugPrint('LocalAuthManager.getCurrentUser error: $e');
      return null;
    }
  }

  Future<void> _persist(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('LocalAuthManager._persist error: $e');
    }
  }

  // Public method to persist arbitrary user updates
  Future<void> saveUser(User user) => _persist(user);

  @override
  Future signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserKey);
    } catch (e) {
      debugPrint('LocalAuthManager.signOut error: $e');
    }
  }

  @override
  Future deleteUser(BuildContext context) async => signOut();

  @override
  Future updateEmail({required String email, required BuildContext context}) async {
    final u = await getCurrentUser();
    if (u == null) return;
    await _persist(u.copyWith(email: email, updatedAt: DateTime.now()));
  }

  @override
  Future resetPassword({required String email, required BuildContext context}) async {
    // Local-only: no-op
  }

  @override
  Future<User?> signInWithEmail(BuildContext context, String email, String password) async {
    final now = DateTime.now();
    final uid = 'email_${email.toLowerCase()}';
    final existing = await getCurrentUser();
    final user = (existing?.uid == uid)
        ? existing!.copyWith(email: email, updatedAt: now)
        : User(uid: uid, email: email, phoneNumber: null, displayName: null, city: null, photoUrl: null, isAdmin: false, createdAt: now, updatedAt: now);
    await _persist(user);
    return user;
  }

  @override
  Future<User?> createAccountWithEmail(BuildContext context, String email, String password) => signInWithEmail(context, email, password);

  @override
  Future beginPhoneAuth({required BuildContext context, required String phoneNumber, required void Function(BuildContext p1) onCodeSent}) async {
    // Local-only: instantly continue to verify step
    onCodeSent(context);
  }

  @override
  Future verifySmsCode({required BuildContext context, required String smsCode}) async {
    // Local-only: no-op
  }

  Future<User> signInWithPhoneInstant(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final now = DateTime.now();
    final user = User(uid: 'phone_$digits', phoneNumber: digits, email: null, displayName: null, city: null, photoUrl: null, isAdmin: false, createdAt: now, updatedAt: now);
    await _persist(user);
    return user;
  }

  @override
  Future<User?> signInAnonymously(BuildContext context) async {
    final now = DateTime.now();
    final user = User(uid: 'anon_${now.millisecondsSinceEpoch}', createdAt: now, updatedAt: now, email: null, phoneNumber: null, displayName: 'Guest', city: null, photoUrl: null, isAdmin: false);
    await _persist(user);
    return user;
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:autoreel/auth/user_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:autoreel/firebase_options.dart';

class AuthProvider extends ChangeNotifier {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _currentUser;
  bool _loading = true;
  String? _error;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  AuthProvider() {
    _init();
  }

  bool get isLoading => _loading;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin == true;
  String? get errorMessage => _error;

  Future<void> _init() async {
    try {
      // Listen to Firebase auth state and load profile accordingly
      _auth.authStateChanges().listen((fb.User? user) async {
        try {
          if (user == null) {
            // Tear down any previous user doc subscription
            await _userDocSub?.cancel();
            _userDocSub = null;
            _currentUser = null;
            _loading = false;
            notifyListeners();
            return;
          }
          // Immediately expose minimal auth info while Firestore subscription warms up
          _currentUser = User(
            uid: user.uid,
            email: user.email,
            phoneNumber: user.phoneNumber,
            displayName: user.displayName,
            city: null,
            photoUrl: user.photoURL,
            isAdmin: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _loading = false;
          _error = null;
          notifyListeners();

          // Listen to users/{uid} in real time so UI stays in sync after writes
          await _userDocSub?.cancel();
          _userDocSub = _db.collection('users').doc(user.uid).snapshots().listen((snap) {
            try {
              final data = snap.data();
              if (data == null) return;
              final createdAt = _parseDate(data['createdAt']) ?? _currentUser?.createdAt ?? DateTime.now();
              _currentUser = User(
                uid: user.uid,
                email: user.email,
                phoneNumber: (data['phone'] as String?) ?? user.phoneNumber,
                displayName: (data['username'] as String?) ?? user.displayName,
                city: data['city'] as String?,
                photoUrl: (data['photoUrl'] as String?) ?? _currentUser?.photoUrl,
                isAdmin: (data['isAdmin'] as bool?) ?? false,
                createdAt: createdAt,
                updatedAt: DateTime.now(),
              );
              notifyListeners();
            } catch (e) {
              debugPrint('AuthProvider user doc listen error: $e');
            }
          });
        } catch (e) {
          debugPrint('Auth state load error: $e');
          _loading = false;
          _error = 'Failed to load user profile';
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('AuthProvider init error: $e');
      _loading = false;
      notifyListeners();
    }
  }

  // Ensure Firebase is initialized (defensive guard for rare edge cases)
  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        debugPrint('Firebase initialize in AuthProvider failed: $e');
        rethrow;
      }
    }
  }

  // Helpers
  DateTime? _parseDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    } catch (e) {
      debugPrint('AuthProvider _parseDate error: $e');
      return null;
    }
  }

  Future<String> _resolveEmailFromIdentifier(String identifier) async {
    final id = identifier.trim();
    if (id.contains('@')) return id; // treat as email
    // Else lookup by username in Firestore
    final snap = await _db.collection('users').where('username', isEqualTo: id).limit(1).get();
    if (snap.docs.isEmpty) {
      throw fb.FirebaseAuthException(code: 'user-not-found', message: 'Account not found for username');
    }
    final data = snap.docs.first.data();
    final email = (data['email'] as String?)?.trim();
    if (email == null || email.isEmpty) {
      throw fb.FirebaseAuthException(code: 'invalid-email', message: 'No email linked to this username');
    }
    return email;
  }

  // Public API: Login with username OR email + password
  Future<void> loginWithIdentifierPassword({required String identifier, required String password}) async {
    try {
      await _ensureFirebase();
      _error = null;
      final id = identifier.trim();
      final pass = password.trim();
      if (id.isEmpty || pass.isEmpty) {
        throw Exception('Please enter username/email and password');
      }
      final email = await _resolveEmailFromIdentifier(id);
      await _auth.signInWithEmailAndPassword(email: email, password: pass);
      // authStateChanges listener will populate _currentUser
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('Firebase login error: ${e.code} ${e.message}');
      _error = e.message;
      rethrow;
    } catch (e) {
      debugPrint('Login error: $e');
      _error = 'Login failed';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // Backward-compat shim (used by old UI): treat provided username as identifier
  Future<void> loginWithUsernamePassword({required String username, required String password}) =>
      loginWithIdentifierPassword(identifier: username, password: password);

  // Public API: Sign up with username + email + password
  Future<void> signUpWithUsernameEmailPassword({required String username, required String email, required String password}) async {
    try {
      await _ensureFirebase();
      _error = null;
      final uname = username.trim();
      final mail = email.trim();
      final pass = password.trim();
      if (uname.isEmpty || mail.isEmpty || pass.isEmpty) {
        throw Exception('All fields are required');
      }
      if (pass.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      // Ensure unique username
      final q = await _db.collection('users').where('username', isEqualTo: uname).limit(1).get();
      if (q.docs.isNotEmpty) {
        throw Exception('Username already taken');
      }
      // Create auth user
      final cred = await _auth.createUserWithEmailAndPassword(email: mail, password: pass);
      final uid = cred.user!.uid;
      // Save profile
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'username': uname,
        'email': mail,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Send email verification (welcome email)
      try {
        await _auth.currentUser?.sendEmailVerification();
      } catch (e) {
        debugPrint('sendEmailVerification error: $e');
      }
      // authStateChanges listener will populate _currentUser
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('Firebase signup error: ${e.code} ${e.message}');
      _error = e.message;
      rethrow;
    } catch (e) {
      debugPrint('Signup error: $e');
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // Backward-compat shim to keep older callers compiling; will throw if email missing
  Future<void> signUpWithUsernamePassword({required String username, required String password, String? phone}) async {
    throw Exception('This app now requires email at signup. Please update UI to provide email.');
  }

  Future<void> updateProfile({String? displayName, String? city, String? phone}) async {
    if (_currentUser == null) return;
    try {
      final uid = _currentUser!.uid;
      final data = <String, dynamic>{};
      if (displayName != null) data['username'] = displayName;
      if (phone != null) data['phone'] = phone;
      if (data.isNotEmpty) {
        data['updatedAt'] = FieldValue.serverTimestamp();
        await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      }
      _currentUser = _currentUser!.copyWith(displayName: displayName ?? _currentUser!.displayName, phoneNumber: phone ?? _currentUser!.phoneNumber, updatedAt: DateTime.now());
    } catch (e) {
      debugPrint('updateProfile error: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> updatePhotoUrl(String url) async {
    if (_currentUser == null) return;
    try {
      // Update Firestore document
      await _db.collection('users').doc(_currentUser!.uid).set({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      // Update Firebase Auth profile photoURL as well
      try {
        final fbUser = _auth.currentUser;
        if (fbUser != null) {
          await fbUser.updatePhotoURL(url);
          await fbUser.reload();
        }
      } catch (e) {
        debugPrint('FirebaseAuth updatePhotoURL error: $e');
      }
      // Update in-memory model
      _currentUser = _currentUser!.copyWith(photoUrl: url, updatedAt: DateTime.now());
    } catch (e) {
      debugPrint('updatePhotoUrl error: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> toggleAdmin(bool value) async {
    if (_currentUser == null) return;
    try {
      await _db.collection('users').doc(_currentUser!.uid).set({'isAdmin': value, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      _currentUser = _currentUser!.copyWith(isAdmin: value, updatedAt: DateTime.now());
    } catch (e) {
      debugPrint('toggleAdmin error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase signOut error: $e');
    } finally {
      try {
        await _userDocSub?.cancel();
      } catch (_) {}
      _userDocSub = null;
      _currentUser = null;
      notifyListeners();
    }
  }
}

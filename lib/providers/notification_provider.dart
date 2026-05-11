import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // like | comment
  final String listingId;
  final String message;
  final DateTime createdAt;
  final bool read;
  const AppNotification({required this.id, required this.type, required this.listingId, required this.message, required this.createdAt, required this.read});
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _items = [];
  String? _userId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => n.read == false).length;

  /// Bind Firestore listener to the given user.
  /// Pass null to detach.
  Future<void> attachUser(String? uid) async {
    if (_userId == uid) return;
    _userId = uid;
    await _sub?.cancel();
    _items.clear();
    notifyListeners();
    if (uid == null || uid.isEmpty) return;
    try {
      final col = FirebaseFirestore.instance.collection('notifications').withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );
      _sub = col
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .listen((snap) {
        final next = snap.docs.map((d) {
          final data = d.data();
          final ts = data['createdAt'];
          DateTime dt;
          if (ts is Timestamp) {
            dt = ts.toDate();
          } else if (ts is DateTime) {
            dt = ts;
          } else {
            dt = DateTime.now();
          }
        
          return AppNotification(
            id: d.id,
            type: (data['type'] ?? 'like').toString(),
            listingId: (data['listingId'] ?? '').toString(),
            message: (data['message'] ?? '').toString(),
            createdAt: dt,
            read: (data['read'] as bool?) ?? false,
          );
        }).toList();
        _items..clear()..addAll(next);
        notifyListeners();
      }, onError: (e) {
        debugPrint('Notification stream error: $e');
      });
    } catch (e) {
      debugPrint('Failed to attach notifications: $e');
    }
  }

  /// Create a notification document for the target user
  Future<void> create({required String userId, required String type, required String listingId, required String message}) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'type': type,
        'listingId': listingId,
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Create notification error: $e');
    }
  }

  Future<void> createLike({required String userId, required String listingId, required String message}) => create(userId: userId, type: 'like', listingId: listingId, message: message);
  Future<void> createComment({required String userId, required String listingId, required String message}) => create(userId: userId, type: 'comment', listingId: listingId, message: message);

  /// Mark all as read for current user (best-effort; loops over loaded items)
  Future<void> markAllRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final n in _items.where((e) => e.read == false)) {
        final ref = FirebaseFirestore.instance.collection('notifications').doc(n.id);
        batch.update(ref, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Mark all read error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

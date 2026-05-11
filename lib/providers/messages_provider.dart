import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight messages provider to expose an inbox unread badge.
/// No chat UI or threads are implemented here – we just count incoming
/// unread messages for the current user (toUserId == uid and read == false).
class MessagesProvider extends ChangeNotifier {
  String? _userId;
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  int get unreadCount => _unreadCount;

  Future<void> attachUser(String? uid) async {
    if (_userId == uid) return;
    _userId = uid;
    await _sub?.cancel();
    _sub = null;
    _unreadCount = 0;
    notifyListeners();
    if (uid == null || uid.isEmpty) return;
    try {
      final col = FirebaseFirestore.instance.collection('messages').withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );
      _sub = col
          .where('toUserId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .limit(200)
          .snapshots()
          .listen((snap) {
        _unreadCount = snap.size;
        notifyListeners();
      }, onError: (e) {
        debugPrint('Messages unread stream error: $e');
      });
    } catch (e) {
      debugPrint('Failed to attach messages provider: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id; // conv-<listingId>-<sellerId>-<buyerId>
  final String listingId;
  final String listingTitle;
  final String sellerId; // may be phone as fallback
  final String sellerName;
  final String sellerPhone;
  final String buyerId; // current user id
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;

  const Conversation({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhone,
    required this.buyerId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  Conversation copyWith({
    String? id,
    String? listingId,
    String? listingTitle,
    String? sellerId,
    String? sellerName,
    String? sellerPhone,
    String? buyerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
  }) => Conversation(
        id: id ?? this.id,
        listingId: listingId ?? this.listingId,
        listingTitle: listingTitle ?? this.listingTitle,
        sellerId: sellerId ?? this.sellerId,
        sellerName: sellerName ?? this.sellerName,
        sellerPhone: sellerPhone ?? this.sellerPhone,
        buyerId: buyerId ?? this.buyerId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastMessage: lastMessage ?? this.lastMessage,
      );
}

class ChatMessage {
  final String id; // msg-<timestamp>
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  const ChatMessage({required this.id, required this.conversationId, required this.senderId, required this.text, required this.timestamp});
}

/// Chat provider backed by Firestore. Keeps a local cache and realtime listeners.
class LocalChatProvider extends ChangeNotifier {
  final Map<String, Conversation> _conversations = <String, Conversation>{};
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};

  // Active listeners
  String? _attachedUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSub;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _messageSubs = {};

  CollectionReference<Map<String, dynamic>> get _conversationsCol => FirebaseFirestore.instance.collection('conversations');

  List<Conversation> conversationsForUser(String userId) {
    // Ensure we attach a realtime listener for this user's conversations.
    _ensureConversationsListener(userId);
    final list = _conversations.values.where((c) => c.buyerId == userId || c.sellerId == userId).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Conversation? byId(String id) => _conversations[id];

  List<ChatMessage> messages(String conversationId) {
    _ensureMessagesListener(conversationId);
    return List<ChatMessage>.from(_messages[conversationId] ?? const <ChatMessage>[]);
  }

  Conversation ensureConversation({
    required String listingId,
    required String listingTitle,
    required String sellerId,
    required String sellerName,
    required String sellerPhone,
    required String buyerId,
  }) {
    // Build a stable conversation id: conv-<listingId>-<minParticipant>-<maxParticipant>
    String keyify(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final a = keyify(buyerId);
    final b = keyify(sellerId);
    final p1 = a.compareTo(b) <= 0 ? a : b;
    final p2 = a.compareTo(b) <= 0 ? b : a;
    final convId = 'conv-${keyify(listingId)}-$p1-$p2';
    final existing = _conversations[convId];
    if (existing != null) return existing;
    final now = DateTime.now();
    final c = Conversation(
      id: convId,
      listingId: listingId,
      listingTitle: listingTitle,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      buyerId: buyerId,
      createdAt: now,
      updatedAt: now,
      lastMessage: null,
    );
    _conversations[convId] = c;
    _messages[convId] = <ChatMessage>[];
    notifyListeners();
    return c;
  }

  Future<void> sendMessage({required String conversationId, required String senderId, required String text}) async {
    if (text.trim().isEmpty) return;
    final trimmed = text.trim();
    try {
      // Ensure conversation document exists and update its last message meta.
      final conv = _conversations[conversationId];
      if (conv == null) {
        debugPrint('sendMessage: conversation $conversationId not found in cache; cannot infer listingId/title');
      }
      final convRef = _conversationsCol.doc(conversationId);
      await FirebaseFirestore.instance.runTransaction((trx) async {
        final convSnap = await trx.get(convRef);
        final now = FieldValue.serverTimestamp();
        if (!convSnap.exists) {
          // Infer participants from id suffix if possible; otherwise fall back to sender only.
          final suffix = conversationId.split('-').skip(2).toList();
          final participants = suffix.length >= 2 ? <String>[suffix[suffix.length - 2], suffix[suffix.length - 1]] : <String>[senderId];
          trx.set(convRef, {
            'participants': participants,
            'listingId': conv?.listingId ?? '',
            'listingTitle': conv?.listingTitle ?? 'Listing',
            'lastMessage': trimmed,
            'lastMessageAt': now,
            'createdAt': now,
          }, SetOptions(merge: true));
        } else {
          trx.update(convRef, {
            'lastMessage': trimmed,
            'lastMessageAt': now,
          });
        }
        final msgRef = convRef.collection('messages').doc();
        trx.set(msgRef, {
          'senderId': senderId,
          'text': trimmed,
          'createdAt': now,
          'read': false,
        });
      });

      // Optimistically update local cache for instant UI feedback.
      final id = 'msg-${DateTime.now().microsecondsSinceEpoch}';
      final msg = ChatMessage(id: id, conversationId: conversationId, senderId: senderId, text: trimmed, timestamp: DateTime.now());
      final list = _messages[conversationId] ?? <ChatMessage>[];
      list.add(msg);
      _messages[conversationId] = list;
      final existing = _conversations[conversationId];
      if (existing != null) {
        _conversations[conversationId] = existing.copyWith(lastMessage: trimmed, updatedAt: DateTime.now());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
  }

  /// Helper to seed a bot auto-reply after user sends first message (optional UX sugar)
  Future<void> maybeAutoReply(String conversationId, String replyText) async {
    final list = _messages[conversationId] ?? const <ChatMessage>[];
    final hasReply = list.any((m) => m.senderId == 'system');
    if (hasReply) return;
    try {
      final convRef = _conversationsCol.doc(conversationId);
      await convRef.collection('messages').add({
        'senderId': 'system',
        'text': replyText,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      await convRef.set({'lastMessage': replyText, 'lastMessageAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('maybeAutoReply error: $e');
    }
  }

  void _ensureConversationsListener(String userId) {
    if (userId.isEmpty) return;
    if (_attachedUserId == userId && _conversationsSub != null) return;
    _attachedUserId = userId;
    _conversationsSub?.cancel();
    try {
      _conversationsSub = _conversationsCol
          .where('participants', arrayContains: userId)
          .limit(200)
          .snapshots()
          .listen((snap) {
        final Map<String, Conversation> next = {..._conversations};
        for (final doc in snap.docs) {
          final data = doc.data();
          final participants = (data['participants'] as List?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? const <String>[];
          final listingId = (data['listingId'] ?? '').toString();
          final listingTitle = (data['listingTitle'] ?? 'Listing').toString();
          final lastMessage = (data['lastMessage'] as String?) ?? next[doc.id]?.lastMessage;
          final createdAtTs = data['createdAt'];
          final updatedAtTs = data['lastMessageAt'] ?? data['updatedAt'];
          DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);
          if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();
          if (updatedAtTs is Timestamp) updatedAt = updatedAtTs.toDate();
          final other = participants.firstWhereOrNull((p) => p != _attachedUserId) ?? '';
          next[doc.id] = Conversation(
            id: doc.id,
            listingId: listingId,
            listingTitle: listingTitle,
            sellerId: other,
            sellerName: '',
            sellerPhone: '',
            buyerId: _attachedUserId ?? '',
            createdAt: createdAt == DateTime.fromMillisecondsSinceEpoch(0) ? DateTime.now() : createdAt,
            updatedAt: updatedAt == DateTime.fromMillisecondsSinceEpoch(0) ? createdAt : updatedAt,
            lastMessage: lastMessage,
          );
        }
        // Remove conversations not in the snapshot for this user
        final currentIds = snap.docs.map((d) => d.id).toSet();
        next.removeWhere((key, value) => !_belongsToUser(value, userId) || !currentIds.contains(key));
        _conversations
          ..clear()
          ..addAll(next);
        notifyListeners();
      }, onError: (e) {
        debugPrint('conversations listener error: $e');
      });
    } catch (e) {
      debugPrint('failed to attach conversations listener: $e');
    }
  }

  bool _belongsToUser(Conversation c, String userId) => c.buyerId == userId || c.sellerId == userId;

  void _ensureMessagesListener(String conversationId) {
    if (_messageSubs.containsKey(conversationId)) return;
    try {
      final sub = _conversationsCol
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt')
          .limit(500)
          .snapshots()
          .listen((snap) {
        final list = <ChatMessage>[];
        for (final doc in snap.docs) {
          final data = doc.data();
          final ts = data['createdAt'];
          final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
          list.add(ChatMessage(id: doc.id, conversationId: conversationId, senderId: (data['senderId'] ?? '').toString(), text: (data['text'] ?? '').toString(), timestamp: createdAt));
        }
        _messages[conversationId] = list;
        notifyListeners();
      }, onError: (e) {
        debugPrint('messages listener error [$conversationId]: $e');
      });
      _messageSubs[conversationId] = sub;
    } catch (e) {
      debugPrint('failed to attach messages listener: $e');
    }
  }

  /// Clear all local chat state and detach listeners (used on logout)
  void clear() {
    try {
      _conversations.clear();
      _messages.clear();
      _conversationsSub?.cancel();
      _conversationsSub = null;
      for (final s in _messageSubs.values) {
        s.cancel();
      }
      _messageSubs.clear();
      _attachedUserId = null;
    } catch (e) {
      debugPrint('LocalChatProvider.clear error: $e');
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _conversationsSub?.cancel();
    for (final s in _messageSubs.values) {
      s.cancel();
    }
    _messageSubs.clear();
    super.dispose();
  }
}

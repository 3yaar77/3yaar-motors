import 'package:flutter/foundation.dart';
import 'package:autoreel/services/reel_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';

DateTime _parseDate(dynamic v) {
  try {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // Assume millis since epoch
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    final s = v.toString();
    if (s.isEmpty) return DateTime.now();
    return DateTime.parse(s);
  } catch (e) {
    debugPrint('Reel date parse error for value="$v": $e');
    return DateTime.now();
  }
}

class ReelItem {
  final String id;
  final String videoUrl;
  final String title;
  // New car details
  final String brand; // e.g., Mercedes-Benz
  final String model; // e.g., G-Class G63 AMG
  final int? year; // optional
  final int? mileageKm; // optional
  final String condition; // e.g., New, Used, Agency warranty, GCC specs
  final int price;
  final String location;
  final String sellerPhone;
  final String description;
  final String userId;
  final String sellerUsername; // username/handle to show in UI
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final String listingType; // Free listing | VIP listing | Featured listing | Urgent listing
  final bool isVip;
  final bool isFeatured;
  final bool isUrgent;
  final int viewsCount;

  const ReelItem({
    required this.id,
    required this.videoUrl,
    required this.title,
    this.brand = '',
    this.model = '',
    this.year,
    this.mileageKm,
    this.condition = '',
    required this.price,
    required this.location,
    required this.sellerPhone,
    required this.description,
    required this.userId,
    this.sellerUsername = '',
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.listingType = 'Free listing',
    this.isVip = false,
    this.isFeatured = false,
    this.isUrgent = false,
    this.viewsCount = 0,
  });

  ReelItem copyWith({
    String? id,
    String? videoUrl,
    String? title,
    String? brand,
    String? model,
    int? year,
    int? mileageKm,
    String? condition,
    int? price,
    String? location,
    String? sellerPhone,
    String? description,
    String? userId,
    String? sellerUsername,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    String? listingType,
    bool? isVip,
    bool? isFeatured,
    bool? isUrgent,
    int? viewsCount,
  }) => ReelItem(
        id: id ?? this.id,
        videoUrl: videoUrl ?? this.videoUrl,
        title: title ?? this.title,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        year: year ?? this.year,
        mileageKm: mileageKm ?? this.mileageKm,
        condition: condition ?? this.condition,
        price: price ?? this.price,
        location: location ?? this.location,
        sellerPhone: sellerPhone ?? this.sellerPhone,
        description: description ?? this.description,
        userId: userId ?? this.userId,
        sellerUsername: sellerUsername ?? this.sellerUsername,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        createdAt: createdAt ?? this.createdAt,
        listingType: listingType ?? this.listingType,
        isVip: isVip ?? this.isVip,
        isFeatured: isFeatured ?? this.isFeatured,
        isUrgent: isUrgent ?? this.isUrgent,
        viewsCount: viewsCount ?? this.viewsCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'video_url': videoUrl,
        'video': videoUrl, // back-compat key
        'title': title,
        'brand': brand,
        'model': model,
        'year': year,
        'mileage_km': mileageKm,
        'condition': condition,
        'price': price,
        'location': location,
        'seller_phone': sellerPhone,
        'description': description,
        'user_id': userId,
        'seller_username': sellerUsername,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'created_at': createdAt.toIso8601String(),
        'listingType': listingType,
        'isVip': isVip,
        'isFeatured': isFeatured,
        'isUrgent': isUrgent,
        'viewsCount': viewsCount,
      };

  factory ReelItem.fromJson(Map<String, dynamic> json) {
    String parsedUsername = '';
    try {
      final userObj = json['user'];
      if (userObj is Map) {
        final u = userObj.cast<String, dynamic>();
        parsedUsername = (u['username'] ?? u['handle'] ?? u['displayName'] ?? u['name'] ?? '').toString();
      }
    } catch (_) {}
    // Also accept flat keys
    if (parsedUsername.trim().isEmpty) {
      parsedUsername = (json['seller_username'] ?? json['username'] ?? json['user_name'] ?? '').toString();
    }

    final createdRaw = json.containsKey('createdAt') ? json['createdAt'] : json['created_at'];

    return ReelItem(
      id: (json['id'] ?? '') as String,
      videoUrl: (json['video_url'] ?? json['videoUrl'] ?? json['video'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      brand: (json['brand'] ?? '') as String,
      model: (json['model'] ?? '') as String,
      year: json['year'] == null
          ? null
          : (json['year'] is int ? json['year'] as int : int.tryParse((json['year'].toString()).trim())),
      mileageKm: json['mileage_km'] == null
          ? null
          : (json['mileage_km'] is int ? json['mileage_km'] as int : int.tryParse((json['mileage_km'].toString()).trim())),
      condition: (json['condition'] ?? '') as String,
      price: (json['price'] is int) ? json['price'] as int : int.tryParse(((json['price'] ?? 0).toString()).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      location: (json['location'] ?? '') as String,
      sellerPhone: (json['seller_phone'] ?? json['sellerPhone'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      userId: (json['user_id'] ?? json['userId'] ?? json['ownerId'] ?? '') as String,
      sellerUsername: parsedUsername,
      likesCount: (json['likes_count'] ?? json['likesCount'] ?? 0) as int,
      commentsCount: (json['comments_count'] ?? json['commentsCount'] ?? 0) as int,
      createdAt: _parseDate(createdRaw),
      listingType: (json['listingType'] as String?) ?? 'Free listing',
      isVip: (json['isVip'] as bool?) ?? false,
      isFeatured: (json['isFeatured'] as bool?) ?? false,
      isUrgent: (json['isUrgent'] as bool?) ?? false,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReelComment {
  final String id;
  final String reelId;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  const ReelComment({
    required this.id,
    required this.reelId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reel_id': reelId,
        'user_id': userId,
        'user_name': userName,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };

  factory ReelComment.fromJson(Map<String, dynamic> json) => ReelComment(
        id: (json['id'] ?? '') as String,
        reelId: (json['reel_id'] ?? '') as String,
        userId: (json['user_id'] ?? '') as String,
        userName: (json['user_name'] ?? 'User') as String,
        text: (json['text'] ?? '') as String,
        createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      );
}

class ReelProvider extends ChangeNotifier {
  final ReelService _service = ReelService();
  bool _loading = true;
  String? _errorMessage;
  final List<ReelItem> _reels = [];
  final Set<String> _liked = <String>{};
  final Map<String, List<ReelComment>> _comments = <String, List<ReelComment>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _loadingTimeout;

  // Keep in sync with ReelService
  static const String _testVideoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  ReelProvider() {
    _init();
  }

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<ReelItem> get reels => List.unmodifiable(_reels);
  bool isLiked(String reelId) => _liked.contains(reelId);
  List<ReelComment> commentsFor(String reelId) => List.unmodifiable(_comments[reelId] ?? const []);

  Future<void> _init() async {
    try {
      // Reset state and start timeout guard to avoid infinite spinners
      _errorMessage = null;
      _loading = true;
      notifyListeners();
      _loadingTimeout?.cancel();
      _loadingTimeout = Timer(const Duration(seconds: 8), () {
        if (_loading) {
          _loading = false;
          _errorMessage ??= 'Timeout while loading reels';
          debugPrint('ReelProvider timeout after 8s - force stop loading');
          notifyListeners();
        }
      });

      // Likes and comments remain device-local
      _liked..clear()..addAll(await _service.loadLikedIds());
      final cm = await _service.loadComments();
      _comments..clear()..addAll(cm);

      Future<void> attach({required bool ordered}) async {
        final base = FirebaseFirestore.instance
            .collection('reels')
            .where('status', isEqualTo: 'active');
        final q = ordered ? base.orderBy('createdAt', descending: true).limit(100) : base.limit(100);
        await _sub?.cancel();
        _sub = q.snapshots().listen((snap) {
          try {
            final items = snap.docs.map((d) {
              final m = d.data();
              // Ensure id present for fromJson mapping
              final map = <String, dynamic>{'id': d.id, ...m};
              return ReelItem.fromJson(map);
            }).toList();
            // Ensure deterministic sort by DateTime (newest first)
            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _reels..clear()..addAll(items);
            _loading = false;
            _errorMessage = null;
            _loadingTimeout?.cancel();
            notifyListeners();
          } catch (e) {
            debugPrint('ReelProvider map error: $e');
            _errorMessage = 'Reels load error: $e';
          }
        }, onError: (e) async {
          debugPrint('ReelProvider Firestore stream error: $e');
          _errorMessage = 'Reels load error: $e';
          final msg = e.toString().toLowerCase();
          if (ordered && (msg.contains('failed-precondition') || msg.contains('requires an index'))) {
            debugPrint('ReelProvider: falling back without orderBy(createdAt)');
            await attach(ordered: false);
          } else {
            _loading = false;
            _loadingTimeout?.cancel();
            notifyListeners();
          }
        });
      }

      await attach(ordered: true);
    } catch (e) {
      debugPrint('ReelProvider init error: $e');
      _errorMessage = 'Reels load error: $e';
      _loading = false;
      _loadingTimeout?.cancel();
      notifyListeners();
    }
  }

  Future<void> addReel(ReelItem reel) async {
    _reels.insert(0, reel);
    notifyListeners();
    await _service.saveReels(_reels);
  }

  Future<void> toggleLike(String id) async {
    final i = _reels.indexWhere((r) => r.id == id);
    if (i == -1) return;
    final current = _reels[i];
    if (_liked.contains(id)) {
      _liked.remove(id);
      final newCount = (current.likesCount - 1).clamp(0, 1 << 31);
      _reels[i] = current.copyWith(likesCount: newCount);
    } else {
      _liked.add(id);
      _reels[i] = current.copyWith(likesCount: current.likesCount + 1);
    }
    notifyListeners();
    await _service.saveReels(_reels);
    await _service.saveLikedIds(_liked);
  }

  Future<void> addComment(String reelId, ReelComment comment) async {
    final list = List<ReelComment>.from(_comments[reelId] ?? const []);
    list.add(comment);
    _comments[reelId] = list;
    // bump count on reel
    final i = _reels.indexWhere((r) => r.id == reelId);
    if (i != -1) {
      final current = _reels[i];
      _reels[i] = current.copyWith(commentsCount: current.commentsCount + 1);
    }
    notifyListeners();
    await _service.saveReels(_reels);
    await _service.saveComments(_comments);
  }

  Future<void> incrementViews(String reelId) async {
    final i = _reels.indexWhere((r) => r.id == reelId);
    if (i == -1) return;
    final current = _reels[i];
    _reels[i] = current.copyWith(viewsCount: current.viewsCount + 1);
    notifyListeners();
    await _service.saveReels(_reels);
  }

  /// Apply a local upgrade package to a reel/video listing
  /// package: featured | vip | urgent | topBoost (topBoost just reorders visually)
  Future<void> applyUpgrade({required String id, required String package}) async {
    final i = _reels.indexWhere((r) => r.id == id);
    if (i == -1) return;
    var current = _reels[i];
    switch (package) {
      case 'featured':
        current = current.copyWith(isFeatured: true);
        break;
      case 'vip':
        current = current.copyWith(isVip: true);
        break;
      case 'urgent':
        current = current.copyWith(isUrgent: true);
        break;
      case 'topBoost':
        // Move to top of list locally
        final item = current;
        _reels.removeAt(i);
        _reels.insert(0, item);
        notifyListeners();
        await _service.saveReels(_reels);
        return;
      default:
        break;
    }
    _reels[i] = current;
    notifyListeners();
    await _service.saveReels(_reels);
  }

  /// Delete a reel by id (owner-only in UI). Updates local state and persists.
  Future<void> deleteReel(String id) async {
    try {
      // Try to delete associated storage files (videoUrls)
      final docRef = FirebaseFirestore.instance.collection('reels').doc(id);
      final snap = await docRef.get();
      final data = snap.data();
      if (data != null) {
        final urls = (data['videoUrls'] is List) ? List<String>.from(data['videoUrls'] as List) : <String>[];
        for (final url in urls) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(url);
            await ref.delete();
          } catch (e) {
            debugPrint('ReelProvider.deleteReel: storage delete failed for $url: $e');
          }
        }
      }
      await docRef.delete();
      // Local cleanup
      final before = _reels.length;
      _reels.removeWhere((r) => r.id == id);
      _comments.remove(id);
      notifyListeners();
      await _service.saveComments(_comments); // likes/comments remain local
      debugPrint('ReelProvider.deleteReel: deleted $id (before=$before, after=${_reels.length})');
    } catch (e) {
      debugPrint('ReelProvider.deleteReel error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _loadingTimeout?.cancel();
    super.dispose();
  }
}
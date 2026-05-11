import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/services/accessory_service.dart';
import 'package:autoreel/utils/image_url_utils.dart';
import 'package:autoreel/services/image_storage_service.dart';

class Accessory {
  final String id;
  final String title;
  final int price;
  final String condition; // New | Used
  final String category; // Wheels & Tires, Screens & Audio, ...
  final String description;
  final List<String> images; // https urls
  final String location; // city
  final String sellerPhone;
  final String ownerId; // user reference uid
  final DateTime createdAt;
  final DateTime updatedAt;

  const Accessory({
    required this.id,
    required this.title,
    required this.price,
    required this.condition,
    required this.category,
    required this.description,
    required this.images,
    required this.location,
    required this.sellerPhone,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  Accessory copyWith({
    String? id,
    String? title,
    int? price,
    String? condition,
    String? category,
    String? description,
    List<String>? images,
    String? location,
    String? sellerPhone,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Accessory(
        id: id ?? this.id,
        title: title ?? this.title,
        price: price ?? this.price,
        condition: condition ?? this.condition,
        category: category ?? this.category,
        description: description ?? this.description,
        images: images ?? this.images,
        location: location ?? this.location,
        sellerPhone: sellerPhone ?? this.sellerPhone,
        ownerId: ownerId ?? this.ownerId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'price': price,
        'condition': condition,
        'category': category,
        'description': description,
        'images': images,
        'location': location,
        'sellerPhone': sellerPhone,
        'ownerId': ownerId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static Accessory fromJson(String id, Map<String, dynamic> json) {
    DateTime _ts(dynamic v) {
      try {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      } catch (_) {}
      return DateTime.now();
    }

    List<String> _strList(dynamic v) {
      if (v is List) {
        return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).cast<String>().toList();
      }
      return const <String>[];
    }

    int _int(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return 0;
    }

    return Accessory(
      id: id,
      title: (json['title'] as String?)?.trim() ?? '',
      price: _int(json['price']),
      condition: (json['condition'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      images: _strList(json['images']).where((u) => ImageUrlUtils.isValidFirebaseDownload(u)).toList(),
      location: (json['location'] as String?)?.trim() ?? '',
      sellerPhone: (json['sellerPhone'] as String?)?.trim() ?? '',
      ownerId: (json['ownerId'] as String?)?.trim() ?? '',
      createdAt: _ts(json['createdAt']),
      updatedAt: _ts(json['updatedAt']),
    );
  }
}

class AccessoryProvider extends ChangeNotifier {
  final AccessoryService _service = AccessoryService();
  final List<Accessory> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _isLoading = true;

  // Filters
  String? _categoryFilter; // null or one of categories
  String? _conditionFilter; // null | New | Used

  AccessoryProvider() {
    _attachStream();
  }

  bool get isLoading => _isLoading;
  List<Accessory> get items {
    var list = List<Accessory>.from(_items);
    if ((_categoryFilter ?? '').isNotEmpty) {
      final f = _categoryFilter!.toLowerCase();
      list = list.where((a) => a.category.toLowerCase() == f).toList();
    }
    if ((_conditionFilter ?? '').isNotEmpty) {
      final f = _conditionFilter!.toLowerCase();
      list = list.where((a) => a.condition.toLowerCase() == f).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  String? get categoryFilter => _categoryFilter;
  String? get conditionFilter => _conditionFilter;

  void setCategoryFilter(String? v) {
    _categoryFilter = (v == null || v.isEmpty || v == 'All') ? null : v;
    notifyListeners();
  }

  void setConditionFilter(String? v) {
    _conditionFilter = (v == null || v.isEmpty || v == 'All') ? null : v;
    notifyListeners();
  }

  Future<void> create(Accessory accessory) => _service.create(accessory);
  Future<void> update(String id, Map<String, dynamic> data) => _service.update(id, data);
  Future<void> delete(String id) => _service.delete(id);

  /// Force a one-time reload so newly uploaded images show instantly in the grid
  Future<void> refresh() async {
    try {
      final q = await _service.col.orderBy('createdAt', descending: true).limit(100).get();
      final list = q.docs.map((d) => Accessory.fromJson(d.id, d.data())).toList();
      _items..clear()..addAll(list);
      notifyListeners();
    } catch (e) {
      debugPrint('AccessoryProvider.refresh error: $e');
    }
  }

  void _attachStream() async {
    _isLoading = true;
    notifyListeners();
    try {
      final col = _service.col;
      Future<void> listen({required bool ordered}) async {
        final q = ordered ? col.orderBy('createdAt', descending: true).limit(100) : col.limit(100);
        await _sub?.cancel();
        _sub = q.snapshots().listen((snap) {
          final list = snap.docs
              .map((d) => Accessory.fromJson(d.id, d.data()))
              .toList();
          _items..clear()..addAll(list);
          _isLoading = false;
          notifyListeners();

          // Auto-repair any broken gs:// URLs to HTTPS download URLs in background
          for (final d in snap.docs) {
            try {
              final data = d.data();
              final raw = (data['images'] as List?)?.whereType<String>().toList() ?? const <String>[];
              final hasInvalid = raw.any((u) => !ImageUrlUtils.isValidFirebaseDownload(u));
              if (!hasInvalid) continue;
              _repairDocImagesIfPossible(d, raw);
            } catch (e) {
              debugPrint('AccessoryProvider repair scan error: $e');
            }
          }
        }, onError: (e) async {
          debugPrint('AccessoryProvider stream error: $e');
          final msg = e.toString().toLowerCase();
          if (ordered && (msg.contains('failed-precondition') || msg.contains('requires an index'))) {
            await listen(ordered: false);
          }
        });
      }
      await listen(ordered: true);
    } catch (e) {
      debugPrint('AccessoryProvider attachStream error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _repairDocImagesIfPossible(DocumentSnapshot<Map<String, dynamic>> d, List<String> raw) async {
    try {
      final fixed = await ImageStorageService.repairImageUrls(raw);
      if (fixed.isEmpty) return; // don't overwrite with empty
      final areSame = fixed.length == raw.length && List.generate(fixed.length, (i) => fixed[i] == raw[i]).every((b) => b);
      if (areSame) return;
      await d.reference.update({'images': fixed});
      debugPrint('AccessoryProvider: repaired images[] for ${d.id}');
    } catch (e) {
      debugPrint('AccessoryProvider _repairDocImagesIfPossible error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

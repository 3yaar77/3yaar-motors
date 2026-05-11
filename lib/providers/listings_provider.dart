import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:autoreel/utils/image_url_utils.dart';
import 'package:autoreel/services/image_storage_service.dart';

/// Unified listing model for HomePage Featured Listings
/// type: 'photo' or 'reel'
class Listing {
  final String id;
  final String type; // photo | reel | car (normalized from backend)
  final List<String> images; // data URLs or http(s)
  final String? video; // http(s) or blob url for local preview
  final String make; // normalized from 'brand'
  final String model;
  final int? year;
  final int? mileage; // KM
  final int? price; // AED
  final String location;
  final String phone; // normalized from ownerPhone/phone
  final String description;
  final String condition; // New | Used | Agency warranty | GCC specs | ''
  final DateTime createdAt;
  final bool isVip; // optional flag from backend
  final bool isFeatured;
  final bool isUrgent;
  final String ownerId;
  final String ownerName;
  final String listingType; // Free listing | VIP listing | Featured listing | Urgent listing | ''

  const Listing({
    required this.id,
    required this.type,
    required this.images,
    this.video,
    required this.make,
    required this.model,
    this.year,
    this.mileage,
    this.price,
    required this.location,
    required this.phone,
    required this.description,
    required this.condition,
    required this.createdAt,
    this.isVip = false,
    this.isFeatured = false,
    this.isUrgent = false,
    this.ownerId = '',
    this.ownerName = 'Seller',
    this.listingType = '',
  });

  Listing copyWith({
    String? id,
    String? type,
    List<String>? images,
    String? video,
    String? make,
    String? model,
    int? year,
    int? mileage,
    int? price,
    String? location,
    String? phone,
    String? description,
    String? condition,
    DateTime? createdAt,
    bool? isVip,
    bool? isFeatured,
    bool? isUrgent,
    String? ownerId,
    String? ownerName,
    String? listingType,
  }) => Listing(
        id: id ?? this.id,
        type: type ?? this.type,
        images: images ?? this.images,
        video: video ?? this.video,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        mileage: mileage ?? this.mileage,
        price: price ?? this.price,
        location: location ?? this.location,
        phone: phone ?? this.phone,
        description: description ?? this.description,
        condition: condition ?? this.condition,
        createdAt: createdAt ?? this.createdAt,
        isVip: isVip ?? this.isVip,
        isFeatured: isFeatured ?? this.isFeatured,
        isUrgent: isUrgent ?? this.isUrgent,
        ownerId: ownerId ?? this.ownerId,
        ownerName: ownerName ?? this.ownerName,
        listingType: listingType ?? this.listingType,
      );

  /// Build from Firestore doc with defensive parsing
  static Listing fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    String readString(String key, {String alt = ''}) {
      final v = data[key];
      if (v == null) return alt;
      return v.toString();
    }

    int? readInt(String key) {
      final v = data[key];
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) {
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(digits);
      }
      return null;
    }

    DateTime readTime() {
      final v1 = data['createdAt'];
      final v2 = data['created_at'];
      final v = v1 ?? v2;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    List<String> readStringList(String key) {
      final v = data[key];
      if (v is List) {
        return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).cast<String>().toList();
      }
      return const <String>[];
    }

    bool _isValid(String s) => ImageUrlUtils.isValidFirebaseDownload(s);

    final imagesList = readStringList('images');
    final videos = readStringList('videoUrls');
    final cover = readString('coverImageUrl');
    // New rule: primary = cover (if set) else images[0]; ignore legacy fields
    String? primary = cover.isNotEmpty ? cover : (imagesList.isNotEmpty ? imagesList.first : null);
    List<String> rest = imagesList;
    if (primary != null) rest = rest.where((e) => e != primary).toList();
    final List<String> effectiveImages = [if (primary != null) primary, ...rest]
        .where((u) => _isValid(u))
        .toList();
    // Debug: print imageUrl for troubleshooting image loading
    try {
      debugPrint('Listing ${doc.id} primary image: ${effectiveImages.isNotEmpty ? effectiveImages.first : '(none)'} | imageUrl: ${primary ?? '(empty)'}');
    } catch (_) {}

    final brand = readString('brand');
    final make = brand.isNotEmpty ? brand : readString('make');

    return Listing(
      id: readString('id', alt: doc.id),
      type: 'car', // normalize for Featured Cars grid
      images: effectiveImages,
      video: videos.isNotEmpty ? videos.first : null,
      make: make,
      model: readString('model'),
      year: readInt('year'),
      mileage: readInt('mileage'),
      price: readInt('price'),
      location: readString('location'),
      phone: readString('ownerPhone', alt: readString('phone')),
      description: readString('description'),
      condition: readString('condition'),
      createdAt: readTime(),
      isVip: (data['isVip'] as bool?) ?? false,
      isFeatured: (data['isFeatured'] as bool?) ?? false,
      isUrgent: (data['isUrgent'] as bool?) ?? false,
      ownerId: readString('ownerId'),
      ownerName: readString('ownerName', alt: 'Seller'),
      listingType: readString('listingType'),
    );
  }
}

class ListingsProvider extends ChangeNotifier {
  final List<Listing> _listings = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  ListingsProvider() {
    _startFirestoreListener();
    // Removed demo seeding to avoid injecting sample data into Firestore.
    // _ensureSeedData();
  }

  List<Listing> get listings {
    final list = List<Listing>.from(_listings);
    int prio(Listing l) {
      if (l.isVip) return 0;
      if (l.isFeatured) return 1;
      if (l.isUrgent) return 2;
      return 3;
    }
    list.sort((a, b) {
      final pa = prio(a), pb = prio(b);
      if (pa != pb) return pa.compareTo(pb);
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Force a one-time reload to reflect latest Firestore changes immediately
  Future<void> refresh() async {
    try {
      final base = FirebaseFirestore.instance
          .collection('listings')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          )
          .where('status', isEqualTo: 'active')
          .where('category', isEqualTo: 'Cars');
      final q = await base.orderBy('createdAt', descending: true).limit(50).get();
      final items = q.docs.map((d) => Listing.fromFirestore(d)).where((l) => l.images.isNotEmpty && ImageUrlUtils.isValidFirebaseDownload(l.images.first)).toList();
      _listings..clear()..addAll(items);
      notifyListeners();

      // background repair
      for (final d in q.docs) {
        try {
          final data = d.data();
          final raw = (data['images'] as List?)?.whereType<String>().toList() ?? const <String>[];
          final hasInvalid = raw.any((u) => !ImageUrlUtils.isValidFirebaseDownload(u));
          if (!hasInvalid) continue;
          _repairDocImagesIfPossible(d, raw);
        } catch (e) {
          debugPrint('ListingsProvider.refresh repair scan error: $e');
        }
      }
    } catch (e) {
      debugPrint('ListingsProvider.refresh error: $e');
    }
  }

  /// Convert current listings into legacy Map shape used by FeedPage's grid
  List<Map<String, dynamic>> toMapList() => listings
      .map((e) => <String, dynamic>{
            'id': e.id,
            'type': e.type,
            'title': '${e.make} ${e.model}'.trim(),
            'make': e.make,
            'model': e.model,
            'year': e.year,
            'mileage': e.mileage,
            'price': e.price,
            'location': e.location,
            'condition': e.condition,
            'transmission': '',
            // Image fields prioritized by consumer widgets: coverImageUrl || imageUrl || image
            'images': e.images,
            'coverImageUrl': e.images.isNotEmpty ? e.images.first : '',
            'imageUrl': e.images.isNotEmpty ? e.images.first : '',
            'image': e.images.isNotEmpty ? e.images.first : '',
            'sellerPhone': e.phone,
            'phone': e.phone,
            'time': e.createdAt,
            'isVip': e.isVip,
            'isFeatured': e.isFeatured,
            'isUrgent': e.isUrgent,
            'listingType': e.listingType,
            'ownerId': e.ownerId,
          })
      .toList();

  void addListing(Listing listing) {
    _listings.insert(0, listing);
    notifyListeners();
  }

  void clearAll() {
    _listings.clear();
    notifyListeners();
  }

  /// Apply a local upgrade to a unified image listing (not persisted to Firestore)
  /// package: featured | vip | urgent | topBoost (topBoost moves item to top)
  void applyLocalUpgrade({required String id, required String package}) {
    final i = _listings.indexWhere((e) => e.id == id);
    if (i == -1) return;
    var item = _listings[i];
    switch (package) {
      case 'featured':
        item = item.copyWith(isFeatured: true);
        _listings[i] = item;
        break;
      case 'vip':
        item = item.copyWith(isVip: true);
        _listings[i] = item;
        break;
      case 'urgent':
        item = item.copyWith(isUrgent: true);
        _listings[i] = item;
        break;
      case 'topBoost':
        final moved = item;
        _listings.removeAt(i);
        _listings.insert(0, moved);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> _startFirestoreListener() async {
    Future<void> attach({required bool ordered}) async {
      final base = FirebaseFirestore.instance
          .collection('listings')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          )
          .where('status', isEqualTo: 'active')
          .where('category', isEqualTo: 'Cars');
      final q = ordered ? base.orderBy('createdAt', descending: true).limit(50) : base.limit(50);
      _sub?.cancel();
      _sub = q.snapshots().listen((snap) {
        try {
          // Global diagnostics: log every loaded Firestore listing document
          for (final d in snap.docs) {
            final map = d.data();
            try {
              debugPrint('LOADED DOC: ' + (map == null ? '{}' : (map is Map<String, dynamic> ? jsonEncode(map) : map.toString())));
            } catch (_) {
              debugPrint('LOADED DOC: ' + (map?.toString() ?? '{}'));
            }
          }
          final items = snap.docs
              .map((d) => Listing.fromFirestore(d))
              // Keep only listings with valid Firebase download primary image
              .where((l) => l.images.isNotEmpty && ImageUrlUtils.isValidFirebaseDownload(l.images.first))
              .toList();
          _listings..clear()..addAll(items);
          notifyListeners();

          // background repair
          for (final d in snap.docs) {
            try {
              final data = d.data();
              final raw = (data['images'] as List?)?.whereType<String>().toList() ?? const <String>[];
              final hasInvalid = raw.any((u) => !ImageUrlUtils.isValidFirebaseDownload(u));
              if (!hasInvalid) continue;
              _repairDocImagesIfPossible(d, raw);
            } catch (e) {
              debugPrint('ListingsProvider listener repair scan error: $e');
            }
          }
        } catch (e) {
          debugPrint('ListingsProvider map error: $e');
        }
      }, onError: (e) async {
        debugPrint('ListingsProvider Firestore stream error: $e');
        // If index error, fallback without orderBy
        final msg = e.toString().toLowerCase();
        if (ordered && (msg.contains('failed-precondition') || msg.contains('requires an index'))) {
          debugPrint('Falling back to query without orderBy(createdAt)');
          await attach(ordered: false);
        }
      });
    }

    try {
      await attach(ordered: true);
    } catch (e) {
      debugPrint('ListingsProvider listener init error: $e');
    }
  }

  Future<void> _ensureSeedData() async {
    try {
      final col = FirebaseFirestore.instance.collection('listings');
      // Seed only once: if no demo-assets batch exists, add 4 demo docs using bundled assets
      final exist = await col.where('seedTag', isEqualTo: 'demo_assets_v1').limit(1).get();
      if (exist.docs.isNotEmpty) return;

      final now = FieldValue.serverTimestamp();
      final List<Map<String, dynamic>> items = [
        {
          'brand': 'Mercedes-Benz',
          'model': 'G-Class',
          'year': 2022,
          'price': 850000,
          'mileage': 18000,
          'location': 'Dubai',
          'condition': 'Used',
          'transmission': 'Automatic',
          'category': 'Cars',
          'imageUrls': [
            'assets/images/sports_car_black_1777063455577.jpg',
            'assets/images/luxury_car_gray_1777063456696.jpg',
          ],
          'videoUrls': <String>[],
          'ownerName': 'Demo Seller',
          'ownerPhone': '+971500000001',
          'ownerId': 'user_002',
          'isVip': true,
          'status': 'active',
          'createdAt': now,
          'seedTag': 'demo_assets_v1',
        },
        {
          'brand': 'Nissan',
          'model': 'Patrol',
          'year': 2021,
          'price': 185000,
          'mileage': 52000,
          'location': 'Abu Dhabi',
          'condition': 'Used',
          'transmission': 'Automatic',
          'category': 'Cars',
          'imageUrls': [
            'assets/images/SUV_car_UAE_white_1777063448380.jpg',
            'assets/images/fast_car_red_1777063457663.jpg',
          ],
          'videoUrls': <String>[],
          'ownerName': 'Demo Seller',
          'ownerPhone': '+971500000002',
          'ownerId': 'user_002',
          'isVip': false,
          'status': 'active',
          'createdAt': now,
          'seedTag': 'demo_assets_v1',
        },
        {
          'brand': 'Toyota',
          'model': 'Land Cruiser',
          'year': 2023,
          'price': 325000,
          'mileage': 22000,
          'location': 'Dubai',
          'condition': 'Used',
          'transmission': 'Automatic',
          'category': 'Cars',
          'imageUrls': [
            'assets/images/performance_car_side_view_blue_1777063449574.jpg',
            'assets/images/luxury_car_gray_1777063456696.jpg',
          ],
          'videoUrls': <String>[],
          'ownerName': 'Demo Seller',
          'ownerPhone': '+971500000003',
          'ownerId': 'user_002',
          'isVip': false,
          'status': 'active',
          'createdAt': now,
          'seedTag': 'demo_assets_v1',
        },
        {
          'brand': 'BMW',
          'model': 'M4',
          'year': 2019,
          'price': 259000,
          'mileage': 68000,
          'location': 'Dubai',
          'condition': 'Used',
          'transmission': 'Automatic',
          'category': 'Cars',
          'imageUrls': [
            'assets/images/fast_car_red_1777063457663.jpg',
            'assets/images/sports_car_black_1777063455577.jpg',
          ],
          'videoUrls': <String>[],
          'ownerName': 'Demo Seller',
          'ownerPhone': '+971500000004',
          'ownerId': 'user_002',
          'isVip': false,
          'status': 'active',
          'createdAt': now,
          'seedTag': 'demo_assets_v1',
        },
      ];

      for (final m in items) {
        await col.add(m);
      }
      debugPrint('Seeded demo asset car listings into Firestore.');
    } catch (e) {
      debugPrint('Seed data error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _repairDocImagesIfPossible(DocumentSnapshot<Map<String, dynamic>> d, List<String> raw) async {
    try {
      final fixed = await ImageStorageService.repairImageUrls(raw);
      if (fixed.isEmpty) return;
      final areSame = fixed.length == raw.length && List.generate(fixed.length, (i) => fixed[i] == raw[i]).every((b) => b);
      if (areSame) return;
      await d.reference.update({'images': fixed});
      debugPrint('ListingsProvider: repaired images[] for ${d.id}');
    } catch (e) {
      debugPrint('ListingsProvider _repairDocImagesIfPossible error: $e');
    }
  }
}

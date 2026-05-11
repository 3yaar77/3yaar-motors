import 'package:flutter/foundation.dart';
import 'package:autoreel/services/plate_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Plate {
  final String id;
  final String plateNumber; // e.g., "A 12345"
  final String emirate; // e.g., Dubai, Abu Dhabi
  final int price; // AED price
  final String sellerPhone; // digits only, e.g., 971501234567
  final DateTime createdAt;
  final String description; // optional details
  bool isLiked;
  // Optional marketplace signals
  final bool sellerVerified;
  final bool isVip;
  final bool isFeatured;
  final bool isPinned;
  final DateTime? promotionExpiry;
  final String listingType; // Free listing | VIP listing | Featured listing | Urgent listing
  final bool isUrgent;
  final String? paymentStatus; // e.g., pending
  final int? upgradePrice; // AED amount for upgrade
  final int viewsCount;
  final String ownerId; // listing owner (demo/local: current_user | other_user)

  Plate({
    required this.id,
    required this.plateNumber,
    required this.emirate,
    required this.price,
    required this.sellerPhone,
    required this.createdAt,
    this.description = '',
    this.isLiked = false,
    this.sellerVerified = false,
    this.isVip = false,
    this.isFeatured = false,
    this.isPinned = false,
    this.promotionExpiry,
    this.listingType = 'Free listing',
    this.isUrgent = false,
    this.paymentStatus,
    this.upgradePrice,
    this.viewsCount = 0,
    this.ownerId = '',
  });

  Plate copyWith({
    String? id,
    String? plateNumber,
    String? emirate,
    int? price,
    String? sellerPhone,
    DateTime? createdAt,
    String? description,
    bool? isLiked,
    bool? sellerVerified,
    bool? isVip,
    bool? isFeatured,
    bool? isPinned,
    DateTime? promotionExpiry,
    String? listingType,
    bool? isUrgent,
    String? paymentStatus,
    int? upgradePrice,
    int? viewsCount,
    String? ownerId,
  }) => Plate(
        id: id ?? this.id,
        plateNumber: plateNumber ?? this.plateNumber,
        emirate: emirate ?? this.emirate,
        price: price ?? this.price,
        sellerPhone: sellerPhone ?? this.sellerPhone,
        createdAt: createdAt ?? this.createdAt,
        description: description ?? this.description,
        isLiked: isLiked ?? this.isLiked,
        sellerVerified: sellerVerified ?? this.sellerVerified,
        isVip: isVip ?? this.isVip,
        isFeatured: isFeatured ?? this.isFeatured,
        isPinned: isPinned ?? this.isPinned,
        promotionExpiry: promotionExpiry ?? this.promotionExpiry,
        listingType: listingType ?? this.listingType,
        isUrgent: isUrgent ?? this.isUrgent,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        upgradePrice: upgradePrice ?? this.upgradePrice,
        viewsCount: viewsCount ?? this.viewsCount,
        ownerId: ownerId ?? this.ownerId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plateNumber': plateNumber,
        'emirate': emirate,
        'price': price,
        'sellerPhone': sellerPhone,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'isLiked': isLiked,
        'sellerVerified': sellerVerified,
        'isVip': isVip,
        'isFeatured': isFeatured,
        'isPinned': isPinned,
        'promotionExpiry': promotionExpiry?.toIso8601String(),
        'listingType': listingType,
        'isUrgent': isUrgent,
        'paymentStatus': paymentStatus,
        'upgradePrice': upgradePrice,
        'viewsCount': viewsCount,
        'ownerId': ownerId,
      };

  factory Plate.fromJson(Map<String, dynamic> json) {
    DateTime _parseDate(dynamic v) {
      try {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        if (v is String) {
          final dt = DateTime.tryParse(v);
          if (dt != null) return dt;
        }
      } catch (_) {}
      return DateTime.now();
    }

    String _pickPlateNumber() {
      for (final k in ['plateNumber', 'plate_number', 'number', 'plateNo', 'plate_no']) {
        final v = json[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      // If code + number split fields exist, try to join
      final code = (json['plateCode'] as String?)?.trim() ?? '';
      final numOnly = (json['plateNum'] as String?)?.trim() ?? '';
      if (code.isNotEmpty && numOnly.isNotEmpty) return '$code $numOnly';
      return '-';
    }

    return Plate(
      id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
      plateNumber: _pickPlateNumber(),
      emirate: (json['emirate'] as String?)?.trim() ?? '-',
      price: (json['price'] is num) ? (json['price'] as num).toInt() : int.tryParse('${json['price']}') ?? 0,
      sellerPhone: ((json['sellerPhone'] ?? '') as String).trim(),
      createdAt: _parseDate(json['createdAt']),
      description: (json['description'] as String?) ?? '',
      isLiked: (json['isLiked'] as bool?) ?? false,
      sellerVerified: (json['sellerVerified'] as bool?) ?? false,
      isVip: (json['isVip'] as bool?) ?? false,
      isFeatured: (json['isFeatured'] as bool?) ?? false,
      isPinned: (json['isPinned'] as bool?) ?? false,
      promotionExpiry: json['promotionExpiry'] == null ? null : _parseDate(json['promotionExpiry']),
      listingType: (json['listingType'] as String?) ?? 'Free listing',
      isUrgent: (json['isUrgent'] as bool?) ?? false,
      paymentStatus: json['paymentStatus'] as String?,
      upgradePrice: json['upgradePrice'] is num ? (json['upgradePrice'] as num).toInt() : int.tryParse('${json['upgradePrice']}'),
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      ownerId: (json['ownerId'] as String?) ?? '',
    );
  }
}

// Global App State list holding all plate listings
final List<Plate> platesList = [];

class PlateProvider extends ChangeNotifier {
  final PlateService _service = PlateService();
  bool _isLoading = true;

  PlateProvider() {
    _init();
  }

  bool get isLoading => _isLoading;
  List<Plate> get plates => platesList;

  Future<void> _init() async {
    try {
      final loaded = await _service.loadPlates();
      platesList
        ..clear()
        ..addAll(loaded);
    } catch (e) {
      debugPrint('PlateProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String id) async {
    final idx = platesList.indexWhere((p) => p.id == id);
    if (idx != -1) {
      platesList[idx].isLiked = !platesList[idx].isLiked;
      notifyListeners();
      await _service.savePlates(plates);
    }
  }

  Future<void> addPlate(Plate plate) async {
    platesList.insert(0, plate);
    notifyListeners();
    await _service.savePlates(plates);
  }

  Future<void> incrementViews(String id) async {
    final idx = platesList.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final current = platesList[idx];
    platesList[idx] = current.copyWith(viewsCount: current.viewsCount + 1);
    notifyListeners();
    await _service.savePlates(plates);
  }

  Plate? byId(String id) {
    try {
      return platesList.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Apply a local upgrade package to a plate listing
  /// package: featured | vip | urgent | topBoost
  Future<void> applyUpgrade({required String id, required String package}) async {
    final idx = platesList.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final now = DateTime.now();
    var plate = platesList[idx];
    int days = 1;
    switch (package) {
      case 'featured':
        plate = plate.copyWith(isFeatured: true);
        days = 3;
        break;
      case 'vip':
        plate = plate.copyWith(isVip: true);
        days = 7;
        break;
      case 'urgent':
        plate = plate.copyWith(isUrgent: true);
        days = 3;
        break;
      case 'topBoost':
        plate = plate.copyWith(isPinned: true);
        days = 1;
        break;
      default:
        break;
    }
    plate = plate.copyWith(promotionExpiry: now.add(Duration(days: days)));
    platesList[idx] = plate;
    notifyListeners();
    await _service.savePlates(plates);
  }
}

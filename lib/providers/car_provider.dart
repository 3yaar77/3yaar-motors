import 'package:flutter/foundation.dart';
import 'package:autoreel/services/car_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Car {
  final String id;
  final String make;
  final String model;
  final int year;
  final int price;
  final int mileage;
  final String location;
  final String imageUrl;
  final List<String> imageUrls; // New: multiple image URLs (Firebase download URLs)
  final String sellerPhone;
  final String description;
  final DateTime createdAt;
  bool isLiked;
  // Promotions
  final bool isFeatured;
  final bool isPinned;
  final bool isVip;
  final DateTime? promotionExpiry; // unified expiry for current promotion
  // Payment metadata
  final String? lastPaymentId;
  final DateTime? promotedAt;
  // Ownership & moderation
  final String ownerId; // user id of the lister
  final String status; // active | sold | pending_review | rejected
  final bool isBlocked; // blocked by reports/admin
  final int reportCount; // number of reports
  // Views
  final int viewsCount;
  final bool isUrgent;

  // Expose images[] alias for UI (maps to imageUrls)
  List<String> get images => imageUrls;

  Car({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.price,
    required this.mileage,
    required this.location,
    required this.imageUrl,
    this.imageUrls = const <String>[],
    required this.sellerPhone,
    required this.description,
    required this.createdAt,
    this.isLiked = false,
    this.isFeatured = false,
    this.isPinned = false,
    this.isVip = false,
    this.promotionExpiry,
    this.lastPaymentId,
    this.promotedAt,
    this.ownerId = '',
    this.status = 'active',
    this.isBlocked = false,
    this.reportCount = 0,
    this.viewsCount = 0,
    this.isUrgent = false,
  });

  Car copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    int? price,
    int? mileage,
    String? location,
    String? imageUrl,
    List<String>? imageUrls,
    String? sellerPhone,
    String? description,
    DateTime? createdAt,
    bool? isLiked,
    bool? isFeatured,
    bool? isPinned,
    bool? isVip,
    DateTime? promotionExpiry,
    String? lastPaymentId,
    DateTime? promotedAt,
    String? ownerId,
    String? status,
    bool? isBlocked,
    int? reportCount,
    int? viewsCount,
    bool? isUrgent,
  }) => Car(
        id: id ?? this.id,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        price: price ?? this.price,
        mileage: mileage ?? this.mileage,
        location: location ?? this.location,
        imageUrl: imageUrl ?? this.imageUrl,
        imageUrls: imageUrls ?? this.imageUrls,
        sellerPhone: sellerPhone ?? this.sellerPhone,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        isLiked: isLiked ?? this.isLiked,
        isFeatured: isFeatured ?? this.isFeatured,
        isPinned: isPinned ?? this.isPinned,
        isVip: isVip ?? this.isVip,
        promotionExpiry: promotionExpiry ?? this.promotionExpiry,
        lastPaymentId: lastPaymentId ?? this.lastPaymentId,
        promotedAt: promotedAt ?? this.promotedAt,
        ownerId: ownerId ?? this.ownerId,
        status: status ?? this.status,
        isBlocked: isBlocked ?? this.isBlocked,
        reportCount: reportCount ?? this.reportCount,
        viewsCount: viewsCount ?? this.viewsCount,
        isUrgent: isUrgent ?? this.isUrgent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'year': year,
        'price': price,
        'mileage': mileage,
        'location': location,
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        'sellerPhone': sellerPhone,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'isLiked': isLiked,
        'isFeatured': isFeatured,
        'isPinned': isPinned,
        'isVip': isVip,
        'promotionExpiry': promotionExpiry?.toIso8601String(),
        'lastPaymentId': lastPaymentId,
        'promotedAt': promotedAt?.toIso8601String(),
        'ownerId': ownerId,
        'status': status,
        'isBlocked': isBlocked,
        'reportCount': reportCount,
        'viewsCount': viewsCount,
        'isUrgent': isUrgent,
      };

  factory Car.fromJson(Map<String, dynamic> json) {
    List<String> readList(dynamic v) {
      if (v is List) {
        return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).cast<String>().toList();
      }
      return const <String>[];
    }

    // Prefer new 'images' list; fall back to legacy 'imageUrls' or single 'imageUrl'
    final List<String> imgsPrimary = readList(json['images']);
    final List<String> imgsLegacy = readList(json['imageUrls']);
    final List<String> imgs = imgsPrimary.isNotEmpty ? imgsPrimary : imgsLegacy;

    return Car(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: (json['year'] as num).toInt(),
      price: (json['price'] as num).toInt(),
      mileage: (json['mileage'] as num).toInt(),
      location: json['location'] as String,
      imageUrl: (json['imageUrl'] as String?) ?? '',
      imageUrls: imgs.isNotEmpty
          ? imgs
          : [if ((json['imageUrl'] as String?)?.isNotEmpty == true) (json['imageUrl'] as String)],
      sellerPhone: (json['sellerPhone'] ?? json['phoneNumber'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isLiked: (json['isLiked'] as bool?) ?? false,
      isFeatured: (json['isFeatured'] as bool?) ?? false,
      isPinned: (json['isPinned'] as bool?) ?? false,
      isVip: (json['isVip'] as bool?) ?? false,
      promotionExpiry: DateTime.tryParse(json['promotionExpiry'] as String? ?? ''),
      lastPaymentId: json['lastPaymentId'] as String?,
      promotedAt: DateTime.tryParse(json['promotedAt'] as String? ?? ''),
      ownerId: (json['ownerId'] as String?) ?? (json['userId'] as String? ?? ''),
      status: (json['status'] as String?) ?? 'active',
      isBlocked: (json['isBlocked'] as bool?) ?? false,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      isUrgent: (json['isUrgent'] as bool?) ?? false,
    );
  }
}

// Global App State list holding all cars across the app
final List<Car> carsList = [];

class CarProvider extends ChangeNotifier {
  final CarService _service = CarService();
  bool _isLoading = true;
  
  // Removed default mock cache to enforce Firestore-only source

  // Filters
  String _locationFilter = 'All';
  int? _minPrice;
  int? _maxPrice;
  String _makeFilter = '';
  String _modelFilter = '';
  int? _minYear;
  int? _maxMileage;

  CarProvider() {
    _init();
  }

  bool get isLoading => _isLoading;
  // Firestore-only list (no local fallback). If empty, UI shows empty state.
  List<Car> get cars => List.unmodifiable(carsList);

  // Exposed filter values
  String get locationFilter => _locationFilter;
  int? get minPrice => _minPrice;
  int? get maxPrice => _maxPrice;
  String get makeFilter => _makeFilter;
  String get modelFilter => _modelFilter;
  int? get minYear => _minYear;
  int? get maxMileage => _maxMileage;

  // Helper: check if any promotion is active based on unified expiry
  bool _isPromoActive(Car c) {
    final exp = c.promotionExpiry;
    if (exp == null) return false;
    return exp.isAfter(DateTime.now());
  }

  // Cars after applying current filters, sorted by promotions
  List<Car> get filteredCars {
    Iterable<Car> list = cars;
    // Hide blocked and non-active listings from public feed
    list = list.where((c) => c.isBlocked == false && c.status == 'active');
    if (_locationFilter != 'All') {
      list = list.where((c) => c.location == _locationFilter);
    }
    if (_minPrice != null) {
      list = list.where((c) => c.price >= _minPrice!);
    }
    if (_maxPrice != null) {
      list = list.where((c) => c.price <= _maxPrice!);
    }
    if (_makeFilter.isNotEmpty) {
      final q = _makeFilter.toLowerCase();
      list = list.where((c) => c.make.toLowerCase().contains(q));
    }
    if (_modelFilter.isNotEmpty) {
      final q = _modelFilter.toLowerCase();
      list = list.where((c) => c.model.toLowerCase().contains(q));
    }
    if (_minYear != null) {
      list = list.where((c) => c.year >= _minYear!);
    }
    if (_maxMileage != null) {
      list = list.where((c) => c.mileage <= _maxMileage!);
    }
    final result = List<Car>.from(list);
    // Strict priority: VIP (0), Featured/Pinned (1), Urgent (2), Free (3)
    int groupPriority(Car c) {
      final active = _isPromoActive(c);
      final vip = active && c.isVip;
      final featuredOrPinned = active && (c.isFeatured || c.isPinned);
      final urgent = active && c.isUrgent;
      if (vip) return 0;
      if (featuredOrPinned) return 1;
      if (urgent) return 2;
      return 3;
    }
    result.sort((a, b) {
      final ga = groupPriority(a), gb = groupPriority(b);
      if (ga != gb) return ga.compareTo(gb);
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  // Favorites helpers
  Set<String> get favoriteIds => cars.where((c) => c.isLiked).map((c) => c.id).toSet();
  List<Car> get favoriteCars => cars.where((c) => c.isLiked).toList();
  bool isFavorite(String id) => cars.any((c) => c.id == id && c.isLiked);

  void setLocationFilter(String value) {
    _locationFilter = value;
    notifyListeners();
  }

  void setPriceRange({int? min, int? max}) {
    _minPrice = min;
    _maxPrice = max;
    notifyListeners();
  }

  void setMakeFilter(String value) {
    _makeFilter = value.trim();
    notifyListeners();
  }

  void setModelFilter(String value) {
    _modelFilter = value.trim();
    notifyListeners();
  }

  void setMinYear(int? year) {
    _minYear = year;
    notifyListeners();
  }

  void setMaxMileage(int? value) {
    _maxMileage = value;
    notifyListeners();
  }

  void clearFilters() {
    _locationFilter = 'All';
    _minPrice = null;
    _maxPrice = null;
    _makeFilter = '';
    _modelFilter = '';
    _minYear = null;
    _maxMileage = null;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      final loaded = await _service.loadCars();
      carsList
        ..clear()
        ..addAll(loaded);
    } catch (e) {
      debugPrint('CarProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String id) async {
    final carIndex = carsList.indexWhere((car) => car.id == id);
    if (carIndex != -1) {
      carsList[carIndex].isLiked = !carsList[carIndex].isLiked;
      notifyListeners();
      await _service.saveCars(cars);
    }
  }

  Future<void> applyPromotion({
    required String id,
    required String type, // 'featured' | 'pin' | 'vip'
    int days = 1,
  }) async {
    final idx = carsList.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final now = DateTime.now();
    int durationDays;
    bool isFeatured = carsList[idx].isFeatured;
    bool isPinned = carsList[idx].isPinned;
    bool isVip = carsList[idx].isVip;
    switch (type) {
      case 'featured':
        durationDays = 3;
        isFeatured = true;
        break;
      case 'pin':
        durationDays = 1; // fixed per package
        isPinned = true;
        break;
      case 'vip':
        durationDays = 7; // fixed per package
        isVip = true;
        break;
      default:
        durationDays = 1;
    }
    final updated = carsList[idx].copyWith(
      isFeatured: isFeatured,
      isPinned: isPinned,
      isVip: isVip,
      promotionExpiry: now.add(Duration(days: durationDays)),
    );
    carsList[idx] = updated;
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> setPromotionAfterPayment({
    required String id,
    required String type, // 'featured' | 'pin' | 'vip'
    required String paymentId,
    DateTime? paidAt,
  }) async {
    try {
      // Only persist to Firestore after verified payment
      final Map<String, dynamic> update = <String, dynamic>{
        'lastPaymentId': paymentId,
        'promotedAt': FieldValue.serverTimestamp(),
      };
      switch (type) {
        case 'featured':
          update['isFeatured'] = true;
          update['listingType'] = 'Featured listing';
          break;
        case 'pin':
          update['isPinned'] = true;
          update['listingType'] = 'Pinned listing';
          break;
        case 'vip':
          update['isVip'] = true;
          update['listingType'] = 'VIP listing';
          break;
        default:
          break;
      }
      await FirebaseFirestore.instance.collection('listings').doc(id).set(update, SetOptions(merge: true));
      debugPrint('Promotion updated in Firestore for $id: $update');
      // Optionally refresh local cache next time _init runs. We keep current in-memory as-is.
    } catch (e) {
      debugPrint('setPromotionAfterPayment Firestore error: $e');
    }
  }

  Future<void> addCar(Car car) async {
    carsList.insert(0, car); // append to global list at top
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> updateCar(String id, Car updated) async {
    final idx = carsList.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    carsList[idx] = updated;
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> deleteCar(String id) async {
    carsList.removeWhere((c) => c.id == id);
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> markSold(String id) async {
    final idx = carsList.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    carsList[idx] = carsList[idx].copyWith(status: 'sold');
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> setStatus(String id, String status) async {
    final idx = carsList.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    carsList[idx] = carsList[idx].copyWith(status: status);
    notifyListeners();
    await _service.saveCars(cars);
  }

  /// Apply a local upgrade package to a car listing
  /// package: featured | vip | urgent | topBoost
  Future<void> applyUpgrade({required String id, required String package}) async {
    final idx = carsList.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final now = DateTime.now();
    var car = carsList[idx];
    int days = 1;
    switch (package) {
      case 'featured':
        car = car.copyWith(isFeatured: true); days = 3; break;
      case 'vip':
        car = car.copyWith(isVip: true); days = 7; break;
      case 'urgent':
        car = car.copyWith(isUrgent: true); days = 3; break;
      case 'topBoost':
        car = car.copyWith(isPinned: true); days = 1; break;
      default:
        break;
    }
    car = car.copyWith(promotionExpiry: now.add(Duration(days: days)), promotedAt: now);
    carsList[idx] = car;
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> reportListing(String id) async {
    final idx = carsList.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final current = carsList[idx];
    final nextCount = current.reportCount + 1; // simple threshold
    final blocked = nextCount >= 3; // simple threshold
    carsList[idx] = current.copyWith(reportCount: nextCount, isBlocked: blocked);
    notifyListeners();
    await _service.saveCars(cars);
  }

  Future<void> incrementViews(String id) async {
    try {
      await FirebaseFirestore.instance.collection('listings').doc(id).set({'viewsCount': FieldValue.increment(1)}, SetOptions(merge: true));
      debugPrint('Incremented views for listing $id');
    } catch (e) {
      debugPrint('incrementViews Firestore error: $e');
    }
  }

  Car? byId(String id) {
    try {
      return carsList.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

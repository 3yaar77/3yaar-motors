import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/providers/plate_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/notification_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/utils/launch_utils.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:autoreel/services/payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Removed flutter_svg; using PNG logos for reliability
import 'package:autoreel/providers/listings_provider.dart';
import 'package:autoreel/providers/accessory_provider.dart';
import 'package:autoreel/widgets/accessory_grid_card.dart';
import 'package:autoreel/data/car_data.dart';
// Removed local in-memory listings fallback to enforce Firestore-only source
import 'package:autoreel/providers/messages_provider.dart';
import 'package:autoreel/widgets/uae_plate.dart';
import 'package:autoreel/widgets/real_uae_plate.dart';
import 'package:autoreel/utils/format_utils.dart';
import 'package:autoreel/utils/image_url_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum MarketplaceCategory { cars, plates, accessories }

class _HomePageState extends State<HomePage> {
  String _query = '';
  final List<String> _locations = const [
    'All',
    'Dubai',
    'Abu Dhabi',
    'Sharjah'
  ];
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();
  MarketplaceCategory _category = MarketplaceCategory.cars;
  final Set<String> _promoNotified = <String>{};
  // Stories removed as per latest spec — keep top section minimal.

  // Plate filters (HomePage, applied when category = plates)
  String? _plateFilterEmirate; // e.g., Dubai
  String? _plateFilterCode; // prefix/letter or number before space
  String? _plateFilterNumber; // numeric part
  int? _plateMinPrice;
  int? _plateMaxPrice;

  // Popular brands with Clearbit logos
  static const List<Map<String, String>> _popularBrandItems = [
    {'name': 'Toyota', 'logo': 'https://logo.clearbit.com/toyota.com'},
    {'name': 'Nissan', 'logo': 'https://logo.clearbit.com/nissan-global.com'},
    {'name': 'Lexus', 'logo': 'https://logo.clearbit.com/lexus.com'},
    {
      'name': 'Mercedes-Benz',
      'logo': 'https://logo.clearbit.com/mercedes-benz.com'
    },
    {'name': 'BMW', 'logo': 'https://logo.clearbit.com/bmw.com'},
    {'name': 'Audi', 'logo': 'https://logo.clearbit.com/audi.com'},
    {'name': 'Porsche', 'logo': 'https://logo.clearbit.com/porsche.com'},
    {'name': 'Land Rover', 'logo': 'https://logo.clearbit.com/landrover.com'},
    {'name': 'Tesla', 'logo': 'https://logo.clearbit.com/tesla.com'},
    {'name': 'Ferrari', 'logo': 'https://logo.clearbit.com/ferrari.com'},
    {'name': 'Ford', 'logo': 'https://logo.clearbit.com/ford.com'},
    {'name': 'Chevrolet', 'logo': 'https://logo.clearbit.com/chevrolet.com'},
    {'name': 'Hyundai', 'logo': 'https://logo.clearbit.com/hyundai.com'},
    {'name': 'Kia', 'logo': 'https://logo.clearbit.com/kia.com'},
    {'name': 'Honda', 'logo': 'https://logo.clearbit.com/honda.com'},
    {
      'name': 'Mitsubishi',
      'logo': 'https://logo.clearbit.com/mitsubishi-motors.com'
    },
    {'name': 'Mazda', 'logo': 'https://logo.clearbit.com/mazda.com'},
    {'name': 'BYD', 'logo': 'https://logo.clearbit.com/byd.com'},
    {'name': 'Changan', 'logo': 'https://logo.clearbit.com/changan.com.cn'},
    {'name': 'Geely', 'logo': 'https://logo.clearbit.com/geely.com'},
    {'name': 'MG', 'logo': 'https://logo.clearbit.com/mgmotor.eu'},
    {'name': 'GAC', 'logo': 'https://logo.clearbit.com/gac-motor.com'},
    {'name': 'Chery', 'logo': 'https://logo.clearbit.com/cheryglobal.com'},
    {'name': 'Jetour', 'logo': 'https://logo.clearbit.com/jetour.com'},
    {'name': 'Haval', 'logo': 'https://logo.clearbit.com/haval.com'},
  ];

  String _normalizeMake(String name) {
    if (name == 'Mercedes') return 'Mercedes-Benz';
    if (name == 'Land Rover')
      return 'Land Rover'; // some datasets use 'Range Rover'; results page uses contains()
    return name;
  }

  // Removed demo/sample listings method to ensure Firestore-only data source

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Precompute values to avoid using Builder widgets
    final isAdmin = context.select<AuthProvider, bool>((p) => p.isAdmin);
    final notifCount =
        context.select<NotificationProvider, int>((p) => p.unreadCount);
    final msgUnread =
        context.select<MessagesProvider, int>((p) => p.unreadCount);
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        child: Container(
          height: 70,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Home (left)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(AppRoutes.home),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.home,
                          color: MarketplaceColors.accentYellow, size: 26),
                    ),
                  ),
                  // Favorites
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final loggedIn = context.read<AuthProvider>().isLoggedIn;
                      if (!loggedIn) {
                        context.pushNamed('login',
                            queryParameters: {'redirect': AppRoutes.favorites});
                      } else {
                        context.pushNamed('favorites');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.favorite_border,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  // Reserve space under the center button so icons don't sit beneath it
                  const SizedBox(width: 56),
                  // Messages
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final loggedIn = context.read<AuthProvider>().isLoggedIn;
                      if (!loggedIn) {
                        context.pushNamed('login',
                            queryParameters: {'redirect': AppRoutes.messages});
                      } else {
                        context.pushNamed('messages');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              color: Colors.white, size: 24),
                          if (msgUnread > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Reels
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.pushNamed('reels'),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
              // Perfectly centered + button (no vertical offset)
              Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => _showAddSheet(context),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: MarketplaceColors.accentYellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer<CarProvider>(
        builder: (context, carProvider, child) {
          final plateProvider = context.watch<PlateProvider>();
          if (carProvider.isLoading || plateProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Apply provider filters first, then optional text search
          final baseCars = carProvider.filteredCars;
          List<Car> carList = List<Car>.from(baseCars);
          // Notify on promo expiry once per session
          final np = context.read<NotificationProvider>();
          for (final c in context.read<CarProvider>().cars) {
            final exp = c.promotionExpiry;
            final activeAny = c.isVip || c.isFeatured || c.isPinned;
            if (activeAny &&
                exp != null &&
                exp.isBefore(DateTime.now()) &&
                !_promoNotified.contains(c.id)) {
              _promoNotified.add(c.id);
              debugPrint('Promotion expired for ${c.make} ${c.model}');
            }
          }
          final q = (_query).toString().trim().toLowerCase();
          if (_category == MarketplaceCategory.cars) {
            if (q.isNotEmpty) {
              carList = carList
                  .where((c) => ('${c.make} ${c.model} ${c.location}')
                      .toLowerCase()
                      .contains(q))
                  .toList();
            }
          }

          final platesRaw = plateProvider.plates;
          List<Plate> plates = List<Plate>.from(platesRaw);
          if (_category == MarketplaceCategory.plates) {
            if ((_plateFilterEmirate ?? '').isNotEmpty &&
                (_plateFilterEmirate ?? '') != 'All') {
              plates = plates
                  .where((p) =>
                      p.emirate.toLowerCase() ==
                      _plateFilterEmirate!.toLowerCase())
                  .toList();
            }
            if ((_plateFilterCode ?? '').isNotEmpty) {
              final code = _plateFilterCode!.trim().toLowerCase();
              plates = plates
                  .where((p) => p.plateNumber.toLowerCase().startsWith(code))
                  .toList();
            }
            if ((_plateFilterNumber ?? '').isNotEmpty) {
              final numTxt = _plateFilterNumber!.trim().toLowerCase();
              plates = plates
                  .where((p) => p.plateNumber.toLowerCase().contains(numTxt))
                  .toList();
            }
            if (_plateMinPrice != null) {
              plates = plates.where((p) => p.price >= _plateMinPrice!).toList();
            }
            if (_plateMaxPrice != null) {
              plates = plates.where((p) => p.price <= _plateMaxPrice!).toList();
            }
            // Sort by priority: VIP → Featured/Pinned → Urgent → Free; newest-first in each
            int _platePriority(Plate p) {
              final bool active = p.promotionExpiry != null &&
                  p.promotionExpiry!.isAfter(DateTime.now());
              final bool vip = active && p.isVip;
              final bool featOrPinned = active && (p.isFeatured || p.isPinned);
              final bool urgent = active && p.isUrgent;
              if (vip) return 0;
              if (featOrPinned) return 1;
              if (urgent) return 2;
              return 3;
            }

            plates.sort((a, b) {
              final pa = _platePriority(a), pb = _platePriority(b);
              if (pa != pb) return pa.compareTo(pb);
              return b.createdAt.compareTo(a.createdAt);
            });
          }

          // Firestore-backed listings only (no local/demo fallbacks)
          final lp = context.watch<ListingsProvider>();
          final dynamicListings = lp.toMapList();
          // Consolidated diagnostics: log the full list once (exact message required)
          try {
            debugPrint(
                'Loaded Firestore listings: ' + jsonEncode(dynamicListings));
            // Additional log to match requested format
            debugPrint('Listings: ' + jsonEncode(dynamicListings));
          } catch (_) {}

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MarketplaceColors.luxBgGradientStart,
                  MarketplaceColors.luxBgGradientEnd
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          // Header with actions
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Welcome!',
                                            style: context
                                                .textStyles.headlineLarge
                                                ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text('Choose your next car',
                                            style: context
                                                .textStyles.titleMedium
                                                ?.copyWith(
                                                    color: Colors.white70)),
                                      ]),
                                ),
                                const SizedBox(width: 12),
                                _CircleIcon(
                                  icon: Icons.notifications_none,
                                  onTap: () =>
                                      context.pushNamed('notifications'),
                                  showDot: notifCount > 0,
                                ),
                                const SizedBox(width: 10),
                                _ProfileIconButton(
                                    onTap: () => context.pushNamed('profile')),
                              ]),
                          const SizedBox(height: 18),
                          // Search card (keep current design)
                          _SearchCard(
                            initialCategory: _category,
                            onSearch: (
                                {required String make,
                                required String model,
                                required MarketplaceCategory category,
                                String? plateEmirate,
                                String? plateCode,
                                String? plateNumber}) {
                              setState(() {
                                _category = category;
                                _query = '';
                                if (category == MarketplaceCategory.plates) {
                                  _plateFilterEmirate = plateEmirate;
                                  _plateFilterCode = plateCode;
                                  _plateFilterNumber = plateNumber;
                                }
                              });
                              if (category == MarketplaceCategory.cars) {
                                context.read<CarProvider>().setMakeFilter(make);
                                context
                                    .read<CarProvider>()
                                    .setModelFilter(model);
                              }
                            },
                            onMoreOptions: (cat) =>
                                _showFilterSheet(context, cat),
                          ),
                          const SizedBox(height: 14),
                          // Popular Brands (compact, minimal)
                          Row(children: [
                            Expanded(
                              child: Text('Popular Brands',
                                  style: context.textStyles.titleLarge
                                      ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.pushNamed('all_brands'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text('See All',
                                    style: context.textStyles.labelLarge
                                        ?.copyWith(
                                            color:
                                                MarketplaceColors.accentYellow,
                                            fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 82,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _popularBrandItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final it = _popularBrandItems[index];
                                return _BrandLogoCircle(
                                  label: it['name']!,
                                  selected: false,
                                  onTap: () => context.pushNamed(
                                    'brand_results',
                                    queryParameters: {'brand': it['name']!},
                                  ),
                                  size: 56,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Hero title section
                          Text('Best Place to Find Cars and Plates in UAE',
                              style: context.textStyles.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2)),
                          const SizedBox(height: 6),
                          Text('Buy, sell, and discover premium listings',
                              style: context.textStyles.titleMedium
                                  ?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          // Cars / Plates segmented control (58px, rounded pill)
                          Container(
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                  color: MarketplaceColors.luxOuterBorder,
                                  width: 1),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(32),
                                  onTap: () => setState(() =>
                                      _category = MarketplaceCategory.cars),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: _category ==
                                                MarketplaceCategory.cars
                                            ? MarketplaceColors.accentYellow
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      color: _category ==
                                              MarketplaceCategory.cars
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.directions_car,
                                                color: _category ==
                                                        MarketplaceCategory.cars
                                                    ? MarketplaceColors
                                                        .accentYellow
                                                    : Colors.white70,
                                                size: 22),
                                            const SizedBox(width: 8),
                                            Text('Cars',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                        color: _category ==
                                                                MarketplaceCategory
                                                                    .cars
                                                            ? MarketplaceColors
                                                                .accentYellow
                                                            : Colors.white70,
                                                        fontWeight:
                                                            FontWeight.w800)),
                                          ]),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(32),
                                  onTap: () => setState(() =>
                                      _category = MarketplaceCategory.plates),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: _category ==
                                                MarketplaceCategory.plates
                                            ? MarketplaceColors.accentYellow
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      color: _category ==
                                              MarketplaceCategory.plates
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.confirmation_number,
                                                color: _category ==
                                                        MarketplaceCategory
                                                            .plates
                                                    ? MarketplaceColors
                                                        .accentYellow
                                                    : Colors.white70,
                                                size: 22),
                                            const SizedBox(width: 8),
                                            Text('Plates',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                        color: _category ==
                                                                MarketplaceCategory
                                                                    .plates
                                                            ? MarketplaceColors
                                                                .accentYellow
                                                            : Colors.white70,
                                                        fontWeight:
                                                            FontWeight.w800)),
                                          ]),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(32),
                                  onTap: () => setState(() => _category = MarketplaceCategory.accessories),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: _category == MarketplaceCategory.accessories
                                            ? MarketplaceColors.accentYellow
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      color: _category == MarketplaceCategory.accessories
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.build_outlined,
                                            color: _category == MarketplaceCategory.accessories
                                                ? MarketplaceColors.accentYellow
                                                : Colors.white70,
                                            size: 22),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Accessories',
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                    color: _category == MarketplaceCategory.accessories
                                                        ? MarketplaceColors.accentYellow
                                                        : Colors.white70,
                                                    fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 18),
                          // Section title
                          Row(children: [
                            Text('Featured Listings',
                                style: context.textStyles.headlineMedium
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                            const SizedBox(width: 12),
                            Text('Listings count: ${lp.listings.length}',
                                style: context.textStyles.labelSmall
                                    ?.copyWith(color: Colors.white70)),
                          ]),
                        ]),
                  ),
                ),
                if (_category == MarketplaceCategory.cars) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: Builder(builder: (context) {
                      // Show dynamic car items first if exist; otherwise use provider cars list
                      final makeFilter = context
                          .read<CarProvider>()
                          .makeFilter
                          .trim()
                          .toLowerCase();
                      final modelFilter = context
                          .read<CarProvider>()
                          .modelFilter
                          .trim()
                          .toLowerCase();
                      final dynamicCarItems = dynamicListings
                          .where((e) => (e['type'] ?? '') == 'car')
                          .where((e) {
                        final mk = (e['make'] ?? '').toString().toLowerCase();
                        final md = (e['model'] ?? '').toString().toLowerCase();
                        if (makeFilter.isNotEmpty && !mk.contains(makeFilter))
                          return false;
                        if (modelFilter.isNotEmpty && !md.contains(modelFilter))
                          return false;
                        return true;
                      }).toList();
                      if (dynamicCarItems.isNotEmpty) {
                        // Sort by priority: VIP → Featured/Pinned → Urgent → Free; newest-first in each
                        int _priorityOf(Map<String, dynamic> it) {
                          final bool vip = (it['isVip'] ?? false) == true;
                          final bool featured =
                              (it['isFeatured'] ?? false) == true;
                          final bool pinned = (it['isPinned'] ?? false) == true;
                          final bool urgent = (it['isUrgent'] ?? false) == true;
                          // Fallback from listingType string if booleans absent
                          final String lt =
                              (it['listingType'] ?? it['listing_type'] ?? '')
                                  .toString()
                                  .toLowerCase();
                          final bool ltVip = lt.contains('vip');
                          final bool ltFeatured = lt.contains('featured');
                          final bool ltUrgent = lt.contains('urgent');
                          if (vip || ltVip) return 0;
                          if (featured || pinned || ltFeatured) return 1;
                          if (urgent || ltUrgent) return 2;
                          return 3;
                        }

                        DateTime _createdAtOf(Map<String, dynamic> it) {
                          final t = it['time'];
                          if (t is DateTime) return t;
                          final c = it['createdAt'];
                          if (c is String)
                            return DateTime.tryParse(c) ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                          return DateTime.fromMillisecondsSinceEpoch(0);
                        }

                        dynamicCarItems.sort((a, b) {
                          final pa = _priorityOf(a), pb = _priorityOf(b);
                          if (pa != pb) return pa.compareTo(pb);
                          return _createdAtOf(b).compareTo(_createdAtOf(a));
                        });
                        return SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 250,
                          ),
                          itemCount: dynamicCarItems.length,
                          itemBuilder: (context, index) =>
                              CarMapFeaturedGridCard(
                                  item: dynamicCarItems[index]),
                        );
                      }
                      // No fallback to local/cached/demo data — keep grid structure with zero items
                      return SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 250,
                        ),
                        itemCount: 0,
                        itemBuilder: (context, index) =>
                            const SizedBox.shrink(),
                      );
                    }),
                  ),
                ] else if (_category == MarketplaceCategory.plates) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: plates.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                  child: Text('No plates yet',
                                      style: TextStyle(color: Colors.white70))),
                            ),
                          )
                        : SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent:
                                  240, // taller to fit plate + price/stats + actions
                            ),
                            itemCount: plates.length,
                            itemBuilder: (context, index) {
                              final p = plates[index];
                              return PlateListCard(plate: p);
                            },
                          ),
                  ),
                ] else ...[
                  // Accessories: filters + grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: 'All',
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All categories')),
                              DropdownMenuItem(value: 'Wheels & Tires', child: Text('Wheels & Tires')),
                              DropdownMenuItem(value: 'Screens & Audio', child: Text('Screens & Audio')),
                              DropdownMenuItem(value: 'Lights', child: Text('Lights')),
                              DropdownMenuItem(value: 'Interior Parts', child: Text('Interior Parts')),
                              DropdownMenuItem(value: 'Exterior Parts', child: Text('Exterior Parts')),
                              DropdownMenuItem(value: 'Cleaning & Care', child: Text('Cleaning & Care')),
                              DropdownMenuItem(value: 'Performance Parts', child: Text('Performance Parts')),
                              DropdownMenuItem(value: 'Accessories', child: Text('Accessories')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (v) => context.read<AccessoryProvider>().setCategoryFilter(v),
                            decoration: InputDecoration(
                              labelText: 'Category',
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                              labelStyle: const TextStyle(color: Colors.white70),
                            ),
                            dropdownColor: MarketplaceColors.luxItemCard,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: 'All',
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All conditions')),
                              DropdownMenuItem(value: 'New', child: Text('New')),
                              DropdownMenuItem(value: 'Used', child: Text('Used')),
                            ],
                            onChanged: (v) => context.read<AccessoryProvider>().setConditionFilter(v),
                            decoration: InputDecoration(
                              labelText: 'Condition',
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                              labelStyle: const TextStyle(color: Colors.white70),
                            ),
                            dropdownColor: MarketplaceColors.luxItemCard,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: Builder(builder: (context) {
                      final items = context.watch<AccessoryProvider>().items;
                      if (items.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Text('No accessories yet', style: TextStyle(color: Colors.white70))),
                          ),
                        );
                      }
                      return SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 250,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => AccessoryGridCard(accessory: items[index]),
                      );
                    }),
                  ),
                ],
                // Bottom spacer so nav doesn't cover content (requested 170)
                // Removed per request: nav must sit exactly at bottom edge with no extra spacing
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, MarketplaceCategory category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _FilterSheetContent(
        category: category,
        currentQuery: _query,
        onQuickSelect: (m) {
          setState(() => _query = m);
        },
        onApply: (filters) {
          if (category == MarketplaceCategory.cars) {
            final carP = context.read<CarProvider>();
            carP.setMakeFilter(filters['make'] as String? ?? '');
            carP.setModelFilter(filters['model'] as String? ?? '');
            carP.setMinYear(filters['minYear'] as int?);
            carP.setMaxMileage(filters['maxMileage'] as int?);
          } else {
            setState(() {
              _plateFilterEmirate = (filters['emirate'] as String?)?.trim();
              _plateFilterCode = (filters['plateCode'] as String?)?.trim();
              _plateFilterNumber = (filters['plateNumber'] as String?)?.trim();
              _plateMinPrice = filters['minPrice'] as int?;
              _plateMaxPrice = filters['maxPrice'] as int?;
            });
          }
          Navigator.of(context).pop();
        },
        onClear: () {
          setState(() {
            _query = '';
            _minPriceCtrl.clear();
            _maxPriceCtrl.clear();
            _plateFilterEmirate = null;
            _plateFilterCode = null;
            _plateFilterNumber = null;
            _plateMinPrice = null;
            _plateMaxPrice = null;
          });
          if (category == MarketplaceCategory.cars) {
            context.read<CarProvider>().clearFilters();
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) {
        final loggedIn = context.read<AuthProvider>().isLoggedIn;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.directions_car,
                    color: MarketplaceColors.accentYellow),
                title: const Text('Add car listing'),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.white70),
                onTap: () {
                  context.pop();
                  if (!loggedIn) {
                    context.pushNamed('login',
                        queryParameters: {'redirect': AppRoutes.newListing});
                  } else {
                    context.pushNamed('new_listing');
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined,
                    color: MarketplaceColors.accentYellow),
                title: const Text('Add plate number'),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.white70),
                onTap: () {
                  context.pop();
                  if (!loggedIn) {
                    context.pushNamed('login',
                        queryParameters: {'redirect': AppRoutes.platePage});
                  } else {
                    context.pushNamed('plate_page');
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.build_outlined,
                    color: MarketplaceColors.accentYellow),
                title: const Text('Add accessory listing'),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.white70),
                onTap: () {
                  context.pop();
                  if (!loggedIn) {
                    context.pushNamed('login',
                        queryParameters: {'redirect': AppRoutes.newAccessory});
                  } else {
                    context.pushNamed('new_accessory');
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.play_circle_outline,
                    color: MarketplaceColors.accentYellow),
                title: const Text('Add reel video'),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.white70),
                onTap: () {
                  context.pop();
                  if (!loggedIn) {
                    context.pushNamed('login',
                        queryParameters: {'redirect': AppRoutes.uploadReel});
                  } else {
                    context.pushNamed('upload_reel');
                  }
                },
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
  }
}

class _FilterSheetContent extends StatefulWidget {
  final MarketplaceCategory category;
  final String currentQuery;
  final void Function(String) onQuickSelect;
  final void Function(Map<String, dynamic> filters) onApply;
  final VoidCallback onClear;
  const _FilterSheetContent(
      {required this.category,
      required this.currentQuery,
      required this.onQuickSelect,
      required this.onApply,
      required this.onClear});

  @override
  State<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  // Car filters controllers
  late final TextEditingController makeCtrl;
  late final TextEditingController modelCtrl;
  late final TextEditingController minYearCtrl;
  late final TextEditingController maxMileageCtrl;
  // Plate filters controllers
  final TextEditingController plateCodeCtrl = TextEditingController();
  final TextEditingController plateNumberCtrl = TextEditingController();
  final TextEditingController minPriceCtrl = TextEditingController();
  final TextEditingController maxPriceCtrl = TextEditingController();
  String? _emirate;

  @override
  void initState() {
    super.initState();
    final p = context.read<CarProvider>();
    makeCtrl = TextEditingController(text: p.makeFilter);
    modelCtrl = TextEditingController(text: p.modelFilter);
    minYearCtrl = TextEditingController(text: p.minYear?.toString() ?? '');
    maxMileageCtrl =
        TextEditingController(text: p.maxMileage?.toString() ?? '');
  }

  @override
  void dispose() {
    makeCtrl.dispose();
    modelCtrl.dispose();
    minYearCtrl.dispose();
    maxMileageCtrl.dispose();
    plateCodeCtrl.dispose();
    plateNumberCtrl.dispose();
    minPriceCtrl.dispose();
    maxPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCars = widget.category == MarketplaceCategory.cars;
    final emirates = const [
      'Any',
      'Dubai',
      'Abu Dhabi',
      'Sharjah',
      'Ajman',
      'Ras Al Khaimah',
      'Umm Al Quwain',
      'Fujairah'
    ];

    return Padding(
      padding: AppSpacing.paddingLg,
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.lg),
              if (isCars) ...[
                Text('Quick Filters',
                    style: context.textStyles.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Mercedes-Benz',
                    'Porsche',
                    'Lamborghini',
                    'Range Rover',
                    'Ferrari'
                  ]
                      .map((m) => ChoiceChip(
                            label: Text(m),
                            selected: widget.currentQuery.toLowerCase() ==
                                m.toLowerCase(),
                            onSelected: (_) {
                              widget.onQuickSelect(m);
                              Navigator.of(context).pop();
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text('Advanced Filters',
                  style: context.textStyles.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              if (isCars) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: makeCtrl,
                      decoration: InputDecoration(
                          labelText: 'Make',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none)),
                      onChanged: (v) =>
                          context.read<CarProvider>().setMakeFilter(v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: modelCtrl,
                      decoration: InputDecoration(
                          labelText: 'Model',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none)),
                      onChanged: (v) =>
                          context.read<CarProvider>().setModelFilter(v),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: minYearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Min Year',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none)),
                      onChanged: (v) => context
                          .read<CarProvider>()
                          .setMinYear(int.tryParse(v)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: maxMileageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Max Mileage',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none)),
                      onChanged: (v) => context
                          .read<CarProvider>()
                          .setMaxMileage(int.tryParse(v)),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply({
                        'make': makeCtrl.text.trim(),
                        'model': modelCtrl.text.trim(),
                        'minYear': int.tryParse(minYearCtrl.text.trim()),
                        'maxMileage': int.tryParse(maxMileageCtrl.text.trim()),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: MarketplaceColors.accentYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg))),
                    child: const Text('Apply filters'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onClear,
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg))),
                    child: const Text('Clear filters'),
                  ),
                ),
              ] else ...[
                // Plates filters
                DropdownButtonFormField<String>(
                  value: _emirate ?? 'Any',
                  items: emirates
                      .map((e) =>
                          DropdownMenuItem<String>(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _emirate = (v == 'Any') ? null : v),
                  decoration: InputDecoration(
                    labelText: 'Emirate',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none),
                  ),
                  dropdownColor: MarketplaceColors.luxItemCard,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: plateCodeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Plate code',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: plateNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Plate number',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Min Price (AED)',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: maxPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Max Price (AED)',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply({
                        'emirate': _emirate,
                        'plateCode': plateCodeCtrl.text.trim(),
                        'plateNumber': plateNumberCtrl.text.trim(),
                        'minPrice': int.tryParse(minPriceCtrl.text.trim()),
                        'maxPrice': int.tryParse(maxPriceCtrl.text.trim()),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: MarketplaceColors.accentYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg))),
                    child: const Text('Apply filters'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onClear,
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg))),
                    child: const Text('Clear filters'),
                  ),
                ),
              ],
            ]),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;
  const _CircleIcon(
      {required this.icon, required this.onTap, this.showDot = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: MarketplaceColors.luxCard,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6)),
                ]),
            child: Icon(icon, color: Colors.white),
          ),
          if (showDot)
            Positioned(
                right: 2,
                top: 2,
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle))),
        ]),
      );
}

// Profile icon that mirrors ProfilePage avatar source (from SharedPreferences per-user)
class _ProfileIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        context.select<AuthProvider, String?>((p) => p.currentUser?.photoUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MarketplaceColors.luxCard,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: (photoUrl != null && photoUrl.isNotEmpty)
            ? Image.network(
                ImageUrlUtils.sanitize(photoUrl),
                key: ValueKey(photoUrl),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person_outline, color: Colors.white),
              )
            : const Icon(Icons.person_outline, color: Colors.white),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(children: [
            Icon(icon, color: color, size: 24),
            if (badge > 0)
              Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle))),
          ]),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _BrandLogoCircle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double size; // circle diameter
  const _BrandLogoCircle(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.size = 64});

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? MarketplaceColors.accentYellow : MarketplaceColors.luxBorder;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 6))
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 18,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          circle,
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SegmentTab(
      {required this.selected,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected
                    ? MarketplaceColors.accentYellow
                    : MarketplaceColors.luxBorder,
                width: selected ? 2 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                color:
                    selected ? MarketplaceColors.accentYellow : Colors.white70,
                size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: selected
                        ? MarketplaceColors.accentYellow
                        : Colors.white70,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class CarGridCard extends StatelessWidget {
  final Car car;
  const CarGridCard({super.key, required this.car});

  String _formatPrice(int price) {
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  String _formatMileage(int mileage) {
    final s = mileage.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        try {
          context.read<CarProvider>().incrementViews(car.id);
        } catch (_) {}
        context.pushNamed('car_details',
            pathParameters: {'id': car.id}, extra: car);
      },
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 10))
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        height: 220,
        child: Stack(children: [
          // Background image (full-bleed)
          Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _CarImageThumb(
                    url: (car.images.isNotEmpty ? car.images.first : ''), align: Alignment.centerRight),
              ),
          ),
          // Diagonal gradient overlay for readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Text content bottom-left
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 84, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top spacer to push content towards bottom without hardcoding
              const Spacer(),
              Text(car.make,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelLarge?.copyWith(
                      color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(car.model,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      height: 1.15)),
              const SizedBox(height: 6),
              Text(_formatPrice(car.price),
                  maxLines: 1,
                  style: context.textStyles.headlineMedium?.copyWith(
                      color: MarketplaceColors.accentYellow,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(car.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.labelSmall
                            ?.copyWith(color: Colors.white70))),
                const SizedBox(width: 10),
                const Icon(Icons.speed, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(_formatMileage(car.mileage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.labelSmall
                        ?.copyWith(color: Colors.white70)),
              ]),
            ]),
          ),
          // Top-left promo badges
          Positioned(left: 12, top: 12, child: _PromoBadges(car: car)),
          // Top-right heart
          Positioned(
            right: 12,
            top: 12,
            child: GestureDetector(
              onTap: () {
                final loggedIn = context.read<AuthProvider>().isLoggedIn;
                if (!loggedIn) {
                  context.pushNamed('login',
                      queryParameters: {'redirect': AppRoutes.home});
                  return;
                }
                context.read<CarProvider>().toggleLike(car.id);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999)),
                child: Icon(
                    car.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: car.isLiked ? Colors.red : Colors.white,
                    size: 18),
              ),
            ),
          ),
          // Bottom-right circular yellow arrow button
          Positioned(
            right: 18,
            bottom: 18,
            child: GestureDetector(
              onTap: () {
                try {
                  context.read<CarProvider>().incrementViews(car.id);
                } catch (_) {}
                context.pushNamed('car_details',
                    pathParameters: {'id': car.id}, extra: car);
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: MarketplaceColors.accentYellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ]),
                child: const Icon(Icons.arrow_outward, color: Colors.black),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CarImageThumb extends StatelessWidget {
  final String url;
  final Alignment align;
  const _CarImageThumb({required this.url, this.align = Alignment.centerRight});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.black.withValues(alpha: 0.2),
    );
    final u = ImageUrlUtils.sanitize(url);
    if (ImageUrlUtils.isValidFirebaseDownload(u)) {
      return Image.network(
        u,
        key: ValueKey(u),
        fit: BoxFit.cover,
        alignment: align,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) => child,
        errorBuilder: (_, err, ___) {
          debugPrint('IMAGE LOAD ERROR: $u | $err');
          return Container(color: Colors.black.withValues(alpha: 0.2));
        },
      );
    }
    // Non-Firebase https sources are not displayed in cards
    return placeholder;
  }
}

class _PromoBadges extends StatelessWidget {
  final Car car;
  const _PromoBadges({required this.car});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final active =
        car.promotionExpiry != null && car.promotionExpiry!.isAfter(now);
    final isVip = car.isVip && active;
    final isFeatured = car.isFeatured && active;
    final isPinned = car.isPinned && active;
    if (!isVip && !isFeatured && !isPinned) return const SizedBox.shrink();
    List<Widget> chips = [];
    if (isVip) {
      chips.add(
          _Badge(label: 'VIP 👑', bg: MarketplaceColors.vip, fg: Colors.black));
    }
    if (isFeatured) {
      chips.add(_Badge(
          label: 'Featured ⭐',
          bg: MarketplaceColors.featured,
          fg: Colors.white));
    }
    if (isPinned) {
      chips.add(_Badge(
          label: 'Pinned 📌', bg: MarketplaceColors.pinned, fg: Colors.white));
    }
    return Row(children: [
      for (int i = 0; i < chips.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        chips[i],
      ]
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
      );
}

class UpgradeListingSheet extends StatefulWidget {
  final Car car;
  const UpgradeListingSheet({super.key, required this.car});

  @override
  State<UpgradeListingSheet> createState() => _UpgradeListingSheetState();
}

class _UpgradeListingSheetState extends State<UpgradeListingSheet> {
  String _selected = 'featured'; // 'featured' | 'pin' | 'vip'
  bool _processing = false;

  Future<void> _beginCheckout() async {
    setState(() => _processing = true);
    try {
      final plan = _selected == 'featured'
          ? 'featured'
          : _selected == 'vip'
              ? 'vip'
              : 'urgent';
      final ok = await context.pushNamed('payment', queryParameters: {
        'id': widget.car.id,
        'type': 'car',
        'pkg': plan,
      });
      if (!mounted) return;
      if (ok == true) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upgrade activated after payment.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment not completed. Upgrade not applied.')));
      }
    } catch (e) {
      debugPrint('Payment start error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start payment.')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: MediaQuery.of(context)
          .viewInsets
          .add(const EdgeInsets.fromLTRB(20, 16, 20, 20)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Upgrade Listing',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            RadioListTile<String>(
              value: 'featured',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? 'featured'),
              title: const Text('Featured (AED 15 / 3 days)'),
              subtitle:
                  const Text('Boost visibility. Shown prominently for 3 days.'),
            ),
            RadioListTile<String>(
              value: 'pin',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? 'pin'),
              title: const Text('Pin (AED 5 / 1 day)'),
              subtitle: const Text('Keep your listing at the top for 1 day.'),
            ),
            RadioListTile<String>(
              value: 'vip',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? 'vip'),
              title: const Text('VIP (AED 50 / 7 days)'),
              subtitle:
                  const Text('Maximum prominence with VIP badge for a week.'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Secure payments require backend setup. In Dreamflow, open the Firebase panel (left sidebar) and complete setup. I will then enable real Stripe Checkout and Firestore updates.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _beginCheckout,
                icon: _processing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payment, color: Colors.white),
                label: Text(_processing ? 'Processing...' : 'Pay with Stripe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                ).copyWith(splashFactory: NoSplash.splashFactory),
              ),
            ),
          ]),
    );
  }
}

class PlateListCard extends StatelessWidget {
  final Plate plate;
  const PlateListCard({super.key, required this.plate});

  String _formatPrice(int price) {
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usesRed =
        plate.isUrgent || plate.listingType.toLowerCase().contains('urgent');
    final bool isVip = plate.isVip &&
        (plate.promotionExpiry == null ||
            plate.promotionExpiry!.isAfter(DateTime.now()));

    return GestureDetector(
      onTap: () {
        try {
          context.read<PlateProvider>().incrementViews(plate.id);
        } catch (_) {}
        context.push('/plate/${plate.id}', extra: plate);
      },
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: MarketplaceColors.plateCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: MarketplaceColors.upgradeGold.withValues(alpha: 0.45),
              width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 8)),
            if (isVip)
              BoxShadow(
                  color: MarketplaceColors.upgradeGold.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(children: [
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 32, 10, 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Plate visual (top) — use realistic plate component
                  RealUaePlate(
                    emirate: plate.emirate,
                    plateNumber: plate.plateNumber,
                    height: 62,
                  ),
                  const SizedBox(height: 10),
                  // Price (gold/red) + views
                  Row(children: [
                    Expanded(
                      child: Text(
                        plate.price > 0
                            ? _formatPrice(plate.price)
                            : 'Call for price',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: usesRed
                                  ? MarketplaceColors.platePriceRed
                                  : MarketplaceColors.upgradeGold,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(children: [
                      const Icon(Icons.remove_red_eye,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(formatCompactCount(plate.viewsCount),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white70)),
                    ]),
                  ]),
                  const Spacer(),
                  // Bottom actions: Call (left) + Message (center) + WhatsApp (right)
                  Row(children: [
                    // Call
                    Expanded(
                      child: GestureDetector(
                        onTap: () => openPhoneCall(plate.sellerPhone),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: const Center(
                              child: Icon(Icons.call,
                                  color: Colors.white, size: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Message (center) → messages page (no backend changes)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final loggedIn =
                              context.read<AuthProvider>().isLoggedIn;
                          if (!loggedIn) {
                            context.pushNamed('login', queryParameters: {
                              'redirect': '/plate/${plate.id}'
                            });
                          } else {
                            context.pushNamed('messages');
                          }
                        },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: const Center(
                              child: Icon(Icons.chat_bubble_outline,
                                  color: Colors.white, size: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // WhatsApp (right) – green with WhatsApp glyph
                    Expanded(
                      child: GestureDetector(
                        onTap: () => openWhatsAppWaMe(plate.sellerPhone,
                            message:
                                'Hi, I am interested in your plate ${plate.plateNumber}'),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: const Center(
                              child: WhatsAppLogoIcon(
                                  size: 18, color: Colors.white)),
                        ),
                      ),
                    ),
                  ]),
                ]),
          ),

          // Top-left: VIP / Featured / Urgent badge
          if (plate.isVip || plate.isFeatured || plate.isUrgent)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: plate.isVip
                      ? MarketplaceColors.upgradeGold
                      : plate.isFeatured
                          ? MarketplaceColors.featured
                          : MarketplaceColors.urgent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plate.isVip
                      ? 'VIP'
                      : plate.isFeatured
                          ? 'Featured'
                          : 'Urgent',
                  style: TextStyle(
                    color: plate.isVip ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

          // Top-right: Heart (small circle)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => context.read<PlateProvider>().toggleLike(plate.id),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10))),
                child: Icon(
                    plate.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: plate.isLiked ? Colors.red : Colors.white,
                    size: 16),
              ),
            ),
          ),

          // Bottom-right floating WhatsApp removed to avoid overlap; action consolidated in row above.
        ]),
      ),
    );
  }
}

class _MiniCircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniCircleIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      );
}

class ListingCard extends StatelessWidget {
  final Listing listing;
  const ListingCard({super.key, required this.listing});

  String _formatPrice(int? price) {
    if (price == null) return 'AED —';
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  String _formatMileage(int? mileage) {
    if (mileage == null) return '— km';
    final s = mileage.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = listing.type == 'photo' && listing.images.isNotEmpty;
    final imageUrl = hasPhoto ? listing.images.first : '';
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: MarketplaceColors.luxItemCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 8))
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Image section with small bottom gradient
        SizedBox(
          height: 130,
          child: Stack(children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                child: hasPhoto
                    ? _CarImageThumb(url: imageUrl, align: Alignment.center)
                    : Container(
                        decoration: const BoxDecoration(color: Colors.black12),
                        child: const Center(
                            child: Icon(Icons.directions_car,
                                color: Colors.white54, size: 36)),
                      ),
              ),
            ),
            // Subtle bottom gradient only
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 40,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Small badge (type)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(listing.type == 'reel' ? Icons.play_arrow : Icons.photo,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(listing.type == 'reel' ? 'Reel' : 'Photos',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white)),
                ]),
              ),
            ),
            // Promo badge (VIP/Featured/Urgent) below media type
            if (listing.isVip || listing.isFeatured || listing.isUrgent)
              Positioned(
                left: 8,
                top: 34,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: listing.isVip
                        ? MarketplaceColors.upgradeGold
                        : listing.isFeatured
                            ? MarketplaceColors.featured
                            : MarketplaceColors.urgent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    listing.isVip
                        ? 'VIP'
                        : listing.isFeatured
                            ? 'Featured'
                            : 'Urgent',
                    style: TextStyle(
                        color: listing.isVip ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            // Small heart top-right
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.favorite_border,
                    color: Colors.white, size: 16),
              ),
            ),
          ]),
        ),
        // Details section
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Seller row
              Row(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: Colors.black, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.person, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Seller',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 6),
              // Make / brand (small)
              Text(listing.make,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              // Model (16 bold)
              Text(
                listing.model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 6),
              // Price (15 yellow bold)
              Text(
                _formatPrice(listing.price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MarketplaceColors.accentYellow,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
              const SizedBox(height: 6),
              // Condition chip (optional)
              if (listing.condition.trim().isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(listing.condition,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              // Location + mileage (11 grey) with small arrow at end
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    listing.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white60),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.speed, size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Text(_formatMileage(listing.mileage),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white60)),
                const SizedBox(width: 6),
                // Contact quick actions
                _MiniCircleIcon(
                    icon: Icons.call,
                    onTap: () => openPhoneCall(listing.phone)),
                const SizedBox(width: 6),
                _MiniCircleIcon(
                    icon: Icons.chat_bubble_outline,
                    onTap: () => openWhatsAppWaMe(listing.phone,
                        message:
                            'Hi, I am interested in your ${listing.make} ${listing.model}')),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// =============================
// Full-width Featured Car Cards
// =============================

class CarFeaturedCard extends StatelessWidget {
  final Car car;
  const CarFeaturedCard({super.key, required this.car});

  String _formatPrice(int price) {
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  String _formatMileage(int v) {
    final s = v.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => ',')} km';
  }

  String _timeAgo(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isActivePromo = car.promotionExpiry != null &&
        car.promotionExpiry!.isAfter(DateTime.now());
    final isVip = isActivePromo && car.isVip;
    final isFeatured = isActivePromo && car.isFeatured;
    final isUrgent = isActivePromo && car.isUrgent;

    return GestureDetector(
      onTap: () {
        try {
          context.read<CarProvider>().incrementViews(car.id);
        } catch (_) {}
        context.pushNamed('car_details',
            pathParameters: {'id': car.id}, extra: car);
      },
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Image header
          SizedBox(
            height: 238,
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                  child: _CarImageThumb(
                      url: (car.images.isNotEmpty ? car.images.first : ''), align: Alignment.center),
                ),
              ),
              // Top-left: heart + share
              Positioned(
                left: 10,
                top: 10,
                child: Row(children: [
                  _TopIconButton(
                    icon: car.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: car.isLiked ? Colors.red : Colors.white,
                    onTap: () => context.read<CarProvider>().toggleLike(car.id),
                  ),
                  const SizedBox(width: 8),
                  _TopIconButton(
                    icon: Icons.share,
                    onTap: () async {
                      await Clipboard.setData(
                          ClipboardData(text: 'car/${car.id}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')));
                    },
                  ),
                ]),
              ),
              // Top-left: promo badge (small) below icons
              if (isVip || isFeatured || isUrgent)
                Positioned(
                  left: 10,
                  top: 50,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: isVip
                            ? MarketplaceColors.upgradeGold
                            : isFeatured
                                ? MarketplaceColors.featured
                                : MarketplaceColors.urgent,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(
                        isVip
                            ? 'VIP'
                            : isFeatured
                                ? 'Featured'
                                : 'Urgent',
                        style: TextStyle(
                            color: isVip ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              // Bottom-right: photo count (use imageUrls if available)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                      '${(car.images.isEmpty ? 1 : car.images.length)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Price and time
              Row(children: [
                Expanded(
                    child: Text(_formatPrice(car.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: MarketplaceColors.accentYellow,
                            fontWeight: FontWeight.w900))),
                const SizedBox(width: 8),
                Text(_timeAgo(car.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white60)),
              ]),
              const SizedBox(height: 6),
              // Title: Make + Model [+ Trim]
              Text('${car.make} ${car.model}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 6),
              // Description line (optional)
              if (car.description.trim().isNotEmpty)
                Text(car.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              // Details chips row
              Wrap(spacing: 6, runSpacing: 6, children: [
                _DetailChip(text: 'Year: ${car.year}'),
                _DetailChip(text: 'Mileage: ${_formatMileage(car.mileage)}'),
                _DetailChip(
                    text:
                        'Condition: ${car.description.toLowerCase().contains('new') ? 'New' : 'Used'}'),
                const _DetailChip(text: 'Transmission: —'),
              ]),
              const SizedBox(height: 8),
              // Location row
              Row(children: [
                const Icon(Icons.location_on, size: 16, color: Colors.white60),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(car.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.white60))),
              ]),
              const SizedBox(height: 10),
              // Contact buttons and seller avatar
              Row(children: [
                Expanded(
                  child: _ActionButton.dark(
                    icon: Icons.chat_bubble_outline,
                    iconColor: Colors.green,
                    label: 'WhatsApp',
                    onTap: () => openWhatsAppWaMe(car.sellerPhone,
                        message:
                            'Hi, I am interested in your ${car.make} ${car.model}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton.yellow(
                    icon: Icons.call,
                    label: 'Call',
                    onTap: () => openPhoneCall(car.sellerPhone),
                  ),
                ),
                const SizedBox(width: 10),
                const _SellerAvatar(label: 'Seller'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class CarMapFeaturedCard extends StatefulWidget {
  final Map<String, dynamic> item;
  const CarMapFeaturedCard({super.key, required this.item});

  @override
  State<CarMapFeaturedCard> createState() => _CarMapFeaturedCardState();
}

class _CarMapFeaturedCardState extends State<CarMapFeaturedCard> {
  int _index = 0;
  late final PageController _pc;

  List<String> _readImages(Map<String, dynamic> item) {
    // Use images[] only; ignore coverImageUrl and legacy fields
    final dynamic im = item['images'];
    final List<String> listImages = im is List
        ? im
            .map((e) => e?.toString() ?? '')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .cast<String>()
            .toList()
        : const <String>[];
    bool _isHttp(String s) => s.toLowerCase().startsWith('http');
    final seen = <String>{};
    final filtered = <String>[];
    for (final u in listImages) {
      if (u.isEmpty) continue;
      if (!seen.add(u)) continue;
      if (_isHttp(u)) filtered.add(u);
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  String _priceText(String? raw) {
    final r = (raw ?? '').trim();
    if (r.isEmpty) return 'Call for price';
    final digits = r.replaceAll(RegExp(r'[^0-9]'), '');
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${digits.replaceAllMapped(reg, (m) => ',')}';
  }

  String _timeAgo(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  void _openDetails() {
    final item = widget.item;
    final List<String> images = _readImages(item);
    final String imageUrl = images.isNotEmpty ? images.first : '';
    final String id = (item['id']?.toString().isNotEmpty ?? false)
        ? item['id'].toString()
        : 'map-${(item['title'] ?? '').toString().hashCode}-${(item['time'] is DateTime ? (item['time'] as DateTime).millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch)}';
    final String make = (item['make'] ?? '').toString().trim();
    final String model = (item['model'] ?? '').toString().trim();
    final String title = (item['title'] ?? '').toString().trim();
    final String derivedMake = make.isNotEmpty
        ? make
        : (title.split(' ').isNotEmpty ? title.split(' ').first : '');
    final String derivedModel = model.isNotEmpty ? model : title;
    int parseInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      final s = v.toString();
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? fallback;
    }

    final int year = parseInt(item['year'], fallback: 0);
    final int mileage = parseInt(item['mileage'], fallback: 0);
    final int price = parseInt(item['price'], fallback: 0);
    final String location = (item['location'] ?? '').toString();
    final String phone =
        (item['sellerPhone'] ?? item['phone'] ?? '').toString();
    final String description = (item['description'] ?? '').toString();
    final DateTime createdAt =
        item['time'] is DateTime ? (item['time'] as DateTime) : DateTime.now();

    final ownerId = (item['ownerId'] ?? 'user_002').toString();
    final tempCar = Car(
      id: id,
      make: derivedMake.isEmpty ? '—' : derivedMake,
      model: derivedModel.isEmpty ? '—' : derivedModel,
      year: year,
      price: price,
      mileage: mileage,
      location: location.isEmpty ? '—' : location,
      imageUrl: imageUrl,
      sellerPhone: phone,
      description: description,
      createdAt: createdAt,
      ownerId: ownerId,
    );

    if (!mounted) return;
    try {
      context.read<CarProvider>().incrementViews(id);
    } catch (_) {}
    context.pushNamed('car_details',
        pathParameters: {'id': id},
        extra: {'car': tempCar, 'imageUrls': images});
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.item['title'] ?? '').toString();
    final location = (widget.item['location'] ?? '').toString();
    final phone =
        (widget.item['sellerPhone'] ?? widget.item['phone'] ?? '').toString();
    final images = _readImages(widget.item);
    final createdAt = widget.item['time'] is DateTime
        ? widget.item['time'] as DateTime
        : null;
    final year = widget.item['year']?.toString() ?? '—';
    final mileage = widget.item['mileage']?.toString() ?? '—';
    final condition = (widget.item['condition'] ?? '—').toString();
    final transmission = (widget.item['transmission'] ?? '—').toString();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _openDetails,
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Image header with slider if multiple
          SizedBox(
            height: 238,
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                  child: images.length <= 1
                      ? _CarImageThumb(
                          url: images.isEmpty ? '' : images.first,
                          align: Alignment.center)
                      : PageView.builder(
                          controller: _pc,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemCount: images.length,
                          itemBuilder: (_, i) => _CarImageThumb(
                              url: images[i], align: Alignment.center),
                        ),
                ),
              ),
              // Make image itself clickable
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16)),
                    onTap: _openDetails,
                  ),
                ),
              ),
              // Dots indicator bottom center
              if (images.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < images.length; i++) ...[
                          Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                  color: i == _index
                                      ? Colors.white
                                      : Colors.white54,
                                  shape: BoxShape.circle)),
                        ]
                      ]),
                ),
              // Photo count bottom-right
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                      '${(_index + 1).clamp(1, images.length)} / ${images.isEmpty ? 1 : images.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              // Top-left: heart + share (no persistence for map item)
              Positioned(
                left: 10,
                top: 10,
                child: Row(children: [
                  _TopIconButton(icon: Icons.favorite_border, onTap: () {}),
                  const SizedBox(width: 8),
                  _TopIconButton(
                    icon: Icons.share,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: title));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Title copied')));
                      }
                    },
                  ),
                ]),
              ),
              // Top-left: VIP/Featured/Urgent badge (small, below icons)
              if ((widget.item['isVip'] ?? false) ||
                  (widget.item['isFeatured'] ?? false) ||
                  (widget.item['isUrgent'] ?? false))
                Positioned(
                  left: 10,
                  top: 50,
                  child: Builder(builder: (context) {
                    final bool vip = (widget.item['isVip'] ?? false) as bool;
                    final bool featured =
                        (widget.item['isFeatured'] ?? false) as bool;
                    final bool urgent =
                        (widget.item['isUrgent'] ?? false) as bool;
                    final String label = vip
                        ? 'VIP'
                        : featured
                            ? 'Featured'
                            : 'Urgent';
                    final Color bg = vip
                        ? MarketplaceColors.upgradeGold
                        : featured
                            ? MarketplaceColors.featured
                            : MarketplaceColors.urgent;
                    final Color fg = vip ? Colors.black : Colors.white;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(label,
                          style: TextStyle(
                              color: fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    );
                  }),
                ),
            ]),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(_priceText(widget.item['price']?.toString()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: MarketplaceColors.accentYellow,
                            fontWeight: FontWeight.w900))),
                const SizedBox(width: 6),
                Row(children: const [
                  Icon(Icons.remove_red_eye, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('0',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                const SizedBox(width: 8),
                Text(_timeAgo(createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white60)),
              ]),
              const SizedBox(height: 6),
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 6),
              if ((widget.item['description'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty)
                Text(widget.item['description'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _DetailChip(text: 'Year: $year'),
                _DetailChip(
                    text:
                        'Mileage: ${mileage == '—' ? mileage : '$mileage km'}'),
                _DetailChip(text: 'Condition: $condition'),
                _DetailChip(text: 'Transmission: $transmission'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, size: 16, color: Colors.white60),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.white60))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _ActionButton.dark(
                    icon: Icons.chat_bubble_outline,
                    iconColor: Colors.green,
                    label: 'WhatsApp',
                    onTap: () => openWhatsAppWaMe(phone,
                        message: 'Hi, I am interested in your listing'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton.yellow(
                    icon: Icons.call,
                    label: 'Call',
                    onTap: () => openPhoneCall(phone),
                  ),
                ),
                const SizedBox(width: 10),
                const _SellerAvatar(label: 'Seller'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TopIconButton(
      {required this.icon, this.color = Colors.white, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

// Minimal WhatsApp logo painter (white glyph) for use on a green circular button.
class WhatsAppLogoIcon extends StatelessWidget {
  final double size;
  final Color color;
  const WhatsAppLogoIcon(
      {super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _WhatsAppLogoPainter(color)),
      );
}

class _WhatsAppLogoPainter extends CustomPainter {
  final Color color;
  const _WhatsAppLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.12; // ring thickness

    // Outer ring (approximate chat bubble circle glyph)
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final r = (math.min(w, h) - stroke) / 2;
    canvas.drawCircle(Offset(w / 2, h / 2), r, ringPaint);

    // Phone handset: a rounded bar with end caps, rotated slightly
    final handsetPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.7); // ~-40 degrees

    final barW = w * 0.56;
    final barH = h * 0.18;
    final rr = Radius.circular(barH * 0.5);
    final rect =
        Rect.fromCenter(center: Offset.zero, width: barW, height: barH);
    final rrect = RRect.fromRectAndCorners(rect,
        topLeft: rr, topRight: rr, bottomLeft: rr, bottomRight: rr);
    canvas.drawRRect(rrect, handsetPaint);

    // End caps (slightly larger circles to hint earpiece/mouthpiece)
    final capR = barH * 0.55;
    canvas.drawCircle(Offset(-barW / 2, 0), capR, handsetPaint);
    canvas.drawCircle(Offset(barW / 2, 0), capR, handsetPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WhatsAppLogoPainter oldDelegate) => false;
}

class _WhatsAppFab extends StatelessWidget {
  final String phone;
  final String message;
  const _WhatsAppFab({required this.phone, required this.message});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => openWhatsAppWaMe(phone, message: message),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(
                color: MarketplaceColors.upgradeGold.withValues(alpha: 0.6),
                width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.chat_bubble_outline,
              color: Colors.white, size: 20),
        ),
      );
}

class _DetailChip extends StatelessWidget {
  final String text;
  const _DetailChip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Color iconColor;

  const _ActionButton._(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.bg,
      required this.fg,
      required this.iconColor});

  factory _ActionButton.dark(
          {required IconData icon,
          required String label,
          required VoidCallback onTap,
          Color iconColor = Colors.white}) =>
      _ActionButton._(
          icon: icon,
          label: label,
          onTap: onTap,
          bg: Colors.black.withValues(alpha: 0.3),
          fg: Colors.white,
          iconColor: iconColor);

  factory _ActionButton.yellow(
          {required IconData icon,
          required String label,
          required VoidCallback onTap}) =>
      _ActionButton._(
          icon: icon,
          label: label,
          onTap: onTap,
          bg: MarketplaceColors.accentYellow,
          fg: Colors.black,
          iconColor: Colors.black);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _SellerAvatar extends StatelessWidget {
  final String label;
  const _SellerAvatar({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                color: Colors.black, shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 16, color: Colors.white)),
        const SizedBox(width: 6),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
      ]);
}

// =====================================
// Featured Car Grid Cards (2-column UI)
// =====================================

class CarFeaturedGridCard extends StatelessWidget {
  final Car car;
  const CarFeaturedGridCard({super.key, required this.car});

  String _formatPrice(int price) {
    final s = price.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${s.replaceAllMapped(reg, (m) => ',')}';
  }

  String _formatMileage(int v) {
    final s = v.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActivePromo = car.promotionExpiry != null &&
        car.promotionExpiry!.isAfter(DateTime.now());
    final isVip = isActivePromo && car.isVip;
    final isFeatured = isActivePromo && car.isFeatured;
    final condition =
        car.description.toLowerCase().contains('new') ? 'New' : 'Used';
    // Normalize image source: use images[] from Firestore mapping
    final List<String> images = car.images;
    final String selectedUrl = images.isNotEmpty ? images.first : '';
    // Debug removed

    return GestureDetector(
      onTap: () {
        try {
          context.read<CarProvider>().incrementViews(car.id);
        } catch (_) {}
        context.pushNamed('car_details',
            pathParameters: {'id': car.id}, extra: car);
      },
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: MarketplaceColors.upgradeGold.withValues(alpha: 0.45),
              width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 8)),
            if (isVip)
              BoxShadow(
                  color: MarketplaceColors.upgradeGold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6)),
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Image area (compact 95-110 px) with gradient overlay
          SizedBox(
            height: 106,
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                  child: Builder(builder: (context) {
                    final placeholder = Container(
                      color: Colors.black.withValues(alpha: 0.2),
                    );
                    if (selectedUrl.isNotEmpty) {
                      return _CarImageThumb(
                          url: selectedUrl, align: Alignment.center);
                    }
                    return placeholder;
                  }),
                ),
              ),
              // Bottom gradient
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: IgnorePointer(
                      child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16)),
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45)
                          ]),
                    ),
                  ))),
              // Top-left: VIP/Featured/Urgent (bigger, clean)
              Positioned(
                left: 8,
                top: 8,
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('listings')
                      .doc(car.id)
                      .get(),
                  builder: (context, snap) {
                    bool vip = false, featured = false, urgent = false;
                    final nowActive = car.promotionExpiry != null &&
                        car.promotionExpiry!.isAfter(DateTime.now());
                    vip = nowActive && car.isVip;
                    featured = nowActive && car.isFeatured;
                    if (snap.hasData && snap.data!.data() != null) {
                      final d = snap.data!.data()!;
                      vip = (d['isVip'] as bool?) ?? vip;
                      featured = (d['isFeatured'] as bool?) ?? featured;
                      urgent = (d['isUrgent'] as bool?) ?? false;
                    }
                    if (!(vip || featured || urgent))
                      return const SizedBox.shrink();
                    final label = vip
                        ? 'VIP'
                        : featured
                            ? 'Featured'
                            : 'Urgent';
                    final Color bg = vip
                        ? MarketplaceColors.upgradeGold
                        : (featured
                            ? MarketplaceColors.featured
                            : MarketplaceColors.urgent);
                    final Color fg = vip ? Colors.black : Colors.white;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(label,
                          style: TextStyle(
                              color: fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    );
                  },
                ),
              ),
              // Top-right: white outline heart in circular tap area
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () => context.read<CarProvider>().toggleLike(car.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1),
                    ),
                    child: Icon(
                        car.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: car.isLiked ? Colors.red : Colors.white,
                        size: 16),
                  ),
                ),
              ),
            ]),
          ),
          // Text area
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${car.make} ${car.model}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Text(car.year == 0 ? '—' : '${car.year}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white60, fontSize: 11)),
                const SizedBox(width: 10),
                const Icon(Icons.speed, size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Text(_formatMileage(car.mileage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white60, fontSize: 11)),
                const SizedBox(width: 10),
                const Icon(Icons.location_on, size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(car.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.white60, fontSize: 11))),
              ]),
              const SizedBox(height: 6),
              Text(_formatPrice(car.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MarketplaceColors.upgradeGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ]),
          ),
          const Spacer(),
          // Bottom actions: Call • Message • WhatsApp (green)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => openPhoneCall(car.sellerPhone),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Center(
                        child: Icon(Icons.call, color: Colors.white, size: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pushNamed('messages'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Center(
                        child:
                            Icon(Icons.message, color: Colors.white, size: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => openWhatsAppWaMe(car.sellerPhone,
                      message:
                          'Hi, I am interested in your ${car.make} ${car.model}'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Center(
                        child: WhatsAppLogoIcon(size: 18, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class CarMapFeaturedGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const CarMapFeaturedGridCard({super.key, required this.item});

  String _priceText(String? raw) {
    final r = (raw ?? '').trim();
    if (r.isEmpty) return 'AED —';
    final digits = r.replaceAll(RegExp(r'[^0-9]'), '');
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return 'AED ${digits.replaceAllMapped(reg, (m) => ',')}';
  }

  List<String> _readImages(Map<String, dynamic> item) {
    // Use images[] only; ignore coverImageUrl and legacy fields
    final dynamic im = item['images'];
    final List<String> listImages = im is List
        ? im
            .map((e) => e?.toString() ?? '')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .cast<String>()
            .toList()
        : const <String>[];
    bool _isHttp(String s) => s.toLowerCase().startsWith('http');
    final seen = <String>{};
    final filtered = <String>[];
    for (final u in listImages) {
      if (u.isEmpty) continue;
      if (!seen.add(u)) continue;
      if (_isHttp(u)) filtered.add(u);
    }
    return filtered;
  }

  String _mileageText(dynamic v) {
    if (v == null) return '— km';
    final s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return '— km';
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => ',')} km';
  }

  void _openDetails(BuildContext context) {
    final images = _readImages(item);
    final String imageUrl = images.isNotEmpty ? images.first : '';
    final String id = (item['id']?.toString().isNotEmpty ?? false)
        ? item['id'].toString()
        : 'map-${(item['title'] ?? '').toString().hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    final String make = (item['make'] ?? '').toString().trim();
    final String model = (item['model'] ?? '').toString().trim();
    final String title = (item['title'] ?? '').toString().trim();
    final String derivedMake = make.isNotEmpty
        ? make
        : (title.split(' ').isNotEmpty ? title.split(' ').first : '');
    final String derivedModel = model.isNotEmpty ? model : title;
    int parseInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      final s = v.toString();
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? fallback;
    }

    final int year = parseInt(item['year']);
    final int mileage = parseInt(item['mileage']);
    final int price = parseInt(item['price']);
    final String location = (item['location'] ?? '').toString();
    final String phone =
        (item['sellerPhone'] ?? item['phone'] ?? '').toString();
    final String description = (item['description'] ?? '').toString();
    final DateTime createdAt =
        item['time'] is DateTime ? (item['time'] as DateTime) : DateTime.now();

    final ownerId = (item['ownerId'] ?? 'user_002').toString();
    final tempCar = Car(
      id: id,
      make: derivedMake.isEmpty ? '—' : derivedMake,
      model: derivedModel.isEmpty ? '—' : derivedModel,
      year: year,
      price: price,
      mileage: mileage,
      location: location.isEmpty ? '—' : location,
      imageUrl: imageUrl,
      sellerPhone: phone,
      description: description,
      createdAt: createdAt,
      ownerId: ownerId,
    );
    try {
      context.read<CarProvider>().incrementViews(id);
    } catch (_) {}
    context.pushNamed('car_details',
        pathParameters: {'id': id},
        extra: {'car': tempCar, 'imageUrls': images});
  }

  @override
  Widget build(BuildContext context) {
    final images = _readImages(item);
    // Debug raw fields
    debugPrint('listing.images: ${item['images']}');
    debugPrint('listing.imageUrl: ${item['imageUrl']}');
    debugPrint('listing.image: ${item['image']}');
    final title = (item['title'] ?? '').toString();
    final make = (item['make'] ?? '').toString().trim();
    final model = (item['model'] ?? '').toString().trim();
    final showMake = make.isNotEmpty
        ? make
        : (title.split(' ').isNotEmpty ? title.split(' ').first : '');
    final showModel = model.isNotEmpty ? model : title;
    final location = (item['location'] ?? '').toString();
    final condition = (item['condition'] ?? '').toString().trim();
    final transmission = (item['transmission'] ?? '—').toString();
    final phone = (item['sellerPhone'] ?? item['phone'] ?? '').toString();
    final bool vip = (item['isVip'] ?? false) as bool;

    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceColors.luxItemCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: MarketplaceColors.upgradeGold.withValues(alpha: 0.45),
              width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 8)),
            if (vip)
              BoxShadow(
                  color: MarketplaceColors.upgradeGold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6)),
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 106,
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                  child: Builder(builder: (context) {
                    // Use unified priority from _readImages
                    final String imageUrl = images.isNotEmpty ? images.first : '';
                    final String trimmed = ImageUrlUtils.sanitize(imageUrl);
                    final bool isValid = ImageUrlUtils.isValidFirebaseDownload(trimmed);

                    if (trimmed.isEmpty) {
                      // Placeholder only when URL is empty; no icons
                      return Container(
                          color: Colors.black.withValues(alpha: 0.2));
                    }
                    if (isValid) {
                      return Image.network(
                        trimmed,
                        key: ValueKey(trimmed),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, progress) => child,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.black.withValues(alpha: 0.2)),
                      );
                    }
                    // Non-Firebase https sources are not displayed in cards
                    return Container(
                        color: Colors.black.withValues(alpha: 0.2));
                  }),
                ),
              ),
              // Bottom gradient
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: IgnorePointer(
                      child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16)),
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45)
                          ]),
                    ),
                  ))),
              // Top-left: VIP/Featured/Urgent (bigger)
              if ((item['isVip'] ?? false) ||
                  (item['isFeatured'] ?? false) ||
                  (item['isUrgent'] ?? false))
                Positioned(
                  left: 8,
                  top: 8,
                  child: Builder(builder: (context) {
                    final bool vipB = (item['isVip'] ?? false) as bool;
                    final bool featuredB =
                        (item['isFeatured'] ?? false) as bool;
                    final bool urgentB = (item['isUrgent'] ?? false) as bool;
                    final String label = vipB
                        ? 'VIP'
                        : featuredB
                            ? 'Featured'
                            : 'Urgent';
                    final Color bg = vipB
                        ? MarketplaceColors.upgradeGold
                        : (featuredB
                            ? MarketplaceColors.featured
                            : MarketplaceColors.urgent);
                    final Color fg = vipB ? Colors.black : Colors.white;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(label,
                          style: TextStyle(
                              color: fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    );
                  }),
                ),
              // Top-right: white outline heart (no persistence)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1)),
                  child: const Icon(Icons.favorite_border,
                      color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$showMake $showModel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text((item['year'] ?? '—').toString(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white60, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.speed, size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(_mileageText(item['mileage']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white60, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Colors.white60, fontSize: 11))),
                    ]),
                    const SizedBox(height: 6),
                    Text(_priceText(item['price']?.toString()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: MarketplaceColors.accentYellow,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ]),
            ),
          ),
          // Bottom actions row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => openPhoneCall(phone),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Center(
                        child: Icon(Icons.call, color: Colors.white, size: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pushNamed('messages'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Center(
                        child:
                            Icon(Icons.message, color: Colors.white, size: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => openWhatsAppWaMe(phone,
                      message: 'Hi, I am interested in your listing'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Center(
                        child: WhatsAppLogoIcon(size: 18, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class MapListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const MapListingCard({super.key, required this.item});

  String _priceText(String? raw) {
    final r = (raw ?? '').trim();
    if (r.isEmpty) return 'AED —';
    return 'AED $r';
  }

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] ?? '').toString();
    final title = (item['title'] ?? '').toString();
    final price = (item['price'] ?? '').toString();
    final image = (item['image'] ?? '').toString();
    final location = (item['location'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: MarketplaceColors.luxItemCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 8))
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Visual area (image / plate / reel)
        SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: switch (type) {
                'plate' => _PlateFace(title: title, emirate: location),
                'reel' => _ReelThumbOverlay(),
                _ => image.isNotEmpty
                    ? _CarImageThumb(url: image, align: Alignment.center)
                    : Container(
                        color: Colors.black12,
                        child: const Center(
                            child: Icon(Icons.directions_car,
                                color: Colors.white54, size: 36))),
              },
            ),
          ),
        ),
        // Text area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 6),
              Text(_priceText(price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MarketplaceColors.accentYellow,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const Spacer(),
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.white60))),
                const SizedBox(width: 6),
                if (type == 'reel')
                  const Icon(Icons.play_arrow, size: 16, color: Colors.white60),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PlateFace extends StatelessWidget {
  final String title; // plate number
  final String emirate;
  const _PlateFace({required this.title, required this.emirate});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.86,
          child: UaePlate(
            emirate: emirate,
            plateNumber: title,
            height: 88,
          ),
        ),
      ),
    );
  }
}

class _ReelThumbOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.35))),
      const Center(
        child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.black,
            child: Icon(Icons.play_arrow, color: Colors.white)),
      ),
    ]);
  }
}

// =============================
// Stories & Search UI widgets
// =============================

class _Story {
  final String username;
  final String? imageUrl;
  const _Story({required this.username, this.imageUrl});
}

class _StoriesStrip extends StatelessWidget {
  final List<_Story> stories;
  const _StoriesStrip({required this.stories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final s = stories[index];
          return Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Colors.black, MarketplaceColors.accentYellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                      color: MarketplaceColors.luxCard,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06))),
                  child: ClipOval(
                    child: s.imageUrl == null || s.imageUrl!.isEmpty
                        ? const Center(
                            child: Icon(Icons.person, color: Colors.white70))
                        : Image.network(s.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child:
                                    Icon(Icons.person, color: Colors.white70))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
                width: 64,
                child: Text(s.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white70))),
          ]);
        },
      ),
    );
  }
}

class _SearchCard extends StatefulWidget {
  final MarketplaceCategory initialCategory;
  final void Function(
      {required String make,
      required String model,
      required MarketplaceCategory category,
      String? plateEmirate,
      String? plateCode,
      String? plateNumber}) onSearch;
  final void Function(MarketplaceCategory category) onMoreOptions;
  const _SearchCard(
      {required this.initialCategory,
      required this.onSearch,
      required this.onMoreOptions});

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  String? _selectedMake;
  String? _selectedModel;
  // Plates
  String? _selectedEmirate;
  final TextEditingController _plateNumberCtrl = TextEditingController();
  MarketplaceCategory _cat = MarketplaceCategory.cars;

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  void dispose() {
    _plateNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the complete brand database for consistent search filters
    final makes = ['Any', ...getAllBrands(includeOther: false)];
    final models = _selectedMake == null
        ? ['Any']
        : ['Any', ...getModelsForBrand(_selectedMake!)];
    final emirates = const [
      'Any',
      'Dubai',
      'Abu Dhabi',
      'Sharjah',
      'Ajman',
      'Ras Al Khaimah',
      'Umm Al Quwain',
      'Fujairah'
    ];

    return Container(
      decoration: BoxDecoration(
          color: MarketplaceColors.luxCard,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.search, color: MarketplaceColors.accentYellow),
          const SizedBox(width: 8),
          Text('Search',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        if (_cat == MarketplaceCategory.cars)
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedMake ?? 'Any',
                items: makes
                    .map((m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedMake = v == 'Any' ? null : v;
                  _selectedModel = null;
                }),
                decoration: InputDecoration(
                  labelText: 'Make',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                dropdownColor: MarketplaceColors.luxItemCard,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedModel ?? 'Any',
                items: models
                    .map((m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedModel = v == 'Any' ? null : v),
                decoration: InputDecoration(
                  labelText: 'Model',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                dropdownColor: MarketplaceColors.luxItemCard,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ])
        else if (_cat == MarketplaceCategory.plates)
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedEmirate ?? 'Any',
                items: emirates
                    .map((m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedEmirate = v == 'Any' ? null : v;
                }),
                decoration: InputDecoration(
                  labelText: 'Emirate',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                dropdownColor: MarketplaceColors.luxItemCard,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _plateNumberCtrl,
                decoration: InputDecoration(
                    labelText: 'Plate number',
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none),
                    labelStyle: const TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ]),
        
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<MarketplaceCategory>(
              value: _cat,
              items: const [
                DropdownMenuItem(
                    value: MarketplaceCategory.cars, child: Text('Cars')),
                DropdownMenuItem(
                    value: MarketplaceCategory.plates, child: Text('Plates')),
                DropdownMenuItem(
                    value: MarketplaceCategory.accessories, child: Text('Accessories')),
              ],
              onChanged: (v) =>
                  setState(() => _cat = v ?? MarketplaceCategory.cars),
              decoration: InputDecoration(
                labelText: 'Category',
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              dropdownColor: MarketplaceColors.luxItemCard,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (_cat == MarketplaceCategory.cars) {
                  widget.onSearch(
                    make: (_selectedMake ?? '').trim(),
                    model: (_selectedModel ?? '').trim(),
                    category: _cat,
                  );
                } else if (_cat == MarketplaceCategory.plates) {
                  widget.onSearch(
                    make: '',
                    model: '',
                    category: _cat,
                    plateEmirate: _selectedEmirate,
                    plateCode: null,
                    plateNumber: _plateNumberCtrl.text.trim(),
                  );
                } else {
                  widget.onSearch(
                    make: '',
                    model: '',
                    category: _cat,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceColors.accentYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ).copyWith(splashFactory: NoSplash.splashFactory),
              child: const Text('Search'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => widget.onMoreOptions(_cat),
            child: const Text('+ More options',
                style: TextStyle(
                    color: MarketplaceColors.accentYellow,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// Removed legacy _UploadCtaButton (yellow middle button) per latest requirements.

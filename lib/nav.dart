import 'package:go_router/go_router.dart';
import 'package:autoreel/pages/login_page.dart';
import 'package:autoreel/pages/feed_page.dart';
import 'package:autoreel/pages/upload_page.dart';
import 'package:autoreel/pages/car_details_page.dart';
import 'package:autoreel/pages/upload_plate_page.dart';
import 'package:autoreel/pages/new_listing_page.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/pages/favorites_page.dart';
import 'package:autoreel/pages/profile_page.dart';
import 'package:autoreel/pages/my_listings_page.dart';
import 'package:autoreel/pages/admin_review_page.dart';
import 'package:autoreel/pages/notifications_page.dart';
import 'package:autoreel/pages/plate_details_page.dart';
import 'package:autoreel/providers/plate_provider.dart';
import 'package:autoreel/pages/brands_page.dart';
import 'package:autoreel/pages/reels_page.dart';
import 'package:autoreel/pages/upload_reel_page.dart';
import 'package:autoreel/pages/auto_reel_page.dart';
import 'package:autoreel/pages/all_brands_page.dart';
import 'package:autoreel/pages/simple_login_page.dart';
import 'package:autoreel/pages/plate_page.dart';
import 'package:autoreel/pages/brand_results_page.dart';
import 'package:autoreel/pages/listing_videos_page.dart';
import 'package:autoreel/pages/settings_page.dart';
import 'package:autoreel/pages/upgrades_page.dart';
import 'package:autoreel/pages/messages_page.dart';
import 'package:autoreel/pages/chat_page.dart';
import 'package:autoreel/pages/payment_page.dart';
import 'package:autoreel/pages/public_profile_page.dart';
import 'package:autoreel/pages/privacy_settings_page.dart';
import 'package:autoreel/pages/terms_page.dart';
import 'package:autoreel/pages/privacy_policy_page.dart';
import 'package:autoreel/pages/accessories_page.dart';
import 'package:autoreel/pages/accessory_details_page.dart';
import 'package:autoreel/pages/new_accessory_page.dart';
import 'package:autoreel/pages/add_accessory_listing_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// GoRouter configuration for app navigation
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final loggedIn = fb.FirebaseAuth.instance.currentUser != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login || state.matchedLocation == AppRoutes.simpleLogin;
      if (!loggedIn && !isAuthRoute) return AppRoutes.login;
      if (loggedIn && isAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return NoTransitionPage(child: ChatPage(conversationId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(
          child: LoginPage(
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.simpleLogin,
        name: 'simple_login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SimpleLoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        name: 'favorites',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: FavoritesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.upload,
        name: 'upload',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: UploadPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.myListings,
        name: 'my_listings',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: MyListingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminReview,
        name: 'admin_review',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminReviewPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: NotificationsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.messages,
        name: 'messages',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: MessagesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.uploadPlate,
        name: 'upload_plate',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: UploadPlatePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.newListing,
        name: 'new_listing',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: NewListingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.carDetails,
        name: 'car_details',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          Car? car;
          List<String>? imageUrls;
          if (extra is Car) {
            car = extra;
          } else if (extra is Map) {
            final m = Map<String, dynamic>.from(extra as Map);
            final c = m['car'];
            if (c is Car) car = c;
            final imgs = m['imageUrls'];
            if (imgs is List) {
              imageUrls = imgs.whereType<String>().toList();
            }
          }
          return NoTransitionPage(
            child: CarDetailsPage(
              carId: id,
              initialCar: car,
              imageUrls: imageUrls,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.plateDetails,
        name: 'plate_details',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return NoTransitionPage(
            child: PlateDetailsPage(
              plateId: id,
              initialPlate: extra is Plate ? extra : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.brands,
        name: 'brands',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: BrandsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.accessories,
        name: 'accessories',
        pageBuilder: (context, state) => const NoTransitionPage(child: AccessoriesPage()),
      ),
      GoRoute(
        path: AppRoutes.addAccessoryListing,
        name: 'add_accessory_listing',
        pageBuilder: (context, state) => const NoTransitionPage(child: AddAccessoryListingPage()),
      ),
      GoRoute(
        path: AppRoutes.accessoryDetails,
        name: 'accessory_details',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return NoTransitionPage(child: AccessoryDetailsPage(accessoryId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.newAccessory,
        name: 'new_accessory',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return NoTransitionPage(child: NewAccessoryPage(accessoryId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.reels,
        name: 'reels',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ReelsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        name: 'user_profile',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final qp = state.uri.queryParameters;
          return NoTransitionPage(
            child: PublicProfilePage(
              sellerId: id,
              sellerName: qp['sellerName'],
              sellerPhone: qp['sellerPhone'],
              listingId: qp['listingId'],
              listingTitle: qp['listingTitle'],
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.uploadReel,
        name: 'upload_reel',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: UploadReelPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.autoReel,
        name: 'auto_reel',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AutoReelPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.allBrands,
        name: 'all_brands',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AllBrandsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.brandResults,
        name: 'brand_results',
        pageBuilder: (context, state) {
          final brand = state.uri.queryParameters['brand'] ?? '';
          return NoTransitionPage(child: BrandResultsPage(make: brand));
        },
      ),
      GoRoute(
        path: AppRoutes.platePage,
        name: 'plate_page',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: PlatePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.listingVideos,
        name: 'listing_videos',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ListingVideosPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SettingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.upgrades,
        name: 'upgrades',
        pageBuilder: (context, state) {
          return const NoTransitionPage(
            child: UpgradesPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.payment,
        name: 'payment',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          final type = state.uri.queryParameters['type'] ?? '';
          final pkg = state.uri.queryParameters['pkg'];
          return NoTransitionPage(
            child: PaymentPage(listingId: id, listingType: type, initialPackage: pkg),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacySettings,
        name: 'privacy_settings',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: PrivacySettingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        name: 'terms',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: TermsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacy_policy',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: PrivacyPolicyPage(),
        ),
      ),
    ],
  );
}

/// Route path constants
class AppRoutes {
  static const String login = '/';
  static const String simpleLogin = '/simple-login';
  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String upload = '/upload';
  static const String uploadPlate = '/upload-plate';
  static const String newListing = '/new-listing';
  static const String carDetails = '/car/:id';
  static const String plateDetails = '/plate/:id';
  static const String profile = '/profile';
  static const String userProfile = '/user/:id';
  static const String myListings = '/my-listings';
  static const String adminReview = '/admin-review';
  static const String notifications = '/notifications';
  static const String brands = '/brands';
  static const String reels = '/reels';
  static const String uploadReel = '/upload-reel';
  static const String autoReel = '/auto-reel';
  static const String allBrands = '/all-brands';
  static const String brandResults = '/brand-results';
  static const String platePage = '/plate-page';
  static const String listingVideos = '/listing-videos';
  static const String settings = '/settings';
  static const String upgrades = '/upgrades';
  static const String payment = '/payment';
  static const String messages = '/messages';
  static const String chat = '/chat/:id';
  static const String privacySettings = '/privacy-settings';
  static const String terms = '/terms';
  static const String privacyPolicy = '/privacy-policy';
  static const String accessories = '/accessories';
  static const String accessoryDetails = '/accessory/:id';
  static const String newAccessory = '/new-accessory';
  static const String addAccessoryListing = '/add-accessory-listing';
}

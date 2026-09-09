import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:book_bridge/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:book_bridge/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/screens/home_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/listing_details_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/sell_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/profile_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/my_books_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/categories_screen.dart';
import 'package:book_bridge/core/presentation/widgets/scaffold_with_navbar.dart';
import 'package:book_bridge/features/auth/presentation/screens/edit_profile_screen.dart';
import 'package:book_bridge/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:book_bridge/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/privacy_policy_screen.dart';
import 'package:book_bridge/features/auth/presentation/screens/terms_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/faq_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/feedback_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/contact_us_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/about_screen.dart';
import 'package:book_bridge/features/listings/presentation/screens/seller_profile_screen.dart';
import 'package:book_bridge/features/safety/presentation/screens/safety_guidelines_screen.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:book_bridge/features/chat/presentation/screens/chat_screen.dart';
import 'package:book_bridge/features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'package:book_bridge/features/transactions/presentation/screens/transaction_history_screen.dart';
import 'package:book_bridge/features/transactions/presentation/viewmodels/transaction_history_viewmodel.dart';
import 'package:book_bridge/injection_container.dart' as di;

final routerKey = GlobalKey<NavigatorState>();

/// App router configuration using go_router.
///
/// This configures all routes in the application and handles navigation
/// logic based on authentication state.
final appRouter = GoRouter(
  navigatorKey: routerKey,
  initialLocation: '/',
  redirect: (context, state) {
    final authViewModel = context.read<AuthViewModel>();
    final authState = authViewModel.authState;
    final location = state.matchedLocation;

    debugPrint('Router: Redirect check: loc=$location, state=$authState');

    // While initializing or loading, stay on current page (usually slash)
    if (authState == AuthState.initial || authState == AuthState.loading) {
      debugPrint('Router: Still loading auth, staying on $location');
      return null;
    }

    final isAuthenticated = authViewModel.isAuthenticated;
    final isGoingToAuth = location == '/sign-in' || location == '/sign-up';

    debugPrint(
      'Router: AuthStatus: authenticated=$isAuthenticated, isGoingToAuth=$isGoingToAuth',
    );

    // If not authenticated and not going to auth screen, redirect to sign-in
    if (!isAuthenticated && !isGoingToAuth) {
      debugPrint('Router: Redirecting unauthenticated user to /sign-in');
      return '/sign-in';
    }

    // If authenticated...
    if (isAuthenticated) {
      // 1. Check if profile is incomplete
      if (!authViewModel.isProfileComplete && location != '/complete-profile') {
        debugPrint('Router: Redirecting to /complete-profile');
        return '/complete-profile';
      }

      // 2. If profile is complete but trying to go to auth/splash
      if (authViewModel.isProfileComplete &&
          (isGoingToAuth ||
              location == '/' ||
              location == '/complete-profile')) {
        debugPrint('Router: Redirecting to /home');
        return '/home';
      }
    }

    debugPrint('Router: No redirection needed for $location');
    return null;
  },
  refreshListenable: di.getIt<AuthViewModel>(),
  routes: [
    // Splash/Landing route
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // Sign In route
    GoRoute(
      path: '/sign-in',
      name: 'signIn',
      builder: (context, state) => const SignInScreen(),
    ),

    // Sign Up route
    GoRoute(
      path: '/sign-up',
      name: 'signUp',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/complete-profile',
      name: 'completeProfile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),

    // Main Shell Route (with Bottom Navigation)
    // Branch order: Home (0), Categories (1), Sell (2), Chat (3), Profile (4)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Home Branch (index 0)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Categories Branch (index 1)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categories',
              name: 'categories',
              builder: (context, state) => const CategoriesScreen(),
            ),
          ],
        ),

        // Sell Branch (index 2) — triggered via FAB, kept as branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sell',
              name: 'sell',
              builder: (context, state) =>
                  SellScreen(listing: state.extra as Listing?),
            ),
          ],
        ),

        // Chat Branch (index 3) — real-time chat list
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chats',
              name: 'chats',
              builder: (context, state) => ChangeNotifierProvider(
                create: (_) => di.getIt<ChatViewModel>(),
                child: const ChatListScreen(),
              ),
            ),
          ],
        ),

        // Profile Branch (index 4)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Listing Details Route (Full Screen, outside shell)
    GoRoute(
      path: '/listing/:id',
      name: 'listing',
      builder: (context, state) {
        final listingId = state.pathParameters['id']!;
        return ListingDetailsScreen(listingId: listingId);
      },
    ),

    // My Books Route (Full Screen, outside shell — accessible from Profile)
    GoRoute(
      path: '/my-books',
      name: 'my-books',
      builder: (context, state) => const MyBooksScreen(),
    ),

    // Chat Thread Route (Full Screen, outside shell)
    GoRoute(
      path: '/chat/:listingId',
      name: 'chat',
      builder: (context, state) {
        final listingId = state.pathParameters['listingId']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ChangeNotifierProvider(
          create: (_) => di.getIt<ChatViewModel>(),
          child: ChatScreen(
            listingId: listingId,
            otherUserId: extra['otherUserId'] as String? ?? '',
            otherUserName: extra['otherUserName'] as String? ?? 'Seller',
            listingTitle: extra['listingTitle'] as String? ?? '',
            listingPrice: extra['listingPrice'] as int?,
          ),
        );
      },
    ),

    // Edit Profile Route (Full Screen, outside shell)
    GoRoute(
      path: '/edit-profile',
      name: 'editProfile',
      builder: (context, state) => const EditProfileScreen(),
    ),

    // Notifications Route (Full Screen, outside shell)
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    // About Route (Full Screen, outside shell)
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutScreen(),
    ),
    // Favorites Route
    GoRoute(
      path: '/favorites',
      name: 'favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    // Privacy Policy Route
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    // Terms & Conditions Route
    GoRoute(
      path: '/terms',
      name: 'terms',
      builder: (context, state) => const TermsScreen(),
    ),
    // FAQ Route
    GoRoute(
      path: '/faq',
      name: 'faq',
      builder: (context, state) => const FaqScreen(),
    ),
    // Feedback Route
    GoRoute(
      path: '/feedback',
      name: 'feedback',
      builder: (context, state) => const FeedbackScreen(),
    ),
    // Contact Us Route
    GoRoute(
      path: '/contact',
      name: 'contact',
      builder: (context, state) => const ContactUsScreen(),
    ),
    // Transaction History Route
    GoRoute(
      path: '/transactions',
      name: 'transactions',
      builder: (context, state) {
        final userId = di.getIt<AuthViewModel>().currentUser?.id ?? '';
        return ChangeNotifierProvider(
          create: (_) => di.getIt<TransactionHistoryViewModel>()..load(userId),
          child: const TransactionHistoryScreen(),
        );
      },
    ),
    // Seller Public Profile Route
    GoRoute(
      path: '/seller-profile/:userId',
      name: 'sellerProfile',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return SellerProfileScreen(userId: userId);
      },
    ),
    // Safety Guidelines Route
    GoRoute(
      path: '/safety',
      name: 'safety',
      builder: (context, state) => const SafetyGuidelinesScreen(),
    ),
  ],
);

/// Splash screen that shows during initial auth check.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset('assets/logo.png', height: 150),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

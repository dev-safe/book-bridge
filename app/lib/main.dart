import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/injection_container.dart' as di;
import 'package:book_bridge/config/router.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/listing_details_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/sell_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/profile_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/search_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/seller_profile_viewmodel.dart';
import 'package:book_bridge/features/notifications/presentation/viewmodels/notifications_viewmodel.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:book_bridge/features/favorites/presentation/viewmodels/favorites_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/locale_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'package:book_bridge/core/presentation/viewmodels/theme_viewmodel.dart';
import 'package:book_bridge/features/safety/presentation/viewmodels/safety_viewmodel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:book_bridge/firebase_options.dart' show DefaultFirebaseOptions;
import 'package:book_bridge/features/notifications/data/services/push_notification_service.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: AppConfig.supabaseUrl.isNotEmpty
        ? AppConfig.supabaseUrl
        : const String.fromEnvironment('SUPABASE_URL'),
    anonKey: AppConfig.supabaseAnonKey.isNotEmpty
        ? AppConfig.supabaseAnonKey
        : const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(
    PushNotificationService.onBackgroundMessage,
  );

  // Initialize dependency injection
  await di.setupDependencyInjection();

  // Initialize Push Notification Service
  await di.getIt<PushNotificationService>().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => di.getIt<AuthViewModel>(),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => di.getIt<HomeViewModel>(),
        ),
        ChangeNotifierProvider<ListingDetailsViewModel>(
          create: (_) => di.getIt<ListingDetailsViewModel>(),
        ),
        ChangeNotifierProvider<SellViewModel>(
          create: (_) => di.getIt<SellViewModel>(),
        ),
        ChangeNotifierProvider<ProfileViewModel>(
          create: (_) => di.getIt<ProfileViewModel>(),
        ),
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => di.getIt<SearchViewModel>(),
        ),
        ChangeNotifierProvider<NotificationsViewModel>(
          create: (_) => di.getIt<NotificationsViewModel>(),
        ),
        ChangeNotifierProvider<PaymentViewModel>(
          create: (_) => di.getIt<PaymentViewModel>(),
        ),
        ChangeNotifierProvider<FavoritesViewModel>(
          create: (_) => di.getIt<FavoritesViewModel>(),
          lazy: false,
        ),
        ChangeNotifierProvider<ChatViewModel>(
          create: (_) => di.getIt<ChatViewModel>(),
        ),
        ChangeNotifierProvider<LocaleViewModel>(
          create: (_) => LocaleViewModel(),
        ),
        ChangeNotifierProvider<LocationViewModel>(
          create: (_) => di.getIt<LocationViewModel>(),
        ),
        ChangeNotifierProvider<SellerProfileViewModel>(
          create: (_) => di.getIt<SellerProfileViewModel>(),
        ),
        ChangeNotifierProvider<ThemeViewModel>(
          // Added ThemeViewModel
          create: (_) => di.getIt<ThemeViewModel>(),
        ),
        ChangeNotifierProvider<SafetyViewModel>(
          create: (_) => di.getIt<SafetyViewModel>(),
        ),
      ],
      child: Consumer2<LocaleViewModel, ThemeViewModel>(
        // Changed to Consumer2
        builder: (context, localeViewModel, themeViewModel, _) {
          // Updated builder signature
          return MaterialApp.router(
            title: 'BookBridge: Social Venture',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeViewModel.themeMode, // Added themeMode
            routerConfig: appRouter,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeViewModel.locale,
          );
        },
      ),
    );
  }
}

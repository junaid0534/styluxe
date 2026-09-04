// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';   // ← New Import

// Import all screens
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
// Customer Screens
import 'screens/customer_screens/customer_screens.dart';

// Seller Screens
import 'screens/seller_screens/seller_screens.dart';

// Admin Screens
import 'screens/admin_screens/admin_dashboard_screen.dart';
import 'screens/admin_screens/admin_banners_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/chat/inbox_screen.dart';

import 'services/session_service.dart';
import 'services/realtime_notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://sqlhkppxsbvviyengyna.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNxbGhrcHB4c2J2dml5ZW5neW5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyNDk1MDIsImV4cCI6MjA5MzgyNTUwMn0.us_kgATEOAKxrev9hwAmbEel18XqvMrTl9afetgTClk',
  );

  // Initialize Realtime Push Notification & Sound Service
  await RealtimeNotificationService.initialize(navKey: appNavigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        SessionService.recordActivity();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Styluxe',
      theme: AppTheme.lightTheme,
      
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/super_admin': (context) => const SuperAdminDashboardScreen(),
        '/admin_banners': (context) => const AdminBannersScreen(),
        '/maintenance': (context) => const MaintenanceScreen(),
        '/inbox': (context) => const InboxScreen(isCustomer: true),
        // Customer Screens
        '/customer_home': (context) => const CustomerHomeScreen(),
        '/shop_now': (context) => const ShopNowScreen(),
        '/select_customer_category': (context) => CustomerCategoryScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/order_placed': (context) => const OrderPlacedScreen(orderId: '', totalAmount: 0),
        '/my_orders': (context) => const MyOrdersScreen(),
        '/order_detail': (context) => const OrderDetailScreen(order: {}),
        '/order_tracking': (context) => const OrderTrackingScreen(order: {}),
        '/notifications': (context) => const NotificationsScreen(),
        '/wishlist': (context) => const WishlistScreen(),
        '/product_detail': (context) {
          final product = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProductDetailScreen(product: product);
        },
        '/notification_detail': (context) {
          final notification = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return NotificationDetailScreen(notification: notification);
        },
        // Profile Features
        '/my_profile': (context) => const MyProfileScreen(),
        '/edit_profile': (context) => const EditProfileScreen(),
        '/shipping_addresses': (context) => const ShippingAddressesScreen(),
        '/add_address': (context) => const AddAddressScreen(),
        '/change_password': (context) => const ChangePasswordScreen(),
        '/help_support': (context) => const HelpSupportScreen(),
        // Seller Screens
        '/seller': (context) => const SellerHomeScreen(),
        '/add_product': (context) => AddProductScreen(),
        '/my_products': (context) => MyProductsScreen(),
        '/manage_store': (context) => ManageStoreScreen(),
        '/select_category': (context) => SelectCategoryScreen(),
        '/active_orders': (context) => ActiveOrdersScreen(),
        '/seller_all_orders': (context) => const SellerAllOrdersScreen(),
        '/seller_revenue': (context) => const SellerRevenueScreen(),
        '/total_customers': (context) => const TotalCustomersScreen(),
        '/seller_analytics': (context) => const SellerAnalyticsScreen(),
        '/seller_reviews': (context) => const SellerReviewsScreen(),
        '/seller_edit_profile': (context) => const SellerEditProfileScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Center(
            child: Text(
              'No Route Found: ${settings.name}',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}
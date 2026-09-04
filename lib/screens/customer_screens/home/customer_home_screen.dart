import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/banner_service.dart';
import '../../../services/session_service.dart';
import '../../../widgets/customer_shimmer_loading.dart';
import '../../chat/inbox_screen.dart';
import '../product/product_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  TextEditingController? _searchController;
  FocusNode? _searchFocusNode;

  String userName = "Customer";
  String userEmail = "";
  String? avatarUrl;

  // Selected category state
  String selectedCategory = "All";

  // Promo Vouchers State
  List<Map<String, dynamic>> promoCoupons = [];
  int activeBannerIndex = 0;
  final PageController _bannerController = PageController();

  // Categories list expanding to multi-category store
  final List<Map<String, dynamic>> categoryList = [
    {"name": "All", "icon": Icons.grid_view_rounded},
    {"name": "Clothes", "icon": Icons.checkroom_rounded},
    {"name": "Shoes", "icon": Icons.roller_skating_rounded},
    {"name": "Bags", "icon": Icons.shopping_bag_outlined},
    {"name": "Watches", "icon": Icons.watch_rounded},
    {"name": "Accessories", "icon": Icons.auto_awesome_rounded},
  ];

  // Products state
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  Set<String> wishlistIds = {};
  bool isLoadingProducts = true;

  // Realtime Notification State
  int notificationCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  // Navigation Bar Active Index
  int currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    fetchUserData();
    _setupRealtimeNotifications();
    fetchProducts();
    fetchCoupons();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _searchController?.dispose();
    _searchFocusNode?.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  // ================= FETCH USER DATA =================
  Future<void> fetchUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          userName = user.userMetadata?['name'] ??
              user.email?.split('@')[0] ??
              "Customer";
          userEmail = user.email ?? "";
          avatarUrl = user.userMetadata?['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  // ================= REALTIME NOTIFICATIONS =================
  void _setupRealtimeNotifications() {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final notificationStream = supabase.from('notifications').stream(
        primaryKey: ['id'],
      );

      _notificationSubscription = notificationStream.listen(
        (data) {
          if (!mounted) return;
          final unread = data.where((n) {
            final uid = n['user_id'];
            final isRead = n['is_read'];
            return (uid == user.id || uid == null) && (isRead == false || isRead == null);
          }).toList();

          setState(() {
            notificationCount = unread.length;
          });
        },
        onError: (error) => debugPrint("Notification stream error: $error"),
      );
    } catch (e) {
      debugPrint("Realtime notification setup error: $e");
    }
  }

  // ================= FETCH PRODUCTS FROM SUPABASE =================
  Future<void> fetchProducts() async {
    setState(() => isLoadingProducts = true);
    try {
      final data = await supabase
          .from('products')
          .select('*')
          .order('created_at', ascending: false);

      await fetchWishlist();

      if (!mounted) return;

      setState(() {
        products = List<Map<String, dynamic>>.from(data);
        _filterProducts();
        isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (!mounted) return;
      setState(() {
        products = _getFallbackProducts();
        _filterProducts();
        isLoadingProducts = false;
      });
    }
  }

  // Fallback demo multi-category products if Supabase table is empty or loading
  List<Map<String, dynamic>> _getFallbackProducts() {
    return [
      {
        "id": "demo_1",
        "name": "Gucci Ace Sneakers",
        "category": "Shoes",
        "price": 45000,
        "rating": 4.8,
        "reviews": 124,
        "image_url": "https://images.unsplash.com/photo-1549298916-b41d501d3772?auto=format&fit=crop&w=600&q=80",
        "description": "Premium leather sneakers with signature stripe."
      },
      {
        "id": "demo_2",
        "name": "YSL Sac de Jour Bag",
        "category": "Bags",
        "price": 85000,
        "rating": 4.9,
        "reviews": 89,
        "image_url": "https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&w=600&q=80",
        "description": "Luxury structured black calfskin leather handbag."
      },
      {
        "id": "demo_3",
        "name": "Rolex Submariner Watch",
        "category": "Watches",
        "price": 285000,
        "rating": 5.0,
        "reviews": 340,
        "image_url": "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=600&q=80",
        "description": "Oystersteel luxury automatic chronograph watch."
      },
      {
        "id": "demo_4",
        "name": "Burberry Cotton Trench Coat",
        "category": "Clothes",
        "price": 62000,
        "rating": 4.7,
        "reviews": 65,
        "image_url": "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=600&q=80",
        "description": "Classic double-breasted honey trench coat."
      },
    ];
  }

  Future<void> fetchWishlist() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final data = await supabase
          .from('wishlist')
          .select('product_id')
          .eq('user_id', user.id);
      wishlistIds = (data as List)
          .map((item) => item['product_id'].toString())
          .toSet();
    } catch (e) {
      debugPrint("Wishlist fetch error: $e");
    }
  }

  void _filterProducts() {
    final query = (_searchController?.text ?? "").trim().toLowerCase();

    filteredProducts = products.where((item) {
      final name = (item['name'] ?? "").toString().toLowerCase();
      final cat = (item['category'] ?? "").toString().toLowerCase();

      final matchesQuery = query.isEmpty || name.contains(query) || cat.contains(query);

      final matchesCategory = selectedCategory == "All" ||
          cat == selectedCategory.toLowerCase() ||
          _mapCategoryMatch(cat, selectedCategory);

      return matchesQuery && matchesCategory;
    }).toList();
  }

  bool _mapCategoryMatch(String productCategory, String selected) {
    final pc = productCategory.toLowerCase();
    final sc = selected.toLowerCase();

    if (sc == "clothes") {
      return pc.contains("shirt") || pc.contains("dress") || pc.contains("hoodie") || pc.contains("jacket") || pc.contains("jean") || pc.contains("suit");
    }
    if (sc == "shoes") {
      return pc.contains("shoe") || pc.contains("sneaker") || pc.contains("boot") || pc.contains("footwear");
    }
    if (sc == "bags") {
      return pc.contains("bag") || pc.contains("purse") || pc.contains("handbag") || pc.contains("wallet");
    }
    if (sc == "watches") {
      return pc.contains("watch") || pc.contains("clock") || pc.contains("chronograph");
    }
    if (sc == "accessories") {
      return pc.contains("accessory") || pc.contains("belt") || pc.contains("glasses") || pc.contains("ring");
    }
    return pc == sc;
  }

  void _handleSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _filterProducts();
    });
  }

  Future<void> _toggleWishlist(String productId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to manage wishlist")),
      );
      return;
    }

    final isFav = wishlistIds.contains(productId);
    setState(() {
      if (isFav) {
        wishlistIds.remove(productId);
      } else {
        wishlistIds.add(productId);
      }
    });

    try {
      if (isFav) {
        await supabase
            .from('wishlist')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', productId);
      } else {
        await supabase.from('wishlist').insert({
          'user_id': user.id,
          'product_id': productId,
        });
      }
    } catch (e) {
      debugPrint("Wishlist toggle error: $e");
    }
  }

  DateTime? _lastBackPressTime;

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If drawer is open, close drawer first
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // If on another bottom tab, return to Home tab
        if (currentNavIndex != 0) {
          setState(() => currentNavIndex = 0);
          return;
        }

        // Double press back to exit gracefully
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Press back again to exit StyLuxe",
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.slateDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: _buildModernDrawer(),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
            // ================= TOP DYNAMIC HEADER BAR =================
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(
                notificationCount: notificationCount,
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                onOpenNotifications: () {
                  Navigator.pushNamed(context, '/notifications');
                },
                onOpenCart: () => Navigator.pushNamed(context, '/cart'),
              ),
            ),

            // ================= MAIN CONTENT =================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar & Filter
                    _buildSearchBar(),

                    const SizedBox(height: 18),

                    // Multi-Category Chips Bar
                    _buildCategoryChips(),

                    const SizedBox(height: 20),

                    // Promo Banner Carousel
                    _buildPromoBanner(),

                    const SizedBox(height: 22),

                    // Section Header: Products
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedCategory == "All"
                              ? "Featured Products"
                              : "$selectedCategory Collection",
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/select_customer_category');
                          },
                          child: const Text(
                            "See All",
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ================= PRODUCT GRID =================
            if (isLoadingProducts)
              const SliverToBoxAdapter(
                child: CustomerProductsGridShimmer(itemCount: 6),
              )
            else if (filteredProducts.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppColors.slateMuted),
                        const SizedBox(height: 10),
                        Text(
                          "No products found in '$selectedCategory'",
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredProducts[index];
                      return _buildProductCard(item);
                    },
                    childCount: filteredProducts.length,
                  ),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).size.width >= 700 ? 180 : 135,
                    mainAxisExtent: MediaQuery.of(context).size.width >= 700 ? 230 : 178,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
        bottomNavigationBar: _buildFullWidthBottomNav(),
      ),
    );
  }

  // ================= SEARCH BAR =================
  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _handleSearch(),
        style: const TextStyle(
          color: AppColors.slateDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: "Search dresses, shoes, watches...",
          hintStyle: const TextStyle(
            color: AppColors.slateMuted,
            fontSize: 12.5,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.slateMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 34),
          suffixIcon: GestureDetector(
            onTap: _handleSearch,
            child: Container(
              margin: const EdgeInsets.fromLTRB(2, 3, 4, 3),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= MULTI-CATEGORY CHIPS =================
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categoryList.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categoryList[index];
          final String catName = cat['name'];
          final IconData icon = cat['icon'];
          final bool isSelected = selectedCategory.toLowerCase() == catName.toLowerCase();

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = catName;
                _filterProducts();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.slateMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    catName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.slateDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= FETCH PROMO COUPONS & BANNERS =================
  Future<void> fetchCoupons() async {
    try {
      final activeBanners = await BannerService.fetchActiveBanners();
      if (mounted && activeBanners.isNotEmpty) {
        setState(() {
          promoCoupons = activeBanners.map((b) => {
            "code": b.promoCode ?? 'STYLUXE',
            "title": b.title,
            "subtitle": b.subtitle,
            "discount_tag": b.discountTag,
            "bg_colors": b.gradientColors,
            "icon": b.iconData,
          }).toList();
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        promoCoupons = BannerService.defaultBanners.map((b) => {
          "code": b.promoCode ?? 'STYLUXE',
          "title": b.title,
          "subtitle": b.subtitle,
          "discount_tag": b.discountTag,
          "bg_colors": b.gradientColors,
          "icon": b.iconData,
        }).toList();
      });
    }
  }

  // ================= PROMO BANNER CAROUSEL =================
  Widget _buildPromoBanner() {
    if (promoCoupons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 156,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() => activeBannerIndex = index);
            },
            itemCount: promoCoupons.length,
            itemBuilder: (context, index) {
              final coupon = promoCoupons[index];
              final String code = coupon['code']?.toString() ?? 'STYLUXE';
              final String title = coupon['title']?.toString() ?? 'Special Discount';
              final String subtitle = coupon['subtitle']?.toString() ?? 'Get exclusive discounts today';
              final String discountTag = coupon['discount_tag']?.toString() ?? 'PROMO OFFER';
              final dynamic bgColorsRaw = coupon['bg_colors'];
              final List<Color> colors = (bgColorsRaw is List<Color>)
                  ? bgColorsRaw
                  : [AppColors.primary, AppColors.primaryDark];
              final IconData icon = (coupon['icon'] is IconData) ? coupon['icon'] : Icons.local_offer_rounded;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  discountTag.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Copied Coupon Code: $code"),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: AppColors.slateDark,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Code: $code",
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.copy_rounded, size: 10, color: AppColors.slateDark),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/shop_now');
                        },
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: colors.first,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Carousel Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            promoCoupons.length,
            (idx) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              width: activeBannerIndex == idx ? 20 : 6,
              decoration: BoxDecoration(
                color: activeBannerIndex == idx ? AppColors.primary : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= PRODUCT CARD =================
  Widget _buildProductCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? "";
    final name = item['name']?.toString() ?? "Product";
    final category = item['category']?.toString() ?? "General";

    final num rawPrice = num.tryParse(item['price']?.toString() ?? "0") ?? 0;
    // Format price strictly in PKR / Rs. (NO DOLLAR SIGN)
    final String formattedPrice = "Rs. ${rawPrice.toStringAsFixed(0)}";

    final String imageUrl = item['image_url']?.toString() ??
        (item['image_urls'] is List && (item['image_urls'] as List).isNotEmpty
            ? item['image_urls'][0].toString()
            : "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=600&q=80");

    final bool isFav = wishlistIds.contains(id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dedicated Full Fit Flexible Image Box (Adaptive to any screen size)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported_outlined, color: AppColors.slateMuted, size: 20),
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: Icon(Icons.image_not_supported_outlined, color: AppColors.slateMuted, size: 20),
                                ),
                              ),
                      ),
                    ),

                    // Category tag with Dark Glass Backdrop
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    // Wishlist heart button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _toggleWishlist(id),
                        child: Container(
                          height: 22,
                          width: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            size: 12,
                            color: isFav ? AppColors.roseRed : AppColors.slateMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: 1),

                  // Rating row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                      const SizedBox(width: 2),
                      const Text(
                        "4.8",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                      ),
                      Text(
                        " (120)",
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Price & Add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          formattedPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav() {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.home_rounded, label: "Home", index: 0, route: '/customer_home'),
            _navItem(icon: Icons.explore_outlined, label: "Explore", index: 1, route: '/shop_now'),
            _navItem(icon: Icons.favorite_border_rounded, label: "Wishlist", index: 2, route: '/wishlist'),
            _navItem(icon: Icons.shopping_cart_outlined, label: "Cart", index: 3, route: '/cart'),
            _navItem(icon: Icons.person_outline_rounded, label: "Profile", index: 4, route: '/my_profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required String route,
  }) {
    final bool isSelected = currentNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => currentNavIndex = index);
        if (index != 0) {
          Navigator.pushNamed(context, route);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================= MODERN NAVIGATION DRAWER =================
  Widget _buildModernDrawer() {
    final drawerWidth = (MediaQuery.of(context).size.width * 0.72).clamp(255.0, 285.0);
    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          // Drawer Header with User Profile Details
          UserAccountsDrawerHeader(
            margin: EdgeInsets.zero,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? const Text(
                      "S",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            accountName: Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              userEmail.isEmpty ? "StyLuxe Customer" : userEmail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),

          // Drawer Navigation Options (Scrollable together with Logout)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              children: [
                _drawerTile(
                  icon: Icons.home_rounded,
                  title: "Home",
                  onTap: () => Navigator.pop(context),
                ),
                _drawerTile(
                  icon: Icons.grid_view_rounded,
                  title: "Shop Categories",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/select_customer_category');
                  },
                ),
                _drawerTile(
                  icon: Icons.receipt_long_outlined,
                  title: "My Orders",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my_orders');
                  },
                ),
                _drawerTile(
                  icon: Icons.favorite_border_rounded,
                  title: "Wishlist",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/wishlist');
                  },
                ),
                _drawerTile(
                  icon: Icons.shopping_cart_outlined,
                  title: "My Cart",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/cart');
                  },
                ),
                _drawerTile(
                  icon: Icons.person_outline_rounded,
                  title: "My Profile",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my_profile');
                  },
                ),
                _drawerTile(
                  icon: Icons.notifications_outlined,
                  title: "Notifications",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                _drawerTile(
                  icon: Icons.forum_outlined,
                  title: "Chat",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: true)),
                    );
                  },
                ),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),
                _drawerTile(
                  icon: Icons.logout_rounded,
                  title: "Logout",
                  iconColor: AppColors.roseRed,
                  textColor: AppColors.roseRed,
                  tileColor: AppColors.roseRed.withValues(alpha: 0.08),
                  onTap: () async {
                    await SessionService.clearSession();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    Color? tileColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: tileColor,
        leading: Icon(icon, color: iconColor ?? AppColors.slateDark, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? AppColors.slateDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ================= DYNAMIC SHRINKING HOME HEADER DELEGATE =================
class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int notificationCount;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenCart;

  _HomeHeaderDelegate({
    required this.notificationCount,
    required this.onOpenDrawer,
    required this.onOpenNotifications,
    required this.onOpenCart,
  });

  @override
  double get maxExtent => 50.0;

  @override
  double get minExtent => 40.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    final double btnSize = 34.0 - (progress * 4.0); // 34 -> 30
    final double iconSize = 18.0 - (progress * 2.5); // 18 -> 15.5
    final double titleSize = 19.0 - (progress * 2.0); // 19 -> 17 (clearly visible, crisp bold)
    final double btnRadius = 10.0 - (progress * 2.0); // 10 -> 8

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: progress > 0.3
            ? Border(
                bottom: BorderSide(
                  color: const Color(0xFFE2E8F0).withValues(alpha: progress),
                  width: 1,
                ),
              )
            : null,
        boxShadow: progress > 0.3
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03 * progress),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Drawer Icon Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: btnSize, minHeight: btnSize),
            tooltip: "Open Menu",
            icon: Container(
              height: btnSize,
              width: btnSize,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(btnRadius),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: AppColors.slateDark,
                size: iconSize + 1,
              ),
            ),
            onPressed: onOpenDrawer,
          ),

          // Center Brand Title: StyLuxe
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "Sty",
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slateDark,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: "Luxe",
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Action Icons (Notifications + Cart)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: btnSize, minHeight: btnSize),
                    tooltip: "Notifications",
                    icon: Container(
                      height: btnSize,
                      width: btnSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(btnRadius),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.slateDark,
                        size: iconSize,
                      ),
                    ),
                    onPressed: onOpenNotifications,
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          notificationCount > 9 ? "9+" : notificationCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: btnSize, minHeight: btnSize),
                tooltip: "Cart",
                icon: Container(
                  height: btnSize,
                  width: btnSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(btnRadius),
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.slateDark,
                    size: iconSize,
                  ),
                ),
                onPressed: onOpenCart,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return oldDelegate.notificationCount != notificationCount;
  }
}
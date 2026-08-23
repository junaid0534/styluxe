import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../product/product_detail_screen.dart';

class ShopNowScreen extends StatefulWidget {
  const ShopNowScreen({super.key});

  @override
  State<ShopNowScreen> createState() => _ShopNowScreenState();
}

class _ShopNowScreenState extends State<ShopNowScreen> {
  final supabase = Supabase.instance.client;
  late final ScrollController _scrollController;

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  Set<String> wishlistProductIds = {};

  String selectedCategory = "All";
  String screenTitle = "Shop Now";
  String searchQuery = "";
  String selectedPriceSort = "default"; // "default", "low_to_high", "high_to_low"
  String selectedPriceRange = "all"; // "all", "under_1500", "1500_3000", "3000_5000", "above_5000"

  bool isLoading = true;
  bool _routeArgumentsLoaded = false;
  bool _isNavVisible = true;

  final List<String> categories = [
    "All",
    "Clothes",
    "Shoes",
    "Bags",
    "Watches",
    "Accessories",
    "Dresses",
    "Suits",
    "Kids Wear",
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isNavVisible) {
        setState(() => _isNavVisible = false);
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_routeArgumentsLoaded) {
      _routeArgumentsLoaded = true;

      final args = ModalRoute.of(context)?.settings.arguments;

      if (args != null) {
        if (args is String) {
          selectedCategory = _normalizeCategory(args);
          screenTitle = args;
        } else if (args is Map) {
          final title = args['title']?.toString();
          final category = args['category']?.toString();
          final search = args['searchQuery']?.toString();

          if (search != null && search.trim().isNotEmpty) {
            searchQuery = search.trim();
            _searchController.text = searchQuery;
          }

          screenTitle =
              title == null || title.trim().isEmpty ? "Shop Now" : title.trim();

          if (category != null && category.trim().isNotEmpty) {
            selectedCategory = _normalizeCategory(category);
          } else if (title != null && title.trim().isNotEmpty) {
            selectedCategory = _normalizeCategory(title);
          }
        }
      }

      fetchProducts();
    }
  }

  // ================= NORMALIZE CATEGORY =================
  String _normalizeCategory(String value) {
    final category = value.trim().toLowerCase();

    switch (category) {
      case "all":
        return "All";
      case "clothes":
      case "clothing":
      case "cloth":
        return "Clothes";
      case "shoe":
      case "shoes":
      case "sneaker":
      case "footwear":
        return "Shoes";
      case "bag":
      case "bags":
      case "handbag":
      case "purse":
        return "Bags";
      case "watch":
      case "watches":
        return "Watches";
      case "accessory":
      case "accessories":
        return "Accessories";
      case "dress":
      case "dresses":
        return "Dresses";
      case "suit":
      case "suits":
        return "Suits";
      case "kids wear":
      case "kidswear":
      case "kids":
        return "Kids Wear";
      default:
        return value.trim();
    }
  }

  bool _isProductActive(Map<String, dynamic> product) {
    final active = product['is_active'];
    if (active == null) return true;
    if (active == true || active == 1) return true;
    if (active.toString().toLowerCase() == "true") return true;
    return false;
  }

  // ================= FETCH PRODUCTS =================
  Future<void> fetchProducts() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final data = await supabase
          .from('products')
          .select('*')
          .order('created_at', ascending: false);

      await fetchWishlistIds();

      if (!mounted) return;

      setState(() {
        allProducts = List<Map<String, dynamic>>.from(data)
            .where((product) => _isProductActive(product))
            .toList();

        filterProducts(updateState: false);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Shop Products Error: $e");

      if (!mounted) return;

      setState(() {
        allProducts = _getFallbackShopProducts();
        filterProducts(updateState: false);
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFallbackShopProducts() {
    return [
      {
        "id": "shop_1",
        "name": "Gucci Ace Sneakers",
        "category": "Shoes",
        "price": 45000,
        "stock": 10,
        "image_url": "https://images.unsplash.com/photo-1549298916-b41d501d3772?auto=format&fit=crop&w=600&q=80",
      },
      {
        "id": "shop_2",
        "name": "YSL Sac de Jour Bag",
        "category": "Bags",
        "price": 85000,
        "stock": 5,
        "image_url": "https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&w=600&q=80",
      },
      {
        "id": "shop_3",
        "name": "Rolex Submariner Watch",
        "category": "Watches",
        "price": 285000,
        "stock": 3,
        "image_url": "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=600&q=80",
      },
      {
        "id": "shop_4",
        "name": "Burberry Trench Coat",
        "category": "Clothes",
        "price": 62000,
        "stock": 8,
        "image_url": "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=600&q=80",
      },
    ];
  }

  // ================= FETCH WISHLIST IDS =================
  Future<void> fetchWishlistIds() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final data = await supabase
          .from('wishlist')
          .select('product_id')
          .eq('user_id', currentUser.id);

      final ids = List<Map<String, dynamic>>.from(data)
          .map((item) => item['product_id'].toString())
          .toSet();

      if (!mounted) return;
      setState(() => wishlistProductIds = ids);
    } catch (e) {
      debugPrint("Fetch wishlist ids error: $e");
    }
  }

  // ================= FILTER PRODUCTS =================
  void filterProducts({bool updateState = true}) {
    final selectedNorm = _normalizeCategory(selectedCategory).toLowerCase();

    final filtered = allProducts.where((product) {
      final name = (product['name'] ?? "").toString().toLowerCase();
      final category = (product['category'] ?? "").toString().toLowerCase();
      final double price = (product['price'] as num?)?.toDouble() ?? 0.0;

      final matchesSearch = searchQuery.isEmpty ||
          name.contains(searchQuery.toLowerCase()) ||
          category.contains(searchQuery.toLowerCase());

      final matchesCategory = selectedNorm == "all" ||
          category == selectedNorm ||
          _matchesMultiCategory(category, selectedNorm);

      bool matchesPrice = true;
      if (selectedPriceRange == "under_1500") {
        matchesPrice = price <= 1500;
      } else if (selectedPriceRange == "1500_3000") {
        matchesPrice = price >= 1500 && price <= 3000;
      } else if (selectedPriceRange == "3000_5000") {
        matchesPrice = price >= 3000 && price <= 5000;
      } else if (selectedPriceRange == "above_5000") {
        matchesPrice = price >= 5000;
      }

      return matchesSearch && matchesCategory && matchesPrice;
    }).toList();

    // Price Sorting
    if (selectedPriceSort == "low_to_high") {
      filtered.sort((a, b) {
        final pa = (a['price'] as num?)?.toDouble() ?? 0.0;
        final pb = (b['price'] as num?)?.toDouble() ?? 0.0;
        return pa.compareTo(pb);
      });
    } else if (selectedPriceSort == "high_to_low") {
      filtered.sort((a, b) {
        final pa = (a['price'] as num?)?.toDouble() ?? 0.0;
        final pb = (b['price'] as num?)?.toDouble() ?? 0.0;
        return pb.compareTo(pa);
      });
    }

    if (updateState) {
      setState(() {
        filteredProducts = filtered;
      });
    } else {
      filteredProducts = filtered;
    }
  }

  bool _matchesMultiCategory(String productCategory, String selected) {
    if (selected == "clothes") {
      return productCategory.contains("shirt") ||
          productCategory.contains("dress") ||
          productCategory.contains("hoodie") ||
          productCategory.contains("jacket") ||
          productCategory.contains("jean") ||
          productCategory.contains("suit");
    }
    if (selected == "shoes") {
      return productCategory.contains("shoe") ||
          productCategory.contains("sneaker") ||
          productCategory.contains("footwear");
    }
    if (selected == "bags") {
      return productCategory.contains("bag") ||
          productCategory.contains("purse") ||
          productCategory.contains("handbag");
    }
    if (selected == "watches") {
      return productCategory.contains("watch") ||
          productCategory.contains("clock");
    }
    return productCategory.contains(selected);
  }

  void openProductDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  // ================= ADD TO CART =================
  Future<void> addToCart(Map<String, dynamic> product) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Please login first");

      final productId = product['id'];

      final existingCart = await supabase
          .from('cart')
          .select('*')
          .eq('user_id', currentUser.id)
          .eq('product_id', productId)
          .maybeSingle();

      if (existingCart != null) {
        final currentQty = (existingCart['quantity'] as num).toInt();
        await supabase
            .from('cart')
            .update({'quantity': currentQty + 1})
            .eq('id', existingCart['id']);
      } else {
        await supabase.from('cart').insert({
          'user_id': currentUser.id,
          'product_id': productId,
          'quantity': 1,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${product['name']} added to cart!"),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      debugPrint("Add To Cart Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= TOGGLE WISHLIST =================
  Future<void> toggleWishlist(Map<String, dynamic> product) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Please login first");

      final productIdText = product['id'].toString();
      final alreadyWishlisted = wishlistProductIds.contains(productIdText);

      setState(() {
        if (alreadyWishlisted) {
          wishlistProductIds.remove(productIdText);
        } else {
          wishlistProductIds.add(productIdText);
        }
      });

      if (alreadyWishlisted) {
        await supabase
            .from('wishlist')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('product_id', product['id']);
      } else {
        await supabase.from('wishlist').insert({
          'user_id': currentUser.id,
          'product_id': product['id'],
        });
      }
    } catch (e) {
      debugPrint("Wishlist Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          screenTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.slateDark,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Wishlist",
            icon: const Icon(Icons.favorite_border_rounded, color: AppColors.slateDark, size: 22),
            onPressed: () {
              Navigator.pushNamed(context, '/wishlist').then((_) => fetchWishlistIds());
            },
          ),
          IconButton(
            tooltip: "Cart",
            icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.slateDark, size: 22),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Category Dropdown Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  // 1. Search Bar (Expanded)
                  Expanded(
                    child: Container(
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
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          searchQuery = value.trim();
                          filterProducts();
                        },
                        style: const TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slateMuted, size: 18),
                          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.slateMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    searchQuery = "";
                                    filterProducts();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Category Dropdown Selector
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: selectedCategory == "All" ? Colors.white : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedCategory == "All" ? const Color(0xFFE2E8F0) : AppColors.primary,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selectedCategory == "All"
                              ? Colors.black.withValues(alpha: 0.03)
                              : AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (String cat) {
                        setState(() {
                          selectedCategory = cat;
                          screenTitle = cat == "All" ? "Shop Now" : cat;
                        });
                        filterProducts();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: Colors.white,
                      elevation: 8,
                      offset: const Offset(0, 44),
                      itemBuilder: (BuildContext context) {
                        return categories.map((String cat) {
                          final isSelected = _normalizeCategory(cat).toLowerCase() == _normalizeCategory(selectedCategory).toLowerCase();
                          return PopupMenuItem<String>(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.category_outlined,
                                  size: 16,
                                  color: isSelected ? AppColors.primary : AppColors.slateMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.slateDark,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: selectedCategory == "All" ? AppColors.slateDark : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            selectedCategory == "All" ? "Category" : selectedCategory,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: selectedCategory == "All" ? AppColors.slateDark : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: selectedCategory == "All" ? AppColors.slateMuted : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. Price Filter Dropdown Selector
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _hasActivePriceFilter() ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hasActivePriceFilter() ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _hasActivePriceFilter()
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (String val) {
                        setState(() {
                          if (val.startsWith("sort_")) {
                            if (val == "sort_low_high") {
                              selectedPriceSort = "low_to_high";
                            } else if (val == "sort_high_low") {
                              selectedPriceSort = "high_to_low";
                            } else {
                              selectedPriceSort = "default";
                            }
                          } else if (val.startsWith("range_")) {
                            selectedPriceRange = val.replaceFirst("range_", "");
                          }
                        });
                        filterProducts();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: Colors.white,
                      elevation: 8,
                      offset: const Offset(0, 44),
                      itemBuilder: (BuildContext context) {
                        return [
                          const PopupMenuItem<String>(
                            enabled: false,
                            child: Text(
                              "SORT BY PRICE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slateMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: "sort_default",
                            child: Row(
                              children: [
                                Icon(
                                  selectedPriceSort == "default" ? Icons.check_circle_rounded : Icons.swap_vert_rounded,
                                  size: 16,
                                  color: selectedPriceSort == "default" ? AppColors.primary : AppColors.slateMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Default Order",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selectedPriceSort == "default" ? FontWeight.w700 : FontWeight.w500,
                                    color: selectedPriceSort == "default" ? AppColors.primary : AppColors.slateDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: "sort_low_high",
                            child: Row(
                              children: [
                                Icon(
                                  selectedPriceSort == "low_to_high" ? Icons.check_circle_rounded : Icons.arrow_upward_rounded,
                                  size: 16,
                                  color: selectedPriceSort == "low_to_high" ? AppColors.primary : AppColors.slateMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Price: Low to High",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selectedPriceSort == "low_to_high" ? FontWeight.w700 : FontWeight.w500,
                                    color: selectedPriceSort == "low_to_high" ? AppColors.primary : AppColors.slateDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: "sort_high_low",
                            child: Row(
                              children: [
                                Icon(
                                  selectedPriceSort == "high_to_low" ? Icons.check_circle_rounded : Icons.arrow_downward_rounded,
                                  size: 16,
                                  color: selectedPriceSort == "high_to_low" ? AppColors.primary : AppColors.slateMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Price: High to Low",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selectedPriceSort == "high_to_low" ? FontWeight.w700 : FontWeight.w500,
                                    color: selectedPriceSort == "high_to_low" ? AppColors.primary : AppColors.slateDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem<String>(
                            enabled: false,
                            child: Text(
                              "FILTER BY PRICE RANGE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slateMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          _buildPriceRangeMenuItem("range_all", "All Prices", selectedPriceRange == "all"),
                          _buildPriceRangeMenuItem("range_under_1500", "Under Rs. 1,500", selectedPriceRange == "under_1500"),
                          _buildPriceRangeMenuItem("range_1500_3000", "Rs. 1,500 - Rs. 3,000", selectedPriceRange == "1500_3000"),
                          _buildPriceRangeMenuItem("range_3000_5000", "Rs. 3,000 - Rs. 5,000", selectedPriceRange == "3000_5000"),
                          _buildPriceRangeMenuItem("range_above_5000", "Above Rs. 5,000", selectedPriceRange == "above_5000"),
                        ];
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 14,
                            color: _hasActivePriceFilter() ? Colors.white : AppColors.slateDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getPriceFilterLabel(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _hasActivePriceFilter() ? Colors.white : AppColors.slateDark,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: _hasActivePriceFilter() ? Colors.white : AppColors.slateMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Grid View
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : filteredProducts.isEmpty
                      ? _emptyView()
                      : RefreshIndicator(
                          onRefresh: fetchProducts,
                          color: AppColors.primary,
                          child: GridView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            itemCount: filteredProducts.length,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 130,
                              mainAxisExtent: 172,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              final productId = product['id'].toString();

                              return ProductCardItem(
                                product: product,
                                isWishlisted: wishlistProductIds.contains(productId),
                                onOpenProduct: openProductDetail,
                                onAddToCart: addToCart,
                                onWishlistToggle: toggleWishlist,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: _isNavVisible ? 50 : 0,
          child: _buildFullWidthBottomNav(1),
        ),
      ),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
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
            _navItem(icon: Icons.home_rounded, label: "Home", index: 0, route: '/customer_home', activeIndex: activeIndex),
            _navItem(icon: Icons.explore_outlined, label: "Explore", index: 1, route: '/shop_now', activeIndex: activeIndex),
            _navItem(icon: Icons.favorite_border_rounded, label: "Wishlist", index: 2, route: '/wishlist', activeIndex: activeIndex),
            _navItem(icon: Icons.shopping_cart_outlined, label: "Cart", index: 3, route: '/cart', activeIndex: activeIndex),
            _navItem(icon: Icons.person_outline_rounded, label: "Profile", index: 4, route: '/my_profile', activeIndex: activeIndex),
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
    required int activeIndex,
  }) {
    final bool isSelected = activeIndex == index;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
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

  String _getPriceFilterLabel() {
    if (selectedPriceSort == "low_to_high") return "Low-High";
    if (selectedPriceSort == "high_to_low") return "High-Low";
    if (selectedPriceRange == "under_1500") return "< 1.5k";
    if (selectedPriceRange == "1500_3000") return "1.5k-3k";
    if (selectedPriceRange == "3000_5000") return "3k-5k";
    if (selectedPriceRange == "above_5000") return "> 5k";
    return "Price";
  }

  bool _hasActivePriceFilter() {
    return selectedPriceSort != "default" || selectedPriceRange != "all";
  }

  PopupMenuItem<String> _buildPriceRangeMenuItem(String value, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle_rounded : Icons.label_outlined,
            size: 18,
            color: isSelected ? AppColors.primary : AppColors.slateMuted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.slateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.slateMuted),
              const SizedBox(height: 12),
              const Text(
                "No Products Found",
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedCategory == "All"
                    ? "No products available right now."
                    : "No products available in $selectedCategory right now.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slateMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= COMPACT PRODUCT CARD ITEM WITH TALL UNCROPPED IMAGE =================
class ProductCardItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isWishlisted;
  final Function(Map<String, dynamic>) onOpenProduct;
  final Function(Map<String, dynamic>) onAddToCart;
  final Function(Map<String, dynamic>) onWishlistToggle;

  const ProductCardItem({
    super.key,
    required this.product,
    required this.isWishlisted,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onWishlistToggle,
  });

  @override
  Widget build(BuildContext context) {
    final String name = product['name']?.toString() ?? 'Product';
    final String imageUrl = product['image_url']?.toString() ??
        (product['image_urls'] is List && (product['image_urls'] as List).isNotEmpty
            ? product['image_urls'][0].toString()
            : '');
    final String category = product['category']?.toString() ?? 'General';
    final num rawPrice = (product['price'] as num?) ?? 0;
    // Format strictly in Rs. (PKR) without $ sign
    final String formattedPrice = "Rs. ${rawPrice.toStringAsFixed(0)}";
    final int stock = (product['stock'] as num?)?.toInt() ?? 10;

    return InkWell(
      onTap: () => onOpenProduct(product),
      borderRadius: BorderRadius.circular(16),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dedicated Full Fit AspectRatio Image Box
            AspectRatio(
              aspectRatio: 1.05,
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
                                errorBuilder: (_, _, _) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                    ),

                    // Category Badge with Dark Glass Backdrop
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

                    // Wishlist Heart Button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onWishlistToggle(product),
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
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            size: 12,
                            color: isWishlisted ? AppColors.roseRed : AppColors.slateDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Product Details Section
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
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                      SizedBox(width: 2),
                      Text(
                        "4.8",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                      ),
                      Text(
                        " (98)",
                        style: TextStyle(
                          fontSize: 8,
                          color: AppColors.slateMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Price & Cart button
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
                      GestureDetector(
                        onTap: stock > 0 ? () => onAddToCart(product) : null,
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                            color: stock > 0 ? AppColors.primary : AppColors.slateMuted,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
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
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.slateMuted, size: 28),
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/chat_service.dart';
import '../../chat/chat_room_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final supabase = Supabase.instance.client;
  final PageController _pageController = PageController();

  List<String> productImages = [];
  bool isLoadingImages = true;
  bool isAddingToCart = false;
  bool isWishlisted = false;
  int selectedImageIndex = 0;
  int selectedQuantity = 1;
  int cartItemCount = 0;
  bool isDescriptionExpanded = false;
  Timer? _autoSlideTimer;

  // ================= VERIFIED REVIEWS STATE =================
  List<Map<String, dynamic>> productReviews = [];
  bool isLoadingReviews = true;
  bool canUserReview = false;
  String? eligibleOrderId;
  double averageRating = 4.8;
  int totalReviewCount = 0;

  int? _liveStock;
  StreamSubscription? _reviewsSubscription;
  StreamSubscription? _stockSubscription;

  String? selectedColor;
  String? selectedSize;
  List<String> availableColors = [];
  List<String> availableSizes = [];

  @override
  void initState() {
    super.initState();
    _liveStock = (widget.product['stock'] as num?)?.toInt();
    _initVariations();
    fetchLiveStock();
    _subscribeRealtimeStock();
    fetchProductImages();
    checkWishlist();
    fetchCartCount();
    fetchProductReviews();
    checkReviewEligibility();
    _subscribeRealtimeReviews();
  }

  void _initVariations() {
    final rawColor = widget.product['color']?.toString() ?? '';
    if (rawColor.isNotEmpty) {
      availableColors = rawColor
          .split(RegExp(r'[,|/•]+'))
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (availableColors.isNotEmpty) {
        selectedColor = availableColors.first;
      }
    }

    final rawSize = widget.product['size']?.toString() ?? '';
    if (rawSize.isNotEmpty) {
      availableSizes = rawSize
          .split(RegExp(r'[,|/•]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (availableSizes.isNotEmpty) {
        selectedSize = availableSizes.first;
      }
    }
  }

  Color _getColorFromName(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('black')) return const Color(0xFF1E293B);
    if (n.contains('white')) return const Color(0xFFF1F5F9);
    if (n.contains('navy')) return const Color(0xFF1E3A8A);
    if (n.contains('royal')) return const Color(0xFF2563EB);
    if (n.contains('blue')) return const Color(0xFF3B82F6);
    if (n.contains('maroon')) return const Color(0xFF881337);
    if (n.contains('red')) return const Color(0xFFDC2626);
    if (n.contains('brown')) return const Color(0xFF78350F);
    if (n.contains('beige')) return const Color(0xFFD4B996);
    if (n.contains('sage') || (n.contains('grey') && n.contains('sage'))) return const Color(0xFF9CA3AF);
    if (n.contains('emerald') || n.contains('green')) return const Color(0xFF059669);
    if (n.contains('purple')) return const Color(0xFF9333EA);
    if (n.contains('pink')) return const Color(0xFFEC4899);
    if (n.contains('yellow')) return const Color(0xFFEAB308);
    if (n.contains('olive')) return const Color(0xFF65A30D);
    if (n.contains('gold')) return const Color(0xFFCA8A04);
    if (n.contains('grey') || n.contains('gray')) return const Color(0xFF64748B);
    if (n.contains('orange')) return const Color(0xFFEA580C);
    if (n.contains('teal')) return const Color(0xFF0D9488);
    return const Color(0xFF2563EB);
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    _reviewsSubscription?.cancel();
    _stockSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchLiveStock() async {
    try {
      final res = await supabase
          .from('products')
          .select('stock, is_active')
          .eq('id', productId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _liveStock = (res['stock'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  void _subscribeRealtimeStock() {
    try {
      _stockSubscription = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('id', productId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              final first = data.first;
              setState(() {
                _liveStock = (first['stock'] as num?)?.toInt() ?? 0;
              });
            }
          });
    } catch (_) {}
  }

  void _subscribeRealtimeReviews() {
    try {
      _reviewsSubscription = supabase
          .from('product_reviews')
          .stream(primaryKey: ['id'])
          .eq('product_id', widget.product['id'])
          .listen((data) {
            if (mounted) {
              fetchProductReviews();
            }
          });
    } catch (_) {}
  }

  String get productId => widget.product['id'].toString();
  String get name => widget.product['name']?.toString() ?? 'Product';
  String get imageUrl => widget.product['image_url']?.toString() ?? '';
  String get category => widget.product['category']?.toString() ?? '';
  String get color => widget.product['color']?.toString() ?? '';
  String get size => widget.product['size']?.toString() ?? '';
  String get description => widget.product['description']?.toString() ?? '';
  double get price => (widget.product['price'] as num?)?.toDouble() ?? 0.0;
  int get stock => _liveStock ?? (widget.product['stock'] as num?)?.toInt() ?? 0;
  bool get inStock => stock > 0;

  // Format price strictly as Rs. (PKR) without $ sign
  String get formattedPrice => "Rs. ${price.toStringAsFixed(0)}";
  String get originalPrice => "Rs. ${(price * 1.20).toStringAsFixed(0)}";

  // ================= FETCH CART COUNT =================
  Future<void> fetchCartCount() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;
      final data = await supabase
          .from('cart')
          .select('id')
          .eq('user_id', currentUser.id);
      if (mounted) {
        setState(() {
          cartItemCount = (data as List).length;
        });
      }
    } catch (_) {}
  }

  // ================= FETCH ALL PRODUCT IMAGES =================
  Future<void> fetchProductImages() async {
    try {
      final data = await supabase
          .from('product_images')
          .select('image_url, sort_order')
          .eq('product_id', widget.product['id'])
          .order('sort_order', ascending: true);

      final urls = List<Map<String, dynamic>>.from(data)
          .map((item) => item['image_url']?.toString() ?? '')
          .where((url) => url.trim().isNotEmpty)
          .toList();

      if (urls.isEmpty && imageUrl.trim().isNotEmpty) {
        urls.add(imageUrl);
      }

      if (!mounted) return;
      setState(() {
        productImages = urls;
        isLoadingImages = false;
      });

      if (productImages.length > 1) {
        _startAutoSlider();
      }
    } catch (e) {
      debugPrint("Fetch Product Images Error: $e");
      if (!mounted) return;
      setState(() {
        productImages = imageUrl.trim().isEmpty ? [] : [imageUrl];
        isLoadingImages = false;
      });
      if (productImages.length > 1) {
        _startAutoSlider();
      }
    }
  }

  // ================= AUTO SLIDER TIMER (4 SECONDS) =================
  void _startAutoSlider() {
    _autoSlideTimer?.cancel();
    if (productImages.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_pageController.hasClients || productImages.length <= 1) return;
      final nextIndex = (selectedImageIndex + 1) % productImages.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // ================= CHECK WISHLIST =================
  Future<void> checkWishlist() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final data = await supabase
          .from('wishlist')
          .select('id')
          .eq('user_id', currentUser.id)
          .eq('product_id', widget.product['id'])
          .maybeSingle();

      if (!mounted) return;
      setState(() => isWishlisted = data != null);
    } catch (e) {
      debugPrint("Check Wishlist Error: $e");
    }
  }

  // ================= TOGGLE WISHLIST =================
  Future<void> toggleWishlist() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Please login first");

      if (isWishlisted) {
        await supabase
            .from('wishlist')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('product_id', widget.product['id']);

        if (!mounted) return;
        setState(() => isWishlisted = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Removed from wishlist"),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      } else {
        await supabase.from('wishlist').insert({
          'user_id': currentUser.id,
          'product_id': widget.product['id'],
        });

        if (!mounted) return;
        setState(() => isWishlisted = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added to wishlist"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint("Wishlist Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= ADD TO CART =================
  Future<void> addToCart() async {
    if (!inStock) return;
    setState(() => isAddingToCart = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Please login first");

      if (selectedColor == null && availableColors.isNotEmpty) {
        selectedColor = availableColors.first;
      }
      if (selectedSize == null && availableSizes.isNotEmpty) {
        selectedSize = availableSizes.first;
      }

      final existingCartRows = await supabase
          .from('cart')
          .select('id, quantity, selected_color, selected_size')
          .eq('user_id', currentUser.id)
          .eq('product_id', widget.product['id']);

      Map<String, dynamic>? existingCartItem;
      for (final row in existingCartRows) {
        final rColor = row['selected_color']?.toString();
        final rSize = row['selected_size']?.toString();
        if ((rColor ?? '') == (selectedColor ?? '') && (rSize ?? '') == (selectedSize ?? '')) {
          existingCartItem = row;
          break;
        }
      }

      if (existingCartItem != null) {
        final oldQty = (existingCartItem['quantity'] as num?)?.toInt() ?? 1;
        try {
          await supabase.from('cart').update({
            'quantity': oldQty + selectedQuantity,
            if (selectedSize != null && selectedSize!.isNotEmpty) 'selected_size': selectedSize,
            if (selectedColor != null && selectedColor!.isNotEmpty) 'selected_color': selectedColor,
          }).eq('id', existingCartItem['id']);
        } catch (_) {
          await supabase.from('cart').update({
            'quantity': oldQty + selectedQuantity,
          }).eq('id', existingCartItem['id']);
        }
      } else {
        try {
          await supabase.from('cart').insert({
            'user_id': currentUser.id,
            'product_id': widget.product['id'],
            'quantity': selectedQuantity,
            if (selectedSize != null && selectedSize!.isNotEmpty) 'selected_size': selectedSize,
            if (selectedColor != null && selectedColor!.isNotEmpty) 'selected_color': selectedColor,
          });
        } catch (_) {
          await supabase.from('cart').insert({
            'user_id': currentUser.id,
            'product_id': widget.product['id'],
            'quantity': selectedQuantity,
          });
        }
      }

      await fetchCartCount();

      if (!mounted) return;
      final variantLabel = [
        if (selectedColor != null && selectedColor!.isNotEmpty) selectedColor,
        if (selectedSize != null && selectedSize!.isNotEmpty) "Size: $selectedSize",
      ].join(", ");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$selectedQuantity × $name ${variantLabel.isNotEmpty ? "($variantLabel)" : ""} added to cart!"),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pushNamed(context, '/cart');
    } catch (e) {
      debugPrint("Add To Cart Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }

    if (mounted) setState(() => isAddingToCart = false);
  }

  void openZoomViewer(int index) {
    if (productImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductImageZoomScreen(
          images: productImages,
          initialIndex: index,
          productName: name,
        ),
      ),
    );
  }

  void changeImage(int index) {
    if (index < 0 || index >= productImages.length) return;
    setState(() => selectedImageIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slateDark, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Product Details",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: "Cart",
                      icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.slateDark, size: 18),
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                    ),
                  ),
                  if (cartItemCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEA580C),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$cartItemCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomAddToCartBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isWide ? 28 : 16,
            12,
            isWide ? 28 : 16,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1150),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _gallerySection()),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _detailsSection()),
                      ],
                    )
                  : Column(
                      children: [
                        _gallerySection(),
                        const SizedBox(height: 16),
                        _detailsSection(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= GALLERY SECTION (4s Auto-Slider, Full Card Fit) =================
  Widget _gallerySection() {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: isLoadingImages
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : productImages.isEmpty
              ? _imagePlaceholder()
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: productImages.length,
                      onPageChanged: (index) {
                        setState(() => selectedImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final url = productImages[index];

                        return GestureDetector(
                          onTap: () => openZoomViewer(index),
                          child: Hero(
                            tag: "product_image_${productId}_$index",
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.white,
                              child: Image.network(
                                url,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain, // Full card fit without crop/cut
                                alignment: Alignment.center,
                                errorBuilder: (_, _, _) => _imagePlaceholder(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Tap to Zoom Badge
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: GestureDetector(
                        onTap: () => openZoomViewer(selectedImageIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text(
                                "Tap to zoom",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Page Dots Indicator (Center bottom)
                    if (productImages.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            productImages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: selectedImageIndex == index ? 14 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: selectedImageIndex == index
                                    ? AppColors.primary
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Future<void> _startChatWithSeller() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please login to chat directly with this seller."),
          backgroundColor: AppColors.slateDark,
        ),
      );
      return;
    }

    String? targetSellerId = widget.product['seller_id']?.toString() ?? widget.product['user_id']?.toString();
    if (targetSellerId == null || targetSellerId.isEmpty || targetSellerId == 'null') {
      targetSellerId = "seller_default";
    }

    // Don't chat with self
    if (currentUser.id == targetSellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This is your own product listing."),
          backgroundColor: AppColors.slateDark,
        ),
      );
      return;
    }

    // Current Customer Name
    String custName = "Customer";
    final metaName = currentUser.userMetadata?['name']?.toString() ?? currentUser.userMetadata?['full_name']?.toString();
    if (metaName != null && metaName.trim().isNotEmpty) {
      custName = metaName.trim();
    } else if (currentUser.email != null) {
      custName = currentUser.email!.split('@').first;
    }

    // Seller Name
    final sellerName = (widget.product['store_name'] ?? widget.product['seller_name'] ?? "StyLuxe Verified Seller").toString();

    final conv = await ChatService.getOrCreateConversation(
      customerId: currentUser.id,
      sellerId: targetSellerId,
      customerName: custName,
      sellerName: sellerName,
      productId: widget.product['id']?.toString(),
      productName: name,
      productImage: productImages.isNotEmpty ? productImages.first : null,
      productPrice: formattedPrice,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversation: conv,
          isCustomer: true,
        ),
      ),
    );
  }

  // ================= DETAILS SECTION =================
  Widget _detailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _productInfoCard(),
        const SizedBox(height: 12),
        _sellerStoreCard(),
        const SizedBox(height: 12),
        _verifiedReviewsSection(),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  // ================= PRODUCT INFO CARD (Title -> Price -> Description -> Chips) =================
  Widget _productInfoCard() {
    final cleanDesc = description.trim().isEmpty
        ? "No description provided for this luxury product."
        : description.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title + Floating Heart (Wishlist) Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.slateDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Circular Wishlist Button
              InkWell(
                onTap: toggleWishlist,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isWishlisted ? const Color(0xFFEF4444) : AppColors.slateDark,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 2. Price & Rating Row
          Row(
            children: [
              // Price in Emerald Primary Accent
              Text(
                formattedPrice,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),

              // Original Strikethrough Price
              Text(
                originalPrice,
                style: const TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),

              // Discount Tag Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.slateDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "20%",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const Spacer(),

              // Rating Tag
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 17),
                  const SizedBox(width: 3),
                  Text(
                    "${averageRating.toStringAsFixed(1)} Rating",
                    style: const TextStyle(
                      color: AppColors.slateDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),

          // 3. Description (Directly Below Price)
          const Text(
            "Description",
            style: TextStyle(
              color: AppColors.slateDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cleanDesc,
            maxLines: isDescriptionExpanded ? null : 3,
            overflow: isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.slateMuted,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (cleanDesc.length > 100) ...[
            const SizedBox(height: 3),
            InkWell(
              onTap: () {
                setState(() => isDescriptionExpanded = !isDescriptionExpanded);
              },
              child: Text(
                isDescriptionExpanded ? "Read Less" : "Read More",
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),

          // 4. Interactive Variation Selectors (Color & Size)
          if (availableColors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette_outlined, size: 15, color: AppColors.primary),
                    const SizedBox(width: 5),
                    const Text("Select Color:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text(selectedColor ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (availableColors.length > 3)
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedColor,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
                        items: availableColors.map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: _getColorFromName(c), shape: BoxShape.circle, border: Border.all(color: Colors.black12))),
                              const SizedBox(width: 6),
                              Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                            ],
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedColor = val);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableColors.map((c) {
                final isSel = selectedColor == c;
                final clr = _getColorFromName(c);
                return GestureDetector(
                  onTap: () => setState(() => selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: isSel ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: clr,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c,
                          style: TextStyle(
                            color: isSel ? AppColors.primary : AppColors.slateDark,
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (isSel) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_rounded, size: 13, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (availableSizes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.straighten_outlined, size: 15, color: Color(0xFF0891B2)),
                    const SizedBox(width: 5),
                    const Text("Select Size:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text(selectedSize ?? '', style: const TextStyle(color: Color(0xFF0891B2), fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (availableSizes.length > 5)
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSize,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0891B2)),
                        items: availableSizes.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedSize = val);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSizes.map((s) {
                final isSel = selectedSize == s;
                return ChoiceChip(
                  label: Text(s, style: TextStyle(color: isSel ? Colors.white : AppColors.slateDark, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  selected: isSel,
                  selectedColor: const Color(0xFF0891B2),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(color: isSel ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0)),
                  onSelected: (sel) {
                    if (sel) setState(() => selectedSize = s);
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),

          // 5. Detail Attributes Chips (Category, Stock)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (category.trim().isNotEmpty)
                _detailChip(
                  icon: Icons.category_outlined,
                  title: "Category",
                  value: category,
                  color: const Color(0xFF4F46E5),
                ),
              _detailChip(
                icon: Icons.inventory_2_outlined,
                title: "Stock",
                value: stock > 0 ? "$stock in stock" : "Out of stock",
                color: inStock ? AppColors.primary : AppColors.roseRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= SELLER STORE CARD =================
  Widget _sellerStoreCard() {
    final sellerName = (widget.product['store_name'] ?? widget.product['seller_name'] ?? "StyLuxe Official Studio").toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slateDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: AppColors.primary, size: 13),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  "Verified Seller • 98% Positive Ratings",
                  style: TextStyle(color: AppColors.slateMuted, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _startChatWithSeller,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.primary),
            label: const Text(
              "Chat",
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: const Size(58, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            "$title: ",
            style: const TextStyle(
              color: AppColors.slateMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.slateDark,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ================= STICKY BOTTOM ACTION BAR (Matching Compact Height & App Colors) =================
  Widget _bottomAddToCartBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Direct Chat with Seller Button
          InkWell(
            onTap: _startChatWithSeller,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 5),
                  Text(
                    "Chat",
                    style: TextStyle(
                      color: AppColors.slateDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. Add To Cart Button (Matching App Color & 40px Height)
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: inStock && !isAddingToCart ? addToCart : null,
                icon: isAddingToCart
                    ? const SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 16),
                label: Text(
                  inStock ? "Add To Cart" : "Out of Stock",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.slateMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.slateMuted, size: 36),
      ),
    );
  }

  // ================= VERIFIED REVIEWS LOGIC =================
  Future<void> fetchProductReviews() async {
    try {
      final data = await supabase
          .from('product_reviews')
          .select('*')
          .eq('product_id', widget.product['id'])
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);
      double sum = 0.0;
      for (final r in list) {
        sum += (r['rating'] as num?)?.toDouble() ?? 5.0;
      }
      final avg = list.isNotEmpty ? (sum / list.length) : 4.8;

      if (!mounted) return;
      setState(() {
        productReviews = list;
        totalReviewCount = list.length;
        averageRating = avg;
        isLoadingReviews = false;
      });
    } catch (e) {
      debugPrint("Fetch product_reviews error: $e");
      if (!mounted) return;
      setState(() => isLoadingReviews = false);
    }
  }

  Future<void> checkReviewEligibility() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final ordersData = await supabase
          .from('orders')
          .select('id, status, order_items(*)')
          .eq('user_id', currentUser.id);

      bool eligible = false;
      String? foundOrderId;

      for (final order in ordersData) {
        final status = order['status']?.toString().toLowerCase() ?? '';
        if (status == 'delivered') {
          final items = order['order_items'];
          if (items is List) {
            for (final item in items) {
              final pid = item['product_id']?.toString();
              if (pid == productId) {
                eligible = true;
                foundOrderId = order['id']?.toString();
                break;
              }
            }
          }
        }
        if (eligible) break;
      }

      if (!mounted) return;
      setState(() {
        canUserReview = eligible;
        eligibleOrderId = foundOrderId;
      });
    } catch (e) {
      debugPrint("Check review eligibility error: $e");
    }
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return "Recent";
    final date = DateTime.tryParse(raw);
    if (date == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  void _showWriteReviewModal(BuildContext context) {
    if (!canUserReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verified Buyers Only: You must have a delivered order for this item to post a review."),
          backgroundColor: AppColors.slateDark,
        ),
      );
      return;
    }

    double userRating = 5.0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Write a Verified Review", style: TextStyle(color: AppColors.slateDark, fontSize: 17, fontWeight: FontWeight.w900)),
                                Text("Verified Buyer Review", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.slateDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Star Picker
                      const Text("Select Your Rating", style: TextStyle(color: AppColors.slateMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starVal = (index + 1).toDouble();
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                userRating = starVal;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                index < userRating ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 36,
                                color: Colors.amber,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userRating == 5 ? "Excellent! 🔥" : (userRating >= 4 ? "Very Good! 👍" : (userRating >= 3 ? "Good 👌" : "Needs Improvement")),
                        style: const TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 18),

                      // Review Text input
                      TextField(
                        controller: commentController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Write your honest experience with this apparel...",
                          hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Submit Button
                      ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final text = commentController.text.trim();
                                if (text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please write a short review comment.")),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                try {
                                  final currentUser = supabase.auth.currentUser;
                                  String realName = "Verified Buyer";
                                  if (currentUser != null) {
                                    final metaName = currentUser.userMetadata?['name']?.toString() ??
                                        currentUser.userMetadata?['full_name']?.toString();
                                    if (metaName != null && metaName.trim().isNotEmpty) {
                                      realName = metaName.trim();
                                    } else if (currentUser.email != null && currentUser.email!.contains('@')) {
                                      final prefix = currentUser.email!.split('@').first;
                                      realName = prefix.isNotEmpty
                                          ? (prefix[0].toUpperCase() + prefix.substring(1))
                                          : "Verified Buyer";
                                    }
                                  }

                                  String? targetSellerId = widget.product['seller_id']?.toString() ?? widget.product['user_id']?.toString();
                                  if (targetSellerId == null || targetSellerId.trim().isEmpty || targetSellerId == 'null') {
                                    try {
                                      final pRes = await supabase.from('products').select('seller_id').eq('id', widget.product['id']).maybeSingle();
                                      if (pRes != null && pRes['seller_id'] != null) {
                                        targetSellerId = pRes['seller_id'].toString();
                                      }
                                    } catch (e) {
                                      debugPrint("Failed to fetch product seller_id: $e");
                                    }
                                  }

                                  // Fallback: If product seller_id is still null, fetch active seller ID from sellers table
                                  if (targetSellerId == null || targetSellerId.trim().isEmpty || targetSellerId == 'null') {
                                    try {
                                      final sRes = await supabase.from('sellers').select('id').limit(1).maybeSingle();
                                      if (sRes != null && sRes['id'] != null) {
                                        targetSellerId = sRes['id'].toString();
                                      }
                                    } catch (_) {}
                                  }

                                  final reviewRow = <String, dynamic>{
                                    'product_id': widget.product['id'],
                                    'user_id': currentUser?.id,
                                    'seller_id': targetSellerId,
                                    'order_id': eligibleOrderId,
                                    'user_name': realName,
                                    'rating': userRating,
                                    'review_text': text,
                                    'is_verified_purchase': true,
                                  };

                                  await supabase.from('product_reviews').insert(reviewRow);

                                  // Notify Seller about the new customer review!
                                  if (targetSellerId != null && targetSellerId.trim().isNotEmpty && targetSellerId != 'null') {
                                    try {
                                      await supabase.from('notifications').insert({
                                        'user_id': targetSellerId,
                                        'title': 'New Customer Review! ⭐',
                                        'message': '$realName left a ${userRating.toStringAsFixed(0)}-star review on "$name": "$text"',
                                        'type': 'new_review',
                                        'is_read': false,
                                      });
                                      debugPrint("SUCCESS: Seller notification inserted for $targetSellerId");
                                    } catch (e) {
                                      debugPrint("Seller notification RLS/Insert error: $e");
                                    }
                                  }

                                  // Also notify Customer (Review Published confirmation)
                                  if (currentUser?.id != null) {
                                    try {
                                      await supabase.from('notifications').insert({
                                        'user_id': currentUser!.id,
                                        'title': 'Review Published! ⭐',
                                        'message': 'Your ${userRating.toStringAsFixed(0)}-star review on "$name" was posted.',
                                        'type': 'new_review',
                                        'is_read': false,
                                      });
                                    } catch (e) {
                                      debugPrint("Customer confirmation notification error: $e");
                                    }
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Verified Review Submitted Successfully!"),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                  fetchProductReviews();
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  debugPrint("Insert review error: $e");
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Review submitted! Thank you."), backgroundColor: AppColors.primary),
                                    );
                                    Navigator.pop(context);
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: Text(isSubmitting ? "Submitting..." : "Submit Verified Review", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _verifiedReviewsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.slateDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "($totalReviewCount Reviews)",
                    style: const TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: () => _showWriteReviewModal(context),
                  icon: const Icon(Icons.rate_review_outlined, size: 14, color: Colors.white),
                  label: const Text("Rate Product", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canUserReview ? AppColors.primary : AppColors.slateDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Verification Info Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: canUserReview ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: canUserReview ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canUserReview ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  color: canUserReview ? AppColors.primary : AppColors.slateMuted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    canUserReview
                        ? "Verified Buyer: You received this product! You can post a verified review."
                        : "Verified Reviews Only: Only customers who have ordered & received this item can write a review.",
                    style: TextStyle(
                      color: canUserReview ? AppColors.primaryDark : AppColors.slateMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reviews List
          if (isLoadingReviews)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (productReviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "No reviews yet. Be the first verified buyer to review this outfit!",
                style: TextStyle(color: AppColors.slateMuted, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...productReviews.map((review) {
              final rRating = (review['rating'] as num?)?.toDouble() ?? 5.0;
              final rName = review['user_name']?.toString() ?? "Verified Buyer";
              final rText = review['review_text']?.toString() ?? "";
              final rDate = _formatDate(review['created_at']);

              final rReply = review['seller_reply']?.toString();
              final hasReply = rReply != null && rReply.trim().isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                child: Text(
                                  rName.isNotEmpty ? rName[0].toUpperCase() : "V",
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.slateDark, fontSize: 13.5, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: List.generate(5, (starIdx) {
                                        return Icon(
                                          starIdx < rRating ? Icons.star_rounded : Icons.star_border_rounded,
                                          size: 14,
                                          color: Colors.amber,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rDate,
                          style: const TextStyle(color: AppColors.slateLight, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (rText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        rText,
                        style: const TextStyle(color: AppColors.slateDark, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (hasReply) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.store_rounded, color: Color(0xFF2563EB), size: 15),
                                SizedBox(width: 6),
                                Text(
                                  "Store Owner Response",
                                  style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              rReply,
                              style: const TextStyle(color: AppColors.slateDark, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ================= FULL SCREEN ZOOM VIEWER =================
class ProductImageZoomScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String productName;

  const ProductImageZoomScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.productName,
  });

  @override
  State<ProductImageZoomScreen> createState() => _ProductImageZoomScreenState();
}

class _ProductImageZoomScreenState extends State<ProductImageZoomScreen> {
  late PageController _controller;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slateDark, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${currentIndex + 1} / ${widget.images.length}",
          style: const TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => currentIndex = index);
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Hero(
                tag: "product_image_${widget.productName}_$index",
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white,
                      size: 60,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    fetchProductImages();
    checkWishlist();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get productId => widget.product['id'].toString();
  String get name => widget.product['name']?.toString() ?? 'Product';
  String get imageUrl => widget.product['image_url']?.toString() ?? '';
  String get category => widget.product['category']?.toString() ?? '';
  String get color => widget.product['color']?.toString() ?? '';
  String get size => widget.product['size']?.toString() ?? '';
  String get description => widget.product['description']?.toString() ?? '';
  double get price => (widget.product['price'] as num?)?.toDouble() ?? 0.0;
  int get stock => (widget.product['stock'] as num?)?.toInt() ?? 0;
  bool get inStock => stock > 0;

  // Format price strictly as Rs. (PKR) without $ sign
  String get formattedPrice => "Rs. ${price.toStringAsFixed(0)}";

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
    } catch (e) {
      debugPrint("Fetch Product Images Error: $e");
      if (!mounted) return;
      setState(() {
        productImages = imageUrl.trim().isEmpty ? [] : [imageUrl];
        isLoadingImages = false;
      });
    }
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

      final existingCartItem = await supabase
          .from('cart')
          .select('id, quantity')
          .eq('user_id', currentUser.id)
          .eq('product_id', widget.product['id'])
          .maybeSingle();

      if (existingCartItem != null) {
        final oldQty = (existingCartItem['quantity'] as num?)?.toInt() ?? 1;
        await supabase.from('cart').update({
          'quantity': oldQty + 1,
        }).eq('id', existingCartItem['id']);
      } else {
        await supabase.from('cart').insert({
          'user_id': currentUser.id,
          'product_id': widget.product['id'],
          'quantity': 1,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$name added to cart!"),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Wishlist",
            onPressed: toggleWishlist,
            icon: Icon(
              isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isWishlisted ? AppColors.roseRed : AppColors.slateDark,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: "Cart",
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.slateDark, size: 22),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: _bottomAddToCartBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isWide ? 28 : 16,
            16,
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
                        const SizedBox(height: 20),
                        _detailsSection(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= GALLERY SECTION =================
  Widget _gallerySection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 0.95, // Clean tall ratio for full image view
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
                                    color: const Color(0xFFFAFAFA),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain, // Full uncropped image view!
                                      alignment: Alignment.center,
                                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Tap to Zoom Badge
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: GestureDetector(
                              onTap: () => openZoomViewer(selectedImageIndex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 5),
                                    Text(
                                      "Tap to zoom",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Counter Badge (1/4)
                          if (productImages.length > 1)
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${selectedImageIndex + 1}/${productImages.length}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ).animate().fadeIn(duration: 350.ms),

        // Thumbnails carousel
        if (productImages.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 74,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: productImages.length,
              itemBuilder: (context, index) {
                final isSelected = selectedImageIndex == index;

                return GestureDetector(
                  onTap: () => changeImage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 74,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Image.network(
                        productImages[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ================= DETAILS SECTION =================
  Widget _detailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _productInfoCard(),
        const SizedBox(height: 16),
        _descriptionCard(),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _productInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stockChip(),
          const SizedBox(height: 12),

          // Title
          Text(
            name,
            style: const TextStyle(
              color: AppColors.slateDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // Price Tag in Emerald Green
          Text(
            formattedPrice,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Detail Chips Grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (category.trim().isNotEmpty)
                _detailChip(
                  icon: Icons.category_outlined,
                  title: "Category",
                  value: category,
                  color: const Color(0xFF4F46E5),
                ),
              if (size.trim().isNotEmpty)
                _detailChip(
                  icon: Icons.straighten_outlined,
                  title: "Size",
                  value: size,
                  color: const Color(0xFF0891B2),
                ),
              if (color.trim().isNotEmpty)
                _detailChip(
                  icon: Icons.color_lens_outlined,
                  title: "Color",
                  value: color,
                  color: const Color(0xFFDB2777),
                ),
              _detailChip(
                icon: Icons.inventory_2_outlined,
                title: "Stock",
                value: stock > 0 ? "$stock units" : "Out of stock",
                color: inStock ? AppColors.primary : AppColors.roseRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _descriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Product Description",
            style: TextStyle(
              color: AppColors.slateDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description.trim().isEmpty
                ? "No description provided for this item."
                : description,
            style: const TextStyle(
              color: AppColors.slateMuted,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: inStock ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inStock ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Text(
        inStock ? "IN STOCK" : "OUT OF STOCK",
        style: TextStyle(
          color: inStock ? AppColors.primary : AppColors.roseRed,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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
      width: 145,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slateDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STICKY BOTTOM ADD TO CART BAR =================
  Widget _bottomAddToCartBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Price",
                  style: TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formattedPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slateDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: inStock && !isAddingToCart ? addToCart : null,
              icon: isAddingToCart
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
              label: Text(
                inStock ? "Add to Cart" : "Out of Stock",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.slateMuted,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.slateMuted, size: 40),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
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
                  errorBuilder: (_, __, ___) {
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
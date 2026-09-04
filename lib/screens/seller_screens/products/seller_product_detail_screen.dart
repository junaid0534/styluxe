import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../customer_screens/product/product_detail_screen.dart';
import 'edit_product_screen.dart';
import '../../../widgets/seller_shimmer_loading.dart';

class SellerProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const SellerProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<SellerProductDetailScreen> createState() => _SellerProductDetailScreenState();
}

class _SellerProductDetailScreenState extends State<SellerProductDetailScreen> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> productData;
  List<String> productImages = [];
  bool isLoadingImages = true;
  int currentImageIndex = 0;
  final PageController _pageController = PageController();

  // Product Reviews state
  List<Map<String, dynamic>> productReviews = [];
  bool isLoadingReviews = true;
  final TextEditingController _replyController = TextEditingController();

  bool isDescriptionExpanded = false;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Color(0xFFF8FAFC);

  StreamSubscription? _stockSubscription;

  @override
  void initState() {
    super.initState();
    productData = Map<String, dynamic>.from(widget.product);
    fetchFreshProductData();
    _subscribeRealtimeStock();
    fetchProductImages();
    fetchProductReviews();
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> fetchFreshProductData() async {
    final productId = productData['id']?.toString();
    if (productId == null) return;

    try {
      final fresh = await supabase
          .from('products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

      if (fresh != null && mounted) {
        setState(() {
          productData = Map<String, dynamic>.from(fresh);
        });
      }
    } catch (_) {}
  }

  void _subscribeRealtimeStock() {
    final productId = productData['id']?.toString();
    if (productId == null) return;

    try {
      _stockSubscription = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('id', productId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              setState(() {
                productData = Map<String, dynamic>.from(data.first);
              });
            }
          });
    } catch (_) {}
  }

  Future<void> fetchProductImages() async {
    final productId = productData['id']?.toString();
    final mainImage = productData['image_url']?.toString();

    if (productId == null) {
      if (mounted) {
        setState(() {
          productImages = (mainImage != null && mainImage.isNotEmpty) ? [mainImage] : [];
          isLoadingImages = false;
        });
      }
      return;
    }

    try {
      final data = await supabase
          .from('product_images')
          .select('image_url, sort_order')
          .eq('product_id', productId)
          .order('sort_order', ascending: true);

      final urls = List<Map<String, dynamic>>.from(data)
          .map((item) => item['image_url']?.toString() ?? '')
          .where((url) => url.trim().isNotEmpty)
          .toList();

      if (urls.isEmpty && mainImage != null && mainImage.trim().isNotEmpty) {
        urls.add(mainImage);
      }

      if (!mounted) return;
      setState(() {
        productImages = urls;
        isLoadingImages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        productImages = (mainImage != null && mainImage.isNotEmpty) ? [mainImage] : [];
        isLoadingImages = false;
      });
    }
  }

  Future<void> fetchProductReviews() async {
    final pid = productData['id']?.toString();
    if (pid == null) {
      if (mounted) setState(() => isLoadingReviews = false);
      return;
    }

    try {
      final res = await supabase
          .from('product_reviews')
          .select()
          .eq('product_id', pid)
          .order('created_at', ascending: false);

      final fetched = List<Map<String, dynamic>>.from(res);
      if (mounted) {
        setState(() {
          productReviews = fetched;
          isLoadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoadingReviews = false);
      }
    }
  }

  Future<void> _submitReply(Map<String, dynamic> review) async {
    final reviewId = review['id']?.toString() ?? '';
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    try {
      await supabase.from('product_reviews').update({
        'seller_reply': replyText,
        'replied_at': DateTime.now().toIso8601String(),
      }).eq('id', reviewId);

      final customerUserId = review['user_id']?.toString();
      if (customerUserId != null && customerUserId.isNotEmpty) {
        try {
          await supabase.from('notifications').insert({
            'user_id': customerUserId,
            'title': 'Store Reply on Your Review! 💬',
            'message': 'Store owner replied: "$replyText"',
            'is_read': false,
          });
        } catch (_) {
          try {
            await supabase.from('notifications').insert({
              'user_id': customerUserId,
              'title': 'Store Reply on Your Review! 💬',
              'message': 'Store owner replied: "$replyText"',
            });
          } catch (_) {}
        }
      }

      if (!mounted) return;

      setState(() {
        final idx = productReviews.indexWhere((r) => r['id'].toString() == reviewId);
        if (idx != -1) {
          productReviews[idx]['seller_reply'] = replyText;
          productReviews[idx]['replied_at'] = DateTime.now().toIso8601String();
        }
      });

      _replyController.clear();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reply posted successfully! 💬"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post reply: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showReplyModal(Map<String, dynamic> review) {
    final custName = (review['customer_name'] ?? review['user_name'] ?? 'Customer').toString();
    final existingReply = review['seller_reply']?.toString() ?? '';
    _replyController.text = existingReply;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Text("Reply to $custName", style: const TextStyle(color: slateDark, fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            const Text("Write a courteous response to this customer review.", style: TextStyle(color: slateMuted, fontSize: 11.5)),
            const SizedBox(height: 12),

            TextField(
              controller: _replyController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: slateDark),
              decoration: InputDecoration(
                hintText: "Thank you for your feedback! We appreciate your support...",
                hintStyle: const TextStyle(color: slateMuted, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: sapphireBlue, width: 1.5)),
              ),
            ),

            const SizedBox(height: 14),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: sapphireBlue,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _submitReply(review),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              label: const Text("Post Seller Reply", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStockStatus() async {
    final productId = productData['id']?.toString();
    if (productId == null) return;

    final currentStatus = (productData['status']?.toString() ?? 'active').toLowerCase();
    final newStatus = (currentStatus == 'active') ? 'inactive' : 'active';
    final currentStock = (productData['stock'] as num?)?.toInt() ?? 0;
    final newStock = (newStatus == 'active' && currentStock <= 0) ? 10 : currentStock;

    setState(() {
      productData['status'] = newStatus;
      productData['stock'] = newStock;
    });

    try {
      await supabase.from('products').update({
        'status': newStatus,
        'stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'active' ? 'Product is now In Stock!' : 'Product set to Out of Stock!'),
          backgroundColor: newStatus == 'active' ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    } catch (_) {}
  }

  Future<void> _confirmDeleteProduct() async {
    final productId = productData['id']?.toString();
    if (productId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text("Delete Product", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '${productData['name']}'? This action cannot be undone.",
          style: const TextStyle(fontSize: 12.5, color: slateDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: slateMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      try {
        await supabase.from('order_items').delete().eq('product_id', productId);
      } catch (_) {
        try {
          await supabase.from('order_items').update({'product_id': null}).eq('product_id', productId);
        } catch (_) {}
      }
      try {
        await supabase.from('cart').delete().eq('product_id', productId);
      } catch (_) {}
      try {
        await supabase.from('wishlist').delete().eq('product_id', productId);
      } catch (_) {}
      try {
        await supabase.from('reviews').delete().eq('product_id', productId);
      } catch (_) {}

      await supabase.from('products').delete().eq('id', productId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete: ${e.toString().split('\n')[0]}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openZoomViewer(int index) {
    if (productImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductImageZoomScreen(
          images: productImages,
          initialIndex: index,
          productName: productData['name']?.toString() ?? 'Product',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = productData['name']?.toString() ?? 'Product';
    final category = productData['category']?.toString() ?? 'General';
    final color = productData['color']?.toString() ?? 'N/A';
    final size = productData['size']?.toString() ?? 'N/A';
    final description = productData['description']?.toString() ?? 'No description provided.';
    final price = (productData['price'] as num?)?.toDouble() ?? 0.0;
    final rawOrigPrice = (productData['original_price'] as num?)?.toDouble() ?? 0.0;

    final stock = (productData['stock'] as num?)?.toInt() ?? 0;
    final statusStr = (productData['status']?.toString() ?? 'active').toLowerCase();
    final isActive = statusStr == 'active' && stock > 0;

    int discountPercent = 0;
    if (rawOrigPrice > price) {
      discountPercent = (((rawOrigPrice - price) / rawOrigPrice) * 100).round();
    }

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 850;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 42.0,
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 15),
            ),
          ),
        ),
        title: const Text(
          "Product Details",
          style: TextStyle(
            color: slateDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          InkWell(
            onTap: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => EditProductScreen(product: productData)),
              );
              if (res != null && res is Map<String, dynamic>) {
                setState(() => productData = res);
                fetchProductImages();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.edit_note_rounded, color: sapphireBlue, size: 18),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isWide ? 28 : 16,
          10,
          isWide ? 28 : 16,
          24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _gallerySection()),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _productInfoCard(name, category, price, rawOrigPrice, discountPercent, isActive, stock, description),
                            const SizedBox(height: 10),
                            _specificationsCard(category, size, color, stock, isActive),
                            const SizedBox(height: 10),
                            _buildProductReviewsSection(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _gallerySection(),
                      const SizedBox(height: 10),
                      _productInfoCard(name, category, price, rawOrigPrice, discountPercent, isActive, stock, description),
                      const SizedBox(height: 10),
                      _specificationsCard(category, size, color, stock, isActive),
                      const SizedBox(height: 10),
                      _buildProductReviewsSection(),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _bottomActionsBar(isActive),
    );
  }

  Widget _gallerySection() {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: isLoadingImages
          ? const ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 0)
          : productImages.isEmpty
              ? _imagePlaceholder()
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: productImages.length,
                      onPageChanged: (index) => setState(() => currentImageIndex = index),
                      itemBuilder: (context, index) {
                        final url = productImages[index];

                        return GestureDetector(
                          onTap: () => _openZoomViewer(index),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, _, _) => _imagePlaceholder(),
                            ),
                          ),
                        );
                      },
                    ),

                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: GestureDetector(
                        onTap: () => _openZoomViewer(currentImageIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text(
                                "Tap to zoom",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

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
                              width: currentImageIndex == index ? 14 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: currentImageIndex == index
                                    ? sapphireBlue
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_outlined, color: slateMuted, size: 36),
          SizedBox(height: 4),
          Text("No Product Image", style: TextStyle(color: slateMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _productInfoCard(
    String name,
    String category,
    double price,
    double rawOrigPrice,
    int discountPercent,
    bool isActive,
    int stock,
    String description,
  ) {
    final cleanDesc = description.trim().isEmpty ? "No description provided." : description.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sapphireLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: sapphireBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? "IN STOCK ($stock UNITS)" : "OUT OF STOCK",
                  style: TextStyle(
                    color: isActive ? const Color(0xFF10B981) : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (discountPercent > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: slateDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "-$discountPercent% OFF",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          Text(
            name,
            style: const TextStyle(
              color: slateDark,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Text(
                "Rs. ${price.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: sapphireBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              if (rawOrigPrice > price) ...[
                const SizedBox(width: 8),
                Text(
                  "Rs. ${rawOrigPrice.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: slateMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 10),

          const Text(
            "Description",
            style: TextStyle(
              color: slateDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cleanDesc,
            maxLines: isDescriptionExpanded ? null : 3,
            overflow: isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              color: slateMuted,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (cleanDesc.length > 90) ...[
            const SizedBox(height: 2),
            InkWell(
              onTap: () => setState(() => isDescriptionExpanded = !isDescriptionExpanded),
              child: Text(
                isDescriptionExpanded ? "Show Less" : "Read More",
                style: const TextStyle(
                  color: sapphireBlue,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _specificationsCard(String category, String size, String color, int stock, bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Product Specifications",
            style: TextStyle(
              color: slateDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _specRow("Category", category, Icons.category_outlined),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          _specRow("Available Size(s)", size, Icons.straighten_rounded),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          _specRow("Color / Variant", color, Icons.palette_outlined),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          _specRow("Stock Count", "$stock units available", Icons.inventory_2_outlined),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          _specRow("Listing Status", isActive ? "Active in Store" : "Out of Stock", Icons.toggle_on_outlined),
        ],
      ),
    );
  }

  Widget _specRow(String label, String val, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: sapphireBlue, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          val,
          style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildProductReviewsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Customer Reviews (${productReviews.length})",
                style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 3),
                  Text(
                    "Verified Feedback",
                    style: TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (isLoadingReviews)
            Column(
              children: List.generate(2, (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerBox(width: double.infinity, height: 60, borderRadius: 10),
              )),
            )
          else if (productReviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.rate_review_outlined, color: slateMuted, size: 30),
                  SizedBox(height: 6),
                  Text("No Reviews Yet", style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text(
                    "Customer reviews and ratings will appear here after purchase.",
                    style: TextStyle(color: slateMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: productReviews.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rev = productReviews[index];
                return _productReviewItemCard(rev);
              },
            ),
        ],
      ),
    );
  }

  Widget _productReviewItemCard(Map<String, dynamic> rev) {
    final custName = (rev['customer_name'] ?? rev['user_name'] ?? 'Verified Buyer').toString();
    final rating = (rev['rating'] as num?)?.toInt() ?? 5;
    final comment = (rev['comment'] ?? rev['review_text'] ?? 'Great product!').toString();
    final dateStr = rev['created_at']?.toString() ?? '';
    final reply = rev['seller_reply']?.toString();

    final initial = custName.isNotEmpty ? custName[0].toUpperCase() : 'C';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: sapphireLight,
                    child: Text(initial, style: const TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(custName, style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800)),
                      Text(dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr, style: const TextStyle(color: slateMuted, fontSize: 9.5)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (idx) {
                  return Icon(
                    idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 13,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            comment,
            style: const TextStyle(color: slateDark, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500),
          ),

          if (reply != null && reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sapphireLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.store_rounded, color: sapphireBlue, size: 12),
                      SizedBox(width: 4),
                      Text("Store Response", style: TextStyle(color: sapphireBlue, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(reply, style: const TextStyle(color: slateDark, fontSize: 11, height: 1.3)),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _showReplyModal(rev),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_rounded, color: sapphireBlue, size: 13),
                      SizedBox(width: 3),
                      Text("Reply to Buyer", style: TextStyle(color: sapphireBlue, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomActionsBar(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: InkWell(
                onTap: _toggleStockStatus,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? const Color(0xFF10B981) : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isActive ? "In Stock" : "Out of Stock",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF047857) : const Color(0xFFB45309),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sapphireBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => EditProductScreen(product: productData)),
                  );
                  if (res != null && res is Map<String, dynamic>) {
                    setState(() => productData = res);
                    fetchProductImages();
                  }
                },
                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                label: const Text("Edit", style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),

            const SizedBox(width: 8),

            InkWell(
              onTap: _confirmDeleteProduct,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

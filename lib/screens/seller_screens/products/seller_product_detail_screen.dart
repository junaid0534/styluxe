import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_product_screen.dart';

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
  final Map<String, int> _likeCounts = {};
  final Map<String, bool> _likedReviews = {};
  final TextEditingController _replyController = TextEditingController();

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    productData = Map<String, dynamic>.from(widget.product);
    fetchProductImages();
    fetchProductReviews();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  // ================= FETCH ALL PRODUCT IMAGES =================
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

  // ================= FETCH PRODUCT REVIEWS =================
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

  // ================= TOGGLE LIKE =================
  void _toggleLike(String revId) {
    setState(() {
      final isLiked = _likedReviews[revId] ?? false;
      _likedReviews[revId] = !isLiked;
      final current = _likeCounts[revId] ?? 0;
      _likeCounts[revId] = !isLiked ? current + 1 : (current > 0 ? current - 1 : 0);
    });
  }

  // ================= SUBMIT REPLY =================
  Future<void> _submitReply(Map<String, dynamic> review) async {
    final reviewId = review['id']?.toString() ?? '';
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    try {
      await supabase.from('product_reviews').update({
        'seller_reply': replyText,
        'replied_at': DateTime.now().toIso8601String(),
      }).eq('id', reviewId);

      // Send notification to customer
      final customerUserId = review['user_id']?.toString();
      if (customerUserId != null && customerUserId.isNotEmpty) {
        try {
          await supabase.from('notifications').insert({
            'user_id': customerUserId,
            'title': 'New Store Reply on Your Review! 💬',
            'message': 'Store owner replied: "$replyText"',
            'is_read': false,
          });
        } catch (_) {
          try {
            await supabase.from('notifications').insert({
              'user_id': customerUserId,
              'title': 'New Store Reply on Your Review! 💬',
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
          content: Text("Reply posted & customer notified! 💬"),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Reply to $custName", style: const TextStyle(color: slateDark, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text("Write a polite response to this customer review.", style: TextStyle(color: slateMuted, fontSize: 12)),
            const SizedBox(height: 14),

            TextField(
              controller: _replyController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "e.g., Thank you so much for your feedback! We are glad you loved the product...",
                hintStyle: const TextStyle(color: slateMuted, fontSize: 12.5),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: sapphireBlue, width: 2)),
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: sapphireBlue,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _submitReply(review),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: const Text("POST SELLER REPLY", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TOGGLE STOCK STATUS =================
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
          content: Text(newStatus == 'active' ? 'Product is now IN STOCK & Active!' : 'Product set to OUT OF STOCK!'),
          backgroundColor: newStatus == 'active' ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    } catch (_) {}
  }

  // ================= DELETE PRODUCT =================
  Future<void> _confirmDeleteProduct() async {
    final productId = productData['id']?.toString();
    if (productId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text("Delete Product", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
        content: Text("Are you sure you want to permanently delete '${productData['name']}'? This action cannot be undone.", style: const TextStyle(fontSize: 13, color: slateDark)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: slateMuted, fontWeight: FontWeight.w700))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('products').delete().eq('id', productId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {}
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Product Details", style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: sapphireBlue, size: 24),
            tooltip: "Edit Product",
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
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= 1. GALLERY PHOTO CAROUSEL =================
                _buildGalleryCarousel(),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= 2. BADGES =================
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: sapphireLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(category.toUpperCase(), style: const TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? "IN STOCK ($stock UNITS)" : "OUT OF STOCK",
                              style: TextStyle(
                                color: isActive ? const Color(0xFF10B981) : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (discountPercent > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: sapphireBlue, borderRadius: BorderRadius.circular(8)),
                              child: Text("-$discountPercent% OFF", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ================= 3. TITLE & PRICE =================
                      Text(
                        name,
                        style: const TextStyle(color: slateDark, fontSize: 20, fontWeight: FontWeight.w900, height: 1.25),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Text("Rs. ${price.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 24, fontWeight: FontWeight.w900)),
                          if (rawOrigPrice > price) ...[
                            const SizedBox(width: 10),
                            Text("Rs. ${rawOrigPrice.toStringAsFixed(0)}", style: const TextStyle(color: slateMuted, fontSize: 16, decoration: TextDecoration.lineThrough)),
                          ],
                        ],
                      ),

                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 18),

                      // ================= 4. SPECIFICATIONS GRID =================
                      const Text("Product Specifications", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          children: [
                            _specRow("Available Size(s)", size, Icons.straighten_rounded),
                            const Divider(height: 20),
                            _specRow("Color / Variant", color, Icons.palette_outlined),
                            const Divider(height: 20),
                            _specRow("Stock Count", "$stock units available", Icons.inventory_2_outlined),
                            const Divider(height: 20),
                            _specRow("Listing Status", isActive ? "Active in Store" : "Hidden / Out of Stock", Icons.toggle_on_outlined),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ================= 5. DESCRIPTION =================
                      const Text("Product Description", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(color: slateDark, fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 28),
                      const Divider(height: 1),
                      const SizedBox(height: 24),

                      // ================= 6. PRODUCT REVIEWS & CUSTOMER FEEDBACK =================
                      _buildProductReviewsSection(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: cardBorderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. Radio Style Stock Status Pill
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: _toggleStockStatus,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? const Color(0xFF10B981) : Colors.orange,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? const Color(0xFF10B981) : Colors.orange,
                              ),
                            ),
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
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Edit Specs Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sapphireBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  label: const Text("Edit", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),

              const SizedBox(width: 8),

              // 3. Soft Red Delete Button
              InkWell(
                onTap: _confirmDeleteProduct,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= PRODUCT REVIEWS SECTION FOR THIS ITEM =================
  Widget _buildProductReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Product Reviews (${productReviews.length})", style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
            const Row(
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 4),
                Text("Customer Ratings", style: TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (isLoadingReviews)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: sapphireBlue)))
        else if (productReviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
            child: const Column(
              children: [
                Icon(Icons.rate_review_outlined, color: slateMuted, size: 36),
                SizedBox(height: 8),
                Text("No Reviews Yet", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text("Be the first to see customer reviews here once purchased.", style: TextStyle(color: slateMuted, fontSize: 11.5), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: productReviews.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rev = productReviews[index];
              return _productReviewItemCard(rev);
            },
          ),
      ],
    );
  }

  Widget _productReviewItemCard(Map<String, dynamic> rev) {
    final revId = rev['id']?.toString() ?? '';
    final custName = (rev['customer_name'] ?? rev['user_name'] ?? 'Verified Buyer').toString();
    final rating = (rev['rating'] as num?)?.toInt() ?? 5;
    final comment = (rev['comment'] ?? rev['review_text'] ?? 'Great product!').toString();
    final dateStr = rev['created_at']?.toString() ?? '';
    final reply = rev['seller_reply']?.toString();

    final initial = custName.isNotEmpty ? custName[0].toUpperCase() : 'C';

    final isLiked = _likedReviews[revId] ?? false;
    final likeCount = _likeCounts[revId] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
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
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: sapphireLight,
                    child: Text(initial, style: const TextStyle(color: sapphireBlue, fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(custName, style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900)),
                      Text(dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr, style: const TextStyle(color: slateMuted, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (idx) {
                  return Icon(
                    idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 15,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(comment, style: const TextStyle(color: slateDark, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500)),

          const SizedBox(height: 10),

          // SELLER RESPONSE BOX (IF REPLIED)
          if (reply != null && reply.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: sapphireLight, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.store_rounded, color: sapphireBlue, size: 13),
                      SizedBox(width: 4),
                      Text("Store Response", style: TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reply, style: const TextStyle(color: slateDark, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like Button
                InkWell(
                  onTap: () => _toggleLike(revId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isLiked ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? const Color(0xFFEF4444) : slateMuted, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          likeCount > 0 ? "$likeCount" : "Helpful",
                          style: TextStyle(color: isLiked ? const Color(0xFFEF4444) : slateMuted, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                // Reply / Edit Reply Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sapphireBlue,
                    elevation: 0,
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _showReplyModal(rev),
                  icon: const Icon(Icons.reply_rounded, color: Colors.white, size: 13),
                  label: Text(
                    (reply != null && reply.isNotEmpty) ? "Edit Reply" : "Reply",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= GALLERY CAROUSEL =================
  Widget _buildGalleryCarousel() {
    if (isLoadingImages) {
      return Container(
        height: 280,
        color: const Color(0xFFF8FAFC),
        child: const Center(child: CircularProgressIndicator(color: sapphireBlue)),
      );
    }

    if (productImages.isEmpty) {
      return Container(
        height: 280,
        color: const Color(0xFFF8FAFC),
        child: const Center(child: Icon(Icons.image_not_supported_outlined, color: slateMuted, size: 48)),
      );
    }

    return Container(
      height: 280,
      color: const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: productImages.length,
            onPageChanged: (index) => setState(() => currentImageIndex = index),
            itemBuilder: (context, index) {
              return Image.network(
                productImages[index],
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: slateMuted, size: 48),
                ),
              );
            },
          ),
          if (productImages.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(productImages.length, (idx) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: currentImageIndex == idx ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: currentImageIndex == idx ? sapphireBlue : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String val, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: sapphireBlue, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: slateMuted, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(val, style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

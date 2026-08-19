import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../products/seller_product_detail_screen.dart';

class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedStarFilter = "All";
  String selectedProductFilter = "All Products";
  List<String> productFilterOptions = ["All Products"];

  List<Map<String, dynamic>> allReviews = [];
  List<Map<String, dynamic>> filteredReviews = [];

  // Local state for review likes
  final Map<String, int> _likeCounts = {};
  final Map<String, bool> _likedReviews = {};

  StreamSubscription? _reviewsSubscription;
  final TextEditingController replyController = TextEditingController();

  final List<String> starFilterOptions = [
    "All",
    "5 Stars",
    "4 Stars",
    "3 Stars",
    "2 Stars",
    "1 Star",
    "Pending Reply",
  ];

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    fetchSellerReviews();
    _subscribeToRealtimeReviews();
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    replyController.dispose();
    super.dispose();
  }

  // ================= REAL-TIME STREAM SUBSCRIPTION =================
  void _subscribeToRealtimeReviews() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      _reviewsSubscription = supabase
          .from('product_reviews')
          .stream(primaryKey: ['id'])
          .eq('seller_id', user.id)
          .listen((data) {
            if (mounted) {
              fetchSellerReviews(showLoading: false);
            }
          });
    } catch (_) {}
  }

  // ================= FETCH SELLER REVIEWS FROM SUPABASE DATABASE =================
  Future<void> fetchSellerReviews({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Seller not logged in");

      final sellerId = currentUser.id;

      dynamic response;
      try {
        response = await supabase
            .from('product_reviews')
            .select('*, products(*)')
            .eq('seller_id', sellerId)
            .order('created_at', ascending: false);
      } catch (e1) {
        try {
          response = await supabase
              .from('product_reviews')
              .select('*, products(id, name, price, image_url)')
              .eq('seller_id', sellerId)
              .order('created_at', ascending: false);
        } catch (e2) {
          try {
            response = await supabase
                .from('product_reviews')
                .select()
                .eq('seller_id', sellerId)
                .order('created_at', ascending: false);
          } catch (e3) {
            try {
              response = await supabase
                  .from('product_reviews')
                  .select()
                  .order('created_at', ascending: false);
            } catch (e4) {
              response = [];
            }
          }
        }
      }

      final fetched = List<Map<String, dynamic>>.from(response ?? []);

      // If products object was not populated via join, fetch products for each review
      for (var rev in fetched) {
        if (rev['products'] == null && rev['product_id'] != null) {
          try {
            final pRes = await supabase.from('products').select().eq('id', rev['product_id']).maybeSingle();
            if (pRes != null) {
              rev['products'] = pRes;
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;

      setState(() {
        allReviews = fetched;
        filteredReviews = fetched;
        isLoading = false;
      });

      _extractProductFilterOptions();
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        allReviews = [];
        filteredReviews = [];
        isLoading = false;
      });
    }
  }

  // ================= EXTRACT PRODUCT NAMES FOR PRODUCT FILTER =================
  void _extractProductFilterOptions() {
    final Set<String> names = {"All Products"};
    for (var rev in allReviews) {
      final pMap = rev['products'] is Map ? Map<String, dynamic>.from(rev['products']) : <String, dynamic>{};
      final pName = pMap['name']?.toString();
      if (pName != null && pName.trim().isNotEmpty) {
        names.add(pName.trim());
      }
    }
    setState(() {
      productFilterOptions = names.toList();
      if (!productFilterOptions.contains(selectedProductFilter)) {
        selectedProductFilter = "All Products";
      }
    });
  }

  // ================= APPLY RATING & PRODUCT FILTERS =================
  void _applyFilters() {
    setState(() {
      filteredReviews = allReviews.where((rev) {
        // Rating Filter
        final r = (rev['rating'] as num?)?.toInt() ?? 5;
        final hasReply = rev['seller_reply'] != null && rev['seller_reply'].toString().isNotEmpty;

        bool matchesStar = true;
        if (selectedStarFilter == "Pending Reply") {
          matchesStar = !hasReply;
        } else if (selectedStarFilter == "5 Stars") {
          matchesStar = (r == 5);
        } else if (selectedStarFilter == "4 Stars") {
          matchesStar = (r == 4);
        } else if (selectedStarFilter == "3 Stars") {
          matchesStar = (r == 3);
        } else if (selectedStarFilter == "2 Stars") {
          matchesStar = (r == 2);
        } else if (selectedStarFilter == "1 Star") {
          matchesStar = (r == 1);
        }

        // Product Filter
        final pMap = rev['products'] is Map ? Map<String, dynamic>.from(rev['products']) : <String, dynamic>{};
        final pName = pMap['name']?.toString() ?? '';
        bool matchesProduct = (selectedProductFilter == "All Products") || (pName.trim() == selectedProductFilter.trim());

        return matchesStar && matchesProduct;
      }).toList();
    });
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

  // ================= SUBMIT SELLER REPLY TO SUPABASE =================
  Future<void> _submitReply(Map<String, dynamic> review) async {
    final reviewId = review['id']?.toString() ?? '';
    final replyText = replyController.text.trim();
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
        final idx = allReviews.indexWhere((r) => r['id'].toString() == reviewId);
        if (idx != -1) {
          allReviews[idx]['seller_reply'] = replyText;
          allReviews[idx]['replied_at'] = DateTime.now().toIso8601String();
        }
      });

      _applyFilters();
      replyController.clear();
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
    replyController.text = existingReply;

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
              controller: replyController,
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

  @override
  Widget build(BuildContext context) {
    double avgRating = 5.0;
    if (allReviews.isNotEmpty) {
      double sum = 0;
      for (var r in allReviews) {
        sum += (r['rating'] as num?)?.toDouble() ?? 5.0;
      }
      avgRating = sum / allReviews.length;
    }

    final totalCount = allReviews.length;
    final repliedCount = allReviews.where((r) => r['seller_reply'] != null && r['seller_reply'].toString().isNotEmpty).length;
    final replyRate = totalCount > 0 ? ((repliedCount / totalCount) * 100).round() : 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Customer Reviews", style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: sapphireBlue),
            tooltip: "Refresh Reviews",
            onPressed: fetchSellerReviews,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: fetchSellerReviews,
              color: sapphireBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. RATINGS KPI SUMMARY =================
                        _buildRatingsHeader(avgRating, totalCount, replyRate),

                        const SizedBox(height: 18),

                        // ================= 2. DUAL DROPDOWN FILTERS ROW (RATING & PRODUCT) =================
                        Row(
                          children: [
                            // 1. Rating Dropdown Filter
                            Expanded(
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedStarFilter,
                                    isExpanded: true,
                                    icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                    style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => selectedStarFilter = val);
                                        _applyFilters();
                                      }
                                    },
                                    items: starFilterOptions.map((st) {
                                      return DropdownMenuItem<String>(
                                        value: st,
                                        child: Text(st == "All" ? "All Star Ratings" : st, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // 2. Product Dropdown Filter
                            Expanded(
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedProductFilter,
                                    isExpanded: true,
                                    icon: const Icon(Icons.inventory_2_rounded, color: sapphireBlue, size: 16),
                                    style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => selectedProductFilter = val);
                                        _applyFilters();
                                      }
                                    },
                                    items: productFilterOptions.map((pr) {
                                      return DropdownMenuItem<String>(
                                        value: pr,
                                        child: Text(pr, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ================= 3. REVIEWS LIST TITLE =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Customer Reviews (${filteredReviews.length})",
                              style: const TextStyle(color: slateDark, fontSize: 15.5, fontWeight: FontWeight.w900),
                            ),
                            if (selectedProductFilter != "All Products" || selectedStarFilter != "All")
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedStarFilter = "All";
                                    selectedProductFilter = "All Products";
                                  });
                                  _applyFilters();
                                },
                                child: const Text("Reset Filters", style: TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ================= 4. REVIEWS CARDS =================
                        if (filteredReviews.isEmpty)
                          _buildEmptyReviewsView()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredReviews.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final rev = filteredReviews[index];
                              return _modernReviewCard(rev);
                            },
                          ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildSellerBottomNav(3),
    );
  }

  // ================= RATINGS KPI SUMMARY =================
  Widget _buildRatingsHeader(double avgRating, int total, int responseRate) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(avgRating.toStringAsFixed(1), style: const TextStyle(color: slateDark, fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
                  ],
                ),
                const SizedBox(height: 2),
                const Text("Store Rating", style: TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: Column(
              children: [
                Text(total.toString(), style: const TextStyle(color: slateDark, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                const Text("Total Reviews", style: TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: Column(
              children: [
                Text("$responseRate%", style: const TextStyle(color: Color(0xFF10B981), fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                const Text("Replied Rate", style: TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= BORDERLESS REVIEW CARD WITH EQUALIZED 38PX BUTTONS =================
  Widget _modernReviewCard(Map<String, dynamic> rev) {
    final revId = rev['id']?.toString() ?? '';
    final custName = (rev['customer_name'] ?? rev['user_name'] ?? 'Customer').toString();
    final rating = (rev['rating'] as num?)?.toInt() ?? 5;
    final comment = (rev['comment'] ?? rev['review_text'] ?? 'Great product!').toString();
    final dateStr = rev['created_at']?.toString() ?? '';
    final reply = rev['seller_reply']?.toString();
    final hasReply = reply != null && reply.isNotEmpty;

    final pMap = rev['products'] is Map ? Map<String, dynamic>.from(rev['products']) : <String, dynamic>{};

    final initial = custName.isNotEmpty ? custName[0].toUpperCase() : 'C';

    final isLiked = _likedReviews[revId] ?? false;
    final likeCount = _likeCounts[revId] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CUSTOMER NAME & STARS HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: sapphireLight, shape: BoxShape.circle, border: Border.all(color: sapphireBlue, width: 1.2)),
                    child: Center(child: Text(initial, style: const TextStyle(color: sapphireBlue, fontSize: 17, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(custName, style: const TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                      Text(dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr, style: const TextStyle(color: slateMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (idx) {
                  return Icon(
                    idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 18,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. COMMENT BODY
          Text(
            comment,
            style: const TextStyle(color: slateDark, fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 14),

          // 3. SELLER RESPONSE BOX (IF REPLIED) (NO TOP EDIT TEXT HERE)
          if (hasReply) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sapphireLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.store_rounded, color: sapphireBlue, size: 15),
                      SizedBox(width: 6),
                      Text("Your Store Response", style: TextStyle(color: sapphireBlue, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(reply, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Divider(height: 1),
          const SizedBox(height: 10),

          // 4. EQUALIZED 38PX ACTION BUTTONS: VIEW PRODUCT (NO ICON), HELPFUL, REPLY / EDIT REPLY
          SizedBox(
            height: 38,
            child: Row(
              children: [
                // 1. View Product Button (Fixed Text "View Product", No Icon)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (pMap.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => SellerProductDetailScreen(product: pMap),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sapphireLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "View Product",
                        style: TextStyle(color: sapphireBlue, fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Helpful / Like Button (38px height)
                InkWell(
                  onTap: () => _toggleLike(revId),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isLiked ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? const Color(0xFFEF4444) : slateMuted, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          likeCount > 0 ? "$likeCount" : "Helpful",
                          style: TextStyle(color: isLiked ? const Color(0xFFEF4444) : slateMuted, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Reply / Edit Reply Button (38px height)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sapphireBlue,
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _showReplyModal(rev),
                  icon: const Icon(Icons.reply_rounded, color: Colors.white, size: 14),
                  label: Text(
                    hasReply ? "Edit Reply" : "Reply",
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReviewsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: slateMuted),
          SizedBox(height: 12),
          Text("No Customer Reviews Found", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text("No reviews match the selected rating or product filter.", style: TextStyle(color: slateMuted, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ================= 5-TAB SELLER BOTTOM NAV BAR =================
  Widget _buildSellerBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (index == 0) Navigator.pushReplacementNamed(context, '/seller');
            if (index == 1) Navigator.pushNamed(context, '/active_orders');
            if (index == 2) Navigator.pushNamed(context, '/my_products');
            if (index == 3) Navigator.pushNamed(context, '/seller_analytics');
            if (index == 4) Navigator.pushNamed(context, '/manage_store');
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: sapphireBlue,
          unselectedItemColor: slateMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_mall_outlined),
              activeIcon: Icon(Icons.local_mall_rounded),
              label: "Orders",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: "Products",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: "Analytics",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}

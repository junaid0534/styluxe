import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';
import '../product/product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  double subtotalAmount = 0.0;
  double discountAmount = 0.0;
  double totalAmount = 0.0;

  // ================= VOUCHER STATE =================
  final TextEditingController voucherController = TextEditingController();
  Map<String, dynamic>? activeVoucher;
  String? appliedVoucherCode;
  List<Map<String, dynamic>> availableVouchers = [];
  bool isLoadingVouchers = false;

  @override
  void initState() {
    super.initState();
    fetchCart();
    fetchAvailableVouchers();
  }

  @override
  void dispose() {
    voucherController.dispose();
    super.dispose();
  }

  // ================= FETCH VOUCHERS =================
  Future<void> fetchAvailableVouchers() async {
    setState(() => isLoadingVouchers = true);

    final List<Map<String, dynamic>> defaultVouchers = [
      {
        "code": "STYLUXE20",
        "title": "Styluxe Welcome",
        "subtitle": "Flat 20% OFF on all fashion orders",
        "discount_type": "percentage",
        "discount_value": 20.0,
        "max_discount_amount": 1000.0,
        "min_order_amount": 1000.0,
        "tag": "20% OFF",
        "badge_color": const Color(0xFF10B981),
      },
      {
        "code": "SUMMER50",
        "title": "Mega Summer Festival",
        "subtitle": "50% OFF up to Rs. 1000 on min. 1500",
        "discount_type": "percentage",
        "discount_value": 50.0,
        "max_discount_amount": 1000.0,
        "min_order_amount": 1500.0,
        "tag": "50% OFF",
        "badge_color": const Color(0xFFF59E0B),
      },
      {
        "code": "FLASHSALE500",
        "title": "Flash Sale Discount",
        "subtitle": "Flat Rs. 500 discount on min. 2000 spend",
        "discount_type": "fixed",
        "discount_value": 500.0,
        "min_order_amount": 2000.0,
        "tag": "RS 500 OFF",
        "badge_color": const Color(0xFF6366F1),
      },
      {
        "code": "FREESHIP",
        "title": "Free Delivery Voucher",
        "subtitle": "100% Free home shipping on min. 800",
        "discount_type": "fixed",
        "discount_value": 150.0,
        "min_order_amount": 800.0,
        "tag": "FREE SHIP",
        "badge_color": const Color(0xFF0EA5E9),
      },
      {
        "code": "INDEPENDENCE14",
        "title": "Azadi Promo",
        "subtitle": "14% OFF on entire cart",
        "discount_type": "percentage",
        "discount_value": 14.0,
        "min_order_amount": 500.0,
        "tag": "14% OFF",
        "badge_color": const Color(0xFF10B981),
      },
    ];

    try {
      final data = await supabase
          .from('coupons')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> dbCoupons = List<Map<String, dynamic>>.from(data);

      final Map<String, Map<String, dynamic>> combined = {};

      for (final c in dbCoupons) {
        final code = c['code']?.toString().toUpperCase() ?? '';
        if (code.isNotEmpty) {
          combined[code] = {
            ...c,
            "tag": c['discount_type'] == 'percentage'
                ? "${(c['discount_value'] as num?)?.toInt() ?? 0}% OFF"
                : "RS. ${(c['discount_value'] as num?)?.toInt() ?? 0} OFF",
            "badge_color": const Color(0xFF10B981),
          };
        }
      }

      for (final d in defaultVouchers) {
        final code = d['code']!.toString().toUpperCase();
        if (!combined.containsKey(code)) {
          combined[code] = d;
        }
      }

      if (!mounted) return;
      setState(() {
        availableVouchers = combined.values.toList();
        isLoadingVouchers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        availableVouchers = defaultVouchers;
        isLoadingVouchers = false;
      });
    }
  }

  // ================= FETCH CART FROM SUPABASE =================
  Future<void> fetchCart() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Please login first");

      final data = await supabase
          .from('cart')
          .select('*, products(*)')
          .eq('user_id', currentUser.id)
          .order('added_at', ascending: false);

      if (!mounted) return;

      setState(() {
        cartItems = List<Map<String, dynamic>>.from(data);
        calculateTotal();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Cart Error: $e");
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= CALCULATE TOTAL & VOUCHER SAVINGS =================
  void calculateTotal() {
    subtotalAmount = cartItems.fold(0.0, (sum, item) {
      final product = item['products'] ?? {};
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + (price * qty);
    });

    if (activeVoucher != null) {
      final discountType = activeVoucher!['discount_type']?.toString() ?? 'percentage';
      final discountVal = (activeVoucher!['discount_value'] as num?)?.toDouble() ?? 0.0;
      final minOrder = (activeVoucher!['min_order_amount'] as num?)?.toDouble() ?? 0.0;
      final targetSellerId = activeVoucher!['seller_id']?.toString();

      if (subtotalAmount >= minOrder) {
        double eligibleAmount = subtotalAmount;

        if (targetSellerId != null && targetSellerId.isNotEmpty) {
          eligibleAmount = 0.0;
          for (final item in cartItems) {
            final product = item['products'] ?? {};
            if (product['seller_id']?.toString() == targetSellerId) {
              final price = (product['price'] as num?)?.toDouble() ?? 0.0;
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              eligibleAmount += (price * qty);
            }
          }
        }

        if (discountType == 'percentage') {
          discountAmount = (eligibleAmount * discountVal) / 100.0;
          final maxDiscount = (activeVoucher!['max_discount_amount'] as num?)?.toDouble();
          if (maxDiscount != null && maxDiscount > 0 && discountAmount > maxDiscount) {
            discountAmount = maxDiscount;
          }
        } else if (discountType == 'fixed') {
          discountAmount = discountVal;
        }
      } else {
        discountAmount = 0.0;
      }
    } else {
      discountAmount = 0.0;
    }

    if (discountAmount > subtotalAmount) {
      discountAmount = subtotalAmount;
    }

    totalAmount = (subtotalAmount - discountAmount).clamp(0.0, double.infinity);
  }

  // ================= APPLY VOUCHER =================
  Future<void> applyVoucher(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    // Check available vouchers list first
    Map<String, dynamic>? match;
    for (final v in availableVouchers) {
      if (v['code']?.toString().toUpperCase() == cleanCode) {
        match = v;
        break;
      }
    }

    // If not found in memory, query database
    if (match == null) {
      try {
        final data = await supabase
            .from('coupons')
            .select('*')
            .eq('code', cleanCode)
            .eq('is_active', true)
            .maybeSingle();
        if (data != null) {
          match = Map<String, dynamic>.from(data);
        }
      } catch (_) {}
    }

    if (match != null) {
      final minOrder = (match['min_order_amount'] as num?)?.toDouble() ?? 0.0;

      if (subtotalAmount < minOrder) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Order subtotal must be at least Rs. ${minOrder.toStringAsFixed(0)} for this voucher."),
              backgroundColor: AppColors.roseRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() {
        activeVoucher = match;
        appliedVoucherCode = cleanCode;
        voucherController.text = cleanCode;
        calculateTotal();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 Voucher '$cleanCode' applied! You saved Rs. ${discountAmount.toStringAsFixed(0)}"),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid or expired voucher code."),
            backgroundColor: AppColors.roseRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ================= REMOVE VOUCHER =================
  void removeVoucher() {
    setState(() {
      activeVoucher = null;
      appliedVoucherCode = null;
      voucherController.clear();
      discountAmount = 0.0;
      calculateTotal();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Voucher removed"),
        backgroundColor: AppColors.slateDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> updateQuantity(dynamic cartId, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      await supabase.from('cart').update({
        'quantity': newQuantity,
      }).eq('id', cartId);

      fetchCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
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

  void _onPlusClicked(Map<String, dynamic> item, Map<String, dynamic> product) {
    final rawColor = product['color']?.toString() ?? '';
    final rawSize = product['size']?.toString() ?? '';

    final colors = rawColor.split(RegExp(r'[,|/•]+')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    final sizes = rawSize.split(RegExp(r'[,|/•]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (colors.length > 1 || sizes.length > 1) {
      _showAddVariantModal(context, item, product, colors, sizes);
    } else {
      final currentQty = (item['quantity'] as num?)?.toInt() ?? 1;
      updateQuantity(item['id'], currentQty + 1);
    }
  }

  void _showAddVariantModal(
    BuildContext context,
    Map<String, dynamic> item,
    Map<String, dynamic> product,
    List<String> colors,
    List<String> sizes,
  ) {
    String? selectedModalColor = item['selected_color']?.toString() ?? (colors.isNotEmpty ? colors.first : null);
    String? selectedModalSize = item['selected_size']?.toString() ?? (sizes.isNotEmpty ? sizes.first : null);

    final String name = product['name']?.toString() ?? 'Product';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    String resolvedImageUrl = (product['image_url'] ??
            product['image'] ??
            product['photo_url'] ??
            product['cover_image'])
        ?.toString() ??
        '';

    if (resolvedImageUrl.isEmpty &&
        product['image_urls'] is List &&
        (product['image_urls'] as List).isNotEmpty) {
      resolvedImageUrl = product['image_urls'][0].toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(modalCtx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Color & Size",
                    style: TextStyle(
                      color: AppColors.slateDark,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(modalCtx),
                    icon: const Icon(Icons.close_rounded, color: AppColors.slateMuted, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Mini Product Preview Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: resolvedImageUrl.isNotEmpty
                          ? Image.network(resolvedImageUrl, fit: BoxFit.contain)
                          : const Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 13)),
                          Text("Rs. ${price.toStringAsFixed(0)}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Color Selector
              if (colors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 15, color: AppColors.primary),
                        const SizedBox(width: 5),
                        const Text("Available Colors:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        Text(selectedModalColor ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (colors.length > 3)
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
                            value: selectedModalColor,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
                            items: colors.map((c) => DropdownMenuItem(
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
                              if (val != null) setModalState(() => selectedModalColor = val);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: colors.map((c) {
                    final isSel = selectedModalColor == c;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedModalColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary.withValues(alpha: 0.10) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? AppColors.primary : const Color(0xFFE2E8F0),
                            width: isSel ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 11, height: 11, decoration: BoxDecoration(color: _getColorFromName(c), shape: BoxShape.circle, border: Border.all(color: Colors.black12))),
                            const SizedBox(width: 5),
                            Text(c, style: TextStyle(color: isSel ? AppColors.primary : AppColors.slateDark, fontSize: 11, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // 2. Size Selector
              if (sizes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten_outlined, size: 15, color: Color(0xFF0891B2)),
                        const SizedBox(width: 5),
                        const Text("Available Sizes:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        Text(selectedModalSize ?? '', style: const TextStyle(color: Color(0xFF0891B2), fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (sizes.length > 5)
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
                            value: selectedModalSize,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0891B2)),
                            items: sizes.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedModalSize = val);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sizes.map((s) {
                    final isSel = selectedModalSize == s;
                    return ChoiceChip(
                      label: Text(s, style: TextStyle(color: isSel ? Colors.white : AppColors.slateDark, fontSize: 11, fontWeight: FontWeight.w800)),
                      selected: isSel,
                      selectedColor: const Color(0xFF0891B2),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: BorderSide(color: isSel ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0)),
                      onSelected: (sel) {
                        if (sel) setModalState(() => selectedModalSize = s);
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 22),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: () async {
                    Navigator.pop(modalCtx);
                    await _addVariantToCart(item, product, selectedModalColor, selectedModalSize);
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                  label: const Text("ADD THIS VARIANT TO CART", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addVariantToCart(
    Map<String, dynamic> item,
    Map<String, dynamic> product,
    String? color,
    String? size,
  ) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final currentItemColor = item['selected_color']?.toString();
      final currentItemSize = item['selected_size']?.toString();

      if ((color ?? '') == (currentItemColor ?? '') && (size ?? '') == (currentItemSize ?? '')) {
        final currentQty = (item['quantity'] as num?)?.toInt() ?? 1;
        await updateQuantity(item['id'], currentQty + 1);
        return;
      }

      final existing = cartItems.firstWhere(
        (c) =>
            c['product_id']?.toString() == product['id']?.toString() &&
            (c['selected_color']?.toString() ?? '') == (color ?? '') &&
            (c['selected_size']?.toString() ?? '') == (size ?? ''),
        orElse: () => {},
      );

      if (existing.isNotEmpty) {
        final exQty = (existing['quantity'] as num?)?.toInt() ?? 1;
        await updateQuantity(existing['id'], exQty + 1);
      } else {
        try {
          await supabase.from('cart').insert({
            'user_id': user.id,
            'product_id': product['id'],
            'quantity': 1,
            if (size != null && size.isNotEmpty) 'selected_size': size,
            if (color != null && color.isNotEmpty) 'selected_color': color,
          });
        } catch (_) {
          await supabase.from('cart').insert({
            'user_id': user.id,
            'product_id': product['id'],
            'quantity': 1,
          });
        }
      }

      await fetchCart();

      if (!mounted) return;
      final variantLabel = [if (color != null && color.isNotEmpty) color, if (size != null && size.isNotEmpty) "Size: $size"].join(", ");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Added +1 ${product['name']} ${variantLabel.isNotEmpty ? "($variantLabel)" : ""} to Cart!"),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Add variant error: $e");
    }
  }

  // ================= ITEM CLICK OPTIONS MODAL (View Details & Delete) =================
  void _showItemOptionsModal(
    BuildContext context,
    Map<String, dynamic> item,
    Map<String, dynamic> product,
  ) {
    final String name = product['name']?.toString() ?? 'Product';
    String resolvedImageUrl = (product['image_url'] ??
            product['image'] ??
            product['photo_url'] ??
            product['cover_image'])
        ?.toString() ??
        '';

    if (resolvedImageUrl.isEmpty &&
        product['image_urls'] is List &&
        (product['image_urls'] as List).isNotEmpty) {
      resolvedImageUrl = product['image_urls'][0].toString();
    }

    final String imageUrl = resolvedImageUrl.trim();
    final String category = product['category']?.toString() ?? 'Fashion';
    String size = item['selected_size']?.toString() ?? '';
    String color = item['selected_color']?.toString() ?? '';

    if (color.isEmpty) {
      final rawCol = product['color']?.toString() ?? '';
      if (rawCol.isNotEmpty) {
        color = rawCol.split(RegExp(r'[,|/•]+')).first.trim();
      }
    }
    if (size.isEmpty) {
      final rawSz = product['size']?.toString() ?? '';
      if (rawSz.isNotEmpty) {
        size = rawSz.split(RegExp(r'[,|/•]+')).first.trim();
      }
    }

    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final String sizeLabel = size.isNotEmpty ? (size.toLowerCase().startsWith('size') ? size : "Size: $size") : '';
    final String colorLabel = color.isNotEmpty ? (color.toLowerCase().startsWith('color') ? color : "Color: $color") : '';
    final String subtitle = [category, colorLabel, sizeLabel].where((s) => s.trim().isNotEmpty).join(" • ");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(modalContext).padding.bottom,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Product Mini Preview
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 22),
                              )
                            : const Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slateDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Rs. ${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slateMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Option 1: View Product Details
              InkWell(
                onTap: () {
                  Navigator.pop(modalContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(product: product),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: AppColors.primary, size: 22),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "View Details",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slateDark,
                              ),
                            ),
                            Text(
                              "Open full photos, description & ratings",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Option 2: Remove from Cart
              InkWell(
                onTap: () {
                  Navigator.pop(modalContext);
                  removeFromCart(item['id']);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Delete from Cart",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            Text(
                              "Remove this item from your shopping bag",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFEF4444), size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(modalContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> removeFromCart(dynamic cartId) async {
    try {
      await supabase.from('cart').delete().eq('id', cartId);
      fetchCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Clear Cart", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to remove all items from your cart?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppColors.slateMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All", style: TextStyle(color: AppColors.roseRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase.from('cart').delete().eq('user_id', currentUser.id);
      fetchCart();
    } catch (e) {
      debugPrint("Clear Cart Error: $e");
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slateDark, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Cart List",
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
            child: Container(
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
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.roseRed, size: 18),
                onPressed: cartItems.isEmpty ? null : clearCart,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : cartItems.isEmpty
              ? _emptyCartView()
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: fetchCart,
                        color: AppColors.primary,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            width >= 760 ? 32 : 16,
                            12,
                            width >= 760 ? 32 : 16,
                            16,
                          ),
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            final product = item['products'] ?? {};
                            final productMap = Map<String, dynamic>.from(product);

                            return CartItemCard(
                              item: item,
                              product: productMap,
                              onTap: () => _showItemOptionsModal(context, item, productMap),
                              onQuantityChanged: (newQty) {
                                if (newQty >= 1) {
                                  updateQuantity(item['id'], newQty);
                                }
                              },
                              onPlusTap: () => _onPlusClicked(item, productMap),
                              onRemove: () => removeFromCart(item['id']),
                            ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms);
                          },
                        ),
                      ),
                    ),

                    // Reference-matching Bottom Breakdown & Checkout Sheet
                    _bottomCheckoutSheet(),
                  ],
                ),
      bottomNavigationBar: _buildFullWidthBottomNav(3),
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

  // ================= EMPTY CART VIEW =================
  Widget _emptyCartView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Your cart is empty",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Looks like you haven't added anything to your cart yet.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/shop_now');
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                  label: const Text(
                    "Start Shopping",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ================= REFERENCE MATCHING BOTTOM CHECKOUT SHEET =================
  Widget _bottomCheckoutSheet() {
    const double shipping = 0.0; // Free shipping
    final double grandTotal = totalAmount + shipping;
    final bool hasVoucher = activeVoucher != null && discountAmount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Interactive Voucher Code Pill ----
          GestureDetector(
            onTap: _showVouchersModal,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: hasVoucher
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasVoucher
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
                  width: hasVoucher ? 1.2 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: hasVoucher ? AppColors.primary : AppColors.slateDark,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasVoucher ? Icons.check_rounded : Icons.confirmation_number_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: hasVoucher
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    appliedVoucherCode ?? 'VOUCHER',
                                    style: const TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "APPLIED",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "Saved Rs. ${discountAmount.toStringAsFixed(0)} on this order",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "Enter voucher code or select offer",
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  if (hasVoucher)
                    GestureDetector(
                      onTap: removeVoucher,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            availableVouchers.isNotEmpty ? "Offers (${availableVouchers.length})" : "Apply",
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 10),
                        ],
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ---- Cost Breakdown ----
          _summaryRow("Subtotal", "Rs. ${subtotalAmount.toStringAsFixed(0)}"),
          if (hasVoucher) ...[
            const SizedBox(height: 6),
            _summaryRow(
              "Voucher Discount (${appliedVoucherCode ?? ''})",
              "- Rs. ${discountAmount.toStringAsFixed(0)}",
              valueColor: AppColors.primary,
              isBoldValue: true,
            ),
          ],
          const SizedBox(height: 6),
          _summaryRow("Shipping", shipping == 0.0 ? "Free" : "Rs. ${shipping.toStringAsFixed(0)}"),
          const SizedBox(height: 6),
          _summaryRow("Tax (0%)", "Rs. 0"),

          const SizedBox(height: 10),

          // ---- Dashed Divider ----
          Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  color: index % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
                  height: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ---- Total Row ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Rs. ${grandTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  if (hasVoucher)
                    Text(
                      "Original: Rs. ${subtotalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.slateMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ---- Bottom Action Row ----
          Row(
            children: [
              // Left Total Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Rs. ${grandTotal.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Right Checkout Button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/checkout',
                        arguments: {
                          'appliedCoupon': activeVoucher,
                          'appliedCouponCode': appliedVoucherCode,
                        },
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Checkout",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= VOUCHERS MODAL BOTTOM SHEET =================
  void _showVouchersModal() {
    final TextEditingController manualInputController = TextEditingController(text: appliedVoucherCode ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Modal Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_offer_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Available Vouchers",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slateDark,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded, color: AppColors.slateMuted, size: 20),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Color(0xFFF1F5F9), height: 1),

                // Manual Input Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, color: AppColors.slateMuted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: manualInputController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slateDark,
                              letterSpacing: 0.5,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Enter voucher code",
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.slateMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final code = manualInputController.text.trim();
                            if (code.isNotEmpty) {
                              Navigator.pop(modalContext);
                              applyVoucher(code);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Apply",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Vouchers List
                Expanded(
                  child: availableVouchers.isEmpty
                      ? const Center(
                          child: Text(
                            "No vouchers currently available",
                            style: TextStyle(color: AppColors.slateMuted, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                          itemCount: availableVouchers.length,
                          itemBuilder: (context, index) {
                            final v = availableVouchers[index];
                            final String code = v['code']?.toString().toUpperCase() ?? '';
                            final String title = v['title']?.toString() ?? 'Special Voucher';
                            final String subtitle = v['subtitle']?.toString() ?? 'Exclusive discount offer';
                            final String tag = v['tag']?.toString() ?? 'PROMO';
                            final double minOrder = (v['min_order_amount'] as num?)?.toDouble() ?? 0.0;
                            final bool isApplied = appliedVoucherCode == code;
                            final bool isEligible = subtotalAmount >= minOrder;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isApplied
                                    ? AppColors.primary.withValues(alpha: 0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isApplied
                                      ? AppColors.primary
                                      : const Color(0xFFE2E8F0),
                                  width: isApplied ? 1.4 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(modalContext);
                                  applyVoucher(code);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Discount Badge
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: BoxDecoration(
                                          color: isApplied
                                              ? AppColors.primary
                                              : AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.local_offer_rounded,
                                              size: 16,
                                              color: isApplied ? Colors.white : AppColors.primary,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              tag,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: isApplied ? Colors.white : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  code,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.slateDark,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (isApplied)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      "APPLIED",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.slateMedium,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.slateMuted,
                                              ),
                                            ),
                                            if (minOrder > 0) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                isEligible
                                                    ? "✓ Min spend Rs. ${minOrder.toStringAsFixed(0)} reached"
                                                    : "• Add Rs. ${(minOrder - subtotalAmount).toStringAsFixed(0)} more to unlock",
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isEligible
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFFE11D48),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Apply Button
                                      SizedBox(
                                        height: 32,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(modalContext);
                                            applyVoucher(code);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isApplied
                                                ? const Color(0xFFEF4444)
                                                : isEligible
                                                    ? AppColors.primary
                                                    : const Color(0xFF94A3B8),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            isApplied ? "Remove" : "Apply",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor, bool isBoldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slateMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.slateDark,
            fontSize: 12.5,
            fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ================= CART ITEM CARD (Full Fit Without Crop) =================
class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final Function(int) onQuantityChanged;
  final VoidCallback? onPlusTap;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.product,
    required this.onTap,
    required this.onQuantityChanged,
    this.onPlusTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

    final String name = product['name']?.toString() ?? 'Product';
    String resolvedImageUrl = (product['image_url'] ??
            product['image'] ??
            product['photo_url'] ??
            product['cover_image'])
        ?.toString() ??
        '';

    if (resolvedImageUrl.isEmpty &&
        product['image_urls'] is List &&
        (product['image_urls'] as List).isNotEmpty) {
      resolvedImageUrl = product['image_urls'][0].toString();
    }

    final String imageUrl = resolvedImageUrl.trim();
    final String category = product['category']?.toString() ?? 'Fashion';
    String size = item['selected_size']?.toString() ?? '';
    String color = item['selected_color']?.toString() ?? '';

    if (color.isEmpty) {
      final rawCol = product['color']?.toString() ?? '';
      if (rawCol.isNotEmpty) {
        color = rawCol.split(RegExp(r'[,|/•]+')).first.trim();
      }
    }
    if (size.isEmpty) {
      final rawSz = product['size']?.toString() ?? '';
      if (rawSz.isNotEmpty) {
        size = rawSz.split(RegExp(r'[,|/•]+')).first.trim();
      }
    }

    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;

    final String formattedPrice = "Rs. ${price.toStringAsFixed(0)}";
    final String sizeLabel = size.isNotEmpty ? (size.toLowerCase().startsWith('size') ? size : "Size: $size") : '';
    final String colorLabel = color.isNotEmpty ? (color.toLowerCase().startsWith('color') ? color : "Color: $color") : '';
    final String subtitle = [category, colorLabel, sizeLabel].where((s) => s.trim().isNotEmpty).join(" • ");

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "Remove",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.delete_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ================= 1. Product Image Card (Full Fit without Crop) =================
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),

              const SizedBox(width: 12),

              // ================= 2. Details & Controls =================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row: Title + Quick Remove
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.slateDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onRemove,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.slateMuted,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Subtitle / Attributes Chip
                    if (subtitle.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Text(
                        "StyLuxe Collection",
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Bottom Row: Price + Quantity Selector Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price in Emerald Primary Accent
                        Text(
                          formattedPrice,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        // Quantity Selector Pill
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Minus Button
                              InkWell(
                                onTap: () {
                                  if (quantity > 1) {
                                    onQuantityChanged(quantity - 1);
                                  } else {
                                    onRemove();
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 13,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                              ),

                              // Quantity Number
                              Container(
                                constraints: const BoxConstraints(minWidth: 22),
                                alignment: Alignment.center,
                                child: Text(
                                  "$quantity",
                                  style: const TextStyle(
                                    color: AppColors.slateDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              // Plus Button
                              InkWell(
                                onTap: onPlusTap ?? () => onQuantityChanged(quantity + 1),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 24,
        color: AppColors.slateMuted,
      ),
    );
  }
}
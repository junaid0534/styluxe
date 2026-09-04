import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service to manage dynamic product inventory / stock counts.
/// Handles:
/// - Stock deduction / reverse count when orders are placed or shipped
/// - Stock restoration when orders are cancelled or refunded
/// - Live stock fetching and real-time subscription
class InventoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Deducts product stock for a list of items.
  static Future<void> deductStockForOrderItems(List<Map<String, dynamic>> items) async {
    for (final item in items) {
      try {
        String? productId;
        if (item['product_id'] != null) {
          productId = item['product_id'].toString();
        } else if (item['products'] is Map && item['products']['id'] != null) {
          productId = item['products']['id'].toString();
        } else if (item['id'] != null && item['products'] == null) {
          productId = item['id'].toString();
        }

        final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;

        if (productId == null || productId.isEmpty || quantity <= 0) {
          debugPrint("⚠️ InventoryService: Skipping invalid item: $item");
          continue;
        }

        bool rpcDone = false;
        try {
          await _supabase.rpc('decrement_product_stock', params: {
            'p_product_id': productId,
            'p_qty': quantity,
          });
          rpcDone = true;
          debugPrint("⚡ RPC Stock Deducted for product $productId: (-$quantity)");
        } catch (rpcErr) {
          debugPrint("RPC decrement_product_stock note: $rpcErr");
        }

        if (!rpcDone) {
          final productRes = await _supabase
              .from('products')
              .select('stock, is_active')
              .eq('id', productId)
              .maybeSingle();

          if (productRes != null) {
            final int currentStock = (productRes['stock'] as num?)?.toInt() ?? 0;
            final int newStock = (currentStock - quantity).clamp(0, 999999);
            final bool newActive = newStock > 0 ? (productRes['is_active'] ?? true) : false;

            final updated = await _supabase.from('products').update({
              'stock': newStock,
              'is_active': newActive,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', productId).select('id, stock');

            debugPrint("📦 Direct Stock Update result: $updated (was $currentStock -> target $newStock)");
          }
        }
      } catch (e) {
        debugPrint("⚠️ InventoryService.deductStock error: $e");
      }
    }
  }

  /// Deducts stock for an entire order by its order ID.
  static Future<void> deductStockForOrder(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      var items = await _supabase
          .from('order_items')
          .select('product_id, quantity')
          .eq('order_id', orderId);

      if (items.isEmpty) {
        final ord = await _supabase
            .from('orders')
            .select('id, order_id')
            .or('id.eq.$orderId,order_id.eq.$orderId')
            .maybeSingle();

        if (ord != null) {
          final targetId = ord['id']?.toString() ?? '';
          if (targetId.isNotEmpty && targetId != orderId) {
            items = await _supabase
                .from('order_items')
                .select('product_id, quantity')
                .eq('order_id', targetId);
          }
        }
      }

      if (items.isNotEmpty) {
        await deductStockForOrderItems(List<Map<String, dynamic>>.from(items));
      }
    } catch (e) {
      debugPrint("⚠️ InventoryService.deductStockForOrder error: $e");
    }
  }

  /// Restores product stock when an order is cancelled or refunded.
  static Future<void> restoreStockForOrder(String orderId) async {
    if (orderId.isEmpty) return;

    try {
      var items = await _supabase
          .from('order_items')
          .select('product_id, quantity')
          .eq('order_id', orderId);

      if (items.isEmpty) {
        final ord = await _supabase
            .from('orders')
            .select('id, order_id')
            .or('id.eq.$orderId,order_id.eq.$orderId')
            .maybeSingle();

        if (ord != null) {
          final targetId = ord['id']?.toString() ?? '';
          if (targetId.isNotEmpty && targetId != orderId) {
            items = await _supabase
                .from('order_items')
                .select('product_id, quantity')
                .eq('order_id', targetId);
          }
        }
      }

      for (final item in items) {
        final String? productId = item['product_id']?.toString();
        final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;

        if (productId == null || productId.isEmpty || quantity <= 0) continue;

        bool rpcDone = false;
        try {
          await _supabase.rpc('restore_product_stock', params: {
            'p_product_id': productId,
            'p_qty': quantity,
          });
          rpcDone = true;
          debugPrint("⚡ RPC Stock Restored for product $productId: (+$quantity)");
        } catch (_) {}

        if (!rpcDone) {
          final productRes = await _supabase
              .from('products')
              .select('stock, is_active')
              .eq('id', productId)
              .maybeSingle();

          if (productRes != null) {
            final int currentStock = (productRes['stock'] as num?)?.toInt() ?? 0;
            final int newStock = currentStock + quantity;

            await _supabase.from('products').update({
              'stock': newStock,
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', productId).select('id, stock');

            debugPrint("🔄 Direct Stock Restored for product $productId: $currentStock -> $newStock (+$quantity)");
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ InventoryService.restoreStockForOrder error: $e");
    }
  }

  /// Fetches live stock integer for a given product ID.
  static Future<int> fetchLiveStock(String productId) async {
    if (productId.isEmpty) return 0;
    try {
      final res = await _supabase
          .from('products')
          .select('stock')
          .eq('id', productId)
          .maybeSingle();

      if (res != null) {
        return (res['stock'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint("⚠️ InventoryService.fetchLiveStock error: $e");
    }
    return 0;
  }
}

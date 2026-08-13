import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> order;
  StreamSubscription<List<Map<String, dynamic>>>? _orderSubscription;

  @override
  void initState() {
    super.initState();

    order = Map<String, dynamic>.from(widget.order);

    fetchLatestOrder();
    setupRealtimeOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  // ================= FETCH LATEST ORDER =================
  Future<void> fetchLatestOrder() async {
    try {
      final orderId = order['id'];

      if (orderId == null) return;

      final data = await supabase
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .maybeSingle();

      if (!mounted || data == null) return;

      setState(() {
        order = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      debugPrint("Fetch latest tracking order error: $e");
    }
  }

  // ================= REALTIME ORDER UPDATE =================
  void setupRealtimeOrder() {
    try {
      final orderId = order['id'];

      if (orderId == null) return;

      _orderSubscription = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('id', orderId)
          .listen(
            (data) {
              if (!mounted) return;

              if (data.isNotEmpty) {
                setState(() {
                  order = Map<String, dynamic>.from(data.first);
                });
              }
            },
            onError: (error) {
              debugPrint("Order tracking realtime error: $error");
            },
          );
    } catch (e) {
      debugPrint("Realtime tracking setup error: $e");
    }
  }

  // ================= HELPERS =================
  String _orderNumber() {
    final orderId = order['order_id']?.toString();

    if (orderId != null && orderId.trim().isNotEmpty) {
      return orderId;
    }

    final id = order['id']?.toString() ?? '00000000';

    return id.length >= 8 ? id.substring(0, 8) : id;
  }

  String _status() {
    return order['status']?.toString() ?? 'Pending';
  }

  int _currentStepIndex(String status) {
    final value = status.toLowerCase();

    if (value == 'pending') return 0;
    if (value == 'processing') return 1;
    if (value == 'shipped') return 2;
    if (value == 'delivered') return 3;
    if (value == 'cancelled' || value == 'canceled') return -1;

    return 0;
  }

  bool _isCancelled(String status) {
    final value = status.toLowerCase();
    return value == 'cancelled' || value == 'canceled';
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();

    if (value == 'delivered') return const Color(0xFF16A34A);
    if (value == 'shipped') return const Color(0xFF2563EB);
    if (value == 'processing') return const Color(0xFF7C3AED);
    if (value == 'cancelled' || value == 'canceled') {
      return const Color(0xFFDC2626);
    }

    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon(String status) {
    final value = status.toLowerCase();

    if (value == 'delivered') return Icons.check_circle_rounded;
    if (value == 'shipped') return Icons.local_shipping_rounded;
    if (value == 'processing') return Icons.sync_rounded;
    if (value == 'cancelled' || value == 'canceled') {
      return Icons.cancel_rounded;
    }

    return Icons.access_time_filled_rounded;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty) return "N/A";

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }

    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";
  }

  String _estimatedDeliveryDate() {
    final raw = order['created_at']?.toString();
    final createdAt = DateTime.tryParse(raw ?? '');

    final estimated = createdAt == null
        ? DateTime.now().add(const Duration(days: 5))
        : createdAt.add(const Duration(days: 5));

    return "${estimated.day.toString().padLeft(2, '0')}-"
        "${estimated.month.toString().padLeft(2, '0')}-"
        "${estimated.year}";
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final statusColor = _statusColor(status);
    final currentStep = _currentStepIndex(status);
    final isCancelled = _isCancelled(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= SAME PREVIOUS APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFFA8E063),
        surfaceTintColor: const Color(0xFFA8E063),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Track Order",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF111827),
            ),
            onPressed: fetchLatestOrder,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: fetchLatestOrder,
        color: const Color(0xFF22C55E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= ORDER SUMMARY CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.055),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order #${_orderNumber()}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Placed on ${_formatDate(order['created_at'])}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _statusIcon(status),
                            color: statusColor,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isCancelled
                                  ? "Order Status: Cancelled"
                                  : "Current Status: $status",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _MiniInfoBox(
                            title: "Estimated Delivery",
                            value: isCancelled ? "Not Available" : _estimatedDeliveryDate(),
                            icon: Icons.event_available_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniInfoBox(
                            title: "Live Update",
                            value: "Enabled",
                            icon: Icons.wifi_tethering_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.08, end: 0),

              const SizedBox(height: 26),

              const Text(
                "Order Status",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 16),

              // ================= CANCELLED BOX =================
              if (isCancelled)
                _CancelledStatusBox()
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _TrackingStep(
                        title: "Order Placed",
                        subtitle: "We received your order",
                        isCompleted: currentStep >= 0,
                        isActive: currentStep == 0,
                        time: "Confirmed",
                      ),
                      _TrackingStep(
                        title: "Processing",
                        subtitle: "Seller is preparing your order",
                        isCompleted: currentStep >= 1,
                        isActive: currentStep == 1,
                        time: currentStep >= 1 ? "In progress" : "Waiting",
                      ),
                      _TrackingStep(
                        title: "Shipped",
                        subtitle: "Order has been shipped",
                        isCompleted: currentStep >= 2,
                        isActive: currentStep == 2,
                        time: currentStep >= 2 ? "On the way" : "Waiting",
                      ),
                      _TrackingStep(
                        title: "Delivered",
                        subtitle: "Order has been delivered",
                        isCompleted: currentStep >= 3,
                        isActive: currentStep == 3,
                        time: currentStep >= 3 ? "Completed" : "Expected soon",
                        isLast: true,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),

              const SizedBox(height: 26),

              // ================= MAP PLACEHOLDER =================
              Container(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -34,
                      top: -34,
                      child: _CircleDecoration(
                        size: 110,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      left: -38,
                      bottom: -38,
                      child: _CircleDecoration(
                        size: 120,
                        color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              size: 34,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Live Tracking Map",
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Coming Soon",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ================= SUPPORT CARD =================
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Support chat opening..."),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4F46E5),
                              Color(0xFF7C3AED),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.headset_mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Need Help?",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Talk to our support team",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF111827),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MINI INFO BOX =================
class _MiniInfoBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniInfoBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TRACKING STEP =================
class _TrackingStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final String time;
  final bool isLast;

  const _TrackingStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isCompleted
        ? const Color(0xFF22C55E)
        : isActive
            ? const Color(0xFF6366F1)
            : const Color(0xFFD1D5DB);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? const Color(0xFF22C55E)
                    : isActive
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFE5E7EB),
                boxShadow: isCompleted || isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : isActive
                      ? const Icon(
                          Icons.sync_rounded,
                          color: Colors.white,
                          size: 17,
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 58,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
          ],
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? const Color(0xFFF8FAFC)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCompleted || isActive
                      ? const Color(0xFFE5E7EB)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCompleted || isActive
                                ? const Color(0xFF111827)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCompleted || isActive
                          ? const Color(0xFF22C55E)
                          : Colors.grey.shade500,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ================= CANCELLED BOX =================
class _CancelledStatusBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cancel_rounded,
              color: Color(0xFFDC2626),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Order Cancelled",
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "This order has been cancelled by the seller or admin.",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= CIRCLE DECORATION =================
class _CircleDecoration extends StatelessWidget {
  final double size;
  final Color color;

  const _CircleDecoration({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
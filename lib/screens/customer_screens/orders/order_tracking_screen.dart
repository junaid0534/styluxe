import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../profile_features/help_support_screen.dart';

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
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
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
    if (value == 'delivered') return const Color(0xFF10B981);
    if (value == 'shipped') return const Color(0xFF3B82F6);
    if (value == 'processing') return const Color(0xFF8B5CF6);
    if (value == 'cancelled' || value == 'canceled') return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered') return Icons.check_circle_rounded;
    if (value == 'shipped') return Icons.local_shipping_rounded;
    if (value == 'processing') return Icons.sync_rounded;
    if (value == 'cancelled' || value == 'canceled') return Icons.cancel_rounded;
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
        ? DateTime.now().add(const Duration(days: 3))
        : createdAt.add(const Duration(days: 3));

    return "${estimated.day.toString().padLeft(2, '0')}-"
        "${estimated.month.toString().padLeft(2, '0')}-"
        "${estimated.year}";
  }

  double _getProgressPercentage(int currentStep) {
    if (currentStep < 0) return 0.0;
    if (currentStep == 0) return 0.25;
    if (currentStep == 1) return 0.50;
    if (currentStep == 2) return 0.75;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final statusColor = _statusColor(status);
    final currentStep = _currentStepIndex(status);
    final isCancelled = _isCancelled(status);
    final progress = _getProgressPercentage(currentStep);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= PURE WHITE STYLUXE APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 17),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Track Order Progress",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Need Help",
            icon: const Icon(Icons.headset_mic_outlined, color: AppColors.slateDark, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
              );
            },
          ),
          IconButton(
            tooltip: "Refresh Live Status",
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22),
            onPressed: fetchLatestOrder,
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: RefreshIndicator(
              onRefresh: fetchLatestOrder,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= STYLUXE HERO TRACKING BANNER =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.20),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Order #${_orderNumber()}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Placed on ${_formatDate(order['created_at'])}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.88),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_statusIcon(status), size: 13, color: statusColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Live Progress Bar (0% to 100%)
                          if (!isCancelled) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Shipment Progress",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  "${(progress * 100).toInt()}% Completed",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),

                    const SizedBox(height: 16),

                    // Quick Meta Cards (Est Delivery & Courier ID)
                    Row(
                      children: [
                        Expanded(
                          child: _MiniInfoCard(
                            title: "ESTIMATED DELIVERY",
                            value: isCancelled ? "Cancelled" : _estimatedDeliveryDate(),
                            icon: Icons.event_available_outlined,
                            accentColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniInfoCard(
                            title: "COURIER PARTNER",
                            value: "StyLuxe Express",
                            icon: Icons.local_post_office_outlined,
                            accentColor: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),

                    const SizedBox(height: 22),

                    // ================= LIVE TRACKING TIMELINE =================
                    const Text(
                      "Live Order Timeline",
                      style: TextStyle(
                        color: AppColors.slateDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (isCancelled)
                      _CancelledStatusCard()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.06)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
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
                          children: [
                            _TrackingTimelineStep(
                              title: "Order Placed & Confirmed",
                              description: "Your order details have been sent to seller",
                              isCompleted: currentStep >= 0,
                              isActive: currentStep == 0,
                              timestamp: _formatDate(order['created_at']),
                            ),
                            _TrackingTimelineStep(
                              title: "Order Processing & Inspection",
                              description: "Seller is preparing and quality inspecting your apparel",
                              isCompleted: currentStep >= 1,
                              isActive: currentStep == 1,
                              timestamp: currentStep >= 1 ? "In progress" : "Pending",
                            ),
                            _TrackingTimelineStep(
                              title: "Shipped & Out for Delivery",
                              description: "Dispatched with courier tracking ID #STL-${_orderNumber()}",
                              isCompleted: currentStep >= 2,
                              isActive: currentStep == 2,
                              timestamp: currentStep >= 2 ? "On the way" : "Pending",
                            ),
                            _TrackingTimelineStep(
                              title: "Package Delivered",
                              description: "Handed over safely to customer delivery address",
                              isCompleted: currentStep >= 3,
                              isActive: currentStep == 3,
                              timestamp: currentStep >= 3 ? "Completed" : "Estimated soon",
                              isLast: true,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06),

                    const SizedBox(height: 22),

                    // ================= COURIER TRACKING ID CARD =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TRACKING CODE",
                                  style: TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "STL-${_orderNumber()}",
                                  style: const TextStyle(
                                    color: AppColors.slateDark,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: "STL-${_orderNumber()}"));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Tracking code copied to clipboard!"),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.slateDark),
                            label: const Text("Copy", style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),

                    const SizedBox(height: 20),

                    // ================= NEED HELP / SUPPORT ROW =================
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Have questions about your delivery?",
                                    style: TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    "Contact StyLuxe 24/7 Customer Support",
                                    style: TextStyle(
                                      color: AppColors.slateMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slateMuted),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.06),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= MINI INFO CARD =================
class _MiniInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _MiniInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.slateMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.slateDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TIMELINE STEP WIDGET =================
class _TrackingTimelineStep extends StatelessWidget {
  final String title;
  final String description;
  final bool isCompleted;
  final bool isActive;
  final String timestamp;
  final bool isLast;

  const _TrackingTimelineStep({
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isActive,
    required this.timestamp,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color stepColor = isCompleted
        ? AppColors.primary
        : (isActive ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Dot & Vertical Connecting Line Column
          Column(
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  color: isCompleted || isActive ? stepColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: stepColor, width: 2),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : (isActive ? Icons.sync_rounded : Icons.circle_outlined),
                  size: 14,
                  color: isCompleted || isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.primary : const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // Step Title, Description, and Timestamp
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isCompleted || isActive ? AppColors.slateDark : AppColors.slateMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: isCompleted ? AppColors.primary : AppColors.slateMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= CANCELLED STATUS CARD =================
class _CancelledStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order Cancelled",
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "This order was cancelled. If you need any assistance, please contact our support.",
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12.5,
                    height: 1.4,
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
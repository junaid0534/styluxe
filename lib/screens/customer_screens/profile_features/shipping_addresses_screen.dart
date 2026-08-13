import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShippingAddressesScreen extends StatefulWidget {
  const ShippingAddressesScreen({super.key});

  @override
  State<ShippingAddressesScreen> createState() =>
      _ShippingAddressesScreenState();
}

class _ShippingAddressesScreenState extends State<ShippingAddressesScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAddresses();
  }

  // ================= FETCH ADDRESSES =================
  Future<void> fetchAddresses() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Please login first");
      }

      final data = await supabase
          .from('shipping_addresses')
          .select('*')
          .eq('user_id', currentUser.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        addresses = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= ADD / EDIT ADDRESS =================
  Future<void> openAddAddress({Map<String, dynamic>? address}) async {
    final result = await Navigator.pushNamed(
      context,
      '/add_address',
      arguments: address,
    );

    if (!mounted) return;

    if (result == true || result == null) {
      fetchAddresses();
    }
  }

  // ================= DELETE ADDRESS =================
  Future<void> deleteAddress(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Delete Address?",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          content: const Text(
            "This action cannot be undone.",
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase.from('shipping_addresses').delete().eq('id', id);

      if (!mounted) return;

      setState(() {
        addresses.removeWhere((address) => address['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Address deleted successfully"),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _defaultCount() {
    return addresses.where((address) => address['is_default'] == true).length;
  }

  @override
  Widget build(BuildContext context) {
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
          "Shipping Addresses",
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
            tooltip: "Add Address",
            icon: const Icon(
              Icons.add_rounded,
              color: Color(0xFF111827),
              size: 27,
            ),
            onPressed: () => openAddAddress(),
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF111827),
            ),
            onPressed: fetchAddresses,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
              ),
            )
          : addresses.isEmpty
              ? _emptyAddressView()
              : RefreshIndicator(
                  onRefresh: fetchAddresses,
                  color: const Color(0xFF22C55E),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _summaryCard()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 18),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Saved Addresses",
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...List.generate(addresses.length, (index) {
                        final address = addresses[index];

                        return AddressCard(
                          address: address,
                          onEdit: () => openAddAddress(address: address),
                          onDelete: () => deleteAddress(address['id']),
                        )
                            .animate()
                            .fadeIn(
                              duration: 350.ms,
                              delay: (index * 70).ms,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic,
                            );
                      }),
                    ],
                  ),
                ),

      // ================= FLOATING ADD BUTTON =================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAddAddress(),
        backgroundColor: const Color(0xFF22C55E),
        elevation: 4,
        icon: const Icon(
          Icons.add_location_alt_outlined,
          color: Colors.white,
        ),
        label: const Text(
          "Add Address",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -40,
            child: _GlowCircle(
              size: 125,
              opacity: 0.12,
            ),
          ),
          Positioned(
            left: -40,
            bottom: -45,
            child: _GlowCircle(
              size: 135,
              opacity: 0.08,
            ),
          ),
          Row(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Address Book",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${addresses.length} saved address${addresses.length == 1 ? '' : 'es'} • ${_defaultCount()} default",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyAddressView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 46,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 50,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "No addresses saved yet",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Add your delivery address to make checkout faster.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => openAddAddress(),
                  icon: const Icon(
                    Icons.add_location_alt_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                  label: const Text(
                    "Add Address",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).scale(),
      ),
    );
  }
}

// ================= ADDRESS CARD =================
class AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AddressCard({
    super.key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  bool _isDefault() {
    final value = address['is_default'];

    if (value == true) return true;
    if (value == 1) return true;
    if (value.toString().toLowerCase() == 'true') return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = _isDefault();

    final fullName = address['full_name']?.toString() ?? '';
    final phone = address['phone']?.toString() ?? '';
    final addressText = address['address']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDefault
              ? const Color(0xFF22C55E)
              : const Color(0xFFE5E7EB),
          width: isDefault ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isDefault
                        ? const Color(0xFF22C55E).withValues(alpha: 0.11)
                        : const Color(0xFF6366F1).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    isDefault
                        ? Icons.verified_rounded
                        : Icons.location_on_outlined,
                    color: isDefault
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF6366F1),
                    size: 25,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? "Unnamed Address" : fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.isEmpty ? "No phone number" : phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Text(
                      "Default",
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_outlined,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        addressText,
                        city,
                      ].where((item) => item.trim().isNotEmpty).join(", "),
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 13.8,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
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
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        "Edit",
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(
                          color: Color(0xFF4F46E5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "Delete",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================= GLOW CIRCLE =================
class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
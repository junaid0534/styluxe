import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';

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
  StreamSubscription<List<Map<String, dynamic>>>? _addressesSubscription;

  @override
  void initState() {
    super.initState();
    fetchAddresses();
    setupRealtimeAddresses();
  }

  @override
  void dispose() {
    _addressesSubscription?.cancel();
    super.dispose();
  }

  // ================= AUTO REFRESH / REALTIME ADDRESSES =================
  void setupRealtimeAddresses() {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      _addressesSubscription = supabase
          .from('shipping_addresses')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUser.id)
          .listen(
            (data) {
              if (!mounted) return;

              final updated = List<Map<String, dynamic>>.from(data);
              updated.sort((a, b) {
                final aDef = a['is_default'] == true ? 1 : 0;
                final bDef = b['is_default'] == true ? 1 : 0;
                if (aDef != bDef) return bDef.compareTo(aDef);
                final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
                final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
                return bDate.compareTo(aDate);
              });

              setState(() {
                addresses = updated;
                isLoading = false;
              });
            },
            onError: (error) {
              debugPrint("Realtime address error: $error");
            },
          );
    } catch (e) {
      debugPrint("Realtime setup error: $e");
    }
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
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: AppColors.roseRed, size: 22),
              SizedBox(width: 8),
              Text(
                "Delete Address?",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateDark,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to delete this address? This action cannot be undone.",
            style: TextStyle(
              color: AppColors.slateMuted,
              fontSize: 13.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.slateMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.roseRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
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
          backgroundColor: AppColors.primary,
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

      // ================= PURE WHITE STYLUXE APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Shipping Addresses",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Add Address",
            icon: const Icon(
              Icons.add_location_alt_outlined,
              color: AppColors.slateDark,
              size: 22,
            ),
            onPressed: () => openAddAddress(),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : addresses.isEmpty
              ? _emptyAddressView()
              : RefreshIndicator(
                  onRefresh: fetchAddresses,
                  color: AppColors.primary,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        children: [
                          _summaryCard()
                              .animate()
                              .fadeIn(duration: 350.ms)
                              .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Saved Locations",
                          style: TextStyle(
                            color: AppColors.slateDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                              duration: 300.ms,
                              delay: (index * 50).ms,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              duration: 300.ms,
                            );
                      }),
                    ],
                  ),
                ),
              ),
            ),

      // ================= FLOATING ADD BUTTON =================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAddAddress(),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(
          Icons.add_location_alt_outlined,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          "Add New Address",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
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
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 28,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${addresses.length} saved address${addresses.length == 1 ? '' : 'es'} • ${_defaultCount()} default",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "No Addresses Saved",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Add your delivery address to make checkout faster.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => openAddAddress(),
                  icon: const Icon(
                    Icons.add_location_alt_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    "Add New Address",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDefault
              ? AppColors.primary
              : const Color(0xFFE2E8F0),
          width: isDefault ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: isDefault
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDefault
                        ? Icons.verified_rounded
                        : Icons.location_on_outlined,
                    color: isDefault
                        ? AppColors.primary
                        : AppColors.slateDark,
                    size: 22,
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
                          color: AppColors.slateDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        phone.isEmpty ? "No phone number" : phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: AppColors.primary, size: 12),
                        SizedBox(width: 3),
                        Text(
                          "Default",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_outlined,
                    color: AppColors.slateMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        addressText,
                        city,
                      ].where((item) => item.trim().isNotEmpty).join(", "),
                      style: const TextStyle(
                        color: AppColors.slateDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ================= ACTION BUTTONS (NO ICONS, INCREASED SIZE) =================
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Edit",
                        style: TextStyle(
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onDelete,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.roseRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.2,
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
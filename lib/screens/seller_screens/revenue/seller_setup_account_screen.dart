import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerSetupAccountScreen extends StatefulWidget {
  final String methodType; // EasyPaisa, JazzCash, BankCard
  final Map<String, dynamic>? existingData;

  const SellerSetupAccountScreen({
    super.key,
    required this.methodType,
    this.existingData,
  });

  @override
  State<SellerSetupAccountScreen> createState() => _SellerSetupAccountScreenState();
}

class _SellerSetupAccountScreenState extends State<SellerSetupAccountScreen> {
  final supabase = Supabase.instance.client;

  late final TextEditingController _titleController;
  late final TextEditingController _numberController;
  late final TextEditingController _bankNameController;

  bool isSaving = false;

  Color get _brandColor {
    if (widget.methodType == "EasyPaisa") return const Color(0xFF00A651); // EasyPaisa Green
    if (widget.methodType == "JazzCash") return const Color(0xFFD32F2F); // JazzCash Red
    return const Color(0xFF2563EB); // Bank Royal Blue
  }

  IconData get _brandIcon {
    if (widget.methodType == "EasyPaisa") return Icons.account_balance_wallet_rounded;
    if (widget.methodType == "JazzCash") return Icons.mobile_friendly_rounded;
    return Icons.credit_card_rounded;
  }

  String get _displayTitle {
    if (widget.methodType == "EasyPaisa") return "EasyPaisa Wallet";
    if (widget.methodType == "JazzCash") return "JazzCash Wallet";
    return "Bank Account / IBAN";
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingData?['title'] ?? widget.existingData?['name'] ?? '',
    );
    _numberController = TextEditingController(
      text: widget.existingData?['number'] ?? widget.existingData?['iban'] ?? '',
    );
    _bankNameController = TextEditingController(
      text: widget.existingData?['bank'] ?? 'HBL Bank',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    final title = _titleController.text.trim();
    final number = _numberController.text.trim();

    if (title.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final payload = <String, dynamic>{
          'title': title,
          'number': number,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (widget.methodType == "BankCard") {
          payload['bank'] = _bankNameController.text.trim();
        }

        // 1. Save to seller_payout_methods table
        try {
          await supabase.from('seller_payout_methods').upsert({
            'seller_id': user.id,
            'method_type': widget.methodType,
            'account_title': title,
            'account_number': number,
            'bank_name': widget.methodType == "BankCard" ? _bankNameController.text.trim() : null,
            'is_default': true,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'seller_id, method_type');
        } catch (_) {}

        // 2. Backup to User Metadata
        final key = widget.methodType == "EasyPaisa"
            ? 'payout_easypaisa'
            : (widget.methodType == "JazzCash" ? 'payout_jazzcash' : 'payout_bankcard');

        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              key: payload,
              'payout_default_method': widget.methodType,
            },
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$_displayTitle Saved Successfully!"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          "Setup $_displayTitle",
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _brandColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _brandColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_brandIcon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayTitle,
                              style: TextStyle(color: _brandColor, fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Payout Account Details",
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (widget.methodType == "BankCard") ...[
                  const Text("Bank Name", style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bankNameController,
                    decoration: InputDecoration(
                      hintText: "e.g. HBL, Meezan Bank, Allied Bank, UBL",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _brandColor, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text("Account Holder Title", style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: "Full Name on Account (e.g. Muhammad Junaid)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _brandColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  widget.methodType == "BankCard" ? "Account / IBAN Number" : "Mobile Wallet Number",
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _numberController,
                  keyboardType: widget.methodType == "BankCard" ? TextInputType.text : TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: widget.methodType == "BankCard" ? "PK36 HABB 0001 2345 6789 0123" : "0300 1234567",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _brandColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isSaving ? null : _saveAccount,
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save Account", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

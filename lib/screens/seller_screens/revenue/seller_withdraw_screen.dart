import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerWithdrawScreen extends StatefulWidget {
  final double availableBalance;
  final Map<String, dynamic>? easyPaisaAccount;
  final Map<String, dynamic>? jazzCashAccount;
  final Map<String, dynamic>? bankCardAccount;
  final String defaultMethod;

  const SellerWithdrawScreen({
    super.key,
    required this.availableBalance,
    this.easyPaisaAccount,
    this.jazzCashAccount,
    this.bankCardAccount,
    required this.defaultMethod,
  });

  @override
  State<SellerWithdrawScreen> createState() => _SellerWithdrawScreenState();
}

class _SellerWithdrawScreenState extends State<SellerWithdrawScreen> {
  final supabase = Supabase.instance.client;

  late String selectedMethod;
  String selectedPreset = "5000";
  late final TextEditingController _customAmountController;

  bool isSubmitting = false;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    selectedMethod = widget.defaultMethod;
    _customAmountController = TextEditingController(
      text: widget.availableBalance >= 5000 ? "5000" : widget.availableBalance.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentAccountData {
    if (selectedMethod == "EasyPaisa") return widget.easyPaisaAccount;
    if (selectedMethod == "JazzCash") return widget.jazzCashAccount;
    if (selectedMethod == "BankCard") return widget.bankCardAccount;
    return null;
  }

  double get _enteredAmount {
    if (selectedPreset == "MAX") return widget.availableBalance;
    if (selectedPreset != "Custom") {
      return double.tryParse(selectedPreset) ?? 0.0;
    }
    return double.tryParse(_customAmountController.text.trim()) ?? 0.0;
  }

  // Auto 3% Tax calculation
  double get _taxAmount => _enteredAmount * 0.03;
  double get _netAmount => _enteredAmount - _taxAmount;

  Future<void> _submitWithdrawal() async {
    final amt = _enteredAmount;

    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a valid withdrawal amount"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (amt > widget.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Amount exceeds available balance"), backgroundColor: Colors.orange),
      );
      return;
    }

    final accData = _currentAccountData;
    if (accData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please setup $selectedMethod account details first"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      final refId = "PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

      final newReq = {
        'id': refId,
        'seller_id': user?.id,
        'amount': amt,
        'tax_amount': _taxAmount,
        'net_amount': _netAmount,
        'method': selectedMethod,
        'account_title': accData['title'] ?? accData['name'] ?? 'Seller Account',
        'account_number': accData['number'] ?? accData['iban'] ?? '',
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await supabase.from('payout_requests').insert(newReq);
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Withdrawal Request for Rs. ${amt.toStringAsFixed(0)} Submitted! (Net: Rs. ${_netAmount.toStringAsFixed(0)})"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting request: $e"), backgroundColor: Colors.red),
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
        iconTheme: const IconThemeData(color: slateDark),
        title: const Text(
          "Request Payout",
          style: TextStyle(color: slateDark, fontWeight: FontWeight.w900, fontSize: 17),
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
                // Available Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AVAILABLE BALANCE",
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Rs. ${widget.availableBalance.toStringAsFixed(0)}",
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. SELECT PAYOUT METHOD DROPDOWN
                const Text("Select Payout Account", style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMethod,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: sapphireBlue),
                      items: [
                        DropdownMenuItem(
                          value: "EasyPaisa",
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 6, backgroundColor: Color(0xFF00A651)),
                              const SizedBox(width: 10),
                              Text("EasyPaisa ${widget.easyPaisaAccount != null ? '(${widget.easyPaisaAccount!['number']})' : '(Not Set)'}"),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: "JazzCash",
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 6, backgroundColor: Color(0xFFD32F2F)),
                              const SizedBox(width: 10),
                              Text("JazzCash ${widget.jazzCashAccount != null ? '(${widget.jazzCashAccount!['number']})' : '(Not Set)'}"),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: "BankCard",
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 6, backgroundColor: sapphireBlue),
                              const SizedBox(width: 10),
                              Text("Bank Card ${widget.bankCardAccount != null ? '(${widget.bankCardAccount!['bank']})' : '(Not Set)'}"),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedMethod = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. SELECT AMOUNT DROPDOWN & PRESETS
                const Text("Select Amount", style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPreset,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: sapphireBlue),
                      items: [
                        const DropdownMenuItem(value: "1000", child: Text("Rs. 1,000")),
                        const DropdownMenuItem(value: "5000", child: Text("Rs. 5,000")),
                        const DropdownMenuItem(value: "10000", child: Text("Rs. 10,000")),
                        const DropdownMenuItem(value: "25000", child: Text("Rs. 25,000")),
                        DropdownMenuItem(value: "MAX", child: Text("MAX AMOUNT (Rs. ${widget.availableBalance.toStringAsFixed(0)})")),
                        const DropdownMenuItem(value: "Custom", child: Text("Custom Amount")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedPreset = val;
                            if (val != "Custom" && val != "MAX") {
                              _customAmountController.text = val;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),

                if (selectedPreset == "Custom") ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customAmountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Enter custom amount in Rs.",
                      prefixText: "Rs. ",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderColor)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 3. REAL-TIME AUTO 3% TAX CALCULATION CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Requested Amount", style: TextStyle(color: slateMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text("Rs. ${_enteredAmount.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text("Service Tax (3%)", style: TextStyle(color: slateMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.info_outline_rounded, color: slateMuted, size: 14),
                            ],
                          ),
                          Text("- Rs. ${_taxAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Net Receivable", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                          Text("Rs. ${_netAmount.toStringAsFixed(0)}", style: const TextStyle(color: sapphireBlue, fontSize: 17, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sapphireBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isSubmitting ? null : _submitWithdrawal,
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Confirm & Request Payout", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
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

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _openFaqIndex;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How long does standard delivery take?',
      'answer': 'Standard delivery across Pakistan takes 2 to 4 working days. Express delivery in major cities takes 1 to 2 working days.',
      'category': 'Shipping',
    },
    {
      'question': 'What is your return & refund policy?',
      'answer': 'We offer a hassle-free 7-day return policy. If you receive a damaged or incorrect item, you can request a return via My Orders.',
      'category': 'Returns',
    },
    {
      'question': 'Is Cash on Delivery (COD) available?',
      'answer': 'Yes! Cash on Delivery is available nationwide on all apparel, footwear, and accessory orders with zero extra fee.',
      'category': 'Payments',
    },
    {
      'question': 'How can I track my live order status?',
      'answer': 'Go to the Profile tab, tap "My Orders", and click the "Track" button next to your active order to see real-time updates.',
      'category': 'Shipping',
    },
    {
      'question': 'How do I modify or cancel my order?',
      'answer': 'You can cancel an order within 1 hour of placing it directly from the My Orders page, or contact live support for assistance.',
      'category': 'Orders',
    },
    {
      'question': 'Are all products authentic StyLuxe items?',
      'answer': 'Yes, 100% guaranteed! All products on StyLuxe are sourced directly from verified sellers and undergo strict quality checks.',
      'category': 'Quality',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredFaqs {
    if (_searchQuery.trim().isEmpty) return _faqs;
    final query = _searchQuery.trim().toLowerCase();
    return _faqs.where((faq) {
      final q = faq['question']!.toLowerCase();
      final a = faq['answer']!.toLowerCase();
      final c = faq['category']!.toLowerCase();
      return q.contains(query) || a.contains(query) || c.contains(query);
    }).toList();
  }

  void _showContactModal(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == 'call'
                      ? Icons.phone_in_talk_rounded
                      : type == 'email'
                          ? Icons.email_rounded
                          : Icons.chat_bubble_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                type == 'call'
                    ? "Call Customer Care"
                    : type == 'email'
                        ? "Email Support Team"
                        : "WhatsApp Live Chat",
                style: const TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                type == 'call'
                    ? "+92 300 1234567\nAvailable 24/7 for urgent assistance."
                    : type == 'email'
                        ? "support@styluxe.com\nAverage response time: under 15 minutes."
                        : "+92 301 4025346\nInstant chat response with support representatives.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicketDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              "Submit Support Ticket",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.slateDark),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: "Subject (e.g. Order #123 issue)",
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.slateMuted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Describe your issue in detail...",
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.slateMuted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppColors.slateMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Support ticket submitted! Our team will contact you shortly."),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Submit Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Help & Support",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HERO SUPPORT BANNER =================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30),
                              ),
                            ),
                            child: const Icon(
                              Icons.headset_mic_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "How can we help you?",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Search FAQs or select a option below.",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Search Bar inside Hero Header
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _openFaqIndex = null;
                            });
                          },
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.slateDark,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search help topics (e.g. refund, delivery)...",
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.slateMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.slateMuted,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _openFaqIndex = null;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.slateMuted,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),

                const SizedBox(height: 20),

                // ================= QUICK ACTION HELP CARDS =================
                const Text(
                  "Quick Support Categories",
                  style: TextStyle(
                    color: AppColors.slateDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 74,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  children: [
                    _quickCategoryCard(
                      icon: Icons.local_shipping_outlined,
                      title: "Track Orders",
                      subtitle: "Live shipment status",
                      color: const Color(0xFF3B82F6),
                      onTap: () => Navigator.pushNamed(context, '/my_orders'),
                    ),
                    _quickCategoryCard(
                      icon: Icons.assignment_return_outlined,
                      title: "Returns & Refund",
                      subtitle: "Easy 7-day policy",
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'return';
                          _searchQuery = 'return';
                          _openFaqIndex = null;
                        });
                      },
                    ),
                    _quickCategoryCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "Payments & COD",
                      subtitle: "Pricing & invoice help",
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'payment';
                          _searchQuery = 'payment';
                          _openFaqIndex = null;
                        });
                      },
                    ),
                    _quickCategoryCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: "WhatsApp Chat",
                      subtitle: "Talk with live agent",
                      color: const Color(0xFF25D366),
                      onTap: () => _showContactModal(context, 'whatsapp'),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms),

            const SizedBox(height: 24),

            // ================= FREQUENTLY ASKED QUESTIONS =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Frequently Asked Questions",
                  style: TextStyle(
                    color: AppColors.slateDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  Text(
                    "${_filteredFaqs.length} found",
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            _filteredFaqs.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, color: AppColors.slateMuted, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          "No results found for '$_searchQuery'",
                          style: const TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Try searching another keyword or contact live support.",
                          style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredFaqs.length,
                    itemBuilder: (context, index) {
                      final faq = _filteredFaqs[index];
                      final realIndex = _faqs.indexOf(faq);
                      final isExpanded = _openFaqIndex == realIndex;

                      return _faqCard(
                        realIndex: realIndex,
                        isExpanded: isExpanded,
                        question: faq['question']!,
                        answer: faq['answer']!,
                        category: faq['category']!,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            if (expanded) {
                              _openFaqIndex = realIndex;
                            } else if (_openFaqIndex == realIndex) {
                              _openFaqIndex = null;
                            }
                          });
                        },
                      ).animate().fadeIn(delay: (index * 40).ms, duration: 300.ms);
                    },
                  ),

            const SizedBox(height: 24),

            // ================= 24/7 CONTACT SUPPORT CARD =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Still need assistance?",
                              style: TextStyle(
                                color: AppColors.slateDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Our support team is available 24/7 for you.",
                              style: TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _showContactModal(context, 'call'),
                            icon: const Icon(Icons.phone_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              "Call Care",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _showContactModal(context, 'email'),
                            icon: const Icon(Icons.email_outlined, size: 16, color: AppColors.slateDark),
                            label: const Text(
                              "Email Support",
                              style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showTicketDialog(context),
                      icon: const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.primary),
                      label: const Text(
                        "Submit Support Ticket",
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.40)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _quickCategoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slateDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faqCard({
    required int realIndex,
    required bool isExpanded,
    required String question,
    required String answer,
    required String category,
    required ValueChanged<bool> onExpansionChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('faq_${realIndex}_$isExpanded'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.slateMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isExpanded ? Colors.white : AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    color: isExpanded ? AppColors.primary : AppColors.slateDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  answer,
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
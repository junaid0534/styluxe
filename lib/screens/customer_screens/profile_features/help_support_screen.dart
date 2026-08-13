import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              "How can we help you today?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "We're here to assist you",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Quick Help Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _helpCard(
                  icon: Icons.local_shipping_outlined,
                  title: "Shipping",
                  subtitle: "Track your order",
                  color: const Color(0xFF3B82F6),
                  onTap: () {},
                ),
                _helpCard(
                  icon: Icons.refresh_outlined,
                  title: "Returns",
                  subtitle: "Return & Refund",
                  color: const Color(0xFF22C55E),
                  onTap: () {},
                ),
                _helpCard(
                  icon: Icons.payment_outlined,
                  title: "Payments",
                  subtitle: "Payment issues",
                  color: const Color(0xFFF59E0B),
                  onTap: () {},
                ),
                _helpCard(
                  icon: Icons.headset_mic_outlined,
                  title: "Live Chat",
                  subtitle: "Talk to us",
                  color: const Color(0xFFEC4899),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 40),

            // FAQ Section
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _faqTile("How long does delivery take?", "Standard delivery takes 3-7 working days."),
            _faqTile("Can I return a product?", "Yes, you can return within 7 days of delivery."),
            _faqTile("Do you accept COD?", "Yes, Cash on Delivery is available."),
            _faqTile("How to track my order?", "Go to My Orders and click on Track Order."),

            const SizedBox(height: 40),

            // Contact Us
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
              ),
              child: Column(
                children: [
                  const Text(
                    "Still need help?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Our support team is available 24/7",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call),
                          label: const Text("Call Us"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.email_outlined),
                          label: const Text("Email Us"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _helpCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ).animate().fadeIn().scale(),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TotalCustomersScreen extends StatefulWidget {
  const TotalCustomersScreen({super.key});

  @override
  State<TotalCustomersScreen> createState() => _TotalCustomersScreenState();
}

class _TotalCustomersScreenState extends State<TotalCustomersScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> customers = [];
  int totalUniqueCustomers = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    setState(() => isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      // Get unique customers who bought from this seller
      final data = await supabase
          .from('orders')
          .select('user_id, created_at')
          .eq('seller_id', userId)
          .order('created_at', ascending: false);

      // Remove duplicate users
      final uniqueCustomers = <String, Map<String, dynamic>>{};

      for (var order in data) {
        final uid = order['user_id'].toString();
        if (!uniqueCustomers.containsKey(uid)) {
          uniqueCustomers[uid] = {
            'user_id': uid,
            'name': "Customer",           // We can improve this later with join
            'email': "customer@email.com", // Placeholder for now
            'first_order': order['created_at'],
          };
        }
      }

      setState(() {
        customers = uniqueCustomers.values.toList();
        totalUniqueCustomers = customers.length;
      });
    } catch (e) {
      debugPrint("Customers Fetch Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Total Customers"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : customers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 90, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No customers yet", style: TextStyle(fontSize: 20)),
                      Text("When someone buys your product, they'll appear here", 
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Beautiful Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 48, color: Colors.white),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                totalUniqueCustomers.toString(),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                "Unique Customers",
                                style: TextStyle(fontSize: 18, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 4,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                child: const Icon(Icons.person, color: Color(0xFF4F46E5), size: 32),
                              ),
                              title: Text(
                                customer['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                customer['email'],
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("First Order", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    customer['first_order']?.toString().substring(0, 10) ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn().slideX();
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
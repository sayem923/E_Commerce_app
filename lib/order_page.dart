import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _supabase = Supabase.instance.client;
  Timer? _ticker;
  
  // 🔄 স্ট্রিম ক্যাশ এবং রিলোড বাগ ফিক্স করার জন্য লেট ভ্যারিয়েবল
  late final Stream<List<Map<String, dynamic>>> _userOrdersStream;

  @override
  void initState() {
    super.initState();
    _initOrdersStream();

    // প্রতি সেকেন্ডে UI রিলোড করবে যাতে লাইভ ঘড়ির মতো টাইমার কমে
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  // 🎯 রিয়েল-টাইম স্ট্রিম ইনিশিয়েলাইজেশন (initState-এ নিয়ে আসা হয়েছে)
  void _initOrdersStream() {
    final user = _supabase.auth.currentUser;
    
    if (user == null) {
      _userOrdersStream = Stream.value([]);
      return;
    }

    _userOrdersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id) 
        .order('created_at', ascending: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _calculateTimeLeft(String? expiresAtStr) {
    if (expiresAtStr == null) return "No Timer Set";
    final expiresAt = DateTime.parse(expiresAtStr);
    final difference = expiresAt.difference(DateTime.now());

    if (difference.isNegative) {
      return "Time Expired";
    }

    final minutes = difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = difference.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds Mins Left";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Track Orders & Live Timer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userOrdersStream, // 🎯 ফিক্সড লেট স্ট্রিম ব্যবহার করা হয়েছে
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text("No active orders found!", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              final order = orders[index];
              final timeLeftText = _calculateTimeLeft(order['expires_at']);
              final isExpired = timeLeftText == "Time Expired";

              final productName = order['product_name'] ?? 'Unknown Product';
              final quantity = order['quantity'] ?? 1;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Order ID: #${order['id']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpired ? Colors.red[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text(
                              order['status'].toString().toUpperCase(),
                              style: TextStyle(color: isExpired ? Colors.red[900] : Colors.green[900], fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          if (order['image_url'] != null && order['image_url'].toString().isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(order['image_url'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const Icon(Icons.image)),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName, 
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text("Quantity: $quantity", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      Text(
                        "Total Amount: ৳ ${order['total_amount']}", 
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      const Divider(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.hourglass_bottom, color: isExpired ? Colors.red : Colors.green, size: 20),
                              const SizedBox(width: 5),
                              Text(
                                timeLeftText,
                                style: TextStyle(color: isExpired ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await _supabase.from('orders').delete().eq('id', order['id']);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Removed!")));
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            label: const Text("Remove", style: TextStyle(color: Colors.red)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
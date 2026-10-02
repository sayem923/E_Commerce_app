import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'skeleton_widgets.dart';
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

  // 🔍 Filter state
  String _statusFilter = "All";
  DateTimeRange? _dateRange;
  final List<String> _statusOptions = ["All", "Pending", "Processing", "Completed", "Cancelled"];

  @override
  void initState() {
    super.initState();
    _initOrdersStream();

    // 🎯 pg_cron না থাকলেও fallback হিসেবে — পেজ খোলার সময় একবার
    // expired order গুলো cancel করার চেষ্টা করা হচ্ছে (stock ফেরত সহ)
    _supabase.rpc('cancel_expired_orders').catchError((e) {
      debugPrint("cancel_expired_orders fallback error: $e");
    });

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

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      if (_statusFilter != "All") {
        final status = (order['status'] ?? '').toString().toLowerCase();
        if (status != _statusFilter.toLowerCase()) return false;
      }
      if (_dateRange != null) {
        final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
        if (createdAt == null) return false;
        final startOk = !createdAt.isBefore(_dateRange!.start);
        final endOk = createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        if (!startOk || !endOk) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Track Orders & Live Timer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: _dateRange != null ? Colors.white : Colors.white70),
            tooltip: "Filter by date",
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              tooltip: "Clear date filter",
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userOrdersStream, // 🎯 ফিক্সড লেট স্ট্রিম ব্যবহার করা হয়েছে
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
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

          final filteredOrders = _applyFilters(orders);

          return Column(
            children: [
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: _statusOptions.map((status) {
                    final isSelected = _statusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: isSelected,
                        selectedColor: Colors.orange[800],
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
                        onSelected: (_) => setState(() => _statusFilter = status),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? const Center(
                        child: Text("এই ফিল্টারে কোনো অর্ডার নেই", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      )
                    : _buildOrdersList(filteredOrders),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
          return RefreshIndicator(
            color: Colors.orange,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
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
                              color: (isExpired || order['status'].toString().toLowerCase() == 'cancelled')
                                  ? Colors.red[50]
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text(
                              (isExpired && order['status'].toString().toLowerCase() == 'pending')
                                  ? "EXPIRED"
                                  : order['status'].toString().toUpperCase(),
                              style: TextStyle(
                                color: (isExpired || order['status'].toString().toLowerCase() == 'cancelled')
                                    ? Colors.red[900]
                                    : Colors.green[900],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
                              child: CachedNetworkImage(
                                imageUrl: order['image_url'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.image),
                                placeholder: (context, url) => const SizedBox(
                                  width: 50, height: 50,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              ),
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
                      if ((order['shipping_address'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Delivery to: ${order['shipping_address']}",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        (order['payment_method'] ?? 'COD') == 'COD'
                            ? "Payment: Cash on Delivery"
                            : "Payment: ${order['payment_method']} (${(order['payment_status'] ?? 'unpaid').toString().replaceAll('_', ' ')})",
                        style: TextStyle(
                          color: (order['payment_status'] == 'verified') ? Colors.green : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
            ),
          );
  }
}
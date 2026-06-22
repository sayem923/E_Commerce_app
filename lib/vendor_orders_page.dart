import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorOrdersPage extends StatefulWidget {
  final bool? isVendor; 
  const VendorOrdersPage({super.key, this.isVendor});

  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchInitialOrders();
    _listenToRealtimeOrders();
  }

  // 📥 ১. ডাটাবেজ থেকে এই ভেন্ডরের আগের সব অর্ডার ডাটা নিয়ে আসা
  Future<void> _fetchInitialOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "ইউজার লগইন করা নেই!";
        _isLoading = false;
      });
      return;
    }

    try {
      final data = await _supabase
          .from('orders')
          .select()
          .eq('vendor_id', user.id)
          .order('id', ascending: false);

      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 🔄 ২. ব্যাকগ্রাউন্ডে নতুন কোনো অর্ডার আসলে বা স্ট্যাটাস আপডেট হলে লাইভ রিফ্রেশ করা
  void _listenToRealtimeOrders() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = _supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'vendor_id',
            value: user.id,
          ),
          callback: (payload) {
            _fetchInitialOrders();
          },
        );

    _realtimeChannel?.subscribe();
  }

  // ⚡ ৩. স্ট্যাটাস রিয়েল-টাইম আপডেট করার ফাংশন
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus.toLowerCase()}) // ডাটাবেজে ছোট হাতের অক্ষরে যাবে
          .eq('id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Status updated to $newStatus successfully!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'PROCESSING':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Vendor Orders (Receive)", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "Error: $_errorMessage", 
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "No orders received yet!", 
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _orders.length,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      itemBuilder: (context, index) {
        final order = _orders[index];

        final String orderId = order['id']?.toString() ?? '0';
        final String productName = order['product_name']?.toString() ?? 'Unknown Product';
        final String productPrice = order['price']?.toString() ?? '0';
        final String quantity = order['quantity']?.toString() ?? '1';
        final String currentStatus = order['status']?.toString().toUpperCase() ?? 'PENDING';
        final String imageUrl = order['image_url']?.toString() ?? '';

        final Color statusColor = _getStatusColor(currentStatus);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ১. অর্ডার আইডি এবং লাইভ স্ট্যাটাস ব্যাজ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Order ID: #$orderId", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        currentStatus,
                        style: TextStyle(
                          color: statusColor, 
                          fontSize: 12, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    )
                  ],
                ),
                const Divider(height: 25, color: Color(0xFFEEEEEE)),
                
                // ২. প্রোডাক্টের ডিটেইলস রো
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: Colors.green[50],
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, color: Colors.green))
                            : const Icon(Icons.shopping_bag, color: Colors.green, size: 28),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName, 
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Price: ৳ $productPrice  |  Qty: $quantity", 
                            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 14)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 25, color: Color(0xFFEEEEEE)),
                
                // ৩. লাইভ স্ট্যাটাস আপডেট বাটন অ্যাকশন প্যানেল
                const Text(
                  "Change Status:", 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusButton(orderId, "Pending", currentStatus == "PENDING", Colors.orange),
                    _buildStatusButton(orderId, "Processing", currentStatus == "PROCESSING", Colors.blue),
                    _buildStatusButton(orderId, "Completed", currentStatus == "COMPLETED", Colors.green),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🔘 ফিক্সড কাস্টম স্ট্যাটাস বাটন বিল্ডার
  Widget _buildStatusButton(String orderId, String statusText, bool isActive, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? color : Colors.grey[100],
            foregroundColor: isActive ? Colors.white : Colors.black87,
            elevation: isActive ? 2 : 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isActive ? color : Colors.grey.shade300, width: 0.8),
            ),
          ),
          onPressed: isActive ? null : () => _updateOrderStatus(orderId, statusText),
          child: Text(
            statusText, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
          ),
        ),
      ),
    );
  }
}
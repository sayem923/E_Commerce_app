import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'sales_analytics_page.dart';
import 'skeleton_widgets.dart';

/// 🎯 নতুন মডেল: Order কোনো নির্দিষ্ট vendor-এর সাথে বাঁধা থাকে না।
/// Order হলে সব vendor notification পায়, যে vendor আগে "Accept" করবে
/// শুধু সে-ই সেই order-এর জন্য দায়ী হবে (delivery করবে)। এর জন্য
/// orders.vendor_id কলামটা nullable হতে হবে, আর প্রথম Accept-ই জিতবে
/// (race-condition-safe: WHERE vendor_id IS NULL শর্ত দিয়ে update)।
class VendorOrdersPage extends StatefulWidget {
  final bool? isVendor; 
  const VendorOrdersPage({super.key, this.isVendor});

  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // "আমার" Accept করা order
  List<Map<String, dynamic>> _myOrders = [];
  // সবার জন্য open — এখনো কোনো vendor Accept করেনি
  List<Map<String, dynamic>> _availableOrders = [];

  bool _isLoading = true;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;
  late final TabController _tabController;

  // 🔍 My Orders ট্যাবের জন্য filter state
  String _statusFilter = "All";
  final List<String> _statusOptions = ["All", "Pending", "Processing", "Completed", "Cancelled"];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 🎯 pg_cron না থাকলেও fallback হিসেবে — পেজ খোলার সময় একবার
    // expired order গুলো cancel করার চেষ্টা করা হচ্ছে (stock ফেরত সহ)
    _supabase.rpc('cancel_expired_orders').catchError((e) {
      debugPrint("cancel_expired_orders fallback error: $e");
    });

    _fetchAllOrders();
    _listenToRealtimeOrders();
  }

  Future<void> _fetchAllOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "ইউজার লগইন করা নেই!";
        _isLoading = false;
      });
      return;
    }

    try {
      final myData = await _supabase
          .from('orders')
          .select()
          .eq('vendor_id', user.id)
          .order('id', ascending: false);

      final availableData = await _supabase
          .from('orders')
          .select()
          .filter('vendor_id', 'is', null)
          .eq('status', 'pending')
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _myOrders = List<Map<String, dynamic>>.from(myData);
          _availableOrders = List<Map<String, dynamic>>.from(availableData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // 🙋 এই order-টা আমি (এই vendor) নেব — race-condition-safe accept
  Future<void> _acceptOrder(String orderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final result = await _supabase
          .from('orders')
          .update({'vendor_id': user.id, 'status': 'processing'})
          .eq('id', orderId)
          .filter('vendor_id', 'is', null)
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        // ততক্ষণে অন্য কোনো vendor আগেই accept করে ফেলেছে
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("দুঃখিত, এই অর্ডারটি অন্য একজন Vendor আগেই গ্রহণ করে ফেলেছেন।"),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("অর্ডারটি আপনি গ্রহণ করেছেন!"), backgroundColor: Colors.green),
        );
        _tabController.animateTo(0); // "My Orders" ট্যাবে নিয়ে যাবে
      }

      _fetchAllOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Accept করতে সমস্যা হয়েছে: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updatePaymentStatus(String orderId, String newStatus) async {
    try {
      await _supabase.from('orders').update({'payment_status': newStatus}).eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment marked as $newStatus!"), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
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

  // 🔄 orders টেবিলের যেকোনো পরিবর্তনে (নতুন order/accept/status বদল) দুটো লিস্টই রিফ্রেশ
  void _listenToRealtimeOrders() {
    _realtimeChannel = _supabase
        .channel('public:orders:vendor-view')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            _fetchAllOrders();
          },
        );

    _realtimeChannel?.subscribe();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase.from('orders').update({'status': newStatus.toLowerCase()}).eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status updated to $newStatus successfully!"), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
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
    _tabController.dispose();
    _searchController.dispose();
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
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Vendor Orders", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: "Sales Analytics",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesAnalyticsPage()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: "My Orders"),
            Tab(text: "Available (${_availableOrders.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const ListSkeleton()
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text("Error: $_errorMessage", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyOrdersList(),
                    _buildAvailableOrdersList(),
                  ],
                ),
    );
  }

  // ================= MY ORDERS TAB =================
  Widget _buildMyOrdersList() {
    if (_myOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text("এখনো কোনো অর্ডার গ্রহণ করেননি!", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final filtered = _myOrders.where((order) {
      if (_statusFilter != "All") {
        final status = (order['status'] ?? '').toString().toLowerCase();
        if (status != _statusFilter.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final productName = (order['product_name'] ?? '').toString().toLowerCase();
        final orderId = (order['id'] ?? '').toString();
        final q = _searchQuery.toLowerCase();
        if (!productName.contains(q) && !orderId.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: "Order ID বা Product নাম দিয়ে খুঁজুন",
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            children: _statusOptions.map((status) {
              final isSelected = _statusFilter == status;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: Colors.green[700],
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text("এই ফিল্টারে কোনো অর্ডার নেই", style: TextStyle(color: Colors.grey, fontSize: 14)),
                )
              : RefreshIndicator(
                  color: Colors.green,
                  onRefresh: _fetchAllOrders,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    itemBuilder: (context, index) => _buildMyOrderCard(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMyOrderCard(Map<String, dynamic> order) {
    final String orderId = order['id']?.toString() ?? '0';
    final String productName = order['product_name']?.toString() ?? 'Unknown Product';
    final String productPrice = order['price']?.toString() ?? '0';
    final String quantity = order['quantity']?.toString() ?? '1';
    final String rawStatus = order['status']?.toString().toUpperCase() ?? 'PENDING';
    final String imageUrl = order['image_url']?.toString() ?? '';
    final String shippingAddress = order['shipping_address']?.toString() ?? '';
    final String shippingPhone = order['shipping_phone']?.toString() ?? '';
    final String paymentMethod = order['payment_method']?.toString() ?? 'COD';
    final String paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
    final String transactionId = order['transaction_id']?.toString() ?? '';

    bool isExpired = false;
    if (order['expires_at'] != null && rawStatus == 'PENDING') {
      final expiresAt = DateTime.tryParse(order['expires_at'].toString());
      isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    }

    final String currentStatus = isExpired ? 'EXPIRED' : rawStatus;
    final Color statusColor = isExpired ? Colors.red : _getStatusColor(currentStatus);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Order ID: #$orderId", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(currentStatus, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Divider(height: 25, color: Color(0xFFEEEEEE)),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.green[50],
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag, color: Colors.green),
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                          )
                        : const Icon(Icons.shopping_bag, color: Colors.green, size: 28),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(productName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Text("Price: ৳ $productPrice  |  Qty: $quantity", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            if (shippingAddress.isNotEmpty) ...[
              const Divider(height: 25, color: Color(0xFFEEEEEE)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shippingPhone.isNotEmpty ? "$shippingAddress\nPhone: $shippingPhone" : shippingAddress,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 25, color: Color(0xFFEEEEEE)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paymentMethod == 'COD' ? "Cash on Delivery" : "$paymentMethod  •  TrxID: ${transactionId.isNotEmpty ? transactionId : 'N/A'}",
                        style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: paymentStatus == 'verified'
                              ? Colors.green.withOpacity(0.1)
                              : paymentStatus == 'pending_verification'
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          paymentStatus.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: paymentStatus == 'verified'
                                ? Colors.green[800]
                                : paymentStatus == 'pending_verification'
                                    ? Colors.orange[800]
                                    : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (paymentStatus == 'pending_verification')
                  TextButton(
                    onPressed: () => _updatePaymentStatus(orderId, 'verified'),
                    child: const Text("Verify", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 25, color: Color(0xFFEEEEEE)),
            if (isExpired)
              const Text(
                "এই অর্ডারের সময়সীমা শেষ হয়ে গেছে — স্ট্যাটাস পরিবর্তন করা যাবে না।",
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
              )
            else ...[
              const Text("Change Status:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
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
          ],
        ),
      ),
    );
  }

  // ================= AVAILABLE ORDERS TAB =================
  Widget _buildAvailableOrdersList() {
    if (_availableOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text("এই মুহূর্তে গ্রহণযোগ্য কোনো নতুন অর্ডার নেই।", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.green,
      onRefresh: _fetchAllOrders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _availableOrders.length,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        itemBuilder: (context, index) {
          final order = _availableOrders[index];
          final String orderId = order['id']?.toString() ?? '0';
          final String productName = order['product_name']?.toString() ?? 'Unknown Product';
          final String productPrice = order['price']?.toString() ?? '0';
          final String quantity = order['quantity']?.toString() ?? '1';
          final String imageUrl = order['image_url']?.toString() ?? '';
          final String shippingAddress = order['shipping_address']?.toString() ?? '';

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
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 60,
                          height: 60,
                          color: Colors.orange[50],
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag, color: Colors.orange),
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                                )
                              : const Icon(Icons.shopping_bag, color: Colors.orange, size: 28),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text("Price: ৳ $productPrice  |  Qty: $quantity", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (shippingAddress.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(shippingAddress, style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptOrder(orderId),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("Accept Order"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
          child: Text(statusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

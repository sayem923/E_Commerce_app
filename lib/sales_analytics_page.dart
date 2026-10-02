import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

/// Vendor-এর নিজের Accept-করা order গুলো থেকে বিক্রি সম্পর্কিত পরিসংখ্যান
/// দেখায় — মোট বিক্রি, order breakdown by status, best-selling product,
/// আর গত ৭ দিনের revenue trend (bar chart)।
///
/// এখানে "Revenue" ধরা হয়েছে শুধু status = 'completed' order এর
/// total_amount যোগফল — কারণ pending/processing order-এর টাকা এখনো
/// নিশ্চিত না।
class SalesAnalyticsPage extends StatefulWidget {
  const SalesAnalyticsPage({super.key});

  @override
  State<SalesAnalyticsPage> createState() => _SalesAnalyticsPageState();
}

class _SalesAnalyticsPageState extends State<SalesAnalyticsPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('orders')
          .select()
          .eq('vendor_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double get _totalRevenue {
    return _orders
        .where((o) => (o['status'] ?? '').toString().toLowerCase() == 'completed')
        .fold(0.0, (sum, o) => sum + (double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0));
  }

  int _countByStatus(String status) {
    return _orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == status).length;
  }

  List<MapEntry<String, int>> get _bestSellers {
    final Map<String, int> counts = {};
    for (final o in _orders) {
      if ((o['status'] ?? '').toString().toLowerCase() == 'cancelled') continue;
      final name = o['product_name']?.toString() ?? 'Unknown';
      final qty = int.tryParse(o['quantity']?.toString() ?? '1') ?? 1;
      counts[name] = (counts[name] ?? 0) + qty;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  // গত ৭ দিনের প্রতিদিনের revenue (শুধু completed order)
  List<double> get _last7DaysRevenue {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final List<double> result = List.filled(7, 0.0);

    for (final o in _orders) {
      if ((o['status'] ?? '').toString().toLowerCase() != 'completed') continue;
      final createdAt = DateTime.tryParse(o['created_at']?.toString() ?? '');
      if (createdAt == null) continue;

      final orderDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final diff = todayStart.difference(orderDay).inDays;

      if (diff >= 0 && diff < 7) {
        final index = 6 - diff;
        result[index] += double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Sales Analytics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _fetchOrders,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 24),
                        const Text("গত ৭ দিনের বিক্রি", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildTrendChart(),
                        const SizedBox(height: 24),
                        const Text("সবচেয়ে বেশি বিক্রি হওয়া প্রোডাক্ট", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildBestSellers(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final cards = [
      {'label': 'Total Revenue', 'value': '৳ ${_totalRevenue.toStringAsFixed(0)}', 'color': Colors.green},
      {'label': 'Total Orders', 'value': '${_orders.length}', 'color': Colors.blue},
      {'label': 'Completed', 'value': '${_countByStatus('completed')}', 'color': Colors.teal},
      {'label': 'Pending', 'value': '${_countByStatus('pending')}', 'color': Colors.orange},
      {'label': 'Processing', 'value': '${_countByStatus('processing')}', 'color': Colors.indigo},
      {'label': 'Cancelled', 'value': '${_countByStatus('cancelled')}', 'color': Colors.red},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final c = cards[index];
        final color = c['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(c['value'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(c['label'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendChart() {
    final data = _last7DaysRevenue;
    final maxY = (data.reduce((a, b) => a > b ? a : b)) * 1.2;
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return "${d.day}/${d.month}";
    });

    if (data.every((v) => v == 0)) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Text("গত ৭ দিনে কোনো Completed অর্ডার নেই", style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 16, right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 10 : maxY,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(dayLabels[idx], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i],
                  color: Colors.orange[800],
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBestSellers() {
    final bestSellers = _bestSellers;

    if (bestSellers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Text("এখনো কোনো বিক্রির তথ্য নেই", style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: bestSellers.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final name = entry.value.key;
          final qty = entry.value.value;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              child: Text("$rank", style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold)),
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text("$qty বিক্রি", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          );
        }).toList(),
      ),
    );
  }
}

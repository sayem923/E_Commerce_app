import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _supabase = Supabase.instance.client;

  // আইটেম রিমুভ করার ফাংশন
  Future<void> _removeItem(String id) async {
    await _supabase.from('cart').delete().eq('id', id);
  }

  // কোয়ান্টিটি আপডেট করার ফাংশন
  Future<void> _updateQuantity(String id, int newQty) async {
    if (newQty < 1) return;
    await _supabase.from('cart').update({'quantity': newQty}).eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final cartStream = _supabase
        .from('cart')
        .stream(primaryKey: ['id'])
        .eq('user_id', user?.id ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("My Cart", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyCart();
          }

          final cartItems = snapshot.data!;
          
          // মোট মূল্য হিসাব করা
          double subtotal = 0;
          for (var item in cartItems) {
            subtotal += (item['price'] ?? 0) * (item['quantity'] ?? 1);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return _buildCartItem(item);
                  },
                ),
              ),
              _buildCheckoutSection(subtotal),
            ],
          );
        },
      ),
    );
  }

  // কার্ট আইটেম কার্ড ডিজাইন
  Widget _buildCartItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          // প্রোডাক্ট ইমেজ
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              item['image_url'] ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(color: Colors.grey[200], width: 80, height: 80, child: const Icon(Icons.image)),
            ),
          ),
          const SizedBox(width: 15),
          // নাম ও দাম
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['product_name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text("৳${item['price']}", style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          // কোয়ান্টিটি কন্ট্রোল
          Column(
            children: [
              IconButton(
                onPressed: () => _removeItem(item['id'].toString()),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
              Row(
                children: [
                  _qtyButton(Icons.remove, () => _updateQuantity(item['id'].toString(), item['quantity'] - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text("${item['quantity']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _qtyButton(Icons.add, () => _updateQuantity(item['id'].toString(), item['quantity'] + 1)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  // চেকআউট সেকশন
  Widget _buildCheckoutSection(double subtotal) {
    double deliveryCharge = subtotal > 0 ? 60 : 0;
    double total = subtotal + deliveryCharge;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rowPrice("Subtotal", "৳$subtotal"),
            const SizedBox(height: 10),
            _rowPrice("Delivery Charge", "৳$deliveryCharge"),
            const Divider(height: 30),
            _rowPrice("Total", "৳$total", isTotal: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // চেকআউট লজিক এখানে হবে
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Proceed to Checkout", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowPrice(String label, String price, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(price, style: TextStyle(fontSize: isTotal ? 20 : 16, fontWeight: FontWeight.bold, color: isTotal ? Colors.orange[800] : Colors.black)),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("Your cart is empty!", style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
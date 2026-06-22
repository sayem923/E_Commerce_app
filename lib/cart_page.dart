import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_page.dart'; 

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _supabase = Supabase.instance.client;

  
  Future<void> _updateQuantity(int itemId, int currentQty, int change) async {
    final newQty = currentQty + change;
    try {
      if (newQty <= 0) {
        await _supabase.from('cart').delete().eq('id', itemId);
      } else {
        await _supabase.from('cart').update({'quantity': newQty}).eq('id', itemId);
      }
    } catch (e) {
      debugPrint("Update Quantity Error: $e");
    }
  }

  Future<void> _placeOrder(List<Map<String, dynamic>> cartItems) async {
    final user = _supabase.auth.currentUser;
    if (user == null || cartItems.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    try {
      for (var item in cartItems) {
        final price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        final String vendorId = item['vendor_id']?.toString() ?? '';

        if (vendorId.isEmpty) {
          throw "কার্টের এই প্রোডাক্টটিতে কোনো Vendor ID পাওয়া যায়নি!";
        }

        // 💡 এখানে ইনসার্ট করার সময় কোনো কলামের নাম ভুল হলে সুপাবেস সরাসরি ক্যাচ (Catch) এ পাঠিয়ে দেবে
        await _supabase.from('orders').insert({
          'user_id': user.id,
          'vendor_id': vendorId, 
          'product_id': int.tryParse(item['product_id']?.toString() ?? '0') ?? 0,
          'product_name': item['product_name'] ?? 'Product',
          'price': price,
          'quantity': qty,
          'total_amount': (price * qty),
          'image_url': item['image_url'] ?? '',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        });
      }

      // অর্ডার সম্পূর্ণ হওয়ার পর কার্ট খালি করা
      await _supabase.from('cart').delete().eq('user_id', user.id);

      if (!context.mounted) return;
      Navigator.pop(context); // লোডিং ডায়ালগ বন্ধ

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order Placed Successfully!"), backgroundColor: Colors.green),
      );
      
      // ✅ শুধু এইটুকু রাখুন (যা অলরেডি কোডে আছে):
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text("Order Placed Successfully!"), backgroundColor: Colors.green),
);
// পেজ চেঞ্জের কোড না থাকায় ইউজার কার্ট পেজেই থেকে যাবে।
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // লোডিং ডায়ালগ বন্ধ
      
      // 🚨 এই মেসেজটি আপনার স্ক্রিনে ভেসে উঠবে এবং বলে দেবে আসল সমস্যা কোথায়!
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Database Error: $e"), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10), // দেখার সুবিধার্থে ১০ সেকেন্ড থাকবে
          ),
        );
      }
      debugPrint("Order placing error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    
    final cartStream = _supabase
        .from('cart')
        .stream(primaryKey: ['id'])
        .eq('user_id', user?.id ?? '')
        .order('id', ascending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Shopping Cart", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(fontWeight: FontWeight.bold)));
          }

          final cartItems = snapshot.data ?? [];

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  const Text(
                    "Your cart is empty!", 
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            );
          }

          double grandTotal = 0;
          for (var item in cartItems) {
            final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
            final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            grandTotal += (price * qty);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    
                    final int itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                    final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                    final String productName = item['product_name']?.toString() ?? 'Unknown Product';
                    final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
                    final String imageUrl = item['image_url']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 75,
                                height: 75,
                                color: Colors.grey.shade100,
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2));
                                        },
                                      )
                                    : const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                            
                            const SizedBox(width: 14),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "৳ ${(price * qty).toStringAsFixed(0)}",
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildQuantityBtn(Icons.remove, () => _updateQuantity(itemId, qty, -1)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          "$qty", 
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                        ),
                                      ),
                                      _buildQuantityBtn(Icons.add, () => _updateQuantity(itemId, qty, 1)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
                              onPressed: () async {
                                await _supabase.from('cart').delete().eq('id', itemId);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -6))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Grand Total:", 
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)
                        ),
                        Text(
                          "৳ ${grandTotal.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => _placeOrder(cartItems),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          Text(
                            "Proceed to Checkout", 
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuantityBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 0.8),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}
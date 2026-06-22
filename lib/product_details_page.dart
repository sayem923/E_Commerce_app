import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_page.dart'; // নিশ্চিত করুন এই পাথটি আপনার প্রজেক্ট অনুযায়ী ঠিক আছে

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // 🛒 ১. কার্টে প্রোডাক্ট যোগ করার ফাংশন
  Future<void> _addToCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("অর্ডার বা কার্ট করতে আগে লগইন করুন!"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final vendorId = widget.product['vendor_id'];
    if (vendorId == null || vendorId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: এই প্রোডাক্টের কোনো Vendor ID নেই!"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final existingCartItem = await _supabase
          .from('cart')
          .select()
          .eq('user_id', user.id)
          .eq('product_id', widget.product['id'])
          .maybeSingle();

      if (existingCartItem != null) {
        final currentQty = int.tryParse(existingCartItem['quantity'].toString()) ?? 1;
        await _supabase.from('cart').update({'quantity': currentQty + 1}).eq('id', existingCartItem['id']);
      } else {
        await _supabase.from('cart').insert({
          'user_id': user.id,
          'product_id': widget.product['id'],
          'product_name': widget.product['name'] ?? 'Unknown Product',
          'price': double.tryParse(widget.product['price']?.toString() ?? '0.0') ?? 0.0,
          'image_url': widget.product['image_url'] ?? '',
          'quantity': 1,
          'vendor_id': vendorId,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Added to Cart Successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Cart Insert Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ⚡ ২. সরাসরি অর্ডার (Buy Now) করার ফিক্সড ফাংশন
  Future<void> _directBuyNow() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("অর্ডার করতে আগে লগইন করুন!"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final vendorId = widget.product['vendor_id'];
    if (vendorId == null || vendorId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: এই প্রোডাক্টের কোনো Vendor ID নেই!"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // কনফার্মেশন ডায়ালগ
    bool confirmOrder = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Order"),
            content: const Text("আপনি কি প্রোডাক্টটি সরাসরি অর্ডার করতে চান?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm", style: TextStyle(color: Colors.orange))),
            ],
          ),
        ) ??
        false;

    if (!confirmOrder) return;

    setState(() => _isLoading = true);

    try {
      final price = double.tryParse(widget.product['price']?.toString() ?? '0.0') ?? 0.0;

      // সরাসরি orders টেবিলে ডেটা ইনসার্ট করা হচ্ছে
      await _supabase.from('orders').insert({
        'user_id': user.id,
        'vendor_id': vendorId,
        'product_id': int.tryParse(widget.product['id']?.toString() ?? '0') ?? 0,
        'product_name': widget.product['name'] ?? 'Product',
        'price': price,
        'quantity': 1,
        'total_amount': price, 
        'image_url': widget.product['image_url'] ?? '',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
      });

      if (!mounted) return;

      // সাকসেস মেসেজ দেখাবে
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Direct Order Placed Successfully!"), backgroundColor: Colors.green),
      );

      // 🚫 এখানে থাকা Navigator.pushReplacement লাইনটি বন্ধ বা রিমুভ করে দেওয়া হয়েছে 
      // যাতে ইউজার এই পেজেই থাকেন।

    } catch (e) {
      debugPrint("Direct buy error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.product['name'] ?? 'Product Details';
    final String price = widget.product['price']?.toString() ?? '0';
    final String desc = widget.product['description'] ?? 'No description available.';
    final String imgUrl = widget.product['image_url'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 320,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: imgUrl.isNotEmpty
                        ? Image.network(imgUrl, fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 80, color: Colors.grey),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("৳ $price", style: const TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold)),
                        const Divider(height: 30, thickness: 1),
                        const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(desc, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5)),
                        const SizedBox(height: 40),

                        // 🔘 বাটন সেকশন
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _addToCart,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.orange[800]!, width: 1.5),
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_cart_outlined, color: Colors.orange[800]),
                                    const SizedBox(width: 8),
                                    Text("Add to Cart", style: TextStyle(color: Colors.orange[800], fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _directBuyNow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.flash_on, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text("Buy Now", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
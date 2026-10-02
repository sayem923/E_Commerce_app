import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'order_page.dart'; // নিশ্চিত করুন এই পাথটি আপনার প্রজেক্ট অনুযায়ী ঠিক আছে
import 'payment_dialog.dart';
import 'review_widgets.dart';

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  int _currentImageIndex = 0;

  // 🛒 ১. কার্টে প্রোডাক্ট যোগ করার ফাংশন
  Future<void> _addToCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("অর্ডার বা কার্ট করতে আগে লগইন করুন!"), backgroundColor: Colors.redAccent),
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

    // চেকআউটের আগে shipping address সেট আছে কিনা চেক করা হচ্ছে
    String shippingAddress = '';
    String shippingPhone = '';
    try {
      final profile = await _supabase
          .from('profiles')
          .select('address, phone')
          .eq('id', user.id)
          .maybeSingle();
      shippingAddress = (profile?['address'] ?? '').toString().trim();
      shippingPhone = (profile?['phone'] ?? '').toString().trim();
    } catch (e) {
      debugPrint("Profile fetch error before order: $e");
    }

    if (shippingAddress.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("অর্ডার করার আগে আপনার প্রোফাইলে Shipping Address যোগ করুন!"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // পেমেন্ট মেথড বেছে নেওয়া (এটাই এখন কনফার্মেশন হিসেবেও কাজ করবে)
    if (!mounted) return;
    final paymentInfo = await showPaymentMethodDialog(context);
    if (paymentInfo == null) return; // user cancel করেছে

    setState(() => _isLoading = true);

    try {
      final price = double.tryParse(widget.product['price']?.toString() ?? '0.0') ?? 0.0;
      final productId = int.tryParse(widget.product['id']?.toString() ?? '0') ?? 0;

      // 📦 আগে stock কমানোর চেষ্টা — race-condition-safe (DB function দিয়ে)
      final stockOk = await _supabase.rpc('decrement_stock', params: {
        'p_product_id': productId,
        'p_qty': 1,
      });

      if (stockOk != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("দুঃখিত, এই প্রোডাক্টটি এখন Stock-এ নেই!"), backgroundColor: Colors.redAccent),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // সরাসরি orders টেবিলে ডেটা ইনসার্ট করা হচ্ছে (vendor_id ইচ্ছাকৃতভাবে
      // দেওয়া হচ্ছে না — যেকোনো vendor Accept করে এই order নিতে পারবেন)
      await _supabase.from('orders').insert({
        'user_id': user.id,
        'product_id': productId,
        'product_name': widget.product['name'] ?? 'Product',
        'price': price,
        'quantity': 1,
        'total_amount': price, 
        'image_url': widget.product['image_url'] ?? '',
        'status': 'pending',
        'shipping_address': shippingAddress,
        'shipping_phone': shippingPhone,
        'payment_method': paymentInfo['payment_method'],
        'payment_status': paymentInfo['payment_status'],
        'transaction_id': paymentInfo['transaction_id'],
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
    final List<String> galleryImages = (widget.product['image_urls'] is List && (widget.product['image_urls'] as List).isNotEmpty)
        ? (widget.product['image_urls'] as List).map((e) => e.toString()).toList()
        : (imgUrl.isNotEmpty ? [imgUrl] : <String>[]);
    final int stock = int.tryParse(widget.product['stock']?.toString() ?? '0') ?? 0;
    final bool inStock = stock > 0;
    final double avgRating = double.tryParse(widget.product['avg_rating']?.toString() ?? '0') ?? 0;
    final int reviewCount = int.tryParse(widget.product['review_count']?.toString() ?? '0') ?? 0;

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
                  galleryImages.isEmpty
                      ? Container(
                          height: 320,
                          width: double.infinity,
                          color: Colors.grey[100],
                          child: const Icon(Icons.image, size: 80, color: Colors.grey),
                        )
                      : Column(
                          children: [
                            Stack(
                              children: [
                                CarouselSlider(
                                  options: CarouselOptions(
                                    height: 320,
                                    viewportFraction: 1.0,
                                    enableInfiniteScroll: galleryImages.length > 1,
                                    onPageChanged: (index, reason) {
                                      setState(() => _currentImageIndex = index);
                                    },
                                  ),
                                  items: galleryImages.map((url) {
                                    return CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (context, u) => Container(
                                        color: Colors.grey[100],
                                        child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (galleryImages.length > 1)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "${_currentImageIndex + 1}/${galleryImages.length}",
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (galleryImages.length > 1) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: galleryImages.asMap().entries.map((entry) {
                                  return Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == entry.key ? Colors.orange[800] : Colors.grey.shade300,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (avgRating > 0)
                          Row(
                            children: [
                              StarRatingDisplay(rating: avgRating, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "${avgRating.toStringAsFixed(1)} ($reviewCount)",
                                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text("৳ $price", style: const TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: inStock ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            inStock ? "In Stock ($stock available)" : "Out of Stock",
                            style: TextStyle(
                              color: inStock ? Colors.green[800] : Colors.red[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
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
                                onPressed: inStock ? _addToCart : null,
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
                                onPressed: inStock ? _directBuyNow : null,
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

                        const Divider(height: 40, thickness: 1),
                        ReviewsSection(productId: int.tryParse(widget.product['id']?.toString() ?? '0') ?? 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
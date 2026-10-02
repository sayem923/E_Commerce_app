import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_details_page.dart';
import 'skeleton_widgets.dart';

/// এই পেজ কাজ করতে হলে Supabase এ একটা `wishlist` টেবিল লাগবে:
///   id (int8, primary key, identity)
///   user_id (uuid)
///   product_id (int8 / text — আপনার products.id এর টাইপ অনুযায়ী)
///   product_name (text)
///   price (numeric)
///   image_url (text)
///   created_at (timestamptz, default now())
/// RLS পলিসি: user শুধু তার নিজের user_id দিয়ে filtered row select/insert/delete করতে পারবে।
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    final wishlistStream = _supabase
        .from('wishlist')
        .stream(primaryKey: ['id'])
        .eq('user_id', user?.id ?? '')
        .order('created_at', ascending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("My Wishlist", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: wishlistStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  const Text(
                    "আপনার Wishlist খালি!",
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.orange,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final imageUrl = item['image_url']?.toString() ?? '';
              final productName = item['product_name']?.toString() ?? 'Unknown Product';
              final price = item['price']?.toString() ?? '0';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade100,
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : const Icon(Icons.image),
                    ),
                  ),
                  title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text("৳ $price", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () async {
                      await _supabase.from('wishlist').delete().eq('id', item['id']);
                    },
                  ),
                  onTap: () async {
                    try {
                      final productData = await _supabase
                          .from('products')
                          .select()
                          .eq('id', item['product_id'])
                          .maybeSingle();

                      if (!context.mounted) return;

                      if (productData != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: productData)),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("এই প্রোডাক্টটি আর পাওয়া যাচ্ছে না")),
                        );
                      }
                    } catch (e) {
                      debugPrint("Wishlist item open error: $e");
                    }
                  },
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}

/// ছোট্ট reusable heart-icon toggle বাটন — যেকোনো product card এ বসানো যাবে।
/// এটা এখন real-time: user এর পুরো wishlist স্ট্রিম শোনে, তাই অন্য কোনো
/// device/session থেকে এই প্রোডাক্টটা wishlist এ add/remove হলেও heart icon
/// সাথে সাথে (কোনো rebuild/refresh ছাড়াই) আপডেট হয়ে যাবে।
class WishlistToggleButton extends StatelessWidget {
  final Map<String, dynamic> product;
  final double size;

  const WishlistToggleButton({super.key, required this.product, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // লগইন করা না থাকলে শুধু একটা normal (non-filled) heart দেখাবে, tap করলে লগইন করতে বলবে
    if (user == null) {
      return GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Wishlist এ যোগ করতে আগে লগইন করুন")),
          );
        },
        child: Icon(Icons.favorite_border, color: Colors.grey, size: size),
      );
    }

    final wishlistStream = supabase
        .from('wishlist')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: wishlistStream,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        Map<String, dynamic>? existingRow;
        for (final row in rows) {
          if (row['product_id'].toString() == product['id'].toString()) {
            existingRow = row;
            break;
          }
        }
        final isInWishlist = existingRow != null;

        return GestureDetector(
          onTap: () async {
            try {
              if (isInWishlist) {
                await supabase.from('wishlist').delete().eq('id', existingRow!['id']);
              } else {
                await supabase.from('wishlist').insert({
                  'user_id': user.id,
                  'product_id': product['id'],
                  'product_name': product['name'] ?? 'Product',
                  'price': product['price'],
                  'image_url': product['image_url'] ?? '',
                });
              }
            } catch (e) {
              debugPrint("Wishlist toggle error: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Wishlist Error: $e")),
                );
              }
            }
          },
          child: Icon(
            isInWishlist ? Icons.favorite : Icons.favorite_border,
            color: isInWishlist ? Colors.redAccent : Colors.grey,
            size: size,
          ),
        );
      },
    );
  }
}

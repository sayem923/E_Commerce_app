import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'product_details_page.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  Widget build(BuildContext context) {
    final productStream = Supabase.instance.client.from('products').stream(primaryKey: ['id']);
    final bannerStream = Supabase.instance.client.from('banners').stream(primaryKey: ['id']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // ডিজাইনের মতো ব্যাকগ্রাউন্ড
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // হেডার সেকশন
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.grid_view_rounded, size: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network('https://i.pravatar.cc/150', height: 40, width: 40),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text("Collection", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const Text("New Arrivals", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // প্রফেশনাল ব্যানার স্লাইডার
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: bannerStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox(height: 180);
                  return CarouselSlider(
                    options: CarouselOptions(
                      height: 200,
                      autoPlay: true,
                      enlargeCenterPage: true,
                      viewportFraction: 0.9,
                    ),
                    items: snapshot.data!.map((banner) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.network(banner['image_url'], fit: BoxFit.cover, width: double.infinity),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 30),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Best Selling", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("See All", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 15),

              // প্রফেশনাল প্রোডাক্ট গ্রিড
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: productStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final p = snapshot.data![index];
                      return _buildProductCard(context, p);
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> p) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: Image.network(p['image_url'] ?? '', fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1),
                  const SizedBox(height: 5),
                  Text("৳ ${p['price']}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
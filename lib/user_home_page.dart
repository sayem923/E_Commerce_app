import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';

// আপনার প্রোজেক্টের সঠিক ফাইল পাথগুলো চেক করে নিন
import 'product_details_page.dart';
import 'profile_page.dart';
import 'cart_page.dart';
import 'login_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;

  // পেজ লিস্ট
  final List<Widget> _pages = [
    const UserHomeView(),        
    const Center(child: Text("My Wishlist", style: TextStyle(fontSize: 20))), 
    const CartPage(),            
    const ProfilePage(), // ইনডেক্স ৩ (প্রোফাইল পেজ)
  ];

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final profileStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user?.id ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      
      // ড্রয়ার সেকশন
      drawer: StreamBuilder<List<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, snapshot) {
          final profile = (snapshot.hasData && snapshot.data!.isNotEmpty) 
              ? snapshot.data!.first 
              : null;
          return _buildDrawer(profile);
        },
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // বটম নেভিগেশন
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: Colors.orange[800],
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: "Wishlist"),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: "Cart"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
          ],
        ),
      ),
    );
  }

  // ড্রয়ার এবং সাইন আউট লজিক
  Widget _buildDrawer(Map<String, dynamic>? profile) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.orange[800]),
            accountName: Text(profile?['full_name'] ?? "User"),
            accountEmail: Text(_supabase.auth.currentUser?.email ?? ""),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: (profile?['avatar_url'] != null)
                  ? NetworkImage("${profile!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}")
                  : null,
              child: profile?['avatar_url'] == null 
                  ? const Icon(Icons.person, color: Colors.orange, size: 40) 
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline), 
            title: const Text("My Profile"), 
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 3); // প্রোফাইল ট্যাবে নিয়ে যাবে
            }
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red), 
            title: const Text("Sign Out"), 
            onTap: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const LoginPage()), 
                  (route) => false
                );
              }
            }
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- Home View ---
class UserHomeView extends StatefulWidget {
  const UserHomeView({super.key});

  @override
  State<UserHomeView> createState() => _UserHomeViewState();
}

class _UserHomeViewState extends State<UserHomeView> {
  final supabase = Supabase.instance.client;
  String _selectedCategory = "All";

  // ব্যানার থেকে প্রোডাক্ট খুঁজে ডিটেইলস পেজে যাওয়ার মেথড
  Future<void> _onBannerClick(String productId) async {
    try {
      final productData = await supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(product: productData),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching product for banner: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final productStream = supabase.from('products').stream(primaryKey: ['id']);
    final bannerStream = supabase.from('banners').stream(primaryKey: ['id']);
    final profileStream = supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user?.id ?? '');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.grid_view_rounded, size: 28, color: Colors.orange),
                )),
                
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: profileStream,
                  builder: (context, snapshot) {
                    final profile = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data!.first : null;
                    return GestureDetector(
                      onTap: () {
                        final mainPageState = context.findAncestorStateOfType<_UserHomePageState>();
                        if (mainPageState != null) {
                          mainPageState.setState(() {
                            mainPageState._selectedIndex = 3;
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.orange[100],
                        backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile!['avatar_url']) : null,
                        child: profile?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.orange) : null,
                      ),
                    );
                  }
                ),
              ],
            ),

            const SizedBox(height: 25),
            const Text("New Arrivals", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // ব্যানার স্লাইডার (এখানে ক্লিক লজিক আপডেট করা হয়েছে)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: bannerStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 160);
                return CarouselSlider(
                  options: CarouselOptions(height: 160, autoPlay: true, enlargeCenterPage: true, viewportFraction: 1.0),
                  items: snapshot.data!.map((banner) => GestureDetector(
                    onTap: () {
                      if (banner['product_id'] != null) {
                        _onBannerClick(banner['product_id'].toString());
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(banner['image_url'], fit: BoxFit.cover, width: double.infinity),
                    ),
                  )).toList(),
                );
              },
            ),

            const SizedBox(height: 25),
            const Text("Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ["All", "Gadgets", "Fashion", "Watch", "Home", "Phones"].map((cat) {
                  bool isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange[800] : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 25),
            const Text("Popular Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: productStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orange));
                
                final filtered = _selectedCategory == "All"
                    ? snapshot.data!
                    : snapshot.data!.where((p) => p['category'] == _selectedCategory).toList();

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.75, mainAxisSpacing: 15, crossAxisSpacing: 15),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ProductCard(product: filtered[index]),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// প্রোডাক্ট কার্ড
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(product['image_url'] ?? '', fit: BoxFit.cover, width: double.infinity))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1),
                const SizedBox(height: 4),
                Text("৳ ${product['price']}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ]),
            )
          ],
        ),
      ),
    );
  }
}
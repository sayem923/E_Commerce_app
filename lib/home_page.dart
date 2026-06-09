import 'package:e_commerce_app/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';

// আপনার ফাইলের নামগুলোর সাথে এই ইমপোর্টগুলো মিলিয়ে নিন
import 'product_details_page.dart';
import 'vendor_dashboard.dart';
import 'profile_page.dart';
import 'cart_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;

  final List<Widget> _pages = [
    const HomeView(),           // Index 0
    const Center(child: Text("Wishlist", style: TextStyle(fontSize: 20))), // Index 1
    const CartPage(),           // Index 2
    const Center(child: Text("Notifications", style: TextStyle(fontSize: 20))), // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    // ইউজারের প্রোফাইল ডাটা স্ট্রিম (রিয়েল টাইম আপডেটের জন্য)
    final user = _supabase.auth.currentUser;
    final profileStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user?.id ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      
      // ড্রয়ারে প্রোফাইল ডাটা পাস করা হচ্ছে
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

      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorDashboard())),
        backgroundColor: Colors.orange[800],
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 65,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.home_filled, color: _selectedIndex == 0 ? Colors.orange[800] : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
                IconButton(
                  icon: Icon(Icons.favorite_border, color: _selectedIndex == 1 ? Colors.orange[800] : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 1),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.shopping_cart_outlined, color: _selectedIndex == 2 ? Colors.orange[800] : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 2),
                ),
                IconButton(
                  icon: Icon(Icons.notifications_none, color: _selectedIndex == 3 ? Colors.orange[800] : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ড্রয়ার আপডেট
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
          ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () {}),
          ListTile(leading: const Icon(Icons.inventory), title: const Text("Stock Inventory"), onTap: () {}),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person), 
            title: const Text("My Profile"), 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))
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
            MaterialPageRoute(builder: (context) => const LoginPage()), // আপনার লগইন পেজের নাম দিন
          (route) => false, // আগের সব পেজ মেমোরি থেকে মুছে দিবে
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

// --- HomeView আপডেট (এখানেও প্রোফাইল পিকচার শো করবে) ---
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    // স্ট্রিমগুলো ডিফাইন করা
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
            
            // হেডার যেখানে প্রোফাইল পিকচার আছে
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: const Icon(Icons.grid_view_rounded, size: 22),
                  ),
                )),
                
                // রিয়েল টাইম প্রোফাইল পিকচার বাটন
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: profileStream,
                  builder: (context, snapshot) {
                    final profile = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data!.first : null;
                    final String? avatarUrl = profile?['avatar_url'];

                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                        child: CircleAvatar(
                          radius: 20, 
                          backgroundColor: Colors.grey[200],
                          backgroundImage: avatarUrl != null 
                              ? NetworkImage("$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}") 
                              : null,
                          child: avatarUrl == null ? const Icon(Icons.person, size: 20) : null,
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),

            const SizedBox(height: 25),
            const Text("Our Collection", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const Text("New Arrivals", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 20),

            // ব্যানার স্লাইডার
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: bannerStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 160);
                return CarouselSlider(
                  options: CarouselOptions(height: 160, autoPlay: true, enlargeCenterPage: true, viewportFraction: 1.0),
                  items: snapshot.data!.map((banner) => ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(banner['image_url'], fit: BoxFit.cover, width: double.infinity),
                  )).toList(),
                );
              },
            ),

            const SizedBox(height: 25),
            const Text("Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryItem(Icons.laptop, "Gadgets"),
                  _categoryItem(Icons.checkroom, "Fashion"),
                  _categoryItem(Icons.watch, "Watch"),
                  _categoryItem(Icons.home_outlined, "Home"),
                  _categoryItem(Icons.phone_iphone, "Phones"),
                ],
              ),
            ),

            const SizedBox(height: 25),
            const Text("Popular Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // প্রোডাক্ট লিস্ট
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: productStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.75, mainAxisSpacing: 15, crossAxisSpacing: 15),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) => _ProductCard(product: snapshot.data![index]),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _categoryItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
            child: Icon(icon, color: Colors.orange[800], size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

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
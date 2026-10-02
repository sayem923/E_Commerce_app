import 'package:e_commerce_app/login_page.dart';
import 'package:e_commerce_app/vendor_product_details_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

// আপনার প্রোজেক্টের ফাইল পাথগুলো চেক করে নিন
import 'product_details_page.dart';
import 'profile_page.dart';
import 'cart_page.dart';
// 🎯 ভেন্ডর অর্ডার (টাইমার পেজ) ফাইলটি ইম্পোর্ট করা হলো
import 'vendor_orders_page.dart'; 
import 'wishlist_page.dart';
import 'notifications_page.dart';
import 'skeleton_widgets.dart';
import 'review_widgets.dart';

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
    const WishlistPage(), 
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

          ListTile(
            leading: NotificationBadge(child: Icon(Icons.notifications_none, color: Colors.orange[800])),
            title: const Text("Notifications"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
            },
          ),

          // 🎯 নতুন কানেকশন বাটন: ভেন্ডর তার অর্ডারের লাইভ টাইমার দেখতে এই অপশনে ক্লিক করবে
          // ListTile(
          //   leading: Icon(Icons.storefront_rounded, color: Colors.orange[800]), 
          //   title: Text(
          //     "Vendor Dashboard (Orders)", 
          //     style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
          //   ), 
          //   subtitle: const Text("Manage orders with live countdown"),
          //   onTap: () {
          //     Navigator.pop(context); // প্রথমে ড্রয়ার মেনুটি বন্ধ করবে
          //     Navigator.push(
          //       context, 
          //       MaterialPageRoute(builder: (context) => const VendorOrdersPage()) // টাইমার ওয়ালা পেজে নিয়ে যাবে
          //     );
          //   }
          // ),

          const Divider(),
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
  String _searchQuery = "";

  // 📄 Pagination state (products এর জন্য — realtime stream এর বদলে)
  final List<Map<String, dynamic>> _products = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 12;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
          !_isLoadingMore &&
          _hasMore) {
        _fetchProducts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchProducts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isInitialLoading = _products.isEmpty;
        _currentPage = 0;
        _hasMore = true;
        _products.clear();
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      var query = supabase.from('products').select();

      if (_selectedCategory != "All") {
        query = query.eq('category', _selectedCategory);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }

      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final data = await query.order('id', ascending: false).range(from, to);
      final newItems = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _products.addAll(newItems);
          _hasMore = newItems.length == _pageSize;
          _currentPage++;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Product fetch error: $e");
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onCategorySelected(String cat) {
    setState(() => _selectedCategory = cat);
    _fetchProducts(reset: true);
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchProducts(reset: true);
    });
  }

  Future<void> _handleRefresh() async {
    await _fetchProducts(reset: true);
  }

  Future<void> _onBannerClick(String productId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    try {
      final productData = await supabase
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle(); 
      
      if (mounted) {
        Navigator.pop(context); 
        
        if (productData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(product: productData),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product not found or unavailable!")),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      debugPrint("Error fetching product for banner: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final bannerStream = supabase.from('banners').stream(primaryKey: ['id']);
    final profileStream = supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user?.id ?? '');

    return SafeArea(
      child: RefreshIndicator(
        color: Colors.orange[800],
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(), 
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 140, 
            ),
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
                const SizedBox(height: 15),

                TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: "Search products...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 20),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: bannerStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 160);
                    if (snapshot.data!.isEmpty) return const SizedBox();

                    return CarouselSlider(
                      options: CarouselOptions(height: 160, autoPlay: true, enlargeCenterPage: true, viewportFraction: 1.0),
                      items: snapshot.data!.map((banner) => GestureDetector(
                        onTap: () {
                          if (banner['product_id'] != null && banner['product_id'].toString().isNotEmpty) {
                            _onBannerClick(banner['product_id'].toString());
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: banner['image_url'], 
                            fit: BoxFit.cover, 
                            width: double.infinity,
                            placeholder: (context, url) => Container(color: Colors.grey.shade100),
                            errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 40)),
                          ),
                        ),
                      )).toList(),
                    );
                  },
                ),

                const SizedBox(height: 25),
                const Text("Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ["All", "Gadgets", "Fashion", "Book", "Phones", "Others"].map((cat) {
                      bool isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => _onCategorySelected(cat),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange[800] : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                            boxShadow: [
                              if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
                            ]
                          ),
                          child: Center(
                            child: Text(
                              cat, 
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87, 
                                fontWeight: FontWeight.bold,
                                fontSize: 13
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 25),
                const Text("Popular Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                if (_isInitialLoading)
                  const ProductGridSkeleton()
                else if (_products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Text("No products found!", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.75, mainAxisSpacing: 15, crossAxisSpacing: 15),
                    itemCount: _products.length,
                    itemBuilder: (context, index) => _ProductCard(product: _products[index]),
                  ),

                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                  ),

                if (!_hasMore && _products.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("আর কোনো প্রোডাক্ট নেই", style: TextStyle(color: Colors.grey, fontSize: 13))),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final int stock = int.tryParse(product['stock']?.toString() ?? '0') ?? 0;
    final bool outOfStock = stock <= 0;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: product['image_url'] ?? '', 
                      fit: BoxFit.cover, 
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(color: Colors.grey.shade100),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                  if (outOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black45),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                          child: const Text("OUT OF STOCK", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: WishlistToggleButton(product: product, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1),
                  const SizedBox(height: 4),
                  Text("৳ ${product['price']}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  if ((double.tryParse(product['avg_rating']?.toString() ?? '0') ?? 0) > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        StarRatingDisplay(rating: double.tryParse(product['avg_rating']?.toString() ?? '0') ?? 0, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "(${product['review_count'] ?? 0})",
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
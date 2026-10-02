import 'package:e_commerce_app/login_page.dart';
import 'package:e_commerce_app/vendor_product_details_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'product_details_page.dart';
import 'vendor_dashboard.dart';
import 'profile_page.dart';
import 'cart_page.dart';
import 'vendor_orders_page.dart'; 
import 'wishlist_page.dart';
import 'my_products_page.dart';
import 'notifications_page.dart';
import 'sales_analytics_page.dart';
import 'skeleton_widgets.dart';
import 'review_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;

  late final Stream<List<Map<String, dynamic>>> _profileStream;

  final List<Widget> _pages = [
    const HomeView(),           
    const WishlistPage(), 
    const CartPage(),           
    const NotificationsPage(), 
  ];

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    _profileStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user?.id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      drawer: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _profileStream,
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
                  icon: NotificationBadge(
                    child: Icon(Icons.notifications_none, color: _selectedIndex == 3 ? Colors.orange[800] : Colors.grey),
                  ),
                  onPressed: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
          
          // 🏪 ১. ভেন্ডর ড্যাশবোর্ড
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.blue), 
            title: const Text("Vendor Dashboard"), 
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorDashboard()));
            }
          ),

          // 🔔 ২. ভেন্ডরদের জন্য লাইভ অর্ডার রিসিভ করার পেজ
          ListTile(
            leading: const Icon(Icons.storefront_rounded, color: Colors.green), 
            title: const Text("Vendor Orders (Receive)", style: TextStyle(fontWeight: FontWeight.bold)), 
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorOrdersPage()));
            }
          ),

          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text("Stock Inventory"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyProductsPage()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text("Sales Analytics"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesAnalyticsPage()));
            },
          ),
          
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
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
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
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final supabase = Supabase.instance.client;
  String _selectedCategory = "All";
  String _searchQuery = "";

  final List<String> _definedCategories = ["Gadgets", "Fashion", "Book", "Phones"];

  late final Stream<List<Map<String, dynamic>>> _bannerStream;
  late final Stream<List<Map<String, dynamic>>> _profileStream;

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
    final user = supabase.auth.currentUser;
    
    _bannerStream = supabase.from('banners').stream(primaryKey: ['id']);
    _profileStream = supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user?.id ?? '');

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

  // 📄 নির্দিষ্ট page-এর প্রোডাক্ট আনে (category/search filter সহ)। reset:true দিলে
  // প্রথম পাতা থেকে নতুন করে লোড হবে (category/search বদলালে বা pull-to-refresh করলে)।
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

      if (_selectedCategory == "Others") {
        final excluded = _definedCategories.map((c) => '"$c"').join(",");
        query = query.not('category', 'in', '($excluded)');
      } else if (_selectedCategory != "All") {
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

  Future<void> _onBannerClick(dynamic productId) async {
    if (productId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("এই ব্যানারে কোনো product_id সেট করা নেই!")),
        );
      }
      return;
    }
    try {
      final targetId = productId is int ? productId : int.tryParse(productId.toString()) ?? productId;

      final productData = await supabase
          .from('products')
          .select()
          .eq('id', targetId)
          .maybeSingle();
      
      if (productData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("প্রোডাক্ট পাওয়া যায়নি! ডাটাবেজে ID: $targetId চেক করুন।")),
          );
        }
        return;
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> uiCategories = ["All", ..._definedCategories, "Others"];

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
                      stream: _profileStream,
                      builder: (context, snapshot) {
                        final profile = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data!.first : null;
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
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
                  stream: _bannerStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 160);
                    return CarouselSlider(
                      options: CarouselOptions(height: 160, autoPlay: true, enlargeCenterPage: true, viewportFraction: 1.0),
                      items: snapshot.data!.map((banner) => GestureDetector(
                        onTap: () {
                          if (banner['product_id'] != null) {
                            _onBannerClick(banner['product_id']);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: banner['image_url'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(color: Colors.grey.shade100),
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
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
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: uiCategories.map((cat) {
                      bool isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                      return GestureDetector(
                        onTap: () => _onCategorySelected(cat),
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

                if (_isInitialLoading)
                  const ProductGridSkeleton()
                else if (_products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Text("No products found.", style: TextStyle(color: Colors.grey)),
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VendorProductDetailsPage(product: product))),
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
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              ]),
            )
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sales_analytics_page.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _stock = TextEditingController(text: "1");
  List<XFile> _imageFiles = [];
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  
  final List<String> _categories = ["Home", "Fashion", "Gadgets", "Others"];
  String _selectedCategory = "Home"; 

  // ১. ব্যানার আপলোড
  Future<void> _uploadBanner() async {
    final XFile? banner = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 450,
      imageQuality: 85,
    );
    
    if (banner == null) return;

    setState(() => _isLoading = true);
    try {
      final fileName = 'banners/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('product_images').uploadBinary(fileName, await banner.readAsBytes());
      final imageUrl = _supabase.storage.from('product_images').getPublicUrl(fileName);

      await _supabase.from('banners').insert({'image_url': imageUrl});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Professional Banner Added!")));
      }
    } catch (e) {
      debugPrint("$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Banner Upload Failed: $e"), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ২. প্রোডাক্ট আপলোড (ক্যাটাগরি এবং ভেন্ডর আইডি সহ)
  Future<void> _uploadProduct() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login as vendor first!")));
      return;
    }

    if (_name.text.isEmpty || _price.text.isEmpty || _imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and select at least one image")));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      // 🖼️ একাধিক ছবি আপলোড করা হচ্ছে
      final List<String> imageUrls = [];
      for (final file in _imageFiles) {
        final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg';
        await _supabase.storage.from('product_images').uploadBinary(fileName, await file.readAsBytes());
        imageUrls.add(_supabase.storage.from('product_images').getPublicUrl(fileName));
      }

      // ডাটাবেসে ডাটা পাঠানো (vendor_id, stock ও একাধিক ছবি যুক্ত করা হয়েছে)
      // image_url = প্রথম ছবি (cover/thumbnail হিসেবে ব্যবহার হবে cart, order, ইত্যাদিতে)
      // image_urls = সব ছবির array (product details পেজে gallery হিসেবে দেখাবে)
      await _supabase.from('products').insert({
        'name': _name.text.trim(),
        'price': double.parse(_price.text.trim()),
        'description': _desc.text.trim(),
        'image_url': imageUrls.first,
        'image_urls': imageUrls,
        'category': _selectedCategory, 
        'vendor_id': currentUser.id, 
        'stock': int.tryParse(_stock.text.trim()) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Published!"), backgroundColor: Colors.green));
      }
      
      _name.clear(); _price.clear(); _desc.clear(); _stock.text = "1";
      setState(() => _imageFiles = []);
      
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Product Upload Failed: $e"), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _desc.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Panel", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: "Sales Analytics",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesAnalyticsPage()));
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange)) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // প্রোমো ব্যানার সেকশন
                Card(
                  elevation: 2,
                  color: Colors.orange[50],
                  child: ListTile(
                    leading: const Icon(Icons.add_photo_alternate, color: Colors.orange),
                    title: const Text("Upload Promo Banner", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Size: 1200x450 px"),
                    onTap: _uploadBanner,
                  ),
                ),
                
                const SizedBox(height: 25),
                const Text("Add New Product", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // ইমেজ সিলেক্টর (একাধিক ছবি)
                GestureDetector(
                  onTap: () async {
                    final imgs = await ImagePicker().pickMultiImage(imageQuality: 80);
                    if (imgs.isNotEmpty) {
                      setState(() => _imageFiles = [..._imageFiles, ...imgs]);
                    }
                  },
                  child: Container(
                    height: 100, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100], 
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 36, color: Colors.grey),
                        Text("Select Product Images (একাধিক নেওয়া যাবে)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                if (_imageFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) {
                        final file = _imageFiles[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(file.path, width: 90, height: 90, fit: BoxFit.cover)
                                    : Image.file(File(file.path), width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              if (index == 0)
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                    child: const Text("Cover", style: TextStyle(color: Colors.white, fontSize: 9)),
                                  ),
                                ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _imageFiles = List.from(_imageFiles)..removeAt(index)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                TextField(controller: _name, decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                
                // --- ক্যাটাগরি ড্রপডাউন ---
                const Text("Select Category", style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                ),

                const SizedBox(height: 15),
                TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price (৳)", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock Quantity", border: OutlineInputBorder(), helperText: "কয়টা পিস স্টকে আছে")),
                const SizedBox(height: 15),
                TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
                
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _uploadProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800], 
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: const Text("Publish Product", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }
}
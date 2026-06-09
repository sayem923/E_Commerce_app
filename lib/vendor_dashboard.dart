import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  XFile? _imageFile;
  bool _isLoading = false;

  // ক্যাটাগরি লিস্ট (আপনার হোম পেজের সাথে মিল রেখে)
  final List<String> _categories = ["Home", "Fashion", "Gadgets", "Others"];
  String _selectedCategory = "Home"; // ডিফল্ট সিলেক্টেড

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
      final supabase = Supabase.instance.client;
      final fileName = 'banners/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('product_images').uploadBinary(fileName, await banner.readAsBytes());
      final imageUrl = supabase.storage.from('product_images').getPublicUrl(fileName);

      await supabase.from('banners').insert({'image_url': imageUrl});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Professional Banner Added!")));
      }
    } catch (e) {
      debugPrint("$e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ২. প্রোডাক্ট আপলোড (ক্যাটাগরি সহ)
  Future<void> _uploadProduct() async {
    if (_name.text.isEmpty || _price.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and select image")));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('product_images').uploadBinary(fileName, await _imageFile!.readAsBytes());
      final imageUrl = supabase.storage.from('product_images').getPublicUrl(fileName);

      // ডাটাবেসে ডাটা পাঠানো
      await supabase.from('products').insert({
        'name': _name.text.trim(),
        'price': double.parse(_price.text.trim()),
        'description': _desc.text.trim(),
        'image_url': imageUrl,
        'category': _selectedCategory, // এই লাইনটি ক্যাটাগরি সেভ করবে
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Published!"), backgroundColor: Colors.green));
      }
      
      // ফিল্ড ক্লিয়ার করা
      _name.clear(); _price.clear(); _desc.clear(); 
      setState(() => _imageFile = null);
      
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Panel", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
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

                // ইমেজ সিলেক্টর
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (img != null) setState(() => _imageFile = img);
                  },
                  child: Container(
                    height: 180, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100], 
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: _imageFile == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                            Text("Select Product Image", style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(15), 
                          child: Image.network(_imageFile!.path, fit: BoxFit.cover)
                        ),
                  ),
                ),

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
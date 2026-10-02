import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'skeleton_widgets.dart';

/// ভেন্ডর তার নিজের পোস্ট করা প্রোডাক্ট এখানে দেখতে, এডিট (নাম/দাম/বিবরণ/ছবি) ও ডিলিট করতে পারবেন।
class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage> {
  final _supabase = Supabase.instance.client;

  Future<void> _showEditDialog(Map<String, dynamic> product) async {
    final nameController = TextEditingController(text: product['name']?.toString() ?? '');
    final priceController = TextEditingController(text: product['price']?.toString() ?? '');
    final descController = TextEditingController(text: product['description']?.toString() ?? '');
    final stockController = TextEditingController(text: product['stock']?.toString() ?? '0');

    List<String> galleryImages = (product['image_urls'] is List)
        ? (product['image_urls'] as List).map((e) => e.toString()).toList()
        : (product['image_url'] != null && product['image_url'].toString().isNotEmpty ? [product['image_url'].toString()] : <String>[]);
    bool isUploadingImage = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickAndUploadMore() async {
            final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
            if (picked.isEmpty) return;

            setDialogState(() => isUploadingImage = true);
            try {
              for (final file in picked) {
                final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}_${galleryImages.length}.jpg';
                await _supabase.storage.from('product_images').uploadBinary(fileName, await file.readAsBytes());
                final url = _supabase.storage.from('product_images').getPublicUrl(fileName);
                galleryImages.add(url);
              }
            } catch (e) {
              debugPrint("Image upload error: $e");
            } finally {
              setDialogState(() => isUploadingImage = false);
            }
          }

          return AlertDialog(
            title: const Text("Edit Product"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Product Images", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...galleryImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final url = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(imageUrl: url, width: 70, height: 70, fit: BoxFit.cover),
                                ),
                                if (index == 0)
                                  Positioned(
                                    bottom: 2, left: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                      child: const Text("Cover", style: TextStyle(color: Colors.white, fontSize: 8)),
                                    ),
                                  ),
                                Positioned(
                                  top: 0, right: 0,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(() => galleryImages.removeAt(index)),
                                    child: const CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close, size: 11, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: isUploadingImage ? null : pickAndUploadMore,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: isUploadingImage
                                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                                : const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: "Product Name")),
                  const SizedBox(height: 10),
                  TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price (৳)")),
                  const SizedBox(height: 10),
                  TextField(controller: stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock Quantity")),
                  const SizedBox(height: 10),
                  TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(labelText: "Description")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    try {
      await _supabase.from('products').update({
        'name': nameController.text.trim(),
        'price': double.tryParse(priceController.text.trim()) ?? product['price'],
        'description': descController.text.trim(),
        'stock': int.tryParse(stockController.text.trim()) ?? product['stock'] ?? 0,
        'image_urls': galleryImages,
        'image_url': galleryImages.isNotEmpty ? galleryImages.first : product['image_url'],
      }).eq('id', product['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product Updated!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update Failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product"),
        content: Text("আপনি কি \"${product['name']}\" মুছে ফেলতে চান? এটি ফিরিয়ে আনা যাবে না।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('products').delete().eq('id', product['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product Deleted!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete Failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    final myProductsStream = _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('vendor_id', user?.id ?? '')
        .order('id', ascending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("My Products", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: myProductsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return const Center(
              child: Text("আপনি এখনো কোনো প্রোডাক্ট পোস্ট করেননি।", style: TextStyle(color: Colors.grey, fontSize: 15)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final imageUrl = product['image_url']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 55,
                      height: 55,
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
                  title: Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    "৳ ${product['price']}  •  ${product['category'] ?? ''}  •  Stock: ${product['stock'] ?? 0}",
                    style: TextStyle(color: (product['stock'] ?? 0) == 0 ? Colors.red : Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showEditDialog(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(product),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

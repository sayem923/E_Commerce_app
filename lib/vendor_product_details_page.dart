import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'review_widgets.dart';

class VendorProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> product;
  const VendorProductDetailsPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product['name'] ?? "Product Details"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            CachedNetworkImage(
              imageUrl: product['image_url'] ?? '', 
              height: 300, 
              width: double.infinity, 
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 300,
                color: Colors.grey,
                child: const Icon(Icons.broken_image, size: 50, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "৳ ${product['price']}", 
                    style: TextStyle(fontSize: 26, color: Colors.orange[800], fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product['name'] ?? '', 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                  ),
                  if ((double.tryParse(product['avg_rating']?.toString() ?? '0') ?? 0) > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StarRatingDisplay(rating: double.tryParse(product['avg_rating']?.toString() ?? '0') ?? 0, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "${product['avg_rating']} (${product['review_count'] ?? 0} reviews)",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 5),
                  Chip(
                    label: Text("Category: ${product['category'] ?? 'Others'}"),
                    backgroundColor: Colors.orange[50],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Product Description", 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product['description'] ?? 'No description provided.',
                    style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
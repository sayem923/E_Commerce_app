import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// পুরো app জুড়ে ব্যবহার হওয়া reusable "skeleton" (shimmer) loading
/// widget-গুলো এখানে রাখা হয়েছে — যাতে প্রতিটা পেজে আলাদা করে shimmer
/// কোড লিখতে না হয়।

/// এক লাইনে shimmer effect wrap করে দেয়
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(color: Colors.white),
    );
  }
}

/// Product grid card-এর জায়গায় দেখানোর skeleton — home page-এ product
/// লোড হওয়ার সময় ব্যবহার হয়
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 90, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 50, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GridView.builder-এ বসিয়ে সরাসরি product grid-এর জায়গায় N-টা skeleton
/// card দেখানোর জন্য shortcut
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const ProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// Cart/Orders/Wishlist/My Products-এর মতো horizontal card-list-এর জন্য
/// একটা সারি skeleton — ছবি + দুই লাইন লেখার জায়গা
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 100, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 60, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ListView.builder-এ বসিয়ে N-টা row skeleton দেখানোর shortcut
class ListSkeleton extends StatelessWidget {
  final int itemCount;

  const ListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ListRowSkeleton(),
    );
  }
}

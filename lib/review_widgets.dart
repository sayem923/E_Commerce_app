import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// শুধু rating দেখানোর জন্য (read-only) স্টার — product card, product
/// details, review list — সব জায়গায় ব্যবহার হবে
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const StarRatingDisplay({super.key, required this.rating, this.size = 16, this.color = Colors.amber});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        if (rating >= index + 1) {
          icon = Icons.star_rounded;
        } else if (rating > index && rating < index + 1) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

/// Review লেখার সময় ব্যবহারকারী ট্যাপ করে ১-৫ স্টার বেছে নেবেন
class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({super.key, required this.rating, required this.onChanged, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Icon(
            starValue <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: Colors.amber,
          ),
        );
      }),
    );
  }
}

/// Product Details পেজে বসানোর জন্য পুরো review section — average rating
/// সামারি, review list (real-time), আর "Write a Review" ফর্ম
class ReviewsSection extends StatefulWidget {
  final int productId;

  const ReviewsSection({super.key, required this.productId});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  final _supabase = Supabase.instance.client;
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("রিভিউ দিতে আগে লগইন করুন")),
      );
      return;
    }

    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("অনুগ্রহ করে একটা Rating (স্টার) দিন")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = await _supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle();

      await _supabase.from('reviews').upsert({
        'product_id': widget.productId,
        'user_id': user.id,
        'user_name': profile?['full_name'] ?? 'User',
        'rating': _selectedRating,
        'comment': _commentController.text.trim(),
      }, onConflict: 'product_id,user_id');

      if (mounted) {
        setState(() {
          _selectedRating = 0;
          _commentController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("রিভিউ জমা হয়েছে, ধন্যবাদ!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        // RLS policy ব্যর্থ হলে (যেমন এই প্রোডাক্ট কেনা হয়নি) বন্ধুসুলভ মেসেজ দেখানো হচ্ছে
        final msg = e.toString().contains('row-level security') || e.toString().contains('policy')
            ? "শুধুমাত্র যারা এই প্রোডাক্টটি কিনে \"Completed\" পেয়েছেন তারাই রিভিউ দিতে পারবেন।"
            : "রিভিউ জমা দিতে সমস্যা হয়েছে: $e";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsStream = _supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('product_id', widget.productId)
        .order('created_at', ascending: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ratings & Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),

        // ✍️ Write a review
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("আপনার রিভিউ লিখুন", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              StarRatingInput(rating: _selectedRating, onChanged: (val) => setState(() => _selectedRating = val)),
              const SizedBox(height: 10),
              TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "আপনার অভিজ্ঞতা লিখুন (ঐচ্ছিক)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Submit Review", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 📋 Review list
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: reviewsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }

            final reviews = snapshot.data ?? [];

            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text("এখনো কোনো রিভিউ নেই — প্রথম রিভিউ আপনিই দিন!", style: TextStyle(color: Colors.grey)),
              );
            }

            final avgRating = reviews.fold<int>(0, (sum, r) => sum + (r['rating'] as int? ?? 0)) / reviews.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StarRatingDisplay(rating: avgRating, size: 18),
                        Text("${reviews.length} টি রিভিউ", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30),
                ...reviews.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.orange.shade100,
                                child: Text(
                                  (r['user_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['user_name']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    StarRatingDisplay(rating: (r['rating'] as int? ?? 0).toDouble(), size: 13),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 42),
                              child: Text(r['comment'].toString(), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],
            );
          },
        ),
      ],
    );
  }
}

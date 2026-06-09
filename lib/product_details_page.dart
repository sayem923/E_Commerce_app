import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final _pinController = TextEditingController();

  // --- ১. পিন ইনপুট ডায়ালগ (একদম রিয়েল ফিল দিবে) ---
  void _showPinDialog(String method, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(backgroundColor: color, radius: 15, child: const Icon(Icons.security, size: 15, color: Colors.white)),
            const SizedBox(width: 10),
            Text("$method PIN", style: TextStyle(color: color)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your secret PIN to confirm payment"),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: "****",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () {
              Navigator.pop(context); // পিন ডায়ালগ বন্ধ
              _processPayment(); // লোডিং শুরু
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ২. পেমেন্ট প্রসেসিং অ্যানিমেশন ---
  void _processPayment() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.pink)),
    );

    // ডেমো ২ সেকেন্ড লোডিং
    await Future.delayed(const Duration(seconds: 2));
    
    // পেমেন্ট ডেটা সেভ করা (ঐচ্ছিক: আপনার orders টেবিল থাকলে)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('orders').insert({
          'user_id': user.id,
          'product_name': widget.product['name'],
          'price': widget.product['price'],
          'status': 'Paid'
        });
      }
    } catch (e) {
      debugPrint("Order save error: $e");
    }

    if (mounted) {
      Navigator.pop(context); // লোডিং বন্ধ
      _showSuccessDialog(); // সাকসেস ডায়ালগ
    }
  }

  // --- ৩. সাকসেস ডায়ালগ ---
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text("Congratulations!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Order placed successfully!", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // ডায়ালগ বন্ধ
                Navigator.pop(context); // হোম পেজে ব্যাক
              },
              child: const Text("Done"),
            )
          ],
        ),
      ),
    );
  }

  // --- ৪. পেমেন্ট মেথড শিট ---
  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Gateway", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.payment, color: Colors.pink),
                title: const Text("bKash"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                onTap: () {
                  Navigator.pop(context);
                  _showPinDialog("bKash", Colors.pink);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment, color: Colors.orange),
                title: const Text("Nagad"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                onTap: () {
                  Navigator.pop(context);
                  _showPinDialog("Nagad", Colors.orange);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product['name'] ?? "Details")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.network(widget.product['image_url'] ?? '', height: 300, width: double.infinity, fit: BoxFit.cover),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("৳ ${widget.product['price']}", style: const TextStyle(fontSize: 25, color: Colors.teal, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(widget.product['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(widget.product['description'] ?? 'High quality product description...'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // বটম বাটন
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _showPaymentSheet,
              child: const Text("Buy Now", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
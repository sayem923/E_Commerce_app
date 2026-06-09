import 'package:flutter/material.dart';

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Orders"), backgroundColor: Colors.teal),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.teal),
              title: Text("Order #1234$index"),
              subtitle: const Text("Status: Processing"),
              trailing: const Text("৳ 1200", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}
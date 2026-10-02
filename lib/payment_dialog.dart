import 'package:flutter/material.dart';
import 'payment_config.dart';

/// Checkout করার আগে এই dialog দেখানো হয় — Cash on Delivery বা bKash/Nagad
/// বেছে নিতে বলে। bKash/Nagad বেছে নিলে receiving নাম্বার দেখিয়ে sender
/// নাম্বার ও Transaction ID (TrxID) চেয়ে নেয়।
///
/// Return করে:
///   null                         -> user cancel করেছে
///   { 'payment_method': 'COD', 'payment_status': 'unpaid' }
///   { 'payment_method': 'bKash'|'Nagad', 'payment_status': 'pending_verification',
///     'transaction_id': '...', 'sender_number': '...' }
Future<Map<String, dynamic>?> showPaymentMethodDialog(BuildContext context) async {
  String selectedMethod = "COD";

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final senderController = TextEditingController();
      final trxController = TextEditingController();

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Select Payment Method"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Cash on Delivery"),
                    value: "COD",
                    groupValue: selectedMethod,
                    onChanged: (val) => setDialogState(() => selectedMethod = val!),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("bKash"),
                    value: "bKash",
                    groupValue: selectedMethod,
                    onChanged: (val) => setDialogState(() => selectedMethod = val!),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Nagad"),
                    value: "Nagad",
                    groupValue: selectedMethod,
                    onChanged: (val) => setDialogState(() => selectedMethod = val!),
                  ),

                  if (selectedMethod == "bKash" || selectedMethod == "Nagad") ...[
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedMethod == "bKash"
                            ? "এই ${PaymentConfig.bkashType} নাম্বারে Send Money করুন:\n${PaymentConfig.bkashNumber}"
                            : "এই ${PaymentConfig.nagadType} নাম্বারে Send Money করুন:\n${PaymentConfig.nagadNumber}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senderController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "আপনার নাম্বার (যেখান থেকে পাঠিয়েছেন)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: trxController,
                      decoration: const InputDecoration(
                        labelText: "Transaction ID (TrxID)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                onPressed: () {
                  if (selectedMethod == "COD") {
                    Navigator.pop(dialogContext, {
                      'payment_method': 'COD',
                      'payment_status': 'unpaid',
                    });
                    return;
                  }

                  if (senderController.text.trim().isEmpty || trxController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("নাম্বার আর Transaction ID দুটোই লিখুন")),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'payment_method': selectedMethod,
                    'payment_status': 'pending_verification',
                    'transaction_id': trxController.text.trim(),
                    'sender_number': senderController.text.trim(),
                  });
                },
                child: const Text("Confirm", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

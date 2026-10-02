/// এই ফাইলে আপনার bKash/Nagad Personal/Merchant নাম্বার বসিয়ে দিন।
/// এটা "manual verification" পদ্ধতি — সরাসরি bKash/Nagad Payment Gateway API
/// (যেটার জন্য merchant credential ও backend সার্ভার লাগে) না।
///
/// কীভাবে কাজ করে:
/// ১. Checkout-এ customer bKash/Nagad সিলেক্ট করলে এই নাম্বার দেখানো হবে
/// ২. Customer সেই নাম্বারে টাকা "Send Money"/"Payment" করে দেবে
/// ৩. Customer app-এ ফিরে এসে তার নিজের নাম্বার আর bKash/Nagad থেকে পাওয়া
///    Transaction ID (TrxID) লিখে অর্ডার confirm করবে
/// ৪. Vendor তার Orders পেজে গিয়ে TrxID মিলিয়ে "Payment Verified" মার্ক করবে
///
/// ভবিষ্যতে যদি আসল bKash/Nagad Merchant API নিতে চান (auto-verification,
/// instant confirmation), তখন merchant App Key/Secret ও একটা backend
/// (Supabase Edge Function) লাগবে — সেটা এই ফাইল বদলে করা যাবে।
class PaymentConfig {
  static const String bkashNumber = "01XXXXXXXXX"; // <-- আপনার bKash নাম্বার বসান
  static const String nagadNumber = "01XXXXXXXXX"; // <-- আপনার Nagad নাম্বার বসান
  static const String bkashType = "Personal"; // "Personal" অথবা "Merchant"
  static const String nagadType = "Personal";
}

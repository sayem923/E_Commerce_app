import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart'; 
import 'vendor_orders_page.dart'; // 🎯 আপনার তৈরি করা অর্ডার পেজটি ইমপোর্ট করুন
import 'edit_profile_page.dart';   // 🎯 এডিট প্রোফাইল পেজ ইমপোর্ট করুন

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    
    final profileStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user?.id ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        // 🛠️ অ্যাপবারে এডিট প্রোফাইল পেজে যাওয়ার জন্য বাটন যুক্ত করা হলো
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.black87, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          final profile = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data!.first : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.orange.shade100,
                        backgroundImage: profile?['avatar_url'] != null
                            ? NetworkImage("${profile!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}")
                            : null,
                        child: profile?['avatar_url'] == null
                            ? const Icon(Icons.person, size: 60, color: Colors.orange)
                            : null,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        profile?['full_name'] ?? "User Name",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user?.email ?? "No Email Found",
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // 🛠️ "My Orders" বাটনে ক্লিক করলে কাস্টমার হিসেবে ট্র্যাক পেজে নিয়ে যাবে
                _buildProfileItem(Icons.shopping_bag_outlined, "My Orders", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VendorOrdersPage(isVendor: false), // কাস্টমার ট্র্যাকিং ভিউ
                    ),
                  );
                }),
                
                _buildProfileItem(Icons.favorite_border, "Wishlist", () {}),
                _buildProfileItem(Icons.location_on_outlined, "Shipping Address", () {}),
                
                // 🛠️ Settings বাটনে ক্লিক করলেও এডিট প্রোফাইলে যাওয়ার ব্যবস্থা করা হলো
                _buildProfileItem(Icons.settings_outlined, "Settings / Edit Profile", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfilePage()),
                  );
                }),
                
                const Divider(height: 40),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout, color: Colors.red),
                  ),
                  title: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                  onTap: () async {
                    await _supabase.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
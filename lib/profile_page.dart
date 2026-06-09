import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart'; // নিশ্চিত হোন আপনার লগইন পেজের ফাইল পাথ ঠিক আছে

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
    
    // প্রোফাইল ডেটা রিয়েল-টাইম আনার জন্য স্ট্রিম
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
                // প্রোফাইল পিকচার এবং নাম সেকশন
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

                // অপশন লিস্ট
                _buildProfileItem(Icons.shopping_bag_outlined, "My Orders", () {}),
                _buildProfileItem(Icons.favorite_border, "Wishlist", () {}),
                _buildProfileItem(Icons.location_on_outlined, "Shipping Address", () {}),
                _buildProfileItem(Icons.settings_outlined, "Settings", () {}),
                
                const Divider(height: 40),

                // --- সাইন আউট বাটন (এটিই আপনার মেইন রিকোয়েস্ট ছিল) ---
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout, color: Colors.red),
                  ),
                  title: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                  onTap: () async {
                    // ১. সুপারবেস থেকে লগআউট
                    await _supabase.auth.signOut();

                    // ২. লগইন পেজে পাঠিয়ে দেওয়া এবং আগের সব রুট ক্লিয়ার করা
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false, // এটি করলে ব্যাকে টিপলে আর অ্যাপে ঢোকা যাবে না
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

  // কাস্টম লিস্ট আইটেম উইজেট
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
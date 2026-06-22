import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final data = await _supabase.from('profiles').select().eq('id', user.id).single();
      setState(() {
        _nameController.text = data['full_name'] ?? "";
        _avatarUrl = data['avatar_url'];
      });
    } catch (e) {
      debugPrint("Error loading profile data: $e");
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final path = 'profile_pic/${user.id}.png';

      await _supabase.storage.from('avatars').uploadBinary(
        path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/png')
      );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      
      setState(() {
        // 🔄 ইমেজ রিফ্রেশ ক্যাশ বাগ এড়াতে টাইমস্ট্যাম্প যোগ করা হয়েছে
        _avatarUrl = "$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image Uploaded! Save to confirm.")));
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // ইউআরএল থেকে ক্যাশ কোয়েরি স্ট্রিং রিমুভ করে ডাটাবেজে পিওর লিঙ্ক সেভ করা হচ্ছে
      String? cleanUrl = _avatarUrl;
      if (cleanUrl != null && cleanUrl.contains('?t=')) {
        cleanUrl = cleanUrl.split('?t=')[0];
      }

      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'avatar_url': cleanUrl,
      }).eq('id', user.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black, 
        elevation: 0.5
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickAndUploadImage,
                    child: const CircleAvatar(
                      backgroundColor: Colors.pink,
                      radius: 18,
                      child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 1,
              ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
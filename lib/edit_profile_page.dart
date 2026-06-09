import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
    final user = _supabase.auth.currentUser;
    final data = await _supabase.from('profiles').select().eq('id', user!.id).single();
    setState(() {
      _nameController.text = data['full_name'] ?? "";
      _avatarUrl = data['avatar_url'];
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final bytes = await image.readAsBytes();
      final path = 'profile_pic/${user!.id}.png';

      await _supabase.storage.from('avatars').uploadBinary(
        path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/png')
      );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      setState(() => _avatarUrl = publicUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image Uploaded! Save to confirm.")));
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'avatar_url': _avatarUrl,
      }).eq('id', user!.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null ? const Icon(Icons.person, size: 60) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
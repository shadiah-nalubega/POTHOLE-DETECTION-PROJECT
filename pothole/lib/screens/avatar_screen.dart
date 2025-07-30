import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pothole/ui/avatar_provider.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      final imageFile = File(picked.path);
      await Provider.of<AvatarProvider>(
        context,
        listen: false,
      ).uploadAvatar(imageFile);
    }
  }

  @override
  void initState() {
    super.initState();
    Provider.of<AvatarProvider>(context, listen: false).fetchAvatar();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = Provider.of<AvatarProvider>(context).avatarUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Avatar')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            avatarUrl != null
                ? CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(avatarUrl),
                  )
                : const CircleAvatar(
                    radius: 60,
                    child: Icon(Icons.person, size: 50),
                  ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Take Photo"),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Pick from Gallery"),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

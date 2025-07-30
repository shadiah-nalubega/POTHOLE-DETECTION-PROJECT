import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AvatarProvider with ChangeNotifier {
  String? _avatarUrl;
  String? get avatarUrl => _avatarUrl;

  Future<void> uploadAvatar(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use folder per user for easier security rules control
    final ref = FirebaseStorage.instance
        .ref()
        .child('avatars')
        .child(user.uid)
        .child('avatar.jpg');

    await ref.putFile(imageFile);

    final url = await ref.getDownloadURL();
    _avatarUrl = url;

    // Save URL in Firestore, merging so other user fields remain intact
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'avatarUrl': url,
    }, SetOptions(merge: true));

    notifyListeners();
  }
//th is the fetch function for the avatar
  Future<void> fetchAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      _avatarUrl = doc['avatarUrl'] as String?;
    } else {
      _avatarUrl = null;
    }

    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the profile photo on the user's device only. It is never uploaded
/// to the backend; the encoded bytes live in SharedPreferences per account.
class ProfilePhotoStore {
  ProfilePhotoStore._();

  static const maxBytes = 2 * 1024 * 1024;
  static const _prefix = 'pet_tracker_profile_photo_';
  static final photo = Rxn<Uint8List>();
  static String? _uid;

  static Future<void> loadFor(String? uid) async {
    _uid = uid;
    photo.value = null;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_prefix$uid');
    if (_uid != uid || encoded == null || encoded.isEmpty) return;
    try {
      final bytes = base64Decode(encoded);
      if (_uid == uid) photo.value = bytes;
    } catch (_) {}
  }

  static Future<void> save(Uint8List bytes) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    photo.value = bytes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$uid', base64Encode(bytes));
  }

  static Future<void> remove() async {
    final uid = _uid;
    photo.value = null;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$uid');
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_theme.dart';
import '../services/profile_photo_store.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.displayName, this.radius = 34});

  final String? displayName;
  final double radius;

  @override
  Widget build(BuildContext context) => Obx(() {
    final bytes = ProfilePhotoStore.photo.value;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.green.withValues(alpha: .16),
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? Text(
              _initial(displayName),
              style: TextStyle(
                fontSize: radius * .7,
                fontWeight: FontWeight.w900,
                color: AppTheme.green,
              ),
            )
          : null,
    );
  });
}

String _initial(String? displayName) {
  final name = (displayName ?? '').trim();
  if (name.isEmpty) return 'P';
  return name.characters.first.toUpperCase();
}

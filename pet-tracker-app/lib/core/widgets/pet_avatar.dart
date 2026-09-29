import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    required this.photoUrl,
    this.name,
    this.size = 54,
    this.borderRadius,
    this.border,
    this.backgroundColor,
    this.fallbackIcon = Icons.pets,
  });

  final String? photoUrl;
  final String? name;
  final double size;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Color? backgroundColor;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size / 2);
    final fallbackBg = backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : AppTheme.green.withValues(alpha: .12));

    Widget content;
    final url = (photoUrl ?? '').trim();

    if (url.startsWith('data:image') && url.contains('base64,')) {
      try {
        final base64String = url.split('base64,').last;
        final bytes = base64Decode(base64String);
        content = _buildImageFromBytes(bytes);
      } catch (_) {
        content = _buildFallback(fallbackBg);
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      content = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallback(fallbackBg),
      );
    } else if (url.startsWith('assets/')) {
      content = Image.asset(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(fallbackBg),
      );
    } else {
      content = _buildFallback(fallbackBg);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackBg,
        borderRadius: effectiveRadius,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: content,
      ),
    );
  }

  Widget _buildImageFromBytes(Uint8List bytes) {
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildFallback(AppTheme.green.withValues(alpha: .12)),
    );
  }

  Widget _buildFallback(Color bg) {
    return Center(
      child: Icon(
        fallbackIcon,
        color: AppTheme.green,
        size: size * 0.52,
      ),
    );
  }
}

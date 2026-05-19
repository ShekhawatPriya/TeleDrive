import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/auth_user.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.user, this.size = 62, super.key});

  final AuthUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial =
        (user?.firstName.isNotEmpty == true ? user!.firstName[0] : '?')
            .toUpperCase();
    final photoUrl = user?.photoUrl?.trim();

    Widget fallback() => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outline),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: size * .38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) return fallback();

    Widget image;
    if (photoUrl.startsWith('data:image')) {
      final comma = photoUrl.indexOf(',');
      final payload = comma == -1 ? '' : photoUrl.substring(comma + 1);
      try {
        image = Image.memory(
          base64Decode(payload),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        return fallback();
      }
    } else {
      image = CachedNetworkImage(
        imageUrl: photoUrl,
        cacheKey: _cacheKey(photoUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback(),
        errorWidget: (_, __, ___) => fallback(),
      );
    }

    return ClipOval(child: image);
  }

  String _cacheKey(String photoUrl) {
    final uri = Uri.tryParse(photoUrl);
    if (uri == null) return 'profile-photo-${user?.userId ?? 'anon'}';
    final params = Map<String, String>.from(uri.queryParameters)
      ..remove('token');
    final stableUri = uri.replace(
      queryParameters: params.isEmpty ? null : params,
    );
    return 'profile-photo-${user?.userId ?? 'anon'}-$stableUri';
  }
}

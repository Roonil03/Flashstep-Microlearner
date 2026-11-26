import 'package:flutter/material.dart';

import 'image_decode_size.dart';

/// The decorative mark used alongside the app name or version.
class FlashstepLogo extends StatelessWidget {
  const FlashstepLogo({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/LogoWithoutText_WithoutBGLarge_Square_Monochrome.png',
    width: size,
    height: size,
    color: color,
    excludeFromSemantics: true,
    cacheWidth: imageDecodeSize(
      logicalSize: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      sourceSize: 768,
    ),
  );
}

import 'package:flutter/material.dart';

import 'image_decode_size.dart';

/// The original full-color mark used alongside the app name or version.
class FlashstepLogo extends StatelessWidget {
  const FlashstepLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/LogoWithoutText_WithoutBGLarge_Square.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    cacheWidth: imageDecodeSize(
      logicalSize: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      sourceSize: 768,
    ),
  );
}

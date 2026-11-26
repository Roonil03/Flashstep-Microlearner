/// Decode only the physical pixels needed by a fixed-size asset. Set one cache
/// dimension so the decoder preserves the source aspect ratio.
int? imageDecodeSize({
  required double logicalSize,
  required double devicePixelRatio,
  required int sourceSize,
}) {
  if (!logicalSize.isFinite || logicalSize <= 0 || sourceSize <= 0) return null;
  final ratio =
      devicePixelRatio.isFinite && devicePixelRatio > 0
          ? devicePixelRatio
          : 1.0;
  final pixels = logicalSize * ratio;
  if (pixels >= sourceSize) return sourceSize;
  return pixels.ceil().clamp(1, sourceSize);
}

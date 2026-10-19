import 'dart:ui';

import 'camera_preferences.dart';

Rect photoCrop(Size source, PhotoAspect aspect) {
  final ratio = source.width >= source.height
      ? aspect.landscapeRatio
      : 1 / aspect.landscapeRatio;
  final width = (source.height * ratio).clamp(1.0, source.width);
  final height = (source.width / ratio).clamp(1.0, source.height);
  return Rect.fromCenter(
    center: source.center(Offset.zero),
    width: width,
    height: height,
  );
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';

import 'altimeter_reading.dart';
import 'camera_preferences.dart';
import 'photo_geometry.dart';

Uint8List encodeJpeg(Uint8List png) {
  final decoded = image.decodePng(png);
  if (decoded == null) throw const FormatException('照片解码失败');
  return image.encodeJpg(decoded, quality: 92);
}

Future<ui.Image>? _logoFuture;
Future<ui.Image> loadWatermarkLogo() => _logoFuture ??= () async {
  final data = await rootBundle.load(
    'assets/branding/generated/altivex-logo-white-512.png',
  );
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}();

class WatermarkOverlay extends StatelessWidget {
  const WatermarkOverlay(
    this.reading, {
    super.key,
    this.enabled = true,
    this.style = WatermarkStyle.classic,
  });
  final AltimeterReading reading;
  final bool enabled;
  final WatermarkStyle style;
  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: loadWatermarkLogo(),
    builder: (context, snapshot) => CustomPaint(
      painter: PhotoWatermarkPainter(
        reading,
        enabled: enabled,
        style: style,
        logo: snapshot.data,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

/// Used by both the viewfinder and the encoded photo, in image coordinates.
class PhotoWatermarkPainter extends CustomPainter {
  PhotoWatermarkPainter(
    this.snapshot, {
    this.topWatermark = true,
    this.enabled = true,
    this.style = WatermarkStyle.classic,
    this.logo,
    this.onPaintBounds,
  });

  final AltimeterReading snapshot;
  final bool topWatermark;
  final bool enabled;
  final WatermarkStyle style;
  final ui.Image? logo;
  final ValueChanged<Rect>? onPaintBounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final font = size.shortestSide / 32;
    final inset = size.shortestSide * .035;
    final style = TextStyle(
      color: Colors.white,
      fontSize: font,
      height: 1.4,
      shadows: [
        Shadow(
          color: Colors.black,
          blurRadius: font / 5,
          offset: Offset(font / 15, font / 15),
        ),
      ],
    );
    void draw(
      String text, {
      required bool top,
      required bool right,
      double scale = 1,
      bool fullWidth = false,
    }) {
      final painter =
          TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: font * scale),
            ),
            textDirection: TextDirection.ltr,
            textAlign: right ? TextAlign.right : TextAlign.left,
            textScaler: TextScaler.noScaling,
          )..layout(
            maxWidth: fullWidth
                ? size.width - inset * 2
                : size.width / 2 - inset * 1.5,
          );
      try {
        final position = Offset(
          right ? size.width - inset - painter.width : inset,
          top ? inset : size.height - inset - painter.height,
        );
        onPaintBounds?.call((position & painter.size).inflate(font * .5));
        painter.paint(canvas, position);
      } finally {
        painter.dispose();
      }
    }

    final altitude =
        '${snapshot.altitudeText(false)}${snapshot.isDemo ? ' · 模拟' : ''}';
    if (topWatermark) {
      final mark = logo;
      final logoWidth = font * 1.8;
      final logoHeight = mark == null
          ? 0.0
          : logoWidth * mark.height / mark.width;
      if (mark != null) {
        final rect = Rect.fromLTWH(
          inset,
          inset + (font * 1.4 - logoHeight) / 2,
          logoWidth,
          logoHeight,
        );
        final source = Rect.fromLTWH(
          0,
          0,
          mark.width.toDouble(),
          mark.height.toDouble(),
        );
        onPaintBounds?.call(rect.inflate(font * .5));
        canvas.save();
        canvas.translate(font / 15, font / 15);
        canvas.drawImageRect(
          mark,
          source,
          rect,
          Paint()
            ..colorFilter = const ColorFilter.mode(
              Colors.black87,
              BlendMode.srcIn,
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, font / 8),
        );
        canvas.restore();
        canvas.drawImageRect(
          mark,
          source,
          rect,
          Paint()..filterQuality = FilterQuality.high,
        );
      }
      final title =
          TextPainter(
            text: TextSpan(text: 'Altivex 高度计', style: style),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
          )..layout(
            maxWidth:
                size.width / 2 -
                inset * 2 -
                (mark == null ? 0 : logoWidth + font * .35),
          );
      title.paint(
        canvas,
        Offset(inset + (mark == null ? 0 : logoWidth + font * .35), inset),
      );
      onPaintBounds?.call(
        (Offset(inset + (mark == null ? 0 : logoWidth + font * .35), inset) &
                title.size)
            .inflate(font * .5),
      );
      title.dispose();
    }
    switch (this.style) {
      case WatermarkStyle.bottomBar:
        onPaintBounds?.call(
          Rect.fromLTWH(
            0,
            size.height - font * 7.6 - inset * 2,
            size.width,
            font * 7.6 + inset * 2,
          ),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            size.height - font * 7.6 - inset * 2,
            size.width,
            font * 7.6 + inset * 2,
          ),
          Paint()..color = Colors.black54,
        );
        draw(
          '$altitude\n${snapshot.latitude}  ${snapshot.longitude}\n'
          '${snapshot.pressureText}\n${snapshot.capturedAt.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
          top: false,
          right: false,
          fullWidth: true,
        );
        return;
      case WatermarkStyle.minimal:
        draw(altitude, top: false, right: false, scale: 1.2);
        return;
      case WatermarkStyle.instrument:
        draw('ALT  $altitude', top: false, right: false, scale: 1.15);
        draw(
          '${snapshot.pressureText}\n${snapshot.latitude}\n${snapshot.longitude}',
          top: false,
          right: true,
        );
        return;
      case WatermarkStyle.classic:
        break;
    }
    if (topWatermark) {
      draw(snapshot.pressureText, top: true, right: true);
    }
    draw(
      '海拔 ${snapshot.altitudeText(false)}${snapshot.isDemo ? ' · 模拟' : ''}',
      top: false,
      right: false,
    );
    draw(
      '${snapshot.latitude}\n${snapshot.longitude}',
      top: false,
      right: true,
    );
  }

  @override
  bool shouldRepaint(PhotoWatermarkPainter oldDelegate) =>
      snapshot != oldDelegate.snapshot ||
      logo != oldDelegate.logo ||
      enabled != oldDelegate.enabled ||
      style != oldDelegate.style ||
      topWatermark != oldDelegate.topWatermark;
}

/// Renders text into decoded photo pixels; the returned PNG is not a UI overlay.
class PhotoWatermark {
  static const _androidImage = MethodChannel('altivex/image');

  Future<File> _createAndroidJpeg(
    String originalPath,
    File destination,
    AltimeterReading snapshot, {
    required bool enabled,
    required bool topWatermark,
    required WatermarkStyle style,
    PhotoAspect? aspect,
    ValueChanged<String>? onStage,
  }) async {
    final info = await _androidImage.invokeMapMethod<String, dynamic>(
      'photoInfo',
      {'path': originalPath},
    );
    if (info == null) throw StateError('无法读取照片尺寸');
    final source = Size(
      (info['width'] as num).toDouble(),
      (info['height'] as num).toDouble(),
    );
    final crop = aspect == null
        ? Offset.zero & source
        : photoCrop(source, aspect);
    final size = Size(crop.width.roundToDouble(), crop.height.roundToDouble());
    onStage?.call('read_image_info');
    final tiles = <Map<String, Object>>[];
    if (enabled) {
      final logo = topWatermark ? await loadWatermarkLogo() : null;
      final recorder = ui.PictureRecorder();
      final bounds = <Rect>[];
      PhotoWatermarkPainter(
        snapshot,
        enabled: enabled,
        topWatermark: topWatermark,
        style: style,
        logo: logo,
        onPaintBounds: bounds.add,
      ).paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      try {
        final regions = <Rect>[];
        for (final bound in bounds) {
          var region = Rect.fromLTRB(
            bound.left.floorToDouble(),
            bound.top.floorToDouble(),
            bound.right.ceilToDouble(),
            bound.bottom.ceilToDouble(),
          ).intersect(Offset.zero & size);
          if (region.isEmpty) continue;
          // Merge overlaps so translucent pixels are composited exactly once.
          for (var index = 0; index < regions.length;) {
            if (region.inflate(1).overlaps(regions[index])) {
              region = region.expandToInclude(regions.removeAt(index));
              index = 0;
            } else {
              index++;
            }
          }
          regions.add(region);
        }
        for (final region in regions) {
          final tileRecorder = ui.PictureRecorder();
          Canvas(tileRecorder)
            ..translate(-region.left, -region.top)
            ..drawPicture(picture);
          final tilePicture = tileRecorder.endRecording();
          ui.Image? tile;
          try {
            tile = await tilePicture.toImage(
              region.width.toInt(),
              region.height.toInt(),
            );
            final data = await tile.toByteData(format: ui.ImageByteFormat.png);
            if (data == null) throw StateError('水印编码失败');
            tiles.add({
              'left': region.left.toInt(),
              'top': region.top.toInt(),
              'bytes': data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              ),
            });
          } finally {
            tile?.dispose();
            tilePicture.dispose();
          }
        }
      } finally {
        picture.dispose();
      }
    }
    onStage?.call('draw_overlay');
    await _androidImage.invokeMethod<void>('composeJpeg', {
      'path': originalPath,
      'destination': destination.path,
      'crop': [crop.left, crop.top, crop.right, crop.bottom],
      'tiles': tiles,
    });
    if (!await destination.exists()) throw StateError('照片输出失败');
    onStage?.call('compose_and_write_jpeg');
    return destination;
  }

  Future<Uint8List> render(
    Uint8List bytes,
    AltimeterReading snapshot, {
    bool topWatermark = true,
    bool enabled = true,
    WatermarkStyle style = WatermarkStyle.classic,
    PhotoAspect? aspect,
    PhotoFormat format = PhotoFormat.png,
    ValueChanged<String>? onStage,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    ui.Image? input, output;
    ui.Picture? picture;
    try {
      input = (await codec.getNextFrame()).image;
      onStage?.call('decode_image');
      final crop = aspect == null
          ? Rect.fromLTWH(0, 0, input.width.toDouble(), input.height.toDouble())
          : photoCrop(
              Size(input.width.toDouble(), input.height.toDouble()),
              aspect,
            );
      final width = crop.width.roundToDouble(),
          height = crop.height.roundToDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawImageRect(
          input,
          crop,
          Rect.fromLTWH(0, 0, width, height),
          Paint(),
        );
      PhotoWatermarkPainter(
        snapshot,
        topWatermark: topWatermark,
        enabled: enabled,
        style: style,
        logo: enabled && topWatermark ? await loadWatermarkLogo() : null,
      ).paint(canvas, Size(width, height));
      picture = recorder.endRecording();
      output = await picture.toImage(width.toInt(), height.toInt());
      onStage?.call('draw_watermark');
      // Release decoded source/picture before allocating the export pixels.
      picture.dispose();
      picture = null;
      input.dispose();
      input = null;
      if (format == PhotoFormat.jpeg &&
          defaultTargetPlatform == TargetPlatform.android) {
        final rgba = await output.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (rgba == null) throw StateError('照片像素读取失败');
        onStage?.call('read_pixels');
        try {
          final jpeg = await const MethodChannel('altivex/image')
              .invokeMethod<Uint8List>('encodeJpeg', {
                'rgba': rgba.buffer.asUint8List(
                  rgba.offsetInBytes,
                  rgba.lengthInBytes,
                ),
                'width': width.toInt(),
                'height': height.toInt(),
              });
          if (jpeg == null) throw StateError('照片编码失败');
          onStage?.call('encode_jpeg');
          return jpeg;
        } on MissingPluginException {
          // Other platforms and tests retain the portable encoder below.
        }
      }
      final encoded = await output.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) throw StateError('照片编码失败');
      final png = encoded.buffer.asUint8List();
      onStage?.call('encode_png');
      return format == PhotoFormat.jpeg ? await compute(encodeJpeg, png) : png;
    } finally {
      output?.dispose();
      input?.dispose();
      picture?.dispose();
      codec.dispose();
    }
  }

  Future<File> create(
    String originalPath,
    AltimeterReading snapshot, {
    bool topWatermark = true,
    bool enabled = true,
    WatermarkStyle style = WatermarkStyle.classic,
    PhotoAspect? aspect,
    PhotoFormat format = PhotoFormat.png,
    File? destination,
    ValueChanged<String>? onStage,
  }) async {
    File file;
    if (destination != null) {
      file = destination;
    } else {
      final directory = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/Altivex',
      );
      await directory.create(recursive: true);
      file = File(
        '${directory.path}/Altivex_${snapshot.capturedAt.microsecondsSinceEpoch}.${format == PhotoFormat.jpeg ? 'jpg' : 'png'}',
      );
    }
    if (format == PhotoFormat.jpeg &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await _createAndroidJpeg(
          originalPath,
          file,
          snapshot,
          enabled: enabled,
          topWatermark: topWatermark,
          style: style,
          aspect: aspect,
          onStage: onStage,
        );
      } on MissingPluginException {
        // Retain the portable path when the Android adapter is unavailable.
      }
    }
    final originalBytes = await File(originalPath).readAsBytes();
    onStage?.call('read_original');
    final bytes = await render(
      originalBytes,
      snapshot,
      topWatermark: topWatermark,
      enabled: enabled,
      style: style,
      aspect: aspect,
      format: format,
      onStage: onStage,
    );
    await file.writeAsBytes(bytes, flush: true);
    onStage?.call('write_photo');
    return file;
  }
}

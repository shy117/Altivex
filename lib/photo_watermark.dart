import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'altimeter_reading.dart';

/// Used by both the viewfinder and the encoded photo, in image coordinates.
class PhotoWatermarkPainter extends CustomPainter {
  PhotoWatermarkPainter(this.snapshot, {this.topWatermark = true});

  final AltimeterReading snapshot;
  final bool topWatermark;

  @override
  void paint(Canvas canvas, Size size) {
    final font = (size.shortestSide / 32).clamp(1.0, 72.0);
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
    void draw(String text, {required bool top, required bool right}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: right ? TextAlign.right : TextAlign.left,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: size.width / 2 - inset * 1.5);
      try {
        painter.paint(
          canvas,
          Offset(
            right ? size.width - inset - painter.width : inset,
            top ? inset : size.height - inset - painter.height,
          ),
        );
      } finally {
        painter.dispose();
      }
    }

    if (topWatermark) {
      draw('实时高度表', top: true, right: false);
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
      topWatermark != oldDelegate.topWatermark;
}

/// Renders text into decoded photo pixels; the returned PNG is not a UI overlay.
class PhotoWatermark {
  Future<Uint8List> render(
    Uint8List bytes,
    AltimeterReading snapshot, {
    bool topWatermark = true,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    ui.Image? input, output;
    ui.Picture? picture;
    try {
      input = (await codec.getNextFrame()).image;
      final width = input.width.toDouble(), height = input.height.toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawImage(input, Offset.zero, Paint());
      PhotoWatermarkPainter(
        snapshot,
        topWatermark: topWatermark,
      ).paint(canvas, Size(width, height));
      picture = recorder.endRecording();
      output = await picture.toImage(input.width, input.height);
      final encoded = await output.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) throw StateError('照片编码失败');
      return encoded.buffer.asUint8List();
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
  }) async {
    final bytes = await render(
      await File(originalPath).readAsBytes(),
      snapshot,
      topWatermark: topWatermark,
    );
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/Altivex',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/Altivex_${snapshot.capturedAt.microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

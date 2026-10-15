import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/altimeter_reading.dart';
import 'package:altivex/photo_watermark.dart';

void main() {
  testWidgets(
    'Landscape photo retains orientation and matches viewfinder watermark',
    (tester) async {
      await tester.runAsync(() async {
        const size = Size(1000, 600);
        final snapshot = AltimeterReading(
          capturedAt: DateTime.utc(2026, 10, 15),
          altitudeMeters: 3628,
          pressureHpa: 800,
          latitudeDegrees: 39.8,
          longitudeDegrees: -122.4,
        );
        Future<ui.Image> draw({required bool watermark}) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..drawColor(const Color(0xFF102030), BlendMode.src);
          if (watermark) PhotoWatermarkPainter(snapshot).paint(canvas, size);
          final picture = recorder.endRecording();
          try {
            return await picture.toImage(1000, 600);
          } finally {
            picture.dispose();
          }
        }

        final original = await draw(watermark: false);
        final expected = await draw(watermark: true);
        final bytes = (await original.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final encoded = await PhotoWatermark().render(bytes, snapshot);
        final codec = await ui.instantiateImageCodec(encoded);
        final actual = (await codec.getNextFrame()).image;
        expect(actual.width, 1000);
        expect(actual.height, 600);
        final actualPixels = (await actual.toByteData())!.buffer.asUint8List();
        final expectedPixels = (await expected.toByteData())!.buffer
            .asUint8List();
        expect(actualPixels, expectedPixels);
        for (final corner in [
          const Rect.fromLTWH(0, 0, 500, 100),
          const Rect.fromLTWH(500, 0, 500, 100),
          const Rect.fromLTWH(0, 500, 500, 100),
          const Rect.fromLTWH(500, 500, 500, 100),
        ]) {
          var whitePixels = 0;
          for (var y = corner.top.toInt(); y < corner.bottom; y++) {
            for (var x = corner.left.toInt(); x < corner.right; x++) {
              final index = (y * 1000 + x) * 4;
              if (actualPixels[index] > 220 &&
                  actualPixels[index + 1] > 220 &&
                  actualPixels[index + 2] > 220) {
                whitePixels++;
              }
            }
          }
          expect(
            whitePixels,
            greaterThan(20),
            reason: 'Watermark missing at $corner',
          );
        }
        actual.dispose();
        expected.dispose();
        original.dispose();
        codec.dispose();
      });
    },
  );
  testWidgets(
    'Saved PNG contains permanent white watermark pixels from frozen snapshot',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFF102030), BlendMode.src);
        final picture = recorder.endRecording();
        final original = await picture.toImage(800, 1000);
        final sourceBytes = (await original.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final snapshot = AltimeterReading(
          capturedAt: DateTime.utc(2026, 10, 15),
          altitudeMeters: 3628,
          pressureHpa: 800,
          latitudeDegrees: 39.8,
          longitudeDegrees: -122.4,
          altitudeSource: 'GPS高度',
        );
        final Uint8List encoded = await PhotoWatermark().render(
          sourceBytes,
          snapshot,
        );
        final codec = await ui.instantiateImageCodec(encoded);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 800);
        expect(image.height, 1000);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var whiteBottomPixels = 0;
        for (var y = 700; y < 990; y++) {
          for (var x = 20; x < 780; x++) {
            final index = (y * 800 + x) * 4;
            if (pixels[index] > 220 &&
                pixels[index + 1] > 220 &&
                pixels[index + 2] > 220) {
              whiteBottomPixels++;
            }
          }
        }
        expect(whiteBottomPixels, greaterThan(100));
        final center = (500 * 800 + 400) * 4;
        expect(pixels.sublist(center, center + 3), [16, 32, 48]);
        codec.dispose();
        image.dispose();
        original.dispose();
        picture.dispose();
      });
    },
  );
}

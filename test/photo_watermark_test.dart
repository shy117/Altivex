import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/altimeter_reading.dart';
import 'package:altivex/photo_watermark.dart';
import 'package:altivex/camera_preferences.dart';
import 'package:image/image.dart' as image;

import 'dart:convert';
import 'dart:io';

void main() {
  testWidgets(
    'Android file composition sends only transparent watermark and exact crop',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final directory = Directory.systemTemp.createTempSync(
        'altivex-composite-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final output = File('${directory.path}/Altivex_100.jpg');
      const channel = MethodChannel('altivex/image');
      final methods = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        methods.add(call.method);
        if (call.method == 'photoInfo') return {'width': 300, 'height': 400};
        expect(call.method, 'composeJpeg');
        expect(call.arguments['crop'], [37.5, 0.0, 262.5, 400.0]);
        expect(call.arguments.containsKey('rgba'), false);
        final overlay = image.Image(width: 225, height: 400, numChannels: 4);
        var tilePixels = 0;
        for (final tile in call.arguments['tiles'] as List) {
          final bitmap = image.decodePng(tile['bytes'] as Uint8List)!;
          tilePixels += bitmap.width * bitmap.height;
          image.compositeImage(
            overlay,
            bitmap,
            dstX: tile['left'] as int,
            dstY: tile['top'] as int,
          );
        }
        expect(tilePixels, lessThan(225 * 400 * .4));
        expect(overlay.getPixel(110, 200).a, 0);
        expect(overlay.getPixel(10, 14).a, greaterThan(0));
        await output.writeAsBytes([255, 216, 255, 217]);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.runAsync(() async {
        final file = await PhotoWatermark().create(
          'native-only-original.jpg',
          AltimeterReading(capturedAt: DateTime(2026)),
          destination: output,
          format: PhotoFormat.jpeg,
          aspect: PhotoAspect.wide,
        );
        expect(file.path, output.path);
        expect(methods, ['photoInfo', 'composeJpeg']);
      });
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('Watermark title keeps the same relative size at 3000x4000', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final reading = AltimeterReading(
        capturedAt: DateTime(2026),
        altitudeMeters: 3628,
      );
      final logo = await loadWatermarkLogo();
      Future<Rect> titleBounds(int width, int height) async {
        final recorder = ui.PictureRecorder();
        PhotoWatermarkPainter(
          reading,
          logo: logo,
        ).paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
        final picture = recorder.endRecording();
        final output = await picture.toImage(width, height);
        try {
          final data = (await output.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var left = width, right = 0, top = height, bottom = 0;
          for (var y = 0; y < height ~/ 8; y++) {
            for (var x = 0; x < width ~/ 2; x++) {
              final offset = (y * width + x) * 4;
              if (data.getUint8(offset) > 200 &&
                  data.getUint8(offset + 1) > 200 &&
                  data.getUint8(offset + 2) > 200) {
                if (x < left) left = x;
                if (x > right) right = x;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
              }
            }
          }
          return Rect.fromLTRB(
            left / width,
            top / height,
            (right + 1) / width,
            (bottom + 1) / height,
          );
        } finally {
          output.dispose();
          picture.dispose();
        }
      }

      final preview = await titleBounds(300, 400);
      final photo = await titleBounds(3000, 4000);
      expect(photo.width, closeTo(preview.width, .008));
      expect(photo.height, closeTo(preview.height, .004));
      // Allow two preview pixels for rasterization at the small size.
      expect(photo.left, closeTo(preview.left, .007));
    });
  });
  testWidgets(
    'Android JPEG encoder receives full-size RGBA instead of intermediate PNG',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('altivex/image');
      MethodCall? call;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        value,
      ) async {
        call = value;
        return Uint8List.fromList([255, 216, 255, 217]);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.runAsync(() async {
        final input = image.encodePng(
          image.Image(width: 300, height: 400)
            ..clear(image.ColorRgb8(250, 20, 60)),
        );
        final result = await PhotoWatermark().render(
          input,
          AltimeterReading(capturedAt: DateTime(2026)),
          enabled: false,
          format: PhotoFormat.jpeg,
        );
        expect(result.take(2), [255, 216]);
        expect(call!.method, 'encodeJpeg');
        expect(call!.arguments['width'], 300);
        expect(call!.arguments['height'], 400);
        final pixels = call!.arguments['rgba'] as Uint8List;
        expect(pixels.length, 300 * 400 * 4);
        expect(pixels.take(4), [250, 20, 60, 255]);
      });
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'Templates are distinct, watermark can be fully disabled and JPEG uses selected crop',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFF102030), BlendMode.src);
        final picture = recorder.endRecording();
        final original = await picture.toImage(600, 800);
        final bytes = (await original.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final snapshot = AltimeterReading(
          capturedAt: DateTime(2026, 10, 16),
          altitudeMeters: 3628,
          latitudeDegrees: 39.8,
          longitudeDegrees: -122.4,
          pressureHpa: 800,
        );
        final outputs = <String>{};
        for (final style in WatermarkStyle.values) {
          final result = await PhotoWatermark().render(
            bytes,
            snapshot,
            style: style,
          );
          outputs.add(base64Encode(result));
        }
        expect(outputs.length, 4);
        final clean = await PhotoWatermark().render(
          bytes,
          snapshot,
          enabled: false,
        );
        final decoded = image.decodePng(clean)!;
        expect(decoded.getPixel(20, 20).r, 16);
        expect(decoded.getPixel(20, 780).g, 32);
        final jpeg = await PhotoWatermark().render(
          bytes,
          snapshot,
          format: PhotoFormat.jpeg,
          aspect: PhotoAspect.wide,
        );
        expect(jpeg.take(2), [255, 216]);
        final jpg = image.decodeJpg(jpeg)!;
        expect(jpg.width, 450);
        expect(jpg.height, 800);
        expect(jpeg.length, lessThan(150000));
        original.dispose();
        picture.dispose();
      });
    },
  );
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
          if (watermark) {
            PhotoWatermarkPainter(
              snapshot,
              logo: await loadWatermarkLogo(),
            ).paint(canvas, size);
          }
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

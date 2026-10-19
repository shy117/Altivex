import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/camera_preferences.dart';
import 'package:altivex/photo_store.dart';
import 'package:altivex/photo_geometry.dart';

import 'dart:ui';

void main() {
  test('Preferences validate unknown values and retain confirmed defaults', () {
    final defaults = CameraPreferences.fromJson({
      'timerSeconds': 8,
      'format': 'other',
      'style': 'future',
    });
    expect(defaults.autoSave, false);
    expect(
      CameraPreferences.fromJson({'keepOriginal': true})
          .toJson()
          .containsKey('keepOriginal'),
      false,
    );
    expect(defaults.timerSeconds, 0);
    expect(defaults.format, PhotoFormat.jpeg);
    expect(defaults.aspect, PhotoAspect.fourThree);
    expect(defaults.style, WatermarkStyle.classic);
    final changed = defaults.copyWith(
      autoSave: true,
      timerSeconds: 3,
      style: WatermarkStyle.minimal,
      aspect: PhotoAspect.square,
    );
    expect(
      CameraPreferences.fromJson(changed.toJson()).toJson(),
      changed.toJson(),
    );
  });

  test(
    'Crops are centered and preserve portrait, landscape and square ratios',
    () {
      for (final size in [const Size(1280, 720), const Size(720, 1280)]) {
        for (final aspect in PhotoAspect.values) {
          final crop = photoCrop(size, aspect);
          expect(crop.center, size.center(Offset.zero));
          expect(
            crop.width / crop.height,
            closeTo(
              size.width > size.height
                  ? aspect.landscapeRatio
                  : 1 / aspect.landscapeRatio,
              .001,
            ),
          );
          expect(crop.left, greaterThanOrEqualTo(0));
          expect(crop.top, greaterThanOrEqualTo(0));
        }
      }
    },
  );

  test('Photo records, saved URIs and preferences survive restart without reading other albums', () async {
    final directory = await Directory.systemTemp.createTemp('altivex-store-');
    addTearDown(() => directory.delete(recursive: true));
    final outside = await File('${directory.path}/unrelated.jpg')
        .writeAsString('leave intact');
    final store = PhotoStore(directory: () async => directory);
    await store.load();
    await store.file('Altivex_100.jpg').writeAsString('processed');
    await store.file('Altivex_100_original.jpg').writeAsString('raw');
    final record = PhotoRecord(
      id: '100',
      createdAt: DateTime(2026, 10, 16),
      photoName: 'Altivex_100.jpg',
      originalName: 'Altivex_100_original.jpg',
      saved: true,
      photoUri: 'content://media/external/images/media/10',
    );
    await store.put(record);
    await store.savePreferences(
      const CameraPreferences(autoSave: true, grid: true),
    );
    await store.savePreferences(
      const CameraPreferences(autoSave: true, grid: true, timerSeconds: 10),
    );
    final restarted = PhotoStore(directory: () async => directory);
    await restarted.load();
    expect(restarted.records.single.photoUri, record.photoUri);
    expect(restarted.records.single.saved, true);
    expect(restarted.preferences.timerSeconds, 10);
    await restarted.remove(restarted.records.single);
    expect(await outside.readAsString(), 'leave intact');
    expect(await store.file('Altivex_100.jpg').exists(), false);
    await store.load();
    expect(store.records, isEmpty);
  });

  test('Failed processing retains the raw photo record and corrupt metadata is isolated', () async {
    final directory = await Directory.systemTemp.createTemp(
      'altivex-recovery-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = PhotoStore(directory: () async => directory);
    await store.load();
    await store.file('Altivex_101_original.jpg').writeAsString('raw');
    await store.put(
      PhotoRecord(
        id: '101',
        createdAt: DateTime(2026),
        originalName: 'Altivex_101_original.jpg',
        processingFailed: true,
      ),
    );
    await File('${store.root.path}/102.json').writeAsString('{broken');
    await File('${store.root.path}/settings.json').writeAsString('{broken');
    await store.load();
    expect(store.records.single.processingFailed, true);
    expect(store.preferences.autoSave, false);
    expect(() => store.file('../unrelated.jpg'), throwsFormatException);
    expect(
      () => PhotoRecord.fromJson({'id': '../escape'}),
      throwsFormatException,
    );
    expect(
      () => PhotoRecord.fromJson({
        'id': '101',
        'createdAt': '2026-10-16',
        'photoName': '../escape.jpg',
      }),
      throwsFormatException,
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:altivex/altimeter_reading.dart';
import 'package:altivex/camera_preferences.dart';
import 'package:altivex/camera_settings_sheet.dart';
import 'package:altivex/photo_history_page.dart';
import 'package:altivex/photo_store.dart';
import 'package:altivex/photo_gallery.dart';
import 'package:altivex/photo_preview_page.dart';

class HistoryStore extends PhotoStore {
  HistoryStore(this.photo, this.items);
  final File photo;
  final List<PhotoRecord> items;
  @override
  List<PhotoRecord> get records => List.unmodifiable(items);
  @override
  File file(String name) => photo;
  @override
  Future<void> remove(PhotoRecord value) async {
    items.remove(value);
  }
}

class FakeGallery extends PhotoGallery {
  final List<String> deleted = [];
  @override
  bool get canDeleteSavedCopies => true;
  @override
  Future<void> deleteSavedCopies(List<String> uris) async {
    deleted.addAll(uris);
  }
}

void main() {
  testWidgets(
    'Settings header stays fixed and downward header drag dismisses',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  enableDrag: false,
                  builder: (_) => CameraSettingsSheet(
                    preferences: const CameraPreferences(),
                    reading: AltimeterReading(capturedAt: DateTime(2026)),
                    onChanged: (_) async {},
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      const header = ValueKey('camera-settings-header');
      final position = tester.getTopLeft(find.byKey(header));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(header)), position);
      expect(find.text('同时保存原图'), findsNothing);
      await tester.drag(find.byKey(header), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(find.text('相机设置'), findsNothing);
    },
  );

  testWidgets(
    'History viewer swipes photos and saves the currently displayed record',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('altivex-browser-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final photo = File('${directory.path}/photo.jpg')
        ..writeAsBytesSync(image.encodeJpg(image.Image(width: 16, height: 16)));
      final records = [
        for (var id = 1; id <= 3; id++)
          PhotoRecord(
            id: '$id',
            createdAt: DateTime(2026),
            photoName: 'Altivex_$id.jpg',
          ),
      ];
      String? savedId;
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoBrowserPage(
            records: records,
            initialId: '2',
            store: HistoryStore(photo, records),
            savePhoto: (record) async {
              savedId = record.id;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('照片预览 · 2/3'), findsOneWidget);
      final viewer = find.byType(InteractiveViewer).hitTestable();
      final center = tester.getCenter(viewer);
      final left = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var step = 1; step <= 5; step++) {
        await right.moveTo(center + Offset(40 + step * 28, 0));
        await tester.pump();
      }
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      final transform = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1.5));
      // Pinch back to normal size before swiping to another photo.
      final shrinkLeft = await tester.startGesture(
        center - const Offset(120, 0),
        pointer: 1,
      );
      final shrinkRight = await tester.startGesture(
        center + const Offset(120, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var step = 1; step <= 5; step++) {
        await shrinkLeft.moveTo(center - Offset(120 - step * 22, 0));
        await shrinkRight.moveTo(center + Offset(120 - step * 22, 0));
        await tester.pump();
      }
      await shrinkLeft.up();
      await shrinkRight.up();
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), closeTo(1, .01));
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('照片预览 · 3/3'), findsOneWidget);
      await tester.tap(find.text('保存相册').last);
      await tester.pumpAndSettle();
      expect(savedId, '3');
      await tester.drag(find.byType(PageView), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('照片预览 · 2/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Wide portrait preview fills width even with limited height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const previewKey = ValueKey('wide-preview');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CameraCaptureLayout(
            fullWidthPreview: true,
            header: [Icon(Icons.arrow_back), Icon(Icons.settings)],
            viewfinder: ColoredBox(key: previewKey, color: Colors.blue),
            actions: [
              Icon(Icons.photo),
              Icon(Icons.circle),
              Icon(Icons.cameraswitch),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(previewKey)).width, 390);
    expect(
      tester.getSize(find.byKey(previewKey)).height,
      closeTo(390 * 16 / 9, .01),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Settings expose confirmed defaults and persist each chosen value',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CameraPreferences? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraSettingsSheet(
              preferences: const CameraPreferences(),
              reading: AltimeterReading(capturedAt: DateTime(2026)),
              onChanged: (value) async {
                saved = value;
              },
            ),
          ),
        ),
      );
      expect(find.text('JPEG'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '自动保存'))
            .value,
        false,
      );
      await tester.tap(find.text('自动保存'));
      await tester.pumpAndSettle();
      expect(saved!.autoSave, true);
      await tester.scrollUntilVisible(find.text('水印样式'), 150);
      await tester.tap(find.text('水印样式'));
      await tester.pumpAndSettle();
      expect(find.text('极简海拔'), findsOneWidget);
      await tester.tap(find.text('极简海拔'));
      await tester.pumpAndSettle();
      expect(saved!.style, WatermarkStyle.minimal);
      expect(saved!.autoSave, true);
      expect(find.text('显示水印'), findsNothing);
    },
  );

  for (final deleteCopies in [false, true]) {
    testWidgets(
      'History deletion only deletes gallery copies when checked: $deleteCopies',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'altivex-history-',
        );
        final photo = File('${directory.path}/photo.jpg')
          ..writeAsBytesSync(
            image.encodeJpg(image.Image(width: 16, height: 16)),
          );
        addTearDown(() => directory.deleteSync(recursive: true));
        final record = PhotoRecord(
          id: '100',
          createdAt: DateTime(2026),
          photoName: 'Altivex_100.jpg',
          saved: true,
          photoUri: 'content://media/external/images/media/100',
        );
        final store = HistoryStore(photo, [record]);
        final gallery = FakeGallery();
        await tester.pumpWidget(
          MaterialApp(
            home: PhotoHistoryPage(
              store: store,
              gallery: gallery,
              openPhoto: (_) async {},
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byTooltip('删除照片'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          false,
        );
        if (deleteCopies) {
          await tester.tap(find.text('同时删除系统相册副本'));
          await tester.pump();
        }
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(store.records, isEmpty);
        expect(gallery.deleted, deleteCopies ? [record.photoUri] : isEmpty);
        expect(find.text('还没有拍摄记录'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

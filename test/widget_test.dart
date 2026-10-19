import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:altivex/main.dart';
import 'package:altivex/demo_altimeter.dart';
import 'package:altivex/altimeter_controller.dart';
import 'package:altivex/measurement_hardware.dart';
import 'package:altivex/photo_preview_page.dart';
import 'package:altivex/photo_store.dart';
import 'package:altivex/camera_preferences.dart';

import 'support/fake_hardware.dart';

import 'package:altivex/home_preferences.dart';

class MemoryHomeStore extends HomeStore {
  HomePreferences value = const HomePreferences();
  @override
  Future<HomePreferences> load() async => value;
  @override
  Future<void> save(HomePreferences preferences) async {
    value = preferences;
  }

  @override
  Future<File?> backgroundFile(HomePreferences preferences) async => null;
}

class MemoryPhotoStore extends PhotoStore {
  @override
  Future<void> load() async {}
  @override
  Future<void> savePreferences(CameraPreferences value) async {
    preferences = value;
  }
}

void main() {
  testWidgets(
    'Capture controls stay on the device bottom edge in both landscape directions',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final left in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CameraCaptureLayout(
                controlsOnLeft: left,
                header: const [Icon(Icons.arrow_back), Icon(Icons.water_drop)],
                viewfinder: const ColoredBox(color: Colors.black),
                zoom: CameraZoomControls(
                  minZoom: 1,
                  maxZoom: 3.2,
                  zoom: 1,
                  axis: Axis.vertical,
                  reverse: !left,
                  onChanged: (_) {},
                ),
                actions: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.photo)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.circle)),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.cameraswitch),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final photo = tester.getCenter(find.byIcon(Icons.photo));
        final shutter = tester.getCenter(find.byIcon(Icons.circle));
        final camera = tester.getCenter(find.byIcon(Icons.cameraswitch));
        final zoom = tester.getCenter(find.text('1×'));
        expect(photo.dx, shutter.dx);
        expect(camera.dx, shutter.dx);
        if (left) {
          expect(shutter.dx, lessThan(120));
          expect(zoom.dx, greaterThan(shutter.dx));
          expect(photo.dy, lessThan(camera.dy));
        } else {
          expect(shutter.dx, greaterThan(724));
          expect(zoom.dx, lessThan(shutter.dx));
          expect(photo.dy, greaterThan(camera.dy));
        }
      }
    },
  );

  testWidgets('Portrait home keeps the dial and coordinates in the viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = DemoAltimeter();
    addTearDown(source.dispose);
    for (final size in [
      const Size(390, 844),
      const Size(320, 640),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        AltivexApp(source: source, homeStore: MemoryHomeStore()),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final altitude = tester.getRect(find.text('3628 米', findRichText: true));
      final latitude = tester.getRect(find.text(source.reading.latitude));
      final longitude = tester.getRect(find.text(source.reading.longitude));
      for (final rect in [altitude, latitude, longitude]) {
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Zoom buttons expose supported stops and the live pinch value', (
    tester,
  ) async {
    double? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraZoomControls(
            minZoom: 1,
            maxZoom: 2.5,
            zoom: 1.7,
            onChanged: (value) => chosen = value,
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsNothing);
    expect(find.text('1×'), findsOneWidget);
    expect(find.text('1.7×'), findsOneWidget);
    expect(find.text('3×'), findsNothing);
    expect(find.text('0.6×'), findsNothing);
    expect(find.text('3.2×'), findsNothing);
    await tester.tap(find.text('1.7×'));
    expect(chosen, 2);
    await tester.tap(find.text('1×'));
    expect(chosen, 1);
  });

  testWidgets(
    'Photo preview saves only on confirmation and prevents duplicates',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('altivex-preview-');
      final photo = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.black, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(10, 10);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return File('${directory.path}/photo.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      }))!;
      addTearDown(() => directory.delete(recursive: true));
      var calls = 0;
      final saving = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: CapturedPhotoPage(
            photo: photo,
            savePhoto: () {
              calls++;
              return saving.future;
            },
          ),
        ),
      );
      await tester.pump();
      expect(calls, 0);
      expect(find.textContaining('永久水印'), findsNothing);
      expect(find.text('返回拍摄'), findsNothing);
      expect(find.byTooltip('返回'), findsOneWidget);
      expect(find.byTooltip('分享'), findsOneWidget);
      expect(
        tester.getCenter(find.byTooltip('分享')).dy,
        lessThan(tester.getCenter(find.text('保存相册')).dy),
      );
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('保存相册'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('保存中…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '保存中…'))
            .onPressed,
        isNull,
      );
      saving.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('已保存'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '已保存'))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Home dashboard and persistent unit settings remain available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = DemoAltimeter();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      AltivexApp(source: source, homeStore: MemoryHomeStore()),
    );
    await tester.pump();
    expect(find.text('3628 米', findRichText: true), findsOneWidget);
    expect(find.text('Altivex'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英尺 ft'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ft', findRichText: true), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Live unavailable state shows no invented altitude or coordinates',
    (tester) async {
      final hardware = FakeHardware()
        ..permission = LocationAccess.deniedForever;
      final source = AltimeterController(hardware: hardware);
      addTearDown(() async {
        source.dispose();
        await hardware.close();
      });
      await tester.pumpWidget(
        AltivexApp(source: source, homeStore: MemoryHomeStore()),
      );
      await tester.pump();
      hardware.pressures.addError(UnsupportedError('missing'));
      hardware.headings.add(null);
      await tester.pump();
      expect(find.text('-- 米', findRichText: true), findsOneWidget);
      expect(find.text('纬度不可用'), findsOneWidget);
      expect(find.textContaining('模拟数据'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('No camera displays an explicit state and disables shutter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = DemoAltimeter();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoPreviewPage(
          source: source,
          store: MemoryPhotoStore(),
          requestCameraAccess: () async => true,
          enumerateCameras: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('设备没有可用摄像头'), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '拍照'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('顶部水印'), findsNothing);
    expect(find.text('返回'), findsNothing);
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    final back = tester.getCenter(find.byTooltip('返回'));
    final watermark = tester.getCenter(find.byTooltip('水印开关'));
    final previous = tester.getCenter(find.byTooltip('拍摄记录'));
    final shutter = tester.getCenter(find.byTooltip('拍照'));
    final switchCamera = tester.getCenter(find.byTooltip('切换摄像头'));
    expect(back.dx, lessThan(watermark.dx));
    expect(back.dy, lessThan(shutter.dy));
    expect(previous.dx, lessThan(shutter.dx));
    expect(shutter.dx, lessThan(switchCamera.dx));
    expect(previous.dy, shutter.dy);
    expect(switchCamera.dy, shutter.dy);
    await tester.tap(find.byTooltip('水印开关'));
    await tester.pump();
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Camera permission denial provides retry and settings actions', (
    tester,
  ) async {
    final source = DemoAltimeter();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoPreviewPage(
          source: source,
          requestCameraAccess: () async => true,
          enumerateCameras: () async =>
              throw CameraException('CameraAccessDenied', 'denied'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('打开应用设置'), findsOneWidget);
    expect(find.text('重试相机'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Permission guard prevents CameraX initialization when access is denied',
    (tester) async {
      final source = DemoAltimeter();
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoPreviewPage(
            source: source,
            enumerateCameras: () async => [
              const CameraDescription(
                name: 'test',
                lensDirection: CameraLensDirection.back,
                sensorOrientation: 90,
              ),
            ],
            requestCameraAccess: () async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('相机权限不可用，请在系统设置中允许访问'), findsOneWidget);
      expect(find.text('打开应用设置'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '拍照',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Unresponsive camera discovery exits loading and offers retry', (
    tester,
  ) async {
    final source = DemoAltimeter();
    addTearDown(source.dispose);
    final cameras = Completer<List<CameraDescription>>();
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoPreviewPage(
          source: source,
          requestCameraAccess: () async => true,
          enumerateCameras: () => cameras.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(find.text('相机初始化失败或响应超时，请检查权限后重试'), findsOneWidget);
    expect(find.text('重试相机'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Permission dialog pause and resume never re-enter permission initialization',
    (tester) async {
      final source = DemoAltimeter();
      addTearDown(source.dispose);
      final permission = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoPreviewPage(
            source: source,
            requestCameraAccess: () {
              calls++;
              return permission.future;
            },
            enumerateCameras: () async => [],
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      permission.complete(false);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('相机权限不可用，请在系统设置中允许访问'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

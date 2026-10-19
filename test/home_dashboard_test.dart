import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/main.dart';
import 'package:altivex/demo_altimeter.dart';
import 'package:altivex/home_preferences.dart';
import 'package:altivex/altitude_dial.dart';

class HomeMemoryStore extends HomeStore {
  HomeMemoryStore(this.value);
  HomePreferences value;
  @override
  Future<HomePreferences> load() async => value;
  @override
  Future<void> save(HomePreferences preferences) async {
    value = preferences;
  }

  @override
  Future<File?> backgroundFile(HomePreferences preferences) async => null;
}

void main() {
  testWidgets('Four pages, theme and unit changes preserve settings', (
    tester,
  ) async {
    final source = DemoAltimeter();
    final store = HomeMemoryStore(const HomePreferences());
    addTearDown(source.dispose);
    await tester.pumpWidget(AltivexApp(source: source, homeStore: store));
    await tester.pumpAndSettle();
    expect(find.byTooltip('分享'), findsNothing);
    expect(find.text('当前海拔'), findsNothing);
    for (var page = 2; page <= 4; page++) {
      await tester.tap(find.byTooltip('信息第 $page 页'));
      await tester.pumpAndSettle();
    }
    expect(find.text('定位与测高状态'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色主题'));
    await tester.pumpAndSettle();
    expect(store.value.dark, isTrue);
    await tester.tap(find.text('英尺 ft'));
    await tester.pumpAndSettle();
    expect(store.value.feet, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Portrait home adapts to light/dark, screen sizes and larger text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = DemoAltimeter();
    addTearDown(source.dispose);
    if (const bool.fromEnvironment('CAPTURE_HOME')) {
      await tester.runAsync(() async {
        final bytes = await File(const String.fromEnvironment('REVIEW_FONT'))
            .readAsBytes();
        for (final family in ['Ahem', 'Roboto']) {
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
        final icons = await File(const String.fromEnvironment('REVIEW_ICONS'))
            .readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      });
    }
    var index = 0;
    for (final size in [
      const Size(390, 844),
      const Size(430, 932),
      const Size(320, 568),
    ]) {
      for (final dark in [false, true]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          RepaintBoundary(
            key: ValueKey(index++),
            child: AltivexApp(
              source: source,
              homeStore: HomeMemoryStore(HomePreferences(dark: dark)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<AltitudeDial>(find.byType(AltitudeDial)).dark,
          dark,
        );
        // Optional review artifacts are kept in the ignored build directory.
        if (const bool.fromEnvironment('CAPTURE_HOME')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/home-review').create(recursive: true);
            await File(
              'build/home-review/${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byTooltip('设置'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final header = find.byKey(const Key('home-settings-header'));
        final headerTop = tester.getTopLeft(header).dy;
        if (const bool.fromEnvironment('CAPTURE_HOME')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/home-review/settings-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(
          find.byKey(const Key('home-settings-scroll')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(header).dy, headerTop);
        await tester.drag(header, const Offset(0, 100));
        await tester.pumpAndSettle();
        expect(header, findsNothing);
      }
    }
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AltivexApp(
          source: source,
          homeStore: HomeMemoryStore(const HomePreferences()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/main.dart';
import 'package:altivex/demo_altimeter.dart';
import 'package:altivex/photo_preview_page.dart';

void main() {
  testWidgets('Reference layout, settings and photo snapshot', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const AltivexApp());
    expect(find.text('3628 米'), findsOneWidget);
    expect(find.text('实时高度表'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英尺 ft'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ft'), findsOneWidget);
    await tester.tap(find.byTooltip('拍照'));
    await tester.pumpAndSettle();
    final snapshot = tester
        .widget<PhotoPreviewPage>(find.byType(PhotoPreviewPage))
        .reading;
    await tester.pump(const Duration(seconds: 4));
    expect(
      identical(
        snapshot,
        tester.widget<PhotoPreviewPage>(find.byType(PhotoPreviewPage)).reading,
      ),
      isTrue,
    );
    expect(find.text('第一阶段未接入摄像头'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  test('Reading snapshot remains unchanged as demo advances', () {
    final source = DemoAltimeter();
    final snapshot = source.reading;
    expect(snapshot.altitudeMeters, 3628);
    expect(snapshot.latitude, '北纬 39°47′9″');
    source.dispose();
  });
}

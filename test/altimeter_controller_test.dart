import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/altimeter_controller.dart';
import 'package:altivex/altimeter_reading.dart';
import 'package:altivex/measurement_hardware.dart';

import 'support/fake_hardware.dart';

void main() {
  late FakeHardware hardware;
  late AltimeterController source;
  late DateTime now;
  GeoFix fix({
    double altitude = 340,
    double vertical = 5,
    double accuracy = 5,
  }) => GeoFix(
    latitude: 39.8,
    longitude: -122.4,
    altitude: altitude,
    speed: 2,
    accuracy: accuracy,
    altitudeAccuracy: vertical,
    time: now,
  );
  setUp(() {
    now = DateTime.utc(2026, 10, 15);
    hardware = FakeHardware();
    source = AltimeterController(hardware: hardware, clock: () => now);
  });
  tearDown(() async {
    source.dispose();
    await hardware.close();
  });
  test('GPS works when pressure and compass are unavailable', () async {
    await source.start();
    hardware.pressures.addError(UnsupportedError('missing'));
    hardware.headings.add(null);
    hardware.fixes.add(fix());
    expect(source.reading.altitudeMeters, 340);
    expect(source.reading.pressureHpa, isNull);
    expect(source.reading.headingDegrees, isNull);
    expect(source.reading.speedKmh, 7.2);
    expect(source.reading.altitudeSource, 'GPS高度');
  });
  test('Missing hardware never substitutes simulated measurements', () async {
    hardware.permission = LocationAccess.serviceOff;
    await source.start();
    hardware.pressures.addError(UnsupportedError('missing'));
    hardware.headings.add(null);
    expect(source.reading.altitudeMeters, isNull);
    expect(source.reading.latitudeDegrees, isNull);
    expect(source.reading.isDemo, isFalse);
    expect(source.reading.pressureStatus, contains('不可用'));
    expect(source.reading.compassStatus, contains('不可用'));
    expect(source.reading.gpsStatus, contains('关闭'));
  });
  for (final access in [LocationAccess.denied, LocationAccess.deniedForever]) {
    test(
      'Permission $access blocks coordinates without blocking barometer',
      () async {
        hardware.permission = access;
        await source.start();
        hardware.pressures.add(1000);
        hardware.fixes.add(fix());
        expect(source.reading.latitudeDegrees, isNull);
        expect(source.reading.altitudeSource, contains('未校准'));
        expect(source.calibrate(), isFalse);
      },
    );
  }
  test(
    'Fresh accurate GPS calibrates pressure; photo snapshot is immutable',
    () async {
      await source.start();
      hardware.pressures.add(1000);
      hardware.fixes.add(fix());
      expect(source.calibrated, isTrue);
      final snapshot = source.reading;
      expect(snapshot.altitudeMeters, closeTo(340, .001));
      hardware.pressures.add(990);
      hardware.fixes.add(fix(altitude: 400));
      expect(source.reading.altitudeMeters, greaterThan(340));
      expect(snapshot.altitudeMeters, closeTo(340, .001));
      expect(snapshot.latitudeDegrees, 39.8);
    },
  );
  test('Poor GPS vertical accuracy cannot calibrate', () async {
    await source.start();
    hardware.pressures.add(1000);
    hardware.fixes.add(fix(vertical: 100));
    expect(source.calibrated, isFalse);
    expect(source.calibrate(), isFalse);
  });
  test('Position without vertical accuracy does not invent a zero altitude', () async {
    await source.start();
    hardware.fixes.add(fix(altitude: 0, vertical: 0));
    expect(source.reading.latitudeDegrees, 39.8);
    expect(source.reading.altitudeMeters, isNull);
    expect(source.reading.altitudeSource, 'GPS未提供有效高度');
    expect(source.reading.accuracyText, '海拔精度：未知');
  });
  test(
    'Expired data cannot appear as current measurements in watermark',
    () async {
      await source.start();
      hardware.fixes.add(fix());
      hardware.pressures.add(1000);
      hardware.headings.add(80);
      now = now.add(const Duration(seconds: 31));
      final snapshot = source.reading;
      expect(snapshot.altitudeMeters, isNull);
      expect(snapshot.latitudeDegrees, isNull);
      expect(snapshot.pressureHpa, isNull);
      expect(snapshot.headingDegrees, isNull);
      expect(snapshot.watermarkLines.join(), contains('纬度不可用'));
      expect(snapshot.watermarkLines.join(), isNot(contains('北纬')));
    },
  );
  test(
    'Location service disabled clears previous coordinates immediately',
    () async {
      await source.start();
      hardware.fixes.add(fix());
      hardware.services.add(false);
      expect(source.reading.latitudeDegrees, isNull);
      expect(source.reading.altitudeMeters, isNull);
    },
  );
  test(
    'Mode switch clears demo values and does not retain subscriptions',
    () async {
      await source.start();
      await source.setDemo(true);
      expect(source.reading.isDemo, isTrue);
      expect(source.reading.altitudeMeters, 3628);
      await source.setDemo(false);
      expect(source.reading.isDemo, isFalse);
      expect(source.reading.altitudeMeters, isNull);
      hardware.fixes.add(fix());
      expect(source.reading.altitudeMeters, 340);
      source.pause();
      hardware.fixes.add(fix(altitude: 900));
      expect(source.reading.altitudeMeters, isNull);
    },
  );
  test('Non-finite or physically invalid values are ignored', () async {
    await source.start();
    hardware.pressures.add(double.nan);
    hardware.pressures.add(-1);
    hardware.headings.add(double.nan);
    expect(source.reading.pressureHpa, isNull);
    expect(source.reading.headingDegrees, isNull);
  });
  test('Re-enabling location with an initial service event reconnects once', () async {
    hardware.permission = LocationAccess.serviceOff;
    hardware.initialServiceEvent = false;
    await source.start();
    hardware.permission = LocationAccess.ready;
    hardware.initialServiceEvent = true;
    hardware.services.add(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(hardware.serviceSubscriptions, 2);
    expect(source.locationAccess, LocationAccess.ready);
    hardware.fixes.add(fix());
    expect(source.reading.altitudeMeters, 340);
  });
  test(
    'Compass crosses north by shortest rotation, and DMS carries seconds',
    () {
      expect(smoothHeading(359, 1), closeTo(359.4, .001));
      expect(smoothHeading(1, 359), closeTo(.6, .001));
      expect(coordinateDms(39.99999999, latitude: true), '北纬 40°0′0″');
      expect(coordinateDms(-122.5, latitude: false), '西经 122°30′0″');
      expect(pressureAltitude(1013.25, 1013.25), 0);
    },
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/home_preferences.dart';
import 'package:altivex/sun_times.dart';

void main() {
  test(
    'Settings and an internal background copy survive restart independently',
    () async {
      final root = await Directory.systemTemp.createTemp('altivex-home-');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/original.jpg');
      await source.writeAsBytes([1, 2, 3]);
      final store = HomeStore(directory: root);
      final name = await store.importBackground(source);
      await store.save(
        HomePreferences(
          background: name,
          feet: true,
          decimal: true,
          mmHg: true,
        ),
      );
      final reopened = HomeStore(directory: root);
      final loaded = await reopened.load();
      expect(loaded.feet && loaded.decimal && loaded.mmHg, isTrue);
      await reopened.save(loaded.copyWith(dark: true));
      final dark = await reopened.load();
      expect(dark.background, name);
      expect(await (await reopened.backgroundFile(dark))!.readAsBytes(), [
        1,
        2,
        3,
      ]);
      await reopened.save(dark.copyWith(resetBackground: true));
      expect((await reopened.load()).dark, isTrue);
      expect((await reopened.load()).background, isNull);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );
  test('Invalid persisted paths cannot escape home storage', () {
    expect(
      HomePreferences.fromJson({'background': '../secret.jpg'}).background,
      isNull,
    );
    expect(HomePreferences.fromJson({'dark': 'true'}).dark, isFalse);
  });
  test('Equatorial equinox sunrise and sunset approximate 06/18 UTC', () {
    final sun = calculateSunTimes(DateTime(2026, 3, 21), 0, 0);
    expect(sun.status, isNull);
    final rise = sun.sunrise!.toUtc();
    final set = sun.sunset!.toUtc();
    expect(rise.hour * 60 + rise.minute, closeTo(360, 15));
    expect(set.hour * 60 + set.minute, closeTo(1080, 15));
  });
  test('Polar day, polar night and invalid positions have explicit states', () {
    expect(
      calculateSunTimes(DateTime(2026, 6, 21), 90, 0).status,
      contains('极昼'),
    );
    expect(
      calculateSunTimes(DateTime(2026, 12, 21), 90, 0).status,
      contains('极夜'),
    );
    expect(calculateSunTimes(DateTime(2026), double.nan, 0).status, '位置无效');
  });
  test('Date line and leap day retain the requested device local date', () {
    for (final lon in [-179.9, 179.9]) {
      final date = DateTime(2028, 2, 29);
      final sun = calculateSunTimes(date, 10, lon);
      for (final event in [sun.sunrise!, sun.sunset!]) {
        expect([event.year, event.month, event.day], [2028, 2, 29]);
      }
    }
  });
}

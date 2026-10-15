import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';

enum LocationAccess { ready, serviceOff, denied, deniedForever }

class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    required this.altitudeAccuracy,
    required this.time,
  });
  final double latitude, longitude, altitude, speed, accuracy, altitudeAccuracy;
  final DateTime time;
}

abstract class MeasurementHardware {
  Future<LocationAccess> access({required bool request});
  Stream<GeoFix> positions();
  Stream<double> pressure();
  Stream<double?> heading();
  Stream<bool> locationService();
}

class DeviceHardware implements MeasurementHardware {
  @override
  Future<LocationAccess> access({required bool request}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (request && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationAccess.denied,
      _ => LocationAccess.ready,
    };
  }

  @override
  Stream<GeoFix> positions() =>
      Geolocator.getPositionStream(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.best,
                distanceFilter: 0,
                forceLocationManager: true,
                intervalDuration: const Duration(seconds: 1),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.best,
                distanceFilter: 0,
              ),
      ).map(
        (p) => GeoFix(
          latitude: p.latitude,
          longitude: p.longitude,
          altitude: p.altitude,
          speed: p.speed,
          accuracy: p.accuracy,
          altitudeAccuracy: p.altitudeAccuracy,
          time: p.timestamp,
        ),
      );
  @override
  Stream<double> pressure() =>
      barometerEventStream(samplingPeriod: const Duration(milliseconds: 500))
          .map((e) => e.pressure);
  @override
  Stream<double?> heading() =>
      FlutterCompass.events?.map((e) => e.heading) ??
      Stream<double?>.value(null);
  @override
  Stream<bool> locationService() => Geolocator.getServiceStatusStream().map(
    (s) => s == ServiceStatus.enabled,
  );
}

// Debug-only capability fault injection; never active in release builds.
const hardwareUnavailableTest =
    kDebugMode && bool.fromEnvironment('ALTIVEX_DISABLE_HARDWARE');

class UnavailableHardware implements MeasurementHardware {
  @override
  Future<LocationAccess> access({required bool request}) async =>
      LocationAccess.serviceOff;
  @override
  Stream<GeoFix> positions() => const Stream.empty();
  @override
  Stream<double> pressure() =>
      Stream.error(UnsupportedError('No pressure sensor'));
  @override
  Stream<double?> heading() => Stream.value(null);
  @override
  Stream<bool> locationService() => const Stream.empty();
}

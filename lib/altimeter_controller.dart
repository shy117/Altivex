import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'altimeter_reading.dart';
import 'measurement_hardware.dart';

/// Owns foreground subscriptions. No simulated values are used in live mode.
class AltimeterController extends ChangeNotifier {
  AltimeterController({
    MeasurementHardware? hardware,
    DateTime Function()? clock,
    this._demo = false,
  }) : _hardware =
           hardware ??
           (hardwareUnavailableTest ? UnavailableHardware() : DeviceHardware()),
       _clock = clock ?? DateTime.now;
  final MeasurementHardware _hardware;
  final DateTime Function() _clock;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _timer;
  bool _disposed = false, _paused = true, _demo;
  int _generation = 0, _ticks = 0;
  GeoFix? _fix;
  double? _pressure, _heading, _p0;
  DateTime? _pressureAt, _headingAt, _startedAt;
  String gpsStatus = '等待定位', pressureStatus = '等待气压', compassStatus = '等待方向';
  LocationAccess? locationAccess;
  bool get isDemo => _demo;
  bool get calibrated => _p0 != null;
  bool _fresh(DateTime? time, int seconds) =>
      time != null &&
      _clock().difference(time).inSeconds <= seconds &&
      !_clock().isBefore(time.subtract(const Duration(seconds: 5)));

  AltimeterReading get reading {
    final now = _clock();
    if (_demo) {
      return AltimeterReading(
        capturedAt: now,
        altitudeMeters: 3628 + 3 * sin(_ticks / 12),
        pressureHpa: (751.81 + .02 * sin(_ticks / 12)) / .750061683,
        speedKmh: 96,
        headingDegrees: 8 * sin(_ticks / 24),
        latitudeDegrees: 39 + 47 / 60 + 9 / 3600,
        longitudeDegrees: -(122 + 24 / 60 + 23 / 3600),
        horizontalAccuracy: 1,
        verticalAccuracy: 1,
        positionAt: now,
        isDemo: true,
        altitudeSource: '模拟数据',
        gpsStatus: '模拟定位',
        pressureStatus: '模拟气压',
        compassStatus: '模拟方向',
      );
    }
    final fix = !_paused && _fresh(_fix?.time, 30) ? _fix : null;
    final pressure = !_paused && _fresh(_pressureAt, 10) ? _pressure : null;
    final heading = !_paused && _fresh(_headingAt, 10) ? _heading : null;
    // Android providers can return altitude=0 when they have no altitude fix.
    // Without usable vertical accuracy, do not present that sentinel as sea level.
    final gpsAltitude = fix != null && fix.altitudeAccuracy > 0
        ? fix.altitude
        : null;
    final altitude = pressure != null
        ? pressureAltitude(pressure, _p0 ?? 1013.25)
        : gpsAltitude;
    return AltimeterReading(
      capturedAt: now,
      altitudeMeters: altitude,
      pressureHpa: pressure,
      speedKmh: (fix == null || fix.speed < 0) ? null : fix.speed * 3.6,
      headingDegrees: heading,
      latitudeDegrees: fix?.latitude,
      longitudeDegrees: fix?.longitude,
      horizontalAccuracy: fix?.accuracy,
      verticalAccuracy: fix != null && fix.altitudeAccuracy > 0
          ? fix.altitudeAccuracy
          : null,
      positionAt: fix?.time,
      altitudeSource: pressure != null
          ? (_p0 != null ? '气压高度 · GPS已校准' : '标准气压估算 · 未校准')
          : (gpsAltitude != null
                ? 'GPS高度'
                : (fix != null ? 'GPS未提供有效高度' : '高度不可用')),
      gpsStatus:
          _fix != null && fix == null && locationAccess == LocationAccess.ready
          ? '定位已过期，等待更新'
          : gpsStatus,
      pressureStatus: _pressureAt != null && pressure == null
          ? '气压数据已过期'
          : pressureStatus,
      compassStatus: _headingAt != null && heading == null
          ? '方向数据已过期'
          : compassStatus,
    );
  }

  bool calibrate() {
    final fix = _fix;
    if (_demo ||
        _paused ||
        fix == null ||
        !_fresh(fix.time, 30) ||
        !_fresh(_pressureAt, 10) ||
        _pressure == null ||
        fix.accuracy > 30 ||
        fix.altitudeAccuracy <= 0 ||
        fix.altitudeAccuracy > 30 ||
        fix.altitude.abs() > 12000) {
      return false;
    }
    final reference = referencePressure(_pressure!, fix.altitude);
    if (!reference.isFinite || reference < 500 || reference > 1500) {
      return false;
    }
    _p0 = reference;
    _emit();
    return true;
  }

  Future<void> setDemo(bool value) async {
    if (_demo == value) return;
    _demo = value;
    _p0 = null;
    await start(requestPermission: false);
  }

  Future<void> start({bool requestPermission = true}) async {
    final generation = ++_generation;
    await _cancel();
    if (_disposed || generation != _generation) return;
    _paused = false;
    _startedAt = _clock();
    // A new service subscription can immediately emit "enabled". Discard the
    // previous access result so it cannot recursively restart this attempt.
    locationAccess = null;
    _fix = null;
    _pressure = null;
    _heading = null;
    _pressureAt = null;
    _headingAt = null;
    gpsStatus = '等待定位';
    pressureStatus = '等待气压';
    compassStatus = '等待方向';
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _ticks++;
      if (_startedAt != null &&
          _clock().difference(_startedAt!).inSeconds >= 10) {
        if (_pressureAt == null && pressureStatus == '等待气压') {
          pressureStatus = '无气压数据（设备可能不支持）';
        }
        if (_headingAt == null && compassStatus == '等待方向') {
          compassStatus = '无方向数据（设备可能不支持）';
        }
        if (_fix == null && gpsStatus == '正在定位') gpsStatus = '尚无定位，请移至开阔处';
      }
      _emit();
    });
    _emit();
    if (_demo) return;
    bool active() => !_disposed && !_paused && generation == _generation;
    _listen<double>(
      () => _hardware.pressure(),
      (p) {
        if (!active() || !p.isFinite || p < 100 || p > 1200) return;
        _pressure = _pressure == null ? p : _pressure! + .2 * (p - _pressure!);
        _pressureAt = _clock();
        pressureStatus = '气压计可用';
        if (_p0 == null) calibrate();
        _emit();
      },
      () {
        if (active()) {
          _pressure = null;
          _pressureAt = null;
          pressureStatus = '气压计不可用或未授权';
          _emit();
        }
      },
    );
    _listen<double?>(
      () => _hardware.heading(),
      (h) {
        if (!active()) return;
        if (h == null || !h.isFinite || h < 0) {
          _heading = null;
          _headingAt = null;
          compassStatus = '指南针不可用';
        } else {
          _heading = _heading == null ? h % 360 : smoothHeading(_heading!, h);
          _headingAt = _clock();
          compassStatus = '指南针可用';
        }
        _emit();
      },
      () {
        if (active()) {
          _heading = null;
          _headingAt = null;
          compassStatus = '指南针不可用';
          _emit();
        }
      },
    );
    _listen<bool>(() => _hardware.locationService(), (enabled) {
      if (!active()) return;
      if (!enabled) {
        _fix = null;
        locationAccess = LocationAccess.serviceOff;
        gpsStatus = '系统定位已关闭';
        _emit();
      } else if (locationAccess == LocationAccess.serviceOff) {
        unawaited(start(requestPermission: false));
      }
    }, () {});
    try {
      final access = await _hardware.access(request: requestPermission);
      if (!active()) return;
      locationAccess = access;
      gpsStatus = switch (access) {
        LocationAccess.ready => '正在定位',
        LocationAccess.serviceOff => '系统定位已关闭',
        LocationAccess.denied => '定位权限未授权',
        LocationAccess.deniedForever => '定位权限被永久拒绝，请打开设置',
      };
      if (access == LocationAccess.ready) {
        _listen<GeoFix>(
          () => _hardware.positions(),
          (fix) {
            if (!active() ||
                locationAccess != LocationAccess.ready ||
                !fix.latitude.isFinite ||
                !fix.longitude.isFinite ||
                fix.latitude.abs() > 90 ||
                fix.longitude.abs() > 180 ||
                !fix.altitude.isFinite ||
                !fix.speed.isFinite ||
                !fix.accuracy.isFinite ||
                fix.accuracy < 0 ||
                !fix.altitudeAccuracy.isFinite) {
              return;
            }
            if (_fix != null && fix.time.isBefore(_fix!.time)) return;
            _fix = fix;
            gpsStatus = fix.accuracy > 100 ? '定位较粗略' : '定位可用';
            if (_p0 == null) calibrate();
            _emit();
          },
          () {
            if (active()) {
              _fix = null;
              gpsStatus = locationAccess == LocationAccess.serviceOff
                  ? '系统定位已关闭'
                  : '定位不可用，请重试';
              _emit();
            }
          },
        );
      }
    } catch (_) {
      if (active()) gpsStatus = '定位初始化失败，请重试';
    }
    if (active()) _emit();
  }

  void _listen<T>(
    Stream<T> Function() stream,
    void Function(T) data,
    void Function() error,
  ) {
    try {
      _subscriptions.add(
        stream().listen(data, onError: (Object e) => error(), onDone: error),
      );
    } catch (_) {
      error();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _timer = null;
    final old = List.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(old.map((s) => s.cancel()));
  }

  void pause({bool notify = true}) {
    _paused = true;
    _generation++;
    unawaited(_cancel());
    if (notify) _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_cancel());
    super.dispose();
  }
}

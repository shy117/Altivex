import 'dart:math';

import 'package:flutter/foundation.dart';

String coordinateDms(double value, {required bool latitude}) {
  final seconds = (value.abs() * 3600).round();
  final direction = latitude
      ? (value >= 0 ? '北纬' : '南纬')
      : (value >= 0 ? '东经' : '西经');
  return '$direction ${seconds ~/ 3600}°${seconds ~/ 60 % 60}′${seconds % 60}″';
}

double pressureAltitude(double pressure, double seaLevel) =>
    (44330 * (1 - pow(pressure / seaLevel, .1903))).toDouble();
double referencePressure(double pressure, double altitude) =>
    pressure / pow(1 - altitude / 44330, 1 / .1903);
double smoothHeading(double previous, double next) =>
    (previous + ((next - previous + 540) % 360 - 180) * .2 + 360) % 360;

@immutable
class AltimeterReading {
  const AltimeterReading({
    required this.capturedAt,
    this.altitudeMeters,
    this.pressureHpa,
    this.speedKmh,
    this.headingDegrees,
    this.latitudeDegrees,
    this.longitudeDegrees,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.positionAt,
    this.isDemo = false,
    this.altitudeSource = '等待数据',
    this.gpsStatus = '等待定位',
    this.pressureStatus = '等待气压',
    this.compassStatus = '等待方向',
  });
  final DateTime capturedAt;
  final double? altitudeMeters, pressureHpa, speedKmh, headingDegrees;
  final double? latitudeDegrees,
      longitudeDegrees,
      horizontalAccuracy,
      verticalAccuracy;
  final DateTime? positionAt;
  final bool isDemo;
  final String altitudeSource, gpsStatus, pressureStatus, compassStatus;
  double? get pressureMmHg =>
      pressureHpa == null ? null : pressureHpa! * .750061683;
  String get latitude => latitudeDegrees == null
      ? '纬度不可用'
      : coordinateDms(latitudeDegrees!, latitude: true);
  String get longitude => longitudeDegrees == null
      ? '经度不可用'
      : coordinateDms(longitudeDegrees!, latitude: false);
  String altitudeText(bool feet) => altitudeMeters == null
      ? '-- ${feet ? 'ft' : '米'}'
      : '${(altitudeMeters! * (feet ? 3.28084 : 1)).toStringAsFixed(0)} ${feet ? 'ft' : '米'}';
  String get pressureText => pressureMmHg == null
      ? '气压不可用'
      : '${pressureMmHg!.toStringAsFixed(2)} mmHg';
  String get accuracyText => verticalAccuracy == null
      ? '海拔精度：未知'
      : 'GPS 垂直精度：±${max(1, verticalAccuracy!.ceil())}米';
  List<String> get watermarkLines => [
    'Altivex${isDemo ? ' · 模拟数据' : ''}  ${altitudeText(false)}',
    '$latitude  $longitude',
    '$pressureText · $altitudeSource',
    if (horizontalAccuracy != null)
      '水平精度 ±${max(1, horizontalAccuracy!.ceil())}米',
    if (positionAt != null)
      '定位时间 ${positionAt!.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
    '拍摄时间 ${capturedAt.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
  ];
}

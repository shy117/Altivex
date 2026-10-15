import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Immutable values captured together for a future photo watermark.
@immutable
class AltimeterReading {
  const AltimeterReading({
    required this.altitudeMeters,
    required this.pressureMmHg,
    required this.speedKmh,
    required this.headingDegrees,
    required this.capturedAt,
  });
  final double altitudeMeters, pressureMmHg, speedKmh, headingDegrees;
  final DateTime capturedAt;
  String get latitude => '北纬 39°47′9″';
  String get longitude => '西经 122°24′23″';
}

/// Independent simulated values for visual comparison, not real measurements.
class DemoAltimeter extends ChangeNotifier {
  Timer? _timer;
  int _seconds = 0;
  AltimeterReading get reading => AltimeterReading(
    altitudeMeters: 3628 + 3 * sin(_seconds / 12),
    pressureMmHg: 751.81 + 0.02 * sin(_seconds / 12),
    speedKmh: 96,
    headingDegrees: 8 * sin(_seconds / 24),
    capturedAt: DateTime.now(),
  );
  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

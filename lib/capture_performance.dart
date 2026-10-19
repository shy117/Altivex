import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_preferences.dart';

/// One bounded, developer-readable timing record; contains no image/location data.
class CapturePerformance {
  CapturePerformance(CameraPreferences preferences)
    : _configuration = {
        'format': preferences.format.name,
        'aspect': preferences.aspect.name,
        'autoSave': preferences.autoSave,
      };

  final Map<String, Object> _configuration;
  final _watch = Stopwatch()..start();
  final Map<String, double> _steps = {};
  int _previous = 0;
  bool _finished = false;

  void mark(String step) {
    final now = _watch.elapsedMicroseconds;
    _steps[step] = (now - _previous) / 1000;
    _previous = now;
  }

  Future<void> finish({bool success = true}) async {
    if (_finished || kReleaseMode) return;
    _finished = true;
    _watch.stop();
    final totalMs = _watch.elapsedMicroseconds / 1000;
    try {
      final directory = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationSupportDirectory();
      if (directory == null) return;
      await directory.create(recursive: true);
      await File('${directory.path}/last_capture_performance.json')
          .writeAsString(
            jsonEncode({
              ..._configuration,
              'success': success,
              'totalMs': totalMs,
              'stepsMs': _steps,
            }),
            encoding: utf8,
          );
    } catch (_) {
      // Optional diagnostics must never interrupt capture or recovery.
    }
  }
}

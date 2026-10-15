import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'measurement_hardware.dart';

/// CameraX can keep retrying when Android permanently denies camera access.
/// Request permission before creating it. On iOS, camera owns its native prompt.
Future<bool> prepareCameraAccess() async {
  if (hardwareUnavailableTest ||
      defaultTargetPlatform != TargetPlatform.android) {
    return true;
  }
  final status = await Permission.camera.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied || status.isRestricted) return false;
  return (await Permission.camera.request()).isGranted;
}

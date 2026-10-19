import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoGallery {
  static const _channel = MethodChannel('altivex/gallery');
  bool get canDeleteSavedCopies => Platform.isAndroid;

  Future<String?> save(File file) async {
    if (!Platform.isAndroid) {
      // iOS integration remains behind the existing cross-platform adapter.
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw StateError('相册权限未授权');
      }
      await Gal.putImage(file.path);
      return null;
    }
    final api = await _channel.invokeMethod<int>('apiLevel') ?? 29;
    if (api < 29 && !await Permission.storage.request().isGranted) {
      throw StateError('相册权限未授权');
    }
    // The Android adapter handles scoped storage and returns this app's exact URI.
    return _channel.invokeMethod<String>('saveImage', {'path': file.path});
  }

  Future<void> deleteSavedCopies(List<String> uris) async {
    if (uris.isEmpty) return;
    if (!canDeleteSavedCopies) throw UnsupportedError('当前平台暂不支持删除相册副本');
    await _channel.invokeMethod<void>('deleteImages', {'uris': uris});
  }
}

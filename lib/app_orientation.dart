import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const portraitSettingsRoute = '/portrait-settings';

const portraitOrientations = [DeviceOrientation.portraitUp];
const photoOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Only camera/viewer routes opt into rotation. Settings explicitly use portrait.
/// Other dialogs and sheets
/// inherit the underlying page, including when they are popped or replaced.
class PhotoPageRoute<T> extends MaterialPageRoute<T> {
  PhotoPageRoute({required super.builder});
}

class AppOrientationObserver extends NavigatorObserver {
  AppOrientationObserver({
    Future<void> Function(List<DeviceOrientation>)? apply,
  }) : _apply = apply ?? SystemChrome.setPreferredOrientations;
  final Future<void> Function(List<DeviceOrientation>) _apply;
  final List<Route<dynamic>> _routes = [];
  bool? _rotating;

  void _update() {
    final page = _routes.reversed
        .where(
          (route) =>
              route is PageRoute ||
              route.settings.name == portraitSettingsRoute,
        )
        .firstOrNull;
    final rotating = page is PhotoPageRoute;
    if (rotating == _rotating) return;
    _rotating = rotating;
    unawaited(_apply(rotating ? photoOrientations : portraitOrientations));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _update();
  }
}

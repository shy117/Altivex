import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altivex/app_orientation.dart';

void main() {
  testWidgets(
    'Camera and photo routes rotate; home/history and their sheets stay portrait',
    (tester) async {
      final requested = <List<DeviceOrientation>>[];
      final observer = AppOrientationObserver(
        apply: (value) async => requested.add(value),
      );
      final navigation = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigation,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('home')),
        ),
      );
      expect(requested.last, portraitOrientations);

      void pushPage(String label, {bool rotate = false}) {
        Widget page(BuildContext context) => Scaffold(body: Text(label));
        navigation.currentState!.push<void>(
          rotate
              ? PhotoPageRoute<void>(builder: page)
              : MaterialPageRoute<void>(builder: page),
        );
      }

      Future<void> pop() async {
        navigation.currentState!.pop();
        await tester.pumpAndSettle();
      }

      pushPage('camera', rotate: true);
      await tester.pumpAndSettle();
      expect(requested.last, photoOrientations);
      final count = requested.length;
      showModalBottomSheet<void>(
        context: navigation.currentContext!,
        builder: (_) => const Text('camera settings'),
      );
      await tester.pumpAndSettle();
      await pop();
      expect(requested.length, count);
      showModalBottomSheet<void>(
        context: navigation.currentContext!,
        routeSettings: const RouteSettings(name: portraitSettingsRoute),
        builder: (_) => const Text('portrait settings'),
      );
      await tester.pumpAndSettle();
      expect(requested.last, portraitOrientations);
      await pop();
      expect(requested.last, photoOrientations);

      pushPage('history');
      await tester.pumpAndSettle();
      expect(requested.last, portraitOrientations);
      pushPage('single photo', rotate: true);
      await tester.pumpAndSettle();
      expect(requested.last, photoOrientations);
      await pop();
      expect(requested.last, portraitOrientations);
      await pop();
      expect(requested.last, photoOrientations);
      await pop();
      expect(requested.last, portraitOrientations);
      final beforeHomeSheet = requested.length;
      showModalBottomSheet<void>(
        context: navigation.currentContext!,
        builder: (_) => const Text('home settings'),
      );
      await tester.pumpAndSettle();
      await pop();
      expect(requested.length, beforeHomeSheet);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('Replacement and removal restore the remaining page orientation', () {
    final requested = <List<DeviceOrientation>>[];
    final observer = AppOrientationObserver(
      apply: (value) async => requested.add(value),
    );
    final root = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final photo = PhotoPageRoute<void>(builder: (_) => const SizedBox());
    final history = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    observer.didPush(root, null);
    observer.didPush(photo, root);
    observer.didReplace(newRoute: history, oldRoute: photo);
    expect(requested.last, portraitOrientations);
    observer.didReplace(newRoute: photo, oldRoute: history);
    expect(requested.last, photoOrientations);
    observer.didRemove(photo, root);
    expect(requested.last, portraitOrientations);
    root.dispose();
    photo.dispose();
    history.dispose();
  });
}

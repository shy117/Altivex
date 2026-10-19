import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_orientation.dart';

import 'altimeter_page.dart';
import 'altimeter_controller.dart';
import 'home_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(portraitOrientations);
  runApp(const AltivexApp());
}

class AltivexApp extends StatefulWidget {
  const AltivexApp({super.key, this.source, this.homeStore});
  final AltimeterController? source;
  final HomeStore? homeStore;

  @override
  State<AltivexApp> createState() => _AltivexAppState();
}

class _AltivexAppState extends State<AltivexApp> {
  final _orientation = AppOrientationObserver();
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [_orientation],
    title: 'Altivex',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF61DFC5),
      scaffoldBackgroundColor: const Color(0xFF101A23),
      useMaterial3: true,
    ),
    home: AltimeterPage(source: widget.source, store: widget.homeStore),
  );
}

import 'package:flutter/material.dart';

import 'altimeter_page.dart';
import 'altimeter_controller.dart';

void main() => runApp(const AltivexApp());

class AltivexApp extends StatelessWidget {
  const AltivexApp({super.key, this.source});
  final AltimeterController? source;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Altivex',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF61DFC5),
      scaffoldBackgroundColor: const Color(0xFF101A23),
      useMaterial3: true,
    ),
    home: AltimeterPage(source: source),
  );
}

import 'package:flutter/material.dart';

import 'altimeter_page.dart';

void main() => runApp(const AltivexApp());

class AltivexApp extends StatelessWidget {
  const AltivexApp({super.key});

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
    home: const AltimeterPage(),
  );
}

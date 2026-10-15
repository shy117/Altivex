import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'demo_altimeter.dart';
import 'photo_preview_page.dart';

class AltimeterPage extends StatefulWidget {
  const AltimeterPage({super.key});
  @override
  State<AltimeterPage> createState() => _AltimeterPageState();
}

class _AltimeterPageState extends State<AltimeterPage> {
  final _source = DemoAltimeter();
  bool _feet = false;
  @override
  void initState() {
    super.initState();
    _source.start();
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  void _settings() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('显示单位', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('米 m')),
                ButtonSegment(value: true, label: Text('英尺 ft')),
              ],
              selected: {_feet},
              onSelectionChanged: (value) {
                setState(() => _feet = value.first);
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 20),
            const Text('当前海拔、气压、速度、方向及经纬度均为模拟数据。'),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0EB1C6),
              Color(0xFF56B3A5),
              Color(0xFFB99A49),
              Color(0xFFBE3028),
            ],
            stops: [0, .39, .67, 1],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _source,
            builder: (context, _) {
              final reading = _source.reading;
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Scroll only when a short viewport or large accessibility text needs it.
                  final height = max(constraints.maxHeight, 620.0);
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: height,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 54,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Text(
                                  '实时高度表',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: '设置',
                                      onPressed: _settings,
                                      icon: const Icon(Icons.settings_outlined),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: '分享',
                                      onPressed: () =>
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '界面演示：分享功能将在第二阶段接入',
                                                  ),
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.ios_share_outlined,
                                        size: 22,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '拍照',
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => PhotoPreviewPage(
                                            reading: reading,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.camera_alt,
                                        size: 23,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            '${reading.pressureMmHg.toStringAsFixed(4)} mmHg',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            '海拔精度:1米（模拟）',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(flex: 3),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: min(460, height * .43),
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CustomPaint(
                                  painter: _DialPainter(reading.headingDegrees),
                                  child: FractionallySizedBox(
                                    widthFactor: .76,
                                    heightFactor: .76,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '当前海拔',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '${(reading.altitudeMeters * (_feet ? 3.28084 : 1)).toStringAsFixed(0)} ${_feet ? 'ft' : '米'}',
                                                style: const TextStyle(
                                                  fontSize: 58,
                                                  fontWeight: FontWeight.w300,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '当前速度：${reading.speedKmh.toStringAsFixed(0)} km/h',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(flex: 3),
                          Text(
                            reading.latitude,
                            style: const TextStyle(
                              fontSize: 21,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            reading.longitude,
                            style: const TextStyle(
                              fontSize: 21,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(flex: 2),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              '模拟数据 · 界面预览',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  const _DialPainter(this.heading);
  final double heading;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0x708FE3BB));
    final inner = Rect.fromCircle(center: center, radius: radius * .82);
    canvas.drawCircle(
      center,
      radius * .82,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFA52C), Color(0xFFFE304A), Color(0xFFFA2E46)],
          stops: [0, .4, 1],
        ).createShader(inner),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * pi / 180);
    for (final north in [true, false]) {
      final y = (north ? -1 : 1) * radius * .9;
      final direction = north ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(0, y + direction * radius * .07)
        ..lineTo(-radius * .13, y - direction * radius * .055)
        ..lineTo(radius * .13, y - direction * radius * .055)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = north ? const Color(0xFFEF5A5F) : Colors.white,
      );
      final text = TextPainter(
        text: TextSpan(
          text: north ? 'N' : 'S',
          style: TextStyle(
            color: north ? Colors.white70 : const Color(0xFFBFCBB1),
            fontSize: radius * .072,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(-text.width / 2, y - text.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.heading != heading;
}

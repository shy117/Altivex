import 'dart:math';

import 'package:flutter/material.dart';

import 'altimeter_reading.dart';

const coral = Color(0xFFFF694A);
const navy = Color(0xFF102D46);

class AltitudeDial extends StatefulWidget {
  const AltitudeDial({
    super.key,
    required this.reading,
    required this.feet,
    required this.dark,
  });
  final AltimeterReading reading;
  final bool feet, dark;
  @override
  State<AltitudeDial> createState() => _AltitudeDialState();
}

class _AltitudeDialState extends State<AltitudeDial> {
  double _turns = 0;
  double? _previous;
  @override
  void initState() {
    super.initState();
    _updateHeading();
  }

  @override
  void didUpdateWidget(AltitudeDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateHeading();
  }

  void _updateHeading() {
    final next = widget.reading.headingDegrees;
    if (next == null || !next.isFinite) {
      _previous = null;
      return;
    }
    if (_previous == null) {
      _turns = -next / 360;
    } else {
      _turns -= ((next - _previous! + 540) % 360 - 180) / 360;
    }
    _previous = next;
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final valid = reading.headingDegrees?.isFinite == true;
    final foreground = widget.dark ? Colors.white : navy;
    final altitude = reading.altitudeMeters;
    final value = altitude == null || !altitude.isFinite
        ? '--'
        : (altitude * (widget.feet ? 3.28084 : 1)).toStringAsFixed(0);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final diameter = box.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.dark
                      ? const Color(0xFF182F45)
                      : const Color(0xFFF9FCFF),
                  border: Border.all(color: foreground.withValues(alpha: .09)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .05),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
              if (valid)
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _turns),
                  duration: const Duration(milliseconds: 180),
                  builder: (context, turns, child) =>
                      Transform.rotate(angle: turns * 2 * pi, child: child),
                  child: CustomPaint(
                    size: Size.square(diameter),
                    painter: CompassPainter(foreground),
                  ),
                ),
              Positioned(
                top: 0,
                child: CustomPaint(
                  size: Size(diameter * .035, diameter * .025),
                  painter: _ReferencePainter(
                    valid ? coral : foreground.withValues(alpha: .25),
                  ),
                ),
              ),
              Positioned(
                top: diameter * .23,
                child: Image.asset(
                  'assets/branding/generated/home-logo-${widget.dark ? 'dark' : 'light'}.png',
                  width: diameter * .25,
                  height: diameter * .18,
                  fit: BoxFit.contain,
                ),
              ),
              Center(
                child: FractionallySizedBox(
                  widthFactor: .67,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: value,
                            style: const TextStyle(
                              fontSize: 66,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -2,
                            ),
                          ),
                          TextSpan(
                            text: ' ${widget.feet ? 'ft' : '米'}',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      key: const Key('altitude-value'),
                      style: TextStyle(color: foreground),
                      semanticsLabel: '海拔 $value ${widget.feet ? '英尺' : '米'}',
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: diameter * .23,
                child: SizedBox(
                  width: diameter * .6,
                  child: Text(
                    reading.isDemo
                        ? '模拟数据 · 界面预览'
                        : valid
                        ? ''
                        : reading.compassStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: foreground.withValues(alpha: .65),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  const CompassPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()..strokeWidth = 1.5;
    for (var degree = 0; degree < 360; degree += 15) {
      final angle = (degree - 90) * pi / 180;
      final long = degree % 45 == 0;
      paint.color = degree == 0
          ? coral
          : color.withValues(alpha: long ? .65 : .3);
      final outer = radius * .81;
      final inner = outer - radius * (long ? .065 : .035);
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * inner,
        center + Offset(cos(angle), sin(angle)) * outer,
        paint,
      );
    }
    for (var i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * pi / 180;
      final label = TextPainter(
        text: TextSpan(
          text: ['N', 'E', 'S', 'W'][i],
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: radius * .10,
            fontWeight: FontWeight.w600,
            color: i == 0 ? coral : color.withValues(alpha: .65),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final point = center + Offset(cos(angle), sin(angle)) * radius * .89;
      label.paint(canvas, point - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) => oldDelegate.color != color;
}

class _ReferencePainter extends CustomPainter {
  const _ReferencePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ReferencePainter oldDelegate) =>
      color != oldDelegate.color;
}

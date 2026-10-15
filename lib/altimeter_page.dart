import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'altimeter_controller.dart';
import 'altimeter_reading.dart';
import 'measurement_hardware.dart';
import 'sharing.dart';

import 'package:geolocator/geolocator.dart';

import 'photo_preview_page.dart';

class AltimeterPage extends StatefulWidget {
  const AltimeterPage({super.key, this.source});
  final AltimeterController? source;
  @override
  State<AltimeterPage> createState() => _AltimeterPageState();
}

class _AltimeterPageState extends State<AltimeterPage>
    with WidgetsBindingObserver {
  late final AltimeterController _source;
  bool _feet = false;
  @override
  void initState() {
    super.initState();
    _source = widget.source ?? AltimeterController();
    WidgetsBinding.instance.addObserver(this);
    _source.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _source.pause();
    if (widget.source == null) _source.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _source.pause();
    }
    if (state == AppLifecycleState.resumed) {
      _source.start(requestPermission: false);
    }
  }

  void _settings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: _source,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('高度计设置', style: TextStyle(fontSize: 20)),
                SwitchListTile(
                  title: const Text('模拟模式'),
                  subtitle: const Text('关闭时仅显示设备真实数据'),
                  value: _source.isDemo,
                  onChanged: (value) => _source.setDemo(value),
                ),
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
                const SizedBox(height: 16),
                Text(_source.reading.gpsStatus),
                Text(_source.reading.pressureStatus),
                Text(
                  _source.reading.pressureHpa == null
                      ? '气压：-- hPa'
                      : '气压：${_source.reading.pressureHpa!.toStringAsFixed(2)} hPa',
                ),
                Text(_source.reading.compassStatus),
                Text(_source.reading.altitudeSource),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _source.start(),
                  child: const Text('重新检测 / 请求定位权限'),
                ),
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('打开应用权限设置'),
                ),
                TextButton(
                  onPressed: Geolocator.openLocationSettings,
                  child: const Text('打开系统定位设置'),
                ),
                TextButton(
                  onPressed: () {
                    final success = _source.calibrate();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '已使用当前 GPS 高度校准气压高度'
                              : '校准需要新鲜气压数据和垂直、水平精度均在30米内的 GPS 定位',
                        ),
                      ),
                    );
                  },
                  child: const Text('使用 GPS 重新校准气压高度'),
                ),
                const Text(
                  '气压高度受天气影响；GPS 高度及精度取决于设备定位服务。指南针受磁场干扰，异常时请远离金属并校准手机。',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
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
                  if (constraints.maxWidth > constraints.maxHeight) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: SizedBox.square(
                              dimension: min(
                                constraints.maxHeight - 24,
                                constraints.maxWidth / 2 - 24,
                              ),
                              child: _dial(reading),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: '设置',
                                      onPressed: _settings,
                                      icon: const Icon(Icons.settings_outlined),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        '实时高度表',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '分享',
                                      onPressed: () => shareContent(
                                        context,
                                        text: reading.watermarkLines.join('\n'),
                                      ),
                                      icon: const Icon(
                                        Icons.ios_share_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '拍照',
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PhotoPreviewPage(source: _source),
                                        ),
                                      ),
                                      icon: const Icon(Icons.camera_alt),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(reading.pressureText),
                                Text(reading.accuracyText),
                                const SizedBox(height: 20),
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
                                const SizedBox(height: 16),
                                Text(
                                  '${hardwareUnavailableTest ? '硬件缺失测试 · ' : ''}${reading.isDemo ? '模拟数据 · 界面预览' : '${reading.altitudeSource}\n${reading.gpsStatus} · ${reading.pressureStatus}\n${reading.compassStatus}'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
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
                                      onPressed: () => shareContent(
                                        context,
                                        text: reading.watermarkLines.join('\n'),
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
                                          builder: (_) =>
                                              PhotoPreviewPage(source: _source),
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
                            reading.pressureText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            reading.accuracyText,
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
                              child: _dial(reading),
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
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${hardwareUnavailableTest ? '硬件缺失测试 · ' : ''}${reading.isDemo ? '模拟数据 · 界面预览' : '${reading.altitudeSource}\n${reading.gpsStatus} · ${reading.pressureStatus}\n${reading.compassStatus}'}',
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

  Widget _dial(AltimeterReading reading) => AspectRatio(
    aspectRatio: 1,
    child: CustomPaint(
      painter: _DialPainter(reading.headingDegrees),
      child: FractionallySizedBox(
        widthFactor: .76,
        heightFactor: .76,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '当前海拔',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    reading.altitudeText(_feet),
                    style: const TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reading.speedKmh == null
                      ? '速度不可用'
                      : '当前速度：${reading.speedKmh!.toStringAsFixed(0)} km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  const _DialPainter(this.heading);
  final double? heading;
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
    if (heading == null) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading! * pi / 180);
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

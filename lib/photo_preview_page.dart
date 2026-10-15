import 'package:flutter/material.dart';

import 'demo_altimeter.dart';

/// Layout-only preview. The immutable reading demonstrates snapshot semantics.
class PhotoPreviewPage extends StatelessWidget {
  const PhotoPreviewPage({super.key, required this.reading});
  final AltimeterReading reading;
  static const _watermarkStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    shadows: [
      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            height: 5,
            margin: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF159BA7),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF366F90),
                        Color(0xFF315B63),
                        Color(0xFF21332F),
                      ],
                    ),
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text('相机预览示意', style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 8),
                      Text(
                        '第一阶段未接入摄像头',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Text('实时高度表 · 模拟', style: _watermarkStyle),
                      Text(
                        '${reading.pressureMmHg.toStringAsFixed(2)} mmHg',
                        style: _watermarkStyle,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 12,
                  right: 12,
                  child: DefaultTextStyle(
                    style: _watermarkStyle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '海拔 ${reading.altitudeMeters.toStringAsFixed(0)} 米',
                        ),
                        Text('${reading.latitude}  ${reading.longitude}'),
                        Text(
                          '数据快照 ${reading.capturedAt.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 145,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '返回',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: '切换摄像头',
                  onPressed: () => _notice(context),
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
                Semantics(
                  button: true,
                  label: '拍摄（演示）',
                  child: GestureDetector(
                    onTap: () => _notice(context),
                    child: Container(
                      width: 66,
                      height: 66,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF47742),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '水印位置',
                  onPressed: () => _notice(context),
                  icon: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  void _notice(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(
        const SnackBar(content: Text('当前仅预览布局，真实拍摄、永久水印和相册保存将在第二阶段实现')),
      );
}

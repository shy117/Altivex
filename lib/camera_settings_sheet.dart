import 'package:flutter/material.dart';

import 'altimeter_reading.dart';
import 'camera_preferences.dart';
import 'photo_watermark.dart';

class CameraSettingsSheet extends StatefulWidget {
  const CameraSettingsSheet({
    super.key,
    required this.preferences,
    required this.reading,
    required this.onChanged,
  });
  final CameraPreferences preferences;
  final AltimeterReading reading;
  final Future<void> Function(CameraPreferences) onChanged;
  @override
  State<CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<CameraSettingsSheet> {
  late CameraPreferences _value = widget.preferences;
  bool _saving = false;
  double _headerDrag = 0;

  Future<void> _change(CameraPreferences value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onChanged(value);
      if (mounted) setState(() => _value = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设置保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(color: Color(0xFFFF9E52), fontSize: 12),
    ),
  );
  Widget _toggle(
    String title,
    bool value,
    ValueChanged<bool> change, {
    String? subtitle,
  }) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontSize: 15)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
    value: value,
    activeThumbColor: Colors.white,
    activeTrackColor: const Color(0xFF52687D),
    onChanged: _saving ? null : change,
  );
  Widget _choices<T>(
    String title,
    List<T> values,
    T selected,
    String Function(T) label,
    ValueChanged<T> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: values
            .map(
              (value) => ChoiceChip(
                label: Text(label(value)),
                selected: value == selected,
                showCheckmark: false,
                side: BorderSide.none,
                backgroundColor: const Color(0xFF171C24),
                selectedColor: const Color(0xFF303944),
                shape: const StadiumBorder(),
                onSelected: _saving ? null : (_) => change(value),
              ),
            )
            .toList(),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF171C24),
      colorScheme: const ColorScheme.dark(surface: Color(0xFF171C24)),
      dividerColor: Colors.white12,
    ),
    child: SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            GestureDetector(
              key: const ValueKey('camera-settings-header'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _headerDrag = 0,
              onVerticalDragUpdate: (details) {
                _headerDrag += details.delta.dy;
                if (_headerDrag > 48) {
                  _headerDrag = double.negativeInfinity;
                  Navigator.maybePop(context);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '相机设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Altivex',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('照片保存'),
                    _toggle(
                      '自动保存',
                      _value.autoSave,
                      (v) => _change(_value.copyWith(autoSave: v)),
                      subtitle: '拍照后直接保存，不进入预览',
                    ),
                    _choices(
                      '照片格式',
                      PhotoFormat.values,
                      _value.format,
                      (v) => v == PhotoFormat.jpeg ? 'JPEG' : 'PNG',
                      (v) => _change(_value.copyWith(format: v)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        _value.format == PhotoFormat.jpeg
                            ? 'JPEG：文件通常更小，适合日常照片'
                            : 'PNG：无损编码，文件通常更大',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Divider(),
                    _section('拍摄辅助'),
                    _toggle(
                      '九宫格参考线',
                      _value.grid,
                      (v) => _change(_value.copyWith(grid: v)),
                    ),
                    _toggle(
                      '水平仪',
                      _value.level,
                      (v) => _change(_value.copyWith(level: v)),
                    ),
                    _choices(
                      '定时拍照',
                      [0, 3, 10],
                      _value.timerSeconds,
                      (v) => v == 0 ? '关闭' : '$v 秒',
                      (v) => _change(_value.copyWith(timerSeconds: v)),
                    ),
                    _choices(
                      '照片比例',
                      PhotoAspect.values,
                      _value.aspect,
                      (v) => v.label,
                      (v) => _change(_value.copyWith(aspect: v)),
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    _section('水印设置'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('水印样式'),
                      subtitle: Text(
                        _value.style.label,
                        style: const TextStyle(color: Colors.white60),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving
                          ? null
                          : () async {
                              final selected =
                                  await Navigator.push<WatermarkStyle>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WatermarkSelectionPage(
                                        reading: widget.reading,
                                        selected: _value.style,
                                      ),
                                    ),
                                  );
                              if (mounted && selected != null) {
                                await _change(_value.copyWith(style: selected));
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class WatermarkSelectionPage extends StatelessWidget {
  const WatermarkSelectionPage({
    super.key,
    required this.reading,
    required this.selected,
  });
  final AltimeterReading reading;
  final WatermarkStyle selected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('水印样式')),
    body: GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: .8,
      children: WatermarkStyle.values
          .map(
            (style) => InkWell(
              onTap: () => Navigator.pop(context, style),
              child: Column(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42687E), Color(0xFF18292C)],
                        ),
                        border: Border.all(
                          color: style == selected
                              ? Colors.orangeAccent
                              : Colors.white24,
                          width: style == selected ? 2 : 1,
                        ),
                      ),
                      child: WatermarkOverlay(reading, style: style),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${style.label}${style == selected ? ' ✓' : ''}'),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}

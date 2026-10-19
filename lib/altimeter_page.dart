import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'altimeter_controller.dart';
import 'altimeter_reading.dart';
import 'altitude_dial.dart';
import 'app_orientation.dart';
import 'home_preferences.dart';
import 'home_settings_sheet.dart';
import 'measurement_hardware.dart';
import 'photo_preview_page.dart';
import 'sun_times.dart';

class AltimeterPage extends StatefulWidget {
  const AltimeterPage({super.key, this.source, this.store});
  final AltimeterController? source;
  final HomeStore? store;
  @override
  State<AltimeterPage> createState() => _AltimeterPageState();
}

class _AltimeterPageState extends State<AltimeterPage>
    with WidgetsBindingObserver {
  late final AltimeterController _source;
  late final HomeStore _store;
  HomePreferences _preferences = const HomePreferences();
  File? _background;
  bool _ready = false, _busy = false;
  int _page = 0;
  final _pages = PageController();
  final _changes = ValueNotifier<int>(0);

  ThemeData get _theme => ThemeData(
    useMaterial3: true,
    iconTheme: IconThemeData(color: _preferences.dark ? Colors.white : navy),
    brightness: _preferences.dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: coral,
      brightness: _preferences.dark ? Brightness.dark : Brightness.light,
      primary: coral,
      onSurface: _preferences.dark ? Colors.white : navy,
    ),
  );
  ThemeData get _settingsTheme {
    final dark = _preferences.dark;
    final foreground = dark ? const Color(0xFFF0F4F8) : navy;
    final secondary = dark ? const Color(0xFFA3B2C2) : const Color(0xFF64798B);
    final surface = dark ? const Color(0xFF18232F) : const Color(0xFFF8FAFC);
    final selected = dark ? const Color(0xFF35495D) : const Color(0xFFDDE8F0);
    final colors =
        ColorScheme.fromSeed(
          seedColor: navy,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: dark ? const Color(0xFFD7E6F3) : navy,
          onPrimary: dark ? navy : Colors.white,
          surface: surface,
          onSurface: foreground,
          onSurfaceVariant: secondary,
          surfaceContainerHighest: selected,
          outline: dark ? const Color(0xFF435363) : const Color(0xFFCDD8E1),
          outlineVariant: dark
              ? const Color(0xFF2C3947)
              : const Color(0xFFE3EAF0),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: surface,
      iconTheme: IconThemeData(color: foreground),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        textColor: foreground,
        iconColor: secondary,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          color: foreground,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          color: secondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : secondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? const Color(0xFF577590) : const Color(0xFF456780))
              : (dark ? const Color(0xFF2B3947) : const Color(0xFFDFE6EC)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: foreground),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? HomeStore();
    _source = widget.source ?? AltimeterController();
    WidgetsBinding.instance.addObserver(this);
    _source.start();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await _store.load();
      final background = await _store.backgroundFile(preferences);
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _background = background;
        });
      }
    } catch (_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _message('主界面设置读取失败，已使用默认设置');
        });
      }
    } finally {
      if (mounted) setState(() => _ready = true);
    }
    if (Platform.isAndroid) {
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (lost.files?.isNotEmpty == true && mounted) {
          await _setBackground(File(lost.files!.first.path));
        }
      } catch (_) {
        if (mounted) _message('未能恢复上次选择的背景，请重新选择');
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void _refresh() {
    if (mounted) {
      setState(() {});
      _changes.value++;
    }
  }

  Future<void> _save(HomePreferences value) async {
    if (!_ready || _busy) return;
    _busy = true;
    _refresh();
    try {
      await _store.save(value);
      final file = await _store.backgroundFile(value);
      if (mounted) {
        _preferences = value;
        _background = file;
      }
    } catch (_) {
      if (mounted) _message('设置保存失败，请重试');
    } finally {
      _busy = false;
      _refresh();
    }
  }

  Future<void> _setBackground(File file) async {
    try {
      final name = await _store.importBackground(file);
      await _save(_preferences.copyWith(background: name));
    } catch (_) {
      if (mounted) _message('背景图片读取失败，请重新选择');
    }
  }

  Future<void> _pickBackground() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (photo != null && mounted) await _setBackground(File(photo.path));
    } catch (_) {
      if (mounted) _message('无法打开照片选择器，请重试');
    }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    _changes.dispose();
    // Descendants may still be disposing; release streams without rebuilding them.
    _source.pause(notify: false);
    if (widget.source == null) _source.dispose();
    super.dispose();
  }

  void _settings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ListenableBuilder(
      listenable: Listenable.merge([_changes, _source]),
      builder: (context, _) => Theme(
        data: _settingsTheme,
        child: HomeSettingsSheet(
          children: [
            _section('外观'),
            SwitchListTile(
              title: const Text('深色主题'),
              value: _preferences.dark,
              onChanged: !_ready || _busy
                  ? null
                  : (v) => _save(_preferences.copyWith(dark: v)),
            ),
            ListTile(
              title: const Text('主界面背景'),
              subtitle: Text(
                _preferences.background == null ? '默认渐变背景' : '自定义图片',
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: !_ready || _busy ? null : _pickBackground,
            ),
            if (_preferences.background != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _save(_preferences.copyWith(resetBackground: true)),
                child: const Text('恢复默认背景'),
              ),
            _section('单位与格式'),
            _choice(
              '海拔单位',
              _preferences.feet,
              '米',
              '英尺 ft',
              (v) => _save(_preferences.copyWith(feet: v)),
            ),
            _choice(
              '坐标格式',
              _preferences.decimal,
              '度分秒',
              '十进制度',
              (v) => _save(_preferences.copyWith(decimal: v)),
            ),
            _choice(
              '气压单位',
              _preferences.mmHg,
              'hPa',
              'mmHg',
              (v) => _save(_preferences.copyWith(mmHg: v)),
            ),
            _section('测量与校准'),
            _status('定位', _source.reading.gpsStatus),
            _status('气压计', _source.reading.pressureStatus),
            _status('指南针', _source.reading.compassStatus),
            ListTile(
              title: const Text('使用 GPS 校准气压高度'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                final ok = _source.calibrate();
                _message(
                  ok
                      ? '已使用当前 GPS 高度校准气压高度'
                      : '校准需要新鲜气压数据和垂直、水平精度均在30米内的 GPS 定位',
                );
              },
            ),
            ListTile(
              title: const Text('重新检测 / 请求定位权限'),
              trailing: const Icon(Icons.refresh, size: 19),
              onTap: () => _source.start(),
            ),
            ListTile(
              title: const Text('打开应用权限设置'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: Geolocator.openAppSettings,
            ),
            ListTile(
              title: const Text('打开系统定位设置'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: Geolocator.openLocationSettings,
            ),
            _section('预览'),
            SwitchListTile(
              title: const Text('模拟模式'),
              subtitle: const Text('仅用于界面预览，明确标记模拟数据'),
              value: _source.isDemo,
              onChanged: _source.setDemo,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '气压高度受天气影响；GPS 垂直精度不代表气压或融合高度的实际误差。指南针受磁场干扰。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: _settingsTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: .5,
        color: _settingsTheme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _status(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: _settingsTheme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _choice(
    String title,
    bool value,
    String first,
    String second,
    ValueChanged<bool> changed,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 10),
        Center(
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(first)),
              ButtonSegment(value: true, label: Text(second)),
            ],
            selected: {value},
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Roboto', fontSize: 13),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _settingsTheme.colorScheme.surfaceContainerHighest
                    : _settingsTheme.colorScheme.surface,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _settingsTheme.colorScheme.onSurface
                    : _settingsTheme.colorScheme.onSurfaceVariant,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: _settingsTheme.colorScheme.outline),
              ),
            ),
            onSelectionChanged: !_ready || _busy
                ? null
                : (v) => changed(v.first),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (_preferences.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _preferences.dark
                      ? [const Color(0xFF0A1C30), const Color(0xFF203D59)]
                      : [Colors.white, const Color(0xFFEAF2F8)],
                ),
              ),
            ),
            if (_background != null)
              Image.file(
                _background!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                cacheWidth: 2560,
                errorBuilder: (_, error, stack) => const SizedBox.shrink(),
              ),
            if (_background != null)
              ColoredBox(
                color:
                    (_preferences.dark ? const Color(0xFF07182B) : Colors.white)
                        .withValues(alpha: _preferences.dark ? .68 : .75),
              ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: '设置',
                          onPressed: _settings,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        const Expanded(
                          child: Text(
                            'Altivex',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '拍照',
                          onPressed: () => Navigator.push(
                            context,
                            PhotoPageRoute<void>(
                              builder: (_) => PhotoPreviewPage(source: _source),
                            ),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _source,
                      builder: (context, _) {
                        final reading = _source.reading;
                        final dial = AltitudeDial(
                          reading: reading,
                          feet: _preferences.feet,
                          dark: _preferences.dark,
                        );
                        return LayoutBuilder(
                          builder: (context, box) {
                            return SingleChildScrollView(
                              child: SizedBox(
                                height: max(540, box.maxHeight),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                          ),
                                          child: SizedBox.square(
                                            dimension: min(
                                              460,
                                              min(
                                                box.maxWidth - 48,
                                                max(540, box.maxHeight) - 240,
                                              ),
                                            ),
                                            child: dial,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _information(reading),
                                    const SizedBox(height: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _coordinate(double? value, bool latitude) {
    if (value == null || !value.isFinite) return latitude ? '纬度不可用' : '经度不可用';
    if (!_preferences.decimal) return coordinateDms(value, latitude: latitude);
    final direction = latitude
        ? (value >= 0 ? '北纬' : '南纬')
        : (value >= 0 ? '东经' : '西经');
    return '$direction ${value.abs().toStringAsFixed(6)}°';
  }

  Widget _information(AltimeterReading reading) {
    final pressure = _preferences.mmHg
        ? reading.pressureMmHg
        : reading.pressureHpa;
    final latitude = reading.latitudeDegrees,
        longitude = reading.longitudeDegrees;
    final sun = latitude == null || longitude == null
        ? const SunTimes(status: '位置不可用，请先获取定位')
        : calculateSunTimes(reading.capturedAt.toLocal(), latitude, longitude);
    String time(DateTime? value) => value == null
        ? '--'
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 188,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _preferences.dark
                    ? const Color(0xF022394F)
                    : const Color(0xF5FFFFFF),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: PageView(
                controller: _pages,
                onPageChanged: (v) => setState(() => _page = v),
                children: [
                  _card(Icons.location_on_outlined, '经纬度', [
                    _coordinate(latitude, true),
                    _coordinate(longitude, false),
                  ]),
                  _card(Icons.compress, '大气压力', [
                    pressure == null
                        ? '-- ${_preferences.mmHg ? 'mmHg' : 'hPa'}'
                        : '${pressure.toStringAsFixed(2)} ${_preferences.mmHg ? 'mmHg' : 'hPa'}',
                    reading.pressureStatus,
                  ]),
                  _card(
                    Icons.wb_twilight,
                    '日出日落 · 设备本地时区',
                    sun.status != null
                        ? [sun.status!]
                        : [
                            '日出  ${time(sun.sunrise)}',
                            '日落  ${time(sun.sunset)}',
                          ],
                  ),
                  _card(Icons.sensors, '定位与测高状态', [
                    reading.altitudeSource,
                    reading.verticalAccuracy == null
                        ? 'GPS 垂直精度：未知'
                        : 'GPS 垂直精度：±${reading.verticalAccuracy!.ceil()} 米',
                    '气压校准：${_source.calibrated ? '已校准' : '未校准'}',
                    '${latitude != null && longitude != null ? '定位有效' : '定位无效'} · ${reading.gpsStatus}',
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Semantics(
                label: '第 ${index + 1} 页',
                selected: index == _page,
                child: IconButton(
                  tooltip: '信息第 ${index + 1} 页',
                  onPressed: () => _pages.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  iconSize: 8,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.circle,
                    color: index == _page
                        ? coral
                        : (_preferences.dark
                              ? Colors.white24
                              : const Color(0xFFBACBD9)),
                  ),
                ),
              );
            }),
          ),
          if (hardwareUnavailableTest)
            const Text('硬件缺失测试', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _card(IconData icon, String title, List<String> lines) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 23, color: coral),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: lines.length > 2 ? 13 : 19,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

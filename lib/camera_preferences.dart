enum PhotoFormat { jpeg, png }

enum PhotoAspect { fourThree, wide, square }

enum WatermarkStyle { classic, bottomBar, minimal, instrument }

class CameraPreferences {
  const CameraPreferences({
    this.autoSave = false,
    this.grid = false,
    this.level = false,
    this.watermark = true,
    this.timerSeconds = 0,
    this.format = PhotoFormat.jpeg,
    this.aspect = PhotoAspect.fourThree,
    this.style = WatermarkStyle.classic,
  });

  final bool autoSave, grid, level, watermark;
  final int timerSeconds;
  final PhotoFormat format;
  final PhotoAspect aspect;
  final WatermarkStyle style;

  CameraPreferences copyWith({
    bool? autoSave,
    bool? grid,
    bool? level,
    bool? watermark,
    int? timerSeconds,
    PhotoFormat? format,
    PhotoAspect? aspect,
    WatermarkStyle? style,
  }) => CameraPreferences(
    autoSave: autoSave ?? this.autoSave,
    grid: grid ?? this.grid,
    level: level ?? this.level,
    watermark: watermark ?? this.watermark,
    timerSeconds: timerSeconds ?? this.timerSeconds,
    format: format ?? this.format,
    aspect: aspect ?? this.aspect,
    style: style ?? this.style,
  );

  Map<String, Object> toJson() => {
    'autoSave': autoSave,
    'grid': grid,
    'level': level,
    'watermark': watermark,
    'timerSeconds': timerSeconds,
    'format': format.name,
    'aspect': aspect.name,
    'style': style.name,
  };

  factory CameraPreferences.fromJson(Map<String, dynamic> value) {
    T choice<T extends Enum>(List<T> choices, String key, T fallback) =>
        choices.where((item) => item.name == value[key]).firstOrNull ??
        fallback;
    return CameraPreferences(
      autoSave: value['autoSave'] == true,
      grid: value['grid'] == true,
      level: value['level'] == true,
      watermark: value['watermark'] != false,
      timerSeconds:
          value['timerSeconds'] is int &&
              [0, 3, 10].contains(value['timerSeconds'])
          ? value['timerSeconds'] as int
          : 0,
      format: choice(PhotoFormat.values, 'format', PhotoFormat.jpeg),
      aspect: choice(PhotoAspect.values, 'aspect', PhotoAspect.fourThree),
      style: choice(WatermarkStyle.values, 'style', WatermarkStyle.classic),
    );
  }
}

extension PhotoAspectValue on PhotoAspect {
  double get landscapeRatio => switch (this) {
    PhotoAspect.fourThree => 4 / 3,
    PhotoAspect.wide => 16 / 9,
    PhotoAspect.square => 1,
  };
  String get label => switch (this) {
    PhotoAspect.fourThree => '4:3',
    PhotoAspect.wide => '16:9',
    PhotoAspect.square => '1:1',
  };
}

extension WatermarkStyleLabel on WatermarkStyle {
  String get label => switch (this) {
    WatermarkStyle.classic => '经典四角',
    WatermarkStyle.bottomBar => '底部信息栏',
    WatermarkStyle.minimal => '极简海拔',
    WatermarkStyle.instrument => '专业仪表',
  };
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class HomePreferences {
  const HomePreferences({
    this.dark = false,
    this.feet = false,
    this.decimal = false,
    this.mmHg = false,
    this.background,
  });
  final bool dark, feet, decimal, mmHg;
  final String? background;

  HomePreferences copyWith({
    bool? dark,
    bool? feet,
    bool? decimal,
    bool? mmHg,
    String? background,
    bool resetBackground = false,
  }) => HomePreferences(
    dark: dark ?? this.dark,
    feet: feet ?? this.feet,
    decimal: decimal ?? this.decimal,
    mmHg: mmHg ?? this.mmHg,
    background: resetBackground ? null : background ?? this.background,
  );

  Map<String, dynamic> toJson() => {
    'dark': dark,
    'feet': feet,
    'decimal': decimal,
    'mmHg': mmHg,
    'background': background,
  };
  factory HomePreferences.fromJson(Map<String, dynamic> json) =>
      HomePreferences(
        dark: json['dark'] == true,
        feet: json['feet'] == true,
        decimal: json['decimal'] == true,
        mmHg: json['mmHg'] == true,
        background:
            json['background'] is String &&
                RegExp(r'^background_\d+\.[a-zA-Z0-9]+$')
                    .hasMatch(json['background'] as String)
            ? json['background'] as String
            : null,
      );
}

/// Home settings and copies of explicitly selected photos stay in app storage.
class HomeStore {
  HomeStore({Directory? directory}) {
    _directory = directory;
  }
  Directory? _directory;
  Future<Directory> get directory async => _directory ??= await Directory(
    '${(await getApplicationSupportDirectory()).path}/home',
  ).create(recursive: true);

  Future<HomePreferences> load() async {
    final file = File('${(await directory).path}/preferences.json');
    if (!await file.exists()) return const HomePreferences();
    return HomePreferences.fromJson(
      jsonDecode(await file.readAsString(encoding: utf8))
          as Map<String, dynamic>,
    );
  }

  Future<void> save(HomePreferences preferences) async {
    final dir = await directory;
    final temporary = File('${dir.path}/preferences.tmp');
    await temporary.writeAsString(
      jsonEncode(preferences.toJson()),
      encoding: utf8,
      flush: true,
    );
    await temporary.rename('${dir.path}/preferences.json');
  }

  Future<String> importBackground(File source) async {
    // Unique names keep the currently displayed image intact if copying fails.
    final extension = source.path.split('.').last.toLowerCase();
    final suffix = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : 'img';
    final name = 'background_${DateTime.now().microsecondsSinceEpoch}.$suffix';
    await source.copy('${(await directory).path}/$name');
    return name;
  }

  Future<File?> backgroundFile(HomePreferences preferences) async {
    if (preferences.background == null) return null;
    final file = File('${(await directory).path}/${preferences.background}');
    return await file.exists() ? file : null;
  }
}

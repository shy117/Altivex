import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'camera_preferences.dart';

class PhotoRecord {
  const PhotoRecord({
    required this.id,
    required this.createdAt,
    this.photoName,
    this.originalName,
    this.photoUri,
    this.originalUri,
    this.saved = false,
    this.originalSaved = false,
    this.processingFailed = false,
  });
  final String id;
  final DateTime createdAt;
  final String? photoName, originalName, photoUri, originalUri;
  final bool saved, originalSaved, processingFailed;

  PhotoRecord copyWith({
    String? photoName,
    String? originalName,
    String? photoUri,
    String? originalUri,
    bool? saved,
    bool? originalSaved,
    bool? processingFailed,
    bool discardOriginal = false,
  }) => PhotoRecord(
    id: id,
    createdAt: createdAt,
    photoName: photoName ?? this.photoName,
    originalName: discardOriginal ? null : originalName ?? this.originalName,
    photoUri: photoUri ?? this.photoUri,
    originalUri: originalUri ?? this.originalUri,
    saved: saved ?? this.saved,
    originalSaved: originalSaved ?? this.originalSaved,
    processingFailed: processingFailed ?? this.processingFailed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'photoName': photoName,
    'originalName': originalName,
    'photoUri': photoUri,
    'originalUri': originalUri,
    'saved': saved,
    'originalSaved': originalSaved,
    'processingFailed': processingFailed,
  };

  factory PhotoRecord.fromJson(Map<String, dynamic> data) {
    final id = data['id'] as String;
    if (!RegExp(r'^\d+$').hasMatch(id)) throw const FormatException('照片记录编号无效');
    String? fileName(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! String ||
          !RegExp('^Altivex_$id(_original)?\\.(jpg|png)\$').hasMatch(value)) {
        throw const FormatException('照片文件名无效');
      }
      return value;
    }

    return PhotoRecord(
      id: id,
      createdAt: DateTime.parse(data['createdAt'] as String),
      photoName: fileName('photoName'),
      originalName: fileName('originalName'),
      photoUri: data['photoUri'] as String?,
      originalUri: data['originalUri'] as String?,
      saved: data['saved'] == true,
      originalSaved: data['originalSaved'] == true,
      processingFailed: data['processingFailed'] == true,
    );
  }
}

class PhotoStore {
  PhotoStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;
  late Directory root;
  final List<PhotoRecord> _records = [];
  List<PhotoRecord> get records => List.unmodifiable(_records);
  CameraPreferences preferences = const CameraPreferences();
  Future<void> _writes = Future.value();

  Future<void> load() async {
    preferences = const CameraPreferences();
    root = Directory('${(await _directory()).path}/AltivexCamera');
    await root.create(recursive: true);
    final settings = File('${root.path}/settings.json');
    if (await settings.exists()) {
      try {
        preferences = CameraPreferences.fromJson(
          jsonDecode(await settings.readAsString()) as Map<String, dynamic>,
        );
      } on FormatException {
        /* Invalid settings fall back to safe defaults. */
      } on TypeError {
        /* Unknown or incompatible settings use defaults. */
      }
    }
    _records.clear();
    await for (final entry in root.list()) {
      if (entry is! File || !RegExp(r'[/\\]\d+\.json$').hasMatch(entry.path)) {
        continue;
      }
      try {
        final record = PhotoRecord.fromJson(
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
        );
        if ((record.photoName != null &&
                await file(record.photoName!).exists()) ||
            (record.originalName != null &&
                await file(record.originalName!).exists())) {
          _records.add(record);
        }
      } on FormatException {
        /* Isolate corrupt metadata from healthy photos. */
      } on TypeError {
        /* Ignore unsupported metadata fields. */
      }
    }
    _sort();
  }

  File file(String name) {
    if (!RegExp(r'^Altivex_\d+(_original)?\.(jpg|png)$').hasMatch(name)) {
      throw const FormatException('禁止访问照片目录以外的文件');
    }
    return File('${root.path}/$name');
  }

  Future<void> _atomicJson(File target, Map<String, Object?> data) {
    final operation = _writes.then((_) async {
      final pending = File('${target.path}.tmp');
      await pending.writeAsString(
        jsonEncode(data),
        encoding: utf8,
        flush: true,
      );
      await pending.rename(target.path);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> savePreferences(CameraPreferences value) async {
    await _atomicJson(File('${root.path}/settings.json'), value.toJson());
    preferences = value;
  }

  Future<void> put(PhotoRecord value) async {
    PhotoRecord.fromJson(value.toJson());
    await _atomicJson(File('${root.path}/${value.id}.json'), value.toJson());
    _records.removeWhere((record) => record.id == value.id);
    _records.add(value);
    _sort();
  }

  void _sort() => _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> remove(PhotoRecord value) async {
    for (final name in {value.photoName, value.originalName}.nonNulls) {
      final photo = file(name);
      if (await photo.exists()) await photo.delete();
    }
    final metadata = File('${root.path}/${value.id}.json');
    if (await metadata.exists()) await metadata.delete();
    _records.removeWhere((record) => record.id == value.id);
  }
}

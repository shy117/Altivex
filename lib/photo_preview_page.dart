import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

import 'altimeter_controller.dart';
import 'altimeter_reading.dart';
import 'camera_access.dart';
import 'photo_watermark.dart';
import 'sharing.dart';
import 'measurement_hardware.dart';
import 'camera_preferences.dart';
import 'capture_performance.dart';
import 'camera_settings_sheet.dart';
import 'camera_aids.dart';
import 'photo_geometry.dart';
import 'photo_store.dart';
import 'photo_gallery.dart';
import 'photo_history_page.dart';

Future<List<CameraDescription>> enumerateDeviceCameras() =>
    hardwareUnavailableTest ? Future.value([]) : availableCameras();

class CameraZoomControls extends StatelessWidget {
  const CameraZoomControls({
    super.key,
    required this.minZoom,
    required this.maxZoom,
    required this.zoom,
    required this.onChanged,
    this.axis = Axis.horizontal,
    this.reverse = false,
  });

  final double minZoom, maxZoom, zoom;
  final ValueChanged<double>? onChanged;
  final Axis axis;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final stops = <double>[
      0.6,
      1,
      2,
      3.2,
    ].where((stop) => stop >= minZoom && stop <= maxZoom).toList();
    if (stops.isEmpty) return const SizedBox.shrink();
    var selected = 0;
    for (var i = 1; i < stops.length; i++) {
      if ((stops[i] - zoom).abs() < (stops[selected] - zoom).abs()) {
        selected = i;
      }
    }
    String label(double value) =>
        '${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(1)}×';
    return Flex(
      direction: axis,
      verticalDirection: reverse
          ? VerticalDirection.up
          : VerticalDirection.down,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stops.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: TextButton(
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged!(stops[i]),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 11),
                      shape: const CircleBorder(),
                      backgroundColor: i == selected
                          ? Colors.white24
                          : Colors.black54,
                      foregroundColor: i == selected
                          ? const Color(0xFFFFD166)
                          : Colors.white,
                    ),
                    child: Text(label(i == selected ? zoom : stops[i])),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CameraCaptureLayout extends StatelessWidget {
  const CameraCaptureLayout({
    super.key,
    required this.header,
    required this.viewfinder,
    required this.actions,
    this.zoom,
    this.controlsOnLeft = false,
    this.fullWidthPreview = false,
  });

  final List<Widget> header, actions;
  final Widget viewfinder;
  final Widget? zoom;
  final bool controlsOnLeft;
  final bool fullWidthPreview;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final axis = landscape ? Axis.vertical : Axis.horizontal;
    final reverse = landscape && !controlsOnLeft;
    final headerBar = Flex(
      direction: axis,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: reverse ? header.reversed.toList() : header,
    );
    final actionBar = SizedBox(
      width: landscape ? 120 : null,
      height: landscape ? null : 120,
      child: Flex(
        direction: axis,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: reverse ? actions.reversed.toList() : actions,
      ),
    );
    final parts = <Widget>[
      headerBar,
      Expanded(child: viewfinder),
      if (zoom != null) Center(child: zoom),
      actionBar,
    ];
    if (!landscape && fullWidthPreview) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: AspectRatio(aspectRatio: 9 / 16, child: viewfinder),
          ),
          Positioned(top: 0, left: 0, right: 0, child: headerBar),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [?zoom, actionBar],
            ),
          ),
        ],
      );
    }
    return Flex(
      direction: landscape ? Axis.horizontal : Axis.vertical,
      children: landscape && controlsOnLeft ? parts.reversed.toList() : parts,
    );
  }
}

class PhotoBrowserPage extends StatefulWidget {
  const PhotoBrowserPage({
    super.key,
    required this.records,
    required this.initialId,
    required this.store,
    required this.savePhoto,
  });
  final List<PhotoRecord> records;
  final String initialId;
  final PhotoStore store;
  final Future<bool> Function(PhotoRecord) savePhoto;
  @override
  State<PhotoBrowserPage> createState() => _PhotoBrowserPageState();
}

class _PhotoBrowserPageState extends State<PhotoBrowserPage> {
  late final PageController _pages = PageController(
    initialPage: widget.records
        .indexWhere((record) => record.id == widget.initialId)
        .clamp(0, widget.records.length - 1),
  );
  bool _locked = false;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _pages,
    physics: _locked ? const NeverScrollableScrollPhysics() : null,
    itemCount: widget.records.length,
    itemBuilder: (context, index) {
      final initial = widget.records[index];
      final record =
          widget.store.records
              .where((item) => item.id == initial.id)
              .firstOrNull ??
          initial;
      return CapturedPhotoPage(
        key: ValueKey(record.id),
        photo: widget.store.file(record.photoName ?? record.originalName!),
        recovery: record.processingFailed,
        saved: record.saved,
        positionLabel: widget.records.length > 1
            ? '${index + 1}/${widget.records.length}'
            : null,
        onInteractionLock: (locked) {
          if (mounted) setState(() => _locked = locked);
        },
        savePhoto: () => widget.savePhoto(record),
      );
    },
  );
}

class CapturedPhotoPage extends StatefulWidget {
  const CapturedPhotoPage({
    super.key,
    required this.photo,
    required this.savePhoto,
    this.saved = false,
    this.recovery = false,
    this.positionLabel,
    this.onInteractionLock,
  });

  final File photo;
  final Future<bool> Function() savePhoto;
  final bool saved;
  final bool recovery;
  final String? positionLabel;
  final ValueChanged<bool>? onInteractionLock;

  @override
  State<CapturedPhotoPage> createState() => _CapturedPhotoPageState();
}

class _CapturedPhotoPageState extends State<CapturedPhotoPage> {
  late bool _saved = widget.saved;
  bool _saving = false;
  bool _zoomed = false;
  final Set<int> _photoPointers = {};
  final _transform = TransformationController();
  void _updatePhotoLock() {
    widget.onInteractionLock?.call(
      _saving || _zoomed || _photoPointers.length > 1,
    );
  }

  void _photoPointerUp(PointerEvent event) {
    _photoPointers.remove(event.pointer);
    _updatePhotoLock();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    widget.onInteractionLock?.call(true);
    try {
      final saved = await widget.savePhoto();
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      widget.onInteractionLock?.call(_zoomed);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.recovery
              ? '处理失败 · 恢复文件'
              : '照片预览${widget.positionLabel == null ? '' : ' · ${widget.positionLabel}'}',
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          Builder(
            builder: (shareContext) => IconButton(
              tooltip: '分享',
              onPressed: _saving || widget.recovery
                  ? null
                  : () => shareContent(
                      shareContext,
                      photoPath: widget.photo.path,
                    ),
              icon: const Icon(Icons.share),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Listener(
                onPointerDown: (event) {
                  _photoPointers.add(event.pointer);
                  _updatePhotoLock();
                },
                onPointerUp: _photoPointerUp,
                onPointerCancel: _photoPointerUp,
                child: InteractiveViewer(
                  transformationController: _transform,
                  panEnabled: _zoomed,
                  onInteractionEnd: (_) {
                    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
                    setState(() => _zoomed = zoomed);
                    _updatePhotoLock();
                  },
                  child: Center(
                    child: Image.file(widget.photo, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _saving || _saved || widget.recovery
                        ? null
                        : _save,
                    icon: Icon(_saved ? Icons.check : Icons.save_alt),
                    label: Text(
                      _saved
                          ? '已保存'
                          : _saving
                          ? '保存中…'
                          : widget.recovery
                          ? '处理失败，恢复文件已保留'
                          : '保存相册',
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
}

class PhotoPreviewPage extends StatefulWidget {
  const PhotoPreviewPage({
    super.key,
    required this.source,
    this.enumerateCameras = enumerateDeviceCameras,
    this.requestCameraAccess = prepareCameraAccess,
    this.store,
  });
  final AltimeterController source;
  final Future<List<CameraDescription>> Function() enumerateCameras;
  final Future<bool> Function() requestCameraAccess;
  final PhotoStore? store;
  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0, _generation = 0;
  bool _busy = false, _initializing = false, _foreground = true;
  bool _permissionPending = false;
  Completer<void>? _foregroundSignal;
  String? _error;
  bool _permissionError = false;
  late final PhotoStore _store = widget.store ?? PhotoStore();
  final PhotoGallery _gallery = PhotoGallery();
  CameraPreferences _preferences = const CameraPreferences();
  bool _storeReady = false;
  bool _flashSupported = true, _changingFlash = false;
  FlashMode _flash = FlashMode.off;
  double _minExposure = 0, _maxExposure = 0, _exposure = 0;
  bool _settingExposure = false;
  Offset? _focus;
  Timer? _focusTimer;
  int _countdown = 0, _countdownGeneration = 0;
  int _routeDepth = 0;
  StreamSubscription<AccelerometerEvent>? _levelSubscription;
  double? _roll;
  bool _levelUnavailable = false;
  double _minZoom = 1, _maxZoom = 1, _zoom = 1;
  double _gestureStartZoom = 1;
  bool _settingZoom = false;
  AltimeterReading? _captureSnapshot;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadStore());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _countdownGeneration++;
    _focusTimer?.cancel();
    unawaited(_levelSubscription?.cancel());
    if (_foregroundSignal != null && !_foregroundSignal!.isCompleted) {
      _foregroundSignal!.complete();
    }
    unawaited(_release(_camera));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _countdownGeneration++;
      _countdown = 0;
      unawaited(_levelSubscription?.cancel());
      _levelSubscription = null;
      if (_permissionPending) {
        _foregroundSignal ??= Completer<void>();
        return;
      }
      _generation++;
      final previous = _camera;
      _camera = null;
      unawaited(_release(previous));
      if (mounted) setState(() => _initializing = false);
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_foregroundSignal != null && !_foregroundSignal!.isCompleted) {
        _foregroundSignal!.complete();
      }
      _foregroundSignal = null;
      if (!_busy && !_initializing && !_permissionPending && _routeDepth == 0) {
        unawaited(_initialize());
      }
    }
  }

  Future<void> _release(CameraController? camera) async {
    if (camera == null) return;
    try {
      await camera.dispose().timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Continue recovery even if the native driver does not respond. */
    }
  }

  Future<bool> _requestPermission() async {
    _permissionPending = true;
    try {
      final allowed = await widget.requestCameraAccess();
      // Android permission dialogs can pause the activity. Do not create another
      // permission request on resume while this one is still completing.
      if (!_foreground && mounted) {
        _foregroundSignal ??= Completer<void>();
        await _foregroundSignal!.future;
      }
      return allowed;
    } finally {
      _permissionPending = false;
    }
  }

  Future<void> _initialize() async {
    if (!mounted || !_foreground || _routeDepth > 0) return;
    final generation = ++_generation;
    setState(() {
      _initializing = true;
      _error = null;
      _permissionError = false;
    });
    final old = _camera;
    _camera = null;
    CameraController? candidate;
    try {
      await _release(old);
      final permitted = await _requestPermission();
      if (!mounted || generation != _generation || !_foreground) return;
      if (!permitted) {
        setState(() {
          _permissionError = true;
          _error = '相机权限不可用，请在系统设置中允许访问';
          _initializing = false;
        });
        return;
      }
      _cameras = await widget.enumerateCameras().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted || generation != _generation || !_foreground) return;
      if (_cameras.isEmpty) {
        setState(() {
          _error = '设备没有可用摄像头';
          _initializing = false;
        });
        return;
      }
      _cameraIndex %= _cameras.length;
      candidate = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
      );
      await candidate.initialize().timeout(const Duration(seconds: 15));
      double minZoom = 1, maxZoom = 1;
      try {
        minZoom = await candidate.getMinZoomLevel();
        maxZoom = await candidate.getMaxZoomLevel();
      } catch (_) {
        // Some camera drivers do not expose zoom; keep capture available.
      }
      double minExposure = 0, maxExposure = 0;
      try {
        minExposure = await candidate.getMinExposureOffset();
        maxExposure = await candidate.getMaxExposureOffset();
      } catch (_) {
        /* Exposure controls remain disabled for unsupported drivers. */
      }
      var flashSupported = true;
      try {
        await candidate.setFlashMode(_flash);
      } catch (_) {
        flashSupported = false;
      }
      if (!mounted || generation != _generation || !_foreground) {
        await _release(candidate);
        return;
      }
      setState(() {
        _camera = candidate;
        _minZoom = minZoom;
        _maxZoom = maxZoom < minZoom ? minZoom : maxZoom;
        _zoom = 1.0.clamp(_minZoom, _maxZoom);
        _minExposure = minExposure;
        _maxExposure = maxExposure;
        _exposure = 0;
        _focus = null;
        _flashSupported = flashSupported;
        _initializing = false;
      });
      _updateLevel();
    } on CameraException catch (e) {
      await _release(candidate);
      if (mounted && generation == _generation) {
        setState(() {
          _permissionError =
              e.code.contains('Access') || e.code.contains('Permission');
          _error = _permissionError ? '相机权限不可用，请在系统设置中允许访问' : '相机无法启动，请重试';
          _initializing = false;
        });
      }
    } catch (_) {
      await _release(candidate);
      if (mounted && generation == _generation) {
        setState(() {
          _error = '相机初始化失败或响应超时，请检查权限后重试';
          _permissionError = true;
          _initializing = false;
        });
      }
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _setZoom(double value) async {
    final camera = _camera;
    if (camera == null || _busy || _initializing) return;
    setState(() => _zoom = value.clamp(_minZoom, _maxZoom));
    if (_settingZoom) return;
    _settingZoom = true;
    try {
      // Coalesce slider events and never send overlapping native zoom requests.
      double applied;
      do {
        applied = _zoom;
        await camera.setZoomLevel(applied);
      } while (mounted && camera == _camera && !_busy && applied != _zoom);
    } catch (_) {
      if (mounted && camera == _camera) _notice('当前摄像头无法调整该倍数，请重试');
    } finally {
      _settingZoom = false;
    }
  }

  Future<void> _loadStore() async {
    try {
      await _store.load();
      if (!mounted) return;
      setState(() {
        _preferences = _store.preferences;
        _storeReady = true;
      });
      _updateLevel();
    } catch (_) {
      _notice('无法打开照片存储，请检查剩余空间后重新进入相机');
    }
  }

  Future<void> _changePreferences(CameraPreferences value) async {
    await _store.savePreferences(value);
    if (!mounted) return;
    setState(() => _preferences = value);
    _updateLevel();
  }

  void _updateLevel() {
    unawaited(_levelSubscription?.cancel());
    _levelSubscription = null;
    if (!_preferences.level || _camera == null || !_foreground) {
      _roll = null;
      return;
    }
    _levelUnavailable = false;
    _levelSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen(
          (event) {
            if (!mounted || !_foreground) return;
            final orientation = _camera?.value.deviceOrientation;
            final angle = switch (orientation) {
              DeviceOrientation.landscapeLeft => math.atan2(-event.y, event.x),
              DeviceOrientation.landscapeRight => math.atan2(event.y, -event.x),
              DeviceOrientation.portraitDown => math.atan2(-event.x, -event.y),
              _ => math.atan2(event.x, event.y),
            };
            setState(
              () => _roll = math.sqrt(event.x * event.x + event.y * event.y) < 1
                  ? null
                  : angle,
            );
          },
          onError: (Object _) {
            if (mounted) {
              setState(() {
                _levelUnavailable = true;
                _roll = null;
              });
            }
          },
        );
  }

  Future<void> _settings() async {
    if (!_storeReady) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: const Color(0xFF171C24),
      builder: (_) => CameraSettingsSheet(
        preferences: _preferences,
        reading: widget.source.reading,
        onChanged: _changePreferences,
      ),
    );
  }

  Future<void> _cycleFlash() async {
    final camera = _camera;
    if (camera == null || _changingFlash || _busy) return;
    setState(() => _changingFlash = true);
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await camera.setFlashMode(next);
      if (mounted && camera == _camera) setState(() => _flash = next);
    } catch (_) {
      _notice('当前镜头不支持该闪光模式');
    } finally {
      if (mounted) setState(() => _changingFlash = false);
    }
  }

  Future<void> _focusAt(Offset point, Size viewport) async {
    final camera = _camera;
    if (camera == null || _busy) return;
    if (!camera.value.focusPointSupported) {
      _notice('当前镜头不支持点击对焦');
      return;
    }
    final landscape = _isCameraLandscape(camera);
    final source = Size(
      landscape
          ? camera.value.previewSize!.width
          : camera.value.previewSize!.height,
      landscape
          ? camera.value.previewSize!.height
          : camera.value.previewSize!.width,
    );
    final crop = photoCrop(source, _preferences.aspect);
    final displayPoint = Offset(
      (point.dx / viewport.width).clamp(.02, .98),
      (point.dy / viewport.height).clamp(.02, .98),
    );
    final normalized = Offset(
      (crop.left + crop.width * displayPoint.dx) / source.width,
      (crop.top + crop.height * displayPoint.dy) / source.height,
    );
    try {
      await camera.setFocusMode(FocusMode.auto);
      await camera.setFocusPoint(normalized);
      if (camera.value.exposurePointSupported) {
        await camera.setExposurePoint(normalized);
      }
      await _changeExposure(0);
      if (!mounted || camera != _camera) return;
      setState(() => _focus = displayPoint);
      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _focus = null);
      });
    } catch (_) {
      _notice('对焦未完成，请重试');
    }
  }

  Future<void> _changeExposure(double value) async {
    final camera = _camera;
    if (camera == null || _busy || _maxExposure <= _minExposure) return;
    setState(() => _exposure = value.clamp(_minExposure, _maxExposure));
    if (_settingExposure) return;
    _settingExposure = true;
    try {
      double target;
      do {
        target = _exposure;
        await camera.setExposureOffset(target);
      } while (mounted && camera == _camera && target != _exposure);
    } catch (_) {
      _notice('当前镜头无法调整曝光');
    } finally {
      _settingExposure = false;
    }
  }

  PhotoRecord _currentRecord(PhotoRecord record) =>
      _store.records.where((item) => item.id == record.id).firstOrNull ??
      record;

  Future<bool> _saveRecord(
    PhotoRecord record, {
    bool notifySuccess = true,
  }) async {
    var current = _currentRecord(record);
    try {
      if (!current.saved) {
        final name = current.photoName;
        if (name == null) throw StateError('没有可保存的照片');
        final uri = await _gallery.save(_store.file(name));
        current = current.copyWith(saved: true, photoUri: uri);
        await _store.put(current);
      }
      if (notifySuccess) _notice('照片已保存到相册');
      return true;
    } catch (_) {
      _notice('相册保存未完成，照片已保留在拍摄记录中，可重试');
      return false;
    }
  }

  Future<void> _history() async {
    if (!_storeReady) return;
    _routeDepth++;
    final camera = _camera;
    _camera = null;
    await _release(camera);
    if (!mounted) return;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoHistoryPage(
            store: _store,
            gallery: _gallery,
            openPhoto: (record) => _showRecord(record, browse: true),
          ),
        ),
      );
    } finally {
      _routeDepth--;
      if (mounted) {
        setState(() {});
        if (_foreground) unawaited(_initialize());
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_busy ||
        !_storeReady ||
        _countdown > 0 ||
        camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture) {
      return;
    }
    final countdownGeneration = ++_countdownGeneration;
    for (var seconds = _preferences.timerSeconds; seconds > 0; seconds--) {
      setState(() => _countdown = seconds);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted ||
          !_foreground ||
          countdownGeneration != _countdownGeneration ||
          camera != _camera) {
        return;
      }
    }
    setState(() => _countdown = 0);
    // Freeze at the actual shutter, after the timer rather than at its start.
    final snapshot = widget.source.reading;
    final preferences = _preferences;
    final performance = CapturePerformance(preferences);
    setState(() => _busy = true);
    _captureSnapshot = snapshot;
    XFile? raw;
    PhotoRecord? record;
    var rawBackedUp = false;
    try {
      raw = await camera.takePicture();
      performance.mark('camera_capture');
      final id = snapshot.capturedAt.microsecondsSinceEpoch.toString();
      final originalName = 'Altivex_${id}_original.jpg';
      await File(raw.path).copy(_store.file(originalName).path);
      rawBackedUp = true;
      record = PhotoRecord(
        id: id,
        createdAt: snapshot.capturedAt,
        originalName: originalName,
        processingFailed: true,
      );
      await _store.put(record);
      performance.mark('backup_and_metadata');
      final name =
          'Altivex_$id.${preferences.format == PhotoFormat.jpeg ? 'jpg' : 'png'}';
      await PhotoWatermark().create(
        raw.path,
        snapshot,
        enabled: preferences.watermark,
        style: preferences.style,
        format: preferences.format,
        aspect: preferences.aspect,
        destination: _store.file(name),
        onStage: performance.mark,
      );
      record = record.copyWith(photoName: name, processingFailed: false);
      await _store.put(record);
      {
        final original = _store.file(originalName);
        record = record.copyWith(discardOriginal: true);
        await _store.put(record);
        try {
          await original.delete();
        } catch (_) {
          /* A completed photo must not fail because of cleanup. */
        }
      }
      if (!mounted) return;
      performance.mark('complete_metadata');
      setState(() {});
      if (preferences.autoSave) {
        await _saveRecord(record, notifySuccess: false);
        performance.mark('save_gallery');
        unawaited(performance.finish());
      } else if (_foreground) {
        setState(() => _busy = false);
        await _showRecord(record, performance: performance);
      }
    } catch (_) {
      unawaited(performance.finish(success: false));
      _notice(
        rawBackedUp
            ? '照片处理未完成，原图已保留在拍摄记录中'
            : raw == null
            ? '拍摄失败，请重试'
            : '无法保留照片，请检查存储空间；相机临时原图未清理',
      );
      if (mounted) setState(() {});
    } finally {
      if (raw != null && rawBackedUp) {
        try {
          await File(raw.path).delete();
        } catch (_) {
          /* Camera temporary file may already be removed by the platform. */
        }
      }
      if (mounted) {
        setState(() => _busy = false);
        if (_foreground &&
            _camera == null &&
            !_initializing &&
            _routeDepth == 0) {
          unawaited(_initialize());
        }
      }
    }
  }

  Future<void> _showRecord(
    PhotoRecord initialRecord, {
    bool browse = false,
    CapturePerformance? performance,
  }) async {
    if (!mounted) return;
    final record = _currentRecord(initialRecord);
    final name = record.photoName ?? record.originalName;
    if (name == null) return;
    _routeDepth++;
    final camera = _camera;
    _camera = null;
    await _release(camera);
    performance?.mark('release_camera');
    if (!mounted) return;
    try {
      final preview = Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoBrowserPage(
            records: browse ? _store.records : [record],
            initialId: record.id,
            store: _store,
            savePhoto: _saveRecord,
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        performance?.mark('open_preview');
        if (performance != null) unawaited(performance.finish());
      });
      await preview;
    } finally {
      _routeDepth--;
      if (mounted &&
          _foreground &&
          _routeDepth == 0 &&
          !_busy &&
          !_initializing) {
        unawaited(_initialize());
      }
    }
  }

  bool _isCameraLandscape(CameraController camera) =>
      const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ].contains(
        camera.value.lockedCaptureOrientation ?? camera.value.deviceOrientation,
      );

  Widget _viewfinder(CameraController camera) {
    final landscape = _isCameraLandscape(camera);
    final ratio = landscape
        ? _preferences.aspect.landscapeRatio
        : 1 / _preferences.aspect.landscapeRatio;
    final previewRatio = landscape
        ? camera.value.aspectRatio
        : 1 / camera.value.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final previewWidth = math.max(
              bounds.maxWidth,
              bounds.maxHeight * previewRatio,
            );
            final previewHeight = previewWidth / previewRatio;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  _focusAt(details.localPosition, bounds.biggest),
              onScaleStart: (_) => _gestureStartZoom = _zoom,
              onScaleUpdate: (details) {
                if (details.pointerCount >= 2) {
                  unawaited(_setZoom(_gestureStartZoom * details.scale));
                } else if (_focus != null) {
                  unawaited(
                    _changeExposure(
                      _exposure - details.focalPointDelta.dy / 80,
                    ),
                  );
                }
              },
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OverflowBox(
                      maxWidth: previewWidth,
                      minWidth: previewWidth,
                      maxHeight: previewHeight,
                      minHeight: previewHeight,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: CameraPreview(camera),
                      ),
                    ),
                    IgnorePointer(
                      child: ListenableBuilder(
                        listenable: widget.source,
                        builder: (context, _) => WatermarkOverlay(
                          _busy && _captureSnapshot != null
                              ? _captureSnapshot!
                              : widget.source.reading,
                          enabled: _preferences.watermark,
                          style: _preferences.style,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: CameraAidPainter(
                          grid: _preferences.grid,
                          focus: _focus,
                          roll: _preferences.level ? _roll : null,
                          exposure: _exposure,
                          showExposure: _maxExposure > _minExposure,
                        ),
                      ),
                    ),
                    if (_preferences.level && _levelUnavailable)
                      const Positioned(
                        top: 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text('水平仪不可用', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return camera == null
        ? _buildPage(context)
        : ValueListenableBuilder<CameraValue>(
            valueListenable: camera,
            builder: (context, _, _) => _buildPage(context),
          );
  }

  Widget _buildPage(BuildContext context) => PopScope(
    canPop: !_busy,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _countdownGeneration++;
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CameraCaptureLayout(
          fullWidthPreview: _preferences.aspect == PhotoAspect.wide,
          controlsOnLeft:
              _camera?.value.deviceOrientation ==
              DeviceOrientation.landscapeRight,
          header: [
            IconButton(
              tooltip: '返回',
              color: Colors.white,
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: '闪光灯',
              color: Colors.white,
              onPressed:
                  _busy ||
                      _countdown > 0 ||
                      !_flashSupported ||
                      _camera == null ||
                      _changingFlash
                  ? null
                  : _cycleFlash,
              icon: Icon(switch (_flash) {
                FlashMode.off => Icons.flash_off,
                FlashMode.auto => Icons.flash_auto,
                _ => Icons.flash_on,
              }),
            ),
            IconButton(
              tooltip: '水印开关',
              color: Colors.white,
              onPressed: _busy || !_storeReady || _countdown > 0
                  ? null
                  : () async {
                      try {
                        await _changePreferences(
                          _preferences.copyWith(
                            watermark: !_preferences.watermark,
                          ),
                        );
                      } catch (_) {
                        _notice('水印设置保存失败');
                      }
                    },
              icon: Icon(
                _preferences.watermark
                    ? Icons.water_drop
                    : Icons.water_drop_outlined,
              ),
            ),
            IconButton(
              tooltip: '相机设置',
              color: Colors.white,
              onPressed: _busy || _countdown > 0 || !_storeReady
                  ? null
                  : _settings,
              icon: const Icon(Icons.tune),
            ),
          ],
          viewfinder: Stack(
            fit: StackFit.expand,
            children: [
              if (_camera != null && _camera!.value.isInitialized)
                _viewfinder(_camera!)
              else
                Center(
                  child: _initializing
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.no_photography_outlined,
                              size: 48,
                              color: Colors.white54,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _error ?? '相机不可用',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              onPressed: _initialize,
                              child: const Text('重试相机'),
                            ),
                            if (_permissionError)
                              TextButton(
                                onPressed: Geolocator.openAppSettings,
                                child: const Text('打开应用设置'),
                              ),
                          ],
                        ),
                ),
              if (_busy)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在处理照片…'),
                      ],
                    ),
                  ),
                ),
              if (_countdown > 0)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          fontSize: 64,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 8)],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _countdownGeneration++;
                          _countdown = 0;
                        }),
                        child: const Text('取消定时'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          zoom: _camera != null && _maxZoom > _minZoom
              ? CameraZoomControls(
                  reverse:
                      MediaQuery.orientationOf(context) ==
                          Orientation.landscape &&
                      _camera?.value.deviceOrientation !=
                          DeviceOrientation.landscapeRight,
                  axis:
                      MediaQuery.orientationOf(context) == Orientation.landscape
                      ? Axis.vertical
                      : Axis.horizontal,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  zoom: _zoom,
                  onChanged: _busy || _initializing || _countdown > 0
                      ? null
                      : _setZoom,
                )
              : null,
          actions: [
            IconButton(
              tooltip: '拍摄记录',
              onPressed: _busy || !_storeReady || _countdown > 0
                  ? null
                  : _history,
              icon: _storeReady && _store.records.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        _store.file(
                          _store.records.first.photoName ??
                              _store.records.first.originalName!,
                        ),
                        width: 38,
                        height: 38,
                        cacheWidth: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.photo_outlined),
                      ),
                    )
                  : const Icon(Icons.photo_outlined),
            ),
            IconButton(
              tooltip: '拍照',
              iconSize: 68,
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
              onPressed:
                  _busy || _camera == null || !_storeReady || _countdown > 0
                  ? null
                  : _capture,
              icon: Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '切换摄像头',
              onPressed:
                  _busy ||
                      _initializing ||
                      _countdown > 0 ||
                      _cameras.length < 2
                  ? null
                  : () {
                      final current = _cameras[_cameraIndex].lensDirection;
                      final target = current == CameraLensDirection.front
                          ? CameraLensDirection.back
                          : CameraLensDirection.front;
                      final opposite = _cameras.indexWhere(
                        (camera) => camera.lensDirection == target,
                      );
                      _cameraIndex = opposite >= 0
                          ? opposite
                          : (_cameraIndex + 1) % _cameras.length;
                      unawaited(_initialize());
                    },
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          ],
        ),
      ),
    ),
  );
}

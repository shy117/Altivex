import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';

import 'altimeter_controller.dart';
import 'altimeter_reading.dart';
import 'camera_access.dart';
import 'photo_watermark.dart';
import 'sharing.dart';
import 'measurement_hardware.dart';

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
  });

  final List<Widget> header, actions;
  final Widget viewfinder;
  final Widget? zoom;
  final bool controlsOnLeft;

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
    return Flex(
      direction: landscape ? Axis.horizontal : Axis.vertical,
      children: landscape && controlsOnLeft ? parts.reversed.toList() : parts,
    );
  }
}

class CapturedPhotoPage extends StatefulWidget {
  const CapturedPhotoPage({
    super.key,
    required this.photo,
    required this.savePhoto,
    this.saved = false,
  });

  final File photo;
  final Future<bool> Function() savePhoto;
  final bool saved;

  @override
  State<CapturedPhotoPage> createState() => _CapturedPhotoPageState();
}

class _CapturedPhotoPageState extends State<CapturedPhotoPage> {
  late bool _saved = widget.saved;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
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
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('照片预览'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          Builder(
            builder: (shareContext) => IconButton(
              tooltip: '分享',
              onPressed: _saving
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
              child: InteractiveViewer(
                child: Center(
                  child: Image.file(widget.photo, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _saving || _saved ? null : _save,
                    icon: Icon(_saved ? Icons.check : Icons.save_alt),
                    label: Text(
                      _saved
                          ? '已保存'
                          : _saving
                          ? '保存中…'
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
  });
  final AltimeterController source;
  final Future<List<CameraDescription>> Function() enumerateCameras;
  final Future<bool> Function() requestCameraAccess;
  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0, _generation = 0;
  bool _busy = false,
      _initializing = false,
      _topWatermark = true,
      _foreground = true;
  bool _permissionPending = false;
  Completer<void>? _foregroundSignal;
  String? _error;
  bool _permissionError = false;
  File? _lastPhoto;
  final Set<String> _savedPhotos = {};
  double _minZoom = 1, _maxZoom = 1, _zoom = 1;
  double _gestureStartZoom = 1;
  bool _settingZoom = false;
  AltimeterReading? _captureSnapshot;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
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
      if (!_busy && !_initializing && !_permissionPending) {
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
    if (!mounted || !_foreground) return;
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
        ResolutionPreset.high,
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
      if (!mounted || generation != _generation || !_foreground) {
        await _release(candidate);
        return;
      }
      setState(() {
        _camera = candidate;
        _minZoom = minZoom;
        _maxZoom = maxZoom < minZoom ? minZoom : maxZoom;
        _zoom = 1.0.clamp(_minZoom, _maxZoom);
        _initializing = false;
      });
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

  Future<bool> _save(File photo) async {
    if (_savedPhotos.contains(photo.path)) return true;
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        _notice('相册权限未授权，照片已保留在应用内，可重试保存或分享');
        return false;
      }
      await Gal.putImage(photo.path);
      _savedPhotos.add(photo.path);
      _notice('水印照片已保存到相册');
      return true;
    } catch (_) {
      _notice('相册保存失败，照片已保留在应用内，可重试保存或分享');
      return false;
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_busy ||
        camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture) {
      return;
    }
    // Freeze all values at shutter invocation, before any asynchronous camera/encoding work.
    final snapshot = widget.source.reading;
    final topWatermark = _topWatermark;
    setState(() => _busy = true);
    _captureSnapshot = snapshot;
    XFile? raw;
    try {
      raw = await camera.takePicture();
      final photo = await PhotoWatermark().create(
        raw.path,
        snapshot,
        topWatermark: topWatermark,
      );
      if (!mounted) return;
      setState(() {
        _lastPhoto = photo;
      });
      if (mounted && _foreground) await _showPhoto(photo);
    } catch (_) {
      _notice('拍摄或水印生成失败，请重试');
    } finally {
      if (raw != null) {
        try {
          await File(raw.path).delete();
        } catch (_) {
          /* Camera temporary file may already be removed by the platform. */
        }
      }
      if (mounted) {
        setState(() => _busy = false);
        if (_foreground && _camera == null) unawaited(_initialize());
      }
    }
  }

  Future<void> _showPhoto(File photo) async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CapturedPhotoPage(
          photo: photo,
          saved: _savedPhotos.contains(photo.path),
          savePhoto: () => _save(photo),
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
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CameraCaptureLayout(
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
              tooltip: '顶部水印开关',
              color: Colors.white,
              onPressed: _busy
                  ? null
                  : () => setState(() => _topWatermark = !_topWatermark),
              icon: Icon(
                _topWatermark ? Icons.water_drop : Icons.water_drop_outlined,
              ),
            ),
          ],
          viewfinder: Stack(
            fit: StackFit.expand,
            children: [
              if (_camera != null && _camera!.value.isInitialized)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) => _gestureStartZoom = _zoom,
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        unawaited(_setZoom(_gestureStartZoom * details.scale));
                      }
                    },
                    child: CameraPreview(
                      _camera!,
                      child: IgnorePointer(
                        child: ListenableBuilder(
                          listenable: widget.source,
                          builder: (context, _) => CustomPaint(
                            painter: PhotoWatermarkPainter(
                              _busy && _captureSnapshot != null
                                  ? _captureSnapshot!
                                  : widget.source.reading,
                              topWatermark: _topWatermark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
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
                  onChanged: _busy || _initializing ? null : _setZoom,
                )
              : null,
          actions: [
            IconButton(
              tooltip: '上一张照片',
              onPressed: _busy || _lastPhoto == null
                  ? null
                  : () => _showPhoto(_lastPhoto!),
              icon: const Icon(Icons.photo_outlined),
            ),
            IconButton.filled(
              tooltip: '拍照',
              iconSize: 48,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF47742),
              ),
              onPressed: _busy || _camera == null ? null : _capture,
              icon: const Icon(Icons.circle_outlined),
            ),
            IconButton(
              tooltip: '切换摄像头',
              onPressed: _busy || _initializing || _cameras.length < 2
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

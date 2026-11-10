import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/camera_service.dart';

/// Concrete implementation of [CameraService] backed by the Flutter `camera`
/// and `permission_handler` plugins.
class CameraServiceImpl implements CameraService {
  CameraServiceImpl({
    Future<List<CameraDescription>> Function()? availableCamerasLoader,
  }) : _availableCamerasLoader = availableCamerasLoader ?? availableCameras;

  final Future<List<CameraDescription>> Function() _availableCamerasLoader;

  CameraController? _controller;
  CameraDescription? _currentCamera;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;
  bool _isStreaming = false;

  @override
  CameraPermissionStatus get permissionStatus => _permissionStatus;

  @override
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  @override
  bool get isStreaming => _isStreaming;

  @override
  CameraController? get controller => _controller;

  @override
  CameraDescription? get currentCamera => _currentCamera;

  @override
  Future<CameraPermissionStatus> checkPermission() async {
    final PermissionStatus status = await Permission.camera.status;
    _permissionStatus = _mapPermissionStatus(status);
    return _permissionStatus;
  }

  @override
  Future<CameraPermissionStatus> requestPermission() async {
    final PermissionStatus status = await Permission.camera.request();
    _permissionStatus = _mapPermissionStatus(status);
    return _permissionStatus;
  }

  @override
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  @override
  Future<void> initialize({
    required ResolutionPreset resolutionPreset,
    CameraLensDirection lensDirection = CameraLensDirection.front,
  }) async {
    await checkPermission();
    if (_permissionStatus != CameraPermissionStatus.granted) {
      final CameraPermissionStatus requestResult = await requestPermission();
      if (requestResult != CameraPermissionStatus.granted) {
        throw StateError('Camera permission not granted ($requestResult)');
      }
    }

    final List<CameraDescription> cameras = await _availableCamerasLoader();
    if (cameras.isEmpty) {
      throw StateError('No cameras detected on this device');
    }

    CameraDescription selectedCamera = cameras.first;
    for (final CameraDescription cam in cameras) {
      if (cam.lensDirection == lensDirection) {
        selectedCamera = cam;
        break;
      }
    }
    _currentCamera = selectedCamera;

    // Platform format: NV21 on Android, BGRA8888 on iOS
    final ImageFormatGroup targetFormat =
        defaultTargetPlatform == TargetPlatform.android
        ? ImageFormatGroup.nv21
        : ImageFormatGroup.bgra8888;

    await _disposeController();

    try {
      _controller = CameraController(
        selectedCamera,
        resolutionPreset,
        enableAudio: false,
        imageFormatGroup: targetFormat,
      );
      await _controller!.initialize();
    } catch (_) {
      // Fallback to YUV420 on Android if NV21 initialization is unsupported
      if (defaultTargetPlatform == TargetPlatform.android &&
          targetFormat == ImageFormatGroup.nv21) {
        _controller = CameraController(
          selectedCamera,
          resolutionPreset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        await _controller!.initialize();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> startImageStream(
    void Function(CameraImage image) onFrame,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw StateError('CameraController is not initialized');
    }
    if (_isStreaming) return;

    _isStreaming = true;
    await _controller!.startImageStream((CameraImage image) {
      if (_isStreaming) {
        onFrame(image);
      }
    });
  }

  @override
  Future<void> stopImageStream() async {
    if (!_isStreaming || _controller == null) return;
    _isStreaming = false;
    try {
      await _controller!.stopImageStream();
    } catch (_) {
      // Ignore if stream already stopped
    }
  }

  @override
  Future<void> pausePreview() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.pausePreview();
    }
  }

  @override
  Future<void> resumePreview() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.resumePreview();
    }
  }

  @override
  Future<void> lockExposure() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.setExposureMode(ExposureMode.locked);
      } catch (_) {
        // Fallback gracefully on devices without exposure lock capability
      }
    }
  }

  @override
  Future<void> unlockExposure() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (_) {
        // Fallback gracefully
      }
    }
  }

  @override
  Future<void> dispose() async {
    _isStreaming = false;
    try {
      await stopImageStream();
    } catch (_) {}
    await _disposeController();
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      final CameraController ctrl = _controller!;
      _controller = null;
      try {
        await ctrl.dispose();
      } catch (_) {}
    }
  }

  CameraPermissionStatus _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return CameraPermissionStatus.granted;
      case PermissionStatus.denied:
        return CameraPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return CameraPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return CameraPermissionStatus.restricted;
      case PermissionStatus.provisional:
        return CameraPermissionStatus.unknown;
    }
  }
}

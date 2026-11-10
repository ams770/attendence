import 'package:camera/camera.dart';

/// Camera authorization permission states.
enum CameraPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

/// Abstract contract managing device camera lifecycle, hardware selection,
/// permissions, and real-time frame streaming.
abstract interface class CameraService {
  CameraPermissionStatus get permissionStatus;
  bool get isInitialized;
  bool get isStreaming;
  CameraController? get controller;
  CameraDescription? get currentCamera;

  /// Checks current camera permission status without triggering a prompt.
  Future<CameraPermissionStatus> checkPermission();

  /// Requests camera permission from the operating system.
  Future<CameraPermissionStatus> requestPermission();

  /// Opens the device app settings screen when permission is permanently denied.
  Future<bool> openSettings();

  /// Initializes the camera hardware selecting the desired lens direction and resolution.
  Future<void> initialize({
    required ResolutionPreset resolutionPreset,
    CameraLensDirection lensDirection = CameraLensDirection.front,
  });

  /// Starts streaming raw camera frames to the given listener callback.
  Future<void> startImageStream(void Function(CameraImage image) onFrame);

  /// Stops the active camera frame stream.
  Future<void> stopImageStream();

  /// Pauses the camera preview when the app is paused or hidden.
  Future<void> pausePreview();

  /// Resumes the camera preview when returning to the foreground.
  Future<void> resumePreview();

  /// Locks camera exposure mode to prevent auto-compensation during flash tests.
  Future<void> lockExposure();

  /// Unlocks camera exposure mode back to auto.
  Future<void> unlockExposure();

  /// Releases the camera controller and hardware resources.
  Future<void> dispose();
}

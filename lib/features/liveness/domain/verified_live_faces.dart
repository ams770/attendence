part of 'liveness_session.dart';

/// Single high-quality aligned 112x112 face crop collected during the finalizing phase.
class VerifiedLiveFaceCrop {
  const VerifiedLiveFaceCrop({
    required this.rgbBytes,
    required this.sharpness,
    required this.width,
    required this.height,
    required this.trackingId,
    required this.timestamp,
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
  });

  /// 112x112 uncompressed 24-bit RGB pixel buffer.
  final Uint8List rgbBytes;

  /// Laplacian variance sharpness score of the crop.
  final double sharpness;

  /// Width in pixels (standard 112).
  final int width;

  /// Height in pixels (standard 112).
  final int height;

  /// Face tracking identifier.
  final int trackingId;

  /// Frame capture timestamp.
  final DateTime timestamp;

  /// Head yaw rotation at time of capture.
  final double yaw;

  /// Head pitch rotation at time of capture.
  final double pitch;

  /// Head roll rotation at time of capture.
  final double roll;
}

/// Tamper-resistant collection of verified live face crops bound to a succeeded session.
///
/// Notice: The constructor is private (`VerifiedLiveFaces._`). Instances can ONLY be
/// manufactured by [LivenessSession] upon completing all verification layers.
/// The type system strictly prevents recognition from consuming arbitrary crops.
class VerifiedLiveFaces {
  VerifiedLiveFaces._({
    required List<VerifiedLiveFaceCrop> crops,
    required this.trackingId,
    required this.sessionId,
    required this.verifiedAt,
  }) : crops = List<VerifiedLiveFaceCrop>.unmodifiable(crops);

  /// Visible strictly for unit tests requiring synthetic verified faces.
  @visibleForTesting
  factory VerifiedLiveFaces.forTesting({
    required List<VerifiedLiveFaceCrop> crops,
    int trackingId = 1,
    String sessionId = 'test-session',
    DateTime? verifiedAt,
  }) {
    return VerifiedLiveFaces._(
      crops: crops,
      trackingId: trackingId,
      sessionId: sessionId,
      verifiedAt: verifiedAt ?? DateTime(2026, 1, 1),
    );
  }

  /// Up to 3 sharpest aligned crops selected by the session.
  final List<VerifiedLiveFaceCrop> crops;

  /// The face tracking ID validated across all session phases.
  final int trackingId;

  /// Unique identifier of the verification session that approved these crops.
  final String sessionId;

  /// Timestamp when verification succeeded.
  final DateTime verifiedAt;
}

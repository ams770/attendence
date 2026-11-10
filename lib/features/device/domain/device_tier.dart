import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../ml/domain/model_registry.dart';

/// Performance tiers categorizing device capabilities for real-time AI processing.
enum DeviceTier {
  low,
  mid,
  high;

  static DeviceTier fromName(String name) {
    for (final DeviceTier tier in DeviceTier.values) {
      if (tier.name.toLowerCase() == name.toLowerCase()) {
        return tier;
      }
    }
    return DeviceTier.mid;
  }
}

/// SFace model precision variant preference.
enum SFaceVariantPreference {
  floatModel,
  int8Model;

  String get assetPath {
    switch (this) {
      case SFaceVariantPreference.int8Model:
        return 'assets/ai/face_recognition_sface_2021dec_int8.onnx';
      case SFaceVariantPreference.floatModel:
        return ModelRegistry.sFace.assetPath;
    }
  }
}

/// Processing parameters and resource budgets assigned to a specific [DeviceTier].
@immutable
class TierProfile {
  const TierProfile({
    required this.tier,
    required this.cameraPreset,
    required this.analysisFps,
    required this.passiveFrameCount,
    required this.modelsUsed,
    required this.flashChallengeDefault,
    required this.sfaceVariantPreference,
    required this.hasInt8Model,
  });

  final DeviceTier tier;
  final ResolutionPreset cameraPreset;
  final double analysisFps;
  final int passiveFrameCount;
  final List<String> modelsUsed;
  final bool flashChallengeDefault;
  final SFaceVariantPreference sfaceVariantPreference;
  final bool hasInt8Model;

  /// Returns the concrete SFace asset path based on variant preference and asset availability.
  String get sfaceModelPath =>
      (sfaceVariantPreference == SFaceVariantPreference.int8Model &&
          hasInt8Model)
      ? SFaceVariantPreference.int8Model.assetPath
      : SFaceVariantPreference.floatModel.assetPath;

  /// Returns the effective SFace model identifier based on tier preference and asset availability.
  String get effectiveSFaceModelName =>
      (sfaceVariantPreference == SFaceVariantPreference.int8Model &&
          hasInt8Model)
      ? 'face_recognition_sface_2021dec_int8'
      : ModelRegistry.sFace.name;

  /// Creates a predefined [TierProfile] for the specified [tier].
  factory TierProfile.fromTier(DeviceTier tier, {bool hasInt8Model = false}) {
    switch (tier) {
      case DeviceTier.low:
        return TierProfile(
          tier: tier,
          cameraPreset: ResolutionPreset.medium,
          analysisFps: 10.0,
          passiveFrameCount: 5,
          modelsUsed: <String>[
            ModelRegistry.miniFASNetV2.name,
            ModelRegistry.sFace.name,
          ],
          flashChallengeDefault: false,
          sfaceVariantPreference: hasInt8Model
              ? SFaceVariantPreference.int8Model
              : SFaceVariantPreference.floatModel,
          hasInt8Model: hasInt8Model,
        );

      case DeviceTier.mid:
        return TierProfile(
          tier: tier,
          cameraPreset: ResolutionPreset.medium,
          analysisFps: 15.0,
          passiveFrameCount: 8,
          modelsUsed: <String>[
            ModelRegistry.miniFASNetV1SE.name,
            ModelRegistry.miniFASNetV2.name,
            ModelRegistry.sFace.name,
          ],
          flashChallengeDefault: true,
          sfaceVariantPreference: SFaceVariantPreference.floatModel,
          hasInt8Model: hasInt8Model,
        );

      case DeviceTier.high:
        return TierProfile(
          tier: tier,
          cameraPreset: ResolutionPreset.high,
          analysisFps: 20.0,
          passiveFrameCount: 12,
          modelsUsed: <String>[
            ModelRegistry.miniFASNetV1SE.name,
            ModelRegistry.miniFASNetV2.name,
            ModelRegistry.sFace.name,
          ],
          flashChallengeDefault: true,
          sfaceVariantPreference: SFaceVariantPreference.floatModel,
          hasInt8Model: hasInt8Model,
        );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TierProfile &&
        other.tier == tier &&
        other.cameraPreset == cameraPreset &&
        other.analysisFps == analysisFps &&
        other.passiveFrameCount == passiveFrameCount &&
        listEquals(other.modelsUsed, modelsUsed) &&
        other.flashChallengeDefault == flashChallengeDefault &&
        other.sfaceVariantPreference == sfaceVariantPreference &&
        other.hasInt8Model == hasInt8Model;
  }

  @override
  int get hashCode => Object.hash(
    tier,
    cameraPreset,
    analysisFps,
    passiveFrameCount,
    Object.hashAll(modelsUsed),
    flashChallengeDefault,
    sfaceVariantPreference,
    hasInt8Model,
  );
}

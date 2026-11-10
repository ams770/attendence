import 'package:attendence/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('default values are set correctly', () {
      const AppConfig config = AppConfig();

      expect(config.sessionTimeout, const Duration(seconds: 30));
      expect(config.perChallengeTimeout, const Duration(seconds: 6));
      expect(config.failureLimit, 3);
      expect(config.lockoutDuration, const Duration(seconds: 60));
      expect(config.passiveThreshold, 0.85);
      expect(config.passivePassingFrameRatio, 0.75);
      expect(config.passiveHardFloor, 0.40);
      expect(config.passiveBoxExpansion, 1.0);
      expect(config.passivePreprocessConfig.realClassIndex, 1);
      expect(config.passivePreprocessConfig.v2CropScale, 2.7);
      expect(config.passivePreprocessConfig.v1SeCropScale, 4.0);
      expect(config.recognitionThreshold, 0.363);
      expect(config.recognitionMargin, 0.05);
      expect(config.attendanceCooldown, const Duration(seconds: 60));
      expect(config.qualityMinFaceWidthRatio, 0.25);
      expect(config.qualityMaxYaw, 15.0);
      expect(config.qualityMaxPitch, 15.0);
      expect(config.qualityMaxRoll, 15.0);
      expect(config.qualityMinSharpness, 50.0);
      expect(config.qualityMinBrightness, 40.0);
      expect(config.qualityMaxBrightness, 220.0);
      expect(config.qualityMaxNearSaturatedRatio, 0.10);
      expect(config.ovalCornerTolerance, 1.25);
      expect(config.ovalCardinalTolerance, 1.08);
      expect(config.challengeBlinkEyeOpenThreshold, 0.60);
      expect(config.challengeBlinkEyeClosedThreshold, 0.25);
      expect(config.challengeBlinkMinClosedFrames, 2);
      expect(config.challengeBlinkMinOpenFrames, 2);
      expect(config.challengeNeutralMaxYaw, 10.0);
      expect(config.challengeNeutralMaxPitch, 12.0);
      expect(config.challengeNeutralMaxRoll, 12.0);
      expect(config.challengeNeutralMinFrames, 3);
      expect(config.challengeTurnYawThreshold, 20.0);
      expect(config.challengeTurnStartMaxYaw, 10.0);
      expect(config.challengeTurnHysteresis, 4.0);
      expect(config.challengeTurnMinFrames, 3);
      expect(config.yawSignForUserLeft, 1.0);
      expect(config.challengeSmileFloorThreshold, 0.30);
      expect(config.challengeSmileProbabilityThreshold, 0.80);
      expect(config.challengeSmileMinFrames, 3);
      expect(config.challengeNodPitchThreshold, 15.0);
      expect(config.faceLostGracePeriod, const Duration(milliseconds: 700));
      expect(config.temporalConfidenceThreshold, 0.50);
      expect(config.temporalMicroMotionWeight, 0.35);
      expect(config.temporalLoopWeight, 0.35);
      expect(config.temporalRigidityWeight, 0.30);
      expect(config.temporalWindowSize, 25);
      expect(config.flashChallengeEnabled, isFalse);
      expect(config.flashColorDwellDuration, const Duration(milliseconds: 350));
      expect(config.flashCorrelationThreshold, 0.35);
      expect(config.flashMinBrightness, 30.0);
      expect(config.flashMaxBrightness, 220.0);
    });

    test('copyWith updates specified fields only', () {
      const AppConfig initial = AppConfig();

      final AppConfig updated = initial.copyWith(
        sessionTimeout: const Duration(seconds: 45),
        failureLimit: 5,
        passiveThreshold: 0.90,
        recognitionThreshold: 0.40,
        qualityMinFaceWidthRatio: 0.30,
        qualityMaxNearSaturatedRatio: 0.15,
        ovalCardinalTolerance: 1.15,
        challengeTurnYawThreshold: 25.0,
        yawSignForUserLeft: -1.0,
        flashChallengeEnabled: true,
      );

      expect(updated.sessionTimeout, const Duration(seconds: 45));
      expect(updated.failureLimit, 5);
      expect(updated.passiveThreshold, 0.90);
      expect(updated.recognitionThreshold, 0.40);
      expect(updated.qualityMinFaceWidthRatio, 0.30);
      expect(updated.qualityMaxNearSaturatedRatio, 0.15);
      expect(updated.ovalCardinalTolerance, 1.15);
      expect(updated.challengeTurnYawThreshold, 25.0);
      expect(updated.yawSignForUserLeft, -1.0);
      expect(updated.flashChallengeEnabled, isTrue);

      // Unchanged fields maintain initial values
      expect(updated.perChallengeTimeout, initial.perChallengeTimeout);
      expect(updated.lockoutDuration, initial.lockoutDuration);
      expect(
        updated.passivePassingFrameRatio,
        initial.passivePassingFrameRatio,
      );
      expect(updated.passiveHardFloor, initial.passiveHardFloor);
      expect(updated.recognitionMargin, initial.recognitionMargin);
      expect(updated.attendanceCooldown, initial.attendanceCooldown);
      expect(updated.qualityMaxYaw, initial.qualityMaxYaw);
      expect(updated.qualityMaxPitch, initial.qualityMaxPitch);
      expect(updated.qualityMaxRoll, initial.qualityMaxRoll);
      expect(updated.qualityMinSharpness, initial.qualityMinSharpness);
      expect(updated.qualityMinBrightness, initial.qualityMinBrightness);
      expect(updated.qualityMaxBrightness, initial.qualityMaxBrightness);
      expect(
        updated.challengeBlinkEyeOpenThreshold,
        initial.challengeBlinkEyeOpenThreshold,
      );
      expect(
        updated.challengeBlinkEyeClosedThreshold,
        initial.challengeBlinkEyeClosedThreshold,
      );
      expect(
        updated.challengeSmileProbabilityThreshold,
        initial.challengeSmileProbabilityThreshold,
      );
      expect(
        updated.challengeNodPitchThreshold,
        initial.challengeNodPitchThreshold,
      );
      expect(updated.faceLostGracePeriod, initial.faceLostGracePeriod);
      expect(
        updated.temporalConfidenceThreshold,
        initial.temporalConfidenceThreshold,
      );
    });

    test('equality and hashCode contract', () {
      const AppConfig a = AppConfig();
      const AppConfig b = AppConfig();
      final AppConfig c = a.copyWith(failureLimit: 10);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });
  });
}

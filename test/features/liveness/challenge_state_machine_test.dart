import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/features/liveness/domain/challenge_config.dart';
import 'package:attendence/features/liveness/domain/challenge_state_machine.dart';
import 'package:attendence/features/liveness/domain/challenge_type.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockFaceSample implements FaceSample {
  _MockFaceSample({
    this.trackingId = 1,
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
    this.leftEyeOpenProbability = 0.90,
    this.rightEyeOpenProbability = 0.90,
    this.smilingProbability = 0.10,
  });

  @override
  final int? trackingId;

  @override
  final double? yaw;

  @override
  final double? pitch;

  @override
  final double? roll;

  @override
  final double? leftEyeOpenProbability;

  @override
  final double? rightEyeOpenProbability;

  @override
  final double? smilingProbability;
}

void main() {
  late FakeClock clock;
  late DateTime startTime;

  setUp(() {
    startTime = DateTime(2026, 11, 7, 10, 0, 0);
    clock = FakeClock(startTime);
  });

  group('ChallengeStateMachine - Neutral Look Straight', () {
    test(
      'passes neutral step and records baseline yaw after 3 consecutive frames',
      () {
        final ChallengeStateMachine machine = ChallengeStateMachine(
          clock: clock,
          challenges: const <ChallengeType>[
            ChallengeType.lookStraight,
            ChallengeType.smile,
          ],
        );

        final _MockFaceSample neutralFace = _MockFaceSample(
          yaw: 2.0,
          pitch: -1.0,
        );

        // Frame 1
        ChallengeStepResult res = machine.update(neutralFace);
        expect(res.status, ChallengeMachineStatus.inProgress);
        expect(res.challengeIndex, 0);

        // Frame 2
        res = machine.update(neutralFace);
        expect(res.status, ChallengeMachineStatus.inProgress);
        expect(res.challengeIndex, 0);

        // Frame 3 - completes neutral, advances to smile
        res = machine.update(neutralFace);
        expect(res.status, ChallengeMachineStatus.inProgress);
        expect(res.challengeIndex, 1);
        expect(machine.currentChallenge, ChallengeType.smile);
        expect(machine.baselineYaw, 2.0);
        expect(machine.completedChallenges.length, 1);
        expect(
          machine.completedChallenges.first.type,
          ChallengeType.lookStraight,
        );
      },
    );

    test('resets consecutive counter if face pose exceeds limits', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[ChallengeType.lookStraight],
      );

      // Frame 1: valid
      machine.update(_MockFaceSample(yaw: 0.0));
      expect(machine.consecutiveFrames, 1);

      // Frame 2: excessive yaw
      machine.update(_MockFaceSample(yaw: 15.0));
      expect(machine.consecutiveFrames, 0);

      // Frame 3: excessive roll
      machine.update(_MockFaceSample(roll: 18.0));
      expect(machine.consecutiveFrames, 0);

      // Frame 4: valid again
      machine.update(_MockFaceSample(yaw: 0.0));
      expect(machine.consecutiveFrames, 1);
    });

    test(
      'resets consecutive counter if smiling or eyes closed during neutral',
      () {
        final ChallengeStateMachine machine = ChallengeStateMachine(
          clock: clock,
          challenges: const <ChallengeType>[ChallengeType.lookStraight],
        );

        machine.update(_MockFaceSample());
        expect(machine.consecutiveFrames, 1);

        // Smiling
        machine.update(_MockFaceSample(smilingProbability: 0.85));
        expect(machine.consecutiveFrames, 0);

        // Eyes closed
        machine.update(_MockFaceSample(leftEyeOpenProbability: 0.1));
        expect(machine.consecutiveFrames, 0);
      },
    );
  });

  group('ChallengeStateMachine - Blink Challenge', () {
    test('closed-only static photo never passes', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.blink,
        ],
      );

      // Complete neutral
      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample());
      }
      expect(machine.currentChallenge, ChallengeType.blink);

      // Feed only closed eyes (e.g. photo of closed eyes)
      final _MockFaceSample closedFace = _MockFaceSample(
        leftEyeOpenProbability: 0.1,
        rightEyeOpenProbability: 0.1,
      );

      for (int i = 0; i < 10; i++) {
        final ChallengeStepResult res = machine.update(closedFace);
        expect(res.status, ChallengeMachineStatus.inProgress);
        expect(machine.currentChallenge, ChallengeType.blink);
      }
    });

    test('open -> closed -> open successfully passes blink challenge', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.blink,
        ],
      );

      // Complete neutral
      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample());
      }
      expect(machine.currentChallenge, ChallengeType.blink);

      // 1. Initial open
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );

      // 2. Eyes close (2 frames)
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.15,
          rightEyeOpenProbability: 0.15,
        ),
      );
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.15,
          rightEyeOpenProbability: 0.15,
        ),
      );

      // 3. Eyes reopen (2 frames)
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );
      final ChallengeStepResult res = machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );

      expect(res.status, ChallengeMachineStatus.passed);
      expect(machine.completedChallenges.length, 2);
    });

    test('noisy flicker around threshold does not advance blink', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.blink,
        ],
      );

      // Complete neutral
      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample());
      }

      // Initial open
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );

      // Flicker between 0.35 and 0.50 (hysteresis zone)
      for (int i = 0; i < 6; i++) {
        final double prob = i.isEven ? 0.35 : 0.50;
        final ChallengeStepResult res = machine.update(
          _MockFaceSample(
            leftEyeOpenProbability: prob,
            rightEyeOpenProbability: prob,
          ),
        );
        expect(res.status, ChallengeMachineStatus.inProgress);
        expect(machine.currentChallenge, ChallengeType.blink);
      }
    });

    test('single-frame blink passes when minClosedFrames is configured to 1 (low tier)', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.blink,
        ],
        config: const ChallengeConfig(
          blinkMinClosedFrames: 1,
          blinkMinOpenFrames: 1,
        ),
      );

      // Complete neutral
      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample());
      }

      // Open (1 frame)
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );
      // Closed (1 frame)
      machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.15,
          rightEyeOpenProbability: 0.15,
        ),
      );
      // Reopen (1 frame)
      final ChallengeStepResult res = machine.update(
        _MockFaceSample(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85,
        ),
      );

      expect(res.status, ChallengeMachineStatus.passed);
    });
  });

  group('ChallengeStateMachine - Head Turn Challenge', () {
    test(
      'starting already turned fails to advance until face centers first',
      () {
        final ChallengeStateMachine machine = ChallengeStateMachine(
          clock: clock,
          challenges: const <ChallengeType>[
            ChallengeType.lookStraight,
            ChallengeType.turnLeft,
          ],
        );

        // Complete neutral
        for (int i = 0; i < 3; i++) {
          machine.update(_MockFaceSample(yaw: 0.0));
        }
        expect(machine.currentChallenge, ChallengeType.turnLeft);

        // Starts already turned at 25 degrees
        for (int i = 0; i < 5; i++) {
          final ChallengeStepResult res = machine.update(
            _MockFaceSample(yaw: 25.0),
          );
          expect(res.status, ChallengeMachineStatus.inProgress);
          expect(machine.consecutiveFrames, 0);
        }

        // User centers face
        machine.update(_MockFaceSample(yaw: 2.0));

        // Now user turns left (3 frames)
        machine.update(_MockFaceSample(yaw: 22.0));
        machine.update(_MockFaceSample(yaw: 22.0));
        final ChallengeStepResult res = machine.update(
          _MockFaceSample(yaw: 22.0),
        );

        expect(res.status, ChallengeMachineStatus.passed);
      },
    );

    test('wrong turn direction does not pass and resets progress', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.turnLeft,
        ],
      );

      // Neutral
      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample(yaw: 0.0));
      }

      // Center
      machine.update(_MockFaceSample(yaw: 0.0));

      // Turn wrong direction (right: -20 degrees)
      for (int i = 0; i < 5; i++) {
        final ChallengeStepResult res = machine.update(
          _MockFaceSample(yaw: -20.0),
        );
        expect(res.status, ChallengeMachineStatus.inProgress);
        expect(machine.consecutiveFrames, 0);
      }
    });

    test('hysteresis prevents jitter from breaking turn hold', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.turnLeft,
        ],
        config: const ChallengeConfig(
          turnYawThreshold: 20.0,
          turnHysteresis: 4.0, // allowed floor while holding: 16.0
          turnMinFrames: 3,
        ),
      );

      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample(yaw: 0.0));
      }

      // Center
      machine.update(_MockFaceSample(yaw: 0.0));

      // Cross 20 deg
      machine.update(_MockFaceSample(yaw: 21.0));
      expect(machine.consecutiveFrames, 1);

      // Slight head tremor down to 18 deg (> 16 deg hysteresis threshold)
      machine.update(_MockFaceSample(yaw: 18.0));
      expect(machine.consecutiveFrames, 2);

      // Third frame passes
      final ChallengeStepResult res = machine.update(
        _MockFaceSample(yaw: 21.0),
      );
      expect(res.status, ChallengeMachineStatus.passed);
    });
  });

  group('ChallengeStateMachine - Smile Challenge', () {
    test('starting smiling waits for neutral, then smiling passes', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[
          ChallengeType.lookStraight,
          ChallengeType.smile,
        ],
      );

      for (int i = 0; i < 3; i++) {
        machine.update(_MockFaceSample(smilingProbability: 0.0));
      }

      // Starts smiling (0.90)
      machine.update(_MockFaceSample(smilingProbability: 0.90));
      expect(machine.consecutiveFrames, 0);

      // Returns to neutral (0.10)
      machine.update(_MockFaceSample(smilingProbability: 0.10));

      // Smiles (3 frames)
      machine.update(_MockFaceSample(smilingProbability: 0.85));
      machine.update(_MockFaceSample(smilingProbability: 0.85));
      final ChallengeStepResult res = machine.update(
        _MockFaceSample(smilingProbability: 0.85),
      );

      expect(res.status, ChallengeMachineStatus.passed);
    });
  });

  group('ChallengeStateMachine - Tracking & Timeout Robustness', () {
    test('face loss within grace period does not fail session', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[ChallengeType.lookStraight],
        config: const ChallengeConfig(
          faceLostGracePeriod: Duration(milliseconds: 700),
        ),
      );

      machine.update(_MockFaceSample());
      expect(machine.status, ChallengeMachineStatus.inProgress);

      // Face missing for 400ms
      clock.advance(const Duration(milliseconds: 400));
      ChallengeStepResult res = machine.update(null);
      expect(res.status, ChallengeMachineStatus.inProgress);

      // Face reappears
      res = machine.update(_MockFaceSample());
      expect(res.status, ChallengeMachineStatus.inProgress);
    });

    test('face loss beyond grace period fails with trackingLost', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[ChallengeType.lookStraight],
        config: const ChallengeConfig(
          faceLostGracePeriod: Duration(milliseconds: 700),
        ),
      );

      machine.update(_MockFaceSample());

      // Face first lost at t0
      machine.update(null);

      // Face missing for 800ms beyond grace period
      clock.advance(const Duration(milliseconds: 800));
      final ChallengeStepResult res = machine.update(null);

      expect(res.status, ChallengeMachineStatus.failed);
      expect(res.failureReason, ChallengeFailureReason.trackingLost);
    });

    test('tracking ID change fails immediately with trackingChanged', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[ChallengeType.lookStraight],
      );

      machine.update(_MockFaceSample(trackingId: 101));

      // Different tracking ID (different person swapped into camera)
      final ChallengeStepResult res = machine.update(
        _MockFaceSample(trackingId: 102),
      );

      expect(res.status, ChallengeMachineStatus.failed);
      expect(res.failureReason, ChallengeFailureReason.trackingChanged);
    });

    test('per-challenge timeout triggers failure', () {
      final ChallengeStateMachine machine = ChallengeStateMachine(
        clock: clock,
        challenges: const <ChallengeType>[ChallengeType.lookStraight],
        config: const ChallengeConfig(
          perChallengeTimeout: Duration(seconds: 6),
        ),
      );

      machine.update(_MockFaceSample());

      // Advance clock past 6s
      clock.advance(const Duration(seconds: 7));
      final ChallengeStepResult res = machine.update(_MockFaceSample());

      expect(res.status, ChallengeMachineStatus.failed);
      expect(res.failureReason, ChallengeFailureReason.timeout);
    });
  });
}

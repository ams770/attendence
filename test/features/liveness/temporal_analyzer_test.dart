import 'dart:math' as math;

import 'package:attendence/features/liveness/domain/temporal_analyzer.dart';
import 'package:attendence/features/liveness/domain/temporal_config.dart';
import 'package:attendence/features/liveness/domain/temporal_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemporalAnalyzer', () {
    test(
      'returns passed with neutral scores when insufficient samples (< 5)',
      () {
        final TemporalAnalyzer analyzer = TemporalAnalyzer();

        final TemporalAnalysisResult res = analyzer.evaluate();
        expect(res.isPassed, isTrue);
        expect(res.sampleCount, 0);
      },
    );

    test(
      'detects perfectly frozen landmark sequence and fails micro-motion',
      () {
        final TemporalAnalyzer analyzer = TemporalAnalyzer();

        // Feed 20 identical frames (static photo held in front of camera)
        for (int i = 0; i < 20; i++) {
          analyzer.addSample(
            TemporalFrameSample(
              landmarks: const TemporalLandmarks(
                leftEye: TemporalPoint(40, 50),
                rightEye: TemporalPoint(70, 50),
                noseBase: TemporalPoint(55, 70),
                leftMouth: TemporalPoint(42, 90),
                rightMouth: TemporalPoint(68, 90),
              ),
              boxLeft: 20,
              boxTop: 20,
              boxWidth: 100,
              boxHeight: 120,
              yaw: 0.0,
              pitch: 0.0,
              timestamp: DateTime(2026, 11, 7, 10, 0, 0, i * 100),
            ),
          );
        }

        final TemporalAnalysisResult result = analyzer.evaluate();
        expect(result.microMotionScore, 0.0);
        expect(result.isPassed, isFalse);
      },
    );

    test('passes natural micro-motion sequence with healthy score', () {
      final TemporalAnalyzer analyzer = TemporalAnalyzer();

      // Add 20 frames with subtle natural micro-movement (variance ~ 5e-5)
      final math.Random rnd = math.Random(42);
      for (int i = 0; i < 20; i++) {
        final double jitterX = (rnd.nextDouble() - 0.5) * 1.5;
        final double jitterY = (rnd.nextDouble() - 0.5) * 1.5;

        analyzer.addSample(
          TemporalFrameSample(
            landmarks: TemporalLandmarks(
              leftEye: TemporalPoint(40 + jitterX, 50 + jitterY),
              rightEye: TemporalPoint(70 + jitterX, 50 + jitterY),
              noseBase: TemporalPoint(55 + jitterX, 70 + jitterY),
              leftMouth: TemporalPoint(42 + jitterX, 90 + jitterY),
              rightMouth: TemporalPoint(68 + jitterX, 90 + jitterY),
            ),
            boxLeft: 20,
            boxTop: 20,
            boxWidth: 100,
            boxHeight: 120,
            yaw: (rnd.nextDouble() - 0.5) * 2.0,
            pitch: (rnd.nextDouble() - 0.5) * 2.0,
            timestamp: DateTime(2026, 11, 7, 10, 0, 0, i * 100),
          ),
        );
      }

      final TemporalAnalysisResult result = analyzer.evaluate();
      expect(result.microMotionScore, greaterThan(0.8));
      expect(result.loopScore, equals(1.0));
      expect(result.isPassed, isTrue);
    });

    test('detects repeating periodic video loop and drops loop score', () {
      final TemporalAnalyzer analyzer = TemporalAnalyzer(
        config: const TemporalConfig(
          loopMinLag: 4,
          loopMaxLag: 10,
          loopDistanceThreshold: 0.08,
        ),
      );

      // Create a 6-frame repeating animation (e.g. replayed 0.6s boomerang video)
      final List<TemporalLandmarks> cycle = <TemporalLandmarks>[
        const TemporalLandmarks(
          leftEye: TemporalPoint(40, 50),
          rightEye: TemporalPoint(70, 50),
          noseBase: TemporalPoint(55, 70),
          leftMouth: TemporalPoint(42, 90),
          rightMouth: TemporalPoint(68, 90),
        ),
        const TemporalLandmarks(
          leftEye: TemporalPoint(41, 51),
          rightEye: TemporalPoint(71, 51),
          noseBase: TemporalPoint(56, 71),
          leftMouth: TemporalPoint(43, 91),
          rightMouth: TemporalPoint(69, 91),
        ),
        const TemporalLandmarks(
          leftEye: TemporalPoint(43, 53),
          rightEye: TemporalPoint(73, 53),
          noseBase: TemporalPoint(58, 73),
          leftMouth: TemporalPoint(45, 93),
          rightMouth: TemporalPoint(71, 93),
        ),
        const TemporalLandmarks(
          leftEye: TemporalPoint(42, 52),
          rightEye: TemporalPoint(72, 52),
          noseBase: TemporalPoint(57, 72),
          leftMouth: TemporalPoint(44, 92),
          rightMouth: TemporalPoint(70, 92),
        ),
        const TemporalLandmarks(
          leftEye: TemporalPoint(41, 51),
          rightEye: TemporalPoint(71, 51),
          noseBase: TemporalPoint(56, 71),
          leftMouth: TemporalPoint(43, 91),
          rightMouth: TemporalPoint(69, 91),
        ),
        const TemporalLandmarks(
          leftEye: TemporalPoint(40, 50),
          rightEye: TemporalPoint(70, 50),
          noseBase: TemporalPoint(55, 70),
          leftMouth: TemporalPoint(42, 90),
          rightMouth: TemporalPoint(68, 90),
        ),
      ];

      for (int i = 0; i < 24; i++) {
        analyzer.addSample(
          TemporalFrameSample(
            landmarks: cycle[i % cycle.length],
            boxLeft: 20,
            boxTop: 20,
            boxWidth: 100,
            boxHeight: 120,
            yaw: (i % cycle.length).toDouble(),
            pitch: 0.0,
            timestamp: DateTime(2026, 11, 7, 10, 0, 0, i * 100),
          ),
        );
      }

      final TemporalAnalysisResult result = analyzer.evaluate();
      expect(result.loopScore, lessThan(0.3));
    });

    test(
      'detects 2D planar rotation (rotated flat photo) with near-zero residual',
      () {
        final TemporalAnalyzer analyzer = TemporalAnalyzer();

        // 1. Neutral frame (yaw = 0)
        analyzer.addSample(
          TemporalFrameSample(
            landmarks: const TemporalLandmarks(
              leftEye: TemporalPoint(40, 50),
              rightEye: TemporalPoint(70, 50),
              noseBase: TemporalPoint(55, 70),
              leftMouth: TemporalPoint(42, 90),
              rightMouth: TemporalPoint(68, 90),
            ),
            boxLeft: 20,
            boxTop: 20,
            boxWidth: 100,
            boxHeight: 120,
            yaw: 0.0,
            pitch: 0.0,
            timestamp: DateTime(2026, 11, 7, 10, 0, 0),
          ),
        );

        // Intermediate frames with subtle motion
        for (int i = 1; i < 10; i++) {
          analyzer.addSample(
            TemporalFrameSample(
              landmarks: TemporalLandmarks(
                leftEye: TemporalPoint(40 + i * 0.2, 50),
                rightEye: TemporalPoint(70 + i * 0.2, 50),
                noseBase: TemporalPoint(55 + i * 0.2, 70),
                leftMouth: TemporalPoint(42 + i * 0.2, 90),
                rightMouth: TemporalPoint(68 + i * 0.2, 90),
              ),
              boxLeft: 20,
              boxTop: 20,
              boxWidth: 100,
              boxHeight: 120,
              yaw: i * 1.5,
              pitch: 0.0,
              timestamp: DateTime(2026, 11, 7, 10, 0, 0, i * 100),
            ),
          );
        }

        // 2. Turned frame: strictly 2D affine rotated (flat paper rotated by 20 deg, yaw = 20)
        // Affine transform: x' = cos(th)*x - sin(th)*y + tx, y' = sin(th)*x + cos(th)*y + ty
        const double cosT = 0.93969; // cos(20 deg)
        const double sinT = 0.34202; // sin(20 deg)
        TemporalPoint transform(double x, double y) => TemporalPoint(
          cosT * x - sinT * y + 15.0,
          sinT * x + cosT * y + 10.0,
        );

        analyzer.addSample(
          TemporalFrameSample(
            landmarks: TemporalLandmarks(
              leftEye: transform(40, 50),
              rightEye: transform(70, 50),
              noseBase: transform(55, 70),
              leftMouth: transform(42, 90),
              rightMouth: transform(68, 90),
            ),
            boxLeft: 25,
            boxTop: 25,
            boxWidth: 100,
            boxHeight: 120,
            yaw: 20.0,
            pitch: 0.0,
            timestamp: DateTime(2026, 11, 7, 10, 0, 1),
          ),
        );

        final TemporalAnalysisResult result = analyzer.evaluate();
        expect(result.rigidityEvaluated, isTrue);
        // Flat 2D affine has virtually 0 residual, detecting planar photo
        expect(result.rigidityScore, 0.0);
      },
    );

    test('confirms 3D head rotation with parallax residual', () {
      final TemporalAnalyzer analyzer = TemporalAnalyzer();

      // 1. Neutral frame (yaw = 0)
      analyzer.addSample(
        TemporalFrameSample(
          landmarks: const TemporalLandmarks(
            leftEye: TemporalPoint(40, 50),
            rightEye: TemporalPoint(70, 50),
            noseBase: TemporalPoint(55, 70),
            leftMouth: TemporalPoint(42, 90),
            rightMouth: TemporalPoint(68, 90),
          ),
          boxLeft: 20,
          boxTop: 20,
          boxWidth: 100,
          boxHeight: 120,
          yaw: 0.0,
          pitch: 0.0,
          timestamp: DateTime(2026, 11, 7, 10, 0, 0),
        ),
      );

      // Intermediate frames
      for (int i = 1; i < 10; i++) {
        analyzer.addSample(
          TemporalFrameSample(
            landmarks: TemporalLandmarks(
              leftEye: TemporalPoint(40 + i * 0.2, 50),
              rightEye: TemporalPoint(70 + i * 0.2, 50),
              noseBase: TemporalPoint(55 + i * 0.2, 70),
              leftMouth: TemporalPoint(42 + i * 0.2, 90),
              rightMouth: TemporalPoint(68 + i * 0.2, 90),
            ),
            boxLeft: 20,
            boxTop: 20,
            boxWidth: 100,
            boxHeight: 120,
            yaw: i * 1.5,
            pitch: 0.0,
            timestamp: DateTime(2026, 11, 7, 10, 0, 0, i * 100),
          ),
        );
      }

      // 2. Turned frame (yaw = 20) with 3D nose parallax shift!
      // When a 3D head rotates left, the nose tip shifts significantly further left relative to eyes
      analyzer.addSample(
        TemporalFrameSample(
          landmarks: const TemporalLandmarks(
            leftEye: TemporalPoint(46, 51),
            rightEye: TemporalPoint(74, 51),
            noseBase: TemporalPoint(66, 71), // 3D depth parallax!
            leftMouth: TemporalPoint(47, 91),
            rightMouth: TemporalPoint(71, 91),
          ),
          boxLeft: 25,
          boxTop: 25,
          boxWidth: 100,
          boxHeight: 120,
          yaw: 20.0,
          pitch: 0.0,
          timestamp: DateTime(2026, 11, 7, 10, 0, 1),
        ),
      );

      final TemporalAnalysisResult result = analyzer.evaluate();
      expect(result.rigidityEvaluated, isTrue);
      expect(result.rigidityScore, 1.0);
    });

    test('skips rigidity evaluation when yaw did not reach turn threshold', () {
      final TemporalAnalyzer analyzer = TemporalAnalyzer();

      for (int i = 0; i < 10; i++) {
        analyzer.addSample(
          TemporalFrameSample(
            landmarks: TemporalLandmarks(
              leftEye: TemporalPoint(40 + i * 0.1, 50),
              rightEye: TemporalPoint(70 + i * 0.1, 50),
              noseBase: TemporalPoint(55 + i * 0.1, 70),
              leftMouth: TemporalPoint(42 + i * 0.1, 90),
              rightMouth: TemporalPoint(68 + i * 0.1, 90),
            ),
            boxLeft: 20,
            boxTop: 20,
            boxWidth: 100,
            boxHeight: 120,
            yaw: 2.0, // all near neutral
            pitch: 0.0,
            timestamp: DateTime(2026, 11, 7, 10, 0, 0, i * 100),
          ),
        );
      }

      final TemporalAnalysisResult result = analyzer.evaluate();
      expect(result.rigidityEvaluated, isFalse);
      expect(result.rigidityScore, 1.0);
      expect(result.isPassed, isTrue);
    });
  });
}

import 'package:attendence/core/utils/math_utils.dart';
import 'package:attendence/features/liveness/domain/passive_preprocess_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PassivePreprocessConfig', () {
    test(
      'default configuration matches Silent-Face-Anti-Spoofing baseline',
      () {
        const PassivePreprocessConfig config = PassivePreprocessConfig();

        expect(config.channelOrder, ChannelOrder.bgr);
        expect(config.scale, 1.0);
        expect(config.mean, equals(<double>[0.0, 0.0, 0.0]));
        expect(config.std, equals(<double>[1.0, 1.0, 1.0]));
        expect(config.realClassIndex, 1);
        expect(config.applySoftmax, isTrue);
        expect(config.v2CropScale, 2.7);
        expect(config.v1SeCropScale, 4.0);
        expect(config.boxExpansion, 1.0);
        expect(config.inputWidth, 80);
        expect(config.inputHeight, 80);
      },
    );

    test('copyWith updates specified fields only', () {
      const PassivePreprocessConfig config = PassivePreprocessConfig();
      final PassivePreprocessConfig updated = config.copyWith(
        channelOrder: ChannelOrder.rgb,
        scale: 1.0 / 255.0,
        realClassIndex: 0,
        applySoftmax: false,
        v2CropScale: 3.0,
        boxExpansion: 1.2,
      );

      expect(updated.channelOrder, ChannelOrder.rgb);
      expect(updated.scale, closeTo(1.0 / 255.0, 0.0001));
      expect(updated.realClassIndex, 0);
      expect(updated.applySoftmax, isFalse);
      expect(updated.v2CropScale, 3.0);
      expect(updated.boxExpansion, 1.2);

      // Unchanged fields remain intact
      expect(updated.mean, config.mean);
      expect(updated.std, config.std);
      expect(updated.v1SeCropScale, config.v1SeCropScale);
      expect(updated.inputWidth, config.inputWidth);
      expect(updated.inputHeight, config.inputHeight);
    });

    test('equality and hashCode contract', () {
      const PassivePreprocessConfig a = PassivePreprocessConfig();
      const PassivePreprocessConfig b = PassivePreprocessConfig();
      final PassivePreprocessConfig c = a.copyWith(realClassIndex: 2);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('MathUtils.softmax computes numerically stable probabilities summing to 1.0', () {
      // Known logits
      final List<double> logits = <double>[1.0, 2.0, 3.0];
      final List<double> probs = MathUtils.softmax(logits);

      expect(probs.length, 3);
      final double sum = probs.fold<double>(
        0.0,
        (double acc, double p) => acc + p,
      );
      expect(sum, closeTo(1.0, 0.0001));
      expect(probs[2], greaterThan(probs[1]));
      expect(probs[1], greaterThan(probs[0]));

      // Very large logits that would overflow standard exp()
      final List<double> largeLogits = <double>[1000.0, 1001.0, 1002.0];
      final List<double> stableProbs = MathUtils.softmax(largeLogits);
      expect(
        stableProbs.every((double p) => !p.isNaN && !p.isInfinite),
        isTrue,
      );
      final double stableSum = stableProbs.fold<double>(
        0.0,
        (double acc, double p) => acc + p,
      );
      expect(stableSum, closeTo(1.0, 0.0001));
    });
  });
}

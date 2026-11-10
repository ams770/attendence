import 'package:attendence/features/detection/domain/oval_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OvalGuide', () {
    // Ellipse centered at (200, 200) with width 200 (rx = 100), height 100 (ry = 50)
    final Rect oval = Rect.fromCenter(
      center: const Offset(200.0, 200.0),
      width: 200.0,
      height: 100.0,
    );

    test('isFaceInsideOval returns true when face is centered and comfortably inside', () {
      // Small box at center: (180, 180) to (220, 220)
      const Rect innerBox = Rect.fromLTWH(180.0, 180.0, 40.0, 40.0);
      expect(isFaceInsideOval(innerBox, oval), isTrue);
    });

    test('isFaceInsideOval returns false when face corner protrudes outside ellipse', () {
      // Corner at (100, 160): dx = -100, dy = -40 => (-100)^2/100^2 + (-40)^2/50^2 = 1.0 + 0.64 = 1.64 > 1.0
      const Rect protrudingBox = Rect.fromLTWH(100.0, 160.0, 100.0, 40.0);
      expect(isFaceInsideOval(protrudingBox, oval), isFalse);
    });

    test('isFaceInsideOval returns false when face is completely outside', () {
      const Rect outsideBox = Rect.fromLTWH(10.0, 10.0, 50.0, 50.0);
      expect(isFaceInsideOval(outsideBox, oval), isFalse);
    });

    test('isFaceInsideOval returns false on empty rects', () {
      expect(isFaceInsideOval(Rect.zero, oval), isFalse);
      expect(
        isFaceInsideOval(const Rect.fromLTWH(180, 180, 40, 40), Rect.zero),
        isFalse,
      );
    });

    test(
      'isFaceInsideOval allows natural face corner protrusion within tolerance',
      () {
        // Oval: center (200, 200), rx = 100, ry = 50
        // Face filling ~75% of width (w=150 => dx=75) and ~75% of height (h=75 => dy=37.5)
        // Corner normDist = (75/100)^2 + (37.5/50)^2 = 0.5625 + 0.5625 = 1.125
        // 1.125 <= 1.25 tolerance, cardinal extents strictly within 1.0
        final Rect naturalFace = Rect.fromCenter(
          center: const Offset(200.0, 200.0),
          width: 150.0,
          height: 75.0,
        );
        expect(
          isFaceInsideOval(naturalFace, oval, cornerTolerance: 1.25),
          isTrue,
        );
      },
    );

    test('isFaceInsideOval allows cardinal edge within cardinalTolerance', () {
      // Oval: ry = 50, height = 104 => dy = 52 => 52/50 = 1.04 <= 1.08
      // width = 40 => dx = 20 => corner normDist = (20/100)^2 + (52/50)^2 = 0.04 + 1.0816 = 1.1216 <= 1.25
      final Rect slightlyTallerFace = Rect.fromCenter(
        center: const Offset(200.0, 200.0),
        width: 40.0,
        height: 104.0,
      );
      expect(
        isFaceInsideOval(
          slightlyTallerFace,
          oval,
          cornerTolerance: 1.25,
          cardinalTolerance: 1.08,
        ),
        isTrue,
      );
    });

    test(
      'isFaceInsideOval rejects when cardinal edges exceed cardinalTolerance',
      () {
        // Face wider than oval (w=220 > 200 => dx=110, 110/100 = 1.10 > 1.08)
        final Rect tooWideFace = Rect.fromCenter(
          center: const Offset(200.0, 200.0),
          width: 220.0,
          height: 60.0,
        );
        expect(
          isFaceInsideOval(
            tooWideFace,
            oval,
            cornerTolerance: 1.25,
            cardinalTolerance: 1.08,
          ),
          isFalse,
        );
      },
    );

    test(
      'defaultOvalRect calculates centered proportions based on previewSize',
      () {
        const Size previewSize = Size(400.0, 800.0);
        final Rect defaultOval = defaultOvalRect(previewSize);

        expect(defaultOval.width, equals(400.0 * 0.70));
        expect(defaultOval.height, equals(800.0 * 0.50));
        expect(defaultOval.center.dx, equals(200.0));
        expect(defaultOval.center.dy, equals(800.0 * 0.45));
      },
    );

    testWidgets('OvalGuidePainter paints cutout and border without errors', (
      WidgetTester tester,
    ) async {
      final Rect ovalRect = Rect.fromCenter(
        center: const Offset(150.0, 200.0),
        width: 200.0,
        height: 250.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(300.0, 400.0),
              painter: OvalGuidePainter(
                ovalRect: ovalRect,
                borderColor: Colors.green,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is OvalGuidePainter,
        ),
        findsOneWidget,
      );
    });
  });
}

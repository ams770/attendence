import 'package:attendence/features/ml/domain/model_registry.dart';
import 'package:attendence/features/ml/domain/model_self_check.dart';
import 'package:attendence/features/ml/presentation/home_screen.dart';
import 'package:attendence/features/ml/presentation/model_error_screen.dart';
import 'package:attendence/features/ml/presentation/startup_check_screen.dart';
import 'package:attendence/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget createTestWidget({
  required Widget child,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('Presentation and Shell', () {
    testWidgets('StartupCheckScreen displays progress while loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const StartupCheckScreen()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Checking AI models and system resources...'),
        findsOneWidget,
      );
    });

    testWidgets(
      'HomeScreen displays app title and passed status in English and Arabic',
      (WidgetTester tester) async {
        const SelfCheckReport successReport = SelfCheckReport(
          isAllSuccess: true,
          results: <ModelCheckResult>[
            ModelCheckResult(
              spec: ModelRegistry.miniFASNetV1SE,
              isSuccess: true,
              actualOutputSize: 3,
            ),
            ModelCheckResult(
              spec: ModelRegistry.miniFASNetV2,
              isSuccess: true,
              actualOutputSize: 3,
            ),
            ModelCheckResult(
              spec: ModelRegistry.sFace,
              isSuccess: true,
              actualOutputSize: 128,
            ),
          ],
        );

        // English
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: const HomeScreen(report: successReport),
          ),
        );

        expect(find.text('Attendance'), findsOneWidget);
        expect(
          find.text('All models initialized and verified successfully.'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('MiniFASNetV1SE'),
          100.0,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('MiniFASNetV1SE'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('MiniFASNetV2'),
          100.0,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('MiniFASNetV2'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('SFace'),
          100.0,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('SFace'), findsOneWidget);

        // Arabic RTL
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('ar'),
            child: const HomeScreen(report: successReport),
          ),
        );

        expect(find.text('تسجيل الحضور'), findsOneWidget);
        expect(find.text('تم التحقق من جميع النماذج بنجاح.'), findsOneWidget);
      },
    );

    testWidgets('ModelErrorScreen lists failed model with path and reason', (
      WidgetTester tester,
    ) async {
      const SelfCheckReport failureReport = SelfCheckReport(
        isAllSuccess: false,
        results: <ModelCheckResult>[
          ModelCheckResult(
            spec: ModelRegistry.miniFASNetV1SE,
            isSuccess: false,
            errorMessage: 'Asset file missing from disk',
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(child: const ModelErrorScreen(report: failureReport)),
      );

      expect(find.text('Startup Check Failed'), findsOneWidget);
      expect(find.text('Model: MiniFASNetV1SE'), findsOneWidget);
      expect(find.text('Path: assets/ai/MiniFASNetV1SE.onnx'), findsOneWidget);
      expect(find.text('Reason: Asset file missing from disk'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

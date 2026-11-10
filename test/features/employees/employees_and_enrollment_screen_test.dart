import 'package:attendence/core/di/providers.dart';
import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/features/employees/data/fake_employee_repository.dart';
import 'package:attendence/features/employees/domain/employee.dart';
import 'package:attendence/features/employees/presentation/employees_screen.dart';
import 'package:attendence/features/employees/presentation/enrollment_screen.dart';
import 'package:attendence/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeesScreen & EnrollmentScreen UI', () {
    late FakeEmployeeRepository repo;
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(DateTime(2026, 11, 7, 12, 0, 0));
      repo = FakeEmployeeRepository(clock: clock);
    });

    Widget createTestApp(Widget child, {Locale locale = const Locale('en')}) {
      return ProviderScope(
        overrides: [employeeRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          home: child,
        ),
      );
    }

    testWidgets(
      'EmployeesScreen renders list, search, filter, and empty state',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp(const EmployeesScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Employees'), findsOneWidget);
        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('No employees registered yet.'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'EmployeesScreen displays enrolled employees and filters by query',
      (WidgetTester tester) async {
        await repo.createEmployee(
          code: 'E001',
          name: 'Alice Johnson',
          embeddings: <List<double>>[List<double>.filled(128, 0.1)],
          modelId: 'sface',
          dimension: 128,
        );
        await repo.createEmployee(
          code: 'E002',
          name: 'Bob Smith',
          embeddings: <List<double>>[List<double>.filled(128, 0.2)],
          modelId: 'sface',
          dimension: 128,
        );

        await tester.pumpWidget(createTestApp(const EmployeesScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Alice Johnson'), findsOneWidget);
        expect(find.text('Bob Smith'), findsOneWidget);

        // Search for Alice
        await tester.enterText(find.byType(SearchBar), 'Alice');
        await tester.pumpAndSettle();

        expect(find.text('Alice Johnson'), findsOneWidget);
        expect(find.text('Bob Smith'), findsNothing);
      },
    );

    testWidgets('EmployeesScreen opens edit dialog and updates employee', (
      WidgetTester tester,
    ) async {
      await repo.createEmployee(
        code: 'E001',
        name: 'Alice Johnson',
        embeddings: <List<double>>[List<double>.filled(128, 0.1)],
        modelId: 'sface',
        dimension: 128,
      );

      await tester.pumpWidget(createTestApp(const EmployeesScreen()));
      await tester.pumpAndSettle();

      // Open popup menu on employee item
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Edit Employee'), findsOneWidget);
      await tester.tap(find.text('Edit Employee'));
      await tester.pumpAndSettle();

      // Dialog is shown with Name and Code TextFields
      expect(find.widgetWithText(TextField, 'Alice Johnson'), findsOneWidget);
      final Finder nameField = find.widgetWithText(TextField, 'Alice Johnson');
      await tester.enterText(nameField, 'Alice Walker');

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Alice Walker'), findsOneWidget);
    });

    testWidgets('EmployeesScreen deletes employee with confirmation', (
      WidgetTester tester,
    ) async {
      final Employee emp = await repo.createEmployee(
        code: 'DEL_ME',
        name: 'Delete Target',
        embeddings: <List<double>>[List<double>.filled(128, 0.1)],
        modelId: 'sface',
        dimension: 128,
      );

      await tester.pumpWidget(createTestApp(const EmployeesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Delete Target'), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Delete Employee'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Target'), findsNothing);
      expect(await repo.getEmployeeById(emp.id), isNull);
    });

    testWidgets(
      'EnrollmentScreen validates inputs and prevents duplicate code',
      (WidgetTester tester) async {
        await repo.createEmployee(
          code: 'TAKEN1',
          name: 'Existing Person',
          embeddings: <List<double>>[List<double>.filled(128, 0.1)],
          modelId: 'sface',
          dimension: 128,
        );

        await tester.pumpWidget(createTestApp(const EnrollmentScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Employee Enrollment'), findsOneWidget);

        // Try empty submission
        await tester.tap(find.text('Start Face Capture'));
        await tester.pumpAndSettle();

        expect(find.text('Employee name is required'), findsOneWidget);
        expect(find.text('Employee code is required'), findsOneWidget);

        // Enter duplicate code and name
        final Finder textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'New Candidate');
        await tester.enterText(textFields.at(1), 'TAKEN1');

        await tester.tap(find.text('Start Face Capture'));
        await tester.pumpAndSettle();

        // Shows duplicate code snackbar
        expect(find.text('Employee code already exists'), findsOneWidget);
      },
    );
  });
}

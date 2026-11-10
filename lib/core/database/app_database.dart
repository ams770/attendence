import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Database table for registered employees.
@DataClassName('DbEmployee')
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get employeeCode => text().unique()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Database table for encrypted facial embeddings.
@DataClassName('DbEmbedding')
class Embeddings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  BlobColumn get ciphertext => blob()();
  BlobColumn get nonce => blob()();
  BlobColumn get mac => blob()();
  TextColumn get modelId => text()();
  IntColumn get dimension => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Database table for employee attendance check-in / check-out records.
@DataClassName('DbAttendanceRecord')
class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get recordType => text()();
  RealColumn get similarityScore => real()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();
}

/// Database table for verification attempt telemetry logs.
@DataClassName('DbAttemptLog')
class AttemptLogsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get policy => text()();
  BoolColumn get isPassed => boolean()();
  TextColumn get failureReason => text().nullable()();
  IntColumn get durationMs => integer()();
  RealColumn get meanPassiveScore => real()();
  RealColumn get temporalConfidence => real()();
  DateTimeColumn get createdAt => dateTime()();
}

/// SQLite database managed by Drift.
@DriftDatabase(
  tables: <Type>[Employees, Embeddings, AttendanceRecords, AttemptLogsTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final Directory dbFolder = await getApplicationDocumentsDirectory();
      final File file = File(p.join(dbFolder.path, 'attendance.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

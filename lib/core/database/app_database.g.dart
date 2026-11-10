// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EmployeesTable extends Employees
    with TableInfo<$EmployeesTable, DbEmployee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeCodeMeta = const VerificationMeta(
    'employeeCode',
  );
  @override
  late final GeneratedColumn<String> employeeCode = GeneratedColumn<String>(
    'employee_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeCode,
    name,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbEmployee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_code')) {
      context.handle(
        _employeeCodeMeta,
        employeeCode.isAcceptableOrUnknown(
          data['employee_code']!,
          _employeeCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeCodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbEmployee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbEmployee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EmployeesTable createAlias(String alias) {
    return $EmployeesTable(attachedDatabase, alias);
  }
}

class DbEmployee extends DataClass implements Insertable<DbEmployee> {
  final int id;
  final String employeeCode;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  const DbEmployee({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_code'] = Variable<String>(employeeCode);
    map['name'] = Variable<String>(name);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EmployeesCompanion toCompanion(bool nullToAbsent) {
    return EmployeesCompanion(
      id: Value(id),
      employeeCode: Value(employeeCode),
      name: Value(name),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory DbEmployee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbEmployee(
      id: serializer.fromJson<int>(json['id']),
      employeeCode: serializer.fromJson<String>(json['employeeCode']),
      name: serializer.fromJson<String>(json['name']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeCode': serializer.toJson<String>(employeeCode),
      'name': serializer.toJson<String>(name),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DbEmployee copyWith({
    int? id,
    String? employeeCode,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) => DbEmployee(
    id: id ?? this.id,
    employeeCode: employeeCode ?? this.employeeCode,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  DbEmployee copyWithCompanion(EmployeesCompanion data) {
    return DbEmployee(
      id: data.id.present ? data.id.value : this.id,
      employeeCode: data.employeeCode.present
          ? data.employeeCode.value
          : this.employeeCode,
      name: data.name.present ? data.name.value : this.name,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbEmployee(')
          ..write('id: $id, ')
          ..write('employeeCode: $employeeCode, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, employeeCode, name, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbEmployee &&
          other.id == this.id &&
          other.employeeCode == this.employeeCode &&
          other.name == this.name &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class EmployeesCompanion extends UpdateCompanion<DbEmployee> {
  final Value<int> id;
  final Value<String> employeeCode;
  final Value<String> name;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const EmployeesCompanion({
    this.id = const Value.absent(),
    this.employeeCode = const Value.absent(),
    this.name = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EmployeesCompanion.insert({
    this.id = const Value.absent(),
    required String employeeCode,
    required String name,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
  }) : employeeCode = Value(employeeCode),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<DbEmployee> custom({
    Expression<int>? id,
    Expression<String>? employeeCode,
    Expression<String>? name,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeCode != null) 'employee_code': employeeCode,
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EmployeesCompanion copyWith({
    Value<int>? id,
    Value<String>? employeeCode,
    Value<String>? name,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return EmployeesCompanion(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeCode.present) {
      map['employee_code'] = Variable<String>(employeeCode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeesCompanion(')
          ..write('id: $id, ')
          ..write('employeeCode: $employeeCode, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingsTable extends Embeddings
    with TableInfo<$EmbeddingsTable, DbEmbedding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<Uint8List> ciphertext = GeneratedColumn<Uint8List>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<Uint8List> mac = GeneratedColumn<Uint8List>(
    'mac',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionMeta = const VerificationMeta(
    'dimension',
  );
  @override
  late final GeneratedColumn<int> dimension = GeneratedColumn<int>(
    'dimension',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    ciphertext,
    nonce,
    mac,
    modelId,
    dimension,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbEmbedding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    } else if (isInserting) {
      context.missing(_macMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('dimension')) {
      context.handle(
        _dimensionMeta,
        dimension.isAcceptableOrUnknown(data['dimension']!, _dimensionMeta),
      );
    } else if (isInserting) {
      context.missing(_dimensionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbEmbedding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbEmbedding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ciphertext'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}mac'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      dimension: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimension'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EmbeddingsTable createAlias(String alias) {
    return $EmbeddingsTable(attachedDatabase, alias);
  }
}

class DbEmbedding extends DataClass implements Insertable<DbEmbedding> {
  final int id;
  final int employeeId;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;
  final String modelId;
  final int dimension;
  final DateTime createdAt;
  const DbEmbedding({
    required this.id,
    required this.employeeId,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.modelId,
    required this.dimension,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['ciphertext'] = Variable<Uint8List>(ciphertext);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['mac'] = Variable<Uint8List>(mac);
    map['model_id'] = Variable<String>(modelId);
    map['dimension'] = Variable<int>(dimension);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      ciphertext: Value(ciphertext),
      nonce: Value(nonce),
      mac: Value(mac),
      modelId: Value(modelId),
      dimension: Value(dimension),
      createdAt: Value(createdAt),
    );
  }

  factory DbEmbedding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbEmbedding(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      ciphertext: serializer.fromJson<Uint8List>(json['ciphertext']),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      mac: serializer.fromJson<Uint8List>(json['mac']),
      modelId: serializer.fromJson<String>(json['modelId']),
      dimension: serializer.fromJson<int>(json['dimension']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'ciphertext': serializer.toJson<Uint8List>(ciphertext),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'mac': serializer.toJson<Uint8List>(mac),
      'modelId': serializer.toJson<String>(modelId),
      'dimension': serializer.toJson<int>(dimension),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DbEmbedding copyWith({
    int? id,
    int? employeeId,
    Uint8List? ciphertext,
    Uint8List? nonce,
    Uint8List? mac,
    String? modelId,
    int? dimension,
    DateTime? createdAt,
  }) => DbEmbedding(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    ciphertext: ciphertext ?? this.ciphertext,
    nonce: nonce ?? this.nonce,
    mac: mac ?? this.mac,
    modelId: modelId ?? this.modelId,
    dimension: dimension ?? this.dimension,
    createdAt: createdAt ?? this.createdAt,
  );
  DbEmbedding copyWithCompanion(EmbeddingsCompanion data) {
    return DbEmbedding(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      mac: data.mac.present ? data.mac.value : this.mac,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      dimension: data.dimension.present ? data.dimension.value : this.dimension,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbEmbedding(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('nonce: $nonce, ')
          ..write('mac: $mac, ')
          ..write('modelId: $modelId, ')
          ..write('dimension: $dimension, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    $driftBlobEquality.hash(ciphertext),
    $driftBlobEquality.hash(nonce),
    $driftBlobEquality.hash(mac),
    modelId,
    dimension,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbEmbedding &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          $driftBlobEquality.equals(other.ciphertext, this.ciphertext) &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          $driftBlobEquality.equals(other.mac, this.mac) &&
          other.modelId == this.modelId &&
          other.dimension == this.dimension &&
          other.createdAt == this.createdAt);
}

class EmbeddingsCompanion extends UpdateCompanion<DbEmbedding> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<Uint8List> ciphertext;
  final Value<Uint8List> nonce;
  final Value<Uint8List> mac;
  final Value<String> modelId;
  final Value<int> dimension;
  final Value<DateTime> createdAt;
  const EmbeddingsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.nonce = const Value.absent(),
    this.mac = const Value.absent(),
    this.modelId = const Value.absent(),
    this.dimension = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EmbeddingsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List mac,
    required String modelId,
    required int dimension,
    required DateTime createdAt,
  }) : employeeId = Value(employeeId),
       ciphertext = Value(ciphertext),
       nonce = Value(nonce),
       mac = Value(mac),
       modelId = Value(modelId),
       dimension = Value(dimension),
       createdAt = Value(createdAt);
  static Insertable<DbEmbedding> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<Uint8List>? ciphertext,
    Expression<Uint8List>? nonce,
    Expression<Uint8List>? mac,
    Expression<String>? modelId,
    Expression<int>? dimension,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (nonce != null) 'nonce': nonce,
      if (mac != null) 'mac': mac,
      if (modelId != null) 'model_id': modelId,
      if (dimension != null) 'dimension': dimension,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EmbeddingsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<Uint8List>? ciphertext,
    Value<Uint8List>? nonce,
    Value<Uint8List>? mac,
    Value<String>? modelId,
    Value<int>? dimension,
    Value<DateTime>? createdAt,
  }) {
    return EmbeddingsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      modelId: modelId ?? this.modelId,
      dimension: dimension ?? this.dimension,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<Uint8List>(ciphertext.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (mac.present) {
      map['mac'] = Variable<Uint8List>(mac.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (dimension.present) {
      map['dimension'] = Variable<int>(dimension.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('nonce: $nonce, ')
          ..write('mac: $mac, ')
          ..write('modelId: $modelId, ')
          ..write('dimension: $dimension, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AttendanceRecordsTable extends AttendanceRecords
    with TableInfo<$AttendanceRecordsTable, DbAttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _similarityScoreMeta = const VerificationMeta(
    'similarityScore',
  );
  @override
  late final GeneratedColumn<double> similarityScore = GeneratedColumn<double>(
    'similarity_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    timestamp,
    recordType,
    similarityScore,
    status,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAttendanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('similarity_score')) {
      context.handle(
        _similarityScoreMeta,
        similarityScore.isAcceptableOrUnknown(
          data['similarity_score']!,
          _similarityScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_similarityScoreMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAttendanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      similarityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}similarity_score'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $AttendanceRecordsTable createAlias(String alias) {
    return $AttendanceRecordsTable(attachedDatabase, alias);
  }
}

class DbAttendanceRecord extends DataClass
    implements Insertable<DbAttendanceRecord> {
  final int id;
  final int employeeId;
  final DateTime timestamp;
  final String recordType;
  final double similarityScore;
  final String status;
  final String? notes;
  const DbAttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.timestamp,
    required this.recordType,
    required this.similarityScore,
    required this.status,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['record_type'] = Variable<String>(recordType);
    map['similarity_score'] = Variable<double>(similarityScore);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  AttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRecordsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      timestamp: Value(timestamp),
      recordType: Value(recordType),
      similarityScore: Value(similarityScore),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory DbAttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAttendanceRecord(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      recordType: serializer.fromJson<String>(json['recordType']),
      similarityScore: serializer.fromJson<double>(json['similarityScore']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'recordType': serializer.toJson<String>(recordType),
      'similarityScore': serializer.toJson<double>(similarityScore),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  DbAttendanceRecord copyWith({
    int? id,
    int? employeeId,
    DateTime? timestamp,
    String? recordType,
    double? similarityScore,
    String? status,
    Value<String?> notes = const Value.absent(),
  }) => DbAttendanceRecord(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    timestamp: timestamp ?? this.timestamp,
    recordType: recordType ?? this.recordType,
    similarityScore: similarityScore ?? this.similarityScore,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
  );
  DbAttendanceRecord copyWithCompanion(AttendanceRecordsCompanion data) {
    return DbAttendanceRecord(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      similarityScore: data.similarityScore.present
          ? data.similarityScore.value
          : this.similarityScore,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAttendanceRecord(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('timestamp: $timestamp, ')
          ..write('recordType: $recordType, ')
          ..write('similarityScore: $similarityScore, ')
          ..write('status: $status, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    timestamp,
    recordType,
    similarityScore,
    status,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAttendanceRecord &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.timestamp == this.timestamp &&
          other.recordType == this.recordType &&
          other.similarityScore == this.similarityScore &&
          other.status == this.status &&
          other.notes == this.notes);
}

class AttendanceRecordsCompanion extends UpdateCompanion<DbAttendanceRecord> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<DateTime> timestamp;
  final Value<String> recordType;
  final Value<double> similarityScore;
  final Value<String> status;
  final Value<String?> notes;
  const AttendanceRecordsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.recordType = const Value.absent(),
    this.similarityScore = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
  });
  AttendanceRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required DateTime timestamp,
    required String recordType,
    required double similarityScore,
    required String status,
    this.notes = const Value.absent(),
  }) : employeeId = Value(employeeId),
       timestamp = Value(timestamp),
       recordType = Value(recordType),
       similarityScore = Value(similarityScore),
       status = Value(status);
  static Insertable<DbAttendanceRecord> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<DateTime>? timestamp,
    Expression<String>? recordType,
    Expression<double>? similarityScore,
    Expression<String>? status,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (timestamp != null) 'timestamp': timestamp,
      if (recordType != null) 'record_type': recordType,
      if (similarityScore != null) 'similarity_score': similarityScore,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  AttendanceRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<DateTime>? timestamp,
    Value<String>? recordType,
    Value<double>? similarityScore,
    Value<String>? status,
    Value<String?>? notes,
  }) {
    return AttendanceRecordsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      timestamp: timestamp ?? this.timestamp,
      recordType: recordType ?? this.recordType,
      similarityScore: similarityScore ?? this.similarityScore,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (similarityScore.present) {
      map['similarity_score'] = Variable<double>(similarityScore.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('timestamp: $timestamp, ')
          ..write('recordType: $recordType, ')
          ..write('similarityScore: $similarityScore, ')
          ..write('status: $status, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $AttemptLogsTableTable extends AttemptLogsTable
    with TableInfo<$AttemptLogsTableTable, DbAttemptLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptLogsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _policyMeta = const VerificationMeta('policy');
  @override
  late final GeneratedColumn<String> policy = GeneratedColumn<String>(
    'policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPassedMeta = const VerificationMeta(
    'isPassed',
  );
  @override
  late final GeneratedColumn<bool> isPassed = GeneratedColumn<bool>(
    'is_passed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_passed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meanPassiveScoreMeta = const VerificationMeta(
    'meanPassiveScore',
  );
  @override
  late final GeneratedColumn<double> meanPassiveScore = GeneratedColumn<double>(
    'mean_passive_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temporalConfidenceMeta =
      const VerificationMeta('temporalConfidence');
  @override
  late final GeneratedColumn<double> temporalConfidence =
      GeneratedColumn<double>(
        'temporal_confidence',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    policy,
    isPassed,
    failureReason,
    durationMs,
    meanPassiveScore,
    temporalConfidence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempt_logs_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAttemptLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('policy')) {
      context.handle(
        _policyMeta,
        policy.isAcceptableOrUnknown(data['policy']!, _policyMeta),
      );
    } else if (isInserting) {
      context.missing(_policyMeta);
    }
    if (data.containsKey('is_passed')) {
      context.handle(
        _isPassedMeta,
        isPassed.isAcceptableOrUnknown(data['is_passed']!, _isPassedMeta),
      );
    } else if (isInserting) {
      context.missing(_isPassedMeta);
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('mean_passive_score')) {
      context.handle(
        _meanPassiveScoreMeta,
        meanPassiveScore.isAcceptableOrUnknown(
          data['mean_passive_score']!,
          _meanPassiveScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_meanPassiveScoreMeta);
    }
    if (data.containsKey('temporal_confidence')) {
      context.handle(
        _temporalConfidenceMeta,
        temporalConfidence.isAcceptableOrUnknown(
          data['temporal_confidence']!,
          _temporalConfidenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_temporalConfidenceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAttemptLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAttemptLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      policy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy'],
      )!,
      isPassed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_passed'],
      )!,
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      meanPassiveScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mean_passive_score'],
      )!,
      temporalConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temporal_confidence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttemptLogsTableTable createAlias(String alias) {
    return $AttemptLogsTableTable(attachedDatabase, alias);
  }
}

class DbAttemptLog extends DataClass implements Insertable<DbAttemptLog> {
  final int id;
  final DateTime timestamp;
  final String policy;
  final bool isPassed;
  final String? failureReason;
  final int durationMs;
  final double meanPassiveScore;
  final double temporalConfidence;
  final DateTime createdAt;
  const DbAttemptLog({
    required this.id,
    required this.timestamp,
    required this.policy,
    required this.isPassed,
    this.failureReason,
    required this.durationMs,
    required this.meanPassiveScore,
    required this.temporalConfidence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['policy'] = Variable<String>(policy);
    map['is_passed'] = Variable<bool>(isPassed);
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['mean_passive_score'] = Variable<double>(meanPassiveScore);
    map['temporal_confidence'] = Variable<double>(temporalConfidence);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttemptLogsTableCompanion toCompanion(bool nullToAbsent) {
    return AttemptLogsTableCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      policy: Value(policy),
      isPassed: Value(isPassed),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      durationMs: Value(durationMs),
      meanPassiveScore: Value(meanPassiveScore),
      temporalConfidence: Value(temporalConfidence),
      createdAt: Value(createdAt),
    );
  }

  factory DbAttemptLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAttemptLog(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      policy: serializer.fromJson<String>(json['policy']),
      isPassed: serializer.fromJson<bool>(json['isPassed']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      meanPassiveScore: serializer.fromJson<double>(json['meanPassiveScore']),
      temporalConfidence: serializer.fromJson<double>(
        json['temporalConfidence'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'policy': serializer.toJson<String>(policy),
      'isPassed': serializer.toJson<bool>(isPassed),
      'failureReason': serializer.toJson<String?>(failureReason),
      'durationMs': serializer.toJson<int>(durationMs),
      'meanPassiveScore': serializer.toJson<double>(meanPassiveScore),
      'temporalConfidence': serializer.toJson<double>(temporalConfidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DbAttemptLog copyWith({
    int? id,
    DateTime? timestamp,
    String? policy,
    bool? isPassed,
    Value<String?> failureReason = const Value.absent(),
    int? durationMs,
    double? meanPassiveScore,
    double? temporalConfidence,
    DateTime? createdAt,
  }) => DbAttemptLog(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    policy: policy ?? this.policy,
    isPassed: isPassed ?? this.isPassed,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    durationMs: durationMs ?? this.durationMs,
    meanPassiveScore: meanPassiveScore ?? this.meanPassiveScore,
    temporalConfidence: temporalConfidence ?? this.temporalConfidence,
    createdAt: createdAt ?? this.createdAt,
  );
  DbAttemptLog copyWithCompanion(AttemptLogsTableCompanion data) {
    return DbAttemptLog(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      policy: data.policy.present ? data.policy.value : this.policy,
      isPassed: data.isPassed.present ? data.isPassed.value : this.isPassed,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      meanPassiveScore: data.meanPassiveScore.present
          ? data.meanPassiveScore.value
          : this.meanPassiveScore,
      temporalConfidence: data.temporalConfidence.present
          ? data.temporalConfidence.value
          : this.temporalConfidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAttemptLog(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('policy: $policy, ')
          ..write('isPassed: $isPassed, ')
          ..write('failureReason: $failureReason, ')
          ..write('durationMs: $durationMs, ')
          ..write('meanPassiveScore: $meanPassiveScore, ')
          ..write('temporalConfidence: $temporalConfidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    policy,
    isPassed,
    failureReason,
    durationMs,
    meanPassiveScore,
    temporalConfidence,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAttemptLog &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.policy == this.policy &&
          other.isPassed == this.isPassed &&
          other.failureReason == this.failureReason &&
          other.durationMs == this.durationMs &&
          other.meanPassiveScore == this.meanPassiveScore &&
          other.temporalConfidence == this.temporalConfidence &&
          other.createdAt == this.createdAt);
}

class AttemptLogsTableCompanion extends UpdateCompanion<DbAttemptLog> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> policy;
  final Value<bool> isPassed;
  final Value<String?> failureReason;
  final Value<int> durationMs;
  final Value<double> meanPassiveScore;
  final Value<double> temporalConfidence;
  final Value<DateTime> createdAt;
  const AttemptLogsTableCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.policy = const Value.absent(),
    this.isPassed = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.meanPassiveScore = const Value.absent(),
    this.temporalConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttemptLogsTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String policy,
    required bool isPassed,
    this.failureReason = const Value.absent(),
    required int durationMs,
    required double meanPassiveScore,
    required double temporalConfidence,
    required DateTime createdAt,
  }) : timestamp = Value(timestamp),
       policy = Value(policy),
       isPassed = Value(isPassed),
       durationMs = Value(durationMs),
       meanPassiveScore = Value(meanPassiveScore),
       temporalConfidence = Value(temporalConfidence),
       createdAt = Value(createdAt);
  static Insertable<DbAttemptLog> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? policy,
    Expression<bool>? isPassed,
    Expression<String>? failureReason,
    Expression<int>? durationMs,
    Expression<double>? meanPassiveScore,
    Expression<double>? temporalConfidence,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (policy != null) 'policy': policy,
      if (isPassed != null) 'is_passed': isPassed,
      if (failureReason != null) 'failure_reason': failureReason,
      if (durationMs != null) 'duration_ms': durationMs,
      if (meanPassiveScore != null) 'mean_passive_score': meanPassiveScore,
      if (temporalConfidence != null) 'temporal_confidence': temporalConfidence,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttemptLogsTableCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? policy,
    Value<bool>? isPassed,
    Value<String?>? failureReason,
    Value<int>? durationMs,
    Value<double>? meanPassiveScore,
    Value<double>? temporalConfidence,
    Value<DateTime>? createdAt,
  }) {
    return AttemptLogsTableCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      policy: policy ?? this.policy,
      isPassed: isPassed ?? this.isPassed,
      failureReason: failureReason ?? this.failureReason,
      durationMs: durationMs ?? this.durationMs,
      meanPassiveScore: meanPassiveScore ?? this.meanPassiveScore,
      temporalConfidence: temporalConfidence ?? this.temporalConfidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (policy.present) {
      map['policy'] = Variable<String>(policy.value);
    }
    if (isPassed.present) {
      map['is_passed'] = Variable<bool>(isPassed.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (meanPassiveScore.present) {
      map['mean_passive_score'] = Variable<double>(meanPassiveScore.value);
    }
    if (temporalConfidence.present) {
      map['temporal_confidence'] = Variable<double>(temporalConfidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptLogsTableCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('policy: $policy, ')
          ..write('isPassed: $isPassed, ')
          ..write('failureReason: $failureReason, ')
          ..write('durationMs: $durationMs, ')
          ..write('meanPassiveScore: $meanPassiveScore, ')
          ..write('temporalConfidence: $temporalConfidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EmployeesTable employees = $EmployeesTable(this);
  late final $EmbeddingsTable embeddings = $EmbeddingsTable(this);
  late final $AttendanceRecordsTable attendanceRecords =
      $AttendanceRecordsTable(this);
  late final $AttemptLogsTableTable attemptLogsTable = $AttemptLogsTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    employees,
    embeddings,
    attendanceRecords,
    attemptLogsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'employees',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('embeddings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'employees',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attendance_records', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$EmployeesTableCreateCompanionBuilder = EmployeesCompanion Function({
  Value<int> id,
  required String employeeCode,
  required String name,
  Value<bool> isActive,
  required DateTime createdAt,
});
typedef $$EmployeesTableUpdateCompanionBuilder = EmployeesCompanion Function({
  Value<int> id,
  Value<String> employeeCode,
  Value<String> name,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});

final class $$EmployeesTableReferences
    extends BaseReferences<_$AppDatabase, $EmployeesTable, DbEmployee> {
  $$EmployeesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EmbeddingsTable, List<DbEmbedding>>
  _embeddingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.embeddings,
    aliasName: 'employees__id__embeddings__employee_id',
  );

  $$EmbeddingsTableProcessedTableManager get embeddingsRefs {
    final manager = $$EmbeddingsTableTableManager(
      $_db,
      $_db.embeddings,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_embeddingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttendanceRecordsTable, List<DbAttendanceRecord>>
  _attendanceRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attendanceRecords,
        aliasName: 'employees__id__attendance_records__employee_id',
      );

  $$AttendanceRecordsTableProcessedTableManager get attendanceRecordsRefs {
    final manager = $$AttendanceRecordsTableTableManager(
      $_db,
      $_db.attendanceRecords,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EmployeesTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeCode => $composableBuilder(
    column: $table.employeeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> embeddingsRefs(
    Expression<bool> Function($$EmbeddingsTableFilterComposer f) f,
  ) {
    final $$EmbeddingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.embeddings,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmbeddingsTableFilterComposer(
            $db: $db,
            $table: $db.embeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attendanceRecordsRefs(
    Expression<bool> Function($$AttendanceRecordsTableFilterComposer f) f,
  ) {
    final $$AttendanceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attendanceRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EmployeesTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeCode => $composableBuilder(
    column: $table.employeeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get employeeCode => $composableBuilder(
    column: $table.employeeCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> embeddingsRefs<T extends Object>(
    Expression<T> Function($$EmbeddingsTableAnnotationComposer a) f,
  ) {
    final $$EmbeddingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.embeddings,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmbeddingsTableAnnotationComposer(
            $db: $db,
            $table: $db.embeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attendanceRecordsRefs<T extends Object>(
    Expression<T> Function($$AttendanceRecordsTableAnnotationComposer a) f,
  ) {
    final $$AttendanceRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceRecords,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EmployeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeesTable,
          DbEmployee,
          $$EmployeesTableFilterComposer,
          $$EmployeesTableOrderingComposer,
          $$EmployeesTableAnnotationComposer,
          $$EmployeesTableCreateCompanionBuilder,
          $$EmployeesTableUpdateCompanionBuilder,
          (DbEmployee, $$EmployeesTableReferences),
          DbEmployee,
          PrefetchHooks Function({
            bool embeddingsRefs,
            bool attendanceRecordsRefs,
          })
        > {
  $$EmployeesTableTableManager(_$AppDatabase db, $EmployeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> employeeCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EmployeesCompanion(
                id: id,
                employeeCode: employeeCode,
                name: name,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String employeeCode,
                required String name,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
              }) => EmployeesCompanion.insert(
                id: id,
                employeeCode: employeeCode,
                name: name,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EmployeesTable, DbEmployee>(table),
                  $$EmployeesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({embeddingsRefs = false, attendanceRecordsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (embeddingsRefs) db.embeddings,
                    if (attendanceRecordsRefs) db.attendanceRecords,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (embeddingsRefs)
                        await $_getPrefetchedDataByColumns<
                          DbEmployee,
                          $EmployeesTable,
                          DbEmbedding,
                          $EmbeddingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._embeddingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).embeddingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'employee_id',
                          typedResults: items,
                        ),
                      if (attendanceRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          DbEmployee,
                          $EmployeesTable,
                          DbAttendanceRecord,
                          $AttendanceRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._attendanceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).attendanceRecordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'employee_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EmployeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeesTable,
      DbEmployee,
      $$EmployeesTableFilterComposer,
      $$EmployeesTableOrderingComposer,
      $$EmployeesTableAnnotationComposer,
      $$EmployeesTableCreateCompanionBuilder,
      $$EmployeesTableUpdateCompanionBuilder,
      (DbEmployee, $$EmployeesTableReferences),
      DbEmployee,
      PrefetchHooks Function({bool embeddingsRefs, bool attendanceRecordsRefs})
    >;
typedef $$EmbeddingsTableCreateCompanionBuilder = EmbeddingsCompanion Function({
  Value<int> id,
  required int employeeId,
  required Uint8List ciphertext,
  required Uint8List nonce,
  required Uint8List mac,
  required String modelId,
  required int dimension,
  required DateTime createdAt,
});
typedef $$EmbeddingsTableUpdateCompanionBuilder = EmbeddingsCompanion Function({
  Value<int> id,
  Value<int> employeeId,
  Value<Uint8List> ciphertext,
  Value<Uint8List> nonce,
  Value<Uint8List> mac,
  Value<String> modelId,
  Value<int> dimension,
  Value<DateTime> createdAt,
});

final class $$EmbeddingsTableReferences
    extends BaseReferences<_$AppDatabase, $EmbeddingsTable, DbEmbedding> {
  $$EmbeddingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) =>
      db.employees.createAlias('embeddings__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimension => $composableBuilder(
    column: $table.dimension,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimension => $composableBuilder(
    column: $table.dimension,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<Uint8List> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get dimension =>
      $composableBuilder(column: $table.dimension, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmbeddingsTable,
          DbEmbedding,
          $$EmbeddingsTableFilterComposer,
          $$EmbeddingsTableOrderingComposer,
          $$EmbeddingsTableAnnotationComposer,
          $$EmbeddingsTableCreateCompanionBuilder,
          $$EmbeddingsTableUpdateCompanionBuilder,
          (DbEmbedding, $$EmbeddingsTableReferences),
          DbEmbedding,
          PrefetchHooks Function({bool employeeId})
        > {
  $$EmbeddingsTableTableManager(_$AppDatabase db, $EmbeddingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<Uint8List> ciphertext = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<Uint8List> mac = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> dimension = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EmbeddingsCompanion(
                id: id,
                employeeId: employeeId,
                ciphertext: ciphertext,
                nonce: nonce,
                mac: mac,
                modelId: modelId,
                dimension: dimension,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required Uint8List ciphertext,
                required Uint8List nonce,
                required Uint8List mac,
                required String modelId,
                required int dimension,
                required DateTime createdAt,
              }) => EmbeddingsCompanion.insert(
                id: id,
                employeeId: employeeId,
                ciphertext: ciphertext,
                nonce: nonce,
                mac: mac,
                modelId: modelId,
                dimension: dimension,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EmbeddingsTable, DbEmbedding>(table),
                  $$EmbeddingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$EmbeddingsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$EmbeddingsTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmbeddingsTable,
      DbEmbedding,
      $$EmbeddingsTableFilterComposer,
      $$EmbeddingsTableOrderingComposer,
      $$EmbeddingsTableAnnotationComposer,
      $$EmbeddingsTableCreateCompanionBuilder,
      $$EmbeddingsTableUpdateCompanionBuilder,
      (DbEmbedding, $$EmbeddingsTableReferences),
      DbEmbedding,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$AttendanceRecordsTableCreateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<int> id,
      required int employeeId,
      required DateTime timestamp,
      required String recordType,
      required double similarityScore,
      required String status,
      Value<String?> notes,
    });
typedef $$AttendanceRecordsTableUpdateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<DateTime> timestamp,
      Value<String> recordType,
      Value<double> similarityScore,
      Value<String> status,
      Value<String?> notes,
    });

final class $$AttendanceRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttendanceRecordsTable,
          DbAttendanceRecord
        > {
  $$AttendanceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('attendance_records__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttendanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get similarityScore => $composableBuilder(
    column: $table.similarityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get similarityScore => $composableBuilder(
    column: $table.similarityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get similarityScore => $composableBuilder(
    column: $table.similarityScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceRecordsTable,
          DbAttendanceRecord,
          $$AttendanceRecordsTableFilterComposer,
          $$AttendanceRecordsTableOrderingComposer,
          $$AttendanceRecordsTableAnnotationComposer,
          $$AttendanceRecordsTableCreateCompanionBuilder,
          $$AttendanceRecordsTableUpdateCompanionBuilder,
          (DbAttendanceRecord, $$AttendanceRecordsTableReferences),
          DbAttendanceRecord,
          PrefetchHooks Function({bool employeeId})
        > {
  $$AttendanceRecordsTableTableManager(
    _$AppDatabase db,
    $AttendanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<double> similarityScore = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => AttendanceRecordsCompanion(
                id: id,
                employeeId: employeeId,
                timestamp: timestamp,
                recordType: recordType,
                similarityScore: similarityScore,
                status: status,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required DateTime timestamp,
                required String recordType,
                required double similarityScore,
                required String status,
                Value<String?> notes = const Value.absent(),
              }) => AttendanceRecordsCompanion.insert(
                id: id,
                employeeId: employeeId,
                timestamp: timestamp,
                recordType: recordType,
                similarityScore: similarityScore,
                status: status,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttendanceRecordsTable, DbAttendanceRecord>(
                    table,
                  ),
                  $$AttendanceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$AttendanceRecordsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$AttendanceRecordsTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttendanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceRecordsTable,
      DbAttendanceRecord,
      $$AttendanceRecordsTableFilterComposer,
      $$AttendanceRecordsTableOrderingComposer,
      $$AttendanceRecordsTableAnnotationComposer,
      $$AttendanceRecordsTableCreateCompanionBuilder,
      $$AttendanceRecordsTableUpdateCompanionBuilder,
      (DbAttendanceRecord, $$AttendanceRecordsTableReferences),
      DbAttendanceRecord,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$AttemptLogsTableTableCreateCompanionBuilder =
    AttemptLogsTableCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String policy,
      required bool isPassed,
      Value<String?> failureReason,
      required int durationMs,
      required double meanPassiveScore,
      required double temporalConfidence,
      required DateTime createdAt,
    });
typedef $$AttemptLogsTableTableUpdateCompanionBuilder =
    AttemptLogsTableCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> policy,
      Value<bool> isPassed,
      Value<String?> failureReason,
      Value<int> durationMs,
      Value<double> meanPassiveScore,
      Value<double> temporalConfidence,
      Value<DateTime> createdAt,
    });

class $$AttemptLogsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptLogsTableTable> {
  $$AttemptLogsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policy => $composableBuilder(
    column: $table.policy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPassed => $composableBuilder(
    column: $table.isPassed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meanPassiveScore => $composableBuilder(
    column: $table.meanPassiveScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temporalConfidence => $composableBuilder(
    column: $table.temporalConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttemptLogsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptLogsTableTable> {
  $$AttemptLogsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policy => $composableBuilder(
    column: $table.policy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPassed => $composableBuilder(
    column: $table.isPassed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meanPassiveScore => $composableBuilder(
    column: $table.meanPassiveScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temporalConfidence => $composableBuilder(
    column: $table.temporalConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptLogsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptLogsTableTable> {
  $$AttemptLogsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get policy =>
      $composableBuilder(column: $table.policy, builder: (column) => column);

  GeneratedColumn<bool> get isPassed =>
      $composableBuilder(column: $table.isPassed, builder: (column) => column);

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get meanPassiveScore => $composableBuilder(
    column: $table.meanPassiveScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temporalConfidence => $composableBuilder(
    column: $table.temporalConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttemptLogsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptLogsTableTable,
          DbAttemptLog,
          $$AttemptLogsTableTableFilterComposer,
          $$AttemptLogsTableTableOrderingComposer,
          $$AttemptLogsTableTableAnnotationComposer,
          $$AttemptLogsTableTableCreateCompanionBuilder,
          $$AttemptLogsTableTableUpdateCompanionBuilder,
          (
            DbAttemptLog,
            BaseReferences<_$AppDatabase, $AttemptLogsTableTable, DbAttemptLog>,
          ),
          DbAttemptLog,
          PrefetchHooks Function()
        > {
  $$AttemptLogsTableTableTableManager(
    _$AppDatabase db,
    $AttemptLogsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptLogsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptLogsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptLogsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> policy = const Value.absent(),
                Value<bool> isPassed = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> meanPassiveScore = const Value.absent(),
                Value<double> temporalConfidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttemptLogsTableCompanion(
                id: id,
                timestamp: timestamp,
                policy: policy,
                isPassed: isPassed,
                failureReason: failureReason,
                durationMs: durationMs,
                meanPassiveScore: meanPassiveScore,
                temporalConfidence: temporalConfidence,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String policy,
                required bool isPassed,
                Value<String?> failureReason = const Value.absent(),
                required int durationMs,
                required double meanPassiveScore,
                required double temporalConfidence,
                required DateTime createdAt,
              }) => AttemptLogsTableCompanion.insert(
                id: id,
                timestamp: timestamp,
                policy: policy,
                isPassed: isPassed,
                failureReason: failureReason,
                durationMs: durationMs,
                meanPassiveScore: meanPassiveScore,
                temporalConfidence: temporalConfidence,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptLogsTableTable, DbAttemptLog>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AttemptLogsTableTable,
                    DbAttemptLog
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttemptLogsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptLogsTableTable,
      DbAttemptLog,
      $$AttemptLogsTableTableFilterComposer,
      $$AttemptLogsTableTableOrderingComposer,
      $$AttemptLogsTableTableAnnotationComposer,
      $$AttemptLogsTableTableCreateCompanionBuilder,
      $$AttemptLogsTableTableUpdateCompanionBuilder,
      (
        DbAttemptLog,
        BaseReferences<_$AppDatabase, $AttemptLogsTableTable, DbAttemptLog>,
      ),
      DbAttemptLog,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db, _db.employees);
  $$EmbeddingsTableTableManager get embeddings =>
      $$EmbeddingsTableTableManager(_db, _db.embeddings);
  $$AttendanceRecordsTableTableManager get attendanceRecords =>
      $$AttendanceRecordsTableTableManager(_db, _db.attendanceRecords);
  $$AttemptLogsTableTableTableManager get attemptLogsTable =>
      $$AttemptLogsTableTableTableManager(_db, _db.attemptLogsTable);
}

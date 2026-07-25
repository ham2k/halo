// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OperationsTable extends Operations
    with TableInfo<$OperationsTable, OperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _localDataMeta = const VerificationMeta(
    'localData',
  );
  @override
  late final GeneratedColumn<String> localData = GeneratedColumn<String>(
    'local_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMillisMinMeta = const VerificationMeta(
    'startAtMillisMin',
  );
  @override
  late final GeneratedColumn<int> startAtMillisMin = GeneratedColumn<int>(
    'start_at_millis_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMillisMaxMeta = const VerificationMeta(
    'startAtMillisMax',
  );
  @override
  late final GeneratedColumn<int> startAtMillisMax = GeneratedColumn<int>(
    'start_at_millis_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qsoCountMeta = const VerificationMeta(
    'qsoCount',
  );
  @override
  late final GeneratedColumn<int> qsoCount = GeneratedColumn<int>(
    'qso_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMillisMeta = const VerificationMeta(
    'updatedAtMillis',
  );
  @override
  late final GeneratedColumn<int> updatedAtMillis = GeneratedColumn<int>(
    'updated_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    data,
    localData,
    startAtMillisMin,
    startAtMillisMax,
    qsoCount,
    deleted,
    synced,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('local_data')) {
      context.handle(
        _localDataMeta,
        localData.isAcceptableOrUnknown(data['local_data']!, _localDataMeta),
      );
    }
    if (data.containsKey('start_at_millis_min')) {
      context.handle(
        _startAtMillisMinMeta,
        startAtMillisMin.isAcceptableOrUnknown(
          data['start_at_millis_min']!,
          _startAtMillisMinMeta,
        ),
      );
    }
    if (data.containsKey('start_at_millis_max')) {
      context.handle(
        _startAtMillisMaxMeta,
        startAtMillisMax.isAcceptableOrUnknown(
          data['start_at_millis_max']!,
          _startAtMillisMaxMeta,
        ),
      );
    }
    if (data.containsKey('qso_count')) {
      context.handle(
        _qsoCountMeta,
        qsoCount.isAcceptableOrUnknown(data['qso_count']!, _qsoCountMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('updated_at_millis')) {
      context.handle(
        _updatedAtMillisMeta,
        updatedAtMillis.isAcceptableOrUnknown(
          data['updated_at_millis']!,
          _updatedAtMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  OperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      localData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_data'],
      ),
      startAtMillisMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_millis_min'],
      ),
      startAtMillisMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_millis_max'],
      ),
      qsoCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qso_count'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      ),
    );
  }

  @override
  $OperationsTable createAlias(String alias) {
    return $OperationsTable(attachedDatabase, alias);
  }
}

class OperationRow extends DataClass implements Insertable<OperationRow> {
  final String uuid;
  final String data;

  /// Device-local state that never syncs (e.g. UI preferences per operation).
  final String? localData;
  final int? startAtMillisMin;
  final int? startAtMillisMax;
  final int qsoCount;
  final bool deleted;
  final bool synced;

  /// Mirrors `data.updatedAtMillis` (stamped on every local write, app-polo
  /// convention) so sync can compare revisions without decoding the blob:
  /// `markSynced` only flips rows whose stamp still matches what was sent,
  /// and `mergeFromSync` skips inbound records older than the local row.
  final int? updatedAtMillis;
  const OperationRow({
    required this.uuid,
    required this.data,
    this.localData,
    this.startAtMillisMin,
    this.startAtMillisMax,
    required this.qsoCount,
    required this.deleted,
    required this.synced,
    this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || localData != null) {
      map['local_data'] = Variable<String>(localData);
    }
    if (!nullToAbsent || startAtMillisMin != null) {
      map['start_at_millis_min'] = Variable<int>(startAtMillisMin);
    }
    if (!nullToAbsent || startAtMillisMax != null) {
      map['start_at_millis_max'] = Variable<int>(startAtMillisMax);
    }
    map['qso_count'] = Variable<int>(qsoCount);
    map['deleted'] = Variable<bool>(deleted);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || updatedAtMillis != null) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    }
    return map;
  }

  OperationsCompanion toCompanion(bool nullToAbsent) {
    return OperationsCompanion(
      uuid: Value(uuid),
      data: Value(data),
      localData: localData == null && nullToAbsent
          ? const Value.absent()
          : Value(localData),
      startAtMillisMin: startAtMillisMin == null && nullToAbsent
          ? const Value.absent()
          : Value(startAtMillisMin),
      startAtMillisMax: startAtMillisMax == null && nullToAbsent
          ? const Value.absent()
          : Value(startAtMillisMax),
      qsoCount: Value(qsoCount),
      deleted: Value(deleted),
      synced: Value(synced),
      updatedAtMillis: updatedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtMillis),
    );
  }

  factory OperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      data: serializer.fromJson<String>(json['data']),
      localData: serializer.fromJson<String?>(json['localData']),
      startAtMillisMin: serializer.fromJson<int?>(json['startAtMillisMin']),
      startAtMillisMax: serializer.fromJson<int?>(json['startAtMillisMax']),
      qsoCount: serializer.fromJson<int>(json['qsoCount']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      synced: serializer.fromJson<bool>(json['synced']),
      updatedAtMillis: serializer.fromJson<int?>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'data': serializer.toJson<String>(data),
      'localData': serializer.toJson<String?>(localData),
      'startAtMillisMin': serializer.toJson<int?>(startAtMillisMin),
      'startAtMillisMax': serializer.toJson<int?>(startAtMillisMax),
      'qsoCount': serializer.toJson<int>(qsoCount),
      'deleted': serializer.toJson<bool>(deleted),
      'synced': serializer.toJson<bool>(synced),
      'updatedAtMillis': serializer.toJson<int?>(updatedAtMillis),
    };
  }

  OperationRow copyWith({
    String? uuid,
    String? data,
    Value<String?> localData = const Value.absent(),
    Value<int?> startAtMillisMin = const Value.absent(),
    Value<int?> startAtMillisMax = const Value.absent(),
    int? qsoCount,
    bool? deleted,
    bool? synced,
    Value<int?> updatedAtMillis = const Value.absent(),
  }) => OperationRow(
    uuid: uuid ?? this.uuid,
    data: data ?? this.data,
    localData: localData.present ? localData.value : this.localData,
    startAtMillisMin: startAtMillisMin.present
        ? startAtMillisMin.value
        : this.startAtMillisMin,
    startAtMillisMax: startAtMillisMax.present
        ? startAtMillisMax.value
        : this.startAtMillisMax,
    qsoCount: qsoCount ?? this.qsoCount,
    deleted: deleted ?? this.deleted,
    synced: synced ?? this.synced,
    updatedAtMillis: updatedAtMillis.present
        ? updatedAtMillis.value
        : this.updatedAtMillis,
  );
  OperationRow copyWithCompanion(OperationsCompanion data) {
    return OperationRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      data: data.data.present ? data.data.value : this.data,
      localData: data.localData.present ? data.localData.value : this.localData,
      startAtMillisMin: data.startAtMillisMin.present
          ? data.startAtMillisMin.value
          : this.startAtMillisMin,
      startAtMillisMax: data.startAtMillisMax.present
          ? data.startAtMillisMax.value
          : this.startAtMillisMax,
      qsoCount: data.qsoCount.present ? data.qsoCount.value : this.qsoCount,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      synced: data.synced.present ? data.synced.value : this.synced,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationRow(')
          ..write('uuid: $uuid, ')
          ..write('data: $data, ')
          ..write('localData: $localData, ')
          ..write('startAtMillisMin: $startAtMillisMin, ')
          ..write('startAtMillisMax: $startAtMillisMax, ')
          ..write('qsoCount: $qsoCount, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    data,
    localData,
    startAtMillisMin,
    startAtMillisMax,
    qsoCount,
    deleted,
    synced,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationRow &&
          other.uuid == this.uuid &&
          other.data == this.data &&
          other.localData == this.localData &&
          other.startAtMillisMin == this.startAtMillisMin &&
          other.startAtMillisMax == this.startAtMillisMax &&
          other.qsoCount == this.qsoCount &&
          other.deleted == this.deleted &&
          other.synced == this.synced &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class OperationsCompanion extends UpdateCompanion<OperationRow> {
  final Value<String> uuid;
  final Value<String> data;
  final Value<String?> localData;
  final Value<int?> startAtMillisMin;
  final Value<int?> startAtMillisMax;
  final Value<int> qsoCount;
  final Value<bool> deleted;
  final Value<bool> synced;
  final Value<int?> updatedAtMillis;
  final Value<int> rowid;
  const OperationsCompanion({
    this.uuid = const Value.absent(),
    this.data = const Value.absent(),
    this.localData = const Value.absent(),
    this.startAtMillisMin = const Value.absent(),
    this.startAtMillisMax = const Value.absent(),
    this.qsoCount = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationsCompanion.insert({
    required String uuid,
    this.data = const Value.absent(),
    this.localData = const Value.absent(),
    this.startAtMillisMin = const Value.absent(),
    this.startAtMillisMax = const Value.absent(),
    this.qsoCount = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid);
  static Insertable<OperationRow> custom({
    Expression<String>? uuid,
    Expression<String>? data,
    Expression<String>? localData,
    Expression<int>? startAtMillisMin,
    Expression<int>? startAtMillisMax,
    Expression<int>? qsoCount,
    Expression<bool>? deleted,
    Expression<bool>? synced,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (data != null) 'data': data,
      if (localData != null) 'local_data': localData,
      if (startAtMillisMin != null) 'start_at_millis_min': startAtMillisMin,
      if (startAtMillisMax != null) 'start_at_millis_max': startAtMillisMax,
      if (qsoCount != null) 'qso_count': qsoCount,
      if (deleted != null) 'deleted': deleted,
      if (synced != null) 'synced': synced,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? data,
    Value<String?>? localData,
    Value<int?>? startAtMillisMin,
    Value<int?>? startAtMillisMax,
    Value<int>? qsoCount,
    Value<bool>? deleted,
    Value<bool>? synced,
    Value<int?>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return OperationsCompanion(
      uuid: uuid ?? this.uuid,
      data: data ?? this.data,
      localData: localData ?? this.localData,
      startAtMillisMin: startAtMillisMin ?? this.startAtMillisMin,
      startAtMillisMax: startAtMillisMax ?? this.startAtMillisMax,
      qsoCount: qsoCount ?? this.qsoCount,
      deleted: deleted ?? this.deleted,
      synced: synced ?? this.synced,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (localData.present) {
      map['local_data'] = Variable<String>(localData.value);
    }
    if (startAtMillisMin.present) {
      map['start_at_millis_min'] = Variable<int>(startAtMillisMin.value);
    }
    if (startAtMillisMax.present) {
      map['start_at_millis_max'] = Variable<int>(startAtMillisMax.value);
    }
    if (qsoCount.present) {
      map['qso_count'] = Variable<int>(qsoCount.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('data: $data, ')
          ..write('localData: $localData, ')
          ..write('startAtMillisMin: $startAtMillisMin, ')
          ..write('startAtMillisMax: $startAtMillisMax, ')
          ..write('qsoCount: $qsoCount, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QsosTable extends Qsos with TableInfo<$QsosTable, QsoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QsosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ourCallMeta = const VerificationMeta(
    'ourCall',
  );
  @override
  late final GeneratedColumn<String> ourCall = GeneratedColumn<String>(
    'our_call',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _theirCallMeta = const VerificationMeta(
    'theirCall',
  );
  @override
  late final GeneratedColumn<String> theirCall = GeneratedColumn<String>(
    'their_call',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bandMeta = const VerificationMeta('band');
  @override
  late final GeneratedColumn<String> band = GeneratedColumn<String>(
    'band',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMillisMeta = const VerificationMeta(
    'startAtMillis',
  );
  @override
  late final GeneratedColumn<int> startAtMillis = GeneratedColumn<int>(
    'start_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scoreCacheMeta = const VerificationMeta(
    'scoreCache',
  );
  @override
  late final GeneratedColumn<String> scoreCache = GeneratedColumn<String>(
    'score_cache',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMillisMeta = const VerificationMeta(
    'updatedAtMillis',
  );
  @override
  late final GeneratedColumn<int> updatedAtMillis = GeneratedColumn<int>(
    'updated_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    operation,
    ourCall,
    theirCall,
    band,
    mode,
    startAtMillis,
    data,
    deleted,
    synced,
    scoreCache,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qsos';
  @override
  VerificationContext validateIntegrity(
    Insertable<QsoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('our_call')) {
      context.handle(
        _ourCallMeta,
        ourCall.isAcceptableOrUnknown(data['our_call']!, _ourCallMeta),
      );
    }
    if (data.containsKey('their_call')) {
      context.handle(
        _theirCallMeta,
        theirCall.isAcceptableOrUnknown(data['their_call']!, _theirCallMeta),
      );
    }
    if (data.containsKey('band')) {
      context.handle(
        _bandMeta,
        band.isAcceptableOrUnknown(data['band']!, _bandMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('start_at_millis')) {
      context.handle(
        _startAtMillisMeta,
        startAtMillis.isAcceptableOrUnknown(
          data['start_at_millis']!,
          _startAtMillisMeta,
        ),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('score_cache')) {
      context.handle(
        _scoreCacheMeta,
        scoreCache.isAcceptableOrUnknown(data['score_cache']!, _scoreCacheMeta),
      );
    }
    if (data.containsKey('updated_at_millis')) {
      context.handle(
        _updatedAtMillisMeta,
        updatedAtMillis.isAcceptableOrUnknown(
          data['updated_at_millis']!,
          _updatedAtMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  QsoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QsoRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      ourCall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}our_call'],
      ),
      theirCall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}their_call'],
      ),
      band: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      startAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_millis'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      scoreCache: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_cache'],
      ),
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      ),
    );
  }

  @override
  $QsosTable createAlias(String alias) {
    return $QsosTable(attachedDatabase, alias);
  }
}

class QsoRow extends DataClass implements Insertable<QsoRow> {
  final String uuid;
  final String operation;
  final String? ourCall;
  final String? theirCall;
  final String? band;
  final String? mode;
  final int? startAtMillis;
  final String data;
  final bool deleted;
  final bool synced;

  /// Cached plugin scoring results so list rendering never waits on the
  /// plugin runtime (DESIGN.md §4). Unused until the scoring hooks land.
  final String? scoreCache;

  /// See `Operations.updatedAtMillis`.
  final int? updatedAtMillis;
  const QsoRow({
    required this.uuid,
    required this.operation,
    this.ourCall,
    this.theirCall,
    this.band,
    this.mode,
    this.startAtMillis,
    required this.data,
    required this.deleted,
    required this.synced,
    this.scoreCache,
    this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || ourCall != null) {
      map['our_call'] = Variable<String>(ourCall);
    }
    if (!nullToAbsent || theirCall != null) {
      map['their_call'] = Variable<String>(theirCall);
    }
    if (!nullToAbsent || band != null) {
      map['band'] = Variable<String>(band);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || startAtMillis != null) {
      map['start_at_millis'] = Variable<int>(startAtMillis);
    }
    map['data'] = Variable<String>(data);
    map['deleted'] = Variable<bool>(deleted);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || scoreCache != null) {
      map['score_cache'] = Variable<String>(scoreCache);
    }
    if (!nullToAbsent || updatedAtMillis != null) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    }
    return map;
  }

  QsosCompanion toCompanion(bool nullToAbsent) {
    return QsosCompanion(
      uuid: Value(uuid),
      operation: Value(operation),
      ourCall: ourCall == null && nullToAbsent
          ? const Value.absent()
          : Value(ourCall),
      theirCall: theirCall == null && nullToAbsent
          ? const Value.absent()
          : Value(theirCall),
      band: band == null && nullToAbsent ? const Value.absent() : Value(band),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      startAtMillis: startAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(startAtMillis),
      data: Value(data),
      deleted: Value(deleted),
      synced: Value(synced),
      scoreCache: scoreCache == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreCache),
      updatedAtMillis: updatedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtMillis),
    );
  }

  factory QsoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QsoRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      operation: serializer.fromJson<String>(json['operation']),
      ourCall: serializer.fromJson<String?>(json['ourCall']),
      theirCall: serializer.fromJson<String?>(json['theirCall']),
      band: serializer.fromJson<String?>(json['band']),
      mode: serializer.fromJson<String?>(json['mode']),
      startAtMillis: serializer.fromJson<int?>(json['startAtMillis']),
      data: serializer.fromJson<String>(json['data']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      synced: serializer.fromJson<bool>(json['synced']),
      scoreCache: serializer.fromJson<String?>(json['scoreCache']),
      updatedAtMillis: serializer.fromJson<int?>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'operation': serializer.toJson<String>(operation),
      'ourCall': serializer.toJson<String?>(ourCall),
      'theirCall': serializer.toJson<String?>(theirCall),
      'band': serializer.toJson<String?>(band),
      'mode': serializer.toJson<String?>(mode),
      'startAtMillis': serializer.toJson<int?>(startAtMillis),
      'data': serializer.toJson<String>(data),
      'deleted': serializer.toJson<bool>(deleted),
      'synced': serializer.toJson<bool>(synced),
      'scoreCache': serializer.toJson<String?>(scoreCache),
      'updatedAtMillis': serializer.toJson<int?>(updatedAtMillis),
    };
  }

  QsoRow copyWith({
    String? uuid,
    String? operation,
    Value<String?> ourCall = const Value.absent(),
    Value<String?> theirCall = const Value.absent(),
    Value<String?> band = const Value.absent(),
    Value<String?> mode = const Value.absent(),
    Value<int?> startAtMillis = const Value.absent(),
    String? data,
    bool? deleted,
    bool? synced,
    Value<String?> scoreCache = const Value.absent(),
    Value<int?> updatedAtMillis = const Value.absent(),
  }) => QsoRow(
    uuid: uuid ?? this.uuid,
    operation: operation ?? this.operation,
    ourCall: ourCall.present ? ourCall.value : this.ourCall,
    theirCall: theirCall.present ? theirCall.value : this.theirCall,
    band: band.present ? band.value : this.band,
    mode: mode.present ? mode.value : this.mode,
    startAtMillis: startAtMillis.present
        ? startAtMillis.value
        : this.startAtMillis,
    data: data ?? this.data,
    deleted: deleted ?? this.deleted,
    synced: synced ?? this.synced,
    scoreCache: scoreCache.present ? scoreCache.value : this.scoreCache,
    updatedAtMillis: updatedAtMillis.present
        ? updatedAtMillis.value
        : this.updatedAtMillis,
  );
  QsoRow copyWithCompanion(QsosCompanion data) {
    return QsoRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      operation: data.operation.present ? data.operation.value : this.operation,
      ourCall: data.ourCall.present ? data.ourCall.value : this.ourCall,
      theirCall: data.theirCall.present ? data.theirCall.value : this.theirCall,
      band: data.band.present ? data.band.value : this.band,
      mode: data.mode.present ? data.mode.value : this.mode,
      startAtMillis: data.startAtMillis.present
          ? data.startAtMillis.value
          : this.startAtMillis,
      data: data.data.present ? data.data.value : this.data,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      synced: data.synced.present ? data.synced.value : this.synced,
      scoreCache: data.scoreCache.present
          ? data.scoreCache.value
          : this.scoreCache,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QsoRow(')
          ..write('uuid: $uuid, ')
          ..write('operation: $operation, ')
          ..write('ourCall: $ourCall, ')
          ..write('theirCall: $theirCall, ')
          ..write('band: $band, ')
          ..write('mode: $mode, ')
          ..write('startAtMillis: $startAtMillis, ')
          ..write('data: $data, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
          ..write('scoreCache: $scoreCache, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    operation,
    ourCall,
    theirCall,
    band,
    mode,
    startAtMillis,
    data,
    deleted,
    synced,
    scoreCache,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QsoRow &&
          other.uuid == this.uuid &&
          other.operation == this.operation &&
          other.ourCall == this.ourCall &&
          other.theirCall == this.theirCall &&
          other.band == this.band &&
          other.mode == this.mode &&
          other.startAtMillis == this.startAtMillis &&
          other.data == this.data &&
          other.deleted == this.deleted &&
          other.synced == this.synced &&
          other.scoreCache == this.scoreCache &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class QsosCompanion extends UpdateCompanion<QsoRow> {
  final Value<String> uuid;
  final Value<String> operation;
  final Value<String?> ourCall;
  final Value<String?> theirCall;
  final Value<String?> band;
  final Value<String?> mode;
  final Value<int?> startAtMillis;
  final Value<String> data;
  final Value<bool> deleted;
  final Value<bool> synced;
  final Value<String?> scoreCache;
  final Value<int?> updatedAtMillis;
  final Value<int> rowid;
  const QsosCompanion({
    this.uuid = const Value.absent(),
    this.operation = const Value.absent(),
    this.ourCall = const Value.absent(),
    this.theirCall = const Value.absent(),
    this.band = const Value.absent(),
    this.mode = const Value.absent(),
    this.startAtMillis = const Value.absent(),
    this.data = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.scoreCache = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QsosCompanion.insert({
    required String uuid,
    required String operation,
    this.ourCall = const Value.absent(),
    this.theirCall = const Value.absent(),
    this.band = const Value.absent(),
    this.mode = const Value.absent(),
    this.startAtMillis = const Value.absent(),
    this.data = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.scoreCache = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       operation = Value(operation);
  static Insertable<QsoRow> custom({
    Expression<String>? uuid,
    Expression<String>? operation,
    Expression<String>? ourCall,
    Expression<String>? theirCall,
    Expression<String>? band,
    Expression<String>? mode,
    Expression<int>? startAtMillis,
    Expression<String>? data,
    Expression<bool>? deleted,
    Expression<bool>? synced,
    Expression<String>? scoreCache,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (operation != null) 'operation': operation,
      if (ourCall != null) 'our_call': ourCall,
      if (theirCall != null) 'their_call': theirCall,
      if (band != null) 'band': band,
      if (mode != null) 'mode': mode,
      if (startAtMillis != null) 'start_at_millis': startAtMillis,
      if (data != null) 'data': data,
      if (deleted != null) 'deleted': deleted,
      if (synced != null) 'synced': synced,
      if (scoreCache != null) 'score_cache': scoreCache,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QsosCompanion copyWith({
    Value<String>? uuid,
    Value<String>? operation,
    Value<String?>? ourCall,
    Value<String?>? theirCall,
    Value<String?>? band,
    Value<String?>? mode,
    Value<int?>? startAtMillis,
    Value<String>? data,
    Value<bool>? deleted,
    Value<bool>? synced,
    Value<String?>? scoreCache,
    Value<int?>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return QsosCompanion(
      uuid: uuid ?? this.uuid,
      operation: operation ?? this.operation,
      ourCall: ourCall ?? this.ourCall,
      theirCall: theirCall ?? this.theirCall,
      band: band ?? this.band,
      mode: mode ?? this.mode,
      startAtMillis: startAtMillis ?? this.startAtMillis,
      data: data ?? this.data,
      deleted: deleted ?? this.deleted,
      synced: synced ?? this.synced,
      scoreCache: scoreCache ?? this.scoreCache,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (ourCall.present) {
      map['our_call'] = Variable<String>(ourCall.value);
    }
    if (theirCall.present) {
      map['their_call'] = Variable<String>(theirCall.value);
    }
    if (band.present) {
      map['band'] = Variable<String>(band.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startAtMillis.present) {
      map['start_at_millis'] = Variable<int>(startAtMillis.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (scoreCache.present) {
      map['score_cache'] = Variable<String>(scoreCache.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QsosCompanion(')
          ..write('uuid: $uuid, ')
          ..write('operation: $operation, ')
          ..write('ourCall: $ourCall, ')
          ..write('theirCall: $theirCall, ')
          ..write('band: $band, ')
          ..write('mode: $mode, ')
          ..write('startAtMillis: $startAtMillis, ')
          ..write('data: $data, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
          ..write('scoreCache: $scoreCache, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperationsBackupTable extends OperationsBackup
    with TableInfo<$OperationsBackupTable, OperationBackupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationsBackupTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _backupIdMeta = const VerificationMeta(
    'backupId',
  );
  @override
  late final GeneratedColumn<String> backupId = GeneratedColumn<String>(
    'backup_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backupAtMillisMeta = const VerificationMeta(
    'backupAtMillis',
  );
  @override
  late final GeneratedColumn<int> backupAtMillis = GeneratedColumn<int>(
    'backup_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMillisMinMeta = const VerificationMeta(
    'startAtMillisMin',
  );
  @override
  late final GeneratedColumn<int> startAtMillisMin = GeneratedColumn<int>(
    'start_at_millis_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMillisMaxMeta = const VerificationMeta(
    'startAtMillisMax',
  );
  @override
  late final GeneratedColumn<int> startAtMillisMax = GeneratedColumn<int>(
    'start_at_millis_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qsoCountMeta = const VerificationMeta(
    'qsoCount',
  );
  @override
  late final GeneratedColumn<int> qsoCount = GeneratedColumn<int>(
    'qso_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    backupId,
    backupAtMillis,
    uuid,
    data,
    startAtMillisMin,
    startAtMillisMax,
    qsoCount,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operations_backup';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationBackupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('backup_id')) {
      context.handle(
        _backupIdMeta,
        backupId.isAcceptableOrUnknown(data['backup_id']!, _backupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_backupIdMeta);
    }
    if (data.containsKey('backup_at_millis')) {
      context.handle(
        _backupAtMillisMeta,
        backupAtMillis.isAcceptableOrUnknown(
          data['backup_at_millis']!,
          _backupAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backupAtMillisMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('start_at_millis_min')) {
      context.handle(
        _startAtMillisMinMeta,
        startAtMillisMin.isAcceptableOrUnknown(
          data['start_at_millis_min']!,
          _startAtMillisMinMeta,
        ),
      );
    }
    if (data.containsKey('start_at_millis_max')) {
      context.handle(
        _startAtMillisMaxMeta,
        startAtMillisMax.isAcceptableOrUnknown(
          data['start_at_millis_max']!,
          _startAtMillisMaxMeta,
        ),
      );
    }
    if (data.containsKey('qso_count')) {
      context.handle(
        _qsoCountMeta,
        qsoCount.isAcceptableOrUnknown(data['qso_count']!, _qsoCountMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationBackupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationBackupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      backupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_id'],
      )!,
      backupAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backup_at_millis'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      startAtMillisMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_millis_min'],
      ),
      startAtMillisMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_millis_max'],
      ),
      qsoCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qso_count'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $OperationsBackupTable createAlias(String alias) {
    return $OperationsBackupTable(attachedDatabase, alias);
  }
}

class OperationBackupRow extends DataClass
    implements Insertable<OperationBackupRow> {
  final int id;
  final String backupId;
  final int backupAtMillis;
  final String uuid;
  final String data;
  final int? startAtMillisMin;
  final int? startAtMillisMax;
  final int qsoCount;
  final bool deleted;
  const OperationBackupRow({
    required this.id,
    required this.backupId,
    required this.backupAtMillis,
    required this.uuid,
    required this.data,
    this.startAtMillisMin,
    this.startAtMillisMax,
    required this.qsoCount,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['backup_id'] = Variable<String>(backupId);
    map['backup_at_millis'] = Variable<int>(backupAtMillis);
    map['uuid'] = Variable<String>(uuid);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || startAtMillisMin != null) {
      map['start_at_millis_min'] = Variable<int>(startAtMillisMin);
    }
    if (!nullToAbsent || startAtMillisMax != null) {
      map['start_at_millis_max'] = Variable<int>(startAtMillisMax);
    }
    map['qso_count'] = Variable<int>(qsoCount);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  OperationsBackupCompanion toCompanion(bool nullToAbsent) {
    return OperationsBackupCompanion(
      id: Value(id),
      backupId: Value(backupId),
      backupAtMillis: Value(backupAtMillis),
      uuid: Value(uuid),
      data: Value(data),
      startAtMillisMin: startAtMillisMin == null && nullToAbsent
          ? const Value.absent()
          : Value(startAtMillisMin),
      startAtMillisMax: startAtMillisMax == null && nullToAbsent
          ? const Value.absent()
          : Value(startAtMillisMax),
      qsoCount: Value(qsoCount),
      deleted: Value(deleted),
    );
  }

  factory OperationBackupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationBackupRow(
      id: serializer.fromJson<int>(json['id']),
      backupId: serializer.fromJson<String>(json['backupId']),
      backupAtMillis: serializer.fromJson<int>(json['backupAtMillis']),
      uuid: serializer.fromJson<String>(json['uuid']),
      data: serializer.fromJson<String>(json['data']),
      startAtMillisMin: serializer.fromJson<int?>(json['startAtMillisMin']),
      startAtMillisMax: serializer.fromJson<int?>(json['startAtMillisMax']),
      qsoCount: serializer.fromJson<int>(json['qsoCount']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'backupId': serializer.toJson<String>(backupId),
      'backupAtMillis': serializer.toJson<int>(backupAtMillis),
      'uuid': serializer.toJson<String>(uuid),
      'data': serializer.toJson<String>(data),
      'startAtMillisMin': serializer.toJson<int?>(startAtMillisMin),
      'startAtMillisMax': serializer.toJson<int?>(startAtMillisMax),
      'qsoCount': serializer.toJson<int>(qsoCount),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  OperationBackupRow copyWith({
    int? id,
    String? backupId,
    int? backupAtMillis,
    String? uuid,
    String? data,
    Value<int?> startAtMillisMin = const Value.absent(),
    Value<int?> startAtMillisMax = const Value.absent(),
    int? qsoCount,
    bool? deleted,
  }) => OperationBackupRow(
    id: id ?? this.id,
    backupId: backupId ?? this.backupId,
    backupAtMillis: backupAtMillis ?? this.backupAtMillis,
    uuid: uuid ?? this.uuid,
    data: data ?? this.data,
    startAtMillisMin: startAtMillisMin.present
        ? startAtMillisMin.value
        : this.startAtMillisMin,
    startAtMillisMax: startAtMillisMax.present
        ? startAtMillisMax.value
        : this.startAtMillisMax,
    qsoCount: qsoCount ?? this.qsoCount,
    deleted: deleted ?? this.deleted,
  );
  OperationBackupRow copyWithCompanion(OperationsBackupCompanion data) {
    return OperationBackupRow(
      id: data.id.present ? data.id.value : this.id,
      backupId: data.backupId.present ? data.backupId.value : this.backupId,
      backupAtMillis: data.backupAtMillis.present
          ? data.backupAtMillis.value
          : this.backupAtMillis,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      data: data.data.present ? data.data.value : this.data,
      startAtMillisMin: data.startAtMillisMin.present
          ? data.startAtMillisMin.value
          : this.startAtMillisMin,
      startAtMillisMax: data.startAtMillisMax.present
          ? data.startAtMillisMax.value
          : this.startAtMillisMax,
      qsoCount: data.qsoCount.present ? data.qsoCount.value : this.qsoCount,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationBackupRow(')
          ..write('id: $id, ')
          ..write('backupId: $backupId, ')
          ..write('backupAtMillis: $backupAtMillis, ')
          ..write('uuid: $uuid, ')
          ..write('data: $data, ')
          ..write('startAtMillisMin: $startAtMillisMin, ')
          ..write('startAtMillisMax: $startAtMillisMax, ')
          ..write('qsoCount: $qsoCount, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    backupId,
    backupAtMillis,
    uuid,
    data,
    startAtMillisMin,
    startAtMillisMax,
    qsoCount,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationBackupRow &&
          other.id == this.id &&
          other.backupId == this.backupId &&
          other.backupAtMillis == this.backupAtMillis &&
          other.uuid == this.uuid &&
          other.data == this.data &&
          other.startAtMillisMin == this.startAtMillisMin &&
          other.startAtMillisMax == this.startAtMillisMax &&
          other.qsoCount == this.qsoCount &&
          other.deleted == this.deleted);
}

class OperationsBackupCompanion extends UpdateCompanion<OperationBackupRow> {
  final Value<int> id;
  final Value<String> backupId;
  final Value<int> backupAtMillis;
  final Value<String> uuid;
  final Value<String> data;
  final Value<int?> startAtMillisMin;
  final Value<int?> startAtMillisMax;
  final Value<int> qsoCount;
  final Value<bool> deleted;
  const OperationsBackupCompanion({
    this.id = const Value.absent(),
    this.backupId = const Value.absent(),
    this.backupAtMillis = const Value.absent(),
    this.uuid = const Value.absent(),
    this.data = const Value.absent(),
    this.startAtMillisMin = const Value.absent(),
    this.startAtMillisMax = const Value.absent(),
    this.qsoCount = const Value.absent(),
    this.deleted = const Value.absent(),
  });
  OperationsBackupCompanion.insert({
    this.id = const Value.absent(),
    required String backupId,
    required int backupAtMillis,
    required String uuid,
    required String data,
    this.startAtMillisMin = const Value.absent(),
    this.startAtMillisMax = const Value.absent(),
    this.qsoCount = const Value.absent(),
    this.deleted = const Value.absent(),
  }) : backupId = Value(backupId),
       backupAtMillis = Value(backupAtMillis),
       uuid = Value(uuid),
       data = Value(data);
  static Insertable<OperationBackupRow> custom({
    Expression<int>? id,
    Expression<String>? backupId,
    Expression<int>? backupAtMillis,
    Expression<String>? uuid,
    Expression<String>? data,
    Expression<int>? startAtMillisMin,
    Expression<int>? startAtMillisMax,
    Expression<int>? qsoCount,
    Expression<bool>? deleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (backupId != null) 'backup_id': backupId,
      if (backupAtMillis != null) 'backup_at_millis': backupAtMillis,
      if (uuid != null) 'uuid': uuid,
      if (data != null) 'data': data,
      if (startAtMillisMin != null) 'start_at_millis_min': startAtMillisMin,
      if (startAtMillisMax != null) 'start_at_millis_max': startAtMillisMax,
      if (qsoCount != null) 'qso_count': qsoCount,
      if (deleted != null) 'deleted': deleted,
    });
  }

  OperationsBackupCompanion copyWith({
    Value<int>? id,
    Value<String>? backupId,
    Value<int>? backupAtMillis,
    Value<String>? uuid,
    Value<String>? data,
    Value<int?>? startAtMillisMin,
    Value<int?>? startAtMillisMax,
    Value<int>? qsoCount,
    Value<bool>? deleted,
  }) {
    return OperationsBackupCompanion(
      id: id ?? this.id,
      backupId: backupId ?? this.backupId,
      backupAtMillis: backupAtMillis ?? this.backupAtMillis,
      uuid: uuid ?? this.uuid,
      data: data ?? this.data,
      startAtMillisMin: startAtMillisMin ?? this.startAtMillisMin,
      startAtMillisMax: startAtMillisMax ?? this.startAtMillisMax,
      qsoCount: qsoCount ?? this.qsoCount,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (backupId.present) {
      map['backup_id'] = Variable<String>(backupId.value);
    }
    if (backupAtMillis.present) {
      map['backup_at_millis'] = Variable<int>(backupAtMillis.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (startAtMillisMin.present) {
      map['start_at_millis_min'] = Variable<int>(startAtMillisMin.value);
    }
    if (startAtMillisMax.present) {
      map['start_at_millis_max'] = Variable<int>(startAtMillisMax.value);
    }
    if (qsoCount.present) {
      map['qso_count'] = Variable<int>(qsoCount.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationsBackupCompanion(')
          ..write('id: $id, ')
          ..write('backupId: $backupId, ')
          ..write('backupAtMillis: $backupAtMillis, ')
          ..write('uuid: $uuid, ')
          ..write('data: $data, ')
          ..write('startAtMillisMin: $startAtMillisMin, ')
          ..write('startAtMillisMax: $startAtMillisMax, ')
          ..write('qsoCount: $qsoCount, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }
}

class $QsosBackupTable extends QsosBackup
    with TableInfo<$QsosBackupTable, QsoBackupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QsosBackupTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _backupIdMeta = const VerificationMeta(
    'backupId',
  );
  @override
  late final GeneratedColumn<String> backupId = GeneratedColumn<String>(
    'backup_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backupAtMillisMeta = const VerificationMeta(
    'backupAtMillis',
  );
  @override
  late final GeneratedColumn<int> backupAtMillis = GeneratedColumn<int>(
    'backup_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    backupId,
    backupAtMillis,
    uuid,
    operation,
    data,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qsos_backup';
  @override
  VerificationContext validateIntegrity(
    Insertable<QsoBackupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('backup_id')) {
      context.handle(
        _backupIdMeta,
        backupId.isAcceptableOrUnknown(data['backup_id']!, _backupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_backupIdMeta);
    }
    if (data.containsKey('backup_at_millis')) {
      context.handle(
        _backupAtMillisMeta,
        backupAtMillis.isAcceptableOrUnknown(
          data['backup_at_millis']!,
          _backupAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backupAtMillisMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QsoBackupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QsoBackupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      backupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_id'],
      )!,
      backupAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backup_at_millis'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $QsosBackupTable createAlias(String alias) {
    return $QsosBackupTable(attachedDatabase, alias);
  }
}

class QsoBackupRow extends DataClass implements Insertable<QsoBackupRow> {
  final int id;
  final String backupId;
  final int backupAtMillis;
  final String uuid;
  final String operation;
  final String data;
  final bool deleted;
  const QsoBackupRow({
    required this.id,
    required this.backupId,
    required this.backupAtMillis,
    required this.uuid,
    required this.operation,
    required this.data,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['backup_id'] = Variable<String>(backupId);
    map['backup_at_millis'] = Variable<int>(backupAtMillis);
    map['uuid'] = Variable<String>(uuid);
    map['operation'] = Variable<String>(operation);
    map['data'] = Variable<String>(data);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  QsosBackupCompanion toCompanion(bool nullToAbsent) {
    return QsosBackupCompanion(
      id: Value(id),
      backupId: Value(backupId),
      backupAtMillis: Value(backupAtMillis),
      uuid: Value(uuid),
      operation: Value(operation),
      data: Value(data),
      deleted: Value(deleted),
    );
  }

  factory QsoBackupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QsoBackupRow(
      id: serializer.fromJson<int>(json['id']),
      backupId: serializer.fromJson<String>(json['backupId']),
      backupAtMillis: serializer.fromJson<int>(json['backupAtMillis']),
      uuid: serializer.fromJson<String>(json['uuid']),
      operation: serializer.fromJson<String>(json['operation']),
      data: serializer.fromJson<String>(json['data']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'backupId': serializer.toJson<String>(backupId),
      'backupAtMillis': serializer.toJson<int>(backupAtMillis),
      'uuid': serializer.toJson<String>(uuid),
      'operation': serializer.toJson<String>(operation),
      'data': serializer.toJson<String>(data),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  QsoBackupRow copyWith({
    int? id,
    String? backupId,
    int? backupAtMillis,
    String? uuid,
    String? operation,
    String? data,
    bool? deleted,
  }) => QsoBackupRow(
    id: id ?? this.id,
    backupId: backupId ?? this.backupId,
    backupAtMillis: backupAtMillis ?? this.backupAtMillis,
    uuid: uuid ?? this.uuid,
    operation: operation ?? this.operation,
    data: data ?? this.data,
    deleted: deleted ?? this.deleted,
  );
  QsoBackupRow copyWithCompanion(QsosBackupCompanion data) {
    return QsoBackupRow(
      id: data.id.present ? data.id.value : this.id,
      backupId: data.backupId.present ? data.backupId.value : this.backupId,
      backupAtMillis: data.backupAtMillis.present
          ? data.backupAtMillis.value
          : this.backupAtMillis,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      operation: data.operation.present ? data.operation.value : this.operation,
      data: data.data.present ? data.data.value : this.data,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QsoBackupRow(')
          ..write('id: $id, ')
          ..write('backupId: $backupId, ')
          ..write('backupAtMillis: $backupAtMillis, ')
          ..write('uuid: $uuid, ')
          ..write('operation: $operation, ')
          ..write('data: $data, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, backupId, backupAtMillis, uuid, operation, data, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QsoBackupRow &&
          other.id == this.id &&
          other.backupId == this.backupId &&
          other.backupAtMillis == this.backupAtMillis &&
          other.uuid == this.uuid &&
          other.operation == this.operation &&
          other.data == this.data &&
          other.deleted == this.deleted);
}

class QsosBackupCompanion extends UpdateCompanion<QsoBackupRow> {
  final Value<int> id;
  final Value<String> backupId;
  final Value<int> backupAtMillis;
  final Value<String> uuid;
  final Value<String> operation;
  final Value<String> data;
  final Value<bool> deleted;
  const QsosBackupCompanion({
    this.id = const Value.absent(),
    this.backupId = const Value.absent(),
    this.backupAtMillis = const Value.absent(),
    this.uuid = const Value.absent(),
    this.operation = const Value.absent(),
    this.data = const Value.absent(),
    this.deleted = const Value.absent(),
  });
  QsosBackupCompanion.insert({
    this.id = const Value.absent(),
    required String backupId,
    required int backupAtMillis,
    required String uuid,
    required String operation,
    required String data,
    this.deleted = const Value.absent(),
  }) : backupId = Value(backupId),
       backupAtMillis = Value(backupAtMillis),
       uuid = Value(uuid),
       operation = Value(operation),
       data = Value(data);
  static Insertable<QsoBackupRow> custom({
    Expression<int>? id,
    Expression<String>? backupId,
    Expression<int>? backupAtMillis,
    Expression<String>? uuid,
    Expression<String>? operation,
    Expression<String>? data,
    Expression<bool>? deleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (backupId != null) 'backup_id': backupId,
      if (backupAtMillis != null) 'backup_at_millis': backupAtMillis,
      if (uuid != null) 'uuid': uuid,
      if (operation != null) 'operation': operation,
      if (data != null) 'data': data,
      if (deleted != null) 'deleted': deleted,
    });
  }

  QsosBackupCompanion copyWith({
    Value<int>? id,
    Value<String>? backupId,
    Value<int>? backupAtMillis,
    Value<String>? uuid,
    Value<String>? operation,
    Value<String>? data,
    Value<bool>? deleted,
  }) {
    return QsosBackupCompanion(
      id: id ?? this.id,
      backupId: backupId ?? this.backupId,
      backupAtMillis: backupAtMillis ?? this.backupAtMillis,
      uuid: uuid ?? this.uuid,
      operation: operation ?? this.operation,
      data: data ?? this.data,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (backupId.present) {
      map['backup_id'] = Variable<String>(backupId.value);
    }
    if (backupAtMillis.present) {
      map['backup_at_millis'] = Variable<int>(backupAtMillis.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QsosBackupCompanion(')
          ..write('id: $id, ')
          ..write('backupId: $backupId, ')
          ..write('backupAtMillis: $backupAtMillis, ')
          ..write('uuid: $uuid, ')
          ..write('operation: $operation, ')
          ..write('data: $data, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }
}

class $LookupsTable extends Lookups with TableInfo<$LookupsTable, LookupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LookupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subCategoryMeta = const VerificationMeta(
    'subCategory',
  );
  @override
  late final GeneratedColumn<String> subCategory = GeneratedColumn<String>(
    'sub_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flagsMeta = const VerificationMeta('flags');
  @override
  late final GeneratedColumn<int> flags = GeneratedColumn<int>(
    'flags',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedMeta = const VerificationMeta(
    'updated',
  );
  @override
  late final GeneratedColumn<int> updated = GeneratedColumn<int>(
    'updated',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    category,
    subCategory,
    key,
    name,
    data,
    lat,
    lon,
    flags,
    updated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lookups';
  @override
  VerificationContext validateIntegrity(
    Insertable<LookupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('sub_category')) {
      context.handle(
        _subCategoryMeta,
        subCategory.isAcceptableOrUnknown(
          data['sub_category']!,
          _subCategoryMeta,
        ),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('flags')) {
      context.handle(
        _flagsMeta,
        flags.isAcceptableOrUnknown(data['flags']!, _flagsMeta),
      );
    }
    if (data.containsKey('updated')) {
      context.handle(
        _updatedMeta,
        updated.isAcceptableOrUnknown(data['updated']!, _updatedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {category, key};
  @override
  LookupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LookupRow(
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      subCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_category'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      flags: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flags'],
      ),
      updated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated'],
      ),
    );
  }

  @override
  $LookupsTable createAlias(String alias) {
    return $LookupsTable(attachedDatabase, alias);
  }
}

class LookupRow extends DataClass implements Insertable<LookupRow> {
  final String category;
  final String? subCategory;
  final String key;
  final String? name;
  final String? data;
  final double? lat;
  final double? lon;
  final int? flags;
  final int? updated;
  const LookupRow({
    required this.category,
    this.subCategory,
    required this.key,
    this.name,
    this.data,
    this.lat,
    this.lon,
    this.flags,
    this.updated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || subCategory != null) {
      map['sub_category'] = Variable<String>(subCategory);
    }
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || flags != null) {
      map['flags'] = Variable<int>(flags);
    }
    if (!nullToAbsent || updated != null) {
      map['updated'] = Variable<int>(updated);
    }
    return map;
  }

  LookupsCompanion toCompanion(bool nullToAbsent) {
    return LookupsCompanion(
      category: Value(category),
      subCategory: subCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(subCategory),
      key: Value(key),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      flags: flags == null && nullToAbsent
          ? const Value.absent()
          : Value(flags),
      updated: updated == null && nullToAbsent
          ? const Value.absent()
          : Value(updated),
    );
  }

  factory LookupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LookupRow(
      category: serializer.fromJson<String>(json['category']),
      subCategory: serializer.fromJson<String?>(json['subCategory']),
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String?>(json['name']),
      data: serializer.fromJson<String?>(json['data']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      flags: serializer.fromJson<int?>(json['flags']),
      updated: serializer.fromJson<int?>(json['updated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'category': serializer.toJson<String>(category),
      'subCategory': serializer.toJson<String?>(subCategory),
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String?>(name),
      'data': serializer.toJson<String?>(data),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'flags': serializer.toJson<int?>(flags),
      'updated': serializer.toJson<int?>(updated),
    };
  }

  LookupRow copyWith({
    String? category,
    Value<String?> subCategory = const Value.absent(),
    String? key,
    Value<String?> name = const Value.absent(),
    Value<String?> data = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<int?> flags = const Value.absent(),
    Value<int?> updated = const Value.absent(),
  }) => LookupRow(
    category: category ?? this.category,
    subCategory: subCategory.present ? subCategory.value : this.subCategory,
    key: key ?? this.key,
    name: name.present ? name.value : this.name,
    data: data.present ? data.value : this.data,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    flags: flags.present ? flags.value : this.flags,
    updated: updated.present ? updated.value : this.updated,
  );
  LookupRow copyWithCompanion(LookupsCompanion data) {
    return LookupRow(
      category: data.category.present ? data.category.value : this.category,
      subCategory: data.subCategory.present
          ? data.subCategory.value
          : this.subCategory,
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      data: data.data.present ? data.data.value : this.data,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      flags: data.flags.present ? data.flags.value : this.flags,
      updated: data.updated.present ? data.updated.value : this.updated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LookupRow(')
          ..write('category: $category, ')
          ..write('subCategory: $subCategory, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('data: $data, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('flags: $flags, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    category,
    subCategory,
    key,
    name,
    data,
    lat,
    lon,
    flags,
    updated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookupRow &&
          other.category == this.category &&
          other.subCategory == this.subCategory &&
          other.key == this.key &&
          other.name == this.name &&
          other.data == this.data &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.flags == this.flags &&
          other.updated == this.updated);
}

class LookupsCompanion extends UpdateCompanion<LookupRow> {
  final Value<String> category;
  final Value<String?> subCategory;
  final Value<String> key;
  final Value<String?> name;
  final Value<String?> data;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<int?> flags;
  final Value<int?> updated;
  final Value<int> rowid;
  const LookupsCompanion({
    this.category = const Value.absent(),
    this.subCategory = const Value.absent(),
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.data = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.flags = const Value.absent(),
    this.updated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LookupsCompanion.insert({
    required String category,
    this.subCategory = const Value.absent(),
    required String key,
    this.name = const Value.absent(),
    this.data = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.flags = const Value.absent(),
    this.updated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : category = Value(category),
       key = Value(key);
  static Insertable<LookupRow> custom({
    Expression<String>? category,
    Expression<String>? subCategory,
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? data,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<int>? flags,
    Expression<int>? updated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (category != null) 'category': category,
      if (subCategory != null) 'sub_category': subCategory,
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (data != null) 'data': data,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (flags != null) 'flags': flags,
      if (updated != null) 'updated': updated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LookupsCompanion copyWith({
    Value<String>? category,
    Value<String?>? subCategory,
    Value<String>? key,
    Value<String?>? name,
    Value<String?>? data,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<int?>? flags,
    Value<int?>? updated,
    Value<int>? rowid,
  }) {
    return LookupsCompanion(
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      key: key ?? this.key,
      name: name ?? this.name,
      data: data ?? this.data,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      flags: flags ?? this.flags,
      updated: updated ?? this.updated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (subCategory.present) {
      map['sub_category'] = Variable<String>(subCategory.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (flags.present) {
      map['flags'] = Variable<int>(flags.value);
    }
    if (updated.present) {
      map['updated'] = Variable<int>(updated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LookupsCompanion(')
          ..write('category: $category, ')
          ..write('subCategory: $subCategory, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('data: $data, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('flags: $flags, ')
          ..write('updated: $updated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SequencesTable extends Sequences
    with TableInfo<$SequencesTable, SequenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextValueMeta = const VerificationMeta(
    'nextValue',
  );
  @override
  late final GeneratedColumn<int> nextValue = GeneratedColumn<int>(
    'next_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startValueMeta = const VerificationMeta(
    'startValue',
  );
  @override
  late final GeneratedColumn<int> startValue = GeneratedColumn<int>(
    'start_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMillisMeta = const VerificationMeta(
    'updatedAtMillis',
  );
  @override
  late final GeneratedColumn<int> updatedAtMillis = GeneratedColumn<int>(
    'updated_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operation,
    label,
    nextValue,
    startValue,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sequences';
  @override
  VerificationContext validateIntegrity(
    Insertable<SequenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('next_value')) {
      context.handle(
        _nextValueMeta,
        nextValue.isAcceptableOrUnknown(data['next_value']!, _nextValueMeta),
      );
    } else if (isInserting) {
      context.missing(_nextValueMeta);
    }
    if (data.containsKey('start_value')) {
      context.handle(
        _startValueMeta,
        startValue.isAcceptableOrUnknown(data['start_value']!, _startValueMeta),
      );
    }
    if (data.containsKey('updated_at_millis')) {
      context.handle(
        _updatedAtMillisMeta,
        updatedAtMillis.isAcceptableOrUnknown(
          data['updated_at_millis']!,
          _updatedAtMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operation, label};
  @override
  SequenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SequenceRow(
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      nextValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_value'],
      )!,
      startValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_value'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      ),
    );
  }

  @override
  $SequencesTable createAlias(String alias) {
    return $SequencesTable(attachedDatabase, alias);
  }
}

class SequenceRow extends DataClass implements Insertable<SequenceRow> {
  final String operation;

  /// `<extensionKey>/<key>` plus any scope values, e.g. `cqwpx/serial` or
  /// `rsgb/serial/2m`. Computed by the core at allocation time from the
  /// committed QSO, never by the extension — only the core knows which band
  /// the QSO actually ended up on.
  final String label;

  /// The next number to issue.
  final int nextValue;

  /// First number this sequence issues; the operator can set it when they
  /// logged the first hour on paper.
  final int startValue;
  final int? updatedAtMillis;
  const SequenceRow({
    required this.operation,
    required this.label,
    required this.nextValue,
    required this.startValue,
    this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation'] = Variable<String>(operation);
    map['label'] = Variable<String>(label);
    map['next_value'] = Variable<int>(nextValue);
    map['start_value'] = Variable<int>(startValue);
    if (!nullToAbsent || updatedAtMillis != null) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    }
    return map;
  }

  SequencesCompanion toCompanion(bool nullToAbsent) {
    return SequencesCompanion(
      operation: Value(operation),
      label: Value(label),
      nextValue: Value(nextValue),
      startValue: Value(startValue),
      updatedAtMillis: updatedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtMillis),
    );
  }

  factory SequenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SequenceRow(
      operation: serializer.fromJson<String>(json['operation']),
      label: serializer.fromJson<String>(json['label']),
      nextValue: serializer.fromJson<int>(json['nextValue']),
      startValue: serializer.fromJson<int>(json['startValue']),
      updatedAtMillis: serializer.fromJson<int?>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operation': serializer.toJson<String>(operation),
      'label': serializer.toJson<String>(label),
      'nextValue': serializer.toJson<int>(nextValue),
      'startValue': serializer.toJson<int>(startValue),
      'updatedAtMillis': serializer.toJson<int?>(updatedAtMillis),
    };
  }

  SequenceRow copyWith({
    String? operation,
    String? label,
    int? nextValue,
    int? startValue,
    Value<int?> updatedAtMillis = const Value.absent(),
  }) => SequenceRow(
    operation: operation ?? this.operation,
    label: label ?? this.label,
    nextValue: nextValue ?? this.nextValue,
    startValue: startValue ?? this.startValue,
    updatedAtMillis: updatedAtMillis.present
        ? updatedAtMillis.value
        : this.updatedAtMillis,
  );
  SequenceRow copyWithCompanion(SequencesCompanion data) {
    return SequenceRow(
      operation: data.operation.present ? data.operation.value : this.operation,
      label: data.label.present ? data.label.value : this.label,
      nextValue: data.nextValue.present ? data.nextValue.value : this.nextValue,
      startValue: data.startValue.present
          ? data.startValue.value
          : this.startValue,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SequenceRow(')
          ..write('operation: $operation, ')
          ..write('label: $label, ')
          ..write('nextValue: $nextValue, ')
          ..write('startValue: $startValue, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(operation, label, nextValue, startValue, updatedAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SequenceRow &&
          other.operation == this.operation &&
          other.label == this.label &&
          other.nextValue == this.nextValue &&
          other.startValue == this.startValue &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class SequencesCompanion extends UpdateCompanion<SequenceRow> {
  final Value<String> operation;
  final Value<String> label;
  final Value<int> nextValue;
  final Value<int> startValue;
  final Value<int?> updatedAtMillis;
  final Value<int> rowid;
  const SequencesCompanion({
    this.operation = const Value.absent(),
    this.label = const Value.absent(),
    this.nextValue = const Value.absent(),
    this.startValue = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SequencesCompanion.insert({
    required String operation,
    required String label,
    required int nextValue,
    this.startValue = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operation = Value(operation),
       label = Value(label),
       nextValue = Value(nextValue);
  static Insertable<SequenceRow> custom({
    Expression<String>? operation,
    Expression<String>? label,
    Expression<int>? nextValue,
    Expression<int>? startValue,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operation != null) 'operation': operation,
      if (label != null) 'label': label,
      if (nextValue != null) 'next_value': nextValue,
      if (startValue != null) 'start_value': startValue,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SequencesCompanion copyWith({
    Value<String>? operation,
    Value<String>? label,
    Value<int>? nextValue,
    Value<int>? startValue,
    Value<int?>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return SequencesCompanion(
      operation: operation ?? this.operation,
      label: label ?? this.label,
      nextValue: nextValue ?? this.nextValue,
      startValue: startValue ?? this.startValue,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (nextValue.present) {
      map['next_value'] = Variable<int>(nextValue.value);
    }
    if (startValue.present) {
      map['start_value'] = Variable<int>(startValue.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SequencesCompanion(')
          ..write('operation: $operation, ')
          ..write('label: $label, ')
          ..write('nextValue: $nextValue, ')
          ..write('startValue: $startValue, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HaLoDatabase extends GeneratedDatabase {
  _$HaLoDatabase(QueryExecutor e) : super(e);
  $HaLoDatabaseManager get managers => $HaLoDatabaseManager(this);
  late final $OperationsTable operations = $OperationsTable(this);
  late final $QsosTable qsos = $QsosTable(this);
  late final $OperationsBackupTable operationsBackup = $OperationsBackupTable(
    this,
  );
  late final $QsosBackupTable qsosBackup = $QsosBackupTable(this);
  late final $LookupsTable lookups = $LookupsTable(this);
  late final $SequencesTable sequences = $SequencesTable(this);
  late final Index qsosOperationStart = Index(
    'qsos_operation_start',
    'CREATE INDEX qsos_operation_start ON qsos (operation, start_at_millis)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    operations,
    qsos,
    operationsBackup,
    qsosBackup,
    lookups,
    sequences,
    qsosOperationStart,
  ];
}

typedef $$OperationsTableCreateCompanionBuilder =
    OperationsCompanion Function({
      required String uuid,
      Value<String> data,
      Value<String?> localData,
      Value<int?> startAtMillisMin,
      Value<int?> startAtMillisMax,
      Value<int> qsoCount,
      Value<bool> deleted,
      Value<bool> synced,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });
typedef $$OperationsTableUpdateCompanionBuilder =
    OperationsCompanion Function({
      Value<String> uuid,
      Value<String> data,
      Value<String?> localData,
      Value<int?> startAtMillisMin,
      Value<int?> startAtMillisMax,
      Value<int> qsoCount,
      Value<bool> deleted,
      Value<bool> synced,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });

class $$OperationsTableFilterComposer
    extends Composer<_$HaLoDatabase, $OperationsTable> {
  $$OperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localData => $composableBuilder(
    column: $table.localData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtMillisMin => $composableBuilder(
    column: $table.startAtMillisMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtMillisMax => $composableBuilder(
    column: $table.startAtMillisMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qsoCount => $composableBuilder(
    column: $table.qsoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OperationsTableOrderingComposer
    extends Composer<_$HaLoDatabase, $OperationsTable> {
  $$OperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localData => $composableBuilder(
    column: $table.localData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtMillisMin => $composableBuilder(
    column: $table.startAtMillisMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtMillisMax => $composableBuilder(
    column: $table.startAtMillisMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qsoCount => $composableBuilder(
    column: $table.qsoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationsTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $OperationsTable> {
  $$OperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get localData =>
      $composableBuilder(column: $table.localData, builder: (column) => column);

  GeneratedColumn<int> get startAtMillisMin => $composableBuilder(
    column: $table.startAtMillisMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startAtMillisMax => $composableBuilder(
    column: $table.startAtMillisMax,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qsoCount =>
      $composableBuilder(column: $table.qsoCount, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$OperationsTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $OperationsTable,
          OperationRow,
          $$OperationsTableFilterComposer,
          $$OperationsTableOrderingComposer,
          $$OperationsTableAnnotationComposer,
          $$OperationsTableCreateCompanionBuilder,
          $$OperationsTableUpdateCompanionBuilder,
          (
            OperationRow,
            BaseReferences<_$HaLoDatabase, $OperationsTable, OperationRow>,
          ),
          OperationRow,
          PrefetchHooks Function()
        > {
  $$OperationsTableTableManager(_$HaLoDatabase db, $OperationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> localData = const Value.absent(),
                Value<int?> startAtMillisMin = const Value.absent(),
                Value<int?> startAtMillisMax = const Value.absent(),
                Value<int> qsoCount = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion(
                uuid: uuid,
                data: data,
                localData: localData,
                startAtMillisMin: startAtMillisMin,
                startAtMillisMax: startAtMillisMax,
                qsoCount: qsoCount,
                deleted: deleted,
                synced: synced,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<String> data = const Value.absent(),
                Value<String?> localData = const Value.absent(),
                Value<int?> startAtMillisMin = const Value.absent(),
                Value<int?> startAtMillisMax = const Value.absent(),
                Value<int> qsoCount = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion.insert(
                uuid: uuid,
                data: data,
                localData: localData,
                startAtMillisMin: startAtMillisMin,
                startAtMillisMax: startAtMillisMax,
                qsoCount: qsoCount,
                deleted: deleted,
                synced: synced,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $OperationsTable,
      OperationRow,
      $$OperationsTableFilterComposer,
      $$OperationsTableOrderingComposer,
      $$OperationsTableAnnotationComposer,
      $$OperationsTableCreateCompanionBuilder,
      $$OperationsTableUpdateCompanionBuilder,
      (
        OperationRow,
        BaseReferences<_$HaLoDatabase, $OperationsTable, OperationRow>,
      ),
      OperationRow,
      PrefetchHooks Function()
    >;
typedef $$QsosTableCreateCompanionBuilder =
    QsosCompanion Function({
      required String uuid,
      required String operation,
      Value<String?> ourCall,
      Value<String?> theirCall,
      Value<String?> band,
      Value<String?> mode,
      Value<int?> startAtMillis,
      Value<String> data,
      Value<bool> deleted,
      Value<bool> synced,
      Value<String?> scoreCache,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });
typedef $$QsosTableUpdateCompanionBuilder =
    QsosCompanion Function({
      Value<String> uuid,
      Value<String> operation,
      Value<String?> ourCall,
      Value<String?> theirCall,
      Value<String?> band,
      Value<String?> mode,
      Value<int?> startAtMillis,
      Value<String> data,
      Value<bool> deleted,
      Value<bool> synced,
      Value<String?> scoreCache,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });

class $$QsosTableFilterComposer extends Composer<_$HaLoDatabase, $QsosTable> {
  $$QsosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ourCall => $composableBuilder(
    column: $table.ourCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theirCall => $composableBuilder(
    column: $table.theirCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get band => $composableBuilder(
    column: $table.band,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtMillis => $composableBuilder(
    column: $table.startAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoreCache => $composableBuilder(
    column: $table.scoreCache,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QsosTableOrderingComposer extends Composer<_$HaLoDatabase, $QsosTable> {
  $$QsosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ourCall => $composableBuilder(
    column: $table.ourCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theirCall => $composableBuilder(
    column: $table.theirCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get band => $composableBuilder(
    column: $table.band,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtMillis => $composableBuilder(
    column: $table.startAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoreCache => $composableBuilder(
    column: $table.scoreCache,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QsosTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $QsosTable> {
  $$QsosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get ourCall =>
      $composableBuilder(column: $table.ourCall, builder: (column) => column);

  GeneratedColumn<String> get theirCall =>
      $composableBuilder(column: $table.theirCall, builder: (column) => column);

  GeneratedColumn<String> get band =>
      $composableBuilder(column: $table.band, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get startAtMillis => $composableBuilder(
    column: $table.startAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get scoreCache => $composableBuilder(
    column: $table.scoreCache,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$QsosTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $QsosTable,
          QsoRow,
          $$QsosTableFilterComposer,
          $$QsosTableOrderingComposer,
          $$QsosTableAnnotationComposer,
          $$QsosTableCreateCompanionBuilder,
          $$QsosTableUpdateCompanionBuilder,
          (QsoRow, BaseReferences<_$HaLoDatabase, $QsosTable, QsoRow>),
          QsoRow,
          PrefetchHooks Function()
        > {
  $$QsosTableTableManager(_$HaLoDatabase db, $QsosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QsosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QsosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QsosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> ourCall = const Value.absent(),
                Value<String?> theirCall = const Value.absent(),
                Value<String?> band = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<int?> startAtMillis = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> scoreCache = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QsosCompanion(
                uuid: uuid,
                operation: operation,
                ourCall: ourCall,
                theirCall: theirCall,
                band: band,
                mode: mode,
                startAtMillis: startAtMillis,
                data: data,
                deleted: deleted,
                synced: synced,
                scoreCache: scoreCache,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String operation,
                Value<String?> ourCall = const Value.absent(),
                Value<String?> theirCall = const Value.absent(),
                Value<String?> band = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<int?> startAtMillis = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> scoreCache = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QsosCompanion.insert(
                uuid: uuid,
                operation: operation,
                ourCall: ourCall,
                theirCall: theirCall,
                band: band,
                mode: mode,
                startAtMillis: startAtMillis,
                data: data,
                deleted: deleted,
                synced: synced,
                scoreCache: scoreCache,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QsosTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $QsosTable,
      QsoRow,
      $$QsosTableFilterComposer,
      $$QsosTableOrderingComposer,
      $$QsosTableAnnotationComposer,
      $$QsosTableCreateCompanionBuilder,
      $$QsosTableUpdateCompanionBuilder,
      (QsoRow, BaseReferences<_$HaLoDatabase, $QsosTable, QsoRow>),
      QsoRow,
      PrefetchHooks Function()
    >;
typedef $$OperationsBackupTableCreateCompanionBuilder =
    OperationsBackupCompanion Function({
      Value<int> id,
      required String backupId,
      required int backupAtMillis,
      required String uuid,
      required String data,
      Value<int?> startAtMillisMin,
      Value<int?> startAtMillisMax,
      Value<int> qsoCount,
      Value<bool> deleted,
    });
typedef $$OperationsBackupTableUpdateCompanionBuilder =
    OperationsBackupCompanion Function({
      Value<int> id,
      Value<String> backupId,
      Value<int> backupAtMillis,
      Value<String> uuid,
      Value<String> data,
      Value<int?> startAtMillisMin,
      Value<int?> startAtMillisMax,
      Value<int> qsoCount,
      Value<bool> deleted,
    });

class $$OperationsBackupTableFilterComposer
    extends Composer<_$HaLoDatabase, $OperationsBackupTable> {
  $$OperationsBackupTableFilterComposer({
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

  ColumnFilters<String> get backupId => $composableBuilder(
    column: $table.backupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backupAtMillis => $composableBuilder(
    column: $table.backupAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtMillisMin => $composableBuilder(
    column: $table.startAtMillisMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtMillisMax => $composableBuilder(
    column: $table.startAtMillisMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qsoCount => $composableBuilder(
    column: $table.qsoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OperationsBackupTableOrderingComposer
    extends Composer<_$HaLoDatabase, $OperationsBackupTable> {
  $$OperationsBackupTableOrderingComposer({
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

  ColumnOrderings<String> get backupId => $composableBuilder(
    column: $table.backupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backupAtMillis => $composableBuilder(
    column: $table.backupAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtMillisMin => $composableBuilder(
    column: $table.startAtMillisMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtMillisMax => $composableBuilder(
    column: $table.startAtMillisMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qsoCount => $composableBuilder(
    column: $table.qsoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationsBackupTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $OperationsBackupTable> {
  $$OperationsBackupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get backupId =>
      $composableBuilder(column: $table.backupId, builder: (column) => column);

  GeneratedColumn<int> get backupAtMillis => $composableBuilder(
    column: $table.backupAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get startAtMillisMin => $composableBuilder(
    column: $table.startAtMillisMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startAtMillisMax => $composableBuilder(
    column: $table.startAtMillisMax,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qsoCount =>
      $composableBuilder(column: $table.qsoCount, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$OperationsBackupTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $OperationsBackupTable,
          OperationBackupRow,
          $$OperationsBackupTableFilterComposer,
          $$OperationsBackupTableOrderingComposer,
          $$OperationsBackupTableAnnotationComposer,
          $$OperationsBackupTableCreateCompanionBuilder,
          $$OperationsBackupTableUpdateCompanionBuilder,
          (
            OperationBackupRow,
            BaseReferences<
              _$HaLoDatabase,
              $OperationsBackupTable,
              OperationBackupRow
            >,
          ),
          OperationBackupRow,
          PrefetchHooks Function()
        > {
  $$OperationsBackupTableTableManager(
    _$HaLoDatabase db,
    $OperationsBackupTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationsBackupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationsBackupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationsBackupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> backupId = const Value.absent(),
                Value<int> backupAtMillis = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int?> startAtMillisMin = const Value.absent(),
                Value<int?> startAtMillisMax = const Value.absent(),
                Value<int> qsoCount = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => OperationsBackupCompanion(
                id: id,
                backupId: backupId,
                backupAtMillis: backupAtMillis,
                uuid: uuid,
                data: data,
                startAtMillisMin: startAtMillisMin,
                startAtMillisMax: startAtMillisMax,
                qsoCount: qsoCount,
                deleted: deleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String backupId,
                required int backupAtMillis,
                required String uuid,
                required String data,
                Value<int?> startAtMillisMin = const Value.absent(),
                Value<int?> startAtMillisMax = const Value.absent(),
                Value<int> qsoCount = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => OperationsBackupCompanion.insert(
                id: id,
                backupId: backupId,
                backupAtMillis: backupAtMillis,
                uuid: uuid,
                data: data,
                startAtMillisMin: startAtMillisMin,
                startAtMillisMax: startAtMillisMax,
                qsoCount: qsoCount,
                deleted: deleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OperationsBackupTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $OperationsBackupTable,
      OperationBackupRow,
      $$OperationsBackupTableFilterComposer,
      $$OperationsBackupTableOrderingComposer,
      $$OperationsBackupTableAnnotationComposer,
      $$OperationsBackupTableCreateCompanionBuilder,
      $$OperationsBackupTableUpdateCompanionBuilder,
      (
        OperationBackupRow,
        BaseReferences<
          _$HaLoDatabase,
          $OperationsBackupTable,
          OperationBackupRow
        >,
      ),
      OperationBackupRow,
      PrefetchHooks Function()
    >;
typedef $$QsosBackupTableCreateCompanionBuilder =
    QsosBackupCompanion Function({
      Value<int> id,
      required String backupId,
      required int backupAtMillis,
      required String uuid,
      required String operation,
      required String data,
      Value<bool> deleted,
    });
typedef $$QsosBackupTableUpdateCompanionBuilder =
    QsosBackupCompanion Function({
      Value<int> id,
      Value<String> backupId,
      Value<int> backupAtMillis,
      Value<String> uuid,
      Value<String> operation,
      Value<String> data,
      Value<bool> deleted,
    });

class $$QsosBackupTableFilterComposer
    extends Composer<_$HaLoDatabase, $QsosBackupTable> {
  $$QsosBackupTableFilterComposer({
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

  ColumnFilters<String> get backupId => $composableBuilder(
    column: $table.backupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backupAtMillis => $composableBuilder(
    column: $table.backupAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QsosBackupTableOrderingComposer
    extends Composer<_$HaLoDatabase, $QsosBackupTable> {
  $$QsosBackupTableOrderingComposer({
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

  ColumnOrderings<String> get backupId => $composableBuilder(
    column: $table.backupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backupAtMillis => $composableBuilder(
    column: $table.backupAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QsosBackupTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $QsosBackupTable> {
  $$QsosBackupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get backupId =>
      $composableBuilder(column: $table.backupId, builder: (column) => column);

  GeneratedColumn<int> get backupAtMillis => $composableBuilder(
    column: $table.backupAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$QsosBackupTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $QsosBackupTable,
          QsoBackupRow,
          $$QsosBackupTableFilterComposer,
          $$QsosBackupTableOrderingComposer,
          $$QsosBackupTableAnnotationComposer,
          $$QsosBackupTableCreateCompanionBuilder,
          $$QsosBackupTableUpdateCompanionBuilder,
          (
            QsoBackupRow,
            BaseReferences<_$HaLoDatabase, $QsosBackupTable, QsoBackupRow>,
          ),
          QsoBackupRow,
          PrefetchHooks Function()
        > {
  $$QsosBackupTableTableManager(_$HaLoDatabase db, $QsosBackupTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QsosBackupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QsosBackupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QsosBackupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> backupId = const Value.absent(),
                Value<int> backupAtMillis = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => QsosBackupCompanion(
                id: id,
                backupId: backupId,
                backupAtMillis: backupAtMillis,
                uuid: uuid,
                operation: operation,
                data: data,
                deleted: deleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String backupId,
                required int backupAtMillis,
                required String uuid,
                required String operation,
                required String data,
                Value<bool> deleted = const Value.absent(),
              }) => QsosBackupCompanion.insert(
                id: id,
                backupId: backupId,
                backupAtMillis: backupAtMillis,
                uuid: uuid,
                operation: operation,
                data: data,
                deleted: deleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QsosBackupTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $QsosBackupTable,
      QsoBackupRow,
      $$QsosBackupTableFilterComposer,
      $$QsosBackupTableOrderingComposer,
      $$QsosBackupTableAnnotationComposer,
      $$QsosBackupTableCreateCompanionBuilder,
      $$QsosBackupTableUpdateCompanionBuilder,
      (
        QsoBackupRow,
        BaseReferences<_$HaLoDatabase, $QsosBackupTable, QsoBackupRow>,
      ),
      QsoBackupRow,
      PrefetchHooks Function()
    >;
typedef $$LookupsTableCreateCompanionBuilder =
    LookupsCompanion Function({
      required String category,
      Value<String?> subCategory,
      required String key,
      Value<String?> name,
      Value<String?> data,
      Value<double?> lat,
      Value<double?> lon,
      Value<int?> flags,
      Value<int?> updated,
      Value<int> rowid,
    });
typedef $$LookupsTableUpdateCompanionBuilder =
    LookupsCompanion Function({
      Value<String> category,
      Value<String?> subCategory,
      Value<String> key,
      Value<String?> name,
      Value<String?> data,
      Value<double?> lat,
      Value<double?> lon,
      Value<int?> flags,
      Value<int?> updated,
      Value<int> rowid,
    });

class $$LookupsTableFilterComposer
    extends Composer<_$HaLoDatabase, $LookupsTable> {
  $$LookupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LookupsTableOrderingComposer
    extends Composer<_$HaLoDatabase, $LookupsTable> {
  $$LookupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LookupsTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $LookupsTable> {
  $$LookupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<int> get flags =>
      $composableBuilder(column: $table.flags, builder: (column) => column);

  GeneratedColumn<int> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);
}

class $$LookupsTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $LookupsTable,
          LookupRow,
          $$LookupsTableFilterComposer,
          $$LookupsTableOrderingComposer,
          $$LookupsTableAnnotationComposer,
          $$LookupsTableCreateCompanionBuilder,
          $$LookupsTableUpdateCompanionBuilder,
          (LookupRow, BaseReferences<_$HaLoDatabase, $LookupsTable, LookupRow>),
          LookupRow,
          PrefetchHooks Function()
        > {
  $$LookupsTableTableManager(_$HaLoDatabase db, $LookupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LookupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LookupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LookupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> category = const Value.absent(),
                Value<String?> subCategory = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int?> flags = const Value.absent(),
                Value<int?> updated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookupsCompanion(
                category: category,
                subCategory: subCategory,
                key: key,
                name: name,
                data: data,
                lat: lat,
                lon: lon,
                flags: flags,
                updated: updated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String category,
                Value<String?> subCategory = const Value.absent(),
                required String key,
                Value<String?> name = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int?> flags = const Value.absent(),
                Value<int?> updated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookupsCompanion.insert(
                category: category,
                subCategory: subCategory,
                key: key,
                name: name,
                data: data,
                lat: lat,
                lon: lon,
                flags: flags,
                updated: updated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LookupsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $LookupsTable,
      LookupRow,
      $$LookupsTableFilterComposer,
      $$LookupsTableOrderingComposer,
      $$LookupsTableAnnotationComposer,
      $$LookupsTableCreateCompanionBuilder,
      $$LookupsTableUpdateCompanionBuilder,
      (LookupRow, BaseReferences<_$HaLoDatabase, $LookupsTable, LookupRow>),
      LookupRow,
      PrefetchHooks Function()
    >;
typedef $$SequencesTableCreateCompanionBuilder =
    SequencesCompanion Function({
      required String operation,
      required String label,
      required int nextValue,
      Value<int> startValue,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });
typedef $$SequencesTableUpdateCompanionBuilder =
    SequencesCompanion Function({
      Value<String> operation,
      Value<String> label,
      Value<int> nextValue,
      Value<int> startValue,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });

class $$SequencesTableFilterComposer
    extends Composer<_$HaLoDatabase, $SequencesTable> {
  $$SequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextValue => $composableBuilder(
    column: $table.nextValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startValue => $composableBuilder(
    column: $table.startValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SequencesTableOrderingComposer
    extends Composer<_$HaLoDatabase, $SequencesTable> {
  $$SequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextValue => $composableBuilder(
    column: $table.nextValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startValue => $composableBuilder(
    column: $table.startValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SequencesTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $SequencesTable> {
  $$SequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get nextValue =>
      $composableBuilder(column: $table.nextValue, builder: (column) => column);

  GeneratedColumn<int> get startValue => $composableBuilder(
    column: $table.startValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$SequencesTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $SequencesTable,
          SequenceRow,
          $$SequencesTableFilterComposer,
          $$SequencesTableOrderingComposer,
          $$SequencesTableAnnotationComposer,
          $$SequencesTableCreateCompanionBuilder,
          $$SequencesTableUpdateCompanionBuilder,
          (
            SequenceRow,
            BaseReferences<_$HaLoDatabase, $SequencesTable, SequenceRow>,
          ),
          SequenceRow,
          PrefetchHooks Function()
        > {
  $$SequencesTableTableManager(_$HaLoDatabase db, $SequencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SequencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SequencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SequencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operation = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> nextValue = const Value.absent(),
                Value<int> startValue = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SequencesCompanion(
                operation: operation,
                label: label,
                nextValue: nextValue,
                startValue: startValue,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operation,
                required String label,
                required int nextValue,
                Value<int> startValue = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SequencesCompanion.insert(
                operation: operation,
                label: label,
                nextValue: nextValue,
                startValue: startValue,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SequencesTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $SequencesTable,
      SequenceRow,
      $$SequencesTableFilterComposer,
      $$SequencesTableOrderingComposer,
      $$SequencesTableAnnotationComposer,
      $$SequencesTableCreateCompanionBuilder,
      $$SequencesTableUpdateCompanionBuilder,
      (
        SequenceRow,
        BaseReferences<_$HaLoDatabase, $SequencesTable, SequenceRow>,
      ),
      SequenceRow,
      PrefetchHooks Function()
    >;

class $HaLoDatabaseManager {
  final _$HaLoDatabase _db;
  $HaLoDatabaseManager(this._db);
  $$OperationsTableTableManager get operations =>
      $$OperationsTableTableManager(_db, _db.operations);
  $$QsosTableTableManager get qsos => $$QsosTableTableManager(_db, _db.qsos);
  $$OperationsBackupTableTableManager get operationsBackup =>
      $$OperationsBackupTableTableManager(_db, _db.operationsBackup);
  $$QsosBackupTableTableManager get qsosBackup =>
      $$QsosBackupTableTableManager(_db, _db.qsosBackup);
  $$LookupsTableTableManager get lookups =>
      $$LookupsTableTableManager(_db, _db.lookups);
  $$SequencesTableTableManager get sequences =>
      $$SequencesTableTableManager(_db, _db.sequences);
}

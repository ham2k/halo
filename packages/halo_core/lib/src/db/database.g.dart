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
  static const VerificationMeta _purgedMeta = const VerificationMeta('purged');
  @override
  late final GeneratedColumn<bool> purged = GeneratedColumn<bool>(
    'purged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("purged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _purgedLocallyMeta = const VerificationMeta(
    'purgedLocally',
  );
  @override
  late final GeneratedColumn<bool> purgedLocally = GeneratedColumn<bool>(
    'purged_locally',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("purged_locally" IN (0, 1))',
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
    purged,
    purgedLocally,
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
    if (data.containsKey('purged')) {
      context.handle(
        _purgedMeta,
        purged.isAcceptableOrUnknown(data['purged']!, _purgedMeta),
      );
    }
    if (data.containsKey('purged_locally')) {
      context.handle(
        _purgedLocallyMeta,
        purgedLocally.isAcceptableOrUnknown(
          data['purged_locally']!,
          _purgedLocallyMeta,
        ),
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
      purged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}purged'],
      )!,
      purgedLocally: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}purged_locally'],
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

  /// Set alongside `deleted` when a Test Operation is deleted
  /// (`OperationsRepository.purge`, docs: Test Operations): the tombstone
  /// still pushes through the normal dirty-row sync, and once that push is
  /// acknowledged the row is physically removed. LoFi removes a purged
  /// record outright rather than keeping the tombstone, so no other device
  /// hears of it from there; peer sync still carries the flag. `purged`
  /// alone doesn't say WHO gets to act on it without asking — see
  /// [purgedLocally].
  final bool purged;

  /// True only when THIS device is the one that called
  /// `OperationsRepository.purge` — never set by `mergeFromSync`, which
  /// leaves it at its default `false` no matter what the incoming record's
  /// `purged` says. `hardDeletePurged`'s auto-sweep requires this: a
  /// locally-initiated purge already went through a confirmation dialog on
  /// this device, so it's safe to remove once synced, but a `purged` flag
  /// that only ever arrived via sync has not been confirmed HERE and must
  /// wait for the operator to say so (`OperationsRepository.
  /// confirmReceivedPurges`) — the whole point of `purged` travelling to
  /// another device at all (in practice from a peer; LoFi relays none) is
  /// so every device that receives it asks, not so it silently agrees.
  final bool purgedLocally;

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
    required this.purged,
    required this.purgedLocally,
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
    map['purged'] = Variable<bool>(purged);
    map['purged_locally'] = Variable<bool>(purgedLocally);
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
      purged: Value(purged),
      purgedLocally: Value(purgedLocally),
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
      purged: serializer.fromJson<bool>(json['purged']),
      purgedLocally: serializer.fromJson<bool>(json['purgedLocally']),
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
      'purged': serializer.toJson<bool>(purged),
      'purgedLocally': serializer.toJson<bool>(purgedLocally),
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
    bool? purged,
    bool? purgedLocally,
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
    purged: purged ?? this.purged,
    purgedLocally: purgedLocally ?? this.purgedLocally,
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
      purged: data.purged.present ? data.purged.value : this.purged,
      purgedLocally: data.purgedLocally.present
          ? data.purgedLocally.value
          : this.purgedLocally,
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
          ..write('purged: $purged, ')
          ..write('purgedLocally: $purgedLocally, ')
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
    purged,
    purgedLocally,
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
          other.purged == this.purged &&
          other.purgedLocally == this.purgedLocally &&
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
  final Value<bool> purged;
  final Value<bool> purgedLocally;
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
    this.purged = const Value.absent(),
    this.purgedLocally = const Value.absent(),
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
    this.purged = const Value.absent(),
    this.purgedLocally = const Value.absent(),
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
    Expression<bool>? purged,
    Expression<bool>? purgedLocally,
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
      if (purged != null) 'purged': purged,
      if (purgedLocally != null) 'purged_locally': purgedLocally,
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
    Value<bool>? purged,
    Value<bool>? purgedLocally,
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
      purged: purged ?? this.purged,
      purgedLocally: purgedLocally ?? this.purgedLocally,
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
    if (purged.present) {
      map['purged'] = Variable<bool>(purged.value);
    }
    if (purgedLocally.present) {
      map['purged_locally'] = Variable<bool>(purgedLocally.value);
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
          ..write('purged: $purged, ')
          ..write('purgedLocally: $purgedLocally, ')
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
  static const VerificationMeta _purgedMeta = const VerificationMeta('purged');
  @override
  late final GeneratedColumn<bool> purged = GeneratedColumn<bool>(
    'purged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("purged" IN (0, 1))',
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
    purged,
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
    if (data.containsKey('purged')) {
      context.handle(
        _purgedMeta,
        purged.isAcceptableOrUnknown(data['purged']!, _purgedMeta),
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
      purged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}purged'],
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

  /// See `Operations.purged` — set on every QSO of a Test Operation when the
  /// operation is purged.
  final bool purged;

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
    required this.purged,
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
    map['purged'] = Variable<bool>(purged);
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
      purged: Value(purged),
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
      purged: serializer.fromJson<bool>(json['purged']),
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
      'purged': serializer.toJson<bool>(purged),
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
    bool? purged,
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
    purged: purged ?? this.purged,
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
      purged: data.purged.present ? data.purged.value : this.purged,
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
          ..write('purged: $purged, ')
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
    purged,
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
          other.purged == this.purged &&
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
  final Value<bool> purged;
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
    this.purged = const Value.absent(),
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
    this.purged = const Value.absent(),
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
    Expression<bool>? purged,
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
      if (purged != null) 'purged': purged,
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
    Value<bool>? purged,
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
      purged: purged ?? this.purged,
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
    if (purged.present) {
      map['purged'] = Variable<bool>(purged.value);
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
          ..write('purged: $purged, ')
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

class $InboundCapturesTable extends InboundCaptures
    with TableInfo<$InboundCapturesTable, InboundCaptureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboundCapturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
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
  static const VerificationMeta _receivedAtMillisMeta = const VerificationMeta(
    'receivedAtMillis',
  );
  @override
  late final GeneratedColumn<int> receivedAtMillis = GeneratedColumn<int>(
    'received_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedToOperationMeta = const VerificationMeta(
    'addedToOperation',
  );
  @override
  late final GeneratedColumn<String> addedToOperation = GeneratedColumn<String>(
    'added_to_operation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    source,
    dedupeKey,
    data,
    receivedAtMillis,
    addedToOperation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbound_captures';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboundCaptureRow> instance, {
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
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('received_at_millis')) {
      context.handle(
        _receivedAtMillisMeta,
        receivedAtMillis.isAcceptableOrUnknown(
          data['received_at_millis']!,
          _receivedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMillisMeta);
    }
    if (data.containsKey('added_to_operation')) {
      context.handle(
        _addedToOperationMeta,
        addedToOperation.isAcceptableOrUnknown(
          data['added_to_operation']!,
          _addedToOperationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  InboundCaptureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboundCaptureRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      receivedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_at_millis'],
      )!,
      addedToOperation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_to_operation'],
      ),
    );
  }

  @override
  $InboundCapturesTable createAlias(String alias) {
    return $InboundCapturesTable(attachedDatabase, alias);
  }
}

class InboundCaptureRow extends DataClass
    implements Insertable<InboundCaptureRow> {
  final String uuid;

  /// The program that sent it, e.g. `n1mm`. Only one exists today, but the
  /// buffer's shape shouldn't have to change to add a second.
  final String source;

  /// A dedup key derived from the capture's own fields (call/band/mode/time),
  /// so a program that broadcasts the same contact twice doesn't queue it
  /// twice. Not the primary key: [uuid] is what the UI and
  /// `addedToOperation` reference, and re-deriving the dedup key on every
  /// query would be wasted work a plain unique index avoids.
  final String dedupeKey;

  /// QSON, same shape `Qso.data` uses — built directly from the capture so
  /// accepting it is a plain `qsos.add`, not a second translation.
  final String data;
  final int receivedAtMillis;

  /// Null while pending. Set to the operation's uuid once the operator adds
  /// it to a log — kept (not deleted) so a re-arriving duplicate broadcast is
  /// still recognized by [dedupeKey] as already handled.
  final String? addedToOperation;
  const InboundCaptureRow({
    required this.uuid,
    required this.source,
    required this.dedupeKey,
    required this.data,
    required this.receivedAtMillis,
    this.addedToOperation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['source'] = Variable<String>(source);
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['data'] = Variable<String>(data);
    map['received_at_millis'] = Variable<int>(receivedAtMillis);
    if (!nullToAbsent || addedToOperation != null) {
      map['added_to_operation'] = Variable<String>(addedToOperation);
    }
    return map;
  }

  InboundCapturesCompanion toCompanion(bool nullToAbsent) {
    return InboundCapturesCompanion(
      uuid: Value(uuid),
      source: Value(source),
      dedupeKey: Value(dedupeKey),
      data: Value(data),
      receivedAtMillis: Value(receivedAtMillis),
      addedToOperation: addedToOperation == null && nullToAbsent
          ? const Value.absent()
          : Value(addedToOperation),
    );
  }

  factory InboundCaptureRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboundCaptureRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      source: serializer.fromJson<String>(json['source']),
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      data: serializer.fromJson<String>(json['data']),
      receivedAtMillis: serializer.fromJson<int>(json['receivedAtMillis']),
      addedToOperation: serializer.fromJson<String?>(json['addedToOperation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'source': serializer.toJson<String>(source),
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'data': serializer.toJson<String>(data),
      'receivedAtMillis': serializer.toJson<int>(receivedAtMillis),
      'addedToOperation': serializer.toJson<String?>(addedToOperation),
    };
  }

  InboundCaptureRow copyWith({
    String? uuid,
    String? source,
    String? dedupeKey,
    String? data,
    int? receivedAtMillis,
    Value<String?> addedToOperation = const Value.absent(),
  }) => InboundCaptureRow(
    uuid: uuid ?? this.uuid,
    source: source ?? this.source,
    dedupeKey: dedupeKey ?? this.dedupeKey,
    data: data ?? this.data,
    receivedAtMillis: receivedAtMillis ?? this.receivedAtMillis,
    addedToOperation: addedToOperation.present
        ? addedToOperation.value
        : this.addedToOperation,
  );
  InboundCaptureRow copyWithCompanion(InboundCapturesCompanion data) {
    return InboundCaptureRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      source: data.source.present ? data.source.value : this.source,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      data: data.data.present ? data.data.value : this.data,
      receivedAtMillis: data.receivedAtMillis.present
          ? data.receivedAtMillis.value
          : this.receivedAtMillis,
      addedToOperation: data.addedToOperation.present
          ? data.addedToOperation.value
          : this.addedToOperation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboundCaptureRow(')
          ..write('uuid: $uuid, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('data: $data, ')
          ..write('receivedAtMillis: $receivedAtMillis, ')
          ..write('addedToOperation: $addedToOperation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    source,
    dedupeKey,
    data,
    receivedAtMillis,
    addedToOperation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboundCaptureRow &&
          other.uuid == this.uuid &&
          other.source == this.source &&
          other.dedupeKey == this.dedupeKey &&
          other.data == this.data &&
          other.receivedAtMillis == this.receivedAtMillis &&
          other.addedToOperation == this.addedToOperation);
}

class InboundCapturesCompanion extends UpdateCompanion<InboundCaptureRow> {
  final Value<String> uuid;
  final Value<String> source;
  final Value<String> dedupeKey;
  final Value<String> data;
  final Value<int> receivedAtMillis;
  final Value<String?> addedToOperation;
  final Value<int> rowid;
  const InboundCapturesCompanion({
    this.uuid = const Value.absent(),
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.data = const Value.absent(),
    this.receivedAtMillis = const Value.absent(),
    this.addedToOperation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboundCapturesCompanion.insert({
    required String uuid,
    required String source,
    required String dedupeKey,
    required String data,
    required int receivedAtMillis,
    this.addedToOperation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       source = Value(source),
       dedupeKey = Value(dedupeKey),
       data = Value(data),
       receivedAtMillis = Value(receivedAtMillis);
  static Insertable<InboundCaptureRow> custom({
    Expression<String>? uuid,
    Expression<String>? source,
    Expression<String>? dedupeKey,
    Expression<String>? data,
    Expression<int>? receivedAtMillis,
    Expression<String>? addedToOperation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (source != null) 'source': source,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (data != null) 'data': data,
      if (receivedAtMillis != null) 'received_at_millis': receivedAtMillis,
      if (addedToOperation != null) 'added_to_operation': addedToOperation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboundCapturesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? source,
    Value<String>? dedupeKey,
    Value<String>? data,
    Value<int>? receivedAtMillis,
    Value<String?>? addedToOperation,
    Value<int>? rowid,
  }) {
    return InboundCapturesCompanion(
      uuid: uuid ?? this.uuid,
      source: source ?? this.source,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      data: data ?? this.data,
      receivedAtMillis: receivedAtMillis ?? this.receivedAtMillis,
      addedToOperation: addedToOperation ?? this.addedToOperation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (receivedAtMillis.present) {
      map['received_at_millis'] = Variable<int>(receivedAtMillis.value);
    }
    if (addedToOperation.present) {
      map['added_to_operation'] = Variable<String>(addedToOperation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboundCapturesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('data: $data, ')
          ..write('receivedAtMillis: $receivedAtMillis, ')
          ..write('addedToOperation: $addedToOperation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeerEventsTable extends PeerEvents
    with TableInfo<$PeerEventsTable, PeerEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationUuidMeta = const VerificationMeta(
    'operationUuid',
  );
  @override
  late final GeneratedColumn<String> operationUuid = GeneratedColumn<String>(
    'operation_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordUuidMeta = const VerificationMeta(
    'recordUuid',
  );
  @override
  late final GeneratedColumn<String> recordUuid = GeneratedColumn<String>(
    'record_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    operationUuid,
    kind,
    recordUuid,
    updatedAtMillis,
    data,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('operation_uuid')) {
      context.handle(
        _operationUuidMeta,
        operationUuid.isAcceptableOrUnknown(
          data['operation_uuid']!,
          _operationUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationUuidMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('record_uuid')) {
      context.handle(
        _recordUuidMeta,
        recordUuid.isAcceptableOrUnknown(data['record_uuid']!, _recordUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_recordUuidMeta);
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
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  PeerEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerEventRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      operationUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_uuid'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      recordUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_uuid'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $PeerEventsTable createAlias(String alias) {
    return $PeerEventsTable(attachedDatabase, alias);
  }
}

class PeerEventRow extends DataClass implements Insertable<PeerEventRow> {
  final int seq;
  final String operationUuid;

  /// `'operation'` or `'qso'` — which repository's `mergeFromPeer` the
  /// catch-up reader hands this row's [data] to.
  final String kind;
  final String recordUuid;
  final int? updatedAtMillis;
  final String data;
  const PeerEventRow({
    required this.seq,
    required this.operationUuid,
    required this.kind,
    required this.recordUuid,
    this.updatedAtMillis,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['operation_uuid'] = Variable<String>(operationUuid);
    map['kind'] = Variable<String>(kind);
    map['record_uuid'] = Variable<String>(recordUuid);
    if (!nullToAbsent || updatedAtMillis != null) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    }
    map['data'] = Variable<String>(data);
    return map;
  }

  PeerEventsCompanion toCompanion(bool nullToAbsent) {
    return PeerEventsCompanion(
      seq: Value(seq),
      operationUuid: Value(operationUuid),
      kind: Value(kind),
      recordUuid: Value(recordUuid),
      updatedAtMillis: updatedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtMillis),
      data: Value(data),
    );
  }

  factory PeerEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerEventRow(
      seq: serializer.fromJson<int>(json['seq']),
      operationUuid: serializer.fromJson<String>(json['operationUuid']),
      kind: serializer.fromJson<String>(json['kind']),
      recordUuid: serializer.fromJson<String>(json['recordUuid']),
      updatedAtMillis: serializer.fromJson<int?>(json['updatedAtMillis']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'operationUuid': serializer.toJson<String>(operationUuid),
      'kind': serializer.toJson<String>(kind),
      'recordUuid': serializer.toJson<String>(recordUuid),
      'updatedAtMillis': serializer.toJson<int?>(updatedAtMillis),
      'data': serializer.toJson<String>(data),
    };
  }

  PeerEventRow copyWith({
    int? seq,
    String? operationUuid,
    String? kind,
    String? recordUuid,
    Value<int?> updatedAtMillis = const Value.absent(),
    String? data,
  }) => PeerEventRow(
    seq: seq ?? this.seq,
    operationUuid: operationUuid ?? this.operationUuid,
    kind: kind ?? this.kind,
    recordUuid: recordUuid ?? this.recordUuid,
    updatedAtMillis: updatedAtMillis.present
        ? updatedAtMillis.value
        : this.updatedAtMillis,
    data: data ?? this.data,
  );
  PeerEventRow copyWithCompanion(PeerEventsCompanion data) {
    return PeerEventRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      operationUuid: data.operationUuid.present
          ? data.operationUuid.value
          : this.operationUuid,
      kind: data.kind.present ? data.kind.value : this.kind,
      recordUuid: data.recordUuid.present
          ? data.recordUuid.value
          : this.recordUuid,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerEventRow(')
          ..write('seq: $seq, ')
          ..write('operationUuid: $operationUuid, ')
          ..write('kind: $kind, ')
          ..write('recordUuid: $recordUuid, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, operationUuid, kind, recordUuid, updatedAtMillis, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerEventRow &&
          other.seq == this.seq &&
          other.operationUuid == this.operationUuid &&
          other.kind == this.kind &&
          other.recordUuid == this.recordUuid &&
          other.updatedAtMillis == this.updatedAtMillis &&
          other.data == this.data);
}

class PeerEventsCompanion extends UpdateCompanion<PeerEventRow> {
  final Value<int> seq;
  final Value<String> operationUuid;
  final Value<String> kind;
  final Value<String> recordUuid;
  final Value<int?> updatedAtMillis;
  final Value<String> data;
  const PeerEventsCompanion({
    this.seq = const Value.absent(),
    this.operationUuid = const Value.absent(),
    this.kind = const Value.absent(),
    this.recordUuid = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.data = const Value.absent(),
  });
  PeerEventsCompanion.insert({
    this.seq = const Value.absent(),
    required String operationUuid,
    required String kind,
    required String recordUuid,
    this.updatedAtMillis = const Value.absent(),
    required String data,
  }) : operationUuid = Value(operationUuid),
       kind = Value(kind),
       recordUuid = Value(recordUuid),
       data = Value(data);
  static Insertable<PeerEventRow> custom({
    Expression<int>? seq,
    Expression<String>? operationUuid,
    Expression<String>? kind,
    Expression<String>? recordUuid,
    Expression<int>? updatedAtMillis,
    Expression<String>? data,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (operationUuid != null) 'operation_uuid': operationUuid,
      if (kind != null) 'kind': kind,
      if (recordUuid != null) 'record_uuid': recordUuid,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (data != null) 'data': data,
    });
  }

  PeerEventsCompanion copyWith({
    Value<int>? seq,
    Value<String>? operationUuid,
    Value<String>? kind,
    Value<String>? recordUuid,
    Value<int?>? updatedAtMillis,
    Value<String>? data,
  }) {
    return PeerEventsCompanion(
      seq: seq ?? this.seq,
      operationUuid: operationUuid ?? this.operationUuid,
      kind: kind ?? this.kind,
      recordUuid: recordUuid ?? this.recordUuid,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      data: data ?? this.data,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (operationUuid.present) {
      map['operation_uuid'] = Variable<String>(operationUuid.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (recordUuid.present) {
      map['record_uuid'] = Variable<String>(recordUuid.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerEventsCompanion(')
          ..write('seq: $seq, ')
          ..write('operationUuid: $operationUuid, ')
          ..write('kind: $kind, ')
          ..write('recordUuid: $recordUuid, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }
}

class $PeerCursorsTable extends PeerCursors
    with TableInfo<$PeerCursorsTable, PeerCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerDeviceIdMeta = const VerificationMeta(
    'peerDeviceId',
  );
  @override
  late final GeneratedColumn<String> peerDeviceId = GeneratedColumn<String>(
    'peer_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationUuidMeta = const VerificationMeta(
    'operationUuid',
  );
  @override
  late final GeneratedColumn<String> operationUuid = GeneratedColumn<String>(
    'operation_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAppliedSeqMeta = const VerificationMeta(
    'lastAppliedSeq',
  );
  @override
  late final GeneratedColumn<int> lastAppliedSeq = GeneratedColumn<int>(
    'last_applied_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerDeviceId,
    operationUuid,
    lastAppliedSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_device_id')) {
      context.handle(
        _peerDeviceIdMeta,
        peerDeviceId.isAcceptableOrUnknown(
          data['peer_device_id']!,
          _peerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerDeviceIdMeta);
    }
    if (data.containsKey('operation_uuid')) {
      context.handle(
        _operationUuidMeta,
        operationUuid.isAcceptableOrUnknown(
          data['operation_uuid']!,
          _operationUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationUuidMeta);
    }
    if (data.containsKey('last_applied_seq')) {
      context.handle(
        _lastAppliedSeqMeta,
        lastAppliedSeq.isAcceptableOrUnknown(
          data['last_applied_seq']!,
          _lastAppliedSeqMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerDeviceId, operationUuid};
  @override
  PeerCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerCursorRow(
      peerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_device_id'],
      )!,
      operationUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_uuid'],
      )!,
      lastAppliedSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_applied_seq'],
      )!,
    );
  }

  @override
  $PeerCursorsTable createAlias(String alias) {
    return $PeerCursorsTable(attachedDatabase, alias);
  }
}

class PeerCursorRow extends DataClass implements Insertable<PeerCursorRow> {
  final String peerDeviceId;
  final String operationUuid;
  final int lastAppliedSeq;
  const PeerCursorRow({
    required this.peerDeviceId,
    required this.operationUuid,
    required this.lastAppliedSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_device_id'] = Variable<String>(peerDeviceId);
    map['operation_uuid'] = Variable<String>(operationUuid);
    map['last_applied_seq'] = Variable<int>(lastAppliedSeq);
    return map;
  }

  PeerCursorsCompanion toCompanion(bool nullToAbsent) {
    return PeerCursorsCompanion(
      peerDeviceId: Value(peerDeviceId),
      operationUuid: Value(operationUuid),
      lastAppliedSeq: Value(lastAppliedSeq),
    );
  }

  factory PeerCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerCursorRow(
      peerDeviceId: serializer.fromJson<String>(json['peerDeviceId']),
      operationUuid: serializer.fromJson<String>(json['operationUuid']),
      lastAppliedSeq: serializer.fromJson<int>(json['lastAppliedSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerDeviceId': serializer.toJson<String>(peerDeviceId),
      'operationUuid': serializer.toJson<String>(operationUuid),
      'lastAppliedSeq': serializer.toJson<int>(lastAppliedSeq),
    };
  }

  PeerCursorRow copyWith({
    String? peerDeviceId,
    String? operationUuid,
    int? lastAppliedSeq,
  }) => PeerCursorRow(
    peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    operationUuid: operationUuid ?? this.operationUuid,
    lastAppliedSeq: lastAppliedSeq ?? this.lastAppliedSeq,
  );
  PeerCursorRow copyWithCompanion(PeerCursorsCompanion data) {
    return PeerCursorRow(
      peerDeviceId: data.peerDeviceId.present
          ? data.peerDeviceId.value
          : this.peerDeviceId,
      operationUuid: data.operationUuid.present
          ? data.operationUuid.value
          : this.operationUuid,
      lastAppliedSeq: data.lastAppliedSeq.present
          ? data.lastAppliedSeq.value
          : this.lastAppliedSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerCursorRow(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('operationUuid: $operationUuid, ')
          ..write('lastAppliedSeq: $lastAppliedSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerDeviceId, operationUuid, lastAppliedSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerCursorRow &&
          other.peerDeviceId == this.peerDeviceId &&
          other.operationUuid == this.operationUuid &&
          other.lastAppliedSeq == this.lastAppliedSeq);
}

class PeerCursorsCompanion extends UpdateCompanion<PeerCursorRow> {
  final Value<String> peerDeviceId;
  final Value<String> operationUuid;
  final Value<int> lastAppliedSeq;
  final Value<int> rowid;
  const PeerCursorsCompanion({
    this.peerDeviceId = const Value.absent(),
    this.operationUuid = const Value.absent(),
    this.lastAppliedSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeerCursorsCompanion.insert({
    required String peerDeviceId,
    required String operationUuid,
    this.lastAppliedSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerDeviceId = Value(peerDeviceId),
       operationUuid = Value(operationUuid);
  static Insertable<PeerCursorRow> custom({
    Expression<String>? peerDeviceId,
    Expression<String>? operationUuid,
    Expression<int>? lastAppliedSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerDeviceId != null) 'peer_device_id': peerDeviceId,
      if (operationUuid != null) 'operation_uuid': operationUuid,
      if (lastAppliedSeq != null) 'last_applied_seq': lastAppliedSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeerCursorsCompanion copyWith({
    Value<String>? peerDeviceId,
    Value<String>? operationUuid,
    Value<int>? lastAppliedSeq,
    Value<int>? rowid,
  }) {
    return PeerCursorsCompanion(
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      operationUuid: operationUuid ?? this.operationUuid,
      lastAppliedSeq: lastAppliedSeq ?? this.lastAppliedSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerDeviceId.present) {
      map['peer_device_id'] = Variable<String>(peerDeviceId.value);
    }
    if (operationUuid.present) {
      map['operation_uuid'] = Variable<String>(operationUuid.value);
    }
    if (lastAppliedSeq.present) {
      map['last_applied_seq'] = Variable<int>(lastAppliedSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerCursorsCompanion(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('operationUuid: $operationUuid, ')
          ..write('lastAppliedSeq: $lastAppliedSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeerTrustTable extends PeerTrust
    with TableInfo<$PeerTrustTable, PeerTrustRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerTrustTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerDeviceIdMeta = const VerificationMeta(
    'peerDeviceId',
  );
  @override
  late final GeneratedColumn<String> peerDeviceId = GeneratedColumn<String>(
    'peer_device_id',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pairedAtMillisMeta = const VerificationMeta(
    'pairedAtMillis',
  );
  @override
  late final GeneratedColumn<int> pairedAtMillis = GeneratedColumn<int>(
    'paired_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMillisMeta = const VerificationMeta(
    'lastSeenAtMillis',
  );
  @override
  late final GeneratedColumn<int> lastSeenAtMillis = GeneratedColumn<int>(
    'last_seen_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerDeviceId,
    name,
    pairedAtMillis,
    lastSeenAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_trust';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerTrustRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_device_id')) {
      context.handle(
        _peerDeviceIdMeta,
        peerDeviceId.isAcceptableOrUnknown(
          data['peer_device_id']!,
          _peerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerDeviceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('paired_at_millis')) {
      context.handle(
        _pairedAtMillisMeta,
        pairedAtMillis.isAcceptableOrUnknown(
          data['paired_at_millis']!,
          _pairedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pairedAtMillisMeta);
    }
    if (data.containsKey('last_seen_at_millis')) {
      context.handle(
        _lastSeenAtMillisMeta,
        lastSeenAtMillis.isAcceptableOrUnknown(
          data['last_seen_at_millis']!,
          _lastSeenAtMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerDeviceId};
  @override
  PeerTrustRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerTrustRow(
      peerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pairedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paired_at_millis'],
      )!,
      lastSeenAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at_millis'],
      ),
    );
  }

  @override
  $PeerTrustTable createAlias(String alias) {
    return $PeerTrustTable(attachedDatabase, alias);
  }
}

class PeerTrustRow extends DataClass implements Insertable<PeerTrustRow> {
  final String peerDeviceId;
  final String name;
  final int pairedAtMillis;
  final int? lastSeenAtMillis;
  const PeerTrustRow({
    required this.peerDeviceId,
    required this.name,
    required this.pairedAtMillis,
    this.lastSeenAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_device_id'] = Variable<String>(peerDeviceId);
    map['name'] = Variable<String>(name);
    map['paired_at_millis'] = Variable<int>(pairedAtMillis);
    if (!nullToAbsent || lastSeenAtMillis != null) {
      map['last_seen_at_millis'] = Variable<int>(lastSeenAtMillis);
    }
    return map;
  }

  PeerTrustCompanion toCompanion(bool nullToAbsent) {
    return PeerTrustCompanion(
      peerDeviceId: Value(peerDeviceId),
      name: Value(name),
      pairedAtMillis: Value(pairedAtMillis),
      lastSeenAtMillis: lastSeenAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAtMillis),
    );
  }

  factory PeerTrustRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerTrustRow(
      peerDeviceId: serializer.fromJson<String>(json['peerDeviceId']),
      name: serializer.fromJson<String>(json['name']),
      pairedAtMillis: serializer.fromJson<int>(json['pairedAtMillis']),
      lastSeenAtMillis: serializer.fromJson<int?>(json['lastSeenAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerDeviceId': serializer.toJson<String>(peerDeviceId),
      'name': serializer.toJson<String>(name),
      'pairedAtMillis': serializer.toJson<int>(pairedAtMillis),
      'lastSeenAtMillis': serializer.toJson<int?>(lastSeenAtMillis),
    };
  }

  PeerTrustRow copyWith({
    String? peerDeviceId,
    String? name,
    int? pairedAtMillis,
    Value<int?> lastSeenAtMillis = const Value.absent(),
  }) => PeerTrustRow(
    peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    name: name ?? this.name,
    pairedAtMillis: pairedAtMillis ?? this.pairedAtMillis,
    lastSeenAtMillis: lastSeenAtMillis.present
        ? lastSeenAtMillis.value
        : this.lastSeenAtMillis,
  );
  PeerTrustRow copyWithCompanion(PeerTrustCompanion data) {
    return PeerTrustRow(
      peerDeviceId: data.peerDeviceId.present
          ? data.peerDeviceId.value
          : this.peerDeviceId,
      name: data.name.present ? data.name.value : this.name,
      pairedAtMillis: data.pairedAtMillis.present
          ? data.pairedAtMillis.value
          : this.pairedAtMillis,
      lastSeenAtMillis: data.lastSeenAtMillis.present
          ? data.lastSeenAtMillis.value
          : this.lastSeenAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerTrustRow(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('name: $name, ')
          ..write('pairedAtMillis: $pairedAtMillis, ')
          ..write('lastSeenAtMillis: $lastSeenAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(peerDeviceId, name, pairedAtMillis, lastSeenAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerTrustRow &&
          other.peerDeviceId == this.peerDeviceId &&
          other.name == this.name &&
          other.pairedAtMillis == this.pairedAtMillis &&
          other.lastSeenAtMillis == this.lastSeenAtMillis);
}

class PeerTrustCompanion extends UpdateCompanion<PeerTrustRow> {
  final Value<String> peerDeviceId;
  final Value<String> name;
  final Value<int> pairedAtMillis;
  final Value<int?> lastSeenAtMillis;
  final Value<int> rowid;
  const PeerTrustCompanion({
    this.peerDeviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.pairedAtMillis = const Value.absent(),
    this.lastSeenAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeerTrustCompanion.insert({
    required String peerDeviceId,
    required String name,
    required int pairedAtMillis,
    this.lastSeenAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerDeviceId = Value(peerDeviceId),
       name = Value(name),
       pairedAtMillis = Value(pairedAtMillis);
  static Insertable<PeerTrustRow> custom({
    Expression<String>? peerDeviceId,
    Expression<String>? name,
    Expression<int>? pairedAtMillis,
    Expression<int>? lastSeenAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerDeviceId != null) 'peer_device_id': peerDeviceId,
      if (name != null) 'name': name,
      if (pairedAtMillis != null) 'paired_at_millis': pairedAtMillis,
      if (lastSeenAtMillis != null) 'last_seen_at_millis': lastSeenAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeerTrustCompanion copyWith({
    Value<String>? peerDeviceId,
    Value<String>? name,
    Value<int>? pairedAtMillis,
    Value<int?>? lastSeenAtMillis,
    Value<int>? rowid,
  }) {
    return PeerTrustCompanion(
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      name: name ?? this.name,
      pairedAtMillis: pairedAtMillis ?? this.pairedAtMillis,
      lastSeenAtMillis: lastSeenAtMillis ?? this.lastSeenAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerDeviceId.present) {
      map['peer_device_id'] = Variable<String>(peerDeviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pairedAtMillis.present) {
      map['paired_at_millis'] = Variable<int>(pairedAtMillis.value);
    }
    if (lastSeenAtMillis.present) {
      map['last_seen_at_millis'] = Variable<int>(lastSeenAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerTrustCompanion(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('name: $name, ')
          ..write('pairedAtMillis: $pairedAtMillis, ')
          ..write('lastSeenAtMillis: $lastSeenAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaimsTable extends Claims with TableInfo<$ClaimsTable, ClaimRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaimsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programMeta = const VerificationMeta(
    'program',
  );
  @override
  late final GeneratedColumn<String> program = GeneratedColumn<String>(
    'program',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holderMeta = const VerificationMeta('holder');
  @override
  late final GeneratedColumn<String> holder = GeneratedColumn<String>(
    'holder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editionMeta = const VerificationMeta(
    'edition',
  );
  @override
  late final GeneratedColumn<String> edition = GeneratedColumn<String>(
    'edition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMillisMeta = const VerificationMeta(
    'atMillis',
  );
  @override
  late final GeneratedColumn<int> atMillis = GeneratedColumn<int>(
    'at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qsoMeta = const VerificationMeta('qso');
  @override
  late final GeneratedColumn<String> qso = GeneratedColumn<String>(
    'qso',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epochMeta = const VerificationMeta('epoch');
  @override
  late final GeneratedColumn<int> epoch = GeneratedColumn<int>(
    'epoch',
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
    program,
    holder,
    edition,
    ref,
    band,
    mode,
    source,
    level,
    atMillis,
    qso,
    data,
    version,
    epoch,
    deleted,
    synced,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claims';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClaimRow> instance, {
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
    if (data.containsKey('program')) {
      context.handle(
        _programMeta,
        program.isAcceptableOrUnknown(data['program']!, _programMeta),
      );
    } else if (isInserting) {
      context.missing(_programMeta);
    }
    if (data.containsKey('holder')) {
      context.handle(
        _holderMeta,
        holder.isAcceptableOrUnknown(data['holder']!, _holderMeta),
      );
    } else if (isInserting) {
      context.missing(_holderMeta);
    }
    if (data.containsKey('edition')) {
      context.handle(
        _editionMeta,
        edition.isAcceptableOrUnknown(data['edition']!, _editionMeta),
      );
    }
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
      );
    } else if (isInserting) {
      context.missing(_refMeta);
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
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('at_millis')) {
      context.handle(
        _atMillisMeta,
        atMillis.isAcceptableOrUnknown(data['at_millis']!, _atMillisMeta),
      );
    }
    if (data.containsKey('qso')) {
      context.handle(
        _qsoMeta,
        qso.isAcceptableOrUnknown(data['qso']!, _qsoMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('epoch')) {
      context.handle(
        _epochMeta,
        epoch.isAcceptableOrUnknown(data['epoch']!, _epochMeta),
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
  ClaimRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClaimRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      program: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program'],
      )!,
      holder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holder'],
      )!,
      edition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edition'],
      )!,
      ref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref'],
      )!,
      band: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      atMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_millis'],
      ),
      qso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qso'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      epoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epoch'],
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
  $ClaimsTable createAlias(String alias) {
    return $ClaimsTable(attachedDatabase, alias);
  }
}

class ClaimRow extends DataClass implements Insertable<ClaimRow> {
  final String uuid;
  final String program;
  final String holder;

  /// Empty for a lifetime program.
  final String edition;
  final String ref;

  /// Null: any band.
  final String? band;

  /// Null: any mode.
  final String? mode;

  /// `log`, or `import:<batchId>`.
  final String source;

  /// A `ClaimLevel` name.
  final String level;

  /// When the claiming contact happened; null when an import did not say.
  final int? atMillis;

  /// The claiming contact; null for an import that matched none.
  final String? qso;

  /// `by`, `label`, `guess`, and an import's own fields.
  final String data;

  /// The program version that computed this row.
  final int version;

  /// Raised by a rescan; outranks the claim itself on merge (§7).
  final int epoch;
  final bool deleted;
  final bool synced;
  final int? updatedAtMillis;
  const ClaimRow({
    required this.uuid,
    required this.program,
    required this.holder,
    required this.edition,
    required this.ref,
    this.band,
    this.mode,
    required this.source,
    required this.level,
    this.atMillis,
    this.qso,
    required this.data,
    required this.version,
    required this.epoch,
    required this.deleted,
    required this.synced,
    this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['program'] = Variable<String>(program);
    map['holder'] = Variable<String>(holder);
    map['edition'] = Variable<String>(edition);
    map['ref'] = Variable<String>(ref);
    if (!nullToAbsent || band != null) {
      map['band'] = Variable<String>(band);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    map['source'] = Variable<String>(source);
    map['level'] = Variable<String>(level);
    if (!nullToAbsent || atMillis != null) {
      map['at_millis'] = Variable<int>(atMillis);
    }
    if (!nullToAbsent || qso != null) {
      map['qso'] = Variable<String>(qso);
    }
    map['data'] = Variable<String>(data);
    map['version'] = Variable<int>(version);
    map['epoch'] = Variable<int>(epoch);
    map['deleted'] = Variable<bool>(deleted);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || updatedAtMillis != null) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    }
    return map;
  }

  ClaimsCompanion toCompanion(bool nullToAbsent) {
    return ClaimsCompanion(
      uuid: Value(uuid),
      program: Value(program),
      holder: Value(holder),
      edition: Value(edition),
      ref: Value(ref),
      band: band == null && nullToAbsent ? const Value.absent() : Value(band),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      source: Value(source),
      level: Value(level),
      atMillis: atMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(atMillis),
      qso: qso == null && nullToAbsent ? const Value.absent() : Value(qso),
      data: Value(data),
      version: Value(version),
      epoch: Value(epoch),
      deleted: Value(deleted),
      synced: Value(synced),
      updatedAtMillis: updatedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtMillis),
    );
  }

  factory ClaimRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClaimRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      program: serializer.fromJson<String>(json['program']),
      holder: serializer.fromJson<String>(json['holder']),
      edition: serializer.fromJson<String>(json['edition']),
      ref: serializer.fromJson<String>(json['ref']),
      band: serializer.fromJson<String?>(json['band']),
      mode: serializer.fromJson<String?>(json['mode']),
      source: serializer.fromJson<String>(json['source']),
      level: serializer.fromJson<String>(json['level']),
      atMillis: serializer.fromJson<int?>(json['atMillis']),
      qso: serializer.fromJson<String?>(json['qso']),
      data: serializer.fromJson<String>(json['data']),
      version: serializer.fromJson<int>(json['version']),
      epoch: serializer.fromJson<int>(json['epoch']),
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
      'program': serializer.toJson<String>(program),
      'holder': serializer.toJson<String>(holder),
      'edition': serializer.toJson<String>(edition),
      'ref': serializer.toJson<String>(ref),
      'band': serializer.toJson<String?>(band),
      'mode': serializer.toJson<String?>(mode),
      'source': serializer.toJson<String>(source),
      'level': serializer.toJson<String>(level),
      'atMillis': serializer.toJson<int?>(atMillis),
      'qso': serializer.toJson<String?>(qso),
      'data': serializer.toJson<String>(data),
      'version': serializer.toJson<int>(version),
      'epoch': serializer.toJson<int>(epoch),
      'deleted': serializer.toJson<bool>(deleted),
      'synced': serializer.toJson<bool>(synced),
      'updatedAtMillis': serializer.toJson<int?>(updatedAtMillis),
    };
  }

  ClaimRow copyWith({
    String? uuid,
    String? program,
    String? holder,
    String? edition,
    String? ref,
    Value<String?> band = const Value.absent(),
    Value<String?> mode = const Value.absent(),
    String? source,
    String? level,
    Value<int?> atMillis = const Value.absent(),
    Value<String?> qso = const Value.absent(),
    String? data,
    int? version,
    int? epoch,
    bool? deleted,
    bool? synced,
    Value<int?> updatedAtMillis = const Value.absent(),
  }) => ClaimRow(
    uuid: uuid ?? this.uuid,
    program: program ?? this.program,
    holder: holder ?? this.holder,
    edition: edition ?? this.edition,
    ref: ref ?? this.ref,
    band: band.present ? band.value : this.band,
    mode: mode.present ? mode.value : this.mode,
    source: source ?? this.source,
    level: level ?? this.level,
    atMillis: atMillis.present ? atMillis.value : this.atMillis,
    qso: qso.present ? qso.value : this.qso,
    data: data ?? this.data,
    version: version ?? this.version,
    epoch: epoch ?? this.epoch,
    deleted: deleted ?? this.deleted,
    synced: synced ?? this.synced,
    updatedAtMillis: updatedAtMillis.present
        ? updatedAtMillis.value
        : this.updatedAtMillis,
  );
  ClaimRow copyWithCompanion(ClaimsCompanion data) {
    return ClaimRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      program: data.program.present ? data.program.value : this.program,
      holder: data.holder.present ? data.holder.value : this.holder,
      edition: data.edition.present ? data.edition.value : this.edition,
      ref: data.ref.present ? data.ref.value : this.ref,
      band: data.band.present ? data.band.value : this.band,
      mode: data.mode.present ? data.mode.value : this.mode,
      source: data.source.present ? data.source.value : this.source,
      level: data.level.present ? data.level.value : this.level,
      atMillis: data.atMillis.present ? data.atMillis.value : this.atMillis,
      qso: data.qso.present ? data.qso.value : this.qso,
      data: data.data.present ? data.data.value : this.data,
      version: data.version.present ? data.version.value : this.version,
      epoch: data.epoch.present ? data.epoch.value : this.epoch,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      synced: data.synced.present ? data.synced.value : this.synced,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaimRow(')
          ..write('uuid: $uuid, ')
          ..write('program: $program, ')
          ..write('holder: $holder, ')
          ..write('edition: $edition, ')
          ..write('ref: $ref, ')
          ..write('band: $band, ')
          ..write('mode: $mode, ')
          ..write('source: $source, ')
          ..write('level: $level, ')
          ..write('atMillis: $atMillis, ')
          ..write('qso: $qso, ')
          ..write('data: $data, ')
          ..write('version: $version, ')
          ..write('epoch: $epoch, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    program,
    holder,
    edition,
    ref,
    band,
    mode,
    source,
    level,
    atMillis,
    qso,
    data,
    version,
    epoch,
    deleted,
    synced,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaimRow &&
          other.uuid == this.uuid &&
          other.program == this.program &&
          other.holder == this.holder &&
          other.edition == this.edition &&
          other.ref == this.ref &&
          other.band == this.band &&
          other.mode == this.mode &&
          other.source == this.source &&
          other.level == this.level &&
          other.atMillis == this.atMillis &&
          other.qso == this.qso &&
          other.data == this.data &&
          other.version == this.version &&
          other.epoch == this.epoch &&
          other.deleted == this.deleted &&
          other.synced == this.synced &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class ClaimsCompanion extends UpdateCompanion<ClaimRow> {
  final Value<String> uuid;
  final Value<String> program;
  final Value<String> holder;
  final Value<String> edition;
  final Value<String> ref;
  final Value<String?> band;
  final Value<String?> mode;
  final Value<String> source;
  final Value<String> level;
  final Value<int?> atMillis;
  final Value<String?> qso;
  final Value<String> data;
  final Value<int> version;
  final Value<int> epoch;
  final Value<bool> deleted;
  final Value<bool> synced;
  final Value<int?> updatedAtMillis;
  final Value<int> rowid;
  const ClaimsCompanion({
    this.uuid = const Value.absent(),
    this.program = const Value.absent(),
    this.holder = const Value.absent(),
    this.edition = const Value.absent(),
    this.ref = const Value.absent(),
    this.band = const Value.absent(),
    this.mode = const Value.absent(),
    this.source = const Value.absent(),
    this.level = const Value.absent(),
    this.atMillis = const Value.absent(),
    this.qso = const Value.absent(),
    this.data = const Value.absent(),
    this.version = const Value.absent(),
    this.epoch = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaimsCompanion.insert({
    required String uuid,
    required String program,
    required String holder,
    this.edition = const Value.absent(),
    required String ref,
    this.band = const Value.absent(),
    this.mode = const Value.absent(),
    required String source,
    required String level,
    this.atMillis = const Value.absent(),
    this.qso = const Value.absent(),
    this.data = const Value.absent(),
    required int version,
    this.epoch = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       program = Value(program),
       holder = Value(holder),
       ref = Value(ref),
       source = Value(source),
       level = Value(level),
       version = Value(version);
  static Insertable<ClaimRow> custom({
    Expression<String>? uuid,
    Expression<String>? program,
    Expression<String>? holder,
    Expression<String>? edition,
    Expression<String>? ref,
    Expression<String>? band,
    Expression<String>? mode,
    Expression<String>? source,
    Expression<String>? level,
    Expression<int>? atMillis,
    Expression<String>? qso,
    Expression<String>? data,
    Expression<int>? version,
    Expression<int>? epoch,
    Expression<bool>? deleted,
    Expression<bool>? synced,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (program != null) 'program': program,
      if (holder != null) 'holder': holder,
      if (edition != null) 'edition': edition,
      if (ref != null) 'ref': ref,
      if (band != null) 'band': band,
      if (mode != null) 'mode': mode,
      if (source != null) 'source': source,
      if (level != null) 'level': level,
      if (atMillis != null) 'at_millis': atMillis,
      if (qso != null) 'qso': qso,
      if (data != null) 'data': data,
      if (version != null) 'version': version,
      if (epoch != null) 'epoch': epoch,
      if (deleted != null) 'deleted': deleted,
      if (synced != null) 'synced': synced,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaimsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? program,
    Value<String>? holder,
    Value<String>? edition,
    Value<String>? ref,
    Value<String?>? band,
    Value<String?>? mode,
    Value<String>? source,
    Value<String>? level,
    Value<int?>? atMillis,
    Value<String?>? qso,
    Value<String>? data,
    Value<int>? version,
    Value<int>? epoch,
    Value<bool>? deleted,
    Value<bool>? synced,
    Value<int?>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return ClaimsCompanion(
      uuid: uuid ?? this.uuid,
      program: program ?? this.program,
      holder: holder ?? this.holder,
      edition: edition ?? this.edition,
      ref: ref ?? this.ref,
      band: band ?? this.band,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      level: level ?? this.level,
      atMillis: atMillis ?? this.atMillis,
      qso: qso ?? this.qso,
      data: data ?? this.data,
      version: version ?? this.version,
      epoch: epoch ?? this.epoch,
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
    if (program.present) {
      map['program'] = Variable<String>(program.value);
    }
    if (holder.present) {
      map['holder'] = Variable<String>(holder.value);
    }
    if (edition.present) {
      map['edition'] = Variable<String>(edition.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (band.present) {
      map['band'] = Variable<String>(band.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (atMillis.present) {
      map['at_millis'] = Variable<int>(atMillis.value);
    }
    if (qso.present) {
      map['qso'] = Variable<String>(qso.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (epoch.present) {
      map['epoch'] = Variable<int>(epoch.value);
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
    return (StringBuffer('ClaimsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('program: $program, ')
          ..write('holder: $holder, ')
          ..write('edition: $edition, ')
          ..write('ref: $ref, ')
          ..write('band: $band, ')
          ..write('mode: $mode, ')
          ..write('source: $source, ')
          ..write('level: $level, ')
          ..write('atMillis: $atMillis, ')
          ..write('qso: $qso, ')
          ..write('data: $data, ')
          ..write('version: $version, ')
          ..write('epoch: $epoch, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
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
  late final $InboundCapturesTable inboundCaptures = $InboundCapturesTable(
    this,
  );
  late final $PeerEventsTable peerEvents = $PeerEventsTable(this);
  late final $PeerCursorsTable peerCursors = $PeerCursorsTable(this);
  late final $PeerTrustTable peerTrust = $PeerTrustTable(this);
  late final $ClaimsTable claims = $ClaimsTable(this);
  late final Index qsosOperationStart = Index(
    'qsos_operation_start',
    'CREATE INDEX qsos_operation_start ON qsos (operation, start_at_millis)',
  );
  late final Index qsosTheirCallStart = Index(
    'qsos_their_call_start',
    'CREATE INDEX qsos_their_call_start ON qsos (their_call, start_at_millis)',
  );
  late final Index qsosOperationCounters = Index(
    'qsos_operation_counters',
    'CREATE INDEX qsos_operation_counters ON qsos (operation, deleted, band, start_at_millis)',
  );
  late final Index qsosSyncedStart = Index(
    'qsos_synced_start',
    'CREATE INDEX qsos_synced_start ON qsos (synced, start_at_millis)',
  );
  late final Index inboundCapturesDedupeKey = Index(
    'inbound_captures_dedupe_key',
    'CREATE UNIQUE INDEX inbound_captures_dedupe_key ON inbound_captures (dedupe_key)',
  );
  late final Index peerEventsOperationSeq = Index(
    'peer_events_operation_seq',
    'CREATE INDEX peer_events_operation_seq ON peer_events (operation_uuid, seq, record_uuid, updated_at_millis)',
  );
  late final Index peerEventsOperationRecord = Index(
    'peer_events_operation_record',
    'CREATE INDEX peer_events_operation_record ON peer_events (operation_uuid, record_uuid)',
  );
  late final Index claimsQso = Index(
    'claims_qso',
    'CREATE INDEX claims_qso ON claims (qso)',
  );
  late final Index claimsChecklist = Index(
    'claims_checklist',
    'CREATE INDEX claims_checklist ON claims (program, holder, edition)',
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
    inboundCaptures,
    peerEvents,
    peerCursors,
    peerTrust,
    claims,
    qsosOperationStart,
    qsosTheirCallStart,
    qsosOperationCounters,
    qsosSyncedStart,
    inboundCapturesDedupeKey,
    peerEventsOperationSeq,
    peerEventsOperationRecord,
    claimsQso,
    claimsChecklist,
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
      Value<bool> purged,
      Value<bool> purgedLocally,
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
      Value<bool> purged,
      Value<bool> purgedLocally,
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

  ColumnFilters<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get purgedLocally => $composableBuilder(
    column: $table.purgedLocally,
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

  ColumnOrderings<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get purgedLocally => $composableBuilder(
    column: $table.purgedLocally,
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

  GeneratedColumn<bool> get purged =>
      $composableBuilder(column: $table.purged, builder: (column) => column);

  GeneratedColumn<bool> get purgedLocally => $composableBuilder(
    column: $table.purgedLocally,
    builder: (column) => column,
  );

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
                Value<bool> purged = const Value.absent(),
                Value<bool> purgedLocally = const Value.absent(),
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
                purged: purged,
                purgedLocally: purgedLocally,
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
                Value<bool> purged = const Value.absent(),
                Value<bool> purgedLocally = const Value.absent(),
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
                purged: purged,
                purgedLocally: purgedLocally,
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
      Value<bool> purged,
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
      Value<bool> purged,
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

  ColumnFilters<bool> get purged => $composableBuilder(
    column: $table.purged,
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

  ColumnOrderings<bool> get purged => $composableBuilder(
    column: $table.purged,
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

  GeneratedColumn<bool> get purged =>
      $composableBuilder(column: $table.purged, builder: (column) => column);

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
                Value<bool> purged = const Value.absent(),
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
                purged: purged,
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
                Value<bool> purged = const Value.absent(),
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
                purged: purged,
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
typedef $$InboundCapturesTableCreateCompanionBuilder =
    InboundCapturesCompanion Function({
      required String uuid,
      required String source,
      required String dedupeKey,
      required String data,
      required int receivedAtMillis,
      Value<String?> addedToOperation,
      Value<int> rowid,
    });
typedef $$InboundCapturesTableUpdateCompanionBuilder =
    InboundCapturesCompanion Function({
      Value<String> uuid,
      Value<String> source,
      Value<String> dedupeKey,
      Value<String> data,
      Value<int> receivedAtMillis,
      Value<String?> addedToOperation,
      Value<int> rowid,
    });

class $$InboundCapturesTableFilterComposer
    extends Composer<_$HaLoDatabase, $InboundCapturesTable> {
  $$InboundCapturesTableFilterComposer({
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedAtMillis => $composableBuilder(
    column: $table.receivedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedToOperation => $composableBuilder(
    column: $table.addedToOperation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InboundCapturesTableOrderingComposer
    extends Composer<_$HaLoDatabase, $InboundCapturesTable> {
  $$InboundCapturesTableOrderingComposer({
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedAtMillis => $composableBuilder(
    column: $table.receivedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedToOperation => $composableBuilder(
    column: $table.addedToOperation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InboundCapturesTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $InboundCapturesTable> {
  $$InboundCapturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get receivedAtMillis => $composableBuilder(
    column: $table.receivedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedToOperation => $composableBuilder(
    column: $table.addedToOperation,
    builder: (column) => column,
  );
}

class $$InboundCapturesTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $InboundCapturesTable,
          InboundCaptureRow,
          $$InboundCapturesTableFilterComposer,
          $$InboundCapturesTableOrderingComposer,
          $$InboundCapturesTableAnnotationComposer,
          $$InboundCapturesTableCreateCompanionBuilder,
          $$InboundCapturesTableUpdateCompanionBuilder,
          (
            InboundCaptureRow,
            BaseReferences<
              _$HaLoDatabase,
              $InboundCapturesTable,
              InboundCaptureRow
            >,
          ),
          InboundCaptureRow,
          PrefetchHooks Function()
        > {
  $$InboundCapturesTableTableManager(
    _$HaLoDatabase db,
    $InboundCapturesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboundCapturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboundCapturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboundCapturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> dedupeKey = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> receivedAtMillis = const Value.absent(),
                Value<String?> addedToOperation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboundCapturesCompanion(
                uuid: uuid,
                source: source,
                dedupeKey: dedupeKey,
                data: data,
                receivedAtMillis: receivedAtMillis,
                addedToOperation: addedToOperation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String source,
                required String dedupeKey,
                required String data,
                required int receivedAtMillis,
                Value<String?> addedToOperation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboundCapturesCompanion.insert(
                uuid: uuid,
                source: source,
                dedupeKey: dedupeKey,
                data: data,
                receivedAtMillis: receivedAtMillis,
                addedToOperation: addedToOperation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InboundCapturesTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $InboundCapturesTable,
      InboundCaptureRow,
      $$InboundCapturesTableFilterComposer,
      $$InboundCapturesTableOrderingComposer,
      $$InboundCapturesTableAnnotationComposer,
      $$InboundCapturesTableCreateCompanionBuilder,
      $$InboundCapturesTableUpdateCompanionBuilder,
      (
        InboundCaptureRow,
        BaseReferences<
          _$HaLoDatabase,
          $InboundCapturesTable,
          InboundCaptureRow
        >,
      ),
      InboundCaptureRow,
      PrefetchHooks Function()
    >;
typedef $$PeerEventsTableCreateCompanionBuilder =
    PeerEventsCompanion Function({
      Value<int> seq,
      required String operationUuid,
      required String kind,
      required String recordUuid,
      Value<int?> updatedAtMillis,
      required String data,
    });
typedef $$PeerEventsTableUpdateCompanionBuilder =
    PeerEventsCompanion Function({
      Value<int> seq,
      Value<String> operationUuid,
      Value<String> kind,
      Value<String> recordUuid,
      Value<int?> updatedAtMillis,
      Value<String> data,
    });

class $$PeerEventsTableFilterComposer
    extends Composer<_$HaLoDatabase, $PeerEventsTable> {
  $$PeerEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationUuid => $composableBuilder(
    column: $table.operationUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordUuid => $composableBuilder(
    column: $table.recordUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerEventsTableOrderingComposer
    extends Composer<_$HaLoDatabase, $PeerEventsTable> {
  $$PeerEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationUuid => $composableBuilder(
    column: $table.operationUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordUuid => $composableBuilder(
    column: $table.recordUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerEventsTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $PeerEventsTable> {
  $$PeerEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get operationUuid => $composableBuilder(
    column: $table.operationUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get recordUuid => $composableBuilder(
    column: $table.recordUuid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$PeerEventsTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $PeerEventsTable,
          PeerEventRow,
          $$PeerEventsTableFilterComposer,
          $$PeerEventsTableOrderingComposer,
          $$PeerEventsTableAnnotationComposer,
          $$PeerEventsTableCreateCompanionBuilder,
          $$PeerEventsTableUpdateCompanionBuilder,
          (
            PeerEventRow,
            BaseReferences<_$HaLoDatabase, $PeerEventsTable, PeerEventRow>,
          ),
          PeerEventRow,
          PrefetchHooks Function()
        > {
  $$PeerEventsTableTableManager(_$HaLoDatabase db, $PeerEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeerEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> operationUuid = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> recordUuid = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<String> data = const Value.absent(),
              }) => PeerEventsCompanion(
                seq: seq,
                operationUuid: operationUuid,
                kind: kind,
                recordUuid: recordUuid,
                updatedAtMillis: updatedAtMillis,
                data: data,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String operationUuid,
                required String kind,
                required String recordUuid,
                Value<int?> updatedAtMillis = const Value.absent(),
                required String data,
              }) => PeerEventsCompanion.insert(
                seq: seq,
                operationUuid: operationUuid,
                kind: kind,
                recordUuid: recordUuid,
                updatedAtMillis: updatedAtMillis,
                data: data,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $PeerEventsTable,
      PeerEventRow,
      $$PeerEventsTableFilterComposer,
      $$PeerEventsTableOrderingComposer,
      $$PeerEventsTableAnnotationComposer,
      $$PeerEventsTableCreateCompanionBuilder,
      $$PeerEventsTableUpdateCompanionBuilder,
      (
        PeerEventRow,
        BaseReferences<_$HaLoDatabase, $PeerEventsTable, PeerEventRow>,
      ),
      PeerEventRow,
      PrefetchHooks Function()
    >;
typedef $$PeerCursorsTableCreateCompanionBuilder =
    PeerCursorsCompanion Function({
      required String peerDeviceId,
      required String operationUuid,
      Value<int> lastAppliedSeq,
      Value<int> rowid,
    });
typedef $$PeerCursorsTableUpdateCompanionBuilder =
    PeerCursorsCompanion Function({
      Value<String> peerDeviceId,
      Value<String> operationUuid,
      Value<int> lastAppliedSeq,
      Value<int> rowid,
    });

class $$PeerCursorsTableFilterComposer
    extends Composer<_$HaLoDatabase, $PeerCursorsTable> {
  $$PeerCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationUuid => $composableBuilder(
    column: $table.operationUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAppliedSeq => $composableBuilder(
    column: $table.lastAppliedSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerCursorsTableOrderingComposer
    extends Composer<_$HaLoDatabase, $PeerCursorsTable> {
  $$PeerCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationUuid => $composableBuilder(
    column: $table.operationUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAppliedSeq => $composableBuilder(
    column: $table.lastAppliedSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerCursorsTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $PeerCursorsTable> {
  $$PeerCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationUuid => $composableBuilder(
    column: $table.operationUuid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAppliedSeq => $composableBuilder(
    column: $table.lastAppliedSeq,
    builder: (column) => column,
  );
}

class $$PeerCursorsTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $PeerCursorsTable,
          PeerCursorRow,
          $$PeerCursorsTableFilterComposer,
          $$PeerCursorsTableOrderingComposer,
          $$PeerCursorsTableAnnotationComposer,
          $$PeerCursorsTableCreateCompanionBuilder,
          $$PeerCursorsTableUpdateCompanionBuilder,
          (
            PeerCursorRow,
            BaseReferences<_$HaLoDatabase, $PeerCursorsTable, PeerCursorRow>,
          ),
          PeerCursorRow,
          PrefetchHooks Function()
        > {
  $$PeerCursorsTableTableManager(_$HaLoDatabase db, $PeerCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeerCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> peerDeviceId = const Value.absent(),
                Value<String> operationUuid = const Value.absent(),
                Value<int> lastAppliedSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerCursorsCompanion(
                peerDeviceId: peerDeviceId,
                operationUuid: operationUuid,
                lastAppliedSeq: lastAppliedSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerDeviceId,
                required String operationUuid,
                Value<int> lastAppliedSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerCursorsCompanion.insert(
                peerDeviceId: peerDeviceId,
                operationUuid: operationUuid,
                lastAppliedSeq: lastAppliedSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $PeerCursorsTable,
      PeerCursorRow,
      $$PeerCursorsTableFilterComposer,
      $$PeerCursorsTableOrderingComposer,
      $$PeerCursorsTableAnnotationComposer,
      $$PeerCursorsTableCreateCompanionBuilder,
      $$PeerCursorsTableUpdateCompanionBuilder,
      (
        PeerCursorRow,
        BaseReferences<_$HaLoDatabase, $PeerCursorsTable, PeerCursorRow>,
      ),
      PeerCursorRow,
      PrefetchHooks Function()
    >;
typedef $$PeerTrustTableCreateCompanionBuilder =
    PeerTrustCompanion Function({
      required String peerDeviceId,
      required String name,
      required int pairedAtMillis,
      Value<int?> lastSeenAtMillis,
      Value<int> rowid,
    });
typedef $$PeerTrustTableUpdateCompanionBuilder =
    PeerTrustCompanion Function({
      Value<String> peerDeviceId,
      Value<String> name,
      Value<int> pairedAtMillis,
      Value<int?> lastSeenAtMillis,
      Value<int> rowid,
    });

class $$PeerTrustTableFilterComposer
    extends Composer<_$HaLoDatabase, $PeerTrustTable> {
  $$PeerTrustTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pairedAtMillis => $composableBuilder(
    column: $table.pairedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAtMillis => $composableBuilder(
    column: $table.lastSeenAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerTrustTableOrderingComposer
    extends Composer<_$HaLoDatabase, $PeerTrustTable> {
  $$PeerTrustTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pairedAtMillis => $composableBuilder(
    column: $table.pairedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAtMillis => $composableBuilder(
    column: $table.lastSeenAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerTrustTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $PeerTrustTable> {
  $$PeerTrustTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get pairedAtMillis => $composableBuilder(
    column: $table.pairedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAtMillis => $composableBuilder(
    column: $table.lastSeenAtMillis,
    builder: (column) => column,
  );
}

class $$PeerTrustTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $PeerTrustTable,
          PeerTrustRow,
          $$PeerTrustTableFilterComposer,
          $$PeerTrustTableOrderingComposer,
          $$PeerTrustTableAnnotationComposer,
          $$PeerTrustTableCreateCompanionBuilder,
          $$PeerTrustTableUpdateCompanionBuilder,
          (
            PeerTrustRow,
            BaseReferences<_$HaLoDatabase, $PeerTrustTable, PeerTrustRow>,
          ),
          PeerTrustRow,
          PrefetchHooks Function()
        > {
  $$PeerTrustTableTableManager(_$HaLoDatabase db, $PeerTrustTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerTrustTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerTrustTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeerTrustTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> peerDeviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> pairedAtMillis = const Value.absent(),
                Value<int?> lastSeenAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerTrustCompanion(
                peerDeviceId: peerDeviceId,
                name: name,
                pairedAtMillis: pairedAtMillis,
                lastSeenAtMillis: lastSeenAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerDeviceId,
                required String name,
                required int pairedAtMillis,
                Value<int?> lastSeenAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerTrustCompanion.insert(
                peerDeviceId: peerDeviceId,
                name: name,
                pairedAtMillis: pairedAtMillis,
                lastSeenAtMillis: lastSeenAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerTrustTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $PeerTrustTable,
      PeerTrustRow,
      $$PeerTrustTableFilterComposer,
      $$PeerTrustTableOrderingComposer,
      $$PeerTrustTableAnnotationComposer,
      $$PeerTrustTableCreateCompanionBuilder,
      $$PeerTrustTableUpdateCompanionBuilder,
      (
        PeerTrustRow,
        BaseReferences<_$HaLoDatabase, $PeerTrustTable, PeerTrustRow>,
      ),
      PeerTrustRow,
      PrefetchHooks Function()
    >;
typedef $$ClaimsTableCreateCompanionBuilder =
    ClaimsCompanion Function({
      required String uuid,
      required String program,
      required String holder,
      Value<String> edition,
      required String ref,
      Value<String?> band,
      Value<String?> mode,
      required String source,
      required String level,
      Value<int?> atMillis,
      Value<String?> qso,
      Value<String> data,
      required int version,
      Value<int> epoch,
      Value<bool> deleted,
      Value<bool> synced,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });
typedef $$ClaimsTableUpdateCompanionBuilder =
    ClaimsCompanion Function({
      Value<String> uuid,
      Value<String> program,
      Value<String> holder,
      Value<String> edition,
      Value<String> ref,
      Value<String?> band,
      Value<String?> mode,
      Value<String> source,
      Value<String> level,
      Value<int?> atMillis,
      Value<String?> qso,
      Value<String> data,
      Value<int> version,
      Value<int> epoch,
      Value<bool> deleted,
      Value<bool> synced,
      Value<int?> updatedAtMillis,
      Value<int> rowid,
    });

class $$ClaimsTableFilterComposer
    extends Composer<_$HaLoDatabase, $ClaimsTable> {
  $$ClaimsTableFilterComposer({
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

  ColumnFilters<String> get program => $composableBuilder(
    column: $table.program,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holder => $composableBuilder(
    column: $table.holder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMillis => $composableBuilder(
    column: $table.atMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qso => $composableBuilder(
    column: $table.qso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epoch => $composableBuilder(
    column: $table.epoch,
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

class $$ClaimsTableOrderingComposer
    extends Composer<_$HaLoDatabase, $ClaimsTable> {
  $$ClaimsTableOrderingComposer({
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

  ColumnOrderings<String> get program => $composableBuilder(
    column: $table.program,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holder => $composableBuilder(
    column: $table.holder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMillis => $composableBuilder(
    column: $table.atMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qso => $composableBuilder(
    column: $table.qso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epoch => $composableBuilder(
    column: $table.epoch,
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

class $$ClaimsTableAnnotationComposer
    extends Composer<_$HaLoDatabase, $ClaimsTable> {
  $$ClaimsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get program =>
      $composableBuilder(column: $table.program, builder: (column) => column);

  GeneratedColumn<String> get holder =>
      $composableBuilder(column: $table.holder, builder: (column) => column);

  GeneratedColumn<String> get edition =>
      $composableBuilder(column: $table.edition, builder: (column) => column);

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<String> get band =>
      $composableBuilder(column: $table.band, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get atMillis =>
      $composableBuilder(column: $table.atMillis, builder: (column) => column);

  GeneratedColumn<String> get qso =>
      $composableBuilder(column: $table.qso, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get epoch =>
      $composableBuilder(column: $table.epoch, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$ClaimsTableTableManager
    extends
        RootTableManager<
          _$HaLoDatabase,
          $ClaimsTable,
          ClaimRow,
          $$ClaimsTableFilterComposer,
          $$ClaimsTableOrderingComposer,
          $$ClaimsTableAnnotationComposer,
          $$ClaimsTableCreateCompanionBuilder,
          $$ClaimsTableUpdateCompanionBuilder,
          (ClaimRow, BaseReferences<_$HaLoDatabase, $ClaimsTable, ClaimRow>),
          ClaimRow,
          PrefetchHooks Function()
        > {
  $$ClaimsTableTableManager(_$HaLoDatabase db, $ClaimsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaimsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaimsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaimsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> program = const Value.absent(),
                Value<String> holder = const Value.absent(),
                Value<String> edition = const Value.absent(),
                Value<String> ref = const Value.absent(),
                Value<String?> band = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<int?> atMillis = const Value.absent(),
                Value<String?> qso = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> epoch = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimsCompanion(
                uuid: uuid,
                program: program,
                holder: holder,
                edition: edition,
                ref: ref,
                band: band,
                mode: mode,
                source: source,
                level: level,
                atMillis: atMillis,
                qso: qso,
                data: data,
                version: version,
                epoch: epoch,
                deleted: deleted,
                synced: synced,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String program,
                required String holder,
                Value<String> edition = const Value.absent(),
                required String ref,
                Value<String?> band = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                required String source,
                required String level,
                Value<int?> atMillis = const Value.absent(),
                Value<String?> qso = const Value.absent(),
                Value<String> data = const Value.absent(),
                required int version,
                Value<int> epoch = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int?> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimsCompanion.insert(
                uuid: uuid,
                program: program,
                holder: holder,
                edition: edition,
                ref: ref,
                band: band,
                mode: mode,
                source: source,
                level: level,
                atMillis: atMillis,
                qso: qso,
                data: data,
                version: version,
                epoch: epoch,
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

typedef $$ClaimsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaLoDatabase,
      $ClaimsTable,
      ClaimRow,
      $$ClaimsTableFilterComposer,
      $$ClaimsTableOrderingComposer,
      $$ClaimsTableAnnotationComposer,
      $$ClaimsTableCreateCompanionBuilder,
      $$ClaimsTableUpdateCompanionBuilder,
      (ClaimRow, BaseReferences<_$HaLoDatabase, $ClaimsTable, ClaimRow>),
      ClaimRow,
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
  $$InboundCapturesTableTableManager get inboundCaptures =>
      $$InboundCapturesTableTableManager(_db, _db.inboundCaptures);
  $$PeerEventsTableTableManager get peerEvents =>
      $$PeerEventsTableTableManager(_db, _db.peerEvents);
  $$PeerCursorsTableTableManager get peerCursors =>
      $$PeerCursorsTableTableManager(_db, _db.peerCursors);
  $$PeerTrustTableTableManager get peerTrust =>
      $$PeerTrustTableTableManager(_db, _db.peerTrust);
  $$ClaimsTableTableManager get claims =>
      $$ClaimsTableTableManager(_db, _db.claims);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevisionMeta = const VerificationMeta(
    'localRevision',
  );
  @override
  late final GeneratedColumn<int> localRevision = GeneratedColumn<int>(
    'local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _acknowledgedRevisionMeta =
      const VerificationMeta('acknowledgedRevision');
  @override
  late final GeneratedColumn<int> acknowledgedRevision = GeneratedColumn<int>(
    'acknowledged_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    localRevision,
    acknowledgedRevision,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_revision')) {
      context.handle(
        _localRevisionMeta,
        localRevision.isAcceptableOrUnknown(
          data['local_revision']!,
          _localRevisionMeta,
        ),
      );
    }
    if (data.containsKey('acknowledged_revision')) {
      context.handle(
        _acknowledgedRevisionMeta,
        acknowledgedRevision.isAcceptableOrUnknown(
          data['acknowledged_revision']!,
          _acknowledgedRevisionMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      localRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision'],
      )!,
      acknowledgedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acknowledged_revision'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  /// UUID generated by the DAO.
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Monotonic local version used by backup sync.
  final int localRevision;

  /// Highest [localRevision] confirmed by cloud backup (`0` means never backed up).
  final int acknowledgedRevision;
  final DateTime? syncedAt;
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRevision,
    required this.acknowledgedRevision,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['local_revision'] = Variable<int>(localRevision);
    map['acknowledged_revision'] = Variable<int>(acknowledgedRevision);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRevision: Value(localRevision),
      acknowledgedRevision: Value(acknowledgedRevision),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      localRevision: serializer.fromJson<int>(json['localRevision']),
      acknowledgedRevision: serializer.fromJson<int>(
        json['acknowledgedRevision'],
      ),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'localRevision': serializer.toJson<int>(localRevision),
      'acknowledgedRevision': serializer.toJson<int>(acknowledgedRevision),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? localRevision,
    int? acknowledgedRevision,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRevision: localRevision ?? this.localRevision,
    acknowledgedRevision: acknowledgedRevision ?? this.acknowledgedRevision,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRevision: data.localRevision.present
          ? data.localRevision.value
          : this.localRevision,
      acknowledgedRevision: data.acknowledgedRevision.present
          ? data.acknowledgedRevision.value
          : this.acknowledgedRevision,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRevision: $localRevision, ')
          ..write('acknowledgedRevision: $acknowledgedRevision, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    localRevision,
    acknowledgedRevision,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRevision == this.localRevision &&
          other.acknowledgedRevision == this.acknowledgedRevision &&
          other.syncedAt == this.syncedAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> localRevision;
  final Value<int> acknowledgedRevision;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.acknowledgedRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.acknowledgedRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? localRevision,
    Expression<int>? acknowledgedRevision,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRevision != null) 'local_revision': localRevision,
      if (acknowledgedRevision != null)
        'acknowledged_revision': acknowledgedRevision,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? localRevision,
    Value<int>? acknowledgedRevision,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRevision: localRevision ?? this.localRevision,
      acknowledgedRevision: acknowledgedRevision ?? this.acknowledgedRevision,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (localRevision.present) {
      map['local_revision'] = Variable<int>(localRevision.value);
    }
    if (acknowledgedRevision.present) {
      map['acknowledged_revision'] = Variable<int>(acknowledgedRevision.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRevision: $localRevision, ')
          ..write('acknowledgedRevision: $acknowledgedRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES customers (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPiastersMeta = const VerificationMeta(
    'amountPiasters',
  );
  @override
  late final GeneratedColumn<int> amountPiasters = GeneratedColumn<int>(
    'amount_piasters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  @override
  late final GeneratedColumn<DateTime> transactionDate =
      GeneratedColumn<DateTime>(
        'transaction_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevisionMeta = const VerificationMeta(
    'localRevision',
  );
  @override
  late final GeneratedColumn<int> localRevision = GeneratedColumn<int>(
    'local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _acknowledgedRevisionMeta =
      const VerificationMeta('acknowledgedRevision');
  @override
  late final GeneratedColumn<int> acknowledgedRevision = GeneratedColumn<int>(
    'acknowledged_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    type,
    amountPiasters,
    note,
    transactionDate,
    createdAt,
    updatedAt,
    deletedAt,
    localRevision,
    acknowledgedRevision,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_piasters')) {
      context.handle(
        _amountPiastersMeta,
        amountPiasters.isAcceptableOrUnknown(
          data['amount_piasters']!,
          _amountPiastersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPiastersMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('local_revision')) {
      context.handle(
        _localRevisionMeta,
        localRevision.isAcceptableOrUnknown(
          data['local_revision']!,
          _localRevisionMeta,
        ),
      );
    }
    if (data.containsKey('acknowledged_revision')) {
      context.handle(
        _acknowledgedRevisionMeta,
        acknowledgedRevision.isAcceptableOrUnknown(
          data['acknowledged_revision']!,
          _acknowledgedRevisionMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountPiasters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_piasters'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transaction_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      localRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision'],
      )!,
      acknowledgedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acknowledged_revision'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class TransactionRecord extends DataClass
    implements Insertable<TransactionRecord> {
  /// UUID generated by the DAO.
  final String id;
  final String customerId;
  final String type;
  final int amountPiasters;
  final String? note;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Monotonic local version used by backup sync.
  final int localRevision;

  /// Highest [localRevision] confirmed by cloud backup (`0` means never backed up).
  final int acknowledgedRevision;
  final DateTime? syncedAt;
  const TransactionRecord({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountPiasters,
    this.note,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.localRevision,
    required this.acknowledgedRevision,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    map['type'] = Variable<String>(type);
    map['amount_piasters'] = Variable<int>(amountPiasters);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['transaction_date'] = Variable<DateTime>(transactionDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['local_revision'] = Variable<int>(localRevision);
    map['acknowledged_revision'] = Variable<int>(acknowledgedRevision);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      customerId: Value(customerId),
      type: Value(type),
      amountPiasters: Value(amountPiasters),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      transactionDate: Value(transactionDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localRevision: Value(localRevision),
      acknowledgedRevision: Value(acknowledgedRevision),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory TransactionRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRecord(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      type: serializer.fromJson<String>(json['type']),
      amountPiasters: serializer.fromJson<int>(json['amountPiasters']),
      note: serializer.fromJson<String?>(json['note']),
      transactionDate: serializer.fromJson<DateTime>(json['transactionDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      localRevision: serializer.fromJson<int>(json['localRevision']),
      acknowledgedRevision: serializer.fromJson<int>(
        json['acknowledgedRevision'],
      ),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'type': serializer.toJson<String>(type),
      'amountPiasters': serializer.toJson<int>(amountPiasters),
      'note': serializer.toJson<String?>(note),
      'transactionDate': serializer.toJson<DateTime>(transactionDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'localRevision': serializer.toJson<int>(localRevision),
      'acknowledgedRevision': serializer.toJson<int>(acknowledgedRevision),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  TransactionRecord copyWith({
    String? id,
    String? customerId,
    String? type,
    int? amountPiasters,
    Value<String?> note = const Value.absent(),
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? localRevision,
    int? acknowledgedRevision,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => TransactionRecord(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    type: type ?? this.type,
    amountPiasters: amountPiasters ?? this.amountPiasters,
    note: note.present ? note.value : this.note,
    transactionDate: transactionDate ?? this.transactionDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    localRevision: localRevision ?? this.localRevision,
    acknowledgedRevision: acknowledgedRevision ?? this.acknowledgedRevision,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  TransactionRecord copyWithCompanion(TransactionsCompanion data) {
    return TransactionRecord(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      type: data.type.present ? data.type.value : this.type,
      amountPiasters: data.amountPiasters.present
          ? data.amountPiasters.value
          : this.amountPiasters,
      note: data.note.present ? data.note.value : this.note,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localRevision: data.localRevision.present
          ? data.localRevision.value
          : this.localRevision,
      acknowledgedRevision: data.acknowledgedRevision.present
          ? data.acknowledgedRevision.value
          : this.acknowledgedRevision,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRecord(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('type: $type, ')
          ..write('amountPiasters: $amountPiasters, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRevision: $localRevision, ')
          ..write('acknowledgedRevision: $acknowledgedRevision, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    type,
    amountPiasters,
    note,
    transactionDate,
    createdAt,
    updatedAt,
    deletedAt,
    localRevision,
    acknowledgedRevision,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRecord &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.type == this.type &&
          other.amountPiasters == this.amountPiasters &&
          other.note == this.note &&
          other.transactionDate == this.transactionDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localRevision == this.localRevision &&
          other.acknowledgedRevision == this.acknowledgedRevision &&
          other.syncedAt == this.syncedAt);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRecord> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<String> type;
  final Value<int> amountPiasters;
  final Value<String?> note;
  final Value<DateTime> transactionDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> localRevision;
  final Value<int> acknowledgedRevision;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountPiasters = const Value.absent(),
    this.note = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.acknowledgedRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String customerId,
    required String type,
    required int amountPiasters,
    this.note = const Value.absent(),
    required DateTime transactionDate,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.acknowledgedRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       type = Value(type),
       amountPiasters = Value(amountPiasters),
       transactionDate = Value(transactionDate);
  static Insertable<TransactionRecord> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? type,
    Expression<int>? amountPiasters,
    Expression<String>? note,
    Expression<DateTime>? transactionDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? localRevision,
    Expression<int>? acknowledgedRevision,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (type != null) 'type': type,
      if (amountPiasters != null) 'amount_piasters': amountPiasters,
      if (note != null) 'note': note,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localRevision != null) 'local_revision': localRevision,
      if (acknowledgedRevision != null)
        'acknowledged_revision': acknowledgedRevision,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<String>? type,
    Value<int>? amountPiasters,
    Value<String?>? note,
    Value<DateTime>? transactionDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? localRevision,
    Value<int>? acknowledgedRevision,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      amountPiasters: amountPiasters ?? this.amountPiasters,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localRevision: localRevision ?? this.localRevision,
      acknowledgedRevision: acknowledgedRevision ?? this.acknowledgedRevision,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountPiasters.present) {
      map['amount_piasters'] = Variable<int>(amountPiasters.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<DateTime>(transactionDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (localRevision.present) {
      map['local_revision'] = Variable<int>(localRevision.value);
    }
    if (acknowledgedRevision.present) {
      map['acknowledged_revision'] = Variable<int>(acknowledgedRevision.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('type: $type, ')
          ..write('amountPiasters: $amountPiasters, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localRevision: $localRevision, ')
          ..write('acknowledgedRevision: $acknowledgedRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionAuditLogsTable extends TransactionAuditLogs
    with TableInfo<$TransactionAuditLogsTable, TransactionAuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionAuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousTypeMeta = const VerificationMeta(
    'previousType',
  );
  @override
  late final GeneratedColumn<String> previousType = GeneratedColumn<String>(
    'previous_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousAmountPiastersMeta =
      const VerificationMeta('previousAmountPiasters');
  @override
  late final GeneratedColumn<int> previousAmountPiasters = GeneratedColumn<int>(
    'previous_amount_piasters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousNoteMeta = const VerificationMeta(
    'previousNote',
  );
  @override
  late final GeneratedColumn<String> previousNote = GeneratedColumn<String>(
    'previous_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previousTransactionDateMeta =
      const VerificationMeta('previousTransactionDate');
  @override
  late final GeneratedColumn<DateTime> previousTransactionDate =
      GeneratedColumn<DateTime>(
        'previous_transaction_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _localRevisionMeta = const VerificationMeta(
    'localRevision',
  );
  @override
  late final GeneratedColumn<int> localRevision = GeneratedColumn<int>(
    'local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _acknowledgedRevisionMeta =
      const VerificationMeta('acknowledgedRevision');
  @override
  late final GeneratedColumn<int> acknowledgedRevision = GeneratedColumn<int>(
    'acknowledged_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    action,
    previousType,
    previousAmountPiasters,
    previousNote,
    previousTransactionDate,
    createdAt,
    localRevision,
    acknowledgedRevision,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionAuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('previous_type')) {
      context.handle(
        _previousTypeMeta,
        previousType.isAcceptableOrUnknown(
          data['previous_type']!,
          _previousTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousTypeMeta);
    }
    if (data.containsKey('previous_amount_piasters')) {
      context.handle(
        _previousAmountPiastersMeta,
        previousAmountPiasters.isAcceptableOrUnknown(
          data['previous_amount_piasters']!,
          _previousAmountPiastersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousAmountPiastersMeta);
    }
    if (data.containsKey('previous_note')) {
      context.handle(
        _previousNoteMeta,
        previousNote.isAcceptableOrUnknown(
          data['previous_note']!,
          _previousNoteMeta,
        ),
      );
    }
    if (data.containsKey('previous_transaction_date')) {
      context.handle(
        _previousTransactionDateMeta,
        previousTransactionDate.isAcceptableOrUnknown(
          data['previous_transaction_date']!,
          _previousTransactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousTransactionDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('local_revision')) {
      context.handle(
        _localRevisionMeta,
        localRevision.isAcceptableOrUnknown(
          data['local_revision']!,
          _localRevisionMeta,
        ),
      );
    }
    if (data.containsKey('acknowledged_revision')) {
      context.handle(
        _acknowledgedRevisionMeta,
        acknowledgedRevision.isAcceptableOrUnknown(
          data['acknowledged_revision']!,
          _acknowledgedRevisionMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionAuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionAuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      previousType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_type'],
      )!,
      previousAmountPiasters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}previous_amount_piasters'],
      )!,
      previousNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_note'],
      ),
      previousTransactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}previous_transaction_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      localRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision'],
      )!,
      acknowledgedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acknowledged_revision'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $TransactionAuditLogsTable createAlias(String alias) {
    return $TransactionAuditLogsTable(attachedDatabase, alias);
  }
}

class TransactionAuditLog extends DataClass
    implements Insertable<TransactionAuditLog> {
  /// UUID generated by the DAO.
  final String id;
  final String transactionId;
  final String action;
  final String previousType;
  final int previousAmountPiasters;
  final String? previousNote;
  final DateTime previousTransactionDate;
  final DateTime createdAt;

  /// Monotonic local version used by backup sync.
  final int localRevision;

  /// Highest [localRevision] confirmed by cloud backup (`0` means never backed up).
  final int acknowledgedRevision;
  final DateTime? syncedAt;
  const TransactionAuditLog({
    required this.id,
    required this.transactionId,
    required this.action,
    required this.previousType,
    required this.previousAmountPiasters,
    this.previousNote,
    required this.previousTransactionDate,
    required this.createdAt,
    required this.localRevision,
    required this.acknowledgedRevision,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transaction_id'] = Variable<String>(transactionId);
    map['action'] = Variable<String>(action);
    map['previous_type'] = Variable<String>(previousType);
    map['previous_amount_piasters'] = Variable<int>(previousAmountPiasters);
    if (!nullToAbsent || previousNote != null) {
      map['previous_note'] = Variable<String>(previousNote);
    }
    map['previous_transaction_date'] = Variable<DateTime>(
      previousTransactionDate,
    );
    map['created_at'] = Variable<DateTime>(createdAt);
    map['local_revision'] = Variable<int>(localRevision);
    map['acknowledged_revision'] = Variable<int>(acknowledgedRevision);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  TransactionAuditLogsCompanion toCompanion(bool nullToAbsent) {
    return TransactionAuditLogsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      action: Value(action),
      previousType: Value(previousType),
      previousAmountPiasters: Value(previousAmountPiasters),
      previousNote: previousNote == null && nullToAbsent
          ? const Value.absent()
          : Value(previousNote),
      previousTransactionDate: Value(previousTransactionDate),
      createdAt: Value(createdAt),
      localRevision: Value(localRevision),
      acknowledgedRevision: Value(acknowledgedRevision),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory TransactionAuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionAuditLog(
      id: serializer.fromJson<String>(json['id']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      action: serializer.fromJson<String>(json['action']),
      previousType: serializer.fromJson<String>(json['previousType']),
      previousAmountPiasters: serializer.fromJson<int>(
        json['previousAmountPiasters'],
      ),
      previousNote: serializer.fromJson<String?>(json['previousNote']),
      previousTransactionDate: serializer.fromJson<DateTime>(
        json['previousTransactionDate'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      localRevision: serializer.fromJson<int>(json['localRevision']),
      acknowledgedRevision: serializer.fromJson<int>(
        json['acknowledgedRevision'],
      ),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transactionId': serializer.toJson<String>(transactionId),
      'action': serializer.toJson<String>(action),
      'previousType': serializer.toJson<String>(previousType),
      'previousAmountPiasters': serializer.toJson<int>(previousAmountPiasters),
      'previousNote': serializer.toJson<String?>(previousNote),
      'previousTransactionDate': serializer.toJson<DateTime>(
        previousTransactionDate,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'localRevision': serializer.toJson<int>(localRevision),
      'acknowledgedRevision': serializer.toJson<int>(acknowledgedRevision),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  TransactionAuditLog copyWith({
    String? id,
    String? transactionId,
    String? action,
    String? previousType,
    int? previousAmountPiasters,
    Value<String?> previousNote = const Value.absent(),
    DateTime? previousTransactionDate,
    DateTime? createdAt,
    int? localRevision,
    int? acknowledgedRevision,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => TransactionAuditLog(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    action: action ?? this.action,
    previousType: previousType ?? this.previousType,
    previousAmountPiasters:
        previousAmountPiasters ?? this.previousAmountPiasters,
    previousNote: previousNote.present ? previousNote.value : this.previousNote,
    previousTransactionDate:
        previousTransactionDate ?? this.previousTransactionDate,
    createdAt: createdAt ?? this.createdAt,
    localRevision: localRevision ?? this.localRevision,
    acknowledgedRevision: acknowledgedRevision ?? this.acknowledgedRevision,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  TransactionAuditLog copyWithCompanion(TransactionAuditLogsCompanion data) {
    return TransactionAuditLog(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      action: data.action.present ? data.action.value : this.action,
      previousType: data.previousType.present
          ? data.previousType.value
          : this.previousType,
      previousAmountPiasters: data.previousAmountPiasters.present
          ? data.previousAmountPiasters.value
          : this.previousAmountPiasters,
      previousNote: data.previousNote.present
          ? data.previousNote.value
          : this.previousNote,
      previousTransactionDate: data.previousTransactionDate.present
          ? data.previousTransactionDate.value
          : this.previousTransactionDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      localRevision: data.localRevision.present
          ? data.localRevision.value
          : this.localRevision,
      acknowledgedRevision: data.acknowledgedRevision.present
          ? data.acknowledgedRevision.value
          : this.acknowledgedRevision,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAuditLog(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('action: $action, ')
          ..write('previousType: $previousType, ')
          ..write('previousAmountPiasters: $previousAmountPiasters, ')
          ..write('previousNote: $previousNote, ')
          ..write('previousTransactionDate: $previousTransactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('localRevision: $localRevision, ')
          ..write('acknowledgedRevision: $acknowledgedRevision, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    action,
    previousType,
    previousAmountPiasters,
    previousNote,
    previousTransactionDate,
    createdAt,
    localRevision,
    acknowledgedRevision,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionAuditLog &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.action == this.action &&
          other.previousType == this.previousType &&
          other.previousAmountPiasters == this.previousAmountPiasters &&
          other.previousNote == this.previousNote &&
          other.previousTransactionDate == this.previousTransactionDate &&
          other.createdAt == this.createdAt &&
          other.localRevision == this.localRevision &&
          other.acknowledgedRevision == this.acknowledgedRevision &&
          other.syncedAt == this.syncedAt);
}

class TransactionAuditLogsCompanion
    extends UpdateCompanion<TransactionAuditLog> {
  final Value<String> id;
  final Value<String> transactionId;
  final Value<String> action;
  final Value<String> previousType;
  final Value<int> previousAmountPiasters;
  final Value<String?> previousNote;
  final Value<DateTime> previousTransactionDate;
  final Value<DateTime> createdAt;
  final Value<int> localRevision;
  final Value<int> acknowledgedRevision;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const TransactionAuditLogsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.action = const Value.absent(),
    this.previousType = const Value.absent(),
    this.previousAmountPiasters = const Value.absent(),
    this.previousNote = const Value.absent(),
    this.previousTransactionDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.acknowledgedRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionAuditLogsCompanion.insert({
    required String id,
    required String transactionId,
    required String action,
    required String previousType,
    required int previousAmountPiasters,
    this.previousNote = const Value.absent(),
    required DateTime previousTransactionDate,
    this.createdAt = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.acknowledgedRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transactionId = Value(transactionId),
       action = Value(action),
       previousType = Value(previousType),
       previousAmountPiasters = Value(previousAmountPiasters),
       previousTransactionDate = Value(previousTransactionDate);
  static Insertable<TransactionAuditLog> custom({
    Expression<String>? id,
    Expression<String>? transactionId,
    Expression<String>? action,
    Expression<String>? previousType,
    Expression<int>? previousAmountPiasters,
    Expression<String>? previousNote,
    Expression<DateTime>? previousTransactionDate,
    Expression<DateTime>? createdAt,
    Expression<int>? localRevision,
    Expression<int>? acknowledgedRevision,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (action != null) 'action': action,
      if (previousType != null) 'previous_type': previousType,
      if (previousAmountPiasters != null)
        'previous_amount_piasters': previousAmountPiasters,
      if (previousNote != null) 'previous_note': previousNote,
      if (previousTransactionDate != null)
        'previous_transaction_date': previousTransactionDate,
      if (createdAt != null) 'created_at': createdAt,
      if (localRevision != null) 'local_revision': localRevision,
      if (acknowledgedRevision != null)
        'acknowledged_revision': acknowledgedRevision,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionAuditLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? transactionId,
    Value<String>? action,
    Value<String>? previousType,
    Value<int>? previousAmountPiasters,
    Value<String?>? previousNote,
    Value<DateTime>? previousTransactionDate,
    Value<DateTime>? createdAt,
    Value<int>? localRevision,
    Value<int>? acknowledgedRevision,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return TransactionAuditLogsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      action: action ?? this.action,
      previousType: previousType ?? this.previousType,
      previousAmountPiasters:
          previousAmountPiasters ?? this.previousAmountPiasters,
      previousNote: previousNote ?? this.previousNote,
      previousTransactionDate:
          previousTransactionDate ?? this.previousTransactionDate,
      createdAt: createdAt ?? this.createdAt,
      localRevision: localRevision ?? this.localRevision,
      acknowledgedRevision: acknowledgedRevision ?? this.acknowledgedRevision,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (previousType.present) {
      map['previous_type'] = Variable<String>(previousType.value);
    }
    if (previousAmountPiasters.present) {
      map['previous_amount_piasters'] = Variable<int>(
        previousAmountPiasters.value,
      );
    }
    if (previousNote.present) {
      map['previous_note'] = Variable<String>(previousNote.value);
    }
    if (previousTransactionDate.present) {
      map['previous_transaction_date'] = Variable<DateTime>(
        previousTransactionDate.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (localRevision.present) {
      map['local_revision'] = Variable<int>(localRevision.value);
    }
    if (acknowledgedRevision.present) {
      map['acknowledged_revision'] = Variable<int>(acknowledgedRevision.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('action: $action, ')
          ..write('previousType: $previousType, ')
          ..write('previousAmountPiasters: $previousAmountPiasters, ')
          ..write('previousNote: $previousNote, ')
          ..write('previousTransactionDate: $previousTransactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('localRevision: $localRevision, ')
          ..write('acknowledgedRevision: $acknowledgedRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackupMetadataTable extends BackupMetadata
    with TableInfo<$BackupMetadataTable, BackupMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _scheduleMeta = const VerificationMeta(
    'schedule',
  );
  @override
  late final GeneratedColumn<String> schedule = GeneratedColumn<String>(
    'schedule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastConfirmedAtIsoMeta =
      const VerificationMeta('lastConfirmedAtIso');
  @override
  late final GeneratedColumn<String> lastConfirmedAtIso =
      GeneratedColumn<String>(
        'last_confirmed_at_iso',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextDueAtIsoMeta = const VerificationMeta(
    'nextDueAtIso',
  );
  @override
  late final GeneratedColumn<String> nextDueAtIso = GeneratedColumn<String>(
    'next_due_at_iso',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeviceActiveMeta = const VerificationMeta(
    'isDeviceActive',
  );
  @override
  late final GeneratedColumn<bool> isDeviceActive = GeneratedColumn<bool>(
    'is_device_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_device_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schedule,
    lastConfirmedAtIso,
    nextDueAtIso,
    isDeviceActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schedule')) {
      context.handle(
        _scheduleMeta,
        schedule.isAcceptableOrUnknown(data['schedule']!, _scheduleMeta),
      );
    }
    if (data.containsKey('last_confirmed_at_iso')) {
      context.handle(
        _lastConfirmedAtIsoMeta,
        lastConfirmedAtIso.isAcceptableOrUnknown(
          data['last_confirmed_at_iso']!,
          _lastConfirmedAtIsoMeta,
        ),
      );
    }
    if (data.containsKey('next_due_at_iso')) {
      context.handle(
        _nextDueAtIsoMeta,
        nextDueAtIso.isAcceptableOrUnknown(
          data['next_due_at_iso']!,
          _nextDueAtIsoMeta,
        ),
      );
    }
    if (data.containsKey('is_device_active')) {
      context.handle(
        _isDeviceActiveMeta,
        isDeviceActive.isAcceptableOrUnknown(
          data['is_device_active']!,
          _isDeviceActiveMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupMetadataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      schedule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule'],
      ),
      lastConfirmedAtIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_confirmed_at_iso'],
      ),
      nextDueAtIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_due_at_iso'],
      ),
      isDeviceActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_device_active'],
      )!,
    );
  }

  @override
  $BackupMetadataTable createAlias(String alias) {
    return $BackupMetadataTable(attachedDatabase, alias);
  }
}

class BackupMetadataRow extends DataClass
    implements Insertable<BackupMetadataRow> {
  final int id;
  final String? schedule;
  final String? lastConfirmedAtIso;
  final String? nextDueAtIso;
  final bool isDeviceActive;
  const BackupMetadataRow({
    required this.id,
    this.schedule,
    this.lastConfirmedAtIso,
    this.nextDueAtIso,
    required this.isDeviceActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || schedule != null) {
      map['schedule'] = Variable<String>(schedule);
    }
    if (!nullToAbsent || lastConfirmedAtIso != null) {
      map['last_confirmed_at_iso'] = Variable<String>(lastConfirmedAtIso);
    }
    if (!nullToAbsent || nextDueAtIso != null) {
      map['next_due_at_iso'] = Variable<String>(nextDueAtIso);
    }
    map['is_device_active'] = Variable<bool>(isDeviceActive);
    return map;
  }

  BackupMetadataCompanion toCompanion(bool nullToAbsent) {
    return BackupMetadataCompanion(
      id: Value(id),
      schedule: schedule == null && nullToAbsent
          ? const Value.absent()
          : Value(schedule),
      lastConfirmedAtIso: lastConfirmedAtIso == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConfirmedAtIso),
      nextDueAtIso: nextDueAtIso == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueAtIso),
      isDeviceActive: Value(isDeviceActive),
    );
  }

  factory BackupMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupMetadataRow(
      id: serializer.fromJson<int>(json['id']),
      schedule: serializer.fromJson<String?>(json['schedule']),
      lastConfirmedAtIso: serializer.fromJson<String?>(
        json['lastConfirmedAtIso'],
      ),
      nextDueAtIso: serializer.fromJson<String?>(json['nextDueAtIso']),
      isDeviceActive: serializer.fromJson<bool>(json['isDeviceActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'schedule': serializer.toJson<String?>(schedule),
      'lastConfirmedAtIso': serializer.toJson<String?>(lastConfirmedAtIso),
      'nextDueAtIso': serializer.toJson<String?>(nextDueAtIso),
      'isDeviceActive': serializer.toJson<bool>(isDeviceActive),
    };
  }

  BackupMetadataRow copyWith({
    int? id,
    Value<String?> schedule = const Value.absent(),
    Value<String?> lastConfirmedAtIso = const Value.absent(),
    Value<String?> nextDueAtIso = const Value.absent(),
    bool? isDeviceActive,
  }) => BackupMetadataRow(
    id: id ?? this.id,
    schedule: schedule.present ? schedule.value : this.schedule,
    lastConfirmedAtIso: lastConfirmedAtIso.present
        ? lastConfirmedAtIso.value
        : this.lastConfirmedAtIso,
    nextDueAtIso: nextDueAtIso.present ? nextDueAtIso.value : this.nextDueAtIso,
    isDeviceActive: isDeviceActive ?? this.isDeviceActive,
  );
  BackupMetadataRow copyWithCompanion(BackupMetadataCompanion data) {
    return BackupMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      schedule: data.schedule.present ? data.schedule.value : this.schedule,
      lastConfirmedAtIso: data.lastConfirmedAtIso.present
          ? data.lastConfirmedAtIso.value
          : this.lastConfirmedAtIso,
      nextDueAtIso: data.nextDueAtIso.present
          ? data.nextDueAtIso.value
          : this.nextDueAtIso,
      isDeviceActive: data.isDeviceActive.present
          ? data.isDeviceActive.value
          : this.isDeviceActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupMetadataRow(')
          ..write('id: $id, ')
          ..write('schedule: $schedule, ')
          ..write('lastConfirmedAtIso: $lastConfirmedAtIso, ')
          ..write('nextDueAtIso: $nextDueAtIso, ')
          ..write('isDeviceActive: $isDeviceActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schedule,
    lastConfirmedAtIso,
    nextDueAtIso,
    isDeviceActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupMetadataRow &&
          other.id == this.id &&
          other.schedule == this.schedule &&
          other.lastConfirmedAtIso == this.lastConfirmedAtIso &&
          other.nextDueAtIso == this.nextDueAtIso &&
          other.isDeviceActive == this.isDeviceActive);
}

class BackupMetadataCompanion extends UpdateCompanion<BackupMetadataRow> {
  final Value<int> id;
  final Value<String?> schedule;
  final Value<String?> lastConfirmedAtIso;
  final Value<String?> nextDueAtIso;
  final Value<bool> isDeviceActive;
  const BackupMetadataCompanion({
    this.id = const Value.absent(),
    this.schedule = const Value.absent(),
    this.lastConfirmedAtIso = const Value.absent(),
    this.nextDueAtIso = const Value.absent(),
    this.isDeviceActive = const Value.absent(),
  });
  BackupMetadataCompanion.insert({
    this.id = const Value.absent(),
    this.schedule = const Value.absent(),
    this.lastConfirmedAtIso = const Value.absent(),
    this.nextDueAtIso = const Value.absent(),
    this.isDeviceActive = const Value.absent(),
  });
  static Insertable<BackupMetadataRow> custom({
    Expression<int>? id,
    Expression<String>? schedule,
    Expression<String>? lastConfirmedAtIso,
    Expression<String>? nextDueAtIso,
    Expression<bool>? isDeviceActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schedule != null) 'schedule': schedule,
      if (lastConfirmedAtIso != null)
        'last_confirmed_at_iso': lastConfirmedAtIso,
      if (nextDueAtIso != null) 'next_due_at_iso': nextDueAtIso,
      if (isDeviceActive != null) 'is_device_active': isDeviceActive,
    });
  }

  BackupMetadataCompanion copyWith({
    Value<int>? id,
    Value<String?>? schedule,
    Value<String?>? lastConfirmedAtIso,
    Value<String?>? nextDueAtIso,
    Value<bool>? isDeviceActive,
  }) {
    return BackupMetadataCompanion(
      id: id ?? this.id,
      schedule: schedule ?? this.schedule,
      lastConfirmedAtIso: lastConfirmedAtIso ?? this.lastConfirmedAtIso,
      nextDueAtIso: nextDueAtIso ?? this.nextDueAtIso,
      isDeviceActive: isDeviceActive ?? this.isDeviceActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (schedule.present) {
      map['schedule'] = Variable<String>(schedule.value);
    }
    if (lastConfirmedAtIso.present) {
      map['last_confirmed_at_iso'] = Variable<String>(lastConfirmedAtIso.value);
    }
    if (nextDueAtIso.present) {
      map['next_due_at_iso'] = Variable<String>(nextDueAtIso.value);
    }
    if (isDeviceActive.present) {
      map['is_device_active'] = Variable<bool>(isDeviceActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupMetadataCompanion(')
          ..write('id: $id, ')
          ..write('schedule: $schedule, ')
          ..write('lastConfirmedAtIso: $lastConfirmedAtIso, ')
          ..write('nextDueAtIso: $nextDueAtIso, ')
          ..write('isDeviceActive: $isDeviceActive')
          ..write(')'))
        .toString();
  }
}

class $BackupInFlightBatchesTable extends BackupInFlightBatches
    with TableInfo<$BackupInFlightBatchesTable, BackupInFlightBatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupInFlightBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtIsoMeta = const VerificationMeta(
    'capturedAtIso',
  );
  @override
  late final GeneratedColumn<String> capturedAtIso = GeneratedColumn<String>(
    'captured_at_iso',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    batchId,
    ownerUserId,
    deviceId,
    capturedAtIso,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_in_flight_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupInFlightBatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('captured_at_iso')) {
      context.handle(
        _capturedAtIsoMeta,
        capturedAtIso.isAcceptableOrUnknown(
          data['captured_at_iso']!,
          _capturedAtIsoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtIsoMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupInFlightBatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupInFlightBatchRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      capturedAtIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_at_iso'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
    );
  }

  @override
  $BackupInFlightBatchesTable createAlias(String alias) {
    return $BackupInFlightBatchesTable(attachedDatabase, alias);
  }
}

class BackupInFlightBatchRow extends DataClass
    implements Insertable<BackupInFlightBatchRow> {
  final int id;
  final String batchId;
  final String ownerUserId;
  final String deviceId;
  final String capturedAtIso;
  final String payloadJson;
  const BackupInFlightBatchRow({
    required this.id,
    required this.batchId,
    required this.ownerUserId,
    required this.deviceId,
    required this.capturedAtIso,
    required this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['batch_id'] = Variable<String>(batchId);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['device_id'] = Variable<String>(deviceId);
    map['captured_at_iso'] = Variable<String>(capturedAtIso);
    map['payload_json'] = Variable<String>(payloadJson);
    return map;
  }

  BackupInFlightBatchesCompanion toCompanion(bool nullToAbsent) {
    return BackupInFlightBatchesCompanion(
      id: Value(id),
      batchId: Value(batchId),
      ownerUserId: Value(ownerUserId),
      deviceId: Value(deviceId),
      capturedAtIso: Value(capturedAtIso),
      payloadJson: Value(payloadJson),
    );
  }

  factory BackupInFlightBatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupInFlightBatchRow(
      id: serializer.fromJson<int>(json['id']),
      batchId: serializer.fromJson<String>(json['batchId']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      capturedAtIso: serializer.fromJson<String>(json['capturedAtIso']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'batchId': serializer.toJson<String>(batchId),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'deviceId': serializer.toJson<String>(deviceId),
      'capturedAtIso': serializer.toJson<String>(capturedAtIso),
      'payloadJson': serializer.toJson<String>(payloadJson),
    };
  }

  BackupInFlightBatchRow copyWith({
    int? id,
    String? batchId,
    String? ownerUserId,
    String? deviceId,
    String? capturedAtIso,
    String? payloadJson,
  }) => BackupInFlightBatchRow(
    id: id ?? this.id,
    batchId: batchId ?? this.batchId,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    deviceId: deviceId ?? this.deviceId,
    capturedAtIso: capturedAtIso ?? this.capturedAtIso,
    payloadJson: payloadJson ?? this.payloadJson,
  );
  BackupInFlightBatchRow copyWithCompanion(
    BackupInFlightBatchesCompanion data,
  ) {
    return BackupInFlightBatchRow(
      id: data.id.present ? data.id.value : this.id,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      capturedAtIso: data.capturedAtIso.present
          ? data.capturedAtIso.value
          : this.capturedAtIso,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupInFlightBatchRow(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtIso: $capturedAtIso, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    batchId,
    ownerUserId,
    deviceId,
    capturedAtIso,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupInFlightBatchRow &&
          other.id == this.id &&
          other.batchId == this.batchId &&
          other.ownerUserId == this.ownerUserId &&
          other.deviceId == this.deviceId &&
          other.capturedAtIso == this.capturedAtIso &&
          other.payloadJson == this.payloadJson);
}

class BackupInFlightBatchesCompanion
    extends UpdateCompanion<BackupInFlightBatchRow> {
  final Value<int> id;
  final Value<String> batchId;
  final Value<String> ownerUserId;
  final Value<String> deviceId;
  final Value<String> capturedAtIso;
  final Value<String> payloadJson;
  const BackupInFlightBatchesCompanion({
    this.id = const Value.absent(),
    this.batchId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capturedAtIso = const Value.absent(),
    this.payloadJson = const Value.absent(),
  });
  BackupInFlightBatchesCompanion.insert({
    this.id = const Value.absent(),
    required String batchId,
    required String ownerUserId,
    required String deviceId,
    required String capturedAtIso,
    required String payloadJson,
  }) : batchId = Value(batchId),
       ownerUserId = Value(ownerUserId),
       deviceId = Value(deviceId),
       capturedAtIso = Value(capturedAtIso),
       payloadJson = Value(payloadJson);
  static Insertable<BackupInFlightBatchRow> custom({
    Expression<int>? id,
    Expression<String>? batchId,
    Expression<String>? ownerUserId,
    Expression<String>? deviceId,
    Expression<String>? capturedAtIso,
    Expression<String>? payloadJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (batchId != null) 'batch_id': batchId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (deviceId != null) 'device_id': deviceId,
      if (capturedAtIso != null) 'captured_at_iso': capturedAtIso,
      if (payloadJson != null) 'payload_json': payloadJson,
    });
  }

  BackupInFlightBatchesCompanion copyWith({
    Value<int>? id,
    Value<String>? batchId,
    Value<String>? ownerUserId,
    Value<String>? deviceId,
    Value<String>? capturedAtIso,
    Value<String>? payloadJson,
  }) {
    return BackupInFlightBatchesCompanion(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      deviceId: deviceId ?? this.deviceId,
      capturedAtIso: capturedAtIso ?? this.capturedAtIso,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (capturedAtIso.present) {
      map['captured_at_iso'] = Variable<String>(capturedAtIso.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupInFlightBatchesCompanion(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtIso: $capturedAtIso, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }
}

class $BackupDeviceIdentitiesTable extends BackupDeviceIdentities
    with TableInfo<$BackupDeviceIdentitiesTable, BackupDeviceIdentityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupDeviceIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, deviceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_device_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupDeviceIdentityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupDeviceIdentityRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupDeviceIdentityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $BackupDeviceIdentitiesTable createAlias(String alias) {
    return $BackupDeviceIdentitiesTable(attachedDatabase, alias);
  }
}

class BackupDeviceIdentityRow extends DataClass
    implements Insertable<BackupDeviceIdentityRow> {
  final int id;
  final String deviceId;
  const BackupDeviceIdentityRow({required this.id, required this.deviceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  BackupDeviceIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return BackupDeviceIdentitiesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
    );
  }

  factory BackupDeviceIdentityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupDeviceIdentityRow(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  BackupDeviceIdentityRow copyWith({int? id, String? deviceId}) =>
      BackupDeviceIdentityRow(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
      );
  BackupDeviceIdentityRow copyWithCompanion(
    BackupDeviceIdentitiesCompanion data,
  ) {
    return BackupDeviceIdentityRow(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupDeviceIdentityRow(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupDeviceIdentityRow &&
          other.id == this.id &&
          other.deviceId == this.deviceId);
}

class BackupDeviceIdentitiesCompanion
    extends UpdateCompanion<BackupDeviceIdentityRow> {
  final Value<int> id;
  final Value<String> deviceId;
  const BackupDeviceIdentitiesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  BackupDeviceIdentitiesCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
  }) : deviceId = Value(deviceId);
  static Insertable<BackupDeviceIdentityRow> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  BackupDeviceIdentitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
  }) {
    return BackupDeviceIdentitiesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupDeviceIdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $TransactionAuditLogsTable transactionAuditLogs =
      $TransactionAuditLogsTable(this);
  late final $BackupMetadataTable backupMetadata = $BackupMetadataTable(this);
  late final $BackupInFlightBatchesTable backupInFlightBatches =
      $BackupInFlightBatchesTable(this);
  late final $BackupDeviceIdentitiesTable backupDeviceIdentities =
      $BackupDeviceIdentitiesTable(this);
  late final Index idxCustomersDeletedAt = Index(
    'idx_customers_deleted_at',
    'CREATE INDEX idx_customers_deleted_at ON customers (deleted_at)',
  );
  late final Index idxCustomersName = Index(
    'idx_customers_name',
    'CREATE INDEX idx_customers_name ON customers (name)',
  );
  late final Index idxTransactionsCustomerId = Index(
    'idx_transactions_customer_id',
    'CREATE INDEX idx_transactions_customer_id ON transactions (customer_id)',
  );
  late final Index idxTransactionsDeletedAt = Index(
    'idx_transactions_deleted_at',
    'CREATE INDEX idx_transactions_deleted_at ON transactions (deleted_at)',
  );
  late final Index idxTransactionsTransactionDate = Index(
    'idx_transactions_transaction_date',
    'CREATE INDEX idx_transactions_transaction_date ON transactions (transaction_date)',
  );
  late final Index idxTransactionsCustomerDeleted = Index(
    'idx_transactions_customer_deleted',
    'CREATE INDEX idx_transactions_customer_deleted ON transactions (customer_id, deleted_at)',
  );
  late final Index idxTransactionAuditLogsTransactionId = Index(
    'idx_transaction_audit_logs_transaction_id',
    'CREATE INDEX idx_transaction_audit_logs_transaction_id ON transaction_audit_logs (transaction_id)',
  );
  late final CustomerDao customerDao = CustomerDao(this as AppDatabase);
  late final TransactionDao transactionDao = TransactionDao(
    this as AppDatabase,
  );
  late final BackupDao backupDao = BackupDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    customers,
    transactions,
    transactionAuditLogs,
    backupMetadata,
    backupInFlightBatches,
    backupDeviceIdentities,
    idxCustomersDeletedAt,
    idxCustomersName,
    idxTransactionsCustomerId,
    idxTransactionsDeletedAt,
    idxTransactionsTransactionDate,
    idxTransactionsCustomerDeleted,
    idxTransactionAuditLogsTransactionId,
  ];
}

typedef $$CustomersTableCreateCompanionBuilder = CustomersCompanion Function({
  required String id,
  required String name,
  Value<String?> phone,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> localRevision,
  Value<int> acknowledgedRevision,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$CustomersTableUpdateCompanionBuilder = CustomersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> phone,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> localRevision,
  Value<int> acknowledgedRevision,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

final class $$CustomersTableReferences
    extends BaseReferences<_$AppDatabase, $CustomersTable, Customer> {
  $$CustomersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRecord>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'customers__id__transactions__customer_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, $$CustomersTableReferences),
          Customer,
          PrefetchHooks Function({bool transactionsRefs})
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> acknowledgedRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRevision: localRevision,
                acknowledgedRevision: acknowledgedRevision,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> acknowledgedRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRevision: localRevision,
                acknowledgedRevision: acknowledgedRevision,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomersTable, Customer>(table),
                  $$CustomersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedDataByColumns<
                      Customer,
                      $CustomersTable,
                      TransactionRecord,
                      $TransactionsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CustomersTableReferences
                          ._transactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CustomersTableReferences(
                            db,
                            table,
                            p0,
                          ).transactionsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'customer_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, $$CustomersTableReferences),
      Customer,
      PrefetchHooks Function({bool transactionsRefs})
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String customerId,
      required String type,
      required int amountPiasters,
      Value<String?> note,
      required DateTime transactionDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> localRevision,
      Value<int> acknowledgedRevision,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> customerId,
      Value<String> type,
      Value<int> amountPiasters,
      Value<String?> note,
      Value<DateTime> transactionDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> localRevision,
      Value<int> acknowledgedRevision,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRecord> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CustomersTable _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias('transactions__customer_id__customers__id');

  $$CustomersTableProcessedTableManager get customerId {
    final $_column = $_itemColumn<String>('customer_id')!;

    final manager = $$CustomersTableTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $TransactionAuditLogsTable,
    List<TransactionAuditLog>
  >
  _transactionAuditLogsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionAuditLogs,
        aliasName: 'transactions__id__transaction_audit_logs__transaction_id',
      );

  $$TransactionAuditLogsTableProcessedTableManager
  get transactionAuditLogsRefs {
    final manager = $$TransactionAuditLogsTableTableManager(
      $_db,
      $_db.transactionAuditLogs,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionAuditLogsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPiasters => $composableBuilder(
    column: $table.amountPiasters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CustomersTableFilterComposer get customerId {
    final $$CustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionAuditLogsRefs(
    Expression<bool> Function($$TransactionAuditLogsTableFilterComposer f) f,
  ) {
    final $$TransactionAuditLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionAuditLogs,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionAuditLogsTableFilterComposer(
            $db: $db,
            $table: $db.transactionAuditLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPiasters => $composableBuilder(
    column: $table.amountPiasters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CustomersTableOrderingComposer get customerId {
    final $$CustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountPiasters => $composableBuilder(
    column: $table.amountPiasters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$CustomersTableAnnotationComposer get customerId {
    final $$CustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionAuditLogsRefs<T extends Object>(
    Expression<T> Function($$TransactionAuditLogsTableAnnotationComposer a) f,
  ) {
    final $$TransactionAuditLogsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionAuditLogs,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionAuditLogsTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionAuditLogs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          TransactionRecord,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (TransactionRecord, $$TransactionsTableReferences),
          TransactionRecord,
          PrefetchHooks Function({
            bool customerId,
            bool transactionAuditLogsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountPiasters = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> transactionDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> acknowledgedRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                customerId: customerId,
                type: type,
                amountPiasters: amountPiasters,
                note: note,
                transactionDate: transactionDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRevision: localRevision,
                acknowledgedRevision: acknowledgedRevision,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                required String type,
                required int amountPiasters,
                Value<String?> note = const Value.absent(),
                required DateTime transactionDate,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> acknowledgedRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                customerId: customerId,
                type: type,
                amountPiasters: amountPiasters,
                note: note,
                transactionDate: transactionDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                localRevision: localRevision,
                acknowledgedRevision: acknowledgedRevision,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, TransactionRecord>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({customerId = false, transactionAuditLogsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionAuditLogsRefs) db.transactionAuditLogs,
                  ],
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
                        if (customerId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.customerId,
                            referencedTable: $$TransactionsTableReferences
                                ._customerIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._customerIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionAuditLogsRefs)
                        await $_getPrefetchedDataByColumns<
                          TransactionRecord,
                          $TransactionsTable,
                          TransactionAuditLog,
                          $TransactionAuditLogsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._transactionAuditLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionAuditLogsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'transaction_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      TransactionRecord,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (TransactionRecord, $$TransactionsTableReferences),
      TransactionRecord,
      PrefetchHooks Function({bool customerId, bool transactionAuditLogsRefs})
    >;
typedef $$TransactionAuditLogsTableCreateCompanionBuilder =
    TransactionAuditLogsCompanion Function({
      required String id,
      required String transactionId,
      required String action,
      required String previousType,
      required int previousAmountPiasters,
      Value<String?> previousNote,
      required DateTime previousTransactionDate,
      Value<DateTime> createdAt,
      Value<int> localRevision,
      Value<int> acknowledgedRevision,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$TransactionAuditLogsTableUpdateCompanionBuilder =
    TransactionAuditLogsCompanion Function({
      Value<String> id,
      Value<String> transactionId,
      Value<String> action,
      Value<String> previousType,
      Value<int> previousAmountPiasters,
      Value<String?> previousNote,
      Value<DateTime> previousTransactionDate,
      Value<DateTime> createdAt,
      Value<int> localRevision,
      Value<int> acknowledgedRevision,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

final class $$TransactionAuditLogsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionAuditLogsTable,
          TransactionAuditLog
        > {
  $$TransactionAuditLogsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) => db
      .transactions
      .createAlias('transaction_audit_logs__transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<String>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionAuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionAuditLogsTable> {
  $$TransactionAuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousType => $composableBuilder(
    column: $table.previousType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previousAmountPiasters => $composableBuilder(
    column: $table.previousAmountPiasters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousNote => $composableBuilder(
    column: $table.previousNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get previousTransactionDate => $composableBuilder(
    column: $table.previousTransactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionAuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionAuditLogsTable> {
  $$TransactionAuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousType => $composableBuilder(
    column: $table.previousType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previousAmountPiasters => $composableBuilder(
    column: $table.previousAmountPiasters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousNote => $composableBuilder(
    column: $table.previousNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get previousTransactionDate => $composableBuilder(
    column: $table.previousTransactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionAuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionAuditLogsTable> {
  $$TransactionAuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get previousType => $composableBuilder(
    column: $table.previousType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previousAmountPiasters => $composableBuilder(
    column: $table.previousAmountPiasters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousNote => $composableBuilder(
    column: $table.previousNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get previousTransactionDate => $composableBuilder(
    column: $table.previousTransactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acknowledgedRevision => $composableBuilder(
    column: $table.acknowledgedRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionAuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionAuditLogsTable,
          TransactionAuditLog,
          $$TransactionAuditLogsTableFilterComposer,
          $$TransactionAuditLogsTableOrderingComposer,
          $$TransactionAuditLogsTableAnnotationComposer,
          $$TransactionAuditLogsTableCreateCompanionBuilder,
          $$TransactionAuditLogsTableUpdateCompanionBuilder,
          (TransactionAuditLog, $$TransactionAuditLogsTableReferences),
          TransactionAuditLog,
          PrefetchHooks Function({bool transactionId})
        > {
  $$TransactionAuditLogsTableTableManager(
    _$AppDatabase db,
    $TransactionAuditLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionAuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionAuditLogsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TransactionAuditLogsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> previousType = const Value.absent(),
                Value<int> previousAmountPiasters = const Value.absent(),
                Value<String?> previousNote = const Value.absent(),
                Value<DateTime> previousTransactionDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> acknowledgedRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionAuditLogsCompanion(
                id: id,
                transactionId: transactionId,
                action: action,
                previousType: previousType,
                previousAmountPiasters: previousAmountPiasters,
                previousNote: previousNote,
                previousTransactionDate: previousTransactionDate,
                createdAt: createdAt,
                localRevision: localRevision,
                acknowledgedRevision: acknowledgedRevision,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String transactionId,
                required String action,
                required String previousType,
                required int previousAmountPiasters,
                Value<String?> previousNote = const Value.absent(),
                required DateTime previousTransactionDate,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> acknowledgedRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionAuditLogsCompanion.insert(
                id: id,
                transactionId: transactionId,
                action: action,
                previousType: previousType,
                previousAmountPiasters: previousAmountPiasters,
                previousNote: previousNote,
                previousTransactionDate: previousTransactionDate,
                createdAt: createdAt,
                localRevision: localRevision,
                acknowledgedRevision: acknowledgedRevision,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionAuditLogsTable, TransactionAuditLog>(
                    table,
                  ),
                  $$TransactionAuditLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false}) {
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
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable: $$TransactionAuditLogsTableReferences
                            ._transactionIdTable(db),
                        referencedColumn: $$TransactionAuditLogsTableReferences
                            ._transactionIdTable(db)
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

typedef $$TransactionAuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionAuditLogsTable,
      TransactionAuditLog,
      $$TransactionAuditLogsTableFilterComposer,
      $$TransactionAuditLogsTableOrderingComposer,
      $$TransactionAuditLogsTableAnnotationComposer,
      $$TransactionAuditLogsTableCreateCompanionBuilder,
      $$TransactionAuditLogsTableUpdateCompanionBuilder,
      (TransactionAuditLog, $$TransactionAuditLogsTableReferences),
      TransactionAuditLog,
      PrefetchHooks Function({bool transactionId})
    >;
typedef $$BackupMetadataTableCreateCompanionBuilder =
    BackupMetadataCompanion Function({
      Value<int> id,
      Value<String?> schedule,
      Value<String?> lastConfirmedAtIso,
      Value<String?> nextDueAtIso,
      Value<bool> isDeviceActive,
    });
typedef $$BackupMetadataTableUpdateCompanionBuilder =
    BackupMetadataCompanion Function({
      Value<int> id,
      Value<String?> schedule,
      Value<String?> lastConfirmedAtIso,
      Value<String?> nextDueAtIso,
      Value<bool> isDeviceActive,
    });

class $$BackupMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $BackupMetadataTable> {
  $$BackupMetadataTableFilterComposer({
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

  ColumnFilters<String> get schedule => $composableBuilder(
    column: $table.schedule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastConfirmedAtIso => $composableBuilder(
    column: $table.lastConfirmedAtIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextDueAtIso => $composableBuilder(
    column: $table.nextDueAtIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeviceActive => $composableBuilder(
    column: $table.isDeviceActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupMetadataTable> {
  $$BackupMetadataTableOrderingComposer({
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

  ColumnOrderings<String> get schedule => $composableBuilder(
    column: $table.schedule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastConfirmedAtIso => $composableBuilder(
    column: $table.lastConfirmedAtIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextDueAtIso => $composableBuilder(
    column: $table.nextDueAtIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeviceActive => $composableBuilder(
    column: $table.isDeviceActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupMetadataTable> {
  $$BackupMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get schedule =>
      $composableBuilder(column: $table.schedule, builder: (column) => column);

  GeneratedColumn<String> get lastConfirmedAtIso => $composableBuilder(
    column: $table.lastConfirmedAtIso,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextDueAtIso => $composableBuilder(
    column: $table.nextDueAtIso,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeviceActive => $composableBuilder(
    column: $table.isDeviceActive,
    builder: (column) => column,
  );
}

class $$BackupMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupMetadataTable,
          BackupMetadataRow,
          $$BackupMetadataTableFilterComposer,
          $$BackupMetadataTableOrderingComposer,
          $$BackupMetadataTableAnnotationComposer,
          $$BackupMetadataTableCreateCompanionBuilder,
          $$BackupMetadataTableUpdateCompanionBuilder,
          (
            BackupMetadataRow,
            BaseReferences<
              _$AppDatabase,
              $BackupMetadataTable,
              BackupMetadataRow
            >,
          ),
          BackupMetadataRow,
          PrefetchHooks Function()
        > {
  $$BackupMetadataTableTableManager(
    _$AppDatabase db,
    $BackupMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> schedule = const Value.absent(),
                Value<String?> lastConfirmedAtIso = const Value.absent(),
                Value<String?> nextDueAtIso = const Value.absent(),
                Value<bool> isDeviceActive = const Value.absent(),
              }) => BackupMetadataCompanion(
                id: id,
                schedule: schedule,
                lastConfirmedAtIso: lastConfirmedAtIso,
                nextDueAtIso: nextDueAtIso,
                isDeviceActive: isDeviceActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> schedule = const Value.absent(),
                Value<String?> lastConfirmedAtIso = const Value.absent(),
                Value<String?> nextDueAtIso = const Value.absent(),
                Value<bool> isDeviceActive = const Value.absent(),
              }) => BackupMetadataCompanion.insert(
                id: id,
                schedule: schedule,
                lastConfirmedAtIso: lastConfirmedAtIso,
                nextDueAtIso: nextDueAtIso,
                isDeviceActive: isDeviceActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupMetadataTable, BackupMetadataRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BackupMetadataTable,
                    BackupMetadataRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupMetadataTable,
      BackupMetadataRow,
      $$BackupMetadataTableFilterComposer,
      $$BackupMetadataTableOrderingComposer,
      $$BackupMetadataTableAnnotationComposer,
      $$BackupMetadataTableCreateCompanionBuilder,
      $$BackupMetadataTableUpdateCompanionBuilder,
      (
        BackupMetadataRow,
        BaseReferences<_$AppDatabase, $BackupMetadataTable, BackupMetadataRow>,
      ),
      BackupMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$BackupInFlightBatchesTableCreateCompanionBuilder =
    BackupInFlightBatchesCompanion Function({
      Value<int> id,
      required String batchId,
      required String ownerUserId,
      required String deviceId,
      required String capturedAtIso,
      required String payloadJson,
    });
typedef $$BackupInFlightBatchesTableUpdateCompanionBuilder =
    BackupInFlightBatchesCompanion Function({
      Value<int> id,
      Value<String> batchId,
      Value<String> ownerUserId,
      Value<String> deviceId,
      Value<String> capturedAtIso,
      Value<String> payloadJson,
    });

class $$BackupInFlightBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BackupInFlightBatchesTable> {
  $$BackupInFlightBatchesTableFilterComposer({
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

  ColumnFilters<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedAtIso => $composableBuilder(
    column: $table.capturedAtIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupInFlightBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupInFlightBatchesTable> {
  $$BackupInFlightBatchesTableOrderingComposer({
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

  ColumnOrderings<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedAtIso => $composableBuilder(
    column: $table.capturedAtIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupInFlightBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupInFlightBatchesTable> {
  $$BackupInFlightBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get capturedAtIso => $composableBuilder(
    column: $table.capturedAtIso,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$BackupInFlightBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupInFlightBatchesTable,
          BackupInFlightBatchRow,
          $$BackupInFlightBatchesTableFilterComposer,
          $$BackupInFlightBatchesTableOrderingComposer,
          $$BackupInFlightBatchesTableAnnotationComposer,
          $$BackupInFlightBatchesTableCreateCompanionBuilder,
          $$BackupInFlightBatchesTableUpdateCompanionBuilder,
          (
            BackupInFlightBatchRow,
            BaseReferences<
              _$AppDatabase,
              $BackupInFlightBatchesTable,
              BackupInFlightBatchRow
            >,
          ),
          BackupInFlightBatchRow,
          PrefetchHooks Function()
        > {
  $$BackupInFlightBatchesTableTableManager(
    _$AppDatabase db,
    $BackupInFlightBatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupInFlightBatchesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BackupInFlightBatchesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BackupInFlightBatchesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> batchId = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> capturedAtIso = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
              }) => BackupInFlightBatchesCompanion(
                id: id,
                batchId: batchId,
                ownerUserId: ownerUserId,
                deviceId: deviceId,
                capturedAtIso: capturedAtIso,
                payloadJson: payloadJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String batchId,
                required String ownerUserId,
                required String deviceId,
                required String capturedAtIso,
                required String payloadJson,
              }) => BackupInFlightBatchesCompanion.insert(
                id: id,
                batchId: batchId,
                ownerUserId: ownerUserId,
                deviceId: deviceId,
                capturedAtIso: capturedAtIso,
                payloadJson: payloadJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $BackupInFlightBatchesTable,
                    BackupInFlightBatchRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BackupInFlightBatchesTable,
                    BackupInFlightBatchRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupInFlightBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupInFlightBatchesTable,
      BackupInFlightBatchRow,
      $$BackupInFlightBatchesTableFilterComposer,
      $$BackupInFlightBatchesTableOrderingComposer,
      $$BackupInFlightBatchesTableAnnotationComposer,
      $$BackupInFlightBatchesTableCreateCompanionBuilder,
      $$BackupInFlightBatchesTableUpdateCompanionBuilder,
      (
        BackupInFlightBatchRow,
        BaseReferences<
          _$AppDatabase,
          $BackupInFlightBatchesTable,
          BackupInFlightBatchRow
        >,
      ),
      BackupInFlightBatchRow,
      PrefetchHooks Function()
    >;
typedef $$BackupDeviceIdentitiesTableCreateCompanionBuilder =
    BackupDeviceIdentitiesCompanion Function({
      Value<int> id,
      required String deviceId,
    });
typedef $$BackupDeviceIdentitiesTableUpdateCompanionBuilder =
    BackupDeviceIdentitiesCompanion Function({
      Value<int> id,
      Value<String> deviceId,
    });

class $$BackupDeviceIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $BackupDeviceIdentitiesTable> {
  $$BackupDeviceIdentitiesTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupDeviceIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupDeviceIdentitiesTable> {
  $$BackupDeviceIdentitiesTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupDeviceIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupDeviceIdentitiesTable> {
  $$BackupDeviceIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$BackupDeviceIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupDeviceIdentitiesTable,
          BackupDeviceIdentityRow,
          $$BackupDeviceIdentitiesTableFilterComposer,
          $$BackupDeviceIdentitiesTableOrderingComposer,
          $$BackupDeviceIdentitiesTableAnnotationComposer,
          $$BackupDeviceIdentitiesTableCreateCompanionBuilder,
          $$BackupDeviceIdentitiesTableUpdateCompanionBuilder,
          (
            BackupDeviceIdentityRow,
            BaseReferences<
              _$AppDatabase,
              $BackupDeviceIdentitiesTable,
              BackupDeviceIdentityRow
            >,
          ),
          BackupDeviceIdentityRow,
          PrefetchHooks Function()
        > {
  $$BackupDeviceIdentitiesTableTableManager(
    _$AppDatabase db,
    $BackupDeviceIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupDeviceIdentitiesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BackupDeviceIdentitiesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BackupDeviceIdentitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
          }) => BackupDeviceIdentitiesCompanion(id: id, deviceId: deviceId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
              }) => BackupDeviceIdentitiesCompanion.insert(
                id: id,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $BackupDeviceIdentitiesTable,
                    BackupDeviceIdentityRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BackupDeviceIdentitiesTable,
                    BackupDeviceIdentityRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupDeviceIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupDeviceIdentitiesTable,
      BackupDeviceIdentityRow,
      $$BackupDeviceIdentitiesTableFilterComposer,
      $$BackupDeviceIdentitiesTableOrderingComposer,
      $$BackupDeviceIdentitiesTableAnnotationComposer,
      $$BackupDeviceIdentitiesTableCreateCompanionBuilder,
      $$BackupDeviceIdentitiesTableUpdateCompanionBuilder,
      (
        BackupDeviceIdentityRow,
        BaseReferences<
          _$AppDatabase,
          $BackupDeviceIdentitiesTable,
          BackupDeviceIdentityRow
        >,
      ),
      BackupDeviceIdentityRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$TransactionAuditLogsTableTableManager get transactionAuditLogs =>
      $$TransactionAuditLogsTableTableManager(_db, _db.transactionAuditLogs);
  $$BackupMetadataTableTableManager get backupMetadata =>
      $$BackupMetadataTableTableManager(_db, _db.backupMetadata);
  $$BackupInFlightBatchesTableTableManager get backupInFlightBatches =>
      $$BackupInFlightBatchesTableTableManager(_db, _db.backupInFlightBatches);
  $$BackupDeviceIdentitiesTableTableManager get backupDeviceIdentities =>
      $$BackupDeviceIdentitiesTableTableManager(
        _db,
        _db.backupDeviceIdentities,
      );
}

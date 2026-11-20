import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/app_exception.dart';
import '../models/security_record.dart';

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;
  static const recordKey = 'daftari.security.record.v1';

  Future<SecurityRecord?> read() async {
    try {
      final value = await _storage.read(key: recordKey);
      if (value == null) return null;
      return SecurityRecord.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      throw const StorageException();
    }
  }

  Future<void> write(SecurityRecord record) async {
    try {
      // One encrypted write avoids split credential/attempt/preference updates.
      await _storage.write(key: recordKey, value: jsonEncode(record.toJson()));
    } catch (_) {
      throw const StorageException();
    }
  }
}

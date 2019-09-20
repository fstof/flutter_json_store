import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final _storage = new FlutterSecureStorage();
  static SecureStorage _instance;

  SecureStorage._createInstance();

  factory SecureStorage() {
    if (_instance == null) {
      _instance = SecureStorage._createInstance();
    }
    return _instance;
  }

  Future<void> set(String key, Map<String, dynamic> value) async {
    final String jsonString = json.encode(value);
    return _storage.write(key: key, value: jsonString);
  }

  Future<Map<String, dynamic>> get(String key) async {
    final value = await _storage.read(key: key);
    if (value != null) {
      final Map<String, dynamic> parsedValue = json.decode(value);
      return parsedValue;
    }
    return null;
  }
}

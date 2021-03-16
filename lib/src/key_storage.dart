import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStorage {
  static const IV_LENGTH = 8;
  static const KEY_LENGTH = 32;
  static const _keyKey = 'encryption_key';
  static const _ivKey = 'encryption_iv';

  final _storage = new FlutterSecureStorage();
  static final _iOptions = IOSOptions(
    accessibility: IOSAccessibility.first_unlock_this_device,
  );

  Future<Key> getKey() async {
    final containsOriginalKey = await _storage.containsKey(key: _keyKey);
    if (containsOriginalKey) {
      _storage.write(
        key: _keyKey,
        value: await _storage.read(key: _keyKey),
        iOptions: _iOptions,
      );
    }

    final containsKey = await _storage.containsKey(
      key: _keyKey,
      iOptions: _iOptions,
    );
    if (!containsKey) {
      Key key = Key.fromSecureRandom(KEY_LENGTH);

      await _storage.write(
        key: _keyKey,
        value: json.encode({'value': key.base64}),
        iOptions: _iOptions,
      );
    }

    final Map<String, dynamic> keyMap = json.decode(
      (await _storage.read(key: _keyKey, iOptions: _iOptions))!,
    );

    Key key;
    String value = keyMap['value'];
    // For backward compatibility
    if (value.length == 32) {
      key = Key.fromUtf8(value);
    } else {
      key = Key.fromBase64(value);
    }
    return key;
  }

  Future<IV> getGlobalIV() async {
    final containsOriginalKey = await _storage.containsKey(key: _ivKey);
    if (containsOriginalKey) {
      _storage.write(
        key: _ivKey,
        value: await _storage.read(key: _ivKey),
        iOptions: _iOptions,
      );
    }

    final containsKey = await _storage.containsKey(
      key: _ivKey,
      iOptions: _iOptions,
    );
    if (!containsKey) {
      IV iv = IV.fromSecureRandom(IV_LENGTH);

      await _storage.write(
        key: _ivKey,
        value: json.encode({'value': iv.base64}),
        iOptions: _iOptions,
      );
    }

    final Map<String, dynamic> ivMap = json.decode(
      (await _storage.read(key: _ivKey, iOptions: _iOptions))!,
    );

    IV iv;
    String value = ivMap['value'];
    // For backward compatibility
    if (value.length == 32) {
      iv = IV.fromUtf8(value);
    } else {
      iv = IV.fromBase64(value);
    }
    return iv;
  }
}

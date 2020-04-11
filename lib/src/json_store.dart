import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'secure_storage.dart';
import 'store_exception.dart';

class JsonStore {
  static JsonStore _instance;

  static SecureStorage _secureStorage;
  static Future<Database> _databaseFuture;
  static Encrypter _encrypter;
  static Key _key;
  static IV _iv;

  static const IV_LENGTH = 8;
  static const KEY_LENGTH = 32;

  static const String _table = 'json_store';
  static const String _timeToLiveKey = 'ttl';
  static const String _encryptedKey = 'encrypted';
  static const String _ivKey = 'iv';
  static const bool encryptByDefault = false;

  JsonStore._createInstance(Database database, String dbName, bool inMemory) {
    _secureStorage = SecureStorage();

    if (database != null) {
      _databaseFuture = Future.value(database);
    }
    if (_databaseFuture == null) {
      _databaseFuture = _initialiseDatabase(dbName, inMemory);
    }
  }

  factory JsonStore({Database database, String dbName = 'json_store', bool inMemory = false}) {
    if (_instance == null) {
      _instance = JsonStore._createInstance(database, dbName, inMemory);
    }
    return _instance;
  }

  Future<void> clearDataBase() async {
    final Database db = await _databaseFuture;
    await db.delete(_table);
  }

  Future<Database> _initialiseDatabase(String dbName, bool inMemory) async {
    if (inMemory) {
      return openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createDb,
      );
    }
    final Directory path = await getApplicationDocumentsDirectory();
    return openDatabase(
      '${path.path}/$dbName.db',
      version: 1,
      onCreate: _createDb,
    );
  }

  void _createDb(Database db, int newVersion) async {
    await db.execute('''CREATE TABLE $_table(
      key TEXT PRIMARY KEY,
      value TEXT,
      lastUpdated INTEGER,
      metadata TEXT
    );
    ''');
  }

  /// This function will create a [Batch] object, this allowed you to do some sort of transaction control.
  /// example:
  ///   var b = await jsonStore.startBatch();
  ///   await jsonStore.set('key', value1, batch: b);
  ///   await jsonStore.set('key', value2, batch: b);
  ///   await jsonStore.set('key', value3, batch: b);
  ///   await jsonStore.commitBatch(b);
  ///
  Future<Batch> startBatch() async {
    final Database db = await _databaseFuture;
    return db.batch();
  }

  Future<void> commitBatch(Batch batch) async {
    await batch.commit(noResult: true);
  }

  /// This function will store any data as a single json object in the database.
  /// We will try and update the key first and then insert if none exists
  Future<void> setItem(
    String key,
    Map<String, dynamic> value, {
    bool encrypt = encryptByDefault,
    Duration timeToLive = const Duration(days: 365),
    Batch batch,
  }) async {
    try {
      IV iv;
      if (encrypt) {
        iv = IV.fromSecureRandom(IV_LENGTH);
      }
      final metadata = {
        _timeToLiveKey: timeToLive.inMilliseconds,
        _encryptedKey: encrypt,
        _ivKey: (encrypt ? iv.base64 : null),
      };
      bool doCommit = false;
      if (batch == null) {
        doCommit = true;
        batch = await startBatch();
      }
      final jsonString = await _encodeJson(value, encrypt, iv);
      _upsert(batch, key, jsonString, metadata);

      if (doCommit) {
        await commitBatch(batch);
      }
    } catch (error) {
      throw StorageException('error setting value with key: $key', error);
    }
  }

  Future<void> deleteItem(String key, {Batch batch}) async {
    bool doCommit = false;
    if (batch == null) {
      doCommit = true;
      batch = await startBatch();
    }

    _delete(batch, key);

    if (doCommit) {
      await commitBatch(batch);
    }
  }

  /// Function that will retrieve a single json object from the database.
  Future<Map<String, dynamic>> getItem(String key) async {
    final Database db = await _databaseFuture;
    final List<Map<String, dynamic>> queryResult =
        await db.query(_table, where: 'key = ?', whereArgs: [key]);
    return processQueryResult(key, queryResult, db);
  }

//Function that will retrieve a single json object from the database as a result of like query on the key.
  Future<Map<String, dynamic>> getItemLike(String key) async {
    final Database db = await _databaseFuture;
    final List<Map<String, dynamic>> queryResult =
        await db.query(_table, where: 'key like ?', whereArgs: [key]);
    return processQueryResult(key, queryResult, db);
  }

  Future<Map<String, dynamic>> processQueryResult(
    String key,
    List<Map<String, dynamic>> queryResult,
    Database db,
  ) async {
    if (queryResult != null && queryResult.isNotEmpty) {
      final Map<String, dynamic> row = queryResult[0];
      final Map<String, dynamic> metadata = json.decode(row['metadata']);
      final DateTime lastUpdated =
          DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);
      final timeLapsed = DateTime.now().millisecondsSinceEpoch -
          lastUpdated.millisecondsSinceEpoch;
      if (timeLapsed > (metadata[_timeToLiveKey] as int)) {
        await db.delete(_table, where: 'key = ?', whereArgs: [key]);
        return null;
      } else {
        final String value = row['value'];
        final bool encrypted = metadata[_encryptedKey] as bool;
        if (encrypted && metadata[_ivKey] != null) {
          final IV iv = IV.fromBase64(metadata[_ivKey]);
          return await _decodeJson(value, encrypted, iv);
        } else {
          return await _decodeJson(value, encrypted, null);
        }
      }
    }
    return null;
  }

  /// Function to retrieve a list of objects from the database stored under a similar key.
  /// example:
  /// Message list could be retrieved like this
  ///   await jsonStore.getListLike('message%');
  /// //this should return a list based on the following data
  ///   | key       | value |
  ///   | message-1 | ...   |
  ///   | message-2 | ...   |
  ///   | message-3 | ...   |
  Future<List<Map<String, dynamic>>> getListLike(String key) async {
    final Database db = await _databaseFuture;

    final List<Map<String, dynamic>> queryResult =
        await db.query(_table, where: 'key like ?', whereArgs: [key]);

    if (queryResult != null && queryResult.isNotEmpty) {
      List<Map<String, dynamic>> result = List<Map<String, dynamic>>();
      await Future.forEach(queryResult, (row) async {
        final Map<String, dynamic> metadata = json.decode(row['metadata']);
        final String value = row['value'];
        final DateTime lastUpdated =
            DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);
        final timeLapsed = DateTime.now().millisecondsSinceEpoch -
            lastUpdated.millisecondsSinceEpoch;
        if (timeLapsed > (metadata[_timeToLiveKey] as int)) {
          await db.delete(_table, where: 'key like ?', whereArgs: [key]);
          return null;
        } else {
          final encrypted = metadata[_encryptedKey] as bool;
          if (encrypted && metadata[_ivKey] != null) {
            final IV iv = IV.fromBase64(metadata[_ivKey]);
            result.add(
              await _decodeJson(value, encrypted, iv),
            );
          } else {
            result.add(
              await _decodeJson(value, encrypted, null),
            );
          }
        }
      });
      return result;
    }
    return null;
  }

  void _delete(Batch db, String key) async {
    db.delete(
      _table,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  void _upsert(
    Batch db,
    String key,
    String value,
    Map<String, dynamic> metadata,
  ) async {
    final metadataJson = json.encode(metadata);
    final lastUpdated = DateTime.now().millisecondsSinceEpoch;
    db.rawInsert(
      'INSERT OR REPLACE INTO $_table(key, value, metadata, lastUpdated) VALUES(?, ?, ?, ?)',
      [key, value, metadataJson, lastUpdated],
    );
  }

  Future<String> _encodeJson(Map<String, dynamic> value, bool encrypt, IV iv) async {
    if (encrypt) {
      if (iv == null) {
        iv = await _getGlobalIV();
      }
      Encrypted encryptedValue = (await _getEncrypter()).encrypt(
        json.encode(value),
        iv: iv,
      );
      return encryptedValue.base16;
    }

    return json.encode(value);
  }

  Future<dynamic> _decodeJson(String value, bool encrypted, IV iv) async {
    if (encrypted) {
      if (iv == null) {
        iv = await _getGlobalIV();
      }
      String decryptedValue = (await _getEncrypter()).decrypt(
        Encrypted.fromBase16(value),
        iv: iv,
      );
      return json.decode(decryptedValue);
    }

    return json.decode(value);
  }

  Future<Encrypter> _getEncrypter() async {
    if (_encrypter == null) {
      _encrypter = Encrypter(Salsa20(await _getKey()));
    }
    return _encrypter;
  }

  Future<Key> _getKey() async {
    if (_key == null) {
      final keyMap = await _secureStorage.get('encryption_key');
      if (keyMap == null) {
        _key = Key.fromSecureRandom(KEY_LENGTH);
        await _secureStorage.set('encryption_key', {'value': _key.base64});
      } else {
        String value = keyMap['value'];
        // For backward compatibility
        if (value.length == 32) {
          _key = Key.fromUtf8(value);
        } else {
          _key = Key.fromBase64(value);
        }
      }
    }
    return _key;
  }

  Future<IV> _getGlobalIV() async {
    if (_iv == null) {
      final ivMap = await _secureStorage.get('encryption_iv');
      if (ivMap == null) {
        IV iv = IV.fromSecureRandom(IV_LENGTH);
        await _secureStorage.set('encryption_iv', {'value': iv.base64});
        _iv = iv;
      } else {
        String value = ivMap['value'];
        // For backward compatibility
        if (value.length == 8) {
          _iv = IV.fromUtf8(value);
        } else {
          _iv = IV.fromBase64(value);
        }
      }
    }
    return _iv;
  }
}

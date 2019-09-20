import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'secure_storage.dart';
import 'store_exception.dart';

class JsonStore {
  static JsonStore _instance;

  static Random _random;
  static SecureStorage _secureStorage;
  static Future<Database> _databaseFuture;
  static Encrypter _encrypter;
  static Key _key;
  static IV _iv;

  static const String _table = 'json_store';
  static const String _timeToLiveKey = 'ttl';
  static const String _encryptedKey = 'encrypted';
  static const bool encryptByDefault = false;

  JsonStore._createInstance(Database database, bool inMemory) {
    _secureStorage = SecureStorage();

    if (database != null) {
      _databaseFuture = Future.value(database);
    }
    if (_databaseFuture == null) {
      _databaseFuture = _initialiseDatabase(inMemory);
    }
  }

  factory JsonStore({Database database, bool inMemory = false}) {
    if (_instance == null) {
      _instance = JsonStore._createInstance(database, inMemory);
    }
    return _instance;
  }

  Future<void> clearDataBase() async {
    final Database db = await _databaseFuture;
    await db.delete(_table);
  }

  Future<Database> _initialiseDatabase(bool inMemory) async {
    if (inMemory) {
      return openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createDb,
      );
    }
    final Directory path = await getApplicationDocumentsDirectory();
    return openDatabase(
      '${path.path}/json_store.db',
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
      final metadata = {
        _timeToLiveKey: timeToLive.inMilliseconds,
        _encryptedKey: encrypt,
      };
      bool doCommit = false;
      if (batch == null) {
        doCommit = true;
        batch = await startBatch();
      }

      final jsonString = await _encodeJson(value, encrypt);
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

        return await _decodeJson(value, encrypted);
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
          result.add(
            await _decodeJson(value, encrypted),
          );
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

  Future<String> _encodeJson(Map<String, dynamic> value, bool encrypt) async {
    if (encrypt) {
      Encrypted encryptedValue = (await _getEncrypter()).encrypt(
        json.encode(value),
        iv: await _getIV(),
      );
      return encryptedValue.base16;
    }

    return json.encode(value);
  }

  Future<dynamic> _decodeJson(String value, bool encrypted) async {
    if (encrypted) {
      String decryptedValue = (await _getEncrypter()).decrypt(
        Encrypted.fromBase16(value),
        iv: await _getIV(),
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
        String keyString = _randomString(32);
        await _secureStorage.set('encryption_key', {'value': keyString});
        _key = Key.fromUtf8(keyString);
      } else {
        _key = Key.fromUtf8(keyMap['value']);
      }
    }
    return _key;
  }

  Future<IV> _getIV() async {
    if (_iv == null) {
      final ivMap = await _secureStorage.get('encryption_iv');
      if (ivMap == null) {
        String ivString = _randomString(8);
        await _secureStorage.set('encryption_iv', {'value': ivString});
        _iv = IV.fromUtf8(ivString);
      } else {
        _iv = IV.fromUtf8(ivMap['value']);
      }
    }
    return _iv;
  }

  static const _chars = "abcdefghijklmnopqrstuvwxyz0123456789";

  String _randomString(int strlen) {
    if (_random == null) {
      // Random rnd = Random(DateTime.now().millisecondsSinceEpoch);
      _random = Random.secure();
    }
    String result = "";
    for (var i = 0; i < strlen; i++) {
      result += _chars[_random.nextInt(_chars.length)];
    }
    return result;
  }
}

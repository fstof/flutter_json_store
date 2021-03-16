import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'key_storage.dart';
import 'store_exception.dart';

class JsonStore {
  static JsonStore? _instance;

  final KeyStorage _keyStorage;
  late final Future<Database> _databaseFuture;
  Encrypter? _encrypter;

  static const String _table = 'json_store';
  static const String _timeToLiveKey = 'ttl';
  static const String _encryptedKey = 'encrypted';
  static const String _ivKey = 'iv';
  static const bool encryptByDefault = false;

  JsonStore._createInstance(
    Database? database,
    Directory? dbLocation,
    String dbName,
    bool inMemory,
  ) : _keyStorage = KeyStorage() {
    _databaseFuture = database != null
        ? Future.value(database)
        : _initialiseDatabase(dbLocation, dbName, inMemory);
  }

  /// create instance of your singleton [JsonStore]
  /// [database] If you need to supply your own database for whatever reason (maybe mocking or something)
  /// [dbLocation] If you want to use a different location for the DB file (default: `ApplicationDocumentsDirectory`)
  /// [dbName] Provide a custom database file name (default: `json_store`)
  /// [inMemory] If you don't want to store to disk but rather have it all in memory (default: `false`)
  factory JsonStore({
    Database? database,
    Directory? dbLocation,
    String dbName = 'json_store',
    bool inMemory = false,
  }) =>
      _instance ??=
          JsonStore._createInstance(database, dbLocation, dbName, inMemory);

  Future<void> clearDataBase() async {
    final Database db = await _databaseFuture;
    await db.delete(_table);
  }

  Future<Database> _initialiseDatabase(
    Directory? dbLocation,
    String dbName,
    bool inMemory,
  ) async {
    if (inMemory) {
      return openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createDb,
      );
    }
    dbLocation ??= await getApplicationDocumentsDirectory();
    return openDatabase(
      '${dbLocation.path}/$dbName.db',
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
  ///   await jsonStore.setItem('key', value1, batch: b);
  ///   await jsonStore.setItem('key', value2, batch: b);
  ///   await jsonStore.setItem('key', value3, batch: b);
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
  /// [key] the key of your item used to be retrieved later
  /// [value] json Map of your value object
  /// [encrypt] should the value be encrypted (default: [false])
  /// [timeToLive] how long should the data be considered valid (default: [null])
  /// If you [getItem] and the TTL has expired [null] will be returned and it will be removed from the database
  /// if [timeToLive] is [null] the data will never expire
  /// [batch] for transaction control where many [setItem] operations can be done in batch and commited at the end. see [startBatch]
  Future<void> setItem(
    String key,
    Map<String, dynamic> value, {
    bool encrypt = encryptByDefault,
    Duration? timeToLive,
    Batch? batch,
  }) async {
    try {
      IV? iv;
      if (encrypt) {
        iv = IV.fromSecureRandom(KeyStorage.IV_LENGTH);
      }
      final metadata = {
        _timeToLiveKey: timeToLive?.inMilliseconds,
        _encryptedKey: encrypt,
        _ivKey: iv?.base64,
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
    } catch (error, stack) {
      throw StorageException(
          'error setting value with key: $key', error, stack);
    }
  }

  Future<void> deleteItem(String key, {Batch? batch}) async {
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

  Future<void> deleteLike(String key, {Batch? batch}) async {
    bool doCommit = false;
    if (batch == null) {
      doCommit = true;
      batch = await startBatch();
    }

    batch.delete(
      _table,
      where: 'key like ?',
      whereArgs: [key],
    );

    if (doCommit) {
      await commitBatch(batch);
    }
  }

  /// Function that will retrieve a single json object from the database.
  Future<Map<String, dynamic>?> getItem(String key) async {
    final Database db = await _databaseFuture;
    final List<Map<String, dynamic>> queryResult =
        await db.query(_table, where: 'key = ?', whereArgs: [key]);
    return _processQueryResult(key, queryResult, db);
  }

//Function that will retrieve a single json object from the database as a result of like query on the key.
  Future<Map<String, dynamic>?> getItemLike(String key) async {
    final Database db = await _databaseFuture;
    final List<Map<String, dynamic>> queryResult =
        await db.query(_table, where: 'key like ?', whereArgs: [key]);
    return _processQueryResult(key, queryResult, db);
  }

  Future<Map<String, dynamic>?> _processQueryResult(
    String key,
    List<Map<String, dynamic>> queryResult,
    Database db,
  ) async {
    if (queryResult.isNotEmpty) {
      final Map<String, dynamic> row = queryResult[0];
      final Map<String, dynamic> metadata = json.decode(row['metadata']);
      final DateTime lastUpdated =
          DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);
      final timeLapsed = DateTime.now().millisecondsSinceEpoch -
          lastUpdated.millisecondsSinceEpoch;
      final ttl = metadata[_timeToLiveKey];
      if (ttl != null && timeLapsed > (ttl as int)) {
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
  Future<List<Map<String, dynamic>>?> getListLike(String key) async {
    final Database db = await _databaseFuture;

    final List<Map<String, dynamic>> queryResult =
        await db.query(_table, where: 'key like ?', whereArgs: [key]);

    if (queryResult.isNotEmpty) {
      List<Map<String, dynamic>> result = [];
      await Future.forEach(queryResult, (Map<String, dynamic> row) async {
        final Map<String, dynamic> metadata = json.decode(row['metadata']);
        final String value = row['value'];
        final DateTime lastUpdated =
            DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);
        final timeLapsed = DateTime.now().millisecondsSinceEpoch -
            lastUpdated.millisecondsSinceEpoch;
        final ttl = metadata[_timeToLiveKey];
        if (ttl != null && timeLapsed > (ttl as int)) {
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

  Future<String> _encodeJson(
    Map<String, dynamic> value,
    bool encrypt,
    IV? iv,
  ) async {
    if (encrypt) {
      iv ??= await _keyStorage.getGlobalIV();
      Encrypted encryptedValue = (await _getEncrypter()).encrypt(
        json.encode(value),
        iv: iv,
      );
      return encryptedValue.base16;
    }

    return json.encode(value);
  }

  Future<dynamic> _decodeJson(
    String value,
    bool encrypted,
    IV? iv,
  ) async {
    if (encrypted) {
      iv ??= await _keyStorage.getGlobalIV();
      String decryptedValue = (await _getEncrypter()).decrypt(
        Encrypted.fromBase16(value),
        iv: iv,
      );
      return json.decode(decryptedValue);
    }

    return json.decode(value);
  }

  Future<Encrypter> _getEncrypter() async {
    return _encrypter ??= Encrypter(Salsa20(await _keyStorage.getKey()));
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';
import 'package:sqflite/sqlite_api.dart';

class Message {
  final int id;
  final String title;
  final String body;

  Message([this.id, this.title, this.body]);
  Message.fromJson(Map<String, dynamic> json)
      : this.id = json['id'],
        this.title = json['title'],
        this.body = json['body'];
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };
}

class ListSample extends StatefulWidget {
  ListSample({Key key}) : super(key: key);
  @override
  _ListSampleState createState() => _ListSampleState();
}

class _ListSampleState extends State<ListSample> {
  List<Message> _messages = [];
  JsonStore _jsonStore = JsonStore(dbName: 'sampleapp');

  Random _random = Random();

  @override
  void initState() {
    super.initState();
    // _loadFromStorage();
  }

  _loadFromStorage() async {
    List<Map<String, dynamic>> json =
        await _jsonStore.getListLike('messages-%');

    _messages = json != null
        ? json.map((messageJson) => Message.fromJson(messageJson)).toList()
        : [];
    setState(() {});
  }

  _generate100() {
    for (var k = 0; k < 100; k++) {
      _addToList();
    }
  }

  _saveToStorageWithBatch() async {
    var start = DateTime.now().millisecondsSinceEpoch;
    // It's always better to use the Batch in this case as its way more performant
    Batch batch = await _jsonStore.startBatch();
    await Future.forEach(_messages, (message) async {
      // _messages.forEach((message) async {
      await _jsonStore.setItem(
        'messages-${message.id}',
        message.toJson(),
        batch: batch,
        encrypt: true,
      );
    });
    await _jsonStore.commitBatch(batch);
    var end = DateTime.now().millisecondsSinceEpoch;
    print(
        'time taken to store ${_messages.length} messages in a Batch: ${end - start}ms');
    setState(() {});
  }

  _saveToStorageWithoutBatch() async {
    var start = DateTime.now().millisecondsSinceEpoch;
    await Future.forEach(_messages, (message) async {
      await _jsonStore.setItem(
        'messages-${message.id}',
        message.toJson(),
        encrypt: true,
      );
    });
    var end = DateTime.now().millisecondsSinceEpoch;
    print('time taken to store ${_messages.length} messages: ${end - start}ms');
    setState(() {});
  }

  _addToList() {
    int num = _random.nextInt(9999999);
    setState(() => _messages.add(Message(num, '$num', '$num$num$num$num$num')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            Text('Store each item in its own row of the database'),
            Wrap(
              direction: Axis.horizontal,
              children: <Widget>[
                RaisedButton(
                  child: Text('Generate 100'),
                  onPressed: _generate100,
                ),
                SizedBox(width: 8),
                RaisedButton(
                  child: Text('Load'),
                  onPressed: _loadFromStorage,
                ),
                SizedBox(width: 8),
                RaisedButton(
                  child: Text('Save'),
                  onPressed: _saveToStorageWithoutBatch,
                ),
                SizedBox(width: 8),
                RaisedButton(
                  child: Text('Save batch'),
                  onPressed: _saveToStorageWithBatch,
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: _messages
                    .map((message) => ListTile(
                          title: Text(message.title),
                          subtitle: Text(message.body),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addToList,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}

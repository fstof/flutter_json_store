import 'dart:math';

import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';

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

class SingleListSample extends StatefulWidget {
  SingleListSample({Key key}) : super(key: key);
  @override
  _SingleListSampleState createState() => _SingleListSampleState();
}

class _SingleListSampleState extends State<SingleListSample> {
  List<Message> _messages = [];
  JsonStore _jsonStore = JsonStore();

  Random _random = Random();

  @override
  void initState() {
    super.initState();
    // _loadFromStorage();
  }

  _loadFromStorage() async {
    Map<String, dynamic> json = await _jsonStore.getItem('messages');

    _messages = json != null
        ? json['value'].map<Message>((messageJson) {
            return Message.fromJson(messageJson);
          }).toList()
        : [];
    setState(() {});
  }

  _saveToStorage() async {
    await _jsonStore.setItem('messages', {
      'value': _messages.map((message) {
        return message.toJson();
      }).toList()
    });
    setState(() {});
  }

  _addToList() {
    int num = _random.nextInt(999);
    setState(() => _messages.add(Message(num, '$num', '$num$num$num$num$num')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            Text('Store all the data in one single key / value object'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text('Load'),
                  onPressed: _loadFromStorage,
                ),
                SizedBox(width: 8),
                RaisedButton(
                  child: Text('Save'),
                  onPressed: _saveToStorage,
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

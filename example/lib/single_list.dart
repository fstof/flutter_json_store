import 'dart:math';

import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';

import 'model.dart';

class SingleListSample extends StatefulWidget {
  SingleListSample({Key? key}) : super(key: key);
  @override
  _SingleListSampleState createState() => _SingleListSampleState();
}

class _SingleListSampleState extends State<SingleListSample> {
  List<Message> _messages = [];

  Random _random = Random();

  @override
  void initState() {
    super.initState();
    // _loadFromStorage();
  }

  _loadFromStorage() async {
    Map<String, dynamic>? json = await JsonStore().getItem('messages');

    _messages = json != null
        ? json['value'].map<Message>((messageJson) {
            return Message.fromJson(messageJson);
          }).toList()
        : [];
    setState(() {});
  }

  _saveToStorage() async {
    await JsonStore().setItem('messages', {
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
                ElevatedButton(
                  child: Text('Load'),
                  onPressed: _loadFromStorage,
                ),
                SizedBox(width: 8),
                ElevatedButton(
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

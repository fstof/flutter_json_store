import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';

import 'counter.dart';
import 'form.dart';
import 'list.dart';
import 'single_list.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentTab = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Json Store Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // home: CounterSample(title: 'JSON store Counter demo'),
      // home: FormSample(title: 'JSON store Form demo'),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Storage demo'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () async {
                await JsonStore().clearDataBase();
              },
            )
          ],
        ),
        body: [
          CounterSample(),
          FormSample(),
          ListSample(),
          SingleListSample(),
        ][_currentTab],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.add),
              title: Text('Counter'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.format_bold),
              title: Text('Basic'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              title: Text('List'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              title: Text('Single List'),
            ),
          ],
        ),
      ),
    );
  }
}

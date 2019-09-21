import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';

class CounterModel {
  int value;
  CounterModel(this.value);
  CounterModel.fromJson(Map<String, dynamic> json) : this.value = json['value'];
  Map<String, dynamic> toJson() => {'value': value};
}

class CounterSample extends StatefulWidget {
  CounterSample({Key key}) : super(key: key);
  @override
  _CounterSampleState createState() => _CounterSampleState();
}

class _CounterSampleState extends State<CounterSample> {
  CounterModel _counter = CounterModel(0);
  JsonStore _jsonStore = JsonStore(dbName: 'sampleapp');

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  _loadFromStorage() async {
    Map<String, dynamic> json = await _jsonStore.getItem('counter');
    _counter = json != null ? CounterModel.fromJson(json) : CounterModel(0);
    setState(() {});
  }

  void _incrementCounter() async {
    setState(() => _counter.value++);
    await _jsonStore.setItem('counter', _counter.toJson());
  }

  void _decrementCounter() async {
    setState(() => _counter.value--);
    await _jsonStore.setItem('counter', _counter.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '${_counter.value}',
              style: Theme.of(context).textTheme.display1,
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: Icon(Icons.add),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _decrementCounter,
            tooltip: 'Decrement',
            child: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

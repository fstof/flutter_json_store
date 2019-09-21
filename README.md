# json_store

A Storage solution somewhat similar to a browser's localStorage in the sence that it is a key value pair storage. The value should be a dart reprisentation of a JSON Object (aka a `Map<String, dynamic>`)

## Features
- Data is stored in [sqflite](https://pub.dev/packages/sqflite) Database
- Data may be fully encrypted ([encrypt](https://pub.dev/packages/encrypt))
- Encryption keys are stored in [Keychain](https://developer.apple.com/documentation/security/keychain_services)  and [Keystore](https://developer.android.com/training/articles/keystore.html) thanks to [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- Because the DB schema never changes, there is no concern about database migrations
- Batch processing
- Data stored has a time to live. Whenever a `getItem` is done on a key which ttl has expired, that key will be deleted and a `null` value will be returned

## Getting Started

In your flutter project add the dependency:

```
dependencies:
  ...
  json_store:
  ...
```

For help getting started with Flutter, view the online [documentation](https://flutter.dev).

## Usage example
See example folder for full sample app

> Note: `JsonStore` is a singleton and instantiating with factory constructor `JsonStore()` will only ever have one instance

### Simple example
```dart
import 'package:json_store/json_store.dart';

class CounterModel {
  int value;
  CounterModel(this.value);
  CounterModel.fromJson(Map<String, dynamic> json) : this.value = json['value'];
  Map<String, dynamic> toJson() => {'value': value};
}

...

JsonStore jsonStore = JsonStore();
CounterModel counter;

loadFromStorage() async {
  Map<String, dynamic> json = await jsonStore.getItem('counter');
  counter = json != null ? CounterModel.fromJson(json) : CounterModel(0);
}

incrementCounter() async {
  counter.value++;
  await jsonStore.setItem('counter', counter.toJson());
}

...
```

### Batch example
When adding a lot of data at a time (Like a long list of messages), use the batch feature as it will improve performance significantly
```dart
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

saveBigList() {
  Batch batch = await jsonStore.startBatch();
  await Future.forEach(_messages, (message) async {
    await jsonStore.setItem(
      'messages-${message.id}',
      message.toJson(),
      batch: batch,
    );
  });
  jsonStore.commitBatch(batch);
}

loadBigList() {
      List<Map<String, dynamic>> json = await jsonStore.getListLike('messages-%');

    messages = json != null
        ? json.map((messageJson) => Message.fromJson(messageJson)).toList()
        : [];

}
```

## Configure Android
In [project]/android/app/build.gradle set minSdkVersion to >= 18.
```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 18
        ...
    }
}
```

### Thanks
Thanks to contributors
- Lester Cloete
- [Manjun Vasudevan](https://github.com/devmanjun)
- Yogesh Kumar
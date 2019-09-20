import 'package:flutter_test/flutter_test.dart';
import 'package:json_store/json_store.dart';

void main() {
  test('set and get an item', () async {
    // TODO: still need to do the unit tests. Probably needs to be integration test as the dependencies need a device
    final jsonStore = JsonStore();
    try {
      await jsonStore.setItem('key', {'some': 'value'});

      var result = await jsonStore.getItem('key');

      expect(result, isNotNull);
    } on StorageException catch (error) {
      print(error.message);
      print(error.causedBy);
      throw error;
    }
  });
}

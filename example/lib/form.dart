import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';

import 'model.dart';

class FormSample extends StatefulWidget {
  FormSample({Key? key}) : super(key: key);
  @override
  _FormSampleState createState() => _FormSampleState();
}

class _FormSampleState extends State<FormSample> {
  UserModel? _user;

  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _loadFromStorage();
  }

  _loadFromStorage() async {
    final json = await JsonStore().getItem('user');
    if (json != null) {
      setState(() {
        _user = UserModel.fromJson(json);
        _emailController.text = _user!.email;
        _passwordController.text = _user!.password;
      });
    }
  }

  _saveToStorage() async {
    _user = UserModel(_emailController.text, _passwordController.text);
    await JsonStore().setItem(
      'user',
      _user!.toJson(),
      timeToLive: Duration(seconds: 10),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            const Text(
              '''This data will be stored and will only be valid for 10 seconds. 
              When you load the data after that it will not return''',
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Email',
              ),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
              ),
            ),
            SizedBox(height: 8),
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
            Text('Email: ${_user?.email}'),
            Text('Password: ${_user?.password}'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:json_store/json_store.dart';

class UserModel {
  String email;
  String password;
  UserModel([this.email, this.password]);
  UserModel.fromJson(Map<String, dynamic> json)
      : this.email = json['email'],
        this.password = json['password'];
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class FormSample extends StatefulWidget {
  FormSample({Key key}) : super(key: key);
  @override
  _FormSampleState createState() => _FormSampleState();
}

class _FormSampleState extends State<FormSample> {
  UserModel _user = UserModel();
  JsonStore _jsonStore = JsonStore();

  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _loadFromStorage();
  }

  _loadFromStorage() async {
    Map<String, dynamic> json = await _jsonStore.getItem('user');
    _user = json != null ? UserModel.fromJson(json) : UserModel();
    _emailController.text = _user.email;
    _passwordController.text = _user.password;
    setState(() {});
  }

  _saveToStorage() async {
    _user.email = _emailController.text;
    _user.password = _passwordController.text;
    await _jsonStore.setItem('user', _user.toJson());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
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
            Text('Email: ${_user.email}'),
            Text('Password: ${_user.password}'),
          ],
        ),
      ),
    );
  }
}

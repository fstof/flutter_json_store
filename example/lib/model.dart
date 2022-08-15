class Message {
  final int id;
  final String title;
  final String body;

  Message(this.id, this.title, this.body);
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

class UserModel {
  String email;
  String password;
  UserModel(this.email, this.password);
  UserModel.fromJson(Map<String, dynamic> json)
      : this.email = json['email'],
        this.password = json['password'];
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class CounterModel {
  int value;
  CounterModel(this.value);
  CounterModel.fromJson(Map<String, dynamic> json) : this.value = json['value'];
  Map<String, dynamic> toJson() => {'value': value};
}

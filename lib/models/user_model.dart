class UserModel {
  final String uid;
  final String name;
  final String email;
  final String password;
  final String roleId;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.password,
    required this.roleId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      roleId: map['roleId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'roleId': roleId,
      'createdAt': DateTime.now(),
    };
  }
}

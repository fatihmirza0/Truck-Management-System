import 'package:lojistik/domain/entities/user.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'driver',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'isActive': isActive,
      };

  UserEntity toEntity() => UserEntity(
        id: id,
        name: name,
        email: email,
        role: role,
        isActive: isActive,
      );
}

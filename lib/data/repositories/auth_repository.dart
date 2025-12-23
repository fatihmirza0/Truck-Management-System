import 'package:lojistik/core/di/service_locator.dart';
import 'package:lojistik/domain/entities/user.dart';

class AuthRepository {
  final AuthServiceFacade _authService = getIt<AuthServiceFacade>();

  Future<UserEntity?> restoreSession() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) return null;
    final data = await _authService.getSavedUserData();
    final uid = data['uid'];
    if (uid == null) return null;
    return UserEntity(
      id: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'driver',
      isActive: true,
    );
  }

  Future<UserEntity?> login(String email, String password) async {
    final res = await _authService.login(email: email, password: password);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Login failed');
    }
    return UserEntity(
      id: res['uid'] ?? '',
      name: '',
      email: email,
      role: res['role'] ?? 'driver',
      isActive: true,
    );
  }

  Future<void> logout() => _authService.logout();
}

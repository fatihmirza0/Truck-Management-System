import 'package:get_it/get_it.dart';
import 'package:lojistik/services/auth_service.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  if (!getIt.isRegistered<AuthServiceFacade>()) {
    getIt.registerLazySingleton<AuthServiceFacade>(() => AuthServiceFacade());
  }
}

class AuthServiceFacade {
  Future<bool> isLoggedIn() => AuthService.isLoggedIn();
  Future<Map<String, String?>> getSavedUserData() => AuthService.getSavedUserData();
  Future<Map<String, dynamic>> login({required String email, required String password}) =>
      AuthService.login(email: email, password: password);
  Future<void> logout() => AuthService.logout();
}

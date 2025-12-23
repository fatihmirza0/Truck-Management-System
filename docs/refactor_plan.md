# Truck Management System – Clean Architecture Refactor Plan

This document outlines a prioritized refactor strategy to move the app to a modular, testable, and scalable architecture while preserving existing Firebase data and Cloud Functions.

## 1) Step-by-step refactoring order (most critical first)
1. **Foundations**
   - Add required dependencies (Riverpod/Provider, go_router, get_it, dio, hive, shared_preferences, freezed/json_serializable, firebase packages) and enable sound null safety across the codebase.
   - Create `core` module with constants, theming, helpers, validation, and error classes.
   - Configure static analysis (lint rules) and set up CI to enforce formatting/tests.
2. **Dependency injection & configuration**
   - Introduce `get_it` service locator with initialization in `main.dart` (Firebase initialization, local storage, repositories, and providers/controllers).
   - Ensure services expose interfaces for mocking; register lazy singletons and factories.
3. **Navigation overhaul with go_router**
   - Define typed routes in `core/constants/app_routes.dart` and configure `GoRouter` in `app.dart`.
   - Implement route guards using auth/role providers; migrate screens incrementally to the new router.
4. **Domain layer extraction**
   - Define entities and use cases (login/logout, job lifecycle, document upload, vehicle assignment) detached from Firebase specifics.
   - Replace direct service calls in UI with use case invocations.
5. **Data layer segmentation**
   - Introduce models with serialization (Freezed or json_serializable) and data sources (Firebase Auth, Firestore, Storage, HTTP where needed).
   - Implement repositories that translate between models and entities and wrap errors into Failures.
6. **Presentation layer with state management**
   - Use **Riverpod** (`StateNotifier`/`AsyncNotifier`) for providers and controllers; move business logic out of widgets.
   - Add reusable loading/error widgets and consistent page states.
7. **Feature-by-feature migration** (iterate per role)
   - Auth → Common (login/profile) → Driver jobs/documents → Dispatch jobs/drivers → Manager approvals → Admin users/reports.
   - For each feature: create providers, screens, widgets, repositories/use cases, and migrate navigation.
8. **Offline & storage improvements**
   - Add Hive + shared_preferences caches for auth/session, user profiles, and recent jobs/documents.
   - Use dio interceptors for caching/retries, and background sync hooks where possible.
9. **Testing enablement**
   - Add unit tests for use cases/repositories, widget tests for critical screens, and integration tests for navigation/auth flows.
10. **Documentation & polish**
    - Update README, architecture docs, and migration notes. Add logging/analytics hooks if needed.

## 2) Target folder structure (post-refactor)
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   ├── api_endpoints.dart
│   │   └── app_routes.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── text_styles.dart
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── formatters.dart
│   │   └── helpers.dart
│   └── errors/
│       ├── exceptions.dart
│       └── failures.dart
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── job_model.dart
│   │   ├── vehicle_model.dart
│   │   └── document_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── job_repository.dart
│   │   ├── user_repository.dart
│   │   └── vehicle_repository.dart
│   └── data_sources/
│       ├── firebase_auth_datasource.dart
│       ├── firestore_datasource.dart
│       └── storage_datasource.dart
├── domain/
│   ├── entities/
│   │   ├── user.dart
│   │   ├── job.dart
│   │   └── vehicle.dart
│   └── use_cases/
│       ├── auth/
│       │   ├── login_usecase.dart
│       │   └── logout_usecase.dart
│       └── jobs/
│           ├── create_job_usecase.dart
│           ├── approve_job_usecase.dart
│           └── complete_job_usecase.dart
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── job_provider.dart
│   │   └── user_provider.dart
│   ├── screens/
│   │   ├── common/
│   │   │   ├── login/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── login_controller.dart
│   │   │   └── profile/
│   │   │       ├── profile_screen.dart
│   │   │       └── profile_controller.dart
│   │   ├── driver/
│   │   │   ├── home/
│   │   │   │   ├── driver_home_screen.dart
│   │   │   │   └── driver_home_controller.dart
│   │   │   ├── jobs/
│   │   │   │   ├── active_jobs_screen.dart
│   │   │   │   ├── job_detail_screen.dart
│   │   │   │   └── jobs_controller.dart
│   │   │   └── documents/
│   │   │       ├── upload_document_screen.dart
│   │   │       └── documents_controller.dart
│   │   ├── dispatch/
│   │   │   ├── home/
│   │   │   ├── jobs/
│   │   │   │   ├── create_job_screen.dart
│   │   │   │   ├── job_list_screen.dart
│   │   │   │   └── jobs_controller.dart
│   │   │   └── drivers/
│   │   │       ├── add_driver_screen.dart
│   │   │       └── drivers_controller.dart
│   │   ├── manager/
│   │   │   ├── home/
│   │   │   ├── jobs/
│   │   │   │   ├── pending_jobs_screen.dart
│   │   │   │   ├── job_approval_screen.dart
│   │   │   │   └── jobs_controller.dart
│   │   │   └── reports/
│   │   └── admin/
│   │       ├── home/
│   │       ├── users/
│   │       └── reports/
│   └── widgets/
│       ├── common/
│       │   ├── custom_button.dart
│       │   ├── custom_text_field.dart
│       │   ├── loading_indicator.dart
│       │   └── error_widget.dart
│       ├── job/
│       │   ├── job_card.dart
│       │   └── job_status_badge.dart
│       └── user/
│           └── user_avatar.dart
└── services/
    ├── notification_service.dart
    ├── firebase_service.dart
    └── local_storage_service.dart
```

## 3) Code examples (key patterns)

### Models with serialization (Freezed + json_serializable)
```dart
// data/models/user_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user.dart';
part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel extends User with _$UserModel {
  const factory UserModel({
    required String id,
    required String name,
    required String email,
    required String role,
    String? phone,
    String? fcmToken,
    String? activePlate,
    String? jobStatus,
    @Default(true) bool isActive,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(String id, Map<String, dynamic> data) =>
      UserModel.fromJson({...data, 'id': id});
}
```

### Repository pattern
```dart
// domain/repositories/auth_repository.dart
import '../entities/user.dart';
abstract class AuthRepository {
  Future<User?> currentUser();
  Future<User> login({required String email, required String password});
  Future<void> logout();
}

// data/repositories/auth_repository_impl.dart
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../data_sources/firebase_auth_datasource.dart';
import '../models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._authDataSource);
  final FirebaseAuthDataSource _authDataSource;

  @override
  Future<User?> currentUser() async {
    final model = await _authDataSource.currentUser();
    return model;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    try {
      final user = await _authDataSource.login(email: email, password: password);
      return user;
    } on ServerException catch (e) {
      throw Failure.server(message: e.message);
    }
  }

  @override
  Future<void> logout() async {
    await _authDataSource.logout();
  }
}
```

### State management with Riverpod
```dart
// presentation/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/use_cases/auth/login_usecase.dart';
import '../../domain/use_cases/auth/logout_usecase.dart';
import '../../domain/entities/user.dart';

class AuthController extends AsyncNotifier<User?> {
  late final LoginUseCase _login;
  late final LogoutUseCase _logout;

  @override
  Future<User?> build() async => _login.currentUser();

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _login(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _logout());
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(() {
  return AuthController()
    .._login = getIt<LoginUseCase>()
    .._logout = getIt<LogoutUseCase>();
});
```

### Navigation with go_router and guards
```dart
// app.dart
final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final auth = context.read(authProvider); // use Riverpod listener
    final isLoggedIn = auth.valueOrNull != null;
    final isLoggingIn = state.matchedLocation == '/login';
    if (!isLoggedIn && !isLoggingIn) return '/login';

    final role = auth.valueOrNull?.role;
    if (state.subloc.startsWith('/manager') && role != 'manager') {
      return '/unauthorized';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/driver', builder: (_, __) => const DriverHomeScreen()),
    GoRoute(path: '/dispatch', builder: (_, __) => const DispatchHomeScreen()),
    // ...other role routes
  ],
);
```

### Dependency injection with get_it
```dart
// lib/di.dart
final getIt = GetIt.instance;

Future<void> setupDI() async {
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final hive = await Hive.openBox('app');

  // Data sources
  getIt.registerLazySingleton(() => FirebaseAuthDataSource());
  getIt.registerLazySingleton(() => FirestoreDataSource());
  getIt.registerLazySingleton(() => StorageDataSource());

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt()),
  );

  // Use cases
  getIt.registerFactory(() => LoginUseCase(getIt()));
  getIt.registerFactory(() => LogoutUseCase(getIt()));

  // Services
  getIt.registerLazySingleton(() => NotificationService());
  getIt.registerLazySingleton(() => LocalStorageService(prefs, hive));
}
```

### Error handling pattern
```dart
// core/errors/exceptions.dart
class ServerException implements Exception {
  ServerException(this.message, {this.code});
  final String message;
  final String? code;
}

class CacheException implements Exception {
  CacheException(this.message);
  final String message;
}

// core/errors/failures.dart
sealed class Failure {
  const Failure(this.message);
  final String message;
  factory Failure.server({required String message}) = ServerFailure;
  factory Failure.cache({required String message}) = CacheFailure;
}
class ServerFailure extends Failure { const ServerFailure({required super.message}); }
class CacheFailure extends Failure { const CacheFailure({required super.message}); }
```

### Service layer example (Firestore data source)
```dart
// data/data_sources/firestore_datasource.dart
class FirestoreDataSource {
  FirestoreDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<List<JobModel>> watchDriverJobs(String driverId) {
    return _firestore
        .collection('jobs')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<void> createJob(JobModel job) async {
    await _firestore.collection('jobs').doc(job.id).set(job.toJson());
  }
}
```

## 4) Migration strategy
- **Create the new structure alongside existing code**, starting with `core`, `domain`, and `data` layers so you can migrate features incrementally.
- **Adapter layer**: add temporary bridges that wrap old services into new repositories to avoid blocking UI rewrites.
- **Feature-by-feature port**: move one screen stack at a time (e.g., login → driver jobs → dispatch jobs). Replace old navigation strings with go_router paths as each screen migrates.
- **Data compatibility**: keep collection names/fields identical; models map 1:1 to current schema. Any new optional fields should default safely (`??` or `@Default`).
- **Gradual DI adoption**: register legacy services in get_it and refactor callers incrementally to request dependencies instead of instantiating directly.
- **Testing safety net**: add unit/widget tests for migrated features before removing legacy code. Maintain feature flags if needed.
- **Cleanup phase**: remove deprecated screens/services only after new paths are stable and monitored in production.

## 5) Best practices
- **Flutter**: keep widgets lean; extract reusable components; favor `const` constructors; use `Theme.of(context)` with centralized `AppTheme` and `TextStyles`.
- **Firebase**: wrap Firestore calls with try/catch and convert to Failures; use security rules for server-side validation; leverage batched writes/transactions for job approvals; include `fcmToken` updates on login.
- **State management**: use Riverpod providers scoped per feature; expose immutable state classes (loading/error/content); prefer `AsyncValue` for async flows.
- **Testing**: mock repositories/data sources; use `fake_cloud_firestore` for Firestore tests; widget tests for navigation guards; integration tests for login + role routing.
- **Performance/Offline**: enable Firestore persistence; cache recent jobs/documents in Hive; debounce search/filters; use dio retry/interceptor for transient failures.
- **Security**: validate inputs on both client and server; ensure role checks in UI **and** Firestore rules/Cloud Functions; never expose admin-only operations client-side without rules.

## 6) Package recommendations
- **State management**: `flutter_riverpod`, `hooks_riverpod` (optional for hooks).
- **Navigation**: `go_router`.
- **DI**: `get_it` + `injectable` (optional for code generation).
- **Networking**: `dio` (retry/interceptors), `http` (lightweight cases).
- **Serialization**: `freezed`, `json_serializable`, `build_runner`.
- **Local storage**: `shared_preferences`, `hive`, `path_provider`.
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`.
- **Utilities**: `equatable`, `dartz` or `fpdart` (optional for Either), `intl` (formatting), `file_picker`/`image_picker` for documents, `flutter_local_notifications` for foreground alerts.
- Prefer keeping dependency versions aligned with the current Flutter SDK; lock major versions to match Firebase BOM compatibility.

## 7) Initialization (main.dart outline)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDI();

  runApp(
    ProviderScope(
      observers: [Logger()],
      child: const MyApp(),
    ),
  );
}
```

This plan prioritizes stability while enabling incremental migration to a clean architecture with strong separation of concerns, consistent error handling, and improved testability.

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/user_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/user_repository.dart';
import '../../features/auth/domain/usecases/verify_role_code.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/ai/data/repositories/ai_repository_impl.dart';
import '../../features/ai/domain/repositories/ai_repository.dart';
import '../../features/college/data/repositories/college_repository_impl.dart';
import '../../features/college/domain/repositories/college_repository.dart'
    as college_domain;
import '../../features/groups/data/repositories/group_repository_impl.dart';
import '../../features/groups/domain/repositories/group_repository.dart';
import '../network/api_client.dart';
import '../presentation/controllers/theme_cubit.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core services — registered once for the lifetime of the app.
  sl.registerLazySingleton<LocalStorageService>(() => LocalStorageService());
  sl.registerLazySingleton<http.Client>(() => http.Client());
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(httpClient: sl<http.Client>()),
  );
  sl.registerLazySingleton<AiRepository>(
    () => AiRepositoryImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<college_domain.CollegeRepository>(
    () => CollegeRepositoryImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSource());
  sl.registerLazySingleton<AuthLocalDataSource>(() => AuthLocalDataSource());
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: sl<AuthRemoteDataSource>()),
  );
  sl.registerLazySingleton<VerifyRoleCode>(
    () => VerifyRoleCode(apiClient: sl<ApiClient>()),
  );
  // Theme cubit — persisted theme mode
  sl.registerLazySingleton(
    () => ThemeCubit(storage: sl<LocalStorageService>()),
  );

  // If the user already picked a college in a previous session, pre-register
  // the college-scoped deps so returning users never hit AuthNeedsCollegePick.
  // Use sl<LocalStorageService>() — same instance everywhere, no double reads.
  final String? savedCollegeId = await sl<LocalStorageService>().getCollegeId();
  if (savedCollegeId != null && savedCollegeId.isNotEmpty) {
    await initCollegeDependencies(savedCollegeId);
  }
  // If no college saved, leave UserRepository unregistered.
  // AuthCubit._handleLoggedInUser() will emit AuthNeedsCollegePick,
  // which shows CollegePickScreen → onCollegePicked() → initCollegeDependencies.

  // AuthCubit is a factory so each BlocProvider gets a fresh instance.
  sl.registerLazySingleton<AuthCubit>(
    () => AuthCubit(
      authRepository: sl<AuthRepository>(),
      userRepository: sl.isRegistered<UserRepository>()
          ? sl<UserRepository>()
          : null,
    ),
  );
}

Future<void> initCollegeDependencies(String collegeId) async {
  if (sl.isRegistered<UserRepository>()) {
    await sl.unregister<UserRepository>();
  }
  if (sl.isRegistered<GroupRepository>()) {
    await sl.unregister<GroupRepository>();
  }
  if (sl.isRegistered<NotificationService>()) {
    await sl.unregister<NotificationService>();
  }

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(collegeId: collegeId),
  );
  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(collegeId: collegeId),
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(userRepository: sl<UserRepository>()),
  );
}

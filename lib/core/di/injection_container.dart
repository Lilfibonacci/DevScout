import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/job_local_data_source.dart';
import '../../data/datasources/job_remote_data_source.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/repositories/job_repository.dart';
import '../../domain/usecases/get_cached_jobs_usecase.dart';
import '../../domain/usecases/scrape_jobs_usecase.dart';
import '../../domain/usecases/toggle_bookmark_usecase.dart';
import '../../presentation/bloc/jobs_bloc.dart';
import '../../presentation/bloc/locale_cubit.dart';
import '../../presentation/bloc/theme_cubit.dart';
import '../router/app_router.dart';
import '../services/background_worker_service.dart';
import '../services/deep_link_service.dart';
import '../services/notification_service.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencies({SharedPreferences? prefsOverride}) async {
  if (sl.isRegistered<SharedPreferences>()) {
    await sl.reset();
  }

  // External (SharedPreferences)
  final sharedPreferences =
      prefsOverride ?? await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);

  // Core Services
  sl.registerLazySingleton<DeepLinkService>(() => DeepLinkService());
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<BackgroundWorkerService>(
    () => BackgroundWorkerService(sharedPreferences: sl()),
  );

  // Data Sources
  sl.registerLazySingleton<JobLocalDataSource>(
    () => JobLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<JobRemoteDataSource>(
    () => JobRemoteDataSourceImpl(),
  );

  // Repository
  sl.registerLazySingleton<JobRepository>(
    () => JobRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      notificationService: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton<GetCachedJobsUseCase>(
    () => GetCachedJobsUseCase(sl()),
  );
  sl.registerLazySingleton<ScrapeJobsUseCase>(
    () => ScrapeJobsUseCase(sl()),
  );
  sl.registerLazySingleton<ToggleBookmarkUseCase>(
    () => ToggleBookmarkUseCase(sl()),
  );

  // Blocs & Cubits
  sl.registerLazySingleton<JobsBloc>(
    () => JobsBloc(
      getCachedJobsUseCase: sl(),
      scrapeJobsUseCase: sl(),
      toggleBookmarkUseCase: sl(),
    ),
  );
  sl.registerLazySingleton<ThemeCubit>(
    () => ThemeCubit(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<LocaleCubit>(
    () => LocaleCubit(sharedPreferences: sl()),
  );

  // Router (GoRouter)
  sl.registerLazySingleton<AppRouter>(() => AppRouter());
}

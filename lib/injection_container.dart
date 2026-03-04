import 'package:get_it/get_it.dart';
import 'data/datasources/local_database.dart';
import 'data/repositories/task_repository_impl.dart';
import 'domain/repositories/task_repository.dart';
import 'domain/usecases/task_usecases.dart';
import 'presentation/blocs/task_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Task
  // Bloc
  sl.registerFactory(
    () => TaskBloc(
      getTasks: sl(),
      addTask: sl(),
      updateTask: sl(),
      deleteTask: sl(),
      searchTasks: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetTasksUseCase(sl()));
  sl.registerLazySingleton(() => AddTaskUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTaskUseCase(sl()));
  sl.registerLazySingleton(() => DeleteTaskUseCase(sl()));
  sl.registerLazySingleton(() => SearchTasksUseCase(sl()));

  // Repository
  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(localDatabase: sl()),
  );

  // Data sources
  sl.registerLazySingleton(() => LocalDatabase.instance);
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/task_usecases.dart';

part 'task_event.dart';
part 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final GetTasksUseCase getTasks;
  final AddTaskUseCase addTask;
  final UpdateTaskUseCase updateTask;
  final DeleteTaskUseCase deleteTask;
  final SearchTasksUseCase searchTasks;

  TaskBloc({
    required this.getTasks,
    required this.addTask,
    required this.updateTask,
    required this.deleteTask,
    required this.searchTasks,
  }) : super(TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddNewTask>(_onAddTask);
    on<UpdateExistingTask>(_onUpdateTask);
    on<DeleteExistingTask>(_onDeleteTask);
    on<SearchTasksEvent>(_onSearchTasks);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    try {
      final tasks = await getTasks();
      emit(TaskLoaded(tasks));
    } catch (e) {
      emit(const TaskError('Failed to load tasks'));
    }
  }

  Future<void> _onAddTask(AddNewTask event, Emitter<TaskState> emit) async {
    try {
      await addTask(event.task);
      add(LoadTasks());
    } catch (e) {
      emit(const TaskError('Failed to add task'));
    }
  }

  Future<void> _onUpdateTask(
    UpdateExistingTask event,
    Emitter<TaskState> emit,
  ) async {
    try {
      await updateTask(event.task);
      add(LoadTasks());
    } catch (e) {
      emit(const TaskError('Failed to update task'));
    }
  }

  Future<void> _onDeleteTask(
    DeleteExistingTask event,
    Emitter<TaskState> emit,
  ) async {
    try {
      await deleteTask(event.id);
      add(LoadTasks());
    } catch (e) {
      emit(const TaskError('Failed to delete task'));
    }
  }

  Future<void> _onSearchTasks(
    SearchTasksEvent event,
    Emitter<TaskState> emit,
  ) async {
    emit(TaskLoading());
    try {
      final tasks = await searchTasks(event.keyword);
      emit(TaskLoaded(tasks));
    } catch (e) {
      emit(const TaskError('Failed to search tasks'));
    }
  }
}

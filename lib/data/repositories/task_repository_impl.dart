import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final SupabaseClient supabaseClient;

  TaskRepositoryImpl({required this.supabaseClient});

  @override
  Future<List<Task>> getTasks({
    String? boardId,
    String? query,
    String? status,
  }) async {
    var request = supabaseClient.from('tasks').select();

    if (boardId != null) {
      request = request.eq('board_id', boardId);
    }
    if (status != null) {
      request = request.eq('status', status);
    }
    if (query != null && query.isNotEmpty) {
      request = request.ilike('title', '%$query%');
    }

    final response = await request.order('created_at', ascending: false);
    return (response as List).map<Task>((e) => TaskModel.fromMap(e)).toList();
  }

  @override
  Future<void> addTask(Task task) async {
    final taskModel = TaskModel(
      id: task.id,
      boardId: task.boardId,
      title: task.title,
      description: task.description,
      status: task.status,
      assigneeId: task.assigneeId,
      creatorId: task.creatorId,
      createdAt: task.createdAt,
    );
    await supabaseClient.from('tasks').insert(taskModel.toMap());
  }

  @override
  Future<void> updateTask(Task task) async {
    final taskModel = TaskModel(
      id: task.id,
      boardId: task.boardId,
      title: task.title,
      description: task.description,
      status: task.status,
      assigneeId: task.assigneeId,
      creatorId: task.creatorId,
      createdAt: task.createdAt,
    );
    await supabaseClient
        .from('tasks')
        .update(taskModel.toMap())
        .eq('id', task.id);
  }

  @override
  Future<void> deleteTask(String id) async {
    await supabaseClient.from('tasks').delete().eq('id', id);
  }
}

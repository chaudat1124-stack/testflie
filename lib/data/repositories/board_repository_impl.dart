import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/board.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../models/board_model.dart';

class BoardRepositoryImpl implements BoardRepository {
  final SupabaseClient supabaseClient;

  BoardRepositoryImpl({required this.supabaseClient});

  @override
  Future<List<Board>> getBoards() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return [];

    // Tìm các bảng do user sỡ hữu
    final ownerResponse = await supabaseClient
        .from('boards')
        .select()
        .eq('owner_id', userId);

    // Tìm các bảng mà user là thành viên
    final memberResponse = await supabaseClient
        .from('board_members')
        .select('boards(*)')
        .eq('user_id', userId);

    final Map<String, BoardModel> boardsMap = {};

    for (var row in (ownerResponse as List)) {
      final board = BoardModel.fromMap(row);
      boardsMap[board.id] = board;
    }

    for (var row in (memberResponse as List)) {
      if (row['boards'] != null) {
        final board = BoardModel.fromMap(row['boards']);
        boardsMap[board.id] = board;
      }
    }

    final boards = List<Board>.from(boardsMap.values);
    boards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return boards;
  }

  @override
  Future<void> addBoard(Board board) async {
    final boardModel = BoardModel(
      id: board.id,
      title: board.title,
      ownerId: board.ownerId,
      createdAt: board.createdAt,
    );
    await supabaseClient.from('boards').insert(boardModel.toMap());

    // Tự động thêm owner vào board_members với quyền admin
    await supabaseClient.from('board_members').insert({
      'board_id': board.id,
      'user_id': board.ownerId,
      'role': 'admin',
    });
  }

  @override
  Future<void> updateBoard(Board board) async {
    final boardModel = BoardModel(
      id: board.id,
      title: board.title,
      ownerId: board.ownerId,
      createdAt: board.createdAt,
    );
    await supabaseClient
        .from('boards')
        .update(boardModel.toMap())
        .eq('id', board.id);
  }

  @override
  Future<void> deleteBoard(String id) async {
    await supabaseClient.from('boards').delete().eq('id', id);
  }

  @override
  Future<void> addMember(String boardId, String email) async {
    // 1. Tìm user bằng email trong bảng profiles
    final profileResponse = await supabaseClient
        .from('profiles')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (profileResponse == null) {
      throw Exception('Không tìm thấy người dùng với email $email.');
    }

    final userId = profileResponse['id'];

    // 2. Kiểm tra xem đã là member chưa
    final existingMember = await supabaseClient
        .from('board_members')
        .select()
        .eq('board_id', boardId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('Người dùng này đã có trong bảng.');
    }

    // 3. Thêm vào board_members
    await supabaseClient.from('board_members').insert({
      'board_id': boardId,
      'user_id': userId,
      'role': 'member',
    });
  }

  @override
  Future<List<UserModel>> getBoardMembers(String boardId) async {
    // 1. Fetch board members
    final memberResponse = await supabaseClient
        .from('board_members')
        .select('user_id, role')
        .eq('board_id', boardId);

    final memberRows = memberResponse as List;
    if (memberRows.isEmpty) return [];

    // Extract user IDs
    final userIds = memberRows.map((e) => e['user_id'] as String).toList();

    // 2. Fetch profiles for those user IDs
    final profileResponse = await supabaseClient
        .from('profiles')
        .select()
        .filter('id', 'in', userIds);

    final profiles = profileResponse as List;
    final members = <UserModel>[];

    for (var profile in profiles) {
      members.add(
        UserModel(
          id: profile['id'],
          email: profile['email'] ?? '',
          displayName: profile['display_name'],
          avatarUrl: profile['avatar_url'],
        ),
      );
    }
    return members;
  }

  @override
  Future<void> removeMember(String boardId, String userId) async {
    await supabaseClient
        .from('board_members')
        .delete()
        .eq('board_id', boardId)
        .eq('user_id', userId);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user.dart' as user_ent;
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient supabaseClient;

  AuthRepositoryImpl({required this.supabaseClient});

  @override
  Stream<user_ent.UserModel?> get authStateChanges {
    return supabaseClient.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return user_ent.UserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        avatarUrl: user.userMetadata?['avatar_url'],
      );
    });
  }

  @override
  user_ent.UserModel? getCurrentUser() {
    final user = supabaseClient.auth.currentUser;
    if (user == null) return null;
    return user_ent.UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
    );
  }

  @override
  Future<user_ent.UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user!;
    return user_ent.UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
    );
  }

  @override
  Future<void> signOut() async {
    await supabaseClient.auth.signOut();
  }

  @override
  Future<user_ent.UserModel> signUp({
    required String email,
    required String password,
  }) async {
    final response = await supabaseClient.auth.signUp(
      email: email,
      password: password,
      // You can add data like displayName if required in userMetadata
    );
    final user = response.user!;

    // Tạo record trong bảng profiles tự động sau khi signUp qua triggers hoặc tự insert
    // Ở đây supabase sẽ cho phép insert (do auth.uid() == id)
    await supabaseClient.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'display_name': email.split('@')[0],
    });

    return user_ent.UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: email.split('@')[0],
      avatarUrl: null,
    );
  }
}

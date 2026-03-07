import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';

class EmptyDashboardView extends StatefulWidget {
  final VoidCallback onAddBoard;
  final VoidCallback onOpenMenu;

  const EmptyDashboardView({
    super.key,
    required this.onAddBoard,
    required this.onOpenMenu,
  });

  @override
  State<EmptyDashboardView> createState() => _EmptyDashboardViewState();
}

class _EmptyDashboardViewState extends State<EmptyDashboardView> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;

  String _displayName = 'Nguoi dung';
  String _email = '';
  String _bio = '';
  String? _avatarUrl;

  int _ownedBoards = 0;
  int _joinedBoards = 0;
  int _assignedTasks = 0;
  int _doneTasks = 0;
  int _friendCount = 0;
  int _unreadNotifications = 0;

  bool _isMissingColumnError(Object error) {
    return error is PostgrestException && error.code == '42703';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final currentUser = _client.auth.currentUser;
    final authState = context.read<AuthBloc>().state;
    final userId = currentUser?.id ?? (authState is Authenticated ? authState.user.id : null);
    final authEmail =
        currentUser?.email ?? (authState is Authenticated ? authState.user.email : null);

    if (userId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _displayName = (authEmail ?? 'Nguoi dung').split('@').first;
        _email = authEmail ?? '';
      });
    }

    try {
      Map<String, dynamic>? profile;
      try {
        final response = await _client
            .from('profiles')
            .select('display_name,email,avatar_url,bio')
            .eq('id', userId)
            .maybeSingle();
        profile = response;
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        final response = await _client
            .from('profiles')
            .select('display_name,email,avatar_url')
            .eq('id', userId)
            .maybeSingle();
        profile = response;
      }

      int ownedBoards = 0;
      int joinedBoards = 0;
      int assignedTasksCount = 0;
      int doneTasksCount = 0;
      int friendCount = 0;
      int unreadNotifications = 0;

      try {
        final ownedBoardsResponse = await _client
            .from('boards')
            .select('id')
            .eq('owner_id', userId);
        ownedBoards = (ownedBoardsResponse as List).length;
      } catch (_) {}

      try {
        final joinedBoardsResponse = await _client
            .from('board_members')
            .select('board_id')
            .eq('user_id', userId);
        joinedBoards = (joinedBoardsResponse as List).length;
      } catch (_) {}

      try {
        final assignedTasksResponse = await _client
            .from('tasks')
            .select('id,status')
            .eq('assignee_id', userId);
        final assignedTasks = assignedTasksResponse as List;
        assignedTasksCount = assignedTasks.length;
        doneTasksCount = assignedTasks
            .where((item) => (item as Map<String, dynamic>)['status'] == 'done')
            .length;
      } catch (_) {}

      try {
        final friendResponse = await _client
            .from('friendships')
            .select('friend_id')
            .eq('user_id', userId);
        friendCount = (friendResponse as List).length;
      } catch (_) {}

      try {
        final unreadNotificationsResponse = await _client
            .from('user_notifications')
            .select('id')
            .eq('user_id', userId)
            .eq('is_read', false);
        unreadNotifications = (unreadNotificationsResponse as List).length;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _displayName =
            (profile?['display_name'] as String?) ??
            ((profile?['email'] as String?)?.split('@').first ?? _displayName);
        _email = (profile?['email'] as String?) ?? _email;
        _bio = (profile?['bio'] as String?) ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;

        _ownedBoards = ownedBoards;
        _joinedBoards = joinedBoards;
        _assignedTasks = assignedTasksCount;
        _doneTasks = doneTasksCount;
        _friendCount = friendCount;
        _unreadNotifications = unreadNotifications;
      });
    } catch (_) {
      // Keep auth fallback values.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildStatsGrid(),
          const SizedBox(height: 14),
          _buildCompletionChartCard(),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildAccountActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.blueAccent.withOpacity(0.15),
            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
            child: _avatarUrl == null
                ? Text(
                    _displayName.isEmpty ? 'N' : _displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isEmpty ? 'Chua co email' : _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                if (_bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard('Bang so huu', _ownedBoards.toString(), Icons.dashboard_customize),
        _statCard('Bang tham gia', _joinedBoards.toString(), Icons.group_outlined),
        _statCard('Task duoc giao', _assignedTasks.toString(), Icons.task_alt_outlined),
        _statCard('Task hoan thanh', _doneTasks.toString(), Icons.check_circle_outline),
        _statCard('So ban be', _friendCount.toString(), Icons.people_outline_rounded),
        _statCard('Thong bao moi', _unreadNotifications.toString(), Icons.notifications_none),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildCompletionChartCard() {
    final progress = _assignedTasks == 0 ? 0.0 : (_doneTasks / _assignedTasks).clamp(0.0, 1.0);
    final percentText = '${(progress * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
                Container(
                  width: 94,
                  height: 94,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      percentText,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ti le hoan thanh task',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tinh theo task duoc giao va task da xong',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hanh dong nhanh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onAddBoard,
                  icon: const Icon(Icons.add),
                  label: const Text('Tao bang'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenMenu,
                  icon: const Icon(Icons.menu_open),
                  label: const Text('Mo menu'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tai khoan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh),
            title: const Text('Lam moi du lieu'),
            onTap: _loadProfileData,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cai dat'),
            onTap: () async {
              await Navigator.pushNamed(context, '/settings');
              await _loadProfileData();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined),
            title: const Text('Ban be'),
            onTap: () async {
              await Navigator.pushNamed(context, '/friends');
              await _loadProfileData();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Dang xuat', style: TextStyle(color: Colors.redAccent)),
            onTap: () => context.read<AuthBloc>().add(SignOutRequested()),
          ),
        ],
      ),
    );
  }
}

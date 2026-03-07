import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/friend_user.dart';
import 'chat_screen.dart';

class FriendProfileScreen extends StatefulWidget {
  final FriendUser friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loadingStats = true;
  int _ownedBoards = 0;
  int _joinedBoards = 0;
  int _assignedTasks = 0;
  int _doneTasks = 0;
  int _friendCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  String _statusText() {
    if (widget.friend.isOnline) return 'Dang online';
    final lastSeen = widget.friend.lastSeenAt;
    if (lastSeen == null) return 'Offline';

    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Vua hoat dong';
    if (diff.inMinutes < 60) return 'Hoat dong ${diff.inMinutes} phut truoc';
    if (diff.inHours < 24) return 'Hoat dong ${diff.inHours} gio truoc';
    return 'Hoat dong ${diff.inDays} ngay truoc';
  }

  String _lastSeenDetail() {
    final lastSeen = widget.friend.lastSeenAt;
    if (lastSeen == null) return 'Chua co du lieu';

    final local = lastSeen.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _loadStats() async {
    final userId = widget.friend.id;

    try {
      int ownedBoards = 0;
      int joinedBoards = 0;
      int assignedTasks = 0;
      int doneTasks = 0;
      int friendCount = 0;

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
        final assigned = assignedTasksResponse as List;
        assignedTasks = assigned.length;
        doneTasks = assigned
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

      if (!mounted) return;
      setState(() {
        _ownedBoards = ownedBoards;
        _joinedBoards = joinedBoards;
        _assignedTasks = assignedTasks;
        _doneTasks = doneTasks;
        _friendCount = friendCount;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.friend.displayName ?? widget.friend.email;
    final statusText = _statusText();

    return Scaffold(
      appBar: AppBar(title: const Text('Trang ca nhan')),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Colors.blueAccent.withOpacity(0.15),
                backgroundImage: widget.friend.avatarUrl != null
                    ? NetworkImage(widget.friend.avatarUrl!)
                    : null,
                child: widget.friend.avatarUrl == null
                    ? Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.friend.email,
                style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.friend.isOnline ? Icons.circle : Icons.schedule_rounded,
                    size: 14,
                    color: widget.friend.isOnline
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: widget.friend.isOnline
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(friend: widget.friend),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Nhan tin'),
              ),
            ),
            const SizedBox(height: 16),
            _infoCard(
              icon: widget.friend.isOnline ? Icons.circle : Icons.schedule_rounded,
              title: 'Trang thai hoat dong',
              value: statusText,
              subtitle: widget.friend.isOnline
                  ? 'Dang hoat dong ngay luc nay'
                  : 'Lan cuoi: ${_lastSeenDetail()}',
              valueColor: widget.friend.isOnline
                  ? Colors.green.shade700
                  : Colors.grey.shade700,
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.mail_outline_rounded,
              title: 'Lien he',
              value: widget.friend.email,
              subtitle: 'Email da xac minh tu tai khoan',
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.badge_outlined,
              title: 'Thong tin tai khoan',
              value: widget.friend.displayName?.trim().isNotEmpty == true
                  ? widget.friend.displayName!.trim()
                  : 'Chua dat ten hien thi',
              subtitle: 'ID: ${widget.friend.id}',
            ),
            if ((widget.friend.bio ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _infoCard(
                icon: Icons.notes_rounded,
                title: 'Mo ta ban than',
                value: widget.friend.bio!.trim(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Thong ke',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                if (_loadingStats)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard('Bang so huu', _ownedBoards.toString(), Icons.dashboard_customize),
                _statCard('Bang tham gia', _joinedBoards.toString(), Icons.group_outlined),
                _statCard('Task duoc giao', _assignedTasks.toString(), Icons.task_alt_outlined),
                _statCard('Task hoan thanh', _doneTasks.toString(), Icons.check_circle_outline),
                _statCard('So ban be', _friendCount.toString(), Icons.people_outline_rounded),
              ],
            ),
            const SizedBox(height: 14),
            _completionChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;
    return Container(
      width: width,
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

  Widget _completionChartCard() {
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
                  style: TextStyle(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

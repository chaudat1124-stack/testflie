import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/friend_repository.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_user.dart';
import 'chat_screen.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _repo = FriendRepository();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<FriendUser> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getFriends(),
        _repo.getIncomingRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendUser>;
        _incomingRequests = results[1] as List<FriendRequest>;
      });
    } catch (e) {
      _showSnack('Không tải được dữ liệu bạn bè: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Vui lòng nhập email.');
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.sendFriendRequestByEmail(email);
      _emailController.clear();
      _showSnack('Đã gửi lời mời kết bạn.');
      await _refresh();
    } catch (e) {
      _showSnack('Không thể gửi lời mời: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _respond(FriendRequest request, bool accept) async {
    try {
      await _repo.respondToRequest(requestId: request.id, accept: accept);
      _showSnack(accept ? 'Đã chấp nhận lời mời.' : 'Đã từ chối lời mời.');
      await _refresh();
    } catch (e) {
      _showSnack('Không thể xử lý lời mời: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSendRequestCard(),
                const SizedBox(height: 16),
                _buildIncomingRequestsCard(),
                const SizedBox(height: 16),
                _buildFriendsCard(),
              ],
            ),
    );
  }

  Widget _buildSendRequestCard() {
    return _sectionCard(
      title: 'Kết bạn bằng email',
      icon: Icons.person_add_alt_1_rounded,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Nhập email người muốn kết bạn',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _sending ? null : _sendRequest,
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsCard() {
    return _sectionCard(
      title: 'Lời mời đang chờ',
      icon: Icons.mark_email_unread_outlined,
      child: _incomingRequests.isEmpty
          ? const Text('Không có lời mời nào.')
          : Column(
              children: _incomingRequests.map((request) {
                final display = request.senderDisplayName ?? request.senderEmail;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(display),
                  subtitle: Text(request.senderEmail),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => _respond(request, false),
                        child: const Text('Từ chối'),
                      ),
                      ElevatedButton(
                        onPressed: () => _respond(request, true),
                        child: const Text('Chấp nhận'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFriendsCard() {
    return _sectionCard(
      title: 'Danh sách bạn bè',
      icon: Icons.group_outlined,
      child: _friends.isEmpty
          ? const Text('Bạn chưa có bạn bè nào.')
          : Column(
              children: _friends.map((friend) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendProfileScreen(friend: friend),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    backgroundImage: friend.avatarUrl != null
                        ? NetworkImage(friend.avatarUrl!)
                        : null,
                    child: friend.avatarUrl == null
                        ? Text(
                            (friend.displayName ?? friend.email)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(friend.displayName ?? friend.email),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.email),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _buildStatusText(friend),
                            style: TextStyle(
                              fontSize: 12,
                              color: friend.isOnline
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            friend.isOnline ? Icons.circle : Icons.schedule_rounded,
                            size: 12,
                            color: friend.isOnline
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    tooltip: 'Chat',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(friend: friend),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _buildStatusText(FriendUser friend) {
    if (friend.isOnline) return 'Đang online';
    final lastSeen = friend.lastSeenAt;
    if (lastSeen == null) return 'Offline';

    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Vừa hoạt động';
    if (diff.inMinutes < 60) return 'Hoạt động ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Hoạt động ${diff.inHours} giờ trước';
    return 'Hoạt động ${diff.inDays} ngày trước';
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

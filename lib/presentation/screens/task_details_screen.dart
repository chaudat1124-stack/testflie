import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_preferences.dart';
import '../../injection_container.dart';
import '../../data/repositories/task_interaction_repository.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_attachment.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/entities/task_rating.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../widgets/board_member_select_dialog.dart';
import '../widgets/user_avatar.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  final Color accentColor;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.accentColor,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _repo = sl<TaskInteractionRepository>();
  final _commentController = TextEditingController();

  late Task _currentTask;
  List<TaskComment> _comments = [];
  List<TaskAttachment> _attachments = [];
  bool _loadingComments = true;
  bool _loadingAttachments = true;
  bool _sendingComment = false;
  bool _uploadingAttachment = false;
  bool _loadingRating = true;
  bool _savingRating = false;
  TaskRating? _myRating;
  double _avgRating = 0;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _loadComments();
    _loadAttachments();
    _loadRatings();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await _repo.getComments(_currentTask.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
      });
    } catch (_) {
      _showSnack(
        AppPreferences.tr(
          'Không tải được bình luận',
          'Failed to load comments',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingComments = false);
      }
    }
  }

  Future<void> _loadAttachments() async {
    setState(() => _loadingAttachments = true);
    try {
      final attachments = await _repo.getAttachments(_currentTask.id);
      if (!mounted) return;
      setState(() {
        _attachments = attachments;
      });
    } catch (_) {
      _showSnack(
        AppPreferences.tr(
          'Không tải được tệp đính kèm',
          'Failed to load attachments',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingAttachments = false);
      }
    }
  }

  Future<void> _loadRatings() async {
    setState(() => _loadingRating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final stats = await _repo.getRatingStats(_currentTask.id);
      TaskRating? myRating;
      if (userId != null) {
        myRating = await _repo.getMyRating(
          taskId: _currentTask.id,
          userId: userId,
        );
      }
      if (!mounted) return;
      setState(() {
        _avgRating = stats.$1;
        _ratingCount = stats.$2;
        _myRating = myRating;
      });
    } catch (_) {
      _showSnack(
        AppPreferences.tr('Không tải được đánh giá', 'Failed to load ratings'),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingRating = false);
      }
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        AppPreferences.tr('Cần đăng nhập để bình luận', 'Login to comment'),
      );
      return;
    }

    setState(() => _sendingComment = true);
    try {
      final comment = await _repo.addComment(
        taskId: _currentTask.id,
        userId: userId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _commentController.clear();
      });
    } catch (_) {
      _showSnack(AppPreferences.tr('Gửi bình luận thất bại', 'Comment failed'));
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        AppPreferences.tr('Cần đăng nhập để tải tệp', 'Login to upload'),
      );
      return;
    }

    final file = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (file == null || file.files.isEmpty) return;

    final picked = file.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack(
        AppPreferences.tr('Không đọc được dữ liệu tệp', 'Invalid file data'),
      );
      return;
    }

    setState(() => _uploadingAttachment = true);
    try {
      final uploaded = await _repo.uploadAttachment(
        boardId: _currentTask.boardId,
        taskId: _currentTask.id,
        fileName: picked.name,
        bytes: bytes,
        uploaderId: userId,
        contentType: lookupMimeType(picked.name),
      );
      if (!mounted) return;
      setState(() {
        _attachments = [uploaded, ..._attachments];
      });
      _showSnack(AppPreferences.tr('Tải tệp thành công', 'File uploaded'));
    } catch (_) {
      _showSnack(AppPreferences.tr('Tải tệp thất bại', 'Upload failed'));
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _openAttachment(TaskAttachment attachment) async {
    final url = Uri.tryParse(attachment.publicUrl);
    if (url == null) {
      _showSnack(
        AppPreferences.tr('Liên kết tệp không hợp lệ', 'Invalid file link'),
      );
      return;
    }
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack(AppPreferences.tr('Không mở được tệp', 'Cannot open file'));
    }
  }

  Future<void> _deleteAttachment(TaskAttachment attachment) async {
    try {
      await _repo.deleteAttachment(attachment);
      if (!mounted) return;
      setState(() {
        _attachments = _attachments
            .where((item) => item.id != attachment.id)
            .toList();
      });
      _showSnack(AppPreferences.tr('Đã xóa tệp', 'File deleted'));
    } catch (_) {
      _showSnack(AppPreferences.tr('Xóa tệp thất bại', 'Delete failed'));
    }
  }

  Future<void> _rateTask(int score) async {
    if (score < 1 || score > 5) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        AppPreferences.tr('Cần đăng nhập để đánh giá', 'Login to rate'),
      );
      return;
    }
    setState(() => _savingRating = true);
    try {
      await _repo.upsertRating(
        taskId: _currentTask.id,
        userId: userId,
        rating: score,
      );
      await _loadRatings();
      _showSnack(AppPreferences.tr('Đã cập nhật đánh giá', 'Rating updated'));
    } catch (_) {
      _showSnack(
        AppPreferences.tr('Cập nhật đánh giá thất bại', 'Rating failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _savingRating = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    if (status == 'todo') return AppPreferences.tr('Cần làm', 'To Do');
    if (status == 'doing') return AppPreferences.tr('Đang làm', 'Doing');
    return AppPreferences.tr('Hoàn thành', 'Done');
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          AppPreferences.tr('Chi tiết thẻ', 'Task Details'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAssigneeSection(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                  _buildRatingSection(),
                  const SizedBox(height: 24),
                  _buildAttachmentsSection(),
                  const SizedBox(height: 24),
                  _buildCommentsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentTask.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBadge(
                _statusLabel(_currentTask.status),
                widget.accentColor.withOpacity(0.12),
                widget.accentColor,
              ),
              _buildBadge(
                _formatDate(_currentTask.createdAt),
                Colors.grey.withOpacity(0.08),
                const Color(0xFF64748B),
              ),
              if (_currentTask.dueAt != null)
                _buildBadge(
                  AppPreferences.tr(
                    'Hạn: ${_formatDate(_currentTask.dueAt!.toIso8601String())}',
                    'Due: ${_formatDate(_currentTask.dueAt!.toIso8601String())}',
                  ),
                  Colors.orange.withOpacity(0.12),
                  Colors.orange[800]!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildAssigneeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          AppPreferences.tr('NGƯỜI THỰC HIỆN', 'ASSIGNEE'),
          trailing: TextButton.icon(
            onPressed: () async {
              final selectedUserId = await showDialog<String>(
                context: context,
                builder: (context) => BoardMemberSelectDialog(
                  boardId: _currentTask.boardId,
                  currentAssigneeId: _currentTask.assigneeId,
                ),
              );
              if (selectedUserId == null) return;

              final updatedTask = Task(
                id: _currentTask.id,
                boardId: _currentTask.boardId,
                title: _currentTask.title,
                description: _currentTask.description,
                status: _currentTask.status,
                creatorId: _currentTask.creatorId,
                createdAt: _currentTask.createdAt,
                assigneeId: selectedUserId.isEmpty ? null : selectedUserId,
                dueAt: _currentTask.dueAt,
              );

              setState(() => _currentTask = updatedTask);
              if (!mounted) return;
              context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(AppPreferences.tr('Thay đổi', 'Change')),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child:
              _currentTask.assigneeId != null &&
                  _currentTask.assigneeId!.isNotEmpty
              ? UserAvatar(
                  userId: _currentTask.assigneeId!,
                  radius: 24,
                  showName: true,
                )
              : Text(
                  AppPreferences.tr('Chưa giao cho ai', 'Unassigned'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppPreferences.tr('MÔ TẢ CHI TIẾT', 'DESCRIPTION')),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _currentTask.description.isEmpty
                ? AppPreferences.tr(
                    'Chưa có mô tả cho task này.',
                    'No description for this task.',
                  )
                : _currentTask.description,
            style: TextStyle(
              fontSize: 15,
              color: _currentTask.description.isEmpty
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF334155),
              fontStyle: _currentTask.description.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final myScore = _myRating?.rating ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppPreferences.tr('ĐÁNH GIÁ TASK', 'TASK RATING')),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _loadingRating
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final active = star <= myScore;
                        return IconButton(
                          onPressed: _savingRating
                              ? null
                              : () => _rateTask(star),
                          iconSize: 32,
                          icon: Icon(
                            active
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: active
                                ? Colors.amber[600]
                                : const Color(0xFFCBD5E1),
                          ),
                          tooltip: '$star ${AppPreferences.tr('sao', 'stars')}',
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ratingCount == 0
                          ? AppPreferences.tr(
                              'Chưa có đánh giá',
                              'No ratings yet',
                            )
                          : '${AppPreferences.tr('Trung bình', 'Average')}: ${_avgRating.toStringAsFixed(1)}/5 ($_ratingCount ${AppPreferences.tr('đánh giá', 'ratings')})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          AppPreferences.tr('TỆP ĐÍNH KÈM', 'ATTACHMENTS'),
          trailing: TextButton.icon(
            onPressed: _uploadingAttachment ? null : _pickAndUploadAttachment,
            icon: _uploadingAttachment
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline, size: 16),
            label: Text(AppPreferences.tr('Thêm tệp', 'Add file')),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _loadingAttachments
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _attachments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      AppPreferences.tr(
                        'Chưa có tệp đính kèm',
                        'No attachments yet',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: _attachments.map((item) {
                    return ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file_outlined,
                        color: Color(0xFF64748B),
                      ),
                      title: Text(
                        item.fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatDate(item.createdAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: AppPreferences.tr('Mở', 'Open'),
                            onPressed: () => _openAttachment(item),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            tooltip: AppPreferences.tr('Xóa', 'Delete'),
                            onPressed: () => _deleteAttachment(item),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppPreferences.tr('BÌNH LUẬN', 'COMMENTS')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_loadingComments)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      AppPreferences.tr('Chưa có bình luận', 'No comments yet'),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  itemBuilder: (context, index) {
                    final item = _comments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserAvatar(userId: item.userId, radius: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Spacer(),
                                    Text(
                                      _formatDate(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item.content,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: AppPreferences.tr(
                          'Nhập bình luận...',
                          'Write a comment...',
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: widget.accentColor,
                    child: IconButton(
                      onPressed: _sendingComment ? null : _addComment,
                      icon: _sendingComment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

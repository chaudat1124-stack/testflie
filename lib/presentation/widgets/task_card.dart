import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/task_interaction_repository.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_attachment.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/entities/task_rating.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import 'board_member_select_dialog.dart';
import 'user_avatar.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Color accentColor;

  const TaskCard({super.key, required this.task, required this.accentColor});

  String _formatDueAt(DateTime dueAt) {
    return '${dueAt.day.toString().padLeft(2, '0')}/'
        '${dueAt.month.toString().padLeft(2, '0')} '
        '${dueAt.hour.toString().padLeft(2, '0')}:'
        '${dueAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.dueAt != null &&
        task.status != 'done' &&
        task.dueAt!.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => _TaskDetailsDialog(task: task, accentColor: accentColor),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accentColor, width: 3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => context.read<TaskBloc>().add(DeleteTaskEvent(task.id)),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.close, color: Colors.black26, size: 18),
                        ),
                      ),
                    ],
                  ),
                  if (task.assigneeId != null && task.assigneeId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (task.dueAt != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? Colors.red.withOpacity(0.12)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isOverdue
                                      ? Colors.red.withOpacity(0.4)
                                      : Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _formatDueAt(task.dueAt!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          const Spacer(),
                          UserAvatar(userId: task.assigneeId!, radius: 12),
                        ],
                      ),
                    ),
                  if ((task.assigneeId == null || task.assigneeId!.isEmpty) &&
                      task.dueAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.withOpacity(0.12)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isOverdue
                                ? Colors.red.withOpacity(0.4)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          _formatDueAt(task.dueAt!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskDetailsDialog extends StatefulWidget {
  final Task task;
  final Color accentColor;

  const _TaskDetailsDialog({required this.task, required this.accentColor});

  @override
  State<_TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<_TaskDetailsDialog> {
  final _repo = TaskInteractionRepository();
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
      _showSnack('Không tải được bình luận');
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
      _showSnack('Không tải được tệp đính kèm');
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
        myRating = await _repo.getMyRating(taskId: _currentTask.id, userId: userId);
      }
      if (!mounted) return;
      setState(() {
        _avgRating = stats.$1;
        _ratingCount = stats.$2;
        _myRating = myRating;
      });
    } catch (_) {
      _showSnack('Không tải được đánh giá');
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
      _showSnack('Cần đăng nhập để bình luận');
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
      _showSnack('Gửi bình luận thất bại');
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('Cần đăng nhập để tải tệp');
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
      _showSnack('Không đọc được dữ liệu tệp');
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
      _showSnack('Tải tệp thành công');
    } catch (_) {
      _showSnack('Tải tệp thất bại');
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _openAttachment(TaskAttachment attachment) async {
    final url = Uri.tryParse(attachment.publicUrl);
    if (url == null) {
      _showSnack('Liên kết tệp không hợp lệ');
      return;
    }
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack('Không mở được tệp');
    }
  }

  Future<void> _deleteAttachment(TaskAttachment attachment) async {
    try {
      await _repo.deleteAttachment(attachment);
      if (!mounted) return;
      setState(() {
        _attachments = _attachments.where((item) => item.id != attachment.id).toList();
      });
      _showSnack('Đã xóa tệp');
    } catch (_) {
      _showSnack('Xóa tệp thất bại');
    }
  }

  Future<void> _rateTask(int score) async {
    if (score < 1 || score > 5) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('Cần đăng nhập để đánh giá');
      return;
    }
    setState(() => _savingRating = true);
    try {
      await _repo.upsertRating(taskId: _currentTask.id, userId: userId, rating: score);
      await _loadRatings();
      _showSnack('Đã cập nhật đánh giá');
    } catch (_) {
      _showSnack('Cập nhật đánh giá thất bại');
    } finally {
      if (mounted) {
        setState(() => _savingRating = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    if (status == 'todo') return 'Cần làm';
    if (status == 'doing') return 'Đang làm';
    return 'Hoàn thành';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _currentTask.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(_currentTask.status),
                      style: TextStyle(
                        color: widget.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDate(_currentTask.createdAt),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Người thực hiện',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  TextButton.icon(
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
                      if (!context.mounted) return;
                      context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(_currentTask.assigneeId == null ? 'Giao việc' : 'Thay đổi'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _currentTask.assigneeId != null && _currentTask.assigneeId!.isNotEmpty
                    ? UserAvatar(userId: _currentTask.assigneeId!, radius: 20, showName: true)
                    : const Text('Chưa giao cho ai', style: TextStyle(color: Colors.black54)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mô tả chi tiết',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentTask.description.isEmpty ? 'Chưa có mô tả cho task này.' : _currentTask.description,
                  style: TextStyle(
                    color: _currentTask.description.isEmpty ? Colors.black45 : Colors.black87,
                    fontStyle: _currentTask.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildRatingSection(),
              const SizedBox(height: 20),
              _buildCommentsSection(),
              const SizedBox(height: 20),
              _buildAttachmentsSection(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bình luận',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: _loadingComments
              ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
              : _comments.isEmpty
              ? const Text('Chưa có bình luận', style: TextStyle(color: Colors.black54))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _comments.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = _comments[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.userId.isNotEmpty)
                            UserAvatar(userId: item.userId, radius: 14)
                          else
                            const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(item.createdAt),
                                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                                ),
                                const SizedBox(height: 2),
                                Text(item.content),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Nhập bình luận...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _sendingComment ? null : _addComment,
              icon: _sendingComment
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 16),
              label: const Text('Gửi'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final myScore = _myRating?.rating ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đánh giá task',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: _loadingRating
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ratingCount == 0
                          ? 'Chưa có đánh giá'
                          : 'Trung bình: ${_avgRating.toStringAsFixed(1)}/5 ($_ratingCount đánh giá)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final active = star <= myScore;
                        return IconButton(
                          onPressed: _savingRating ? null : () => _rateTask(star),
                          icon: Icon(
                            active ? Icons.star : Icons.star_border,
                            color: active ? Colors.amber[700] : Colors.grey,
                          ),
                          tooltip: '$star sao',
                        );
                      }),
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tệp đính kèm',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _uploadingAttachment ? null : _pickAndUploadAttachment,
              icon: _uploadingAttachment
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: const Text('Tải lên'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: _loadingAttachments
              ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
              : _attachments.isEmpty
              ? const Text('Chưa có tệp đính kèm', style: TextStyle(color: Colors.black54))
              : Column(
                  children: _attachments.map((item) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_formatDate(item.createdAt)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Mở',
                            onPressed: () => _openAttachment(item),
                            icon: const Icon(Icons.open_in_new, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            onPressed: () => _deleteAttachment(item),
                            icon: const Icon(Icons.delete_outline, size: 18),
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
}

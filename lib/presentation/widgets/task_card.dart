import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/task.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import 'user_avatar.dart';
import 'board_member_select_dialog.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Color accentColor;

  const TaskCard({super.key, required this.task, required this.accentColor});

  @override
  Widget build(BuildContext context) {
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
            onTap: () => _showTaskDetailsDialog(context),
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
                        onTap: () => context.read<TaskBloc>().add(
                          DeleteTaskEvent(task.id),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            color: Colors.black26,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.assigneeId != null && task.assigneeId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UserAvatar(userId: task.assigneeId!, radius: 12),
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

  void _showTaskDetailsDialog(BuildContext context) {
    // ID của task đại diện cho MillisecondsSinceEpoch lúc tạo thẻ.
    final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(task.id) ?? DateTime.now().millisecondsSinceEpoch,
    );
    final String formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} lúc ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    final String statusLabel = task.status == 'todo'
        ? 'Cần làm'
        : (task.status == 'doing' ? 'Đang làm' : 'Hoàn thành');

    showDialog(
      context: context,
      builder: (context) {
        // Tạo biến task nội bộ để Dialog có thể tự cập nhật UI bằng StatefulBuilder
        Task currentTask = task;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề & Nút đóng
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            currentTask.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.black54,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Huy hiệu trạng thái và thời gian tạo
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1),
                    ),

                    // Phần "Người thực hiện"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Người thực hiện',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final selectedUserId = await showDialog<String>(
                              context: context,
                              builder: (context) => BoardMemberSelectDialog(
                                boardId: currentTask.boardId,
                                currentAssigneeId: currentTask.assigneeId,
                              ),
                            );

                            if (selectedUserId != null) {
                              // Cập nhật local task
                              final updatedTask = Task(
                                id: currentTask.id,
                                boardId: currentTask.boardId,
                                title: currentTask.title,
                                description: currentTask.description,
                                status: currentTask.status,
                                creatorId: currentTask.creatorId,
                                createdAt: currentTask.createdAt,
                                assigneeId: selectedUserId.isEmpty
                                    ? null
                                    : selectedUserId,
                              );

                              // Cập nhật UI Dialog ngay lập tức
                              setState(() {
                                currentTask = updatedTask;
                              });

                              if (!context.mounted) return;

                              // Gửi Event cho Bloc lưu lên Database
                              context.read<TaskBloc>().add(
                                UpdateTaskEvent(updatedTask),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: Text(
                            currentTask.assigneeId != null
                                ? 'Thay đổi'
                                : 'Giao việc',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                      child:
                          currentTask.assigneeId != null &&
                              currentTask.assigneeId!.isNotEmpty
                          ? UserAvatar(
                              userId: currentTask.assigneeId!,
                              radius: 20,
                              showName: true,
                            )
                          : const Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.help_outline,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Chưa giao cho ai',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Phần mô tả
                    const Text(
                      'Mô tả chi tiết',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Text(
                        currentTask.description.isEmpty
                            ? 'Nhiệm vụ này chưa có mô tả. Thêm nội dung chi tiết để các thành viên khác dễ dàng nắm bắt thông tin công việc.'
                            : currentTask.description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: currentTask.description.isEmpty
                              ? Colors.black45
                              : Colors.black87,
                          fontStyle: currentTask.description.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Nút chỉnh sửa và đóng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Đã Hiểu'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }, // End StatefulBuilder builder
        ); // End StatefulBuilder
      }, // End showDialog builder
    ); // End showDialog
  }
}

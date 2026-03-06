import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../blocs/task_state.dart';
import '../blocs/board_bloc.dart';
import '../blocs/board_event.dart';
import '../blocs/board_state.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/board.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../widgets/empty_dashboard_view.dart';
import '../widgets/animated_menu_hint.dart';
import '../widgets/board_drawer.dart';
import '../widgets/task_card.dart';
import '../widgets/board_member_dialog.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  String? selectedBoardId;
  String selectedLandscapeStatus = 'todo';
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.88);

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (selectedBoardId != null) {
      context.read<TaskBloc>().add(
        LoadTasks(boardId: selectedBoardId, query: searchController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BoardBloc, BoardState>(
          listener: (context, state) {
            if (state is BoardLoaded) {
              if (state.boards.isEmpty) {
                setState(() {
                  selectedBoardId = null;
                });
              } else {
                // Tự động chọn Bảng nếu chưa chọn, hoặc nếu Bảng đang chọn đã bị xóa
                final isBoardCurrentSelectedExists = state.boards.any(
                  (b) => b.id == selectedBoardId,
                );

                if (selectedBoardId == null || !isBoardCurrentSelectedExists) {
                  // Mặc định chọn Bảng mới nhất (nằm ở cuối list)
                  _selectBoard(state.boards.last.id);
                }
              }
            }
          },
        ),
        BlocListener<TaskBloc, TaskState>(
          listener: (context, state) {
            if (state is TaskLoaded && isSearching && state.tasks.isNotEmpty) {
              // Khi đang tìm kiếm, tự động Focus vào Tab chứa kết quả đầu tiên ở màn hình ngang
              if (selectedLandscapeStatus != state.tasks.first.status) {
                setState(() {
                  selectedLandscapeStatus = state.tasks.first.status;
                });
              }
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: selectedBoardId == null ? 140 : 56,
          leading: AnimatedMenuHint(showHint: selectedBoardId == null),
          title: isSearching
              ? TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm công việc...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 18),
                  autofocus: true,
                )
              : const Text(
                  'KanbanFlow',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
          centerTitle: !isSearching,
          actions: [
            if (selectedBoardId != null)
              BlocBuilder<BoardBloc, BoardState>(
                builder: (context, state) {
                  if (state is BoardLoaded) {
                    final currentBoard = state.boards.firstWhere(
                      (b) => b.id == selectedBoardId,
                      orElse: () => state.boards.first,
                    );
                    return IconButton(
                      icon: const Icon(Icons.group_add_outlined),
                      tooltip: 'Thành viên',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => BoardMemberDialog(
                            boardId: currentBoard.id,
                            ownerId: currentBoard.ownerId,
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (isSearching) {
                    isSearching = false;
                    searchController.clear();
                  } else {
                    isSearching = true;
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (selectedBoardId != null) {
                  context.read<TaskBloc>().add(
                    LoadTasks(
                      boardId: selectedBoardId,
                      query: searchController.text,
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: BoardDrawer(
          selectedBoardId: selectedBoardId,
          onSelectBoard: _selectBoard,
          onAddBoard: _showAddBoardDialog,
          onDeleteBoard: _showDeleteBoardDialog,
        ),
        body: selectedBoardId == null
            ? EmptyDashboardView(
                onAddBoard: () => _showAddBoardDialog(context),
                onOpenMenu: () => Scaffold.of(context).openDrawer(),
              )
            : _buildBoardContent(context),
        floatingActionButton: selectedBoardId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Thêm thẻ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.blueAccent,
                elevation: 4,
              ),
      ),
    );
  }

  void _selectBoard(String id) {
    setState(() {
      selectedBoardId = id;
    });
    context.read<TaskBloc>().add(
      LoadTasks(boardId: id, query: searchController.text),
    );
  }

  Widget _buildBoardContent(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TaskLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen =
                  constraints.maxWidth > 600 ||
                  MediaQuery.of(context).orientation == Orientation.landscape;

              if (isWideScreen) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột Menu bên trái
                    Container(
                      width: 250,
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildMenuItem(
                            'Cần làm',
                            'todo',
                            Colors.blueAccent,
                            state.tasks,
                          ),
                          _buildMenuItem(
                            'Đang làm',
                            'doing',
                            Colors.orangeAccent,
                            state.tasks,
                          ),
                          _buildMenuItem(
                            'Hoàn thành',
                            'done',
                            Colors.teal,
                            state.tasks,
                          ),
                        ],
                      ),
                    ),
                    // Kẻ dọc phân cách
                    Container(width: 1, color: Colors.grey.withOpacity(0.2)),
                    // Khu vực chứa thẻ bên phải
                    Expanded(
                      child: Container(
                        color: Colors.grey[50], // Nền nhạt cho khu vực thẻ
                        child: _buildLandscapeTaskContent(
                          context,
                          state.tasks,
                          selectedLandscapeStatus,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Mặc định: Giao diện dọc (Portrait) - Menu sổ xuống
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildColumn(
                          context,
                          'Cần làm',
                          'todo',
                          state.tasks,
                          Colors.blueAccent,
                        ),
                        const SizedBox(height: 24),
                        _buildColumn(
                          context,
                          'Đang làm',
                          'doing',
                          state.tasks,
                          Colors.orangeAccent,
                        ),
                        const SizedBox(height: 24),
                        _buildColumn(
                          context,
                          'Hoàn thành',
                          'done',
                          state.tasks,
                          Colors.teal,
                        ),
                        const SizedBox(height: 60), // Space for FAB
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else if (state is TaskError) {
          return Center(child: Text('Lỗi: ${state.message}'));
        }
        return const Center(child: Text('Chưa có dữ liệu'));
      },
    );
  }

  Widget _buildMenuItem(
    String title,
    String status,
    Color accentColor,
    List<Task> allTasks,
  ) {
    final isSelected = selectedLandscapeStatus == status;
    final tasksCount = allTasks.where((t) => t.status == status).length;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status,
          assigneeId: droppedTask.assigneeId,
          creatorId: droppedTask.creatorId,
          createdAt: droppedTask.createdAt,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return InkWell(
          onTap: () {
            setState(() {
              selectedLandscapeStatus = status;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isHovering
                  ? accentColor.withOpacity(0.2)
                  : (isSelected
                        ? accentColor.withOpacity(0.1)
                        : Colors.transparent),
              border: Border(
                left: BorderSide(
                  color: isHovering || isSelected
                      ? accentColor
                      : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isHovering || isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 16,
                      color: isHovering || isSelected
                          ? accentColor
                          : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$tasksCount',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandscapeTaskContent(
    BuildContext context,
    List<Task> allTasks,
    String status,
  ) {
    final tasks = allTasks.where((t) => t.status == status).toList();
    Color accentColor = status == 'todo'
        ? Colors.blueAccent
        : (status == 'doing' ? Colors.orangeAccent : Colors.teal);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status,
          assigneeId: droppedTask.assigneeId,
          creatorId: droppedTask.creatorId,
          createdAt: droppedTask.createdAt,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: isHovering
              ? accentColor.withOpacity(0.05)
              : Colors.transparent,
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có công việc nào',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 140, // Fixed height for task cards
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 380,
                          child: Opacity(
                            opacity: 0.9,
                            child: TaskCard(
                              task: task,
                              accentColor: accentColor,
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: TaskCard(task: task, accentColor: accentColor),
                      ),
                      child: TaskCard(task: task, accentColor: accentColor),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildColumn(
    BuildContext context,
    String title,
    String status,
    List<Task> allTasks,
    Color accentColor,
  ) {
    final tasks = allTasks.where((t) => t.status == status).toList();

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status,
          assigneeId: droppedTask.assigneeId,
          creatorId: droppedTask.creatorId,
          createdAt: droppedTask.createdAt,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering
                  ? accentColor.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.2),
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? accentColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: ColorScheme.light(primary: accentColor),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (tasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Danh sách trống',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ...tasks.map((task) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Draggable<Task>(
                        data: task,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 64,
                            child: Opacity(
                              opacity: 0.9,
                              child: TaskCard(
                                task: task,
                                accentColor: accentColor,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: TaskCard(task: task, accentColor: accentColor),
                        ),
                        child: TaskCard(task: task, accentColor: accentColor),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Thêm Bảng mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400, // Định hình chiều rộng tối đa
              child: TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Tên Bảng',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                autofocus: true,
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  final authState = context.read<AuthBloc>().state;
                  final userId = authState is Authenticated
                      ? authState.user.id
                      : '';
                  final board = Board(
                    id: const Uuid().v4(),
                    title: titleController.text.trim(),
                    ownerId: userId,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  context.read<BoardBloc>().add(AddBoardEvent(board));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Thêm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteBoardDialog(BuildContext context, Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bảng "${board.title}"?\nTất cả công việc trong bảng sẽ bị xóa vĩnh viễn.',
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              context.read<BoardBloc>().add(DeleteBoardEvent(board.id));
              if (selectedBoardId == board.id) {
                setState(() {
                  selectedBoardId = null;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Xóa Bảng'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Thêm công việc mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400, // Cố định chiều rộng để form không bị bóp méo
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Mô tả (không bắt buộc)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty ||
                      selectedBoardId == null) {
                    return;
                  }
                  final authState = context.read<AuthBloc>().state;
                  final userId = authState is Authenticated
                      ? authState.user.id
                      : null;
                  final task = Task(
                    id: const Uuid().v4(),
                    boardId: selectedBoardId!,
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    status: 'todo',
                    creatorId: userId,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  context.read<TaskBloc>().add(AddTaskEvent(task));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Thêm công việc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

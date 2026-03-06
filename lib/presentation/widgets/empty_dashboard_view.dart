import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

@Preview(name: 'Full Dashboard')
Widget previewEmptyDashboardView() {
  return Scaffold(
    body: EmptyDashboardView(onAddBoard: () {}, onOpenMenu: () {}),
  );
}

class EmptyDashboardView extends StatelessWidget {
  final VoidCallback onAddBoard;
  final VoidCallback onOpenMenu;

  const EmptyDashboardView({
    super.key,
    required this.onAddBoard,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white, // Fallback color
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Biểu tượng tổng quan
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.dashboard_customize_rounded,
                    size: 70,
                    color: Colors.blueAccent.shade400,
                  ),
                ),
                const SizedBox(height: 32),
                // Tiêu đề
                const Text(
                  'Tổng Quan KanbanFlow',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Mô tả
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Không gian làm việc của bạn đang trống. Hãy bắt đầu kiến tạo quy trình làm việc thông minh ngay bây giờ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Mạng lưới các nút tương tác (Action Cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      // Nút: Tạo Bảng Mới
                      DashboardActionCard(
                        title: 'Tạo Bảng Mới',
                        subtitle: 'Bắt đầu dự án mới ngay',
                        icon: Icons.add_chart_rounded,
                        gradientColors: const [
                          Colors.blueAccent,
                          Colors.lightBlue,
                        ],
                        onTap: onAddBoard,
                      ),
                      // Nút: Mở Menu Bảng
                      DashboardActionCard(
                        title: 'Quản Lý Bảng',
                        subtitle: 'Xem các bảng hiện tại',
                        icon: Icons.menu_open_rounded,
                        gradientColors: const [
                          Colors.indigo,
                          Colors.indigoAccent,
                        ],
                        onTap: onOpenMenu,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60), // Khoảng trống dưới cùng
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const DashboardActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: gradientColors.first.withOpacity(0.1),
          highlightColor: gradientColors.first.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

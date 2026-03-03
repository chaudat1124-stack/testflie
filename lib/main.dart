import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Khởi tạo Dependency Injection (GetIt) ở đây sau
  runApp(const KanbanFlowApp());
}

class KanbanFlowApp extends StatelessWidget {
  const KanbanFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KanbanFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('KanbanFlow - Clean Architecture Base'),
        ),
      ),
    );
  }
}
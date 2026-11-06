import 'package:flutter/material.dart';
import 'app_shell.dart';

void main() {
  runApp(const TempAlertApp());
}

class TempAlertApp extends StatelessWidget {
  const TempAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '배관 동파 모니터링',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF5F7FB),
      ),
      home: const AppShell(),
    );
  }
}

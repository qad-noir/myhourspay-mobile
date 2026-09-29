import 'package:flutter/material.dart';

import 'features/hours/repository.dart';
import 'features/session/session_model.dart';
import 'features/hours/hours_screen.dart';

void main() => runApp(const MhpApp());

class MhpApp extends StatefulWidget {
  const MhpApp({super.key});
  @override
  State<MhpApp> createState() => _MhpAppState();
}

class _MhpAppState extends State<MhpApp> {
  final model = SessionModel(DemoHoursRepository());
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MyHoursPay',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffb3421c),
        primary: const Color(0xffb3421c),
        surface: const Color(0xfffaf9fb),
      ),
      scaffoldBackgroundColor: const Color(0xfffaf9fb),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: HoursScreen(model: model),
  );
}

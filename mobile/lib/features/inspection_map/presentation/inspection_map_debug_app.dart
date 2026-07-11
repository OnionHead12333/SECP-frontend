import 'package:flutter/material.dart';

import 'inspection_map_debug_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InspectionMapDebugApp());
}

class InspectionMapDebugApp extends StatelessWidget {
  const InspectionMapDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspection Map Debug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const InspectionMapDebugPage(),
    );
  }
}

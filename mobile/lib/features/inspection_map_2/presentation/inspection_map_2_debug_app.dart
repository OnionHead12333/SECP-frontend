import 'package:flutter/material.dart';

import 'inspection_map_2_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InspectionMap2DebugApp());
}

class InspectionMap2DebugApp extends StatelessWidget {
  const InspectionMap2DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspection Map 2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006D5B)),
        useMaterial3: true,
      ),
      home: const InspectionMap2Page(),
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TumblerDriveApp());
}

class TumblerDriveApp extends StatelessWidget {
  const TumblerDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tumbler Drive',
      theme: ThemeData.dark(useMaterial3: true),
      home: const LobbyScreen(),
    );
  }
}

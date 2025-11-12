import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const ViewSyncApp());
}

class ViewSyncApp extends StatelessWidget {
  const ViewSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViewSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),
      home: const LandingScreen(),
    );
  }
}


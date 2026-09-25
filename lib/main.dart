import 'package:flutter/material.dart';

void main() {
  runApp(const PickDuoApp());
}

class PickDuoApp extends StatelessWidget {
  const PickDuoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickDuo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainGameScreen(),
    );
  }
}

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'PickDuo Game Running',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
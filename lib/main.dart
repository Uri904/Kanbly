import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const KanblyApp());
}

class KanblyApp extends StatelessWidget {
  const KanblyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanbly',
      home: const Scaffold(body: Center(child: Text('Kanbly funcionando'))),
    );
  }
}
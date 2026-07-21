import 'package:firebase_core/firebase_core.dart';
//import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controlador/auth_controller.dart';
import 'Vistas/login_view.dart';
import 'firebase_options.dart';
import 'servicios/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    // Si es duplicate-app, Firebase ya estaba inicializado nativamente, lo ignoramos
  }

  // Activar App Check
  //await FirebaseAppCheck.instance.activate(
    //androidProvider: AndroidProvider.debug,
    //appleProvider: AppleProvider.debug,
  //);

  final firestoreService = FirestoreService();
  // await firestoreService.crearColeccionUsuarios();


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthController()..checkAuthStatus(),
      child: MaterialApp(
        title: 'Kanbly',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFFCFDFD),
          fontFamily: 'Roboto',
        ),
        home: const LoginView(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

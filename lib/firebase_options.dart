import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyDzDl2ABh8Zlo4H-j8ogpWfNngQTteJPrA', // <--- PON TU CLAVE API AQUÍ
    appId: '1:590558463776:android:c62d77cb9a4faa6e86f945', // <--- PON TU APP ID AQUÍ
    messagingSenderId: '590558463776', // <--- PON TU SENDER ID AQUÍ
    projectId: 'kanbly-16722',
    authDomain: 'kanbly-16722.firebaseapp.com',
    storageBucket: 'kanbly-16722.appspot.com',
  );
}
import 'package:blocodenotasturmab/firebase_options.dart';
import 'package:blocodenotasturmab/screens/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'screens/notes_page.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    if (DefaultFirebaseOptions.useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(
        DefaultFirebaseOptions.emulatorHost,
        9099,
      );
      FirebaseFirestore.instance.useFirestoreEmulator(
        DefaultFirebaseOptions.emulatorHost,
        8080,
      );
    }
  } catch (_) {
    startupError =
        'Não foi possível iniciar o Firebase. Confira a configuração do projeto no README e abra o aplicativo novamente.';
  }
  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatelessWidget {
  final String? startupError;
  final NotesCloud? notesCloud;
  const MyApp({super.key, this.startupError, this.notesCloud});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Bloco de Notas',
      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: Color(0xfff7f5fc),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xff6c4ab6),
          brightness: Brightness.light,
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xfff7f5fc),
          foregroundColor: Color(0xff292333),
          elevation: 0,
          centerTitle: false,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 17, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Color(0xff6c4ab6), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6C4AB6),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: startupError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(startupError!, textAlign: TextAlign.center),
                ),
              ),
            )
          : AuthGate(notesCloud: notesCloud),
    );
  }
}

class AuthGate extends StatelessWidget {
  final NotesCloud? notesCloud;
  const AuthGate({super.key, this.notesCloud});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      return user == null
          ? const LoginPage()
          : NotesPage(key: ValueKey(user.uid), cloud: notesCloud);
    },
  );
}

import 'package:blocodenotasturmab/firebase_options.dart';
import 'package:blocodenotasturmab/screens/login_page.dart';
import 'package:blocodenotasturmab/screens/notes_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // O cache offline fica a cargo do SQLite; assim o Firestore só responde com dados do servidor.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


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
          brightness: Brightness.light
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
          contentPadding: EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 20, 
          ),
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
            borderSide: BorderSide(
              color: Color(0xff6c4ab6),
              width:2
            )
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6C4AB6),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)
            )
          )
        )

        
      ),
      // Sessão do Firebase Auth persiste: quem já entrou vai direto para as notas.
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginPage()
          : const NotesPage(),
    );
  }
}


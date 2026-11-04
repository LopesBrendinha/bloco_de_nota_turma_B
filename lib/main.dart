import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/firebase_options.dart';
import 'package:blocodenotasturmab/repositories/notes_repository.dart';
import 'package:blocodenotasturmab/screens/auth_gate.dart';
import 'package:blocodenotasturmab/services/auth_service.dart';
import 'package:blocodenotasturmab/services/firestore_data_source.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // O SQLite já é o armazenamento offline do aplicativo. Com o cache do
  // Firestore ligado, existiriam duas filas de escrita, e uma nota salva sem
  // internet pareceria enviada sem ter chegado à nuvem.
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);

  // Todas as dependências são criadas aqui e entregues por construtor.
  final database = DatabaseHelper(
    databaseFactory,
    join(await getDatabasesPath(), 'notes.db'),
  );
  final syncService = SyncService(database, FirestoreDataSource(firestore));

  runApp(
    MyApp(
      repository: NotesRepository(database, syncService),
      authService: AuthService(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final NotesRepository repository;
  final AuthService authService;

  const MyApp({
    super.key,
    required this.repository,
    required this.authService,
  });


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
      home: AuthGate(repository: repository, authService: authService),
    );
  }
}


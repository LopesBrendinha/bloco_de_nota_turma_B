import 'package:blocodenotasturmab/firebase_options.dart';
import 'package:blocodenotasturmab/servicos/servico_autenticacao.dart';
import 'package:blocodenotasturmab/telas/pagina_login.dart';
import 'package:blocodenotasturmab/telas/pagina_notas.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const usarEmulador = bool.fromEnvironment('EMULADOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  if (usarEmulador) await conectarEmulador();
  runApp(const AplicativoNotas());
}

Future<void> conectarEmulador() async {
  const host = String.fromEnvironment(
    'EMULADOR_HOST',
    defaultValue: '10.0.2.2',
  );
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
}

class AplicativoNotas extends StatelessWidget {
  const AplicativoNotas({super.key});

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
      home: ServicoAutenticacao().usuarioAtual == null
          ? const PaginaLogin()
          : const PaginaNotas(),
    );
  }
}

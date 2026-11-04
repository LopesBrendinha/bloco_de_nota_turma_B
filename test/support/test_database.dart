import 'dart:io';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abre um SQLite real, em um arquivo temporário, para cada teste.
Future<DatabaseHelper> openTestDatabase() async {
  return DatabaseHelper(databaseFactoryFfi, await temporaryDatabasePath());
}

Future<String> temporaryDatabasePath() async {
  sqfliteFfiInit();
  final directory = await Directory.systemTemp.createTemp('notas_teste_');
  return join(directory.path, 'notes.db');
}

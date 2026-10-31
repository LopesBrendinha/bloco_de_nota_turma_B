import 'package:blocodenotasturmab/modelos/categoria.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:blocodenotasturmab/modelos/ordenacao.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BancoLocal {
  static final BancoLocal instancia = BancoLocal();

  final String? caminho;
  Database? _banco;

  BancoLocal({this.caminho});

  Future<Database> get banco async {
    return _banco ??= await _abrir();
  }

  Future<Database> _abrir() async {
    final destino = caminho ?? join(await getDatabasesPath(), 'notes.db');
    return openDatabase(
      destino,
      version: 2,
      onCreate: _criar,
      onUpgrade: _migrar,
    );
  }

  Future<void> _criar(Database db, int versao) async {
    await db.execute('''
      CREATE TABLE notas(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        titulo TEXT NOT NULL,
        conteudo TEXT NOT NULL,
        categoriaId TEXT,
        criadaEm INTEGER NOT NULL,
        atualizadaEm INTEGER NOT NULL,
        excluidaEm INTEGER,
        sincronizada INTEGER NOT NULL DEFAULT 0,
        apagada INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE categorias(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        nome TEXT NOT NULL,
        sincronizada INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _migrar(Database db, int versaoAntiga, int versaoNova) async {
    if (versaoAntiga < 2) {
      await _criar(db, versaoNova);
      final agora = DateTime.now().millisecondsSinceEpoch;
      await db.execute(
        '''
        INSERT INTO notas (id, uid, titulo, conteudo, criadaEm, atualizadaEm)
        SELECT lower(hex(randomblob(16))), uid, title, content, ?, ?
        FROM notes
        ''',
        [agora, agora],
      );
      await db.execute('DROP TABLE notes');
    }
  }

  Future<void> salvarNota(Nota nota) async {
    final db = await banco;
    await db.insert(
      'notas',
      nota.paraMapa(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Nota>> buscarNotas(
    String uid, {
    String termo = '',
    String? categoriaId,
    Ordenacao ordem = Ordenacao.atualizacao,
  }) {
    final filtros = ['uid = ?', 'apagada = 0', 'excluidaEm IS NULL'];
    final argumentos = <Object>[uid];

    if (termo.isNotEmpty) {
      filtros.add('(titulo LIKE ? OR conteudo LIKE ?)');
      argumentos.addAll(['%$termo%', '%$termo%']);
    }
    if (categoriaId != null) {
      filtros.add('categoriaId = ?');
      argumentos.add(categoriaId);
    }

    return _consultarNotas(
      filtros.join(' AND '),
      argumentos,
      ordem: ordem.clausula,
    );
  }

  Future<List<Nota>> buscarLixeira(String uid) {
    return _consultarNotas(
      'uid = ? AND apagada = 0 AND excluidaEm IS NOT NULL',
      [uid],
      ordem: 'excluidaEm DESC',
    );
  }

  Future<List<Nota>> buscarTodasNotas(String uid) {
    return _consultarNotas('uid = ?', [uid]);
  }

  Future<List<Nota>> buscarNotasPendentes(String uid) {
    return _consultarNotas('uid = ? AND sincronizada = 0', [uid]);
  }

  Future<int> contarPendentes(String uid) async {
    final db = await banco;
    final resultado = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM notas WHERE uid = ? AND sincronizada = 0) +
        (SELECT COUNT(*) FROM categorias WHERE uid = ? AND sincronizada = 0)
      ''',
      [uid, uid],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<void> marcarNotaSincronizada(Nota nota) async {
    final db = await banco;
    await db.update(
      'notas',
      {'sincronizada': 1},
      where: 'id = ? AND atualizadaEm = ?',
      whereArgs: [nota.id, nota.atualizadaEm.millisecondsSinceEpoch],
    );
  }

  Future<void> removerNotaApagada(String id) async {
    final db = await banco;
    await db.delete('notas', where: 'id = ? AND apagada = 1', whereArgs: [id]);
  }

  Future<void> removerNotaSincronizada(String id) async {
    final db = await banco;
    await db.delete(
      'notas',
      where: 'id = ? AND sincronizada = 1',
      whereArgs: [id],
    );
  }

  Future<void> salvarCategoria(Categoria categoria) async {
    final db = await banco;
    await db.insert(
      'categorias',
      categoria.paraMapa(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Categoria>> buscarCategorias(String uid) {
    return _consultarCategorias('uid = ?', [uid]);
  }

  Future<List<Categoria>> buscarCategoriasPendentes(String uid) {
    return _consultarCategorias('uid = ? AND sincronizada = 0', [uid]);
  }

  Future<void> marcarCategoriaSincronizada(String id) async {
    final db = await banco;
    await db.update(
      'categorias',
      {'sincronizada': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Nota>> _consultarNotas(
    String filtro,
    List<Object> argumentos, {
    String ordem = 'atualizadaEm DESC',
  }) async {
    final db = await banco;
    final linhas = await db.query(
      'notas',
      where: filtro,
      whereArgs: argumentos,
      orderBy: ordem,
    );
    return linhas.map(Nota.doMapa).toList();
  }

  Future<List<Categoria>> _consultarCategorias(
    String filtro,
    List<Object> argumentos,
  ) async {
    final db = await banco;
    final linhas = await db.query(
      'categorias',
      where: filtro,
      whereArgs: argumentos,
      orderBy: 'nome COLLATE NOCASE',
    );
    return linhas.map(Categoria.doMapa).toList();
  }
}

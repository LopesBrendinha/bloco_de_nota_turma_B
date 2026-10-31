import 'package:blocodenotasturmab/modelos/categoria.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NuvemNotas {
  static const _tempoLimite = Duration(seconds: 10);

  final FirebaseFirestore _firestore;

  NuvemNotas({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _colecao(String uid, String nome) {
    return _firestore.collection('usuarios').doc(uid).collection(nome);
  }

  Future<List<Nota>> buscarNotas(String uid) async {
    final consulta = await _colecao(
      uid,
      'notas',
    ).get(const GetOptions(source: Source.server)).timeout(_tempoLimite);
    return consulta.docs.map(_notaDoDocumento).toList();
  }

  Future<void> salvarNota(Nota nota) {
    return _colecao(
      nota.uid,
      'notas',
    ).doc(nota.id).set(_documentoDaNota(nota)).timeout(_tempoLimite);
  }

  Future<void> excluirNota(Nota nota) {
    return _colecao(
      nota.uid,
      'notas',
    ).doc(nota.id).delete().timeout(_tempoLimite);
  }

  Future<List<Categoria>> buscarCategorias(String uid) async {
    final consulta = await _colecao(
      uid,
      'categorias',
    ).get(const GetOptions(source: Source.server)).timeout(_tempoLimite);
    return consulta.docs.map(_categoriaDoDocumento).toList();
  }

  Future<void> salvarCategoria(Categoria categoria) {
    return _colecao(categoria.uid, 'categorias')
        .doc(categoria.id)
        .set({'uid': categoria.uid, 'nome': categoria.nome})
        .timeout(_tempoLimite);
  }

  Map<String, Object?> _documentoDaNota(Nota nota) {
    return {
      'uid': nota.uid,
      'titulo': nota.titulo,
      'conteudo': nota.conteudo,
      'categoriaId': nota.categoriaId,
      'criadaEm': Timestamp.fromDate(nota.criadaEm),
      'atualizadaEm': Timestamp.fromDate(nota.atualizadaEm),
      'excluidaEm': nota.excluidaEm == null
          ? null
          : Timestamp.fromDate(nota.excluidaEm!),
    };
  }

  Nota _notaDoDocumento(QueryDocumentSnapshot<Map<String, dynamic>> documento) {
    final dados = documento.data();
    final excluidaEm = dados['excluidaEm'] as Timestamp?;
    return Nota(
      id: documento.id,
      uid: dados['uid'] as String,
      titulo: dados['titulo'] as String,
      conteudo: dados['conteudo'] as String,
      categoriaId: dados['categoriaId'] as String?,
      criadaEm: (dados['criadaEm'] as Timestamp).toDate(),
      atualizadaEm: (dados['atualizadaEm'] as Timestamp).toDate(),
      excluidaEm: excluidaEm?.toDate(),
      sincronizada: true,
    );
  }

  Categoria _categoriaDoDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final dados = documento.data();
    return Categoria(
      id: documento.id,
      uid: dados['uid'] as String,
      nome: dados['nome'] as String,
      sincronizada: true,
    );
  }
}

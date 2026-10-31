import 'package:uuid/uuid.dart';

class Categoria {
  final String id;
  final String uid;
  final String nome;
  final bool sincronizada;

  const Categoria({
    required this.id,
    required this.uid,
    required this.nome,
    this.sincronizada = false,
  });

  factory Categoria.nova({required String uid, required String nome}) {
    return Categoria(id: const Uuid().v4(), uid: uid, nome: nome);
  }

  factory Categoria.doMapa(Map<String, Object?> mapa) {
    return Categoria(
      id: mapa['id'] as String,
      uid: mapa['uid'] as String,
      nome: mapa['nome'] as String,
      sincronizada: mapa['sincronizada'] == 1,
    );
  }

  static List<Categoria> padroes(String uid) {
    return [
      Categoria(id: 'estudos', uid: uid, nome: 'Estudos', sincronizada: true),
      Categoria(id: 'trabalho', uid: uid, nome: 'Trabalho', sincronizada: true),
      Categoria(id: 'pessoal', uid: uid, nome: 'Pessoal', sincronizada: true),
    ];
  }

  Map<String, Object?> paraMapa() {
    return {
      'id': id,
      'uid': uid,
      'nome': nome,
      'sincronizada': sincronizada ? 1 : 0,
    };
  }

  Categoria comoSincronizada() {
    return Categoria(id: id, uid: uid, nome: nome, sincronizada: true);
  }

  bool chamada(String outroNome) {
    return nome.toLowerCase() == outroNome.trim().toLowerCase();
  }
}

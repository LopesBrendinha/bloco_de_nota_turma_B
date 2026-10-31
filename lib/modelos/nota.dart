import 'package:uuid/uuid.dart';

class Nota {
  static const diasNaLixeira = 30;

  final String id;
  final String uid;
  final String titulo;
  final String conteudo;
  final String? categoriaId;
  final DateTime criadaEm;
  final DateTime atualizadaEm;
  final DateTime? excluidaEm;
  final bool sincronizada;
  final bool apagada;

  const Nota({
    required this.id,
    required this.uid,
    required this.titulo,
    required this.conteudo,
    this.categoriaId,
    required this.criadaEm,
    required this.atualizadaEm,
    this.excluidaEm,
    this.sincronizada = false,
    this.apagada = false,
  });

  factory Nota.nova({
    required String uid,
    required String titulo,
    required String conteudo,
    String? categoriaId,
  }) {
    final agora = _agora();
    return Nota(
      id: const Uuid().v4(),
      uid: uid,
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      criadaEm: agora,
      atualizadaEm: agora,
    );
  }

  factory Nota.doMapa(Map<String, Object?> mapa) {
    final excluidaEm = mapa['excluidaEm'] as int?;
    return Nota(
      id: mapa['id'] as String,
      uid: mapa['uid'] as String,
      titulo: mapa['titulo'] as String,
      conteudo: mapa['conteudo'] as String,
      categoriaId: mapa['categoriaId'] as String?,
      criadaEm: _dataDoNumero(mapa['criadaEm'] as int),
      atualizadaEm: _dataDoNumero(mapa['atualizadaEm'] as int),
      excluidaEm: excluidaEm == null ? null : _dataDoNumero(excluidaEm),
      sincronizada: mapa['sincronizada'] == 1,
      apagada: mapa['apagada'] == 1,
    );
  }

  Map<String, Object?> paraMapa() {
    return {
      'id': id,
      'uid': uid,
      'titulo': titulo,
      'conteudo': conteudo,
      'categoriaId': categoriaId,
      'criadaEm': criadaEm.millisecondsSinceEpoch,
      'atualizadaEm': atualizadaEm.millisecondsSinceEpoch,
      'excluidaEm': excluidaEm?.millisecondsSinceEpoch,
      'sincronizada': sincronizada ? 1 : 0,
      'apagada': apagada ? 1 : 0,
    };
  }

  bool get naLixeira => excluidaEm != null;

  int get diasRestantesNaLixeira {
    return diasNaLixeira - DateTime.now().difference(excluidaEm!).inDays;
  }

  bool get lixeiraVencida => naLixeira && diasRestantesNaLixeira <= 0;

  Nota editar({
    required String titulo,
    required String conteudo,
    required String? categoriaId,
  }) {
    return _alterar(
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      excluidaEm: excluidaEm,
    );
  }

  Nota moverParaLixeira() {
    return _alterar(
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      excluidaEm: _agora(),
    );
  }

  Nota restaurar() {
    return _alterar(
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      excluidaEm: null,
    );
  }

  Nota apagar() {
    return _alterar(
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      excluidaEm: excluidaEm,
      apagada: true,
    );
  }

  Nota comoSincronizada() {
    return Nota(
      id: id,
      uid: uid,
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      criadaEm: criadaEm,
      atualizadaEm: atualizadaEm,
      excluidaEm: excluidaEm,
      sincronizada: true,
    );
  }

  bool maisRecenteQue(Nota outra) => atualizadaEm.isAfter(outra.atualizadaEm);

  Nota _alterar({
    required String titulo,
    required String conteudo,
    required String? categoriaId,
    required DateTime? excluidaEm,
    bool apagada = false,
  }) {
    return Nota(
      id: id,
      uid: uid,
      titulo: titulo,
      conteudo: conteudo,
      categoriaId: categoriaId,
      criadaEm: criadaEm,
      atualizadaEm: _agora(),
      excluidaEm: excluidaEm,
      apagada: apagada,
    );
  }

  static DateTime _agora() {
    return _dataDoNumero(DateTime.now().millisecondsSinceEpoch);
  }

  static DateTime _dataDoNumero(int milissegundos) {
    return DateTime.fromMillisecondsSinceEpoch(milissegundos);
  }
}

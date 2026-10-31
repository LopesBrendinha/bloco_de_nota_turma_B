import 'dart:async';

import 'package:blocodenotasturmab/dados/banco_local.dart';
import 'package:blocodenotasturmab/dados/nuvem_notas.dart';
import 'package:blocodenotasturmab/modelos/categoria.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:blocodenotasturmab/modelos/ordenacao.dart';
import 'package:blocodenotasturmab/modelos/resultado_sincronizacao.dart';
import 'package:firebase_core/firebase_core.dart';

class RepositorioNotas {
  static Future<void> _fila = Future.value();

  final BancoLocal _local;
  final NuvemNotas _nuvem;

  RepositorioNotas({BancoLocal? local, NuvemNotas? nuvem})
    : _local = local ?? BancoLocal.instancia,
      _nuvem = nuvem ?? NuvemNotas();

  Future<List<Nota>> listar(
    String uid, {
    String termo = '',
    String? categoriaId,
    Ordenacao ordem = Ordenacao.atualizacao,
  }) {
    return _local.buscarNotas(
      uid,
      termo: termo.trim(),
      categoriaId: categoriaId,
      ordem: ordem,
    );
  }

  Future<List<Nota>> listarLixeira(String uid) async {
    await _expirarLixeira(uid);
    return _local.buscarLixeira(uid);
  }

  Future<List<Categoria>> listarCategorias(String uid) async {
    return [...Categoria.padroes(uid), ...await _local.buscarCategorias(uid)];
  }

  Future<Categoria> criarCategoria(String uid, String nome) async {
    final existentes = await listarCategorias(uid);
    for (final categoria in existentes) {
      if (categoria.chamada(nome)) return categoria;
    }

    final nova = Categoria.nova(uid: uid, nome: nome.trim());
    await _local.salvarCategoria(nova);
    return nova;
  }

  Future<int> contarPendentes(String uid) => _local.contarPendentes(uid);

  Future<void> salvar(Nota nota) => _local.salvarNota(nota);

  Future<void> moverParaLixeira(Nota nota) {
    return _local.salvarNota(nota.moverParaLixeira());
  }

  Future<void> restaurar(Nota nota) => _local.salvarNota(nota.restaurar());

  Future<void> excluirDefinitivamente(Nota nota) {
    return _local.salvarNota(nota.apagar());
  }

  Future<void> esvaziarLixeira(String uid) async {
    for (final nota in await _local.buscarLixeira(uid)) {
      await excluirDefinitivamente(nota);
    }
  }

  Future<ResultadoSincronizacao> sincronizar(String uid) {
    return _tentar(() async {
      await _expirarLixeira(uid);
      await _baixarCategorias(uid);
      await _baixarNotas(uid);
      await _enviarPendentes(uid);
    });
  }

  Future<ResultadoSincronizacao> enviarPendentes(String uid) {
    return _tentar(() => _enviarPendentes(uid));
  }

  Future<void> _expirarLixeira(String uid) async {
    for (final nota in await _local.buscarLixeira(uid)) {
      if (nota.lixeiraVencida) await excluirDefinitivamente(nota);
    }
  }

  Future<void> _baixarCategorias(String uid) async {
    for (final categoria in await _nuvem.buscarCategorias(uid)) {
      await _local.salvarCategoria(categoria);
    }
  }

  Future<void> _baixarNotas(String uid) async {
    final remotas = {
      for (final nota in await _nuvem.buscarNotas(uid)) nota.id: nota,
    };
    for (final local in await _local.buscarTodasNotas(uid)) {
      await _mesclar(local, remotas.remove(local.id));
    }
    for (final remota in remotas.values) {
      await _local.salvarNota(remota);
    }
  }

  Future<void> _mesclar(Nota local, Nota? remota) async {
    if (remota == null) {
      await _local.removerNotaSincronizada(local.id);
      return;
    }
    if (remota.maisRecenteQue(local)) {
      await _local.salvarNota(remota);
    }
  }

  Future<void> _enviarPendentes(String uid) async {
    for (final categoria in await _local.buscarCategoriasPendentes(uid)) {
      await _nuvem.salvarCategoria(categoria);
      await _local.marcarCategoriaSincronizada(categoria.id);
    }
    for (final nota in await _local.buscarNotasPendentes(uid)) {
      if (nota.apagada) {
        await _nuvem.excluirNota(nota);
        await _local.removerNotaApagada(nota.id);
      } else {
        await _nuvem.salvarNota(nota);
        await _local.marcarNotaSincronizada(nota);
      }
    }
  }

  Future<ResultadoSincronizacao> _tentar(Future<void> Function() operacao) {
    final resultado = _fila.then((_) => _executar(operacao));
    _fila = resultado;
    return resultado;
  }

  Future<ResultadoSincronizacao> _executar(
    Future<void> Function() operacao,
  ) async {
    try {
      await operacao();
      return ResultadoSincronizacao.concluida;
    } on TimeoutException {
      return ResultadoSincronizacao.semConexao;
    } on FirebaseException catch (erro) {
      return ResultadoSincronizacao.doCodigo(erro.code);
    } catch (_) {
      return ResultadoSincronizacao.falha;
    }
  }
}

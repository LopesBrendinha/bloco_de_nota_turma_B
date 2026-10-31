import 'package:blocodenotasturmab/dados/banco_local.dart';
import 'package:blocodenotasturmab/dados/nuvem_notas.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:blocodenotasturmab/modelos/ordenacao.dart';
import 'package:blocodenotasturmab/modelos/resultado_sincronizacao.dart';
import 'package:blocodenotasturmab/repositorios/repositorio_notas.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const bernardo = 'uid-bernardo';
const moaca = 'uid-moaca';

class NuvemForaDoAr extends NuvemNotas {
  NuvemForaDoAr() : super(firestore: FakeFirebaseFirestore());

  FirebaseException get semRede {
    return FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }

  @override
  Future<List<Nota>> buscarNotas(String uid) async => throw semRede;

  @override
  Future<void> salvarNota(Nota nota) async => throw semRede;

  @override
  Future<void> excluirNota(Nota nota) async => throw semRede;
}

Nota notaEm(DateTime data, {String titulo = 'Treino de perna'}) {
  return Nota(
    id: 'nota-barbosa',
    uid: bernardo,
    titulo: titulo,
    conteudo: 'Agachamento 4x10',
    criadaEm: DateTime(2026, 10, 1),
    atualizadaEm: data,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  var aparelhosCriados = 0;

  Future<BancoLocal> bancoNovo() async {
    final arquivo = 'aparelho_${aparelhosCriados++}.db';
    await databaseFactory.deleteDatabase(arquivo);
    return BancoLocal(caminho: arquivo);
  }

  Future<RepositorioNotas> aparelho({
    BancoLocal? local,
    NuvemNotas? nuvem,
  }) async {
    return RepositorioNotas(
      local: local ?? await bancoNovo(),
      nuvem: nuvem ?? NuvemNotas(firestore: firestore),
    );
  }

  Future<List<Map<String, dynamic>>> documentosNaNuvem(String uid) async {
    final consulta = await firestore
        .collection('usuarios')
        .doc(uid)
        .collection('notas')
        .get();
    return consulta.docs.map((documento) => documento.data()).toList();
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => firestore = FakeFirebaseFirestore());

  test('envia a nota pendente para a pasta do usuário no Firestore', () async {
    final repositorio = await aparelho();
    await repositorio.salvar(
      Nota.nova(uid: bernardo, titulo: 'Mercado', conteudo: 'Manga e aveia'),
    );
    expect(await repositorio.contarPendentes(bernardo), 1);

    final resultado = await repositorio.enviarPendentes(bernardo);

    expect(resultado, ResultadoSincronizacao.concluida);
    expect(await repositorio.contarPendentes(bernardo), 0);
    final documentos = await documentosNaNuvem(bernardo);
    expect(documentos.single['titulo'], 'Mercado');
    expect(documentos.single['uid'], bernardo);
  });

  test('recupera as notas da nuvem em outra instalação', () async {
    final celular = await aparelho();
    final nota = Nota.nova(uid: bernardo, titulo: 'TCC', conteudo: 'Cap. 2');
    await celular.salvar(nota);
    await celular.sincronizar(bernardo);

    final tablet = await aparelho();
    await tablet.sincronizar(bernardo);

    final notas = await tablet.listar(bernardo);
    expect(notas.single.id, nota.id);
    expect(notas.single.sincronizada, isTrue);
  });

  test('remove a nota que foi excluída em outro aparelho', () async {
    final celular = await aparelho();
    final tablet = await aparelho();
    final nota = Nota.nova(uid: bernardo, titulo: 'Ideias', conteudo: 'App');
    await celular.salvar(nota);
    await celular.sincronizar(bernardo);
    await tablet.sincronizar(bernardo);

    await celular.excluirDefinitivamente(nota);
    await celular.enviarPendentes(bernardo);
    await tablet.sincronizar(bernardo);

    expect(await tablet.listar(bernardo), isEmpty);
    expect(await documentosNaNuvem(bernardo), isEmpty);
  });

  test(
    'guarda a alteração no aparelho quando a nuvem está fora do ar',
    () async {
      final local = await bancoNovo();
      final semInternet = await aparelho(local: local, nuvem: NuvemForaDoAr());
      await semInternet.salvar(
        Nota.nova(uid: bernardo, titulo: 'Offline', conteudo: 'Sem rede'),
      );

      final resultado = await semInternet.sincronizar(bernardo);

      expect(resultado, ResultadoSincronizacao.semConexao);
      expect((await semInternet.listar(bernardo)).single.sincronizada, isFalse);

      final comInternet = await aparelho(local: local);
      expect(
        await comInternet.enviarPendentes(bernardo),
        ResultadoSincronizacao.concluida,
      );
      expect(await comInternet.contarPendentes(bernardo), 0);
      expect(await documentosNaNuvem(bernardo), hasLength(1));
    },
  );

  test('não apaga notas locais quando a nuvem não responde', () async {
    final local = await bancoNovo();
    await local.salvarNota(notaEm(DateTime(2026, 10, 2)).comoSincronizada());

    final semInternet = await aparelho(local: local, nuvem: NuvemForaDoAr());
    await semInternet.sincronizar(bernardo);

    expect(await local.buscarNotas(bernardo), hasLength(1));
  });

  test(
    'a versão mais recente vence quando a nota mudou nos dois lados',
    () async {
      final nuvem = NuvemNotas(firestore: firestore);
      await nuvem.salvarNota(
        notaEm(DateTime(2026, 10, 5), titulo: 'Editada no tablet'),
      );
      final celular = await aparelho();
      await celular.salvar(notaEm(DateTime(2026, 10, 3), titulo: 'Do celular'));

      await celular.sincronizar(bernardo);

      expect(
        (await celular.listar(bernardo)).single.titulo,
        'Editada no tablet',
      );

      await celular.salvar(notaEm(DateTime(2026, 10, 9), titulo: 'Mais nova'));
      await celular.sincronizar(bernardo);

      expect((await documentosNaNuvem(bernardo)).single['titulo'], 'Mais nova');
    },
  );

  test('cada usuário enxerga apenas as próprias notas', () async {
    final repositorio = await aparelho();
    await repositorio.salvar(
      Nota.nova(uid: moaca, titulo: 'Particular', conteudo: 'Só da Moaca'),
    );
    await repositorio.sincronizar(moaca);

    expect(await repositorio.listar(bernardo), isEmpty);
    expect(await documentosNaNuvem(bernardo), isEmpty);
    expect(await documentosNaNuvem(moaca), hasLength(1));
  });

  test('pesquisa pelo título ou conteúdo e filtra por categoria', () async {
    final repositorio = await aparelho();
    await repositorio.salvar(
      Nota.nova(
        uid: bernardo,
        titulo: 'Prova de cálculo',
        conteudo: 'Derivadas',
        categoriaId: 'estudos',
      ),
    );
    await repositorio.salvar(
      Nota.nova(
        uid: bernardo,
        titulo: 'Reunião',
        conteudo: 'Levar as derivadas do relatório',
        categoriaId: 'trabalho',
      ),
    );
    await repositorio.salvar(
      Nota.nova(uid: bernardo, titulo: 'Mercado', conteudo: 'Manga'),
    );

    final porTermo = await repositorio.listar(bernardo, termo: 'derivadas');
    final porTitulo = await repositorio.listar(bernardo, termo: 'MERCADO');
    final porCategoria = await repositorio.listar(
      bernardo,
      termo: 'derivadas',
      categoriaId: 'estudos',
    );

    expect(porTermo, hasLength(2));
    expect(porTitulo.single.conteudo, 'Manga');
    expect(porCategoria.single.titulo, 'Prova de cálculo');
  });

  test('categoria criada vai para a nuvem sem duplicar pelo nome', () async {
    final celular = await aparelho();
    final academia = await celular.criarCategoria(bernardo, 'Academia');
    final repetida = await celular.criarCategoria(bernardo, ' academia ');
    final padrao = await celular.criarCategoria(bernardo, 'estudos');
    await celular.salvar(
      Nota.nova(
        uid: bernardo,
        titulo: 'Treino',
        conteudo: 'Supino',
        categoriaId: academia.id,
      ),
    );
    await celular.sincronizar(bernardo);

    final tablet = await aparelho();
    await tablet.sincronizar(bernardo);

    expect(repetida.id, academia.id);
    expect(padrao.id, 'estudos');
    final nomes = (await tablet.listarCategorias(bernardo)).map((c) => c.nome);
    expect(nomes, containsAll(['Estudos', 'Trabalho', 'Pessoal', 'Academia']));
    expect(nomes, hasLength(4));
    expect((await tablet.listar(bernardo)).single.categoriaId, academia.id);
  });

  test(
    'lixeira guarda a nota até ser restaurada em qualquer aparelho',
    () async {
      final celular = await aparelho();
      final tablet = await aparelho();
      final nota = Nota.nova(uid: bernardo, titulo: 'Rascunho', conteudo: 'x');
      await celular.salvar(nota);
      await celular.moverParaLixeira(nota);
      await celular.sincronizar(bernardo);
      await tablet.sincronizar(bernardo);

      expect(await tablet.listar(bernardo), isEmpty);
      final naLixeira = await tablet.listarLixeira(bernardo);
      expect(naLixeira.single.diasRestantesNaLixeira, Nota.diasNaLixeira);
      expect(
        (await documentosNaNuvem(bernardo)).single['excluidaEm'],
        isNotNull,
      );

      await tablet.restaurar(naLixeira.single);
      await tablet.enviarPendentes(bernardo);
      await celular.sincronizar(bernardo);

      expect((await celular.listar(bernardo)).single.titulo, 'Rascunho');
      expect(await celular.listarLixeira(bernardo), isEmpty);
    },
  );

  test('nota com mais de 30 dias na lixeira é excluída de vez', () async {
    final celular = await aparelho();
    final antiga = Nota(
      id: 'nota-manga',
      uid: bernardo,
      titulo: 'Velha',
      conteudo: 'Esquecida',
      criadaEm: DateTime(2026, 8, 1),
      atualizadaEm: DateTime(2026, 8, 2),
      excluidaEm: DateTime.now().subtract(const Duration(days: 31)),
    );
    await celular.salvar(antiga);

    await celular.sincronizar(bernardo);

    expect(await celular.listarLixeira(bernardo), isEmpty);
    expect(await documentosNaNuvem(bernardo), isEmpty);
    expect(await celular.contarPendentes(bernardo), 0);
  });

  test('ordena pela data de criação ou pela última atualização', () async {
    final repositorio = await aparelho();
    await repositorio.salvar(
      Nota(
        id: 'primeira',
        uid: bernardo,
        titulo: 'Criada antes, editada depois',
        conteudo: '',
        criadaEm: DateTime(2026, 9, 1),
        atualizadaEm: DateTime(2026, 10, 20),
      ),
    );
    await repositorio.salvar(
      Nota(
        id: 'segunda',
        uid: bernardo,
        titulo: 'Criada depois',
        conteudo: '',
        criadaEm: DateTime(2026, 10, 1),
        atualizadaEm: DateTime(2026, 10, 1),
      ),
    );

    final porAtualizacao = await repositorio.listar(bernardo);
    final porCriacao = await repositorio.listar(
      bernardo,
      ordem: Ordenacao.criacao,
    );

    expect(porAtualizacao.map((nota) => nota.id), ['primeira', 'segunda']);
    expect(porCriacao.map((nota) => nota.id), ['segunda', 'primeira']);
  });
}

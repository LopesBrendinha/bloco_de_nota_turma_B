import 'package:blocodenotasturmab/componentes/cartao_nota.dart';
import 'package:blocodenotasturmab/componentes/estado_vazio.dart';
import 'package:blocodenotasturmab/componentes/indicador_sincronizacao.dart';
import 'package:blocodenotasturmab/componentes/seletor_categorias.dart';
import 'package:blocodenotasturmab/modelos/categoria.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:blocodenotasturmab/modelos/ordenacao.dart';
import 'package:blocodenotasturmab/modelos/resultado_sincronizacao.dart';
import 'package:blocodenotasturmab/repositorios/repositorio_notas.dart';
import 'package:blocodenotasturmab/servicos/servico_autenticacao.dart';
import 'package:blocodenotasturmab/telas/pagina_formulario_nota.dart';
import 'package:blocodenotasturmab/telas/pagina_lixeira.dart';
import 'package:blocodenotasturmab/telas/pagina_login.dart';
import 'package:blocodenotasturmab/utilitarios/formatar_data.dart';
import 'package:flutter/material.dart';

class PaginaNotas extends StatefulWidget {
  const PaginaNotas({super.key});

  @override
  State<PaginaNotas> createState() => _PaginaNotasState();
}

class _PaginaNotasState extends State<PaginaNotas> {
  final repositorio = RepositorioNotas();
  final autenticacao = ServicoAutenticacao();
  late final usuario = autenticacao.usuarioAtual!;
  final controladorPesquisa = TextEditingController();

  List<Nota> notas = [];
  List<Categoria> categorias = [];
  String? filtroCategoria;
  Ordenacao ordem = Ordenacao.atualizacao;
  int pendentes = 0;
  bool sincronizando = false;
  ResultadoSincronizacao? ultimoResultado;

  @override
  void initState() {
    super.initState();
    carregarNotas().then((_) => sincronizar());
  }

  @override
  void dispose() {
    controladorPesquisa.dispose();
    super.dispose();
  }

  bool get filtrando {
    return controladorPesquisa.text.trim().isNotEmpty ||
        filtroCategoria != null;
  }

  Map<String, String> get nomesCategorias {
    return {for (final categoria in categorias) categoria.id: categoria.nome};
  }

  void mostrarMensagem(String mensagem, {SnackBarAction? acao}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          action: acao,
          persist: false,
        ),
      );
  }

  Future<void> carregarNotas() async {
    final resultado = await repositorio.listar(
      usuario.uid,
      termo: controladorPesquisa.text,
      categoriaId: filtroCategoria,
      ordem: ordem,
    );
    final todasCategorias = await repositorio.listarCategorias(usuario.uid);
    final aguardando = await repositorio.contarPendentes(usuario.uid);

    if (mounted) {
      setState(() {
        notas = resultado;
        categorias = todasCategorias;
        pendentes = aguardando;
      });
    }
  }

  Future<void> sincronizar({bool avisar = false}) async {
    if (!mounted || sincronizando) return;
    setState(() => sincronizando = true);
    final resultado = await repositorio.sincronizar(usuario.uid);
    await concluirSincronizacao(resultado, avisar: avisar);
  }

  Future<void> enviarPendentes() async {
    if (!mounted) return;
    setState(() => sincronizando = true);
    final resultado = await repositorio.enviarPendentes(usuario.uid);
    await concluirSincronizacao(resultado);
  }

  Future<void> concluirSincronizacao(
    ResultadoSincronizacao resultado, {
    bool avisar = false,
  }) async {
    if (!mounted) return;
    setState(() {
      sincronizando = false;
      ultimoResultado = resultado;
    });
    await carregarNotas();

    final falhaInesperada =
        !resultado.sucesso && resultado != ResultadoSincronizacao.semConexao;
    if (mounted && (avisar || falhaInesperada)) {
      mostrarMensagem(resultado.mensagem);
    }
  }

  Future<void> moverParaLixeira(Nota nota) async {
    await repositorio.moverParaLixeira(nota);
    await carregarNotas();
    if (mounted) {
      mostrarMensagem(
        'Nota movida para a lixeira.',
        acao: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => desfazerExclusao(nota),
        ),
      );
    }
    await enviarPendentes();
  }

  Future<void> desfazerExclusao(Nota nota) async {
    await repositorio.restaurar(nota);
    await carregarNotas();
    await enviarPendentes();
  }

  Future<void> abrirLixeira() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaginaLixeira(uid: usuario.uid)),
    );
    await carregarNotas();
    await enviarPendentes();
  }

  void ordenarPor(Ordenacao novaOrdem) {
    setState(() => ordem = novaOrdem);
    carregarNotas();
  }

  String legenda(Nota nota) {
    return ordem == Ordenacao.criacao
        ? 'Criada em ${formatarData(nota.criadaEm)}'
        : 'Editada em ${formatarData(nota.atualizadaEm)}';
  }

  Future<void> abrirFormulario([Nota? nota]) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaginaFormularioNota(uid: usuario.uid, nota: nota),
      ),
    );

    if (salvou == true) {
      await carregarNotas();
      await enviarPendentes();
    }
  }

  Future<void> sair() async {
    await autenticacao.sair();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PaginaLogin()),
      (rota) => false,
    );
  }

  void filtrarPorCategoria(String? categoriaId) {
    setState(() => filtroCategoria = categoriaId);
    carregarNotas();
  }

  void limparPesquisa() {
    controladorPesquisa.clear();
    carregarNotas();
  }

  Widget campoPesquisa() {
    return TextField(
      controller: controladorPesquisa,
      onChanged: (_) => carregarNotas(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Pesquisar por título ou conteúdo',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controladorPesquisa.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar pesquisa',
                onPressed: limparPesquisa,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget listaDeNotas() {
    if (notas.isEmpty) {
      return ListView(
        children: [
          filtrando
              ? const EstadoVazio(
                  icone: Icons.search_off_rounded,
                  titulo: 'Nenhuma nota encontrada',
                  descricao: 'Tente outro termo ou outra categoria.',
                )
              : const EstadoVazio(
                  icone: Icons.sticky_note_2_outlined,
                  titulo: 'Nenhuma nota ainda',
                  descricao: 'Crie sua primeira nota.',
                ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: notas.length,
      itemBuilder: (context, indice) {
        final nota = notas[indice];
        return CartaoNota(
          nota: nota,
          legenda: legenda(nota),
          nomeCategoria: nomesCategorias[nota.categoriaId],
          aoTocar: () => abrirFormulario(nota),
          acoes: [
            IconButton(
              tooltip: 'Mover para a lixeira',
              onPressed: () => moverParaLixeira(nota),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xffb45f6c),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<Ordenacao>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort_rounded),
            onSelected: ordenarPor,
            itemBuilder: (_) => [
              for (final opcao in Ordenacao.values)
                CheckedPopupMenuItem(
                  value: opcao,
                  checked: opcao == ordem,
                  child: Text(opcao.rotulo),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Lixeira',
            onPressed: abrirLixeira,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: sincronizando ? null : () => sincronizar(avisar: true),
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: sair,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirFormulario,
        backgroundColor: const Color(0xFF6C4AB6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usuario.email ?? '',
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),
            const SizedBox(height: 6),
            IndicadorSincronizacao(
              sincronizando: sincronizando,
              pendentes: pendentes,
              ultimoResultado: ultimoResultado,
            ),
            const SizedBox(height: 16),
            campoPesquisa(),
            const SizedBox(height: 12),
            SeletorCategorias(
              categorias: categorias,
              selecionada: filtroCategoria,
              rotuloNenhuma: 'Todas',
              aoSelecionar: filtrarPorCategoria,
            ),
            if (filtrando)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  notas.length == 1
                      ? '1 nota encontrada'
                      : '${notas.length} notas encontradas',
                  style: const TextStyle(
                    color: Color(0xFF77717F),
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => sincronizar(avisar: true),
                child: listaDeNotas(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

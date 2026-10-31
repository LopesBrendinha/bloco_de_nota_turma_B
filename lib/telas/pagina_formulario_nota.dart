import 'package:blocodenotasturmab/componentes/dialogo_categoria.dart';
import 'package:blocodenotasturmab/componentes/seletor_categorias.dart';
import 'package:blocodenotasturmab/modelos/categoria.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:blocodenotasturmab/repositorios/repositorio_notas.dart';
import 'package:flutter/material.dart';

class PaginaFormularioNota extends StatefulWidget {
  final String uid;
  final Nota? nota;

  const PaginaFormularioNota({super.key, required this.uid, this.nota});

  @override
  State<PaginaFormularioNota> createState() => _PaginaFormularioNotaState();
}

class _PaginaFormularioNotaState extends State<PaginaFormularioNota> {
  final controladorTitulo = TextEditingController();
  final controladorConteudo = TextEditingController();

  final repositorio = RepositorioNotas();

  List<Categoria> categorias = [];
  String? categoriaId;

  bool get editando => widget.nota != null;

  @override
  void initState() {
    super.initState();

    if (editando) {
      controladorTitulo.text = widget.nota!.titulo;
      controladorConteudo.text = widget.nota!.conteudo;
      categoriaId = widget.nota!.categoriaId;
    }
    carregarCategorias();
  }

  Future<void> carregarCategorias() async {
    final resultado = await repositorio.listarCategorias(widget.uid);
    if (mounted) setState(() => categorias = resultado);
  }

  Future<void> criarCategoria() async {
    final nome = await pedirNomeCategoria(context);
    if (nome == null) return;

    final categoria = await repositorio.criarCategoria(widget.uid, nome);
    await carregarCategorias();
    if (mounted) setState(() => categoriaId = categoria.id);
  }

  bool semAlteracoes(String titulo, String conteudo) {
    final original = widget.nota;
    return original != null &&
        original.titulo == titulo &&
        original.conteudo == conteudo &&
        original.categoriaId == categoriaId;
  }

  Future<void> salvar() async {
    final titulo = controladorTitulo.text.trim();
    final conteudo = controladorConteudo.text.trim();

    if (titulo.isEmpty && conteudo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva um título ou um conteúdo.')),
      );
      return;
    }

    if (semAlteracoes(titulo, conteudo)) {
      Navigator.pop(context, false);
      return;
    }

    final nota = editando
        ? widget.nota!.editar(
            titulo: titulo,
            conteudo: conteudo,
            categoriaId: categoriaId,
          )
        : Nota.nova(
            uid: widget.uid,
            titulo: titulo,
            conteudo: conteudo,
            categoriaId: categoriaId,
          );

    await repositorio.salvar(nota);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    controladorTitulo.dispose();
    controladorConteudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editando ? 'Editar nota' : 'Nova nota',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            onPressed: salvar,
            icon: const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            SeletorCategorias(
              categorias: categorias,
              selecionada: categoriaId,
              rotuloNenhuma: 'Sem categoria',
              aoSelecionar: (id) => setState(() => categoriaId = id),
              aoCriar: criarCategoria,
              emLinhas: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controladorTitulo,
              maxLength: 200,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF292333),
              ),
              decoration: const InputDecoration(
                hintText: 'Título',
                counterText: '',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const Divider(color: Color(0xFFE4DFEA)),
            Expanded(
              child: TextField(
                controller: controladorConteudo,
                maxLength: 50000,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF40394A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  counterText: '',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

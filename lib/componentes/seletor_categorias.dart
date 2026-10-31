import 'package:blocodenotasturmab/modelos/categoria.dart';
import 'package:flutter/material.dart';

class SeletorCategorias extends StatelessWidget {
  final List<Categoria> categorias;
  final String? selecionada;
  final String rotuloNenhuma;
  final ValueChanged<String?> aoSelecionar;
  final VoidCallback? aoCriar;
  final bool emLinhas;

  const SeletorCategorias({
    super.key,
    required this.categorias,
    required this.selecionada,
    required this.rotuloNenhuma,
    required this.aoSelecionar,
    this.aoCriar,
    this.emLinhas = false,
  });

  Widget opcao(String rotulo, String? id) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: selecionada == id,
        showCheckmark: false,
        selectedColor: Color(0xffe8ddf8),
        side: BorderSide(color: Color(0xffe4dfea)),
        onSelected: (_) => aoSelecionar(id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opcoes = [
      opcao(rotuloNenhuma, null),
      for (final categoria in categorias) opcao(categoria.nome, categoria.id),
      if (aoCriar != null)
        ActionChip(
          avatar: Icon(Icons.add_rounded, size: 18),
          label: Text('Nova categoria'),
          side: BorderSide(color: Color(0xffe4dfea)),
          onPressed: aoCriar,
        ),
    ];

    if (emLinhas) return Wrap(runSpacing: 4, children: opcoes);

    return SizedBox(
      height: 42,
      child: ListView(scrollDirection: Axis.horizontal, children: opcoes),
    );
  }
}

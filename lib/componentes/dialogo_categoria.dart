import 'package:flutter/material.dart';

Future<String?> pedirNomeCategoria(BuildContext context) {
  final controlador = TextEditingController();

  void confirmar(BuildContext contexto) {
    final nome = controlador.text.trim();
    if (nome.isNotEmpty) Navigator.pop(contexto, nome);
  }

  return showDialog<String>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('Nova categoria'),
      content: TextField(
        controller: controlador,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Ex.: Academia'),
        onSubmitted: (_) => confirmar(contexto),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => confirmar(contexto),
          child: const Text('Criar'),
        ),
      ],
    ),
  );
}

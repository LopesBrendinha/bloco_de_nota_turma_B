import 'package:flutter/material.dart';

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String acao,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(contexto, true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xffb45f6c)),
          child: Text(acao),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

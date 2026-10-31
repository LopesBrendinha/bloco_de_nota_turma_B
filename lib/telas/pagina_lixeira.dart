import 'dart:async';

import 'package:blocodenotasturmab/componentes/cartao_nota.dart';
import 'package:blocodenotasturmab/componentes/dialogo_confirmacao.dart';
import 'package:blocodenotasturmab/componentes/estado_vazio.dart';
import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:blocodenotasturmab/repositorios/repositorio_notas.dart';
import 'package:flutter/material.dart';

class PaginaLixeira extends StatefulWidget {
  final String uid;

  const PaginaLixeira({super.key, required this.uid});

  @override
  State<PaginaLixeira> createState() => _PaginaLixeiraState();
}

class _PaginaLixeiraState extends State<PaginaLixeira> {
  final repositorio = RepositorioNotas();

  List<Nota> notas = [];

  @override
  void initState() {
    super.initState();
    carregar();
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> carregar() async {
    final resultado = await repositorio.listarLixeira(widget.uid);
    if (mounted) setState(() => notas = resultado);
  }

  Future<void> concluir(String mensagem) async {
    await carregar();
    if (mounted) mostrarMensagem(mensagem);
    unawaited(repositorio.enviarPendentes(widget.uid));
  }

  Future<void> restaurar(Nota nota) async {
    await repositorio.restaurar(nota);
    await concluir('Nota restaurada.');
  }

  Future<void> excluirDefinitivamente(Nota nota) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir para sempre?',
      mensagem: 'A nota será apagada do aparelho e da nuvem.',
      acao: 'Excluir',
    );
    if (!confirmado) return;

    await repositorio.excluirDefinitivamente(nota);
    await concluir('Nota excluída definitivamente.');
  }

  Future<void> esvaziar() async {
    final confirmado = await confirmar(
      context,
      titulo: 'Esvaziar a lixeira?',
      mensagem: 'Todas as ${notas.length} notas serão apagadas para sempre.',
      acao: 'Esvaziar',
    );
    if (!confirmado) return;

    await repositorio.esvaziarLixeira(widget.uid);
    await concluir('Lixeira esvaziada.');
  }

  String prazo(Nota nota) {
    final dias = nota.diasRestantesNaLixeira;
    return dias == 1 ? 'Some em 1 dia' : 'Some em $dias dias';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lixeira',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (notas.isNotEmpty)
            TextButton(onPressed: esvaziar, child: const Text('Esvaziar')),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'As notas ficam aqui por ${Nota.diasNaLixeira} dias e depois '
              'são excluídas definitivamente.',
              style: TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: notas.isEmpty
                  ? ListView(
                      children: const [
                        EstadoVazio(
                          icone: Icons.delete_outline_rounded,
                          titulo: 'Lixeira vazia',
                          descricao: 'As notas excluídas aparecem aqui.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: notas.length,
                      itemBuilder: (context, indice) {
                        final nota = notas[indice];
                        return CartaoNota(
                          nota: nota,
                          legenda: prazo(nota),
                          acoes: [
                            IconButton(
                              tooltip: 'Restaurar',
                              onPressed: () => restaurar(nota),
                              icon: const Icon(
                                Icons.restore_rounded,
                                color: Color(0xff6c4ab6),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Excluir para sempre',
                              onPressed: () => excluirDefinitivamente(nota),
                              icon: const Icon(
                                Icons.delete_forever_outlined,
                                color: Color(0xffb45f6c),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

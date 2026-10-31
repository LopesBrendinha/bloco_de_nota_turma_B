import 'package:blocodenotasturmab/modelos/nota.dart';
import 'package:flutter/material.dart';

class CartaoNota extends StatelessWidget {
  final Nota nota;
  final String legenda;
  final String? nomeCategoria;
  final VoidCallback? aoTocar;
  final List<Widget> acoes;

  const CartaoNota({
    super.key,
    required this.nota,
    required this.legenda,
    this.nomeCategoria,
    this.aoTocar,
    required this.acoes,
  });

  Widget etiquetaCategoria() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Color(0xffede5fa),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        nomeCategoria!,
        style: TextStyle(
          fontSize: 11,
          color: Color(0xff6c4ab6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: aoTocar,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 8, 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xffede5fa),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.note_rounded, color: Color(0xff6c4ab6)),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nota.titulo.isEmpty ? "Sem Título" : nota.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff292333),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      nota.conteudo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xff77717f), height: 1.4),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          nota.sincronizada
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_upload_outlined,
                          size: 14,
                          color: nota.sincronizada
                              ? Color(0xff5b9a74)
                              : Color(0xffc28a3a),
                        ),
                        Text(
                          legenda,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff9a94a1),
                          ),
                        ),
                        if (nomeCategoria != null) etiquetaCategoria(),
                      ],
                    ),
                  ],
                ),
              ),
              ...acoes,
            ],
          ),
        ),
      ),
    );
  }
}

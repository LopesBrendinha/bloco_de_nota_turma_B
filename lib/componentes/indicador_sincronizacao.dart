import 'package:blocodenotasturmab/modelos/resultado_sincronizacao.dart';
import 'package:flutter/material.dart';

class IndicadorSincronizacao extends StatelessWidget {
  final bool sincronizando;
  final int pendentes;
  final ResultadoSincronizacao? ultimoResultado;

  const IndicadorSincronizacao({
    super.key,
    required this.sincronizando,
    required this.pendentes,
    this.ultimoResultado,
  });

  String get textoPendentes {
    if (pendentes == 0) return 'usando as notas do aparelho';
    if (pendentes == 1) return '1 alteração aguardando envio';
    return '$pendentes alterações aguardando envio';
  }

  (IconData, String, Color) get estado {
    if (sincronizando) {
      return (Icons.sync_rounded, 'Sincronizando...', Color(0xff77717f));
    }
    if (ultimoResultado != null && !ultimoResultado!.sucesso) {
      return (
        Icons.cloud_off_outlined,
        'Sem sincronizar · $textoPendentes',
        Color(0xffb45f6c),
      );
    }
    if (pendentes > 0) {
      return (Icons.cloud_upload_outlined, textoPendentes, Color(0xffc28a3a));
    }
    return (Icons.cloud_done_outlined, 'Tudo sincronizado', Color(0xff5b9a74));
  }

  @override
  Widget build(BuildContext context) {
    final (icone, texto, cor) = estado;

    return Row(
      children: [
        Icon(icone, size: 16, color: cor),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cor),
          ),
        ),
      ],
    );
  }
}

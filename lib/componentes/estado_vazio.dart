import 'package:flutter/material.dart';

class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFFEDE5FA),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 50, color: Color(0xFF6C4AB6)),
          ),
          SizedBox(height: 25),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF77717F)),
          ),
        ],
      ),
    );
  }
}

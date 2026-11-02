import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Pauta de caderno desenhada atrás do texto da nota. As linhas acompanham a
/// altura de linha do texto e rolam junto com ele.
class RuledPaper extends StatelessWidget {
  const RuledPaper({
    super.key,
    required this.lineHeight,
    required this.child,
    this.topOffset = 0,
  });

  final double lineHeight;
  final double topOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RulePainter(
        lineHeight: lineHeight,
        topOffset: topOffset,
        rule: Theme.of(context).colorScheme.outline,
      ),
      child: child,
    );
  }
}

class _RulePainter extends CustomPainter {
  _RulePainter({
    required this.lineHeight,
    required this.topOffset,
    required this.rule,
  });

  final double lineHeight;
  final double topOffset;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    final rulePaint = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (var y = topOffset + lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
    }
    final marginPaint = Paint()
      ..color = GrafiteColors.margin
      ..strokeWidth = 1.4;
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.lineHeight != lineHeight ||
      old.topOffset != topOffset ||
      old.rule != rule;
}

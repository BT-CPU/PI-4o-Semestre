import 'package:flutter/material.dart';

// Coloca os cartões lado a lado e ajusta o número de colunas à largura:
// celular = 1 coluna, tablet = 2, computador = colunasMaximas (2 ou 3).
class GradeCartoes extends StatelessWidget {
  final List<Widget> filhos;
  final int colunasMaximas;

  const GradeCartoes({
    super.key,
    required this.filhos,
    this.colunasMaximas = 2,
  });

  int _colunas(double largura) {
    if (largura >= 900) return colunasMaximas;
    if (largura >= 480) return colunasMaximas >= 3 ? 2 : 1;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const espaco = 16.0;
        final largura = constraints.maxWidth;
        final colunas = _colunas(largura);
        // floorToDouble evita a soma passar de "largura" por arredondamento
        final larguraItem =
            ((largura - espaco * (colunas - 1)) / colunas).floorToDouble();

        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final filho in filhos)
              SizedBox(width: larguraItem, child: filho),
          ],
        );
      },
    );
  }
}

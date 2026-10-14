import 'package:flutter/material.dart';

import '../cores.dart';

// Um item do ranking: nome, valor (para o tamanho da barra) e o texto mostrado
class ItemRanking {
  final String rotulo;
  final double valor;
  final String textoValor;

  const ItemRanking(this.rotulo, this.valor, this.textoValor);
}

// Ranking com barras horizontais feitas com Containers (sem pacote).
// O maior valor ocupa a barra inteira; os outros são proporcionais.
// Em espaço largo, cada item fica numa linha só (nome, barra, valor).
// Em espaço estreito, o valor sobe para cima da barra, para não estourar.
class RankingBarras extends StatelessWidget {
  final List<ItemRanking> itens;
  final Color cor;

  const RankingBarras({super.key, required this.itens, this.cor = Cores.azulMedio});

  // A barra em si: um fundo claro com a parte colorida por cima
  Widget _barra(double fator) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          Container(height: 18, color: Cores.fundo),
          FractionallySizedBox(
            // widthFactor precisa ficar entre 0 e 1
            widthFactor: fator.clamp(0.0, 1.0),
            child: Container(height: 18, color: cor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return const Text('Sem dados no período.');
    }

    var maximo = 0.0;
    for (final item in itens) {
      if (item.valor > maximo) maximo = item.valor;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Com menos de 380 px não cabem nome + barra + valor lado a lado
        final estreito = constraints.maxWidth < 380;

        return Column(
          children: [
            for (final item in itens)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: estreito
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.rotulo,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.textoValor,
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _barra(maximo == 0 ? 0 : item.valor / maximo),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              item.rotulo,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(child: _barra(maximo == 0 ? 0 : item.valor / maximo)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 128,
                            child: Text(
                              item.textoValor,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}

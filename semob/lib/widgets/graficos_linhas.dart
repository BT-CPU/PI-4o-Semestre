import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../utils/formatadores.dart';
import 'graficos.dart'; // eixos e estilos compartilhados

// Uma barra do gráfico: a média de viagens e de veículos em uma faixa horária
class PontoHora {
  final int hora;
  final double mediaViagens;
  final double mediaVeiculos;

  const PontoHora(this.hora, this.mediaViagens, this.mediaVeiculos);
}

// Viagens por faixa horária de uma linha (média por dia do período).
// Os pontos já devem chegar na ordem certa (4h ... 23h, 0h).
class GraficoPerfilHorario extends StatelessWidget {
  final List<PontoHora> pontos;

  const GraficoPerfilHorario({super.key, required this.pontos});

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) return const SemDadosGrafico();

    var maximo = 0.0;
    for (final p in pontos) {
      if (p.mediaViagens > maximo) maximo = p.mediaViagens;
    }
    // Eixo com 4 divisões de tamanho inteiro
    final topo = maximo < 1 ? 1.0 : maximo;
    final maxY = (topo / 4).ceilToDouble() * 4;
    final intervalo = maxY / 4;

    final largura = pontos.length <= 12 ? 16.0 : 10.0;
    final passo = pontos.length > 12 ? 2 : 1;

    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < pontos.length; i++) {
      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pontos[i].mediaViagens,
              color: Cores.azulMedio,
              width: largura,
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        barGroups: grupos,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: intervalo,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: semEixo(),
          rightTitles: semEixo(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (valor, meta) {
                final indice = valor.toInt();
                if (valor != indice.toDouble() ||
                    indice < 0 ||
                    indice >= pontos.length ||
                    indice % passo != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text('${pontos[indice].hora}h', style: estiloEixo),
                );
              },
            ),
          ),
          leftTitles: eixoValores(
            (v) => formatarDecimal(v, casas: 0),
            intervalo: intervalo,
            largura: 36,
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (grupo) => Cores.azulEscuro,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final p = pontos[grupo.x];
              return BarTooltipItem(
                'Faixa das ${p.hora}h\n'
                'Viagens por dia: ${formatarDecimal(p.mediaViagens, casas: 1)}\n'
                'Veículos por dia: ${formatarDecimal(p.mediaVeiculos, casas: 1)}',
                estiloTooltip,
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../utils/formatadores.dart';
import '../utils/horas.dart';
import 'graficos.dart'; // eixos e estilos compartilhados

// Uma linha do gráfico (ex.: "Dia útil") com um valor para cada hora
class SerieHoraria {
  final String nome;
  final Color cor;
  final List<double> valores; // na mesma ordem da lista de horas

  const SerieHoraria(this.nome, this.cor, this.valores);
}

// Perfil horário: uma linha por tipo de dia, uma posição por hora
class GraficoPerfilPorTipoDia extends StatelessWidget {
  final List<int> horas; // já na ordem de exibição (4h ... 23h, 0h)
  final List<SerieHoraria> series;
  final String unidade; // "viagens" ou "veículos", usado no balão

  const GraficoPerfilPorTipoDia({
    super.key,
    required this.horas,
    required this.series,
    required this.unidade,
  });

  @override
  Widget build(BuildContext context) {
    if (horas.length < 2 || series.isEmpty) return const SemDadosGrafico();

    var maximo = 0.0;
    for (final s in series) {
      for (final v in s.valores) {
        if (v > maximo) maximo = v;
      }
    }
    // Eixo com 4 divisões de tamanho inteiro
    final topo = maximo < 1 ? 1.0 : maximo;
    final maxY = (topo / 4).ceilToDouble() * 4;
    final intervalo = maxY / 4;
    final passo = horas.length > 12 ? 2 : 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (horas.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
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
                    indice >= horas.length ||
                    indice % passo != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(rotuloHora(horas[indice]), style: estiloEixo),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Cores.azulEscuro,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final serie = series[spot.barIndex];
                final cabecalho = spot.barIndex == 0
                    ? 'Faixa das ${rotuloHora(horas[spot.x.toInt()])}\n'
                    : '';
                return LineTooltipItem(
                  '$cabecalho${serie.nome}: ${formatarDecimal(spot.y, casas: 1)} $unidade',
                  estiloTooltip,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          for (final serie in series)
            LineChartBarData(
              spots: [
                for (var i = 0; i < serie.valores.length; i++)
                  FlSpot(i.toDouble(), serie.valores[i]),
              ],
              isCurved: false,
              color: serie.cor,
              barWidth: 3,
              dotData: FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';
import '../utils/formatadores.dart';
import 'graficos.dart'; // eixos e estilos compartilhados

// Gráficos da tela "Quilometragem" (fl_chart 1.x).
// Como nas outras telas, o eixo X é a POSIÇÃO do dia na lista.

String _cabecalhoDia(DiaOperacao dia) {
  return '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})';
}

// ---------------------------------------------------------------
// 1) Km por dia: barras empilhadas (produtivo + improdutivo)
// ---------------------------------------------------------------
class GraficoKmDiario extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoKmDiario({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const SemDadosGrafico();

    final largura = dias.length > 20 ? 6.0 : (dias.length > 10 ? 12.0 : 20.0);

    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      final d = dias[i];
      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: d.kmTotal,
              width: largura,
              color: Cores.azulMedio,
              // Duas cores na mesma barra: de baixo para cima,
              // primeiro o produtivo e depois o improdutivo
              rodStackItems: [
                BarChartRodStackItem(0, d.kmProdutivo, Cores.azulMedio),
                BarChartRodStackItem(d.kmProdutivo, d.kmTotal, Cores.atencao),
              ],
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: grupos,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: semEixo(),
          rightTitles: semEixo(),
          bottomTitles: eixoDatas(dias),
          leftTitles: eixoValores((v) => formatarCompacto(v)),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (grupo) => Cores.azulEscuro,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final d = dias[grupo.x];
              return BarTooltipItem(
                '${_cabecalhoDia(d)}\n'
                'Produtivo: ${formatarDecimal(d.kmProdutivo, casas: 1)} km\n'
                'Improdutivo: ${formatarDecimal(d.kmImprodutivo, casas: 1)} km\n'
                'Total: ${formatarDecimal(d.kmTotal, casas: 1)} km',
                estiloTooltip,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// 2) % de km improdutivo por dia, com linha tracejada no limite
// ---------------------------------------------------------------
class GraficoKmImprodutivoPercentual extends StatelessWidget {
  final List<DiaOperacao> dias;
  final double limite;

  const GraficoKmImprodutivoPercentual({
    super.key,
    required this.dias,
    required this.limite,
  });

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final pontos = <FlSpot>[];
    var menor = dias.first.percentualKmImprodutivo;
    var maior = dias.first.percentualKmImprodutivo;
    for (var i = 0; i < dias.length; i++) {
      final p = dias[i].percentualKmImprodutivo;
      pontos.add(FlSpot(i.toDouble(), p));
      if (p < menor) menor = p;
      if (p > maior) maior = p;
    }

    // Eixo Y ajustado: sempre inclui os dados e o limite
    final topo = maior > limite ? maior : limite;
    final minY = (menor - 0.5).floorToDouble();
    final maxY = (topo + 0.5).ceilToDouble();
    final intervalo = (maxY - minY) / 4;
    final casas = intervalo == intervalo.roundToDouble() ? 0 : 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (dias.length - 1).toDouble(),
        minY: minY,
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
          bottomTitles: eixoDatas(dias),
          leftTitles: eixoValores(
            (v) => '${formatarDecimal(v, casas: casas)}%',
            intervalo: intervalo,
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: limite,
              color: Cores.erro,
              strokeWidth: 1.5,
              dashArray: [6, 4],
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Cores.azulEscuro,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final d = dias[spot.x.toInt()];
                return LineTooltipItem(
                  '${_cabecalhoDia(d)}\n'
                  'Improdutivo: ${formatarDecimal(d.percentualKmImprodutivo, casas: 2)}%\n'
                  '${formatarDecimal(d.kmImprodutivo, casas: 1)} de '
                  '${formatarDecimal(d.kmTotal, casas: 1)} km',
                  estiloTooltip,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: pontos,
            isCurved: false,
            color: Cores.atencao,
            barWidth: 3,
            dotData: FlDotData(show: dias.length <= 16),
            belowBarData: BarAreaData(
              show: true,
              color: Cores.atencao.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

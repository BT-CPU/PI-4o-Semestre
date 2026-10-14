import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';
import '../utils/formatadores.dart';
import 'graficos.dart'; // eixos e estilos compartilhados

// Gráficos da tela "Passageiros" (fl_chart 1.x).
// Como nas outras telas, o eixo X é a POSIÇÃO do dia na lista.

String _cabecalhoDia(DiaOperacao dia) {
  return '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})';
}

// ---------------------------------------------------------------
// 1) Passageiros por dia: barras empilhadas (catraca + antecipados
//    + não pagantes)
// ---------------------------------------------------------------
class GraficoPassageirosEmpilhado extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoPassageirosEmpilhado({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const SemDadosGrafico();

    final largura = dias.length > 20 ? 6.0 : (dias.length > 10 ? 12.0 : 20.0);

    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      final d = dias[i];
      final c = d.passageirosCatraca.toDouble();
      final a = c + d.passageirosAntecipados;
      final t = a + d.passageirosNaoPagantes;
      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: t,
              width: largura,
              color: Cores.azulClaro,
              // Três cores na mesma barra, de baixo para cima
              rodStackItems: [
                BarChartRodStackItem(0, c, Cores.azulEscuro),
                BarChartRodStackItem(c, a, Cores.azulMedio),
                BarChartRodStackItem(a, t, Cores.azulClaro),
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
                'Catraca: ${formatarInteiro(d.passageirosCatraca)}\n'
                'Antecipados: ${formatarInteiro(d.passageirosAntecipados)}\n'
                'Não pagantes: ${formatarInteiro(d.passageirosNaoPagantes)}\n'
                'Total: ${formatarInteiro(d.passageirosTotal)}',
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
// 2) % de passageiros não pagantes por dia
// ---------------------------------------------------------------
class GraficoPercentualNaoPagantes extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoPercentualNaoPagantes({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final pontos = <FlSpot>[];
    var menor = dias.first.percentualNaoPagantes;
    var maior = dias.first.percentualNaoPagantes;
    for (var i = 0; i < dias.length; i++) {
      final p = dias[i].percentualNaoPagantes;
      pontos.add(FlSpot(i.toDouble(), p));
      if (p < menor) menor = p;
      if (p > maior) maior = p;
    }

    // Eixo Y com 4 divisões de tamanho inteiro (de 5 em 5, por exemplo)
    final minY = ((menor - 2) / 5).floorToDouble() * 5;
    final faixa = ((maior + 2 - minY) / 4).ceilToDouble() * 4;
    final maxY = minY + faixa;
    final intervalo = faixa / 4;

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
            (v) => '${formatarDecimal(v, casas: 0)}%',
            intervalo: intervalo,
            largura: 44,
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Cores.azulEscuro,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final d = dias[spot.x.toInt()];
                return LineTooltipItem(
                  '${_cabecalhoDia(d)}\n'
                  'Não pagantes: ${formatarDecimal(d.percentualNaoPagantes, casas: 1)}%\n'
                  '${formatarInteiro(d.passageirosNaoPagantes)} de '
                  '${formatarInteiro(d.passageirosTotal)}',
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
            color: Cores.azulMedio,
            barWidth: 3,
            dotData: FlDotData(show: dias.length <= 16),
            belowBarData: BarAreaData(
              show: true,
              color: Cores.azulClaro.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 3) Composição dos passageiros no período (gráfico de rosca)
// ---------------------------------------------------------------
class GraficoComposicaoPassageiros extends StatelessWidget {
  final int catraca;
  final int antecipados;
  final int naoPagantes;

  const GraficoComposicaoPassageiros({
    super.key,
    required this.catraca,
    required this.antecipados,
    required this.naoPagantes,
  });

  @override
  Widget build(BuildContext context) {
    final total = catraca + antecipados + naoPagantes;
    if (total == 0) return const SemDadosGrafico();

    PieChartSectionData fatia(int valor, Color cor) {
      final pct = valor / total * 100;
      return PieChartSectionData(
        value: valor.toDouble(),
        color: cor,
        radius: 60,
        // Fatia muito pequena não cabe o texto, então não mostra
        showTitle: pct >= 8,
        title: '${formatarDecimal(pct, casas: 1)}%',
        // Texto escuro na fatia clara (branco sobre azulClaro quase não se lê)
        titleStyle: TextStyle(
          color: cor == Cores.azulClaro ? Cores.azulEscuro : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: [
          fatia(catraca, Cores.azulEscuro),
          fatia(antecipados, Cores.azulMedio),
          fatia(naoPagantes, Cores.azulClaro),
        ],
      ),
    );
  }
}

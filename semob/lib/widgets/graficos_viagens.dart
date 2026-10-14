import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';
import '../utils/formatadores.dart';
import 'graficos.dart'; // eixos e estilos compartilhados

// Gráficos da tela "Viagens e cumprimento" (fl_chart 1.x).
// Como na Visão Geral, o eixo X é a POSIÇÃO do dia na lista.

double _larguraBarra(int quantidadeDias, {required int barrasPorDia}) {
  // Barras mais finas quando há muitos dias
  if (quantidadeDias > 20) return barrasPorDia == 2 ? 3.0 : 6.0;
  if (quantidadeDias > 10) return barrasPorDia == 2 ? 6.0 : 10.0;
  return barrasPorDia == 2 ? 10.0 : 16.0;
}

String _cabecalhoDia(DiaOperacao dia) {
  return '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})';
}

// ---------------------------------------------------------------
// 1) Viagens programadas x realizadas por dia (barras lado a lado)
// ---------------------------------------------------------------
class GraficoProgramadasRealizadas extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoProgramadasRealizadas({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const SemDadosGrafico();

    final largura = _larguraBarra(dias.length, barrasPorDia: 2);
    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      grupos.add(
        BarChartGroupData(
          x: i,
          barsSpace: 1,
          barRods: [
            BarChartRodData(
              toY: dias[i].viagensProgramadas.toDouble(),
              color: Cores.azulClaro,
              width: largura,
            ),
            BarChartRodData(
              toY: dias[i].viagensRealizadas.toDouble(),
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
        barGroups: grupos,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: semEixo(),
          rightTitles: semEixo(),
          bottomTitles: eixoDatas(dias),
          leftTitles: eixoValores((v) => formatarInteiro(v.toInt())),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (grupo) => Cores.azulEscuro,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final dia = dias[grupo.x];
              final nome = indiceBarra == 0 ? 'Programadas' : 'Realizadas';
              return BarTooltipItem(
                '${_cabecalhoDia(dia)}\n'
                '$nome: ${formatarInteiro(barra.toY.toInt())}',
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
// 2) Viagens não realizadas por dia (programadas - realizadas)
// ---------------------------------------------------------------
class GraficoNaoRealizadas extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoNaoRealizadas({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const SemDadosGrafico();

    var maximo = 0;
    for (final d in dias) {
      if (d.viagensNaoRealizadas > maximo) maximo = d.viagensNaoRealizadas;
    }
    // Eixo com números inteiros: 4 divisões de tamanho inteiro
    final topo = maximo < 4 ? 4 : maximo;
    final intervalo = (topo / 4).ceilToDouble();
    final maxY = intervalo * 4;

    final largura = _larguraBarra(dias.length, barrasPorDia: 1);
    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dias[i].viagensNaoRealizadas.toDouble(),
              color: Cores.atencao,
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
          bottomTitles: eixoDatas(dias),
          leftTitles: eixoValores(
            (v) => formatarInteiro(v.toInt()),
            intervalo: intervalo,
            largura: 36,
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (grupo) => Cores.azulEscuro,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final dia = dias[grupo.x];
              return BarTooltipItem(
                '${_cabecalhoDia(dia)}\n'
                'Não realizadas: ${formatarInteiro(dia.viagensNaoRealizadas)}\n'
                'de ${formatarInteiro(dia.viagensProgramadas)} programadas',
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
// 3) FCV por faixa do dia (manhã, tarde, noite)
// ---------------------------------------------------------------
class GraficoFcvFaixas extends StatelessWidget {
  final List<DiaOperacao> dias;
  final double limite;

  const GraficoFcvFaixas({super.key, required this.dias, required this.limite});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final manha = <FlSpot>[];
    final tarde = <FlSpot>[];
    final noite = <FlSpot>[];
    var menor = 100.0;
    var maior = 100.0;

    for (var i = 0; i < dias.length; i++) {
      final x = i.toDouble();
      final d = dias[i];
      manha.add(FlSpot(x, d.fcvManha));
      tarde.add(FlSpot(x, d.fcvTarde));
      noite.add(FlSpot(x, d.fcvNoite));
      for (final v in [d.fcvManha, d.fcvTarde, d.fcvNoite]) {
        if (v < menor) menor = v;
        if (v > maior) maior = v;
      }
    }

    // Eixo Y ajustado aos dados (o FCV fica sempre perto de 100%)
    final minY = (menor - 0.5).floorToDouble();
    final maxY = maior > 100 ? maior.ceilToDouble() : 100.0;
    final intervalo = (maxY - minY) / 4;
    final casas = intervalo < 0.5 ? 2 : 1;
    final pontosDots = dias.length <= 16;

    LineChartBarData linha(List<FlSpot> pontos, Color cor) {
      return LineChartBarData(
        spots: pontos,
        isCurved: false,
        color: cor,
        barWidth: 2.5,
        dotData: FlDotData(show: pontosDots),
      );
    }

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
                final dia = dias[spot.x.toInt()];
                String nome;
                int programadas;
                int realizadas;
                if (spot.barIndex == 0) {
                  nome = 'Manhã';
                  programadas = dia.manhaProgramadas;
                  realizadas = dia.manhaRealizadas;
                } else if (spot.barIndex == 1) {
                  nome = 'Tarde';
                  programadas = dia.tardeProgramadas;
                  realizadas = dia.tardeRealizadas;
                } else {
                  nome = 'Noite';
                  programadas = dia.noiteProgramadas;
                  realizadas = dia.noiteRealizadas;
                }
                final cabecalho =
                    spot.barIndex == 0 ? '${_cabecalhoDia(dia)}\n' : '';
                return LineTooltipItem(
                  '$cabecalho$nome: ${formatarDecimal(spot.y, casas: 2)}% '
                  '($realizadas/$programadas)',
                  estiloTooltip,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          linha(manha, Cores.azulEscuro),
          linha(tarde, Cores.azulMedio),
          linha(noite, Cores.azulClaro),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 4) Veículos por dia (no dia e máximo por faixa horária)
// ---------------------------------------------------------------
class GraficoVeiculos extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoVeiculos({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final noDia = <FlSpot>[];
    final porFaixa = <FlSpot>[];
    for (var i = 0; i < dias.length; i++) {
      noDia.add(FlSpot(i.toDouble(), dias[i].veiculos.toDouble()));
      porFaixa.add(FlSpot(i.toDouble(), dias[i].maxVeiculosFaixa.toDouble()));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (dias.length - 1).toDouble(),
        minY: 0,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: semEixo(),
          rightTitles: semEixo(),
          bottomTitles: eixoDatas(dias),
          leftTitles: eixoValores(
            (v) => formatarInteiro(v.toInt()),
            largura: 36,
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Cores.azulEscuro,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final dia = dias[spot.x.toInt()];
                final nome =
                    spot.barIndex == 0 ? 'Veículos no dia' : 'Máx. por faixa';
                final cabecalho =
                    spot.barIndex == 0 ? '${_cabecalhoDia(dia)}\n' : '';
                return LineTooltipItem(
                  '$cabecalho$nome: ${spot.y.toInt()}',
                  estiloTooltip,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: noDia,
            isCurved: false,
            color: Cores.azulEscuro,
            barWidth: 3,
            dotData: FlDotData(show: dias.length <= 16),
          ),
          LineChartBarData(
            spots: porFaixa,
            isCurved: false,
            color: Cores.azulClaro,
            barWidth: 3,
            dotData: FlDotData(show: dias.length <= 16),
          ),
        ],
      ),
    );
  }
}

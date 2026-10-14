import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';
import '../utils/formatadores.dart';

// Gráficos da Visão Geral (e funções auxiliares usadas por outras telas), feitos com o pacote fl_chart (versão 1.x).
// Em todos eles o eixo X é a POSIÇÃO do dia na lista (0, 1, 2...)
// e as datas são escritas no eixo a partir dessa posição.

const TextStyle estiloEixo = TextStyle(fontSize: 11, color: Colors.black54);
const TextStyle estiloTooltip = TextStyle(color: Colors.white, fontSize: 12);

// De quantos em quantos dias aparece uma data no eixo (para não encavalar)
int passoRotulos(int quantidade) {
  if (quantidade <= 8) return 1;
  if (quantidade <= 16) return 2;
  if (quantidade <= 24) return 3;
  return 5;
}

AxisTitles semEixo() {
  return AxisTitles(sideTitles: SideTitles(showTitles: false));
}

// Eixo de baixo: datas no formato dd/MM
AxisTitles eixoDatas(List<DiaOperacao> dias) {
  final passo = passoRotulos(dias.length);
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 28,
      interval: 1,
      getTitlesWidget: (valor, meta) {
        final indice = valor.toInt();
        // Só escreve nas posições inteiras que são múltiplas do passo
        if (valor != indice.toDouble() ||
            indice < 0 ||
            indice >= dias.length ||
            indice % passo != 0) {
          return const SizedBox.shrink();
        }
        return SideTitleWidget(
          meta: meta,
          space: 6,
          child: Text(formatarDataCurta(dias[indice].data), style: estiloEixo),
        );
      },
    ),
  );
}

// Eixo da esquerda: valores formatados pela função recebida
AxisTitles eixoValores(
  String Function(double) formatar, {
  double? intervalo,
  double largura = 52,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: largura,
      interval: intervalo,
      getTitlesWidget: (valor, meta) {
        return SideTitleWidget(
          meta: meta,
          space: 6,
          child: Text(formatar(valor), style: estiloEixo),
        );
      },
    ),
  );
}

class SemDadosGrafico extends StatelessWidget {
  const SemDadosGrafico({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Dados insuficientes para o gráfico.'));
  }
}

// ---------------------------------------------------------------
// Legenda (quadradinho colorido + texto)
// ---------------------------------------------------------------
class ItemLegenda {
  final Color cor;
  final String texto;

  const ItemLegenda(this.cor, this.texto);
}

class LegendaGrafico extends StatelessWidget {
  final List<ItemLegenda> itens;

  const LegendaGrafico({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final item in itens)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: item.cor),
              const SizedBox(width: 6),
              Text(item.texto, style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// 1) Passageiros por dia: total e não pagantes
// ---------------------------------------------------------------
class GraficoPassageiros extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoPassageiros({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final pontosTotal = <FlSpot>[];
    final pontosNaoPagantes = <FlSpot>[];
    for (var i = 0; i < dias.length; i++) {
      pontosTotal.add(
        FlSpot(i.toDouble(), dias[i].passageirosTotal.toDouble()),
      );
      pontosNaoPagantes.add(
        FlSpot(i.toDouble(), dias[i].passageirosNaoPagantes.toDouble()),
      );
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
          leftTitles: eixoValores((v) => formatarCompacto(v)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Cores.azulEscuro,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final dia = dias[spot.x.toInt()];
                final nome = spot.barIndex == 0 ? 'Total' : 'Não pagantes';
                final cabecalho = spot.barIndex == 0
                    ? '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})\n'
                    : '';
                return LineTooltipItem(
                  '$cabecalho$nome: ${formatarInteiro(spot.y.toInt())}',
                  estiloTooltip,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: pontosTotal,
            isCurved: false,
            color: Cores.azulEscuro,
            barWidth: 3,
            dotData: FlDotData(show: dias.length <= 16),
          ),
          LineChartBarData(
            spots: pontosNaoPagantes,
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

// ---------------------------------------------------------------
// 2) FCV por dia, com linha tracejada no limite
// ---------------------------------------------------------------
class GraficoFcv extends StatelessWidget {
  final List<DiaOperacao> dias;
  final double limite;

  const GraficoFcv({super.key, required this.dias, required this.limite});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final pontos = <FlSpot>[];
    var menor = dias.first.fcv;
    var maior = dias.first.fcv;
    for (var i = 0; i < dias.length; i++) {
      final fcv = dias[i].fcv;
      pontos.add(FlSpot(i.toDouble(), fcv));
      if (fcv < menor) menor = fcv;
      if (fcv > maior) maior = fcv;
    }

    // Eixo Y ajustado aos dados (o FCV fica sempre perto de 100%)
    final minY = (menor - 0.5).floorToDouble();
    final maxY = maior > 100 ? maior.ceilToDouble() : 100.0;
    final intervalo = (maxY - minY) / 4;
    final casas = intervalo < 0.5 ? 2 : 1;

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
        // Linha tracejada vermelha no limite definido pela SEMOB
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
                return LineTooltipItem(
                  '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})\n'
                  'FCV: ${formatarDecimal(dia.fcv, casas: 2)}%\n'
                  '${formatarInteiro(dia.viagensRealizadas)} de '
                  '${formatarInteiro(dia.viagensProgramadas)} viagens',
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
// 3) Vendas x utilização de créditos por dia (barras lado a lado)
// ---------------------------------------------------------------
class GraficoFinanceiro extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoFinanceiro({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    // Barras mais finas quando há muitos dias
    final larguraBarra = dias.length > 20 ? 3.0 : (dias.length > 10 ? 6.0 : 10.0);

    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      grupos.add(
        BarChartGroupData(
          x: i,
          barsSpace: 1,
          barRods: [
            BarChartRodData(
              toY: dias[i].vendas,
              color: Cores.azulMedio,
              width: larguraBarra,
            ),
            BarChartRodData(
              toY: dias[i].utilizacao,
              color: Cores.azulClaro,
              width: larguraBarra,
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
              final dia = dias[grupo.x];
              final nome = indiceBarra == 0 ? 'Vendas' : 'Utilização';
              return BarTooltipItem(
                '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})\n'
                '$nome: ${formatarMoeda(barra.toY)}',
                estiloTooltip,
              );
            },
          ),
        ),
      ),
    );
  }
}

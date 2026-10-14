import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';
import '../utils/formatadores.dart';
import 'graficos.dart'; // eixos e estilos compartilhados
// (o gráfico "Vendas x utilização por dia" já existe em graficos.dart)

// Gráficos da tela "Financeiro" (fl_chart 1.x).
// Como nas outras telas, o eixo X é a POSIÇÃO do dia na lista.

String _cabecalhoDia(DiaOperacao dia) {
  return '${formatarDataCurta(dia.data)} (${nomeDiaSemana(dia.data)})';
}

// ---------------------------------------------------------------
// 1) Acumulado no período: vendas e utilização somadas dia a dia
// ---------------------------------------------------------------
class GraficoFinanceiroAcumulado extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoFinanceiroAcumulado({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final vendas = <FlSpot>[];
    final utilizacao = <FlSpot>[];
    final somaVendas = <double>[];
    final somaUso = <double>[];
    var v = 0.0;
    var u = 0.0;
    for (var i = 0; i < dias.length; i++) {
      v += dias[i].vendas;
      u += dias[i].utilizacao;
      somaVendas.add(v);
      somaUso.add(u);
      vendas.add(FlSpot(i.toDouble(), v));
      utilizacao.add(FlSpot(i.toDouble(), u));
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
          leftTitles: eixoValores((valor) => formatarCompacto(valor)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Cores.azulEscuro,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final indice = spot.x.toInt();
                final nome = spot.barIndex == 0
                    ? 'Vendas acumuladas'
                    : 'Utilização acumulada';
                final cabecalho = spot.barIndex == 0
                    ? '${_cabecalhoDia(dias[indice])}\n'
                    : '';
                return LineTooltipItem(
                  '$cabecalho$nome: ${formatarMoeda(spot.y)}',
                  estiloTooltip,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: vendas,
            isCurved: false,
            color: Cores.azulMedio,
            barWidth: 3,
            dotData: FlDotData(show: dias.length <= 16),
          ),
          LineChartBarData(
            spots: utilizacao,
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
// 2) Saldo do sistema por dia
// ---------------------------------------------------------------
class GraficoSaldoSistema extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoSaldoSistema({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.length < 2) return const SemDadosGrafico();

    final pontos = <FlSpot>[];
    var menor = dias.first.saldoSistema;
    var maior = dias.first.saldoSistema;
    for (var i = 0; i < dias.length; i++) {
      final saldo = dias[i].saldoSistema;
      pontos.add(FlSpot(i.toDouble(), saldo));
      if (saldo < menor) menor = saldo;
      if (saldo > maior) maior = saldo;
    }

    // O saldo é grande (milhões) e varia pouco: o eixo não começa no zero,
    // senão a linha ficaria achatada. Uma margem evita a linha colar na borda.
    final variacao = maior - menor;
    final margem = variacao == 0 ? 100000.0 : variacao * 0.15;
    final minY = menor - margem;
    final maxY = maior + margem;
    final intervalo = (maxY - minY) / 4;
    // Casas decimais (em milhões) suficientes para os rótulos não se repetirem
    final casas = intervalo >= 100000 ? 1 : (intervalo >= 10000 ? 2 : 3);

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
            (valor) => '${formatarDecimal(valor / 1000000, casas: casas)} mi',
            intervalo: intervalo,
            largura: 68,
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
                  'Saldo: ${formatarMoeda(d.saldoSistema)}\n'
                  'Transferido no dia: ${formatarMoeda(d.creditosTransferidos)}',
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
            color: Cores.azulEscuro,
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
// 3) Créditos transferidos para cartões por dia
// ---------------------------------------------------------------
class GraficoCreditosTransferidos extends StatelessWidget {
  final List<DiaOperacao> dias;

  const GraficoCreditosTransferidos({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const SemDadosGrafico();

    var maximo = 0.0;
    for (final d in dias) {
      if (d.creditosTransferidos > maximo) maximo = d.creditosTransferidos;
    }

    final largura = dias.length > 20 ? 6.0 : (dias.length > 10 ? 12.0 : 20.0);
    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dias[i].creditosTransferidos,
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
        // Se nada foi transferido, evita um eixo de altura zero
        maxY: maximo == 0 ? 100 : null,
        barGroups: grupos,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: semEixo(),
          rightTitles: semEixo(),
          bottomTitles: eixoDatas(dias),
          leftTitles: eixoValores((valor) => formatarCompacto(valor)),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (grupo) => Cores.azulEscuro,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final d = dias[grupo.x];
              return BarTooltipItem(
                '${_cabecalhoDia(d)}\n'
                'Transferido: ${formatarMoeda(d.creditosTransferidos)}\n'
                'Vendas do dia: ${formatarMoeda(d.vendas)}',
                estiloTooltip,
              );
            },
          ),
        ),
      ),
    );
  }
}

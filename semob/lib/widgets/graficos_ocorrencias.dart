import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';
import '../utils/formatadores.dart';
import '../utils/horas.dart';
import '../utils/ocorrencias.dart';
import 'graficos.dart'; // eixos e estilos compartilhados

// Gráficos da tela "Ocorrências" (fl_chart 1.x): barras empilhadas, uma cor
// para cada tipo de ocorrência.

// Quantas ocorrências de cada tipo (de um dia ou de uma hora)
class _Contagem {
  int naoRealizadas = 0;
  int naoIniciadas = 0;
  int naoTerminadas = 0;

  int get total => naoRealizadas + naoIniciadas + naoTerminadas;

  void somar(TipoOcorrencia tipo) {
    switch (tipo) {
      case TipoOcorrencia.naoRealizada:
        naoRealizadas++;
        break;
      case TipoOcorrencia.naoIniciada:
        naoIniciadas++;
        break;
      case TipoOcorrencia.naoTerminada:
        naoTerminadas++;
        break;
    }
  }

  // Texto do balão: só os tipos que aconteceram
  String texto() {
    final linhas = <String>[];
    if (naoRealizadas > 0) linhas.add('Não realizadas: $naoRealizadas');
    if (naoIniciadas > 0) linhas.add('Não iniciadas: $naoIniciadas');
    if (naoTerminadas > 0) linhas.add('Não terminadas: $naoTerminadas');
    linhas.add('Total: $total');
    return linhas.join('\n');
  }
}

// Uma barra com 3 cores empilhadas
BarChartRodData _barra(_Contagem c, double largura) {
  final nr = c.naoRealizadas.toDouble();
  final ni = nr + c.naoIniciadas;
  final nt = ni + c.naoTerminadas;
  return BarChartRodData(
    toY: nt,
    width: largura,
    color: corTipoOcorrencia(TipoOcorrencia.naoRealizada),
    rodStackItems: [
      BarChartRodStackItem(0, nr, corTipoOcorrencia(TipoOcorrencia.naoRealizada)),
      BarChartRodStackItem(nr, ni, corTipoOcorrencia(TipoOcorrencia.naoIniciada)),
      BarChartRodStackItem(ni, nt, corTipoOcorrencia(TipoOcorrencia.naoTerminada)),
    ],
  );
}

// Eixo com números inteiros: 4 divisões de tamanho inteiro
double _intervaloInteiro(int maximo) {
  final topo = maximo < 4 ? 4 : maximo;
  return (topo / 4).ceilToDouble();
}

// ---------------------------------------------------------------
// 1) Ocorrências por dia
// ---------------------------------------------------------------
class GraficoOcorrenciasPorDia extends StatelessWidget {
  final List<DiaOperacao> dias;
  final List<Ocorrencia> ocorrencias;

  const GraficoOcorrenciasPorDia({
    super.key,
    required this.dias,
    required this.ocorrencias,
  });

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const SemDadosGrafico();

    final porDia = <DateTime, _Contagem>{};
    for (final o in ocorrencias) {
      porDia.putIfAbsent(o.data, () => _Contagem()).somar(o.tipo);
    }
    final contagens = [for (final d in dias) porDia[d.data] ?? _Contagem()];

    var maximo = 0;
    for (final c in contagens) {
      if (c.total > maximo) maximo = c.total;
    }
    final intervalo = _intervaloInteiro(maximo);
    final largura = dias.length > 20 ? 6.0 : (dias.length > 10 ? 12.0 : 20.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: intervalo * 4,
        barGroups: [
          for (var i = 0; i < contagens.length; i++)
            BarChartGroupData(x: i, barRods: [_barra(contagens[i], largura)]),
        ],
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
              final d = dias[grupo.x];
              return BarTooltipItem(
                '${formatarDataCurta(d.data)} (${nomeDiaSemana(d.data)})\n'
                '${contagens[grupo.x].texto()}',
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
// 2) Ocorrências por faixa horária (horário programado de início)
// ---------------------------------------------------------------
class GraficoOcorrenciasPorHora extends StatelessWidget {
  final List<Ocorrencia> ocorrencias;

  const GraficoOcorrenciasPorHora({super.key, required this.ocorrencias});

  // Horas de operação, para as horas sem ocorrência aparecerem vazias
  static const List<int> _horasPadrao = [
    4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final porHora = <int, _Contagem>{};
    for (final o in ocorrencias) {
      final hora = o.inicioProgramado?.hour;
      if (hora == null) continue;
      porHora.putIfAbsent(hora, () => _Contagem()).somar(o.tipo);
    }

    // Horas padrão + qualquer hora fora delas que tenha ocorrência
    final horas = {..._horasPadrao, ...porHora.keys}.toList()
      ..sort((a, b) => ordemHora(a).compareTo(ordemHora(b)));
    final contagens = [for (final h in horas) porHora[h] ?? _Contagem()];

    var maximo = 0;
    for (final c in contagens) {
      if (c.total > maximo) maximo = c.total;
    }
    final intervalo = _intervaloInteiro(maximo);
    final passo = horas.length > 12 ? 2 : 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: intervalo * 4,
        barGroups: [
          for (var i = 0; i < contagens.length; i++)
            BarChartGroupData(x: i, barRods: [_barra(contagens[i], 10)]),
        ],
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
            (v) => formatarInteiro(v.toInt()),
            intervalo: intervalo,
            largura: 36,
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (grupo) => Cores.azulEscuro,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              return BarTooltipItem(
                'Faixa das ${rotuloHora(horas[grupo.x])}\n'
                '${contagens[grupo.x].texto()}',
                estiloTooltip,
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../cores.dart';
import '../limites.dart';
import '../models/dados_periodo.dart';
import '../models/dia_operacao.dart';
import '../models/periodo.dart';
import '../models/resumo_periodo.dart';
import '../servicos/dados_servico.dart';
import '../servicos/filtro_global.dart';
import '../utils/formatadores.dart';
import '../utils/tipo_dia.dart';
import '../utils/variacoes.dart';
import '../widgets/appbar_semob.dart';
import '../widgets/cartao_indicador.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grade_cartoes.dart';
import '../widgets/graficos.dart';
import '../widgets/graficos_passageiros.dart';
import '../widgets/menu_dashboard.dart';

// Tela 4: Passageiros
class TelaPassageiros extends StatefulWidget {
  final String nomeUsuario;

  const TelaPassageiros({super.key, required this.nomeUsuario});

  @override
  State<TelaPassageiros> createState() => _TelaPassageirosState();
}

class _TelaPassageirosState extends State<TelaPassageiros> {
  TipoPeriodo _tipo = FiltroGlobal.tipo;
  DateTime _dataRef = FiltroGlobal.dataRef ?? DadosServico.dataMaxima;

  bool _carregando = true;
  DadosPeriodo? _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
    });

    final dados = await DadosServico.carregarPeriodo(_tipo, _dataRef);

    // Depois de um await, confere se a tela ainda existe
    if (!mounted) return;
    setState(() {
      _dados = dados;
      _carregando = false;
    });
  }

  Future<void> _escolherData() async {
    final data = await escolherDataReferencia(context, _dataRef);
    if (data == null) return;

    setState(() {
      _dataRef = data;
      FiltroGlobal.dataRef = data;
    });
    await _carregar();
  }

  // ------------------------------------------------------------
  // Cartões de indicadores
  // ------------------------------------------------------------
  List<Widget> _cartoesIndicadores(DadosPeriodo dados) {
    final r = dados.resumo;
    final ant = dados.resumoAnterior;
    final rotulo = rotuloComparacao(_tipo);

    // Quanto uma parte representa do total de passageiros, em %
    double participacao(int parte) {
      if (r.passageirosTotal == 0) return 0;
      return parte / r.passageirosTotal * 100;
    }

    final mediaDia =
        r.quantidadeDias == 0 ? 0.0 : r.passageirosTotal / r.quantidadeDias;

    return [
      CartaoIndicador(
        titulo: 'Total de passageiros',
        icone: Icons.groups,
        valor: formatarInteiro(r.passageirosTotal),
        detalhe: 'Média de ${formatarInteiro(mediaDia.round())} por dia',
        variacao: variacaoPercentual(
          r.passageirosTotal.toDouble(),
          ant?.passageirosTotal.toDouble(),
          rotulo,
          boaQuandoSobe: true,
        ),
      ),
      CartaoIndicador(
        titulo: 'Catraca',
        icone: Icons.payments,
        valor: formatarInteiro(r.passageirosCatraca),
        detalhe:
            '${formatarDecimal(participacao(r.passageirosCatraca), casas: 1)}% do total',
        variacao: variacaoPercentual(
          r.passageirosCatraca.toDouble(),
          ant?.passageirosCatraca.toDouble(),
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Antecipados',
        icone: Icons.credit_card,
        valor: formatarInteiro(r.passageirosAntecipados),
        detalhe:
            '${formatarDecimal(participacao(r.passageirosAntecipados), casas: 1)}% do total',
        variacao: variacaoPercentual(
          r.passageirosAntecipados.toDouble(),
          ant?.passageirosAntecipados.toDouble(),
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Não pagantes',
        icone: Icons.person_off,
        valor: formatarInteiro(r.passageirosNaoPagantes),
        detalhe:
            '${formatarDecimal(r.percentualNaoPagantes, casas: 1)}% do total',
        variacao: variacaoPercentual(
          r.passageirosNaoPagantes.toDouble(),
          ant?.passageirosNaoPagantes.toDouble(),
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Passageiros por viagem',
        icone: Icons.people_alt,
        valor: formatarDecimal(r.passageirosPorViagem, casas: 1),
        detalhe: 'Passageiros ÷ viagens realizadas',
        variacao: variacaoPercentual(
          r.passageirosPorViagem,
          ant?.passageirosPorViagem,
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Passageiros por km (IPK)',
        icone: Icons.speed,
        valor: formatarDecimal(r.passageirosPorKm, casas: 2),
        detalhe: 'Passageiros ÷ km total rodado',
        dica: 'IPK = índice de passageiros por quilômetro. Aqui usa o km '
            'total (produtivo + improdutivo). Confirmar com a SEMOB se '
            'prefere usar só o km produtivo.',
        variacao: variacaoPercentual(
          r.passageirosPorKm,
          ant?.passageirosPorKm,
          rotulo,
        ),
      ),
    ];
  }

  // ------------------------------------------------------------
  // Tabelas
  // ------------------------------------------------------------
  // Média por tipo de dia (dia útil, sábado e domingo)
  Widget _tabelaTipoDia(List<DiaOperacao> dias) {
    final grupos = <String, List<DiaOperacao>>{
      'Dia útil': [],
      'Sábado': [],
      'Domingo': [],
    };
    for (final d in dias) {
      grupos[tipoDia(d.data)]!.add(d);
    }

    final linhas = <DataRow>[];
    grupos.forEach((nome, lista) {
      if (lista.isEmpty) return;

      var passageiros = 0;
      var naoPagantes = 0;
      var viagens = 0;
      var km = 0.0;
      for (final d in lista) {
        passageiros += d.passageirosTotal;
        naoPagantes += d.passageirosNaoPagantes;
        viagens += d.viagensRealizadas;
        km += d.kmTotal;
      }
      final n = lista.length;

      linhas.add(
        DataRow(
          cells: [
            DataCell(Text(nome, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('$n')),
            DataCell(Text(formatarInteiro((passageiros / n).round()))),
            DataCell(
              Text(
                '${formatarDecimal(passageiros == 0 ? 0 : naoPagantes / passageiros * 100, casas: 1)}%',
              ),
            ),
            DataCell(
              Text(formatarDecimal(viagens == 0 ? 0 : passageiros / viagens, casas: 1)),
            ),
            DataCell(
              Text(formatarDecimal(km == 0 ? 0 : passageiros / km, casas: 2)),
            ),
          ],
        ),
      );
    });

    if (linhas.isEmpty) return const Text('Sem dados no período.');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Tipo de dia')),
          DataColumn(label: Text('Dias'), numeric: true),
          DataColumn(label: Text('Passageiros/dia'), numeric: true),
          DataColumn(label: Text('% não pag.'), numeric: true),
          DataColumn(label: Text('Pass./viagem'), numeric: true),
          DataColumn(label: Text('Pass./km'), numeric: true),
        ],
        rows: linhas,
      ),
    );
  }

  // Célula de desvio: quanto o total do dia fugiu da média do mesmo tipo
  // de dia no período. Fica vermelha se passar do limite.
  DataCell _celulaDesvio(
    DiaOperacao d,
    Map<String, double> somas,
    Map<String, int> contagens,
  ) {
    final tipo = tipoDia(d.data);
    final n = contagens[tipo] ?? 0;
    final soma = somas[tipo] ?? 0;

    // Com menos de 2 dias do mesmo tipo não há média para comparar
    if (n < 2 || soma == 0) return const DataCell(Text('-'));

    final media = soma / n;
    final desvio = (d.passageirosTotal / media - 1) * 100;
    final atipico = desvio.abs() > limiteDesvioPassageiros;
    final sinal = desvio > 0 ? '+' : '';

    return DataCell(
      Text(
        '$sinal${formatarDecimal(desvio, casas: 1)}%',
        style: TextStyle(
          color: atipico ? Cores.erro : null,
          fontWeight: atipico ? FontWeight.bold : null,
        ),
      ),
    );
  }

  Widget _tabelaDiaria(List<DiaOperacao> dias, ResumoPeriodo r) {
    // Soma e quantidade de dias de cada tipo, para calcular o desvio
    final somas = <String, double>{};
    final contagens = <String, int>{};
    for (final d in dias) {
      final tipo = tipoDia(d.data);
      somas[tipo] = (somas[tipo] ?? 0) + d.passageirosTotal;
      contagens[tipo] = (contagens[tipo] ?? 0) + 1;
    }

    final linhas = <DataRow>[
      for (final d in dias)
        DataRow(
          cells: [
            DataCell(Text(formatarData(d.data))),
            DataCell(Text(nomeDiaSemana(d.data))),
            DataCell(Text(formatarInteiro(d.passageirosCatraca))),
            DataCell(Text(formatarInteiro(d.passageirosAntecipados))),
            DataCell(Text(formatarInteiro(d.passageirosNaoPagantes))),
            DataCell(Text(formatarInteiro(d.passageirosTotal))),
            DataCell(Text('${formatarDecimal(d.percentualNaoPagantes, casas: 1)}%')),
            DataCell(Text(formatarDecimal(d.passageirosPorViagem, casas: 1))),
            DataCell(Text(formatarDecimal(d.passageirosPorKm, casas: 2))),
            _celulaDesvio(d, somas, contagens),
          ],
        ),
    ];

    // Última linha: total do período
    const negrito = TextStyle(fontWeight: FontWeight.bold);
    linhas.add(
      DataRow(
        color: WidgetStatePropertyAll<Color?>(Cores.fundo),
        cells: [
          const DataCell(Text('Período', style: negrito)),
          const DataCell(Text('')),
          DataCell(Text(formatarInteiro(r.passageirosCatraca), style: negrito)),
          DataCell(Text(formatarInteiro(r.passageirosAntecipados), style: negrito)),
          DataCell(Text(formatarInteiro(r.passageirosNaoPagantes), style: negrito)),
          DataCell(Text(formatarInteiro(r.passageirosTotal), style: negrito)),
          DataCell(
            Text(
              '${formatarDecimal(r.percentualNaoPagantes, casas: 1)}%',
              style: negrito,
            ),
          ),
          DataCell(Text(formatarDecimal(r.passageirosPorViagem, casas: 1), style: negrito)),
          DataCell(Text(formatarDecimal(r.passageirosPorKm, casas: 2), style: negrito)),
          const DataCell(Text('-')),
        ],
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        columnSpacing: 20,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Data')),
          DataColumn(label: Text('Dia')),
          DataColumn(label: Text('Catraca'), numeric: true),
          DataColumn(label: Text('Antecipados'), numeric: true),
          DataColumn(label: Text('Não pagantes'), numeric: true),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('% não pag.'), numeric: true),
          DataColumn(label: Text('Pass./viagem'), numeric: true),
          DataColumn(label: Text('Pass./km'), numeric: true),
          DataColumn(label: Text('Desvio'), numeric: true),
        ],
        rows: linhas,
      ),
    );
  }

  // ------------------------------------------------------------
  // Gráficos e painéis
  // ------------------------------------------------------------
  List<Widget> _cartoesPaineis(DadosPeriodo dados) {
    final grafico = dados.diasGrafico;
    final r = dados.resumo;
    final intervalo = grafico.isEmpty
        ? ''
        : '${formatarData(grafico.first.data)} a ${formatarData(grafico.last.data)}';

    return [
      CartaoPainel(
        titulo: 'Passageiros por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoPassageirosEmpilhado(dias: grafico),
            ),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulEscuro, 'Catraca'),
                ItemLegenda(Cores.azulMedio, 'Antecipados'),
                ItemLegenda(Cores.azulClaro, 'Não pagantes'),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: '% de passageiros não pagantes por dia',
        subtitulo: intervalo,
        child: SizedBox(
          height: 244,
          child: GraficoPercentualNaoPagantes(dias: grafico),
        ),
      ),
      CartaoPainel(
        titulo: 'Composição dos passageiros',
        subtitulo: 'No período selecionado',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: GraficoComposicaoPassageiros(
                catraca: r.passageirosCatraca,
                antecipados: r.passageirosAntecipados,
                naoPagantes: r.passageirosNaoPagantes,
              ),
            ),
            const SizedBox(height: 8),
            LegendaGrafico(
              itens: [
                ItemLegenda(
                  Cores.azulEscuro,
                  'Catraca: ${formatarInteiro(r.passageirosCatraca)}',
                ),
                ItemLegenda(
                  Cores.azulMedio,
                  'Antecipados: ${formatarInteiro(r.passageirosAntecipados)}',
                ),
                ItemLegenda(
                  Cores.azulClaro,
                  'Não pagantes: ${formatarInteiro(r.passageirosNaoPagantes)}',
                ),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Média por tipo de dia',
        subtitulo: 'Feriados contam como o dia da semana em que caem',
        child: _tabelaTipoDia(dados.dias),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;

    return Scaffold(
      drawer: MenuDashboard(
        nomeUsuario: widget.nomeUsuario,
        itemAtual: 'Passageiros',
      ),
      appBar: const AppBarSemob(titulo: 'Passageiros'),
      body: dados == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AvisoDadosExemplo(),
                      const SizedBox(height: 8),
                      // Este aviso vem do próprio relatório da Smart Data
                      const AvisoInformativo(
                        texto: 'Os passageiros são provisórios: o sistema de '
                            'bilhetagem atualiza os números todos os dias, '
                            'então os dias mais recentes podem mudar.',
                      ),
                      const SizedBox(height: 16),
                      FiltroPeriodo(
                        tipo: _tipo,
                        dataRef: _dataRef,
                        janela: dados.janela,
                        janelaAnterior: dados.janelaAnterior,
                        carregando: _carregando,
                        aoMudarTipo: (novoTipo) {
                          setState(() {
                            _tipo = novoTipo;
            FiltroGlobal.tipo = novoTipo;
                          });
                          _carregar();
                        },
                        aoEscolherData: _escolherData,
                      ),
                      const SizedBox(height: 16),
                      GradeCartoes(
                        colunasMaximas: 3,
                        filhos: _cartoesIndicadores(dados),
                      ),
                      const SizedBox(height: 16),
                      GradeCartoes(
                        colunasMaximas: 2,
                        filhos: _cartoesPaineis(dados),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CartaoPainel(
                          titulo: 'Detalhe diário',
                          subtitulo: 'Desvio = quanto o total do dia fugiu da média '
                              'do mesmo tipo de dia no período. Acima de '
                              '${formatarDecimal(limiteDesvioPassageiros, casas: 0)}% '
                              'aparece em vermelho.',
                          child: _tabelaDiaria(dados.dias, dados.resumo),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

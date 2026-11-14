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
import '../widgets/graficos_km.dart';
import '../widgets/menu_dashboard.dart';
import '../widgets/ranking_barras.dart';

// Tela 3: Quilometragem
class TelaQuilometragem extends StatefulWidget {
  final String nomeUsuario;

  const TelaQuilometragem({super.key, required this.nomeUsuario});

  @override
  State<TelaQuilometragem> createState() => _TelaQuilometragemState();
}

class _TelaQuilometragemState extends State<TelaQuilometragem> {
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

    final mediaDia = r.quantidadeDias == 0 ? 0.0 : r.kmTotal / r.quantidadeDias;
    final pctProdutivo = r.kmTotal == 0 ? 0.0 : r.kmProdutivo / r.kmTotal * 100;

    return [
      CartaoIndicador(
        titulo: 'Quilometragem total',
        icone: Icons.route,
        valor: '${formatarDecimal(r.kmTotal, casas: 1)} km',
        detalhe: 'Média de ${formatarDecimal(mediaDia, casas: 0)} km por dia',
        variacao: variacaoPercentual(r.kmTotal, ant?.kmTotal, rotulo),
      ),
      CartaoIndicador(
        titulo: 'Km produtivo',
        icone: Icons.check_circle_outline,
        valor: '${formatarDecimal(r.kmProdutivo, casas: 1)} km',
        detalhe: '${formatarDecimal(pctProdutivo, casas: 1)}% do total  |  '
            'rodado em viagens',
        variacao: variacaoPercentual(r.kmProdutivo, ant?.kmProdutivo, rotulo),
      ),
      CartaoIndicador(
        titulo: 'Km improdutivo',
        icone: Icons.local_gas_station,
        valor: '${formatarDecimal(r.kmImprodutivo, casas: 1)} km',
        detalhe: 'Rodado fora de viagens (atividade "Improdutivas")',
        // Aqui MENOS é melhor, por isso boaQuandoSobe é false
        variacao: variacaoPercentual(
          r.kmImprodutivo,
          ant?.kmImprodutivo,
          rotulo,
          boaQuandoSobe: false,
        ),
      ),
      CartaoIndicador(
        titulo: '% de km improdutivo',
        icone: Icons.percent,
        valor: '${formatarDecimal(r.percentualKmImprodutivo, casas: 2)}%',
        corValor: r.percentualKmImprodutivo > limiteKmImprodutivo
            ? Cores.erro
            : Cores.azulEscuro,
        detalhe: 'Limite: ${formatarDecimal(limiteKmImprodutivo, casas: 0)}% '
            'por dia',
        variacao: variacaoPontos(
          r.percentualKmImprodutivo,
          ant?.percentualKmImprodutivo,
          rotulo,
          boaQuandoSobe: false,
        ),
      ),
      CartaoIndicador(
        titulo: 'Km produtivo por viagem',
        icone: Icons.straighten,
        valor: '${formatarDecimal(r.kmProdutivoPorViagem, casas: 2)} km',
        detalhe: 'Km produtivo ÷ viagens realizadas',
        variacao: variacaoPercentual(
          r.kmProdutivoPorViagem,
          ant?.kmProdutivoPorViagem,
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Km por veículo por dia',
        icone: Icons.directions_bus_filled,
        valor: '${formatarDecimal(r.kmPorVeiculoDia, casas: 1)} km',
        detalhe: 'Km total ÷ veículos em operação em cada dia',
        variacao: variacaoPercentual(
          r.kmPorVeiculoDia,
          ant?.kmPorVeiculoDia,
          rotulo,
        ),
      ),
    ];
  }

  // ------------------------------------------------------------
  // Km produtivo por linha (ranking)
  // ------------------------------------------------------------
  Widget _rankingLinhas(DadosPeriodo dados) {
    // Soma o km de cada linha em todos os dias do período
    final porLinha = <String, double>{};
    for (final k in dados.kmLinhas) {
      porLinha[k.linha] = (porLinha[k.linha] ?? 0) + k.kmProdutivo;
    }

    var total = 0.0;
    for (final km in porLinha.values) {
      total += km;
    }

    // Ordena da linha com mais km para a com menos km
    final ordenadas = porLinha.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final itens = [
      for (final e in ordenadas)
        ItemRanking(
          'Linha ${e.key}',
          e.value,
          '${formatarDecimal(e.value, casas: 1)} km '
          '(${formatarDecimal(total == 0 ? 0 : e.value / total * 100, casas: 1)}%)',
        ),
    ];

    return RankingBarras(itens: itens, cor: Cores.azulMedio);
  }

  // ------------------------------------------------------------
  // Tabelas
  // ------------------------------------------------------------
  // Média por tipo de dia (dia útil, sábado e domingo têm programações
  // diferentes, por isso não dá para misturar na mesma média)
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

      var kmTotal = 0.0;
      var kmImprodutivo = 0.0;
      var viagens = 0;
      var veiculos = 0;
      for (final d in lista) {
        kmTotal += d.kmTotal;
        kmImprodutivo += d.kmImprodutivo;
        viagens += d.viagensRealizadas;
        veiculos += d.veiculos;
      }
      final n = lista.length;
      final pctImprodutivo = kmTotal == 0 ? 0.0 : kmImprodutivo / kmTotal * 100;

      linhas.add(
        DataRow(
          cells: [
            DataCell(Text(nome, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('$n')),
            DataCell(Text(formatarDecimal(kmTotal / n, casas: 1))),
            DataCell(Text(formatarDecimal(viagens / n, casas: 0))),
            DataCell(Text(formatarDecimal(veiculos / n, casas: 1))),
            DataCell(Text('${formatarDecimal(pctImprodutivo, casas: 2)}%')),
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
          DataColumn(label: Text('Km médio/dia'), numeric: true),
          DataColumn(label: Text('Viagens/dia'), numeric: true),
          DataColumn(label: Text('Veículos/dia'), numeric: true),
          DataColumn(label: Text('% improd.'), numeric: true),
        ],
        rows: linhas,
      ),
    );
  }

  // Célula de % improdutivo: fica vermelha se passar do limite
  DataCell _celulaPercentual(double pct, {bool negrito = false}) {
    final acima = pct > limiteKmImprodutivo;
    return DataCell(
      Text(
        '${formatarDecimal(pct, casas: 2)}%',
        style: TextStyle(
          color: acima ? Cores.erro : null,
          fontWeight: (negrito || acima) ? FontWeight.bold : null,
        ),
      ),
    );
  }

  Widget _tabelaDiaria(List<DiaOperacao> dias, ResumoPeriodo r) {
    final linhas = <DataRow>[
      for (final d in dias)
        DataRow(
          cells: [
            DataCell(Text(formatarData(d.data))),
            DataCell(Text(nomeDiaSemana(d.data))),
            DataCell(Text('${d.veiculos}')),
            DataCell(Text(formatarDecimal(d.kmProdutivo, casas: 1))),
            DataCell(Text(formatarDecimal(d.kmImprodutivo, casas: 1))),
            DataCell(Text(formatarDecimal(d.kmTotal, casas: 1))),
            _celulaPercentual(d.percentualKmImprodutivo),
            DataCell(
              Text(
                formatarDecimal(
                  d.veiculos == 0 ? 0 : d.kmTotal / d.veiculos,
                  casas: 1,
                ),
              ),
            ),
          ],
        ),
    ];

    // Última linha: total do período (veículos = média por dia)
    const negrito = TextStyle(fontWeight: FontWeight.bold);
    linhas.add(
      DataRow(
        color: WidgetStatePropertyAll<Color?>(Cores.fundo),
        cells: [
          const DataCell(Text('Período', style: negrito)),
          const DataCell(Text('')),
          DataCell(
            Text(
              'média ${formatarDecimal(r.veiculosMedia, casas: 0)}',
              style: negrito,
            ),
          ),
          DataCell(Text(formatarDecimal(r.kmProdutivo, casas: 1), style: negrito)),
          DataCell(Text(formatarDecimal(r.kmImprodutivo, casas: 1), style: negrito)),
          DataCell(Text(formatarDecimal(r.kmTotal, casas: 1), style: negrito)),
          _celulaPercentual(r.percentualKmImprodutivo, negrito: true),
          DataCell(Text(formatarDecimal(r.kmPorVeiculoDia, casas: 1), style: negrito)),
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
          DataColumn(label: Text('Veículos'), numeric: true),
          DataColumn(label: Text('Km produtivo'), numeric: true),
          DataColumn(label: Text('Km improdutivo'), numeric: true),
          DataColumn(label: Text('Km total'), numeric: true),
          DataColumn(label: Text('% improdutivo'), numeric: true),
          DataColumn(label: Text('Km/veículo'), numeric: true),
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
    final intervalo = grafico.isEmpty
        ? ''
        : '${formatarData(grafico.first.data)} a ${formatarData(grafico.last.data)}';

    return [
      CartaoPainel(
        titulo: 'Km por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 220, child: GraficoKmDiario(dias: grafico)),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulMedio, 'Produtivo'),
                ItemLegenda(Cores.atencao, 'Improdutivo'),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: '% de km improdutivo por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoKmImprodutivoPercentual(
                dias: grafico,
                limite: limiteKmImprodutivo,
              ),
            ),
            const SizedBox(height: 8),
            LegendaGrafico(
              itens: [
                const ItemLegenda(Cores.atencao, '% improdutivo do dia'),
                ItemLegenda(
                  Cores.erro,
                  'Limite de ${formatarDecimal(limiteKmImprodutivo, casas: 0)}%',
                ),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Km produtivo por linha',
        subtitulo: 'No período selecionado. O km improdutivo não é '
            'separado por linha nos relatórios.',
        child: _rankingLinhas(dados),
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
        itemAtual: 'Quilometragem',
      ),
      appBar: const AppBarSemob(titulo: 'Quilometragem'),
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
                          subtitulo:
                              '% de km improdutivo acima de ${formatarDecimal(limiteKmImprodutivo, casas: 0)}% '
                              'aparece em vermelho',
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

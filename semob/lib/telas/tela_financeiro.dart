import 'package:flutter/material.dart';

import '../cores.dart';
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
import '../widgets/graficos_financeiro.dart';
import '../widgets/menu_dashboard.dart';

// Tela 5: Financeiro
class TelaFinanceiro extends StatefulWidget {
  final String nomeUsuario;

  const TelaFinanceiro({super.key, required this.nomeUsuario});

  @override
  State<TelaFinanceiro> createState() => _TelaFinanceiroState();
}

class _TelaFinanceiroState extends State<TelaFinanceiro> {
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

    final diasComVenda = dados.dias.where((d) => d.vendas > 0).length;
    final mediaUso = r.quantidadeDias == 0 ? 0.0 : r.utilizacao / r.quantidadeDias;
    final dia = r.diaMaiorVenda;

    return [
      CartaoIndicador(
        titulo: 'Vendas de créditos',
        icone: Icons.point_of_sale,
        valor: formatarMoeda(r.vendas),
        detalhe: 'Vendas em $diasComVenda de ${r.quantidadeDias} dia(s)',
        variacao: variacaoPercentual(
          r.vendas,
          ant?.vendas,
          rotulo,
          boaQuandoSobe: true,
        ),
      ),
      CartaoIndicador(
        titulo: 'Utilização de créditos',
        icone: Icons.touch_app,
        valor: formatarMoeda(r.utilizacao),
        detalhe: 'Média de ${formatarMoeda(mediaUso)} por dia',
        variacao: variacaoPercentual(
          r.utilizacao,
          ant?.utilizacao,
          rotulo,
          boaQuandoSobe: true,
        ),
      ),
      CartaoIndicador(
        titulo: 'Crédito circulante',
        icone: Icons.account_balance_wallet,
        valor: formatarMoeda(r.creditoCirculante),
        detalhe: 'Vendas − utilização',
        dica: 'Vendas de créditos menos a utilização no período. '
            'Não representa receita nem prejuízo: parte das vendas não '
            'consome crédito no mesmo dia.',
        variacao: variacaoPercentual(
          r.creditoCirculante,
          ant?.creditoCirculante,
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Créditos transferidos para cartões',
        icone: Icons.swap_horiz,
        valor: formatarMoeda(r.creditosTransferidos),
        detalhe: 'Diferença para as vendas: '
            '${formatarMoeda(r.vendas - r.creditosTransferidos)}',
        dica: 'Vem da tabela "Saldo de créditos do sistema" do relatório de '
            'saldos da Smart Data.',
        variacao: variacaoPercentual(
          r.creditosTransferidos,
          ant?.creditosTransferidos,
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Saldo do sistema',
        icone: Icons.savings,
        valor: formatarMoeda(r.saldoFinal),
        detalhe: 'Início do período: ${formatarMoeda(r.saldoInicial)}',
        dica: 'Saldo final de créditos do sistema no último dia do período. '
            'Diminui a cada transferência para cartões.',
        variacao: variacaoPercentual(r.saldoFinal, ant?.saldoFinal, rotulo),
      ),
      CartaoIndicador(
        titulo: 'Maior venda em um dia',
        icone: Icons.trending_up,
        valor: formatarMoeda(r.maiorVenda),
        detalhe: dia == null
            ? 'Sem vendas no período'
            : 'em ${formatarDataCurta(dia)} (${nomeDiaSemana(dia)})',
        variacao: variacaoPercentual(r.maiorVenda, ant?.maiorVenda, rotulo),
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

      var vendas = 0.0;
      var uso = 0.0;
      var transferido = 0.0;
      for (final d in lista) {
        vendas += d.vendas;
        uso += d.utilizacao;
        transferido += d.creditosTransferidos;
      }
      final n = lista.length;

      linhas.add(
        DataRow(
          cells: [
            DataCell(Text(nome, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('$n')),
            DataCell(Text(formatarMoeda(vendas / n))),
            DataCell(Text(formatarMoeda(uso / n))),
            DataCell(Text(formatarMoeda(transferido / n))),
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
          DataColumn(label: Text('Vendas/dia'), numeric: true),
          DataColumn(label: Text('Utilização/dia'), numeric: true),
          DataColumn(label: Text('Transferido/dia'), numeric: true),
        ],
        rows: linhas,
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
            DataCell(Text(formatarMoeda(d.vendas))),
            DataCell(Text(formatarMoeda(d.utilizacao))),
            DataCell(Text(formatarMoeda(d.creditoCirculante))),
            DataCell(Text(formatarMoeda(d.creditosTransferidos))),
            DataCell(Text(formatarMoeda(d.saldoSistema))),
          ],
        ),
    ];

    // Última linha: total do período (o saldo é o do último dia)
    const negrito = TextStyle(fontWeight: FontWeight.bold);
    linhas.add(
      DataRow(
        color: WidgetStatePropertyAll<Color?>(Cores.fundo),
        cells: [
          const DataCell(Text('Período', style: negrito)),
          const DataCell(Text('')),
          DataCell(Text(formatarMoeda(r.vendas), style: negrito)),
          DataCell(Text(formatarMoeda(r.utilizacao), style: negrito)),
          DataCell(Text(formatarMoeda(r.creditoCirculante), style: negrito)),
          DataCell(Text(formatarMoeda(r.creditosTransferidos), style: negrito)),
          DataCell(Text(formatarMoeda(r.saldoFinal), style: negrito)),
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
          DataColumn(label: Text('Vendas'), numeric: true),
          DataColumn(label: Text('Utilização'), numeric: true),
          DataColumn(label: Text('Crédito circulante'), numeric: true),
          DataColumn(label: Text('Transferido p/ cartões'), numeric: true),
          DataColumn(label: Text('Saldo final'), numeric: true),
        ],
        rows: linhas,
      ),
    );
  }

  // Uma linha de explicação com ícone
  Widget _nota(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Cores.azulMedio),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Gráficos e painéis
  // ------------------------------------------------------------
  List<Widget> _cartoesGraficos(DadosPeriodo dados) {
    final grafico = dados.diasGrafico;
    final intervalo = grafico.isEmpty
        ? ''
        : '${formatarData(grafico.first.data)} a ${formatarData(grafico.last.data)}';

    return [
      CartaoPainel(
        titulo: 'Vendas × utilização de créditos por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 220, child: GraficoFinanceiro(dias: grafico)),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulMedio, 'Vendas'),
                ItemLegenda(Cores.azulClaro, 'Utilização'),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Acumulado no período',
        subtitulo: '$intervalo  |  somado dia a dia',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 220, child: GraficoFinanceiroAcumulado(dias: grafico)),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulMedio, 'Vendas acumuladas'),
                ItemLegenda(Cores.azulClaro, 'Utilização acumulada'),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Saldo do sistema por dia',
        subtitulo: '$intervalo  |  o eixo não começa no zero',
        child: SizedBox(height: 244, child: GraficoSaldoSistema(dias: grafico)),
      ),
      CartaoPainel(
        titulo: 'Créditos transferidos para cartões por dia',
        subtitulo: intervalo,
        child: SizedBox(
          height: 244,
          child: GraficoCreditosTransferidos(dias: grafico),
        ),
      ),
    ];
  }

  List<Widget> _cartoesExplicacao(DadosPeriodo dados) {
    return [
      CartaoPainel(
        titulo: 'Média por tipo de dia',
        subtitulo: 'Feriados contam como o dia da semana em que caem',
        child: _tabelaTipoDia(dados.dias),
      ),
      CartaoPainel(
        titulo: 'Como interpretar',
        subtitulo: 'Observações dos relatórios da Smart Data',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nota(
              'A venda do dia pode ser maior ou menor que o uso do crédito, '
              'porque nem toda venda consome crédito na hora. Exemplo: empresa '
              'que paga o boleto, mas cujos cartões ainda não foram emitidos.',
            ),
            _nota(
              'Vias de cartões consomem créditos de transferência, e transações '
              'incompletas ou canceladas também usam créditos.',
            ),
            _nota(
              'Crédito circulante = vendas − utilização. Não é receita nem '
              'prejuízo.',
            ),
            _nota(
              'O saldo do sistema diminui a cada transferência para cartões. '
              'Nos dias sem lançamento (como fins de semana) ele se mantém.',
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;

    return Scaffold(
      drawer: MenuDashboard(
        nomeUsuario: widget.nomeUsuario,
        itemAtual: 'Financeiro',
      ),
      appBar: const AppBarSemob(titulo: 'Financeiro'),
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
                      const AvisoInformativo(
                        texto: 'Os valores do dia mais recente podem estar '
                            'incompletos e mudar nos relatórios seguintes. '
                            'Exemplo: a utilização de 14/08 era R\$ 0,00 no '
                            'relatório de 15/08 e passou a R\$ 12.505,00 no '
                            'relatório mensal.',
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
                        filhos: _cartoesGraficos(dados),
                      ),
                      const SizedBox(height: 16),
                      GradeCartoes(
                        colunasMaximas: 2,
                        filhos: _cartoesExplicacao(dados),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CartaoPainel(
                          titulo: 'Detalhe diário',
                          subtitulo: 'Saldo final = saldo do sistema no fim do dia',
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

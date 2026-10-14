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
import '../utils/variacoes.dart';
import '../widgets/appbar_semob.dart';
import '../widgets/cartao_indicador.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grade_cartoes.dart';
import '../widgets/graficos.dart';
import '../widgets/graficos_viagens.dart';
import '../widgets/menu_dashboard.dart';

// Uma linha da tabela "Resumo por faixa do dia"
class _LinhaFaixa {
  final String nome;
  final int programadas;
  final int realizadas;
  final bool destaque; // true na linha de total

  const _LinhaFaixa(
    this.nome,
    this.programadas,
    this.realizadas, {
    this.destaque = false,
  });
}

// Tela 2: Viagens e cumprimento
class TelaViagens extends StatefulWidget {
  final String nomeUsuario;

  const TelaViagens({super.key, required this.nomeUsuario});

  @override
  State<TelaViagens> createState() => _TelaViagensState();
}

class _TelaViagensState extends State<TelaViagens> {
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

    return [
      CartaoIndicador(
        titulo: 'Viagens programadas',
        icone: Icons.event_note,
        valor: formatarInteiro(r.viagensProgramadas),
        detalhe: '${r.quantidadeDias} dia(s) no período',
        variacao: variacaoPercentual(
          r.viagensProgramadas.toDouble(),
          ant?.viagensProgramadas.toDouble(),
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Viagens realizadas',
        icone: Icons.directions_bus,
        valor: formatarInteiro(r.viagensRealizadas),
        detalhe: 'de ${formatarInteiro(r.viagensProgramadas)} programadas',
        variacao: variacaoPercentual(
          r.viagensRealizadas.toDouble(),
          ant?.viagensRealizadas.toDouble(),
          rotulo,
          boaQuandoSobe: true,
        ),
      ),
      CartaoIndicador(
        titulo: 'Cumprimento de viagens (FCV)',
        icone: Icons.fact_check,
        valor: '${formatarDecimal(r.fcv, casas: 2)}%',
        corValor: r.fcv < limiteFcv ? Cores.erro : Cores.azulEscuro,
        detalhe: 'Realizadas ÷ programadas  |  Limite: '
            '${formatarDecimal(limiteFcv, casas: 1)}%',
        variacao: variacaoPontos(
          r.fcv,
          ant?.fcv,
          rotulo,
          boaQuandoSobe: true,
        ),
      ),
      CartaoIndicador(
        titulo: 'Viagens não realizadas',
        icone: Icons.cancel_schedule_send,
        valor: formatarInteiro(r.viagensNaoRealizadas),
        detalhe: '${formatarDecimal(100 - r.fcv, casas: 2)}% das programadas',
        // Aqui MENOS é melhor, por isso boaQuandoSobe é false
        variacao: variacaoPercentual(
          r.viagensNaoRealizadas.toDouble(),
          ant?.viagensNaoRealizadas.toDouble(),
          rotulo,
          boaQuandoSobe: false,
        ),
      ),
      CartaoIndicador(
        titulo: 'Veículos por dia (média)',
        icone: Icons.directions_bus_filled,
        valor: formatarDecimal(r.veiculosMedia, casas: 1),
        detalhe: 'Máximo em um dia: ${r.veiculosMaximo}',
        variacao: variacaoPercentual(
          r.veiculosMedia,
          ant?.veiculosMedia,
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Pico de veículos por faixa horária',
        icone: Icons.schedule,
        valor: '${r.maxVeiculosFaixa}',
        detalhe: 'Maior valor no período',
        dica: 'Maior número de veículos em uma mesma faixa horária do dia '
            '(coluna "nrMaxVeicFx" do Resumo Geral). Confere com o máximo do '
            'relatório de faixas horárias em todos os dias de agosto.',
        variacao: variacaoPercentual(
          r.maxVeiculosFaixa.toDouble(),
          ant?.maxVeiculosFaixa.toDouble(),
          rotulo,
        ),
      ),
    ];
  }

  // ------------------------------------------------------------
  // Gráficos
  // ------------------------------------------------------------
  List<Widget> _cartoesGraficos(DadosPeriodo dados) {
    final grafico = dados.diasGrafico;
    final intervalo = grafico.isEmpty
        ? ''
        : '${formatarData(grafico.first.data)} a ${formatarData(grafico.last.data)}';

    return [
      CartaoPainel(
        titulo: 'Viagens programadas × realizadas por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoProgramadasRealizadas(dias: grafico),
            ),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulClaro, 'Programadas'),
                ItemLegenda(Cores.azulMedio, 'Realizadas'),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Viagens não realizadas por dia',
        subtitulo: intervalo,
        child: SizedBox(height: 244, child: GraficoNaoRealizadas(dias: grafico)),
      ),
      CartaoPainel(
        titulo: 'FCV por faixa do dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoFcvFaixas(dias: grafico, limite: limiteFcv),
            ),
            const SizedBox(height: 8),
            LegendaGrafico(
              itens: [
                const ItemLegenda(Cores.azulEscuro, 'Manhã'),
                const ItemLegenda(Cores.azulMedio, 'Tarde'),
                const ItemLegenda(Cores.azulClaro, 'Noite'),
                ItemLegenda(
                  Cores.erro,
                  'Limite de ${formatarDecimal(limiteFcv, casas: 1)}%',
                ),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Veículos por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 220, child: GraficoVeiculos(dias: grafico)),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulEscuro, 'Veículos no dia'),
                ItemLegenda(Cores.azulClaro, 'Máx. por faixa horária'),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ------------------------------------------------------------
  // Tabelas
  // ------------------------------------------------------------
  // Célula de FCV: fica vermelha se estiver abaixo do limite
  DataCell _celulaFcv(double fcv, {int casas = 2, bool negrito = false}) {
    return DataCell(
      Text(
        '${formatarDecimal(fcv, casas: casas)}%',
        style: TextStyle(
          color: fcv < limiteFcv ? Cores.erro : null,
          fontWeight: (negrito || fcv < limiteFcv) ? FontWeight.bold : null,
        ),
      ),
    );
  }

  DataRow _linhaTabelaFaixa(_LinhaFaixa f) {
    final naoRealizadas = f.programadas - f.realizadas;
    final fcv = calcularFcv(f.programadas, f.realizadas);
    final negrito = f.destaque ? FontWeight.bold : null;

    return DataRow(
      color: f.destaque ? WidgetStatePropertyAll<Color?>(Cores.fundo) : null,
      cells: [
        DataCell(Text(f.nome, style: TextStyle(fontWeight: negrito))),
        DataCell(Text(formatarInteiro(f.programadas))),
        DataCell(Text(formatarInteiro(f.realizadas))),
        DataCell(Text(formatarInteiro(naoRealizadas))),
        _celulaFcv(fcv, negrito: f.destaque),
      ],
    );
  }

  Widget _tabelaFaixas(ResumoPeriodo r) {
    final linhas = [
      _LinhaFaixa('Manhã', r.manhaProgramadas, r.manhaRealizadas),
      _LinhaFaixa('Tarde', r.tardeProgramadas, r.tardeRealizadas),
      _LinhaFaixa('Noite', r.noiteProgramadas, r.noiteRealizadas),
      _LinhaFaixa(
        'Total',
        r.viagensProgramadas,
        r.viagensRealizadas,
        destaque: true,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        columns: const [
          DataColumn(label: Text('Faixa')),
          DataColumn(label: Text('Programadas'), numeric: true),
          DataColumn(label: Text('Realizadas'), numeric: true),
          DataColumn(label: Text('Não realizadas'), numeric: true),
          DataColumn(label: Text('FCV'), numeric: true),
        ],
        rows: [for (final f in linhas) _linhaTabelaFaixa(f)],
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
            DataCell(Text(formatarInteiro(d.viagensProgramadas))),
            DataCell(Text(formatarInteiro(d.viagensRealizadas))),
            DataCell(Text(formatarInteiro(d.viagensNaoRealizadas))),
            _celulaFcv(d.fcv),
            _celulaFcv(d.fcvManha, casas: 1),
            _celulaFcv(d.fcvTarde, casas: 1),
            _celulaFcv(d.fcvNoite, casas: 1),
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
          DataCell(Text(formatarInteiro(r.viagensProgramadas), style: negrito)),
          DataCell(Text(formatarInteiro(r.viagensRealizadas), style: negrito)),
          DataCell(Text(formatarInteiro(r.viagensNaoRealizadas), style: negrito)),
          _celulaFcv(r.fcv, negrito: true),
          _celulaFcv(r.fcvManha, casas: 1, negrito: true),
          _celulaFcv(r.fcvTarde, casas: 1, negrito: true),
          _celulaFcv(r.fcvNoite, casas: 1, negrito: true),
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
          DataColumn(label: Text('Programadas'), numeric: true),
          DataColumn(label: Text('Realizadas'), numeric: true),
          DataColumn(label: Text('Não realizadas'), numeric: true),
          DataColumn(label: Text('FCV'), numeric: true),
          DataColumn(label: Text('FCV manhã'), numeric: true),
          DataColumn(label: Text('FCV tarde'), numeric: true),
          DataColumn(label: Text('FCV noite'), numeric: true),
        ],
        rows: linhas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;

    return Scaffold(
      drawer: MenuDashboard(
        nomeUsuario: widget.nomeUsuario,
        itemAtual: 'Viagens e cumprimento',
      ),
      appBar: const AppBarSemob(titulo: 'Viagens e cumprimento'),
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
                        filhos: _cartoesGraficos(dados),
                      ),
                      const SizedBox(height: 16),
                      CartaoPainel(
                        titulo: 'Resumo por faixa do dia',
                        subtitulo:
                            'Limites prováveis (inferidos dos dados): manhã até 11h59, '
                            'tarde de 12h às 17h59, noite a partir das 18h',
                        child: _tabelaFaixas(dados.resumo),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CartaoPainel(
                          titulo: 'Detalhe diário',
                          subtitulo:
                              'FCV abaixo de ${formatarDecimal(limiteFcv, casas: 1)}% aparece em vermelho',
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

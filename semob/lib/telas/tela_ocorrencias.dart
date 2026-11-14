import 'package:flutter/material.dart';

import '../cores.dart';
import '../limites.dart';
import '../models/dados_periodo.dart';
import '../models/dia_operacao.dart';
import '../models/periodo.dart';
import '../servicos/dados_servico.dart';
import '../servicos/filtro_global.dart';
import '../utils/formatadores.dart';
import '../utils/ocorrencias.dart';
import '../utils/variacoes.dart';
import '../widgets/appbar_semob.dart';
import '../widgets/cartao_indicador.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grade_cartoes.dart';
import '../widgets/graficos.dart';
import '../widgets/graficos_ocorrencias.dart';
import '../widgets/menu_dashboard.dart';
import '../widgets/ranking_barras.dart';

// Tela 8: Ocorrências (viagens não realizadas, não iniciadas e não terminadas)
class TelaOcorrencias extends StatefulWidget {
  final String nomeUsuario;

  const TelaOcorrencias({super.key, required this.nomeUsuario});

  @override
  State<TelaOcorrencias> createState() => _TelaOcorrenciasState();
}

class _TelaOcorrenciasState extends State<TelaOcorrencias> {
  TipoPeriodo _tipo = FiltroGlobal.tipo;
  DateTime _dataRef = FiltroGlobal.dataRef ?? DadosServico.dataMaxima;

  bool _carregando = true;
  DadosPeriodo? _dados;

  // Filtros desta tela (valem para os gráficos e a tabela)
  String _filtroTipo = 'Todas'; // Todas, Não realizadas, Não iniciadas, Não terminadas
  String _filtroLinha = 'Todas'; // Todas ou o número de uma linha

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
  // Filtros
  // ------------------------------------------------------------
  TipoOcorrencia? get _tipoFiltrado {
    switch (_filtroTipo) {
      case 'Não realizadas':
        return TipoOcorrencia.naoRealizada;
      case 'Não iniciadas':
        return TipoOcorrencia.naoIniciada;
      case 'Não terminadas':
        return TipoOcorrencia.naoTerminada;
      default:
        return null; // todas
    }
  }

  List<Ocorrencia> _porTipo(List<Ocorrencia> lista) {
    final tipo = _tipoFiltrado;
    if (tipo == null) return lista;
    return lista.where((o) => o.tipo == tipo).toList();
  }

  List<Ocorrencia> _porTipoELinha(List<Ocorrencia> lista, String linha) {
    final porTipo = _porTipo(lista);
    if (linha == 'Todas') return porTipo;
    return porTipo.where((o) => o.linha == linha).toList();
  }

  // Conta as ocorrências de um tipo (tipo null = todas)
  int _contar(List<Ocorrencia> lista, TipoOcorrencia? tipo) {
    if (tipo == null) return lista.length;
    return lista.where((o) => o.tipo == tipo).length;
  }

  // ------------------------------------------------------------
  // Cálculos
  // ------------------------------------------------------------
  // Viagens não realizadas agrupadas por tabela
  // (um grupo = mesmo dia, linha, tabela e motorista)
  Map<String, int> _tabelasAfetadas(List<Ocorrencia> lista) {
    final grupos = <String, int>{};
    for (final o in lista) {
      if (o.tipo != TipoOcorrencia.naoRealizada) continue;
      final chave = '${o.data.millisecondsSinceEpoch}|${o.linha}|${o.tabela}|${o.motorista}';
      grupos[chave] = (grupos[chave] ?? 0) + 1;
    }
    return grupos;
  }

  // ------------------------------------------------------------
  // Cartões de indicadores
  // ------------------------------------------------------------
  List<Widget> _cartoes(DadosPeriodo dados) {
    final oc = dados.ocorrencias;
    final anteriores = dados.janelaAnterior == null ? null : dados.ocorrenciasAnterior;
    final rotulo = rotuloComparacao(_tipo);
    final total = oc.length;
    final programadas = dados.resumo.viagensProgramadas;

    // Aqui MENOS é melhor, por isso boaQuandoSobe é false
    Variacao? variacao(TipoOcorrencia? tipo) {
      return variacaoPercentual(
        _contar(oc, tipo).toDouble(),
        anteriores == null ? null : _contar(anteriores, tipo).toDouble(),
        rotulo,
        boaQuandoSobe: false,
      );
    }

    final tabelas = _tabelasAfetadas(oc);
    final naoRealizadas = _contar(oc, TipoOcorrencia.naoRealizada);

    // Conferência: ocorrências x (programadas - realizadas) do Resumo Geral
    final diferenca = dados.resumo.viagensNaoRealizadas;
    final confere = diferenca == total;

    return [
      CartaoIndicador(
        titulo: 'Total de ocorrências',
        icone: Icons.report_problem,
        valor: '$total',
        detalhe: '${formatarDecimal(programadas == 0 ? 0 : total / programadas * 100, casas: 2)}% '
            'das viagens programadas',
        variacao: variacao(null),
      ),
      CartaoIndicador(
        titulo: 'Não realizadas',
        icone: Icons.cancel_schedule_send,
        valor: '$naoRealizadas',
        detalhe: 'Sem registro de veículo, saída ou chegada',
        variacao: variacao(TipoOcorrencia.naoRealizada),
      ),
      CartaoIndicador(
        titulo: 'Não iniciadas',
        icone: Icons.play_disabled,
        valor: '${_contar(oc, TipoOcorrencia.naoIniciada)}',
        detalhe: 'Chegada registrada, sem registro de saída',
        variacao: variacao(TipoOcorrencia.naoIniciada),
      ),
      CartaoIndicador(
        titulo: 'Não terminadas',
        icone: Icons.stop_circle,
        valor: '${_contar(oc, TipoOcorrencia.naoTerminada)}',
        detalhe: 'Saída registrada, sem registro de chegada',
        variacao: variacao(TipoOcorrencia.naoTerminada),
      ),
      CartaoIndicador(
        titulo: 'Tabelas com viagens não realizadas',
        icone: Icons.view_timeline,
        valor: '${tabelas.length}',
        detalhe: tabelas.isEmpty
            ? 'Nenhuma viagem não realizada'
            : 'Média de ${formatarDecimal(naoRealizadas / tabelas.length, casas: 1)} viagens por tabela',
        dica: 'Tabela é a escala de um veículo e motorista. Conta cada '
            'combinação de dia, linha, tabela e motorista com viagens não '
            'realizadas.',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Conferência com o Resumo Geral',
        icone: Icons.verified,
        valor: confere ? 'Confere' : 'Diverge',
        corValor: confere ? Cores.sucesso : Cores.erro,
        detalhe: '$total ocorrências × $diferenca (programadas − realizadas)',
        dica: 'As ocorrências deveriam somar exatamente a diferença entre as '
            'viagens programadas e as realizadas do Resumo Geral. Em agosto '
            'isso fecha em todos os dias.',
        semComparacao: true,
      ),
    ];
  }

  // ------------------------------------------------------------
  // O que chama atenção (calculado sobre o período inteiro)
  // ------------------------------------------------------------
  List<String> _destaques(DadosPeriodo dados) {
    final oc = dados.ocorrencias;
    final textos = <String>[];
    if (oc.isEmpty) return ['Nenhuma ocorrência no período.'];

    // Dia com mais ocorrências
    final porDia = <DateTime, int>{};
    for (final o in oc) {
      porDia[o.data] = (porDia[o.data] ?? 0) + 1;
    }
    var maxDia = 0;
    for (final n in porDia.values) {
      if (n > maxDia) maxDia = n;
    }
    final diasTopo = porDia.entries.where((e) => e.value == maxDia).map((e) => e.key).toList()
      ..sort((a, b) => a.compareTo(b));
    textos.add(
      'Dia${diasTopo.length > 1 ? 's' : ''} com mais ocorrências: '
      '${diasTopo.map((d) => '${formatarDataCurta(d)} (${nomeDiaSemana(d)})').join(', ')}, '
      'com $maxDia ${diasTopo.length > 1 ? 'cada' : '(${formatarDecimal(maxDia / oc.length * 100, casas: 0)}% do período)'}.',
    );

    // Faixa horária com mais ocorrências (pelo horário programado)
    final porHora = <int, int>{};
    for (final o in oc) {
      final h = o.inicioProgramado?.hour;
      if (h != null) porHora[h] = (porHora[h] ?? 0) + 1;
    }
    if (porHora.isNotEmpty) {
      var maxHora = 0;
      for (final n in porHora.values) {
        if (n > maxHora) maxHora = n;
      }
      final horasTopo = porHora.entries.where((e) => e.value == maxHora).map((e) => e.key).toList()
        ..sort();
      final plural = horasTopo.length > 1;
      final listaHoras = horasTopo.map((h) => '${h}h').join(' e ');
      textos.add(
        'Faixa${plural ? 's' : ''} horária${plural ? 's' : ''} com mais '
        'ocorrências (horário programado): $listaHoras, com $maxHora'
        '${plural ? ' cada' : ''}.',
      );
    }

    // Viagens não realizadas por tabela
    final tabelas = _tabelasAfetadas(oc);
    if (tabelas.isNotEmpty) {
      final naoRealizadas = _contar(oc, TipoOcorrencia.naoRealizada);
      final tresOuMais = tabelas.values.where((n) => n >= 3).length;
      textos.add(
        'As $naoRealizadas viagens não realizadas estão em ${tabelas.length} '
        'tabelas (média de ${formatarDecimal(naoRealizadas / tabelas.length, casas: 1)} por tabela).'
        '${tresOuMais > 0 ? ' Em $tresOuMais tabela(s) foram perdidas 3 viagens ou mais.' : ''}',
      );
    }

    // Sequências de não iniciada + não terminada no mesmo veículo e motorista
    final tiposPorGrupo = <String, Set<TipoOcorrencia>>{};
    final viagensPorGrupo = <String, int>{};
    for (final o in oc) {
      if (o.tipo == TipoOcorrencia.naoRealizada) continue;
      final chave = '${o.data.millisecondsSinceEpoch}|${o.linha}|${o.prefixo}|${o.motorista}';
      tiposPorGrupo.putIfAbsent(chave, () => <TipoOcorrencia>{}).add(o.tipo);
      viagensPorGrupo[chave] = (viagensPorGrupo[chave] ?? 0) + 1;
    }
    var sequencias = 0;
    var viagensSequencias = 0;
    tiposPorGrupo.forEach((chave, tipos) {
      if (tipos.length == 2) {
        sequencias++;
        viagensSequencias += viagensPorGrupo[chave]!;
      }
    });
    if (sequencias > 0) {
      textos.add(
        '$sequencias sequência(s) de não iniciada + não terminada no mesmo '
        'veículo, linha e motorista, no mesmo dia ($viagensSequencias viagens). '
        'Pode indicar falha de registro do equipamento: vale confirmar com a '
        'Smart Data.',
      );
    }

    return textos;
  }

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
  // Filtros na tela
  // ------------------------------------------------------------
  Widget _controles(List<String> linhas, String linhaValida) {
    const rotuloEstilo = TextStyle(fontSize: 12, color: Colors.black54);

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tipo de ocorrência', style: rotuloEstilo),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: Cores.azulMedio,
                        selectedForegroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment<String>(value: 'Todas', label: Text('Todas')),
                        ButtonSegment<String>(value: 'Não realizadas', label: Text('Não realizadas')),
                        ButtonSegment<String>(value: 'Não iniciadas', label: Text('Não iniciadas')),
                        ButtonSegment<String>(value: 'Não terminadas', label: Text('Não terminadas')),
                      ],
                      selected: {_filtroTipo},
                      onSelectionChanged: (selecionado) {
                        setState(() {
                          _filtroTipo = selecionado.first;
                        });
                      },
                    ),
 ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Linha', style: rotuloEstilo),
                    DropdownButton<String>(
                      value: linhaValida,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'Todas',
                          child: Text('Todas as linhas'),
                        ),
                        for (final l in linhas)
                          DropdownMenuItem<String>(value: l, child: Text('Linha $l')),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;
                        setState(() {
                          _filtroLinha = valor;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Os filtros valem para os gráficos por dia e por faixa horária, '
              'para o ranking de linhas (só o tipo) e para a tabela. Os '
              'cartões e os destaques mostram sempre o período inteiro.',
              style: rotuloEstilo,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Gráficos e painéis
  // ------------------------------------------------------------
  List<Widget> _paineis(DadosPeriodo dados, String linhaValida) {
    final filtradas = _porTipoELinha(dados.ocorrencias, linhaValida);
    final dias = dados.dias;
    final intervalo = dias.isEmpty
        ? ''
        : (dias.length == 1
            ? formatarData(dias.first.data)
            : '${formatarData(dias.first.data)} a ${formatarData(dias.last.data)}');

    const legenda = LegendaGrafico(
      itens: [
        ItemLegenda(Cores.atencao, 'Não realizadas'),
        ItemLegenda(Cores.azulClaro, 'Não iniciadas'),
        ItemLegenda(Cores.azulEscuro, 'Não terminadas'),
      ],
    );

    // Ranking de linhas: respeita só o filtro de tipo
    final porLinha = <String, int>{};
    for (final o in _porTipo(dados.ocorrencias)) {
      porLinha[o.linha] = (porLinha[o.linha] ?? 0) + 1;
    }
    final ordenadas = porLinha.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      CartaoPainel(
        titulo: 'Ocorrências por dia',
        subtitulo: intervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoOcorrenciasPorDia(dias: dias, ocorrencias: filtradas),
            ),
            const SizedBox(height: 8),
            legenda,
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Ocorrências por faixa horária',
        subtitulo: 'Pelo horário programado de início da viagem',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoOcorrenciasPorHora(ocorrencias: filtradas),
            ),
            const SizedBox(height: 8),
            legenda,
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Ocorrências por linha',
        subtitulo: 'No período selecionado',
        child: RankingBarras(
          cor: Cores.atencao,
          itens: [
            for (final e in ordenadas)
              ItemRanking('Linha ${e.key}', e.value.toDouble(), '${e.value}'),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'O que chama atenção',
        subtitulo: 'Calculado sobre o período inteiro',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final t in _destaques(dados)) _nota(t)],
        ),
      ),
    ];
  }

  // ------------------------------------------------------------
  // Tabela de detalhe
  // ------------------------------------------------------------
  Widget _tabela(List<Ocorrencia> lista) {
    if (lista.isEmpty) {
      return const Text('Nenhuma ocorrência com os filtros escolhidos.');
    }

    final ordenadas = List<Ocorrencia>.from(lista)
      ..sort((a, b) {
        final c = a.data.compareTo(b.data);
        if (c != 0) return c;
        return (a.inicioProgramado ?? a.data).compareTo(b.inicioProgramado ?? b.data);
      });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        columnSpacing: 16,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        columns: [
          const DataColumn(label: Text('Data')),
          const DataColumn(label: Text('Dia')),
          const DataColumn(label: Text('Linha'), numeric: true),
          const DataColumn(label: Text('Atendimento')),
          const DataColumn(label: Text('Tipo')),
          const DataColumn(label: Text('Início prog.')),
          const DataColumn(label: Text('Início real')),
          const DataColumn(label: Text('Fim prog.')),
          const DataColumn(label: Text('Fim real')),
          const DataColumn(label: Text('Veículo')),
          if (exibirMotorista) const DataColumn(label: Text('Motorista')),
          const DataColumn(label: Text('Tabela')),
        ],
        rows: [
          for (final o in ordenadas)
            DataRow(
              cells: [
                DataCell(Text(formatarData(o.data))),
                DataCell(Text(nomeDiaSemana(o.data))),
                DataCell(Text(o.linha)),
                DataCell(Text(o.atendimento)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: corTipoOcorrencia(o.tipo)),
                      const SizedBox(width: 6),
                      Text(nomeTipoOcorrencia(o.tipo)),
                    ],
                  ),
                ),
                DataCell(Text(formatarHora(o.inicioProgramado))),
                DataCell(Text(formatarHora(o.inicioRealizado, segundos: true))),
                DataCell(Text(formatarHora(o.fimProgramado))),
                DataCell(Text(formatarHora(o.fimRealizado, segundos: true))),
                DataCell(Text(o.prefixo.isEmpty ? '-' : o.prefixo)),
                if (exibirMotorista) DataCell(Text(o.motorista)),
                DataCell(Text(o.tabela)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;

    // Linhas que têm ocorrências no período (para o filtro de linha)
    final linhas = dados == null
        ? <String>[]
        : (dados.ocorrencias.map((o) => o.linha).toSet().toList()..sort());
    // O valor do menu precisa existir na lista, senão o Flutter dá erro
    final linhaValida = linhas.contains(_filtroLinha) ? _filtroLinha : 'Todas';

    return Scaffold(
      drawer: MenuDashboard(
        nomeUsuario: widget.nomeUsuario,
        itemAtual: 'Ocorrências',
      ),
      appBar: const AppBarSemob(titulo: 'Ocorrências'),
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
                      AvisoInformativo(
                        texto: 'Não realizada: sem registro de veículo, saída e '
                            'chegada. Não iniciada: chegada registrada, sem '
                            'registro de saída. Não terminada: saída registrada, '
                            'sem registro de chegada. As três contam como não '
                            'realizadas no FCV.'
                            '${exibirMotorista ? '' : ' O número do motorista fica oculto por ser dado pessoal (LGPD).'}',
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
                        filhos: _cartoes(dados),
                      ),
                      const SizedBox(height: 16),
                      _controles(linhas, linhaValida),
                      const SizedBox(height: 16),
                      GradeCartoes(
                        colunasMaximas: 2,
                        filhos: _paineis(dados, linhaValida),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CartaoPainel(
                          titulo: 'Detalhe das ocorrências',
                          subtitulo: 'Horários programados e realizados da viagem. '
                              'Os filtros de tipo e de linha valem aqui.',
                          child: _tabela(_porTipoELinha(dados.ocorrencias, linhaValida)),
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

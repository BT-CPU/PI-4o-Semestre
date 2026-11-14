import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dados_periodo.dart';
import '../models/faixa_sistema.dart';
import '../models/periodo.dart';
import '../servicos/dados_servico.dart';
import '../servicos/filtro_global.dart';
import '../utils/formatadores.dart';
import '../utils/horas.dart';
import '../utils/tipo_dia.dart';
import '../widgets/appbar_semob.dart';
import '../widgets/cartao_indicador.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grade_cartoes.dart';
import '../widgets/graficos.dart';
import '../widgets/graficos_faixas.dart';
import '../widgets/mapa_calor.dart';
import '../widgets/menu_dashboard.dart';
import '../widgets/ranking_barras.dart';

// Soma de viagens e veículos em uma hora (somando vários dias)
class _TotaisHora {
  int viagens = 0;
  int veiculos = 0;
}

// Tela 7: Faixas horárias (o sistema todo)
class TelaFaixas extends StatefulWidget {
  final String nomeUsuario;

  const TelaFaixas({super.key, required this.nomeUsuario});

  @override
  State<TelaFaixas> createState() => _TelaFaixasState();
}

class _TelaFaixasState extends State<TelaFaixas> {
  TipoPeriodo _tipo = FiltroGlobal.tipo;
  DateTime _dataRef = FiltroGlobal.dataRef ?? DadosServico.dataMaxima;

  bool _carregando = true;
  DadosPeriodo? _dados;

  // Filtros desta tela
  String _tipoDiaFiltro = 'Todos'; // Todos, Dia útil, Sábado ou Domingo
  String _metrica = 'Viagens'; // Viagens ou Veículos

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
  // Cálculos
  // ------------------------------------------------------------
  bool get _porViagens => _metrica == 'Viagens';

  String get _unidade => _porViagens ? 'viagens' : 'veículos';

  // Datas do período que são do tipo escolhido ("Todos" = todas)
  Set<DateTime> _datasDoTipo(DadosPeriodo dados, String tipo) {
    final datas = <DateTime>{};
    for (final d in dados.dias) {
      if (tipo == 'Todos' || tipoDia(d.data) == tipo) {
        datas.add(d.data);
      }
    }
    return datas;
  }

  // Soma de viagens e veículos de cada hora, só nas datas informadas
  Map<int, _TotaisHora> _totaisPorHora(DadosPeriodo dados, Set<DateTime> datas) {
    final totais = <int, _TotaisHora>{};
    for (final f in dados.faixasSistema) {
      if (!datas.contains(f.data)) continue;
      final t = totais.putIfAbsent(f.hora, () => _TotaisHora());
      t.viagens += f.viagens;
      t.veiculos += f.veiculos;
    }
    return totais;
  }

  // Todas as horas que aparecem no período, na ordem 4h ... 23h, 0h
  List<int> _horasDoPeriodo(DadosPeriodo dados) {
    final horas = <int>{};
    for (final f in dados.faixasSistema) {
      horas.add(f.hora);
    }
    final lista = horas.toList()..sort((a, b) => ordemHora(a).compareTo(ordemHora(b)));
    return lista;
  }

  // ------------------------------------------------------------
  // Cartões de indicadores
  // ------------------------------------------------------------
  List<Widget> _cartoes(
    DadosPeriodo dados,
    Set<DateTime> datas,
    Map<int, _TotaisHora> totais,
  ) {
    if (totais.isEmpty) return [];
    final n = datas.length;

    var horaPicoViagens = totais.keys.first;
    var horaPicoVeiculos = totais.keys.first;
    var totalViagens = 0;
    for (final e in totais.entries) {
      totalViagens += e.value.viagens;
      if (e.value.viagens > totais[horaPicoViagens]!.viagens) {
        horaPicoViagens = e.key;
      }
      if (e.value.veiculos > totais[horaPicoVeiculos]!.veiculos) {
        horaPicoVeiculos = e.key;
      }
    }

    // Maior número de veículos em uma faixa, em qualquer dia do período
    FaixaSistemaDia? maior;
    for (final f in dados.faixasSistema) {
      if (!datas.contains(f.data)) continue;
      if (maior == null || f.veiculos > maior.veiculos) maior = f;
    }

    // As 3 horas com mais viagens e quanto elas concentram
    final porViagens = totais.entries.toList()
      ..sort((a, b) => b.value.viagens.compareTo(a.value.viagens));
    final top3 = porViagens.take(3).toList();
    var somaTop3 = 0;
    for (final e in top3) {
      somaTop3 += e.value.viagens;
    }
    final horasTop3 = top3.map((e) => e.key).toList()
      ..sort((a, b) => ordemHora(a).compareTo(ordemHora(b)));

    // Horas em que o sistema opera (tem viagens)
    final comViagens = totais.entries
        .where((e) => e.value.viagens > 0)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => ordemHora(a).compareTo(ordemHora(b)));

    return [
      CartaoIndicador(
        titulo: 'Hora de pico de viagens',
        icone: Icons.access_time,
        valor: rotuloHora(horaPicoViagens),
        detalhe: '${formatarDecimal(totais[horaPicoViagens]!.viagens / n, casas: 1)} '
            'viagens por dia nessa faixa',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Hora de pico de veículos',
        icone: Icons.directions_bus_filled,
        valor: rotuloHora(horaPicoVeiculos),
        detalhe: '${formatarDecimal(totais[horaPicoVeiculos]!.veiculos / n, casas: 1)} '
            'veículos em média nessa faixa',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Máximo de veículos em uma faixa',
        icone: Icons.trending_up,
        valor: '${maior!.veiculos}',
        detalhe: 'às ${rotuloHora(maior.hora)} de ${formatarDataCurta(maior.data)} '
            '(${nomeDiaSemana(maior.data)})',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Viagens por dia (média)',
        icone: Icons.event_note,
        valor: formatarDecimal(totalViagens / n, casas: 1),
        detalhe: 'Em $n dia(s) considerado(s)',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Faixas horárias em operação',
        icone: Icons.schedule,
        valor: '${comViagens.length}',
        detalhe: comViagens.isEmpty
            ? 'Sem viagens no período'
            : 'De ${rotuloHora(comViagens.first)} até ${rotuloHora(comViagens.last)}',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Concentração nas 3 horas de pico',
        icone: Icons.pie_chart,
        valor: '${formatarDecimal(totalViagens == 0 ? 0 : somaTop3 / totalViagens * 100, casas: 1)}%',
        detalhe: 'Horas: ${horasTop3.map(rotuloHora).join(', ')}',
        semComparacao: true,
      ),
    ];
  }

  // ------------------------------------------------------------
  // Mapa de calor
  // ------------------------------------------------------------
  Widget _mapaCalor(DadosPeriodo dados, Set<DateTime> datas, List<int> horas) {
    // Procura rápida: dia -> hora -> registro
    final porDiaHora = <DateTime, Map<int, FaixaSistemaDia>>{};
    for (final f in dados.faixasSistema) {
      if (!datas.contains(f.data)) continue;
      final mapaDia = porDiaHora.putIfAbsent(f.data, () => <int, FaixaSistemaDia>{});
      mapaDia[f.hora] = f;
    }

    final dias = datas.toList()..sort((a, b) => a.compareTo(b));

    return MapaCalor(
      dias: dias,
      horas: horas,
      cor: _porViagens ? Cores.azulEscuro : Cores.azulMedio,
      valor: (dia, hora) {
        final f = porDiaHora[dia]?[hora];
        if (f == null) return 0.0;
        return (_porViagens ? f.viagens : f.veiculos).toDouble();
      },
      textoDica: (dia, hora) {
        final f = porDiaHora[dia]?[hora];
        return '${formatarData(dia)} (${nomeDiaSemana(dia)}) às ${rotuloHora(hora)}\n'
            'Viagens: ${f?.viagens ?? 0}  |  Veículos: ${f?.veiculos ?? 0}';
      },
    );
  }

  // ------------------------------------------------------------
  // Perfil horário e ranking de horas
  // ------------------------------------------------------------
  Widget _graficoPerfil(DadosPeriodo dados, List<int> horas) {
    const cores = {
      'Dia útil': Cores.azulEscuro,
      'Sábado': Cores.azulMedio,
      'Domingo': Cores.azulClaro,
    };

    final series = <SerieHoraria>[];
    for (final tipo in ['Dia útil', 'Sábado', 'Domingo']) {
      final datas = _datasDoTipo(dados, tipo);
      if (datas.isEmpty) continue;
      final totais = _totaisPorHora(dados, datas);
      series.add(
        SerieHoraria(
          tipo,
          cores[tipo]!,
          [
            for (final h in horas)
              ((_porViagens ? totais[h]?.viagens : totais[h]?.veiculos) ?? 0) /
                  datas.length,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: GraficoPerfilPorTipoDia(
            horas: horas,
            series: series,
            unidade: _unidade,
          ),
        ),
        const SizedBox(height: 8),
        LegendaGrafico(
          itens: [for (final s in series) ItemLegenda(s.cor, s.nome)],
        ),
      ],
    );
  }

  Widget _rankingHoras(Set<DateTime> datas, Map<int, _TotaisHora> totais) {
    final n = datas.length;
    final lista = totais.entries.toList()
      ..sort((a, b) {
        final va = _porViagens ? a.value.viagens : a.value.veiculos;
        final vb = _porViagens ? b.value.viagens : b.value.veiculos;
        return vb.compareTo(va);
      });

    return RankingBarras(
      cor: _porViagens ? Cores.azulEscuro : Cores.azulMedio,
      itens: [
        for (final e in lista.take(6))
          ItemRanking(
            rotuloHora(e.key),
            (_porViagens ? e.value.viagens : e.value.veiculos) / n,
            '${formatarDecimal((_porViagens ? e.value.viagens : e.value.veiculos) / n, casas: 1)} '
            '$_unidade/dia',
          ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Tabela: oferta por faixa do dia (manhã, tarde, noite)
  // ------------------------------------------------------------
  Widget _tabelaFaixas(DadosPeriodo dados) {
    final tipos = <String, Set<DateTime>>{};
    for (final t in ['Dia útil', 'Sábado', 'Domingo']) {
      final datas = _datasDoTipo(dados, t);
      if (datas.isNotEmpty) tipos[t] = datas;
    }
    if (tipos.isEmpty) return const Text('Sem dados no período.');

    // Média de viagens por dia em cada faixa, para cada tipo de dia
    final medias = <String, Map<String, double>>{};
    tipos.forEach((tipo, datas) {
      final soma = <String, int>{};
      for (final f in dados.faixasSistema) {
        if (!datas.contains(f.data)) continue;
        final faixa = faixaDoDia(f.hora);
        soma[faixa] = (soma[faixa] ?? 0) + f.viagens;
      }
      medias[tipo] = {
        for (final e in soma.entries) e.key: e.value / datas.length,
      };
    });

    const faixas = {
      'Manhã': 'Manhã (4h às 11h59)',
      'Tarde': 'Tarde (12h às 17h59)',
      'Noite': 'Noite (18h em diante)',
    };

    final linhas = <DataRow>[
      for (final e in faixas.entries)
        DataRow(
          cells: [
            DataCell(Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold))),
            for (final tipo in tipos.keys)
              DataCell(Text(formatarDecimal(medias[tipo]![e.key] ?? 0, casas: 1))),
          ],
        ),
    ];

    // Última linha: total do dia
    const negrito = TextStyle(fontWeight: FontWeight.bold);
    linhas.add(
      DataRow(
        color: WidgetStatePropertyAll<Color?>(Cores.fundo),
        cells: [
          const DataCell(Text('Total do dia', style: negrito)),
          for (final tipo in tipos.keys)
            DataCell(
              Text(
                formatarDecimal(
                  medias[tipo]!.values.fold(0.0, (soma, v) => soma + v),
                  casas: 1,
                ),
                style: negrito,
              ),
            ),
        ],
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        columnSpacing: 24,
        columns: [
          const DataColumn(label: Text('Faixa do dia')),
          for (final tipo in tipos.keys)
            DataColumn(label: Text('$tipo (viagens/dia)'), numeric: true),
        ],
        rows: linhas,
      ),
    );
  }

  // ------------------------------------------------------------
  // Filtros desta tela
  // ------------------------------------------------------------
  Widget _controles() {
    const rotuloEstilo = TextStyle(fontSize: 12, color: Colors.black54);
    final estiloBotao = SegmentedButton.styleFrom(
      selectedBackgroundColor: Cores.azulMedio,
      selectedForegroundColor: Colors.white,
    );

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tipo de dia', style: rotuloEstilo),
                const SizedBox(height: 4),
                SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SegmentedButton<String>(
                  style: estiloBotao,
                  segments: const [
                    ButtonSegment<String>(value: 'Todos', label: Text('Todos')),
                    ButtonSegment<String>(value: 'Dia útil', label: Text('Dia útil')),
                    ButtonSegment<String>(value: 'Sábado', label: Text('Sábado')),
                    ButtonSegment<String>(value: 'Domingo', label: Text('Domingo')),
                  ],
                  selected: {_tipoDiaFiltro},
                  onSelectionChanged: (selecionado) {
                    setState(() {
                      _tipoDiaFiltro = selecionado.first;
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
                const Text('Mostrar no mapa e nos gráficos', style: rotuloEstilo),
                const SizedBox(height: 4),
                SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SegmentedButton<String>(
                  style: estiloBotao,
                  segments: const [
                    ButtonSegment<String>(value: 'Viagens', label: Text('Viagens')),
                    ButtonSegment<String>(value: 'Veículos', label: Text('Veículos')),
                  ],
                  selected: {_metrica},
                  onSelectionChanged: (selecionado) {
                    setState(() {
                      _metrica = selecionado.first;
                    });
                  },
                ),
 ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tudo que depende do tipo de dia escolhido
  List<Widget> _conteudo(DadosPeriodo dados) {
    final datas = _datasDoTipo(dados, _tipoDiaFiltro);
    final horas = _horasDoPeriodo(dados);

    if (datas.isEmpty || horas.isEmpty) {
      return [
        const CartaoPainel(
          titulo: 'Sem dados',
          child: Text('Nenhum dia deste tipo no período selecionado.'),
        ),
      ];
    }

    final totais = _totaisPorHora(dados, datas);

    return [
      GradeCartoes(colunasMaximas: 3, filhos: _cartoes(dados, datas, totais)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: CartaoPainel(
          titulo: 'Mapa de calor: $_unidade por faixa horária',
          subtitulo: 'Cada célula é uma faixa horária de um dia (7h = 7h00 às 7h59). '
              'Hora 0 = madrugada depois da meia-noite. '
              'Passe o mouse (ou segure) para ver os detalhes.',
          child: _mapaCalor(dados, datas, horas),
        ),
      ),
      const SizedBox(height: 16),
      GradeCartoes(
        colunasMaximas: 2,
        filhos: [
          CartaoPainel(
            titulo: 'Perfil horário médio por tipo de dia',
            subtitulo: 'Média de $_unidade por dia em cada faixa horária',
            child: _graficoPerfil(dados, horas),
          ),
          CartaoPainel(
            titulo: 'Horas com mais $_unidade',
            subtitulo: _tipoDiaFiltro == 'Todos'
                ? 'Média por dia, em todos os dias do período'
                : 'Média por dia, só em $_tipoDiaFiltro',
            child: _rankingHoras(datas, totais),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: CartaoPainel(
          titulo: 'Oferta por faixa do dia',
          subtitulo: 'Média de viagens por dia. Os limites das faixas foram '
              'inferidos dos dados (manhã até 11h59, tarde de 12h às 17h59, '
              'noite a partir das 18h): falta confirmar com a Smart Data.',
          child: _tabelaFaixas(dados),
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
        itemAtual: 'Faixas horárias',
      ),
      appBar: const AppBarSemob(titulo: 'Faixas horárias'),
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
                      _controles(),
                      const SizedBox(height: 16),
                      ..._conteudo(dados),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

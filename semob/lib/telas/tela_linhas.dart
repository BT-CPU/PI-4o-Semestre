import 'package:flutter/material.dart';

import '../cores.dart';
import '../limites.dart';
import '../models/dados_periodo.dart';
import '../models/dia_operacao.dart';
import '../models/desempenho_linha.dart';
import '../models/periodo.dart';
import '../servicos/dados_servico.dart';
import '../servicos/filtro_global.dart';
import '../utils/formatadores.dart';
import '../utils/tipo_dia.dart';
import '../utils/variacoes.dart';
import '../widgets/appbar_semob.dart';
import '../widgets/cartao_indicador.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grade_cartoes.dart';
import '../widgets/graficos_linhas.dart';
import '../widgets/menu_dashboard.dart';
import '../widgets/ranking_barras.dart';

// Tela 6: Linhas
class TelaLinhas extends StatefulWidget {
  final String nomeUsuario;

  const TelaLinhas({super.key, required this.nomeUsuario});

  @override
  State<TelaLinhas> createState() => _TelaLinhasState();
}

class _TelaLinhasState extends State<TelaLinhas> {
  TipoPeriodo _tipo = FiltroGlobal.tipo;
  DateTime _dataRef = FiltroGlobal.dataRef ?? DadosServico.dataMaxima;

  bool _carregando = true;
  DadosPeriodo? _dados;

  // Resultado de cada linha no período e no período anterior
  Map<String, DesempenhoLinha> _desempenho = {};
  Map<String, DesempenhoLinha>? _desempenhoAnterior;

  // Ordenação da tabela (padrão: km produtivo, do maior para o menor)
  int _colunaOrdem = 5;
  bool _crescente = false;

  // Linha escolhida para o detalhe (null = a de menor FCV)
  String? _linhaSelecionada;

  // Filtro do gráfico de faixas horárias: Todos, Dia útil, Sábado ou Domingo
  String _tipoPerfil = 'Todos';

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
      _desempenho = DesempenhoLinha.calcular(dados.kmLinhas, dados.ocorrencias);
      _desempenhoAnterior = dados.janelaAnterior == null
          ? null
          : DesempenhoLinha.calcular(
              dados.kmLinhasAnterior,
              dados.ocorrenciasAnterior,
            );
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

  void _ordenar(int coluna, bool crescente) {
    setState(() {
      _colunaOrdem = coluna;
      _crescente = crescente;
    });
  }

  // ------------------------------------------------------------
  // Listas e escolhas
  // ------------------------------------------------------------
  List<DesempenhoLinha> _ordenadas() {
    final lista = _desempenho.values.toList();
    lista.sort((a, b) {
      int c;
      switch (_colunaOrdem) {
        case 0:
          c = a.linha.compareTo(b.linha);
          break;
        case 1:
          c = a.viagensRealizadas.compareTo(b.viagensRealizadas);
          break;
        case 2:
          c = a.viagensProgramadas.compareTo(b.viagensProgramadas);
          break;
        case 3:
          c = a.ocorrencias.compareTo(b.ocorrencias);
          break;
        case 4:
          c = a.fcv.compareTo(b.fcv);
          break;
        case 5:
        case 6: // "% do km" tem a mesma ordem do km
          c = a.kmProdutivo.compareTo(b.kmProdutivo);
          break;
        default:
          c = a.kmPorViagem.compareTo(b.kmPorViagem);
      }
      return _crescente ? c : -c;
    });
    return lista;
  }

  // Linha mostrada no detalhe: a escolhida ou, se não houver, a de menor FCV
  String? _linhaEfetiva() {
    if (_desempenho.isEmpty) return null;
    final escolhida = _linhaSelecionada;
    if (escolhida != null && _desempenho.containsKey(escolhida)) {
      return escolhida;
    }
    DesempenhoLinha? pior;
    for (final l in _desempenho.values) {
      if (pior == null || l.fcv < pior.fcv) pior = l;
    }
    return pior!.linha;
  }

  // ------------------------------------------------------------
  // Cartões do topo (visão geral das linhas)
  // ------------------------------------------------------------
  List<Widget> _cartoesVisaoGeral(List<DesempenhoLinha> lista) {
    if (lista.isEmpty) return [];

    var totalViagens = 0;
    var totalKm = 0.0;
    DesempenhoLinha? maisViagens;
    DesempenhoLinha? maisKm;
    DesempenhoLinha? menorFcv;
    var maxOcorrencias = 0;

    for (final l in lista) {
      totalViagens += l.viagensRealizadas;
      totalKm += l.kmProdutivo;
      if (maisViagens == null || l.viagensRealizadas > maisViagens.viagensRealizadas) {
        maisViagens = l;
      }
      if (maisKm == null || l.kmProdutivo > maisKm.kmProdutivo) maisKm = l;
      if (menorFcv == null || l.fcv < menorFcv.fcv) menorFcv = l;
      if (l.ocorrencias > maxOcorrencias) maxOcorrencias = l.ocorrencias;
    }

    final empatadas = lista
        .where((l) => l.ocorrencias == maxOcorrencias)
        .map((l) => l.linha)
        .toList()
      ..sort();
    final abaixoDoLimite = lista.where((l) => l.fcv < limiteFcv).map((l) => l.linha).toList()
      ..sort();

    String percentual(double parte, double total) {
      return formatarDecimal(total == 0 ? 0 : parte / total * 100, casas: 1);
    }

    return [
      CartaoIndicador(
        titulo: 'Linhas em operação',
        icone: Icons.alt_route,
        valor: '${lista.length}',
        detalhe: 'No período selecionado',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Mais viagens realizadas',
        icone: Icons.directions_bus,
        valor: 'Linha ${maisViagens!.linha}',
        detalhe: '${formatarInteiro(maisViagens.viagensRealizadas)} viagens '
            '(${percentual(maisViagens.viagensRealizadas.toDouble(), totalViagens.toDouble())}%)',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Mais km produtivo',
        icone: Icons.route,
        valor: 'Linha ${maisKm!.linha}',
        detalhe: '${formatarDecimal(maisKm.kmProdutivo, casas: 1)} km '
            '(${percentual(maisKm.kmProdutivo, totalKm)}%)',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Menor FCV',
        icone: Icons.fact_check,
        valor: 'Linha ${menorFcv!.linha}',
        corValor: menorFcv.fcv < limiteFcv ? Cores.erro : Cores.azulEscuro,
        detalhe: 'FCV de ${formatarDecimal(menorFcv.fcv, casas: 2)}%  |  '
            '${menorFcv.ocorrencias} ocorrência(s)',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Mais ocorrências',
        icone: Icons.report_problem,
        valor: '$maxOcorrencias',
        detalhe: maxOcorrencias == 0
            ? 'Nenhuma ocorrência no período'
            : 'Linha${empatadas.length > 1 ? 's' : ''} ${empatadas.join(', ')}',
        semComparacao: true,
      ),
      CartaoIndicador(
        titulo: 'Linhas abaixo do limite de FCV',
        icone: Icons.warning_amber,
        valor: '${abaixoDoLimite.length}',
        corValor: abaixoDoLimite.isEmpty ? Cores.azulEscuro : Cores.erro,
        detalhe: abaixoDoLimite.isEmpty
            ? 'Todas acima de ${formatarDecimal(limiteFcv, casas: 1)}%'
            : 'Linha${abaixoDoLimite.length > 1 ? 's' : ''} ${abaixoDoLimite.join(', ')}',
        semComparacao: true,
      ),
    ];
  }

  // ------------------------------------------------------------
  // Rankings (barras)
  // ------------------------------------------------------------
  List<Widget> _paineisRanking(List<DesempenhoLinha> lista) {
    var totalViagens = 0;
    var totalKm = 0.0;
    for (final l in lista) {
      totalViagens += l.viagensRealizadas;
      totalKm += l.kmProdutivo;
    }

    final porViagens = List<DesempenhoLinha>.from(lista)
      ..sort((a, b) => b.viagensRealizadas.compareTo(a.viagensRealizadas));
    final porKm = List<DesempenhoLinha>.from(lista)
      ..sort((a, b) => b.kmProdutivo.compareTo(a.kmProdutivo));
    final porOcorrencias = List<DesempenhoLinha>.from(lista)
      ..sort((a, b) => b.ocorrencias.compareTo(a.ocorrencias));

    return [
      CartaoPainel(
        titulo: 'Viagens realizadas por linha',
        subtitulo: 'No período selecionado',
        child: RankingBarras(
          cor: Cores.azulMedio,
          itens: [
            for (final l in porViagens)
              ItemRanking(
                'Linha ${l.linha}',
                l.viagensRealizadas.toDouble(),
                '${formatarInteiro(l.viagensRealizadas)} '
                '(${formatarDecimal(totalViagens == 0 ? 0 : l.viagensRealizadas / totalViagens * 100, casas: 1)}%)',
              ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Km produtivo por linha',
        subtitulo: 'O km improdutivo não é separado por linha',
        child: RankingBarras(
          cor: Cores.azulEscuro,
          itens: [
            for (final l in porKm)
              ItemRanking(
                'Linha ${l.linha}',
                l.kmProdutivo,
                '${formatarDecimal(l.kmProdutivo, casas: 1)} km '
                '(${formatarDecimal(totalKm == 0 ? 0 : l.kmProdutivo / totalKm * 100, casas: 1)}%)',
              ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Ocorrências por linha',
        subtitulo: 'Não realizadas, não iniciadas e não terminadas',
        child: RankingBarras(
          cor: Cores.atencao,
          itens: [
            for (final l in porOcorrencias)
              ItemRanking(
                'Linha ${l.linha}',
                l.ocorrencias.toDouble(),
                '${l.ocorrencias}',
              ),
          ],
        ),
      ),
    ];
  }

  // ------------------------------------------------------------
  // Tabela principal (ordenável)
  // ------------------------------------------------------------
  Widget _tabelaDesempenho(List<DesempenhoLinha> lista, String? linhaDetalhe) {
    var totalKm = 0.0;
    for (final l in lista) {
      totalKm += l.kmProdutivo;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        sortColumnIndex: _colunaOrdem,
        sortAscending: _crescente,
        showCheckboxColumn: false,
        columnSpacing: 20,
        columns: [
          DataColumn(label: const Text('Linha'), onSort: _ordenar),
          DataColumn(label: const Text('Realizadas'), numeric: true, onSort: _ordenar),
          DataColumn(label: const Text('Programadas'), numeric: true, onSort: _ordenar),
          DataColumn(label: const Text('Ocorrências'), numeric: true, onSort: _ordenar),
          DataColumn(label: const Text('FCV'), numeric: true, onSort: _ordenar),
          DataColumn(label: const Text('Km produtivo'), numeric: true, onSort: _ordenar),
          DataColumn(label: const Text('% do km'), numeric: true, onSort: _ordenar),
          DataColumn(label: const Text('Km/viagem'), numeric: true, onSort: _ordenar),
        ],
        rows: [
          for (final l in lista)
            DataRow(
              selected: l.linha == linhaDetalhe,
              onSelectChanged: (_) {
                setState(() {
                  _linhaSelecionada = l.linha;
                });
              },
              cells: [
                DataCell(
                  Text('Linha ${l.linha}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataCell(Text(formatarInteiro(l.viagensRealizadas))),
                DataCell(Text(formatarInteiro(l.viagensProgramadas))),
                DataCell(Text('${l.ocorrencias}')),
                DataCell(
                  Text(
                    '${formatarDecimal(l.fcv, casas: 2)}%',
                    style: TextStyle(
                      color: l.fcv < limiteFcv ? Cores.erro : null,
                      fontWeight: l.fcv < limiteFcv ? FontWeight.bold : null,
                    ),
                  ),
                ),
                DataCell(Text(formatarDecimal(l.kmProdutivo, casas: 1))),
                DataCell(
                  Text(
                    '${formatarDecimal(totalKm == 0 ? 0 : l.kmProdutivo / totalKm * 100, casas: 1)}%',
                  ),
                ),
                DataCell(Text(formatarDecimal(l.kmPorViagem, casas: 2))),
              ],
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Detalhe de uma linha
  // ------------------------------------------------------------
  // Média de viagens e veículos por faixa horária, só nos dias do tipo
  // escolhido (ou em todos). Hora 0 (madrugada) vai para o fim da lista.
  List<PontoHora> _perfilHorario(DadosPeriodo dados, String linha) {
    final datas = <DateTime>{};
    for (final d in dados.dias) {
      if (_tipoPerfil == 'Todos' || tipoDia(d.data) == _tipoPerfil) {
        datas.add(d.data);
      }
    }
    if (datas.isEmpty) return [];

    final somaViagens = <int, int>{};
    final somaVeiculos = <int, int>{};
    for (final f in dados.faixasLinha) {
      if (f.linha != linha || !datas.contains(f.data)) continue;
      somaViagens[f.hora] = (somaViagens[f.hora] ?? 0) + f.viagens;
      somaVeiculos[f.hora] = (somaVeiculos[f.hora] ?? 0) + f.veiculos;
    }

    int ordem(int hora) => hora < 4 ? hora + 24 : hora;
    final horas = somaViagens.keys.toList()
      ..sort((a, b) => ordem(a).compareTo(ordem(b)));

    final n = datas.length;
    return [
      for (final h in horas)
        PontoHora(h, somaViagens[h]! / n, somaVeiculos[h]! / n),
    ];
  }

  String _nomeTipoOcorrencia(TipoOcorrencia tipo) {
    switch (tipo) {
      case TipoOcorrencia.naoRealizada:
        return 'Não realizada';
      case TipoOcorrencia.naoIniciada:
        return 'Não iniciada';
      case TipoOcorrencia.naoTerminada:
        return 'Não terminada';
    }
  }

  Widget _tabelaOcorrencias(DadosPeriodo dados, String linha) {
    final lista = dados.ocorrencias.where((o) => o.linha == linha).toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    if (lista.isEmpty) {
      return const Text('Nenhuma ocorrência desta linha no período.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll<Color?>(Cores.fundo),
        columnSpacing: 24,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Data')),
          DataColumn(label: Text('Dia')),
          DataColumn(label: Text('Tipo')),
        ],
        rows: [
          for (final o in lista)
            DataRow(
              cells: [
                DataCell(Text(formatarData(o.data))),
                DataCell(Text(nomeDiaSemana(o.data))),
                DataCell(Text(_nomeTipoOcorrencia(o.tipo))),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _cartoesDaLinha(String linha) {
    final r = _desempenho[linha]!;
    final anteriores = _desempenhoAnterior;
    // Se existe período anterior mas a linha não rodou nele, compara com zeros
    final ant = anteriores == null ? null : (anteriores[linha] ?? DesempenhoLinha(linha));
    final rotulo = rotuloComparacao(_tipo);

    var totalKm = 0.0;
    for (final l in _desempenho.values) {
      totalKm += l.kmProdutivo;
    }

    return [
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
        titulo: 'FCV da linha',
        icone: Icons.fact_check,
        valor: '${formatarDecimal(r.fcv, casas: 2)}%',
        corValor: r.fcv < limiteFcv ? Cores.erro : Cores.azulEscuro,
        detalhe: 'Limite: ${formatarDecimal(limiteFcv, casas: 1)}%',
        variacao: variacaoPontos(r.fcv, ant?.fcv, rotulo, boaQuandoSobe: true),
      ),
      CartaoIndicador(
        titulo: 'Km produtivo',
        icone: Icons.route,
        valor: '${formatarDecimal(r.kmProdutivo, casas: 1)} km',
        detalhe: '${formatarDecimal(totalKm == 0 ? 0 : r.kmProdutivo / totalKm * 100, casas: 1)}% '
            'do km de todas as linhas',
        variacao: variacaoPercentual(r.kmProdutivo, ant?.kmProdutivo, rotulo),
      ),
      CartaoIndicador(
        titulo: 'Ocorrências',
        icone: Icons.report_problem,
        valor: '${r.ocorrencias}',
        detalhe: '${r.naoRealizadas} não realizada(s), ${r.naoIniciadas} não iniciada(s), '
            '${r.naoTerminadas} não terminada(s)',
        // Aqui MENOS é melhor, por isso boaQuandoSobe é false
        variacao: variacaoPercentual(
          r.ocorrencias.toDouble(),
          ant?.ocorrencias.toDouble(),
          rotulo,
          boaQuandoSobe: false,
        ),
      ),
    ];
  }

  Widget _detalheLinha(DadosPeriodo dados, String linha) {
    final numeros = _desempenho.keys.toList()..sort();
    final perfil = _perfilHorario(dados, linha);

    return CartaoPainel(
      titulo: 'Detalhe da linha',
      subtitulo: 'Escolha a linha abaixo ou toque em uma linha da tabela',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in numeros)
                ChoiceChip(
                  label: Text('Linha $n'),
                  selected: n == linha,
                  showCheckmark: false,
                  selectedColor: Cores.azulMedio,
                  labelStyle: TextStyle(
                    color: n == linha ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _linhaSelecionada = n;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          GradeCartoes(colunasMaximas: 4, filhos: _cartoesDaLinha(linha)),
          const SizedBox(height: 16),
          GradeCartoes(
            colunasMaximas: 2,
            filhos: [
              CartaoPainel(
                titulo: 'Viagens por faixa horária',
                subtitulo: 'Média por dia, na linha $linha. Hora 0 = madrugada '
                    'depois da meia-noite.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: Cores.azulMedio,
                        selectedForegroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment<String>(value: 'Todos', label: Text('Todos')),
                        ButtonSegment<String>(value: 'Dia útil', label: Text('Dia útil')),
                        ButtonSegment<String>(value: 'Sábado', label: Text('Sábado')),
                        ButtonSegment<String>(value: 'Domingo', label: Text('Domingo')),
                      ],
                      selected: {_tipoPerfil},
                      onSelectionChanged: (selecionado) {
                        setState(() {
                          _tipoPerfil = selecionado.first;
                        });
                      },
                    ),
 ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: perfil.isEmpty
                          ? const Center(
                              child: Text('Nenhum dia deste tipo no período.'),
                            )
                          : GraficoPerfilHorario(pontos: perfil),
                    ),
                  ],
                ),
              ),
              CartaoPainel(
                titulo: 'Ocorrências da linha',
                subtitulo: 'No período selecionado',
                child: _tabelaOcorrencias(dados, linha),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    final lista = _ordenadas();
    final linhaDetalhe = _linhaEfetiva();

    return Scaffold(
      drawer: MenuDashboard(
        nomeUsuario: widget.nomeUsuario,
        itemAtual: 'Linhas',
      ),
      appBar: const AppBarSemob(titulo: 'Linhas'),
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
                        texto: 'FCV por linha = viagens realizadas ÷ (realizadas + '
                            'não realizadas + não iniciadas + não terminadas). '
                            'Esse cálculo fecha com o FCV do Resumo Geral. '
                            'Passageiros e km improdutivo não são separados por '
                            'linha nos relatórios.',
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
                      if (lista.isEmpty)
                        const CartaoPainel(
                          titulo: 'Sem dados',
                          child: Text('Nenhuma linha com viagens no período.'),
                        )
                      else ...[
                        GradeCartoes(
                          colunasMaximas: 3,
                          filhos: _cartoesVisaoGeral(lista),
                        ),
                        const SizedBox(height: 16),
                        GradeCartoes(
                          colunasMaximas: 3,
                          filhos: _paineisRanking(lista),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: CartaoPainel(
                            titulo: 'Desempenho por linha',
                            subtitulo: 'Toque no título de uma coluna para ordenar. '
                                'Toque em uma linha para ver o detalhe mais abaixo.',
                            child: _tabelaDesempenho(lista, linhaDetalhe),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: _detalheLinha(dados, linhaDetalhe!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

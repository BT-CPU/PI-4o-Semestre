import 'package:flutter/material.dart';

import '../cores.dart';
import '../limites.dart';
import '../models/dados_periodo.dart';
import '../models/dia_operacao.dart';
import '../models/periodo.dart';
import '../servicos/dados_servico.dart';
import '../servicos/filtro_global.dart';
import '../utils/formatadores.dart';
import '../utils/variacoes.dart';
import '../widgets/appbar_semob.dart';
import '../widgets/cartao_indicador.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grade_cartoes.dart';
import '../widgets/graficos.dart';
import '../widgets/menu_dashboard.dart';

// Uma linha da caixa de alertas
class Alerta {
  final bool atencao; // true = precisa de atenção, false = tudo certo
  final String texto;

  const Alerta(this.atencao, this.texto);
}

// Tela 1: Visão geral (a tela principal, pensada para apresentar ao prefeito)
class TelaVisaoGeral extends StatefulWidget {
  final String nomeUsuario;

  const TelaVisaoGeral({super.key, required this.nomeUsuario});

  @override
  State<TelaVisaoGeral> createState() => _TelaVisaoGeralState();
}

class _TelaVisaoGeralState extends State<TelaVisaoGeral> {
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
  // Alertas do período
  // ------------------------------------------------------------
  List<Alerta> _montarAlertas(DadosPeriodo dados) {
    final alertas = <Alerta>[];
    final dias = dados.dias;
    final ocorrencias = dados.ocorrencias;
    if (dias.isEmpty) return alertas;

    // 1) Dias com FCV abaixo do limite
    final fcvBaixo = dias.where((d) => d.fcv < limiteFcv).toList()
      ..sort((a, b) => a.fcv.compareTo(b.fcv));
    if (fcvBaixo.isEmpty) {
      alertas.add(
        Alerta(
          false,
          'FCV acima de ${formatarDecimal(limiteFcv, casas: 1)}% em todos os dias do período.',
        ),
      );
    } else {
      final menores = fcvBaixo
          .take(3)
          .map((d) =>
              '${formatarDataCurta(d.data)} (${formatarDecimal(d.fcv, casas: 1)}%)')
          .join(', ');
      alertas.add(
        Alerta(
          true,
          '${fcvBaixo.length} dia(s) com FCV abaixo de '
          '${formatarDecimal(limiteFcv, casas: 1)}%. Menores: $menores.',
        ),
      );
    }

    // 2) Ocorrências (viagens com problema)
    final total = ocorrencias.length;
    if (total == 0) {
      alertas.add(
        const Alerta(
          false,
          'Nenhuma viagem não realizada, não iniciada ou não terminada.',
        ),
      );
    } else {
      final naoRealizadas = ocorrencias
          .where((o) => o.tipo == TipoOcorrencia.naoRealizada)
          .length;
      final naoIniciadas = ocorrencias
          .where((o) => o.tipo == TipoOcorrencia.naoIniciada)
          .length;
      final naoTerminadas = ocorrencias
          .where((o) => o.tipo == TipoOcorrencia.naoTerminada)
          .length;
      alertas.add(
        Alerta(
          true,
          '$total viagem(ns) com ocorrência: $naoRealizadas não realizada(s), '
          '$naoIniciadas não iniciada(s) e $naoTerminadas não terminada(s).',
        ),
      );

      // 3) Linha com mais ocorrências
      final porLinha = <String, int>{};
      for (final o in ocorrencias) {
        porLinha[o.linha] = (porLinha[o.linha] ?? 0) + 1;
      }
      var linhaTop = porLinha.keys.first;
      for (final linha in porLinha.keys) {
        if (porLinha[linha]! > porLinha[linhaTop]!) linhaTop = linha;
      }
      final qtd = porLinha[linhaTop]!;
      final pct = qtd / total * 100;
      alertas.add(
        Alerta(
          true,
          'Linha $linhaTop concentra mais ocorrências: $qtd de $total '
          '(${formatarDecimal(pct, casas: 0)}%).',
        ),
      );
    }

    // 4) Km improdutivo
    var diaMaisAlto = dias.first;
    for (final d in dias) {
      if (d.percentualKmImprodutivo > diaMaisAlto.percentualKmImprodutivo) {
        diaMaisAlto = d;
      }
    }
    final maximo = diaMaisAlto.percentualKmImprodutivo;
    if (maximo > limiteKmImprodutivo) {
      final quantidade = dias
          .where((d) => d.percentualKmImprodutivo > limiteKmImprodutivo)
          .length;
      alertas.add(
        Alerta(
          true,
          'Km improdutivo acima de ${formatarDecimal(limiteKmImprodutivo, casas: 0)}% '
          'em $quantidade dia(s). Maior: ${formatarDecimal(maximo, casas: 1)}% '
          'em ${formatarDataCurta(diaMaisAlto.data)}.',
        ),
      );
    } else {
      alertas.add(
        Alerta(
          false,
          'Km improdutivo dentro do esperado (máximo de '
          '${formatarDecimal(maximo, casas: 1)}% em ${formatarDataCurta(diaMaisAlto.data)}).',
        ),
      );
    }

    return alertas;
  }

  // ------------------------------------------------------------
  // Pedaços da tela
  // ------------------------------------------------------------
  List<Widget> _cartoesIndicadores(DadosPeriodo dados) {
    final r = dados.resumo;
    final ant = dados.resumoAnterior;
    final rotulo = rotuloComparacao(_tipo);

    return [
      CartaoIndicador(
        titulo: 'Viagens realizadas',
        icone: Icons.directions_bus,
        valor: formatarInteiro(r.viagensRealizadas),
        detalhe: 'Programadas: ${formatarInteiro(r.viagensProgramadas)}  |  '
            'Diferença: ${formatarInteiro(r.viagensProgramadas - r.viagensRealizadas)}',
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
        variacao: variacaoPontos(r.fcv, ant?.fcv, rotulo, boaQuandoSobe: true),
      ),
      CartaoIndicador(
        titulo: 'Quilometragem total',
        icone: Icons.route,
        valor: '${formatarDecimal(r.kmTotal, casas: 1)} km',
        detalhe: 'Produtivo: ${formatarDecimal(r.kmProdutivo, casas: 1)} km  |  '
            'Improdutivo: ${formatarDecimal(r.percentualKmImprodutivo, casas: 1)}%',
        variacao: variacaoPercentual(r.kmTotal, ant?.kmTotal, rotulo),
      ),
      CartaoIndicador(
        titulo: 'Passageiros',
        icone: Icons.groups,
        valor: formatarInteiro(r.passageirosTotal),
        detalhe: 'Pagantes: ${formatarInteiro(r.passageirosPagantes)}  |  '
            'Não pagantes: ${formatarInteiro(r.passageirosNaoPagantes)}',
        variacao: variacaoPercentual(
          r.passageirosTotal.toDouble(),
          ant?.passageirosTotal.toDouble(),
          rotulo,
          boaQuandoSobe: true,
        ),
      ),
      CartaoIndicador(
        titulo: 'Passageiros não pagantes',
        icone: Icons.person_off,
        valor: '${formatarDecimal(r.percentualNaoPagantes, casas: 1)}%',
        detalhe: '${formatarInteiro(r.passageirosNaoPagantes)} de '
            '${formatarInteiro(r.passageirosTotal)} passageiros',
        variacao: variacaoPontos(
          r.percentualNaoPagantes,
          ant?.percentualNaoPagantes,
          rotulo,
        ),
      ),
      CartaoIndicador(
        titulo: 'Crédito circulante',
        icone: Icons.account_balance_wallet,
        valor: formatarMoeda(r.creditoCirculante),
        detalhe: 'Vendas: ${formatarMoeda(r.vendas)}  |  '
            'Uso: ${formatarMoeda(r.utilizacao)}',
        dica: 'Vendas de créditos menos a utilização no período. '
            'Não representa receita nem prejuízo: parte das vendas não '
            'consome crédito no mesmo dia.',
        variacao: variacaoPercentual(
          r.creditoCirculante,
          ant?.creditoCirculante,
          rotulo,
        ),
      ),
    ];
  }

  Widget _listaAlertas(List<Alerta> alertas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in alertas)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a.atencao ? Icons.warning_amber : Icons.check_circle,
                  size: 20,
                  color: a.atencao ? Cores.atencao : Cores.sucesso,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(a.texto)),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _cartoesGraficos(DadosPeriodo dados) {
    final grafico = dados.diasGrafico;
    final textoIntervalo = grafico.isEmpty
        ? ''
        : '${formatarData(grafico.first.data)} a ${formatarData(grafico.last.data)}';

    return [
      CartaoPainel(
        titulo: 'Passageiros por dia',
        subtitulo: textoIntervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 220, child: GraficoPassageiros(dias: grafico)),
            const SizedBox(height: 8),
            const LegendaGrafico(
              itens: [
                ItemLegenda(Cores.azulEscuro, 'Total'),
                ItemLegenda(Cores.azulClaro, 'Não pagantes'),
              ],
            ),
          ],
        ),
      ),
      CartaoPainel(
        titulo: 'Cumprimento de viagens (FCV) por dia',
        subtitulo: textoIntervalo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: GraficoFcv(dias: grafico, limite: limiteFcv),
            ),
            const SizedBox(height: 8),
            LegendaGrafico(
              itens: [
                const ItemLegenda(Cores.azulMedio, 'FCV do dia'),
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
        titulo: 'Vendas × utilização de créditos por dia',
        subtitulo: textoIntervalo,
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
        titulo: 'Alertas do período',
        subtitulo: 'Limites de exemplo, a serem definidos pela SEMOB',
        child: _listaAlertas(_montarAlertas(dados)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;

    return Scaffold(
      drawer: MenuDashboard(
        nomeUsuario: widget.nomeUsuario,
        itemAtual: 'Visão geral',
      ),
      appBar: const AppBarSemob(titulo: 'Visão geral'),
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
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Os indicadores usam as posições reais dos dados; a dica fica na camada raiz.
class GraficoLinhaComTooltip extends StatefulWidget {
  final LineChartData data;
  const GraficoLinhaComTooltip(this.data, {super.key});

  @override
  State<GraficoLinhaComTooltip> createState() => _GraficoLinhaComTooltipState();
}

class _GraficoLinhaComTooltipState extends State<GraficoLinhaComTooltip> {
  Map<int, int> _pontosAtivos = {};

  void _selecionar(List<LineBarSpot> pontos) {
    final novos = {for (final ponto in pontos) ponto.barIndex: ponto.spotIndex};
    if (novos.length == _pontosAtivos.length &&
        novos.entries.every((e) => _pontosAtivos[e.key] == e.value)) {
      return;
    }
    setState(() => _pontosAtivos = novos);
  }

  @override
  void didUpdateWidget(GraficoLinhaComTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.lineBarsData != widget.data.lineBarsData) {
      _pontosAtivos = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final cores = Theme.of(context).colorScheme;
    return _TooltipGrafico(
      construir: (mostrar, esconder, chaveRender) => LineChart(
        data.copyWith(
          lineBarsData: [
            for (var i = 0; i < data.lineBarsData.length; i++)
              data.lineBarsData[i].copyWith(
                showingIndicators: [
                  if (_pontosAtivos[i] != null &&
                      _pontosAtivos[i]! < data.lineBarsData[i].spots.length)
                    _pontosAtivos[i]!,
                ],
              ),
          ],
          lineTouchData: data.lineTouchData.copyWith(
            handleBuiltInTouches: false,
            getTouchedSpotIndicator: (serie, indices) => [
              for (final _ in indices)
                TouchedSpotIndicatorData(
                  const FlLine(color: Colors.transparent, strokeWidth: 0),
                  FlDotData(
                    show: true,
                    getDotPainter: (ponto, percentual, linha, indice) =>
                        FlDotCirclePainter(
                          radius: 5,
                          color: serie.color ?? cores.primary,
                          strokeWidth: 2.5,
                          strokeColor: cores.onSurface,
                        ),
                  ),
                ),
            ],
            touchCallback: (evento, resposta) {
              data.lineTouchData.touchCallback?.call(evento, resposta);
              final pontos = resposta?.lineBarSpots;
              if (!evento.isInterestedForInteractions ||
                  pontos == null ||
                  pontos.isEmpty) {
                _selecionar(const []);
                esconder();
                return;
              }
              _selecionar(pontos);
              final itens = data.lineTouchData.touchTooltipData.getTooltipItems(
                pontos,
              );
              mostrar(evento, [
                for (final item in itens)
                  if (item != null)
                    TextSpan(text: item.text, children: item.children),
              ]);
            },
          ),
        ),
        chartRendererKey: chaveRender,
        duration: Duration.zero,
      ),
    );
  }
}

class GraficoBarrasComTooltip extends StatelessWidget {
  final BarChartData data;
  const GraficoBarrasComTooltip(this.data, {super.key});

  @override
  Widget build(BuildContext context) => _TooltipGrafico(
    construir: (mostrar, esconder, chaveRender) => BarChart(
      data.copyWith(
        barTouchData: data.barTouchData.copyWith(
          handleBuiltInTouches: false,
          touchCallback: (evento, resposta) {
            data.barTouchData.touchCallback?.call(evento, resposta);
            final ponto = resposta?.spot;
            if (!evento.isInterestedForInteractions || ponto == null) {
              esconder();
              return;
            }
            final item = data.barTouchData.touchTooltipData.getTooltipItem(
              ponto.touchedBarGroup,
              ponto.touchedBarGroupIndex,
              ponto.touchedRodData,
              ponto.touchedRodDataIndex,
            );
            final caixa =
                chaveRender.currentContext?.findRenderObject() as RenderBox?;
            mostrar(
              evento,
              [
                if (item != null)
                  TextSpan(text: item.text, children: item.children),
              ],
              pontoGlobal: caixa?.localToGlobal(ponto.offset),
              corPonto: ponto.touchedRodData.color,
            );
          },
        ),
      ),
      chartRendererKey: chaveRender,
    ),
  );
}

typedef _MostrarDica = void Function(
  FlTouchEvent evento,
  List<TextSpan> textos, {
  Offset? pontoGlobal,
  Color? corPonto,
});

class _TooltipGrafico extends StatefulWidget {
  final Widget Function(
    _MostrarDica mostrar,
    VoidCallback esconder,
    GlobalKey chaveRender,
  )
  construir;
  const _TooltipGrafico({required this.construir});
  @override
  State<_TooltipGrafico> createState() => _TooltipGraficoState();
}

class _TooltipGraficoState extends State<_TooltipGrafico> {
  final _chaveRender = GlobalKey();
  OverlayEntry? _entrada;
  Offset? _posicaoGlobal;
  Offset? _pontoGlobal;
  Color? _corPonto;
  List<TextSpan> _textos = const [];

  void _mover(PointerEvent evento) {
    _posicaoGlobal = evento.position;
    _entrada?.markNeedsBuild();
  }

  void _esconder() {
    _entrada?.remove();
    _entrada?.dispose();
    _entrada = null;
    _pontoGlobal = null;
  }

  void _mostrar(
    FlTouchEvent evento,
    List<TextSpan> textos, {
    Offset? pontoGlobal,
    Color? corPonto,
  }) {
    if (!mounted || textos.isEmpty || evento.localPosition == null) {
      _esconder();
      return;
    }
    _textos = textos;
    _pontoGlobal = pontoGlobal;
    _corPonto = corPonto;
    _posicaoGlobal ??= (context.findRenderObject()! as RenderBox).localToGlobal(
      evento.localPosition!,
    );
    if (_entrada == null) {
      final sobreposicao = Overlay.of(context, rootOverlay: true);
      _entrada = OverlayEntry(
        builder: (contextoOverlay) {
          final caixa = sobreposicao.context.findRenderObject()! as RenderBox;
          final ancora = caixa.globalToLocal(_posicaoGlobal!);
          final ponto = _pontoGlobal == null
              ? null
              : caixa.globalToLocal(_pontoGlobal!);
          final cores = Theme.of(context).colorScheme;
          return Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  if (ponto != null)
                    Positioned(
                      left: ponto.dx - 6.5,
                      top: ponto.dy - 6.5,
                      child: Container(
                        key: const ValueKey('marcador-ponto-barra'),
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _corPonto ?? cores.primary,
                          border: Border.all(
                            color: cores.onSurface,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: CustomSingleChildLayout(
                      delegate: _PosicaoDica(ancora),
                      child: Material(
                        key: const ValueKey('tooltip-grafico-prioritario'),
                        color: cores.inverseSurface,
                        elevation: 10,
                        shadowColor: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                for (var i = 0; i < _textos.length; i++) ...[
                                  if (i > 0) const TextSpan(text: '\n\n'),
                                  _textos[i],
                                ],
                              ],
                            ),
                            style: TextStyle(
                              color: cores.onInverseSurface,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      sobreposicao.insert(_entrada!);
    } else {
      _entrada!.markNeedsBuild();
    }
  }

  @override
  void deactivate() {
    _esconder();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: _mover,
    onExit: (_) {
      _esconder();
      _posicaoGlobal = null;
    },
    child: Listener(
      onPointerDown: _mover,
      onPointerMove: _mover,
      onPointerSignal: (_) => _esconder(),
      child: widget.construir(_mostrar, _esconder, _chaveRender),
    ),
  );
}

class _PosicaoDica extends SingleChildLayoutDelegate {
  final Offset ancora;
  const _PosicaoDica(this.ancora);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(340, math.max(0, constraints.maxWidth - 24)),
        maxHeight: math.max(0, constraints.maxHeight - 24),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = ancora.dx + childSize.width + 16 > size.width - 12
        ? ancora.dx - childSize.width - 16
        : ancora.dx + 16;
    final y = ancora.dy + childSize.height + 16 > size.height - 12
        ? ancora.dy - childSize.height - 16
        : ancora.dy + 16;
    return Offset(
      x.clamp(12, math.max(12, size.width - childSize.width - 12)),
      y.clamp(12, math.max(12, size.height - childSize.height - 12)),
    );
  }

  @override
  bool shouldRelayout(_PosicaoDica old) => old.ancora != ancora;
}

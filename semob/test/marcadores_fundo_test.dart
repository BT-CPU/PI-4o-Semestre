import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob/tema.dart';
import 'package:semob/widgets/fundo_abstrato.dart';
import 'package:semob/widgets/grafico_tooltip.dart';

void main() {
  for (final escuro in [false, true]) {
    testWidgets(
      'círculos acompanham o dado de cada série no tema ${escuro ? 'escuro' : 'claro'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: criarTema(escuro: escuro),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: GraficoLinhaComTooltip(
                    LineChartData(
                      minX: 0,
                      maxX: 1,
                      minY: 0,
                      maxY: 100,
                      titlesData: const FlTitlesData(show: false),
                      lineTouchData: const LineTouchData(
                        touchSpotThreshold: 40,
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [FlSpot(0, 25), FlSpot(1, 75)],
                          color: Colors.blue,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: const [FlSpot(0, 40), FlSpot(1, 60)],
                          color: Colors.teal,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(700, 500));
        await mouse.moveTo(const Offset(2, 150));
        await tester.pumpAndSettle();
        LineChart grafico() => tester.widget<LineChart>(find.byType(LineChart));
        expect(grafico().data.lineBarsData.map((s) => s.showingIndicators), [
          [0],
          [0],
        ]);
        final serie = grafico().data.lineBarsData.first;
        final indicador = grafico().data.lineTouchData.getTouchedSpotIndicator(
          serie,
          [0],
        ).single!;
        final pintor = indicador.touchedSpotDotData.getDotPainter(
          serie.spots.first,
          0,
          serie,
          0,
        ) as FlDotCirclePainter;
        expect(pintor.radius, 5);
        expect(pintor.strokeWidth, 2.5);
        await mouse.moveTo(const Offset(298, 50));
        await tester.pumpAndSettle();
        expect(grafico().data.lineBarsData.map((s) => s.showingIndicators), [
          [1],
          [1],
        ]);
        expect(
          find.byKey(const ValueKey('tooltip-grafico-prioritario')),
          findsOneWidget,
        );
        await mouse.moveTo(const Offset(700, 500));
        await tester.pumpAndSettle();
        expect(
          grafico().data.lineBarsData.every((s) => s.showingIndicators.isEmpty),
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('tooltip-grafico-prioritario')),
          findsNothing,
        );
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final escala in [1.0, 1.3]) {
    testWidgets(
      'marcador da barra fica no valor exato mesmo com escala $escala',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: criarTema(),
            home: Scaffold(
              body: Transform.scale(
                scale: escala,
                alignment: Alignment.topLeft,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 300,
                    height: 200,
                    child: GraficoBarrasComTooltip(
                      BarChartData(
                        minY: 0,
                        maxY: 100,
                        titlesData: const FlTitlesData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [BarChartRodData(toY: 50, width: 80)],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(700, 500));
        await mouse.moveTo(Offset(150 * escala, 160 * escala));
        await tester.pumpAndSettle();
        final marcador = find.byKey(const ValueKey('marcador-ponto-barra'));
        expect(marcador, findsOneWidget);
        final centro = tester.getCenter(marcador);
        expect(centro.dx, closeTo(150 * escala, .01));
        expect(centro.dy, closeTo(100 * escala, .01));
        await mouse.moveTo(const Offset(700, 500));
        await tester.pumpAndSettle();
        expect(marcador, findsNothing);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final escuro in [false, true]) {
    testWidgets(
      'fundo usa a imagem própria do tema ${escuro ? 'escuro' : 'claro'} sem filtro de cor',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: criarTema(escuro: escuro),
            home: const FundoAbstrato(child: SizedBox.expand()),
          ),
        );
        await tester.pumpAndSettle();
        final caixa = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(FundoAbstrato),
            matching: find.byType(DecoratedBox),
          ),
        );
        final decoracao = caixa.decoration as BoxDecoration;
        final imagem = decoracao.image!;
        final nome = (imagem.image as AssetImage).assetName;
        expect(
          nome,
          'assets/images/fundo_institucional_${escuro ? 'escuro' : 'claro'}.png',
        );
        expect(imagem.fit, BoxFit.fitWidth);
        expect(imagem.alignment, Alignment.bottomCenter);
        expect(imagem.colorFilter, isNull);
        final bytes = await rootBundle.load(nome);
        expect(bytes.getUint32(16), greaterThanOrEqualTo(1600));
        expect(bytes.getUint32(20), greaterThanOrEqualTo(900));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

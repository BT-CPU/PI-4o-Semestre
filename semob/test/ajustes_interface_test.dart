import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob/main.dart';
import 'package:semob/servicos/preferencias_visuais.dart';
import 'package:semob/servicos/sessao.dart';
import 'package:semob/servicos/usuario_servico.dart';
import 'package:semob/tema.dart';
import 'package:semob/telas/tela_admin.dart';
import 'package:semob/telas/tela_upload.dart';
import 'package:semob/telas/tela_visao_geral.dart';
import 'package:semob/widgets/grafico_tooltip.dart';
import 'package:semob/widgets/logo_semob.dart';
import 'package:semob/widgets/menu_dashboard.dart';

import 'apoio/montar_tela.dart';
import 'apoio/api_simulada.dart';
import 'configuracoes_interface_test.dart' show entrar;

void main() {
  setUp(() {
    Sessao.sair();
    final p = PreferenciasVisuais.instancia;
    p.escuro = false;
    p.menuRecolhido = false;
    p.zoom = 1;
    p.letras = 1;
  });
  tearDown(Sessao.sair);

  testWidgetsComApi(
    'símbolo maior no login, com branco atrás e sem legenda SEMOB',
    (tester) async {
      await tester.pumpWidget(const MeuApp());
      await tester.pumpAndSettle();
      final simbolo = find.byType(LogoSemob);
      expect(tester.widget<LogoSemob>(simbolo).altura, 128);
      final branco = find.ancestor(
        of: simbolo,
        matching: find.byType(ColoredBox),
      );
      expect(
        tester.widgetList<ColoredBox>(branco).map((caixa) => caixa.color),
        contains(Colors.white),
      );
      expect(find.text('SEMOB'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgetsComApi(
    'usuário aparece à esquerda da engrenagem e sai do menu lateral',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);
      await entrar(tester);
      final usuario = find.byKey(const ValueKey('usuario-na-barra'));
      expect(tester.widget<Text>(usuario).data, 'admin');
      expect(
        tester.getCenter(usuario).dx,
        lessThan(tester.getCenter(find.byTooltip('Configurações')).dx),
      );
      expect(
        find.descendant(
          of: find.byType(MenuDashboard),
          matching: find.text('admin'),
        ),
        findsNothing,
      );
    },
  );

  for (final abrirUpload in [false, true]) {
    for (final voltarPeloSistema in [false, true]) {
      testWidgetsComApi(
        '${abrirUpload ? 'Enviar Arquivo' : 'Administração'} volta direto ao menu (${voltarPeloSistema ? 'sistema' : 'seta'})',
        (tester) async {
          Sessao.usuarioAtual = await UsuarioServico.autenticar(
            'admin',
            senhaDeTeste,
          );
          // Simula também o acesso direto, sem nenhuma rota anterior na pilha.
          await tester.pumpWidget(
            MaterialApp(
              theme: criarTema(),
              home: abrirUpload ? const TelaUpload() : const TelaAdmin(),
            ),
          );
          await tester.pumpAndSettle();
          if (voltarPeloSistema) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Voltar ao menu'));
          }
          await tester.pumpAndSettle();
          expect(find.byType(TelaVisaoGeral), findsOneWidget);
          expect(find.byType(TelaAdmin), findsNothing);
          expect(find.byType(TelaUpload), findsNothing);
          expect(Sessao.usuarioAtual?.usuario, 'admin');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final escuro in [false, true]) {
    for (final tela in telasDoDashboard) {
      testWidgetsComApi(
        '${tela.titulo}: contraste dos cabeçalhos e totais no tema ${escuro ? 'escuro' : 'claro'}',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: criarTema(escuro: escuro),
              home: tela.criar('teste'),
            ),
          );
          await tester.pumpAndSettle();
          for (final elemento in find.byType(DataTable).evaluate()) {
            final tabela = elemento.widget as DataTable;
            final tema = DataTableTheme.of(elemento);
            final cabecalho = (tabela.headingRowColor ?? tema.headingRowColor)!
                .resolve({})!;
            final corTexto =
                (tabela.headingTextStyle ?? tema.headingTextStyle)!.color!;
            double contraste(Color a, Color b) {
              final la = a.computeLuminance();
              final lb = b.computeLuminance();
              return ((la > lb ? la : lb) + .05) / ((la < lb ? la : lb) + .05);
            }

            expect(contraste(cabecalho, corTexto), greaterThanOrEqualTo(4.5));
            for (final linha in tabela.rows) {
              final estados = {if (linha.selected) WidgetState.selected};
              final fundo =
                  linha.color?.resolve(estados) ??
                  tema.dataRowColor?.resolve(estados) ??
                  Theme.of(elemento).colorScheme.surface;
              for (final celula in linha.cells) {
                final texto = celula.child;
                final cor = texto is Text
                    ? texto.style?.color ?? tema.dataTextStyle!.color!
                    : tema.dataTextStyle!.color!;
                expect(contraste(fundo, cor), greaterThanOrEqualTo(4.5));
              }
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final barras in [false, true]) {
    testWidgetsComApi(
      'tooltip de ${barras ? 'barras' : 'linhas'} fica fora do recorte do cartão e desaparece ao sair',
      (tester) async {
        const mensagem =
            'Dia 01/08\nValor: 25\nDetalhe 1\nDetalhe 2\nDetalhe 3\nDetalhe 4';
        final grafico = barras
            ? GraficoBarrasComTooltip(
                BarChartData(
                  minY: 0,
                  maxY: 100,
                  titlesData: const FlTitlesData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [BarChartRodData(toY: 100, width: 80)],
                    ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (_, _, _, _) =>
                          BarTooltipItem(mensagem, const TextStyle()),
                    ),
                  ),
                ),
              )
            : GraficoLinhaComTooltip(
                LineChartData(
                  minX: 0,
                  maxX: 1,
                  minY: 0,
                  maxY: 100,
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [FlSpot(0, 25), FlSpot(1, 25)],
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchSpotThreshold: 50,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (pontos) => [
                        for (final _ in pontos)
                          LineTooltipItem(mensagem, const TextStyle()),
                      ],
                    ),
                  ),
                ),
              );
        await tester.pumpWidget(
          MaterialApp(
            theme: criarTema(),
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 20,
                    width: 260,
                    height: 160,
                    child: ClipRect(
                      key: const ValueKey('recorte-do-cartao'),
                      child: grafico,
                    ),
                  ),
                  const Positioned(
                    top: 180,
                    left: 0,
                    right: 0,
                    height: 200,
                    child: ColoredBox(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          barras ? const Offset(150, 140) : const Offset(275, 140),
        );
        await tester.pumpAndSettle();
        final dica = find.byKey(const ValueKey('tooltip-grafico-prioritario'));
        expect(dica, findsOneWidget);
        expect(
          find.ancestor(
            of: dica,
            matching: find.byKey(const ValueKey('recorte-do-cartao')),
          ),
          findsNothing,
        );
        final area = tester.getRect(dica);
        expect(area.left, greaterThanOrEqualTo(12));
        expect(area.right, lessThanOrEqualTo(788));
        expect(area.bottom, greaterThan(180));
        await mouse.moveTo(const Offset(700, 500));
        await tester.pumpAndSettle();
        expect(dica, findsNothing);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

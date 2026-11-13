import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob/main.dart';
import 'package:semob/tema.dart';
import 'package:semob/telas/tela_passageiros.dart';
import 'package:semob/telas/tela_visao_geral.dart';
import 'package:semob/widgets/menu_dashboard.dart';

import 'apoio/montar_tela.dart';

void main() {
  for (final tamanho in tamanhosDeTela) {
    testWidgets('login utilizável em ${tamanho.nome}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = tamanho.tamanho;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MeuApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Digite o usuário'), findsOneWidget);
      expect(find.text('Digite a senha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final tela in telasDoDashboard) {
    for (final tamanho in [tamanhoCelularPequeno, tamanhoTablet]) {
      testWidgets('${tela.titulo} em ${tamanho.nome}', (tester) async {
        final handler = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          handler?.call(details);
        };
        addTearDown(() => FlutterError.onError = handler);
        await montarTela(tester, tela.criar('Operador'), tamanho: tamanho);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('menu fixo navega sem remover a rota e permite sair', (
    tester,
  ) async {
    await montarTela(tester, const TelaVisaoGeral(nomeUsuario: 'Operador'));
    expect(find.byType(MenuDashboard), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(MenuDashboard),
        matching: find.text('Passageiros'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TelaPassageiros), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gaveta no celular fecha ao selecionar uma seção', (
    tester,
  ) async {
    await montarTela(
      tester,
      const TelaVisaoGeral(nomeUsuario: 'Operador'),
      tamanho: tamanhoCelular,
    );
    await tester.tap(find.byTooltip('Abrir menu de navegação'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MenuDashboard),
        matching: find.text('Passageiros'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TelaPassageiros), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('preferência de movimento reduzido desativa a transição dos botões', () {
    expect(
      criarTema().elevatedButtonTheme.style!.animationDuration,
      const Duration(milliseconds: 150),
    );
    expect(
      criarTema(reduzirMovimento: true)
          .elevatedButtonTheme
          .style!
          .animationDuration,
      Duration.zero,
    );
  });
}

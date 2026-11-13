import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob/main.dart';
import 'package:semob/models/usuario.dart';
import 'package:semob/servicos/filtro_global.dart';
import 'package:semob/servicos/preferencias_visuais.dart';
import 'package:semob/servicos/sessao.dart';
import 'package:semob/tema.dart';
import 'package:semob/telas/tela_admin.dart';
import 'package:semob/telas/tela_passageiros.dart';
import 'package:semob/telas/tela_visao_geral.dart';
import 'package:semob/widgets/cartao_indicador.dart';
import 'package:semob/widgets/menu_dashboard.dart';

import 'apoio/montar_tela.dart';
import 'apoio/api_simulada.dart';

Future<void> entrar(WidgetTester tester) async {
  await tester.pumpWidget(const MeuApp());
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'admin');
  await tester.enterText(find.byType(TextFormField).at(1), senhaDeTeste);
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  final preferencias = PreferenciasVisuais.instancia;
  setUp(() {
    Sessao.sair();
    preferencias.escuro = false;
    preferencias.menuRecolhido = false;
    preferencias.zoom = 1;
    preferencias.letras = 1;
  });
  tearDown(() {
    Sessao.sair();
    preferencias.escuro = false;
    preferencias.menuRecolhido = false;
    preferencias.zoom = 1;
    preferencias.letras = 1;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgetsComApi(
    'login omite os textos removidos e não expõe opções Admin',
    (tester) async {
      await tester.pumpWidget(const MeuApp());
      await tester.pumpAndSettle();
      for (final texto in [
        'SEMOB / MOBILIDADE URBANA',
        'Operação de Transporte',
        'Informação para acompanhar',
        'Acesso local temporário ativo',
      ]) {
        expect(find.textContaining(texto), findsNothing);
      }
      await tester.tap(find.byTooltip('Configurações'));
      await tester.pumpAndSettle();
      expect(find.text('Admin'), findsNothing);
    },
  );

  testWidgetsComApi('menu minimiza, mantém navegação e saída fica na barra', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.reset);
    await entrar(tester);
    expect(
      find.descendant(
        of: find.byType(MenuDashboard),
        matching: find.byTooltip('Sair'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Sair'), findsOneWidget);
    await tester.tap(find.byTooltip('Minimizar menu'));
    await tester.pumpAndSettle();
    expect(preferencias.menuRecolhido, isTrue);
    await tester.tap(find.byTooltip('Passageiros'));
    await tester.pumpAndSettle();
    expect(find.byType(TelaPassageiros), findsOneWidget);
    await tester.tap(find.byTooltip('Expandir menu'));
    await tester.pumpAndSettle();
    expect(find.text('Viagens e Cumprimentos'), findsOneWidget);
    expect(find.text('Faixas Horárias'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgetsComApi('zoom, letras e modo escuro são aplicados e restaurados', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.reset);
    await entrar(tester);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Zoom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Letras'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(preferencias.zoom, 1.1);
    expect(preferencias.letras, 1.05);
    expect(
      Theme.of(tester.element(find.byType(Dialog))).brightness,
      Brightness.dark,
    );
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(Dialog))).width,
      closeTo(1440 / 1.1, .1),
    );
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(Dialog))).scale(10),
      closeTo(10.5, .01),
    );
    await tester.tap(find.text('Restaurar zoom e letras'));
    await tester.pumpAndSettle();
    expect(preferencias.zoom, 1);
    expect(preferencias.letras, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgetsComApi('configurações de funcionário não incluem Admin', (
    tester,
  ) async {
    Sessao.usuarioAtual = Usuario(
      id: 'func',
      nome: 'Funcionário',
      usuario: 'func',
      email: 'func@example.com',
      ehAdmin: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: criarTema(),
        home: const TelaVisaoGeral(nomeUsuario: 'func'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Administração de Usuários'), findsNothing);
    expect(find.text('Enviar Arquivo'), findsNothing);
  });

  testWidgetsComApi('administrador abre administração pela engrenagem', (
    tester,
  ) async {
    await entrar(tester);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Admin'));
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Administração de Usuários'));
    await tester.tap(find.text('Administração de Usuários'));
    await tester.pumpAndSettle();
    expect(find.byType(TelaAdmin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgetsComApi(
    'cópia inclui título, valor e detalhes e permite fechar notificação',
    (tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiado = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await entrar(tester);
      final cartao = find.byType(CartaoIndicador).first;
      final botao = find.descendant(
        of: cartao,
        matching: find.byTooltip('Copiar informações'),
      );
      await tester.ensureVisible(botao);
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(copiado, contains('Viagens realizadas'));
      expect(copiado, contains('Programadas:'));
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgetsComApi('aviso de exemplo abre como pop-up com fechar', (
    tester,
  ) async {
    await entrar(tester);
    await tester.tap(find.text('Dados de exemplo'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('agosto/2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar notificação'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgetsComApi('cópia de gráfico inclui os valores da série', (
    tester,
  ) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: criarTema(),
        home: Scaffold(
          body: CartaoPainel(
            titulo: 'Viagens por dia',
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [FlSpot(0, 12), FlSpot(1, 34)],
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
    await tester.tap(find.byTooltip('Copiar informações'));
    await tester.pumpAndSettle();
    expect(copiado, contains('Viagens por dia'));
    expect(copiado, contains('0.0; 12.0'));
    expect(copiado, contains('1.0; 34.0'));
  });

  testWidgetsComApi('celular mantém acesso com zoom e letras no máximo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    preferencias.zoom = 1.3;
    preferencias.letras = 1.3;
    preferencias.escuro = true;
    await entrar(tester);
    expect(find.byType(TelaVisaoGeral), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgetsComApi('tela cheia consulta e alterna o canal Windows', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const canal = MethodChannel('semob/janela');
    var cheia = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (
      call,
    ) async {
      if (call.method == 'telaCheia') cheia = call.arguments as bool;
      return cheia;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canal,
        null,
      ),
    );
    await tester.pumpWidget(const MeuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tela cheia'));
    await tester.pumpAndSettle();
    expect(cheia, isTrue);
    await tester.tap(find.text('Sair da tela cheia'));
    await tester.pumpAndSettle();
    expect(cheia, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final tela in telasDoDashboard) {
    for (final tamanho in [
      tamanhoCelularPequeno,
      tamanhoTablet,
      tamanhoDesktop,
    ]) {
      testWidgetsComApi(
        '${tela.titulo}: modo escuro e letras 130% em ${tamanho.nome}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = tamanho.tamanho;
          addTearDown(tester.view.reset);
          FiltroGlobal.redefinir();
          await tester.pumpWidget(
            MaterialApp(
              theme: criarTema(escuro: true),
              locale: const Locale('pt', 'BR'),
              supportedLocales: const [Locale('pt', 'BR')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: tela.criar('Admin'),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

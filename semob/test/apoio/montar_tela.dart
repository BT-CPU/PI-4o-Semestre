import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semob/cores.dart';
import 'package:semob/servicos/filtro_global.dart';
import 'package:semob/servicos/sessao.dart';
import 'package:semob/telas/tela_faixas.dart';
import 'package:semob/telas/tela_financeiro.dart';
import 'package:semob/telas/tela_linhas.dart';
import 'package:semob/telas/tela_ocorrencias.dart';
import 'package:semob/telas/tela_passageiros.dart';
import 'package:semob/telas/tela_quilometragem.dart';
import 'package:semob/telas/tela_viagens.dart';
import 'package:semob/telas/tela_visao_geral.dart';

// Funções de apoio para os testes de tela.
// Este arquivo NÃO termina em "_test", então o "flutter test" não o executa
// sozinho: ele só é importado pelos arquivos de teste.

// ------------------------------------------------------------
// Tamanhos de janela usados nos testes (largura x altura, em pixels lógicos)
// ------------------------------------------------------------
class TamanhoDeTela {
  final String nome;
  final Size tamanho;

  const TamanhoDeTela(this.nome, this.tamanho);
}

const tamanhoCelularPequeno = TamanhoDeTela('celular pequeno 320x640', Size(320, 640));
const tamanhoCelular = TamanhoDeTela('celular 360x800', Size(360, 800));
// 600 de largura é o ponto em que a barra superior (AppBarSemob) muda de layout
const tamanhoTablet = TamanhoDeTela('tablet 600x900', Size(600, 900));
const tamanhoDesktop = TamanhoDeTela('desktop 1280x800', Size(1280, 800));

const List<TamanhoDeTela> tamanhosDeTela = [
  tamanhoCelularPequeno,
  tamanhoCelular,
  tamanhoTablet,
  tamanhoDesktop,
];

// ------------------------------------------------------------
// As 8 telas do dashboard: título (o mesmo da barra superior) e como criar
// ------------------------------------------------------------
class TelaDoDashboard {
  final String titulo;
  final Widget Function(String nomeUsuario) criar;

  const TelaDoDashboard(this.titulo, this.criar);
}

final List<TelaDoDashboard> telasDoDashboard = [
  TelaDoDashboard('Visão geral', (nome) => TelaVisaoGeral(nomeUsuario: nome)),
  TelaDoDashboard('Viagens e cumprimento', (nome) => TelaViagens(nomeUsuario: nome)),
  TelaDoDashboard('Quilometragem', (nome) => TelaQuilometragem(nomeUsuario: nome)),
  TelaDoDashboard('Passageiros', (nome) => TelaPassageiros(nomeUsuario: nome)),
  TelaDoDashboard('Financeiro', (nome) => TelaFinanceiro(nomeUsuario: nome)),
  TelaDoDashboard('Linhas', (nome) => TelaLinhas(nomeUsuario: nome)),
  TelaDoDashboard('Faixas horárias', (nome) => TelaFaixas(nomeUsuario: nome)),
  TelaDoDashboard('Ocorrências', (nome) => TelaOcorrencias(nomeUsuario: nome)),
];

// ------------------------------------------------------------
// Monta uma tela dentro de um MaterialApp igual ao do main.dart
// (português do Brasil, mesmo tema) e espera os dados carregarem.
//
// Também deixa o estado global limpo: FiltroGlobal e Sessao são estáticos,
// então sem isso um teste mudaria o resultado do próximo.
// ------------------------------------------------------------
Future<void> montarTela(
  WidgetTester tester,
  Widget tela, {
  TamanhoDeTela tamanho = tamanhoDesktop,
}) async {
  FiltroGlobal.redefinir();
  Sessao.usuarioAtual = null;

  // Com devicePixelRatio 1, pixel físico = pixel lógico (o tamanho é o da lista acima)
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = tamanho.tamanho;

  // Ao fim do teste: volta o tamanho da janela e limpa o estado global
  addTearDown(tester.view.reset);
  addTearDown(FiltroGlobal.redefinir);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.azulMedio),
        scaffoldBackgroundColor: Cores.fundo,
      ),
      home: tela,
    ),
  );

  // As telas chamam o DadosServico (falso, devolve na hora) e trocam o
  // indicador de carregamento pelo conteúdo. Espera isso terminar.
  await tester.pumpAndSettle();
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semob/models/periodo.dart';
import 'package:semob/servicos/filtro_global.dart';
import 'package:semob/widgets/filtro_periodo.dart';

import 'apoio/montar_tela.dart';

// Testes de widget das 8 telas do dashboard, no tamanho de desktop.
// Cada tela é aberta com os dados de exemplo de agosto/2026 (período padrão:
// mês inteiro, até 31/08). Os testes de tamanhos de tela menores (celular)
// ficam em outro arquivo (responsividade_test.dart).

// Textos que aparecem no conteúdo de cada tela (conferidos no código das telas).
// Servem para provar que a tela desenhou os cartões, os gráficos e as tabelas,
// e não só a barra superior.
const Map<String, List<String>> _conteudoDasTelas = {
  'Visão geral': ['Alertas do período'],
  'Viagens e cumprimento': ['Resumo por faixa do dia', 'Detalhe diário'],
  'Quilometragem': ['Detalhe diário'],
  'Passageiros': ['Composição dos passageiros', 'Detalhe diário'],
  'Financeiro': ['Acumulado no período', 'Detalhe diário'],
  'Linhas': ['Desempenho por linha'],
  'Faixas horárias': ['Mapa de calor', 'Oferta por faixa do dia'],
  'Ocorrências': ['Conferência com o Resumo Geral', 'Detalhe das ocorrências'],
};

// Rótulo de um botão do filtro (Dia, Semana, Quinzena, Mês).
// Procura só dentro do SegmentedButton, porque "Dia" também é título de
// coluna nas tabelas.
Finder _botaoDoFiltro(String rotulo) {
  return find.descendant(
    of: find.byType(SegmentedButton<TipoPeriodo>),
    matching: find.text(rotulo),
  );
}

// Título da tela na barra superior
Finder _tituloNaBarra(String titulo) {
  return find.descendant(of: find.byType(AppBar), matching: find.text(titulo));
}

void main() {
  for (final tela in telasDoDashboard) {
    group('Tela ${tela.titulo}', () {
      testWidgets('abre, carrega os dados e mostra título, aviso, filtro e conteúdo', (tester) async {
        await montarTela(tester, tela.criar('teste'));

        // O indicador de carregamento saiu e o título está na barra superior
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(_tituloNaBarra(tela.titulo), findsOneWidget);

        // Aviso de dados de exemplo e filtro de período (iguais em todas as telas)
        expect(find.byType(AvisoDadosExemplo), findsOneWidget);
        for (final rotulo in ['Dia', 'Semana', 'Quinzena', 'Mês']) {
          expect(_botaoDoFiltro(rotulo), findsOneWidget, reason: 'botão $rotulo');
        }

        // Período padrão: mês de agosto, até o último dia com dados.
        // O mês não tem período anterior nos dados.
        expect(find.text('Data: 31/08/2026'), findsOneWidget);
        expect(
          find.text('Sem período anterior nos dados para comparação.'),
          findsOneWidget,
        );

        // Conteúdo próprio da tela
        for (final texto in _conteudoDasTelas[tela.titulo]!) {
          expect(find.textContaining(texto), findsWidgets, reason: 'texto "$texto"');
        }

        // Nenhum erro de layout (overflow) ou exceção durante a montagem
        expect(tester.takeException(), isNull);
      });

      testWidgets('escolher Semana atualiza o filtro global e a comparação', (tester) async {
        await montarTela(tester, tela.criar('teste'));

        await tester.tap(_botaoDoFiltro('Semana'));
        await tester.pumpAndSettle();

        // O filtro vale para todas as telas, então fica guardado no FiltroGlobal
        expect(FiltroGlobal.tipo, TipoPeriodo.semana);

        // A semana de 25 a 31/08 é comparada com 18 a 24/08 (há dados)
        expect(find.textContaining('Comparado com:'), findsOneWidget);
        expect(
          find.text('Sem período anterior nos dados para comparação.'),
          findsNothing,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('percorre Dia, Semana, Quinzena e Mês sem erro', (tester) async {
        await montarTela(tester, tela.criar('teste'));

        // Períodos curtos têm menos dados (às vezes uma lista vazia ou uma
        // divisão por zero), por isso testamos todos.
        for (final rotulo in ['Dia', 'Semana', 'Quinzena', 'Mês']) {
          await tester.tap(_botaoDoFiltro(rotulo));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'período $rotulo');
          expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'período $rotulo');
          expect(_tituloNaBarra(tela.titulo), findsOneWidget, reason: 'período $rotulo');
        }

        // O último botão tocado foi "Mês"
        expect(FiltroGlobal.tipo, TipoPeriodo.mes);
      });
    });
  }
}
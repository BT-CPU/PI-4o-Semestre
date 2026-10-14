import 'package:flutter_test/flutter_test.dart';

import 'package:semob/dados/dados_exemplo.dart';
import 'package:semob/models/desempenho_linha.dart';
import 'package:semob/models/periodo.dart';
import 'package:semob/models/resumo_periodo.dart';
import 'package:semob/servicos/dados_servico.dart';

// Estes testes guardam as conferências que fizemos entre os relatórios da
// Smart Data. Quando o back end real existir, vale rodar o mesmo tipo de
// teste sobre os dados do banco: se algum falhar, o relatório foi lido errado.
void main() {
  final mes = ResumoPeriodo.dosDias(diasDeExemplo);

  group('Totais de agosto/2026 batem com os relatórios', () {
    test('viagens e FCV', () {
      expect(mes.viagensProgramadas, 35050);
      expect(mes.viagensRealizadas, 34994);
      expect(mes.viagensNaoRealizadas, 56);
      expect(mes.fcv, closeTo(99.84, 0.01));
    });

    test('quilometragem', () {
      expect(mes.kmProdutivo, closeTo(261886.8, 0.05));
      expect(mes.kmImprodutivo, closeTo(13807.7, 0.05));
      expect(mes.kmTotal, closeTo(275694.5, 0.05));
      expect(mes.kmProdutivoPorViagem, closeTo(7.4838, 0.001));
    });

    test('passageiros', () {
      expect(mes.passageirosCatraca, 228430);
      expect(mes.passageirosAntecipados, 59948);
      expect(mes.passageirosNaoPagantes, 761870);
      expect(mes.passageirosTotal, 1050248);
      expect(mes.percentualNaoPagantes, closeTo(72.54, 0.01));
      expect(mes.passageirosPorKm, closeTo(3.81, 0.01));
    });

    test('financeiro', () {
      expect(mes.vendas, closeTo(668605.71, 0.01));
      expect(mes.utilizacao, closeTo(299740.0, 0.01));
      expect(mes.creditoCirculante, closeTo(368865.71, 0.01));
      expect(mes.creditosTransferidos, closeTo(676230.71, 0.01));
      expect(mes.saldoInicial, closeTo(20439472.35, 0.01));
      expect(mes.saldoFinal, closeTo(19763241.64, 0.01));
      expect(mes.maiorVenda, 138950.0);
      expect(mes.diaMaiorVenda, DateTime(2026, 8, 25));
    });

    test('veículos', () {
      expect(mes.veiculosMedia, closeTo(45.29, 0.01));
      expect(mes.veiculosMaximo, 53);
      expect(mes.maxVeiculosFaixa, 48);
    });
  });

  group('Os relatórios são coerentes entre si, dia a dia', () {
    test('ocorrências = viagens programadas - realizadas', () {
      expect(ocorrenciasDeExemplo.length, 56);
      for (final dia in diasDeExemplo) {
        final doDia = ocorrenciasDeExemplo.where((o) => o.data == dia.data).length;
        expect(doDia, dia.viagensNaoRealizadas, reason: 'dia ${dia.data}');
      }
    });

    test('manhã + tarde + noite = programadas e realizadas', () {
      for (final dia in diasDeExemplo) {
        expect(
          dia.manhaProgramadas + dia.tardeProgramadas + dia.noiteProgramadas,
          dia.viagensProgramadas,
          reason: 'programadas, dia ${dia.data}',
        );
        expect(
          dia.manhaRealizadas + dia.tardeRealizadas + dia.noiteRealizadas,
          dia.viagensRealizadas,
          reason: 'realizadas, dia ${dia.data}',
        );
      }
    });

    test('km e viagens por linha somam o total do dia', () {
      for (final dia in diasDeExemplo) {
        final dasLinhas = kmLinhasDeExemplo.where((k) => k.data == dia.data);
        var km = 0.0;
        var viagens = 0;
        for (final k in dasLinhas) {
          km += k.kmProdutivo;
          viagens += k.viagens;
        }
        expect(km, closeTo(dia.kmProdutivo, 0.2), reason: 'km, dia ${dia.data}');
        expect(viagens, dia.viagensRealizadas, reason: 'viagens, dia ${dia.data}');
      }
    });

    test('faixas horárias (por linha e do sistema) somam as viagens do dia', () {
      for (final dia in diasDeExemplo) {
        var porLinha = 0;
        for (final f in faixasLinhaDeExemplo) {
          if (f.data == dia.data) porLinha += f.viagens;
        }
        var doSistema = 0;
        var maxVeiculos = 0;
        for (final f in faixasSistemaDeExemplo) {
          if (f.data != dia.data) continue;
          doSistema += f.viagens;
          if (f.veiculos > maxVeiculos) maxVeiculos = f.veiculos;
        }
        expect(porLinha, dia.viagensRealizadas, reason: 'por linha, dia ${dia.data}');
        expect(doSistema, dia.viagensRealizadas, reason: 'sistema, dia ${dia.data}');
        // nrMaxVeicFx do Resumo Geral = maior nº de veículos em uma hora
        expect(maxVeiculos, dia.maxVeiculosFaixa, reason: 'veículos, dia ${dia.data}');
      }
    });

    test('saldo do sistema = saldo do dia anterior - créditos transferidos', () {
      for (var i = 1; i < diasDeExemplo.length; i++) {
        final ontem = diasDeExemplo[i - 1];
        final hoje = diasDeExemplo[i];
        expect(
          hoje.saldoSistema,
          closeTo(ontem.saldoSistema - hoje.creditosTransferidos, 0.01),
          reason: 'dia ${hoje.data}',
        );
      }
    });
  });

  group('FCV por linha', () {
    test('as linhas somam os totais do sistema', () {
      final mapa = DesempenhoLinha.calcular(kmLinhasDeExemplo, ocorrenciasDeExemplo);
      var programadas = 0;
      var realizadas = 0;
      var ocorrencias = 0;
      for (final l in mapa.values) {
        programadas += l.viagensProgramadas;
        realizadas += l.viagensRealizadas;
        ocorrencias += l.ocorrencias;
      }
      expect(mapa.length, 9);
      expect(programadas, 35050);
      expect(realizadas, 34994);
      expect(ocorrencias, 56);
    });

    test('linha 10', () {
      final mapa = DesempenhoLinha.calcular(kmLinhasDeExemplo, ocorrenciasDeExemplo);
      final l10 = mapa['10']!;
      expect(l10.viagensRealizadas, 3419);
      expect(l10.ocorrencias, 13);
      expect(l10.fcv, closeTo(99.62, 0.01));
    });
  });

  group('Carregamento de um período (DadosServico)', () {
    test('semana de 31/08 é comparada com 18 a 24/08', () async {
      final dados = await DadosServico.carregarPeriodo(TipoPeriodo.semana, DateTime(2026, 8, 31));
      expect(dados.janela.quantidadeDias, 7);
      expect(dados.janelaAnterior, isNotNull);
      expect(dados.resumo.passageirosTotal, 256959);
      expect(dados.resumoAnterior!.passageirosTotal, 256151);
      expect(dados.ocorrencias.length, 9);
      expect(dados.ocorrenciasAnterior.length, 6);
    });

    test('dia 31/08 é comparado com 24/08', () async {
      final dados = await DadosServico.carregarPeriodo(TipoPeriodo.dia, DateTime(2026, 8, 31));
      expect(dados.resumo.passageirosTotal, 43710);
      expect(dados.resumoAnterior!.passageirosTotal, 43967);
      // Os gráficos mostram pelo menos 7 dias, mesmo no período "dia"
      expect(dados.diasGrafico.length, 7);
    });

    test('o mês inteiro não tem período anterior nos dados', () async {
      final dados = await DadosServico.carregarPeriodo(TipoPeriodo.mes, DateTime(2026, 8, 31));
      expect(dados.janelaAnterior, isNull);
      expect(dados.resumoAnterior, isNull);
      expect(dados.dias.length, 31);
    });

    test('a janela é cortada no começo dos dados', () async {
      final dados = await DadosServico.carregarPeriodo(TipoPeriodo.semana, DateTime(2026, 8, 3));
      expect(dados.janela.inicio, DateTime(2026, 8, 1));
      expect(dados.janela.quantidadeDias, 3);
      expect(dados.janelaAnterior, isNull);
    });
  });
}

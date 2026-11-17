import 'package:flutter_test/flutter_test.dart';

import 'package:semob/models/dia_operacao.dart';
import 'package:semob/models/periodo.dart';
import 'package:semob/servicos/api_cliente.dart';
import 'package:semob/servicos/dados_servico.dart';
import 'package:semob/servicos/fonte_dados.dart';
import 'package:semob/servicos/fonte_dados_api.dart';

// Testes de como o app lê o que a API devolve (FonteDadosApi) e de como o
// DadosServico se comporta quando a API falha. A "API" aqui é uma função que
// devolve respostas prontas, então não precisa de servidor.

Map<String, dynamic> _disponibilidade({
  String minima = '2026-08-01',
  String maxima = '2026-08-31',
  String? passageirosDesde,
  String? saldoDesde,
}) {
  return {
    'temDados': true,
    'dataMinima': minima,
    'dataMaxima': maxima,
    'atualizadoEm': '2026-09-04T08:00:00',
    'passageirosDesde': passageirosDesde,
    'saldoDesde': saldoDesde,
  };
}

// Um dia no formato da API (números inteiros nos campos decimais: o JSON
// escreve 100.0 como 100 em alguns casos, e o app precisa aceitar os dois)
Map<String, dynamic> _diaJson(String data) {
  return {
    'data': data, 'veiculos': 51, 'maxVeiculosFaixa': 47,
    'viagensProgramadas': 1280, 'viagensRealizadas': 1278,
    'manhaProgramadas': 494, 'manhaRealizadas': 492,
    'tardeProgramadas': 438, 'tardeRealizadas': 438,
    'noiteProgramadas': 348, 'noiteRealizadas': 348,
    'kmProdutivo': 9560, 'kmImprodutivo': 490.4,
    'passageirosCatraca': 8861, 'passageirosAntecipados': 2530, 'passageirosNaoPagantes': 33467,
    'vendas': 61092.0, 'utilizacao': 12650, 'creditosTransferidos': 60122.0,
    'saldoSistema': 20270393.81,
  };
}

Map<String, dynamic> _periodoJson({List<Map<String, dynamic>>? dias, List<Map<String, dynamic>>? ocorrencias}) {
  return {
    'dias': dias ?? [_diaJson('2026-08-31')],
    'diasAnteriores': <Map<String, dynamic>>[],
    'diasGrafico': dias ?? [_diaJson('2026-08-31')],
    'ocorrencias': ocorrencias ?? <Map<String, dynamic>>[],
    'ocorrenciasAnteriores': <Map<String, dynamic>>[],
    'kmLinhas': [
      {'data': '2026-08-31', 'linha': '01', 'kmProdutivo': 808, 'viagens': 122},
    ],
    'kmLinhasAnteriores': <Map<String, dynamic>>[],
    'faixasLinha': [
      {'data': '2026-08-31', 'linha': '01', 'hora': 4, 'veiculos': 2, 'viagens': 3},
    ],
    'faixasSistema': [
      {'data': '2026-08-31', 'hora': 0, 'veiculos': 5, 'viagens': 7},
    ],
  };
}

void main() {
  group('FonteDadosApi.inicializar', () {
    test('servidor sem dados', () async {
      final fonte = FonteDadosApi(
        requisitar: (m, c) async => RespostaApi(200, {'temDados': false}),
      );
      await fonte.inicializar();
      expect(fonte.temDados, isFalse);
      expect(fonte.dataMinima, equals(fonte.dataMaxima));
      expect(fonte.textoAviso.contains('Ainda não há dados'), isTrue);
    });

    test('servidor com dados: datas e texto do aviso', () async {
      final caminhos = <String>[];
      final fonte = FonteDadosApi(
        requisitar: (m, c) async {
          caminhos.add('$m $c');
          return RespostaApi(
            200,
            _disponibilidade(minima: '2026-07-01', maxima: '2026-08-31', passageirosDesde: '2026-07-15'),
          );
        },
      );
      await fonte.inicializar();

      expect(caminhos, equals(['GET /dados/disponibilidade']));
      expect(fonte.temDados, isTrue);
      expect(fonte.dataMinima, equals(DateTime(2026, 7, 1)));
      expect(fonte.dataMaxima, equals(DateTime(2026, 8, 31)));
      final aviso = fonte.textoAviso;
      expect(aviso.contains('01/07/2026 a 31/08/2026'), isTrue);
      expect(aviso.contains('gerado em 04/09/2026 08:00'), isTrue);
      expect(aviso.contains('Passageiros disponíveis a partir de 15/07/2026'), isTrue);
      expect(aviso.contains('Saldo do sistema'), isFalse); // não informado
    });

    test('passageiros desde o primeiro dia: não precisa avisar', () async {
      final fonte = FonteDadosApi(
        requisitar: (m, c) async => RespostaApi(200, _disponibilidade(passageirosDesde: '2026-08-01')),
      );
      await fonte.inicializar();
      expect(fonte.textoAviso.contains('Passageiros disponíveis'), isFalse);
    });

    test('erro da API vira ErroApi com a mensagem do servidor', () async {
      final fonte = FonteDadosApi(
        requisitar: (m, c) async => RespostaApi(401, {'detail': 'Sessão inválida ou expirada. Entre novamente.'}),
      );
      ErroApi? erro;
      try {
        await fonte.inicializar();
      } on ErroApi catch (e) {
        erro = e;
      }
      expect(erro, isNotNull);
      expect(erro!.mensagem, equals('Sessão inválida ou expirada. Entre novamente.'));
    });

    test('resposta em formato inesperado vira ErroApi', () async {
      final fonte = FonteDadosApi(requisitar: (m, c) async => RespostaApi(200, ['lixo']));
      ErroApi? erro;
      try {
        await fonte.inicializar();
      } on ErroApi catch (e) {
        erro = e;
      }
      expect(erro, isNotNull);
    });
  });

  group('FonteDadosApi.buscar', () {
    final janela = JanelaDatas(DateTime(2026, 8, 25), DateTime(2026, 8, 31));

    test('monta o pedido com o período, a comparação e o início dos gráficos', () async {
      Uri? pedido;
      final fonte = FonteDadosApi(
        requisitar: (m, c) async {
          pedido = Uri.parse(c);
          return RespostaApi(200, _periodoJson());
        },
      );
      await fonte.buscar(
        janela: janela,
        anterior: JanelaDatas(DateTime(2026, 8, 18), DateTime(2026, 8, 24)),
        inicioGrafico: DateTime(2026, 8, 25),
      );
      expect(pedido!.path, equals('/dados/periodo'));
      expect(pedido!.queryParameters['inicio'], equals('2026-08-25'));
      expect(pedido!.queryParameters['fim'], equals('2026-08-31'));
      expect(pedido!.queryParameters['grafico_inicio'], equals('2026-08-25'));
      expect(pedido!.queryParameters['anterior_inicio'], equals('2026-08-18'));
      expect(pedido!.queryParameters['anterior_fim'], equals('2026-08-24'));
    });

    test('sem comparação, não manda os parâmetros do período anterior', () async {
      Uri? pedido;
      final fonte = FonteDadosApi(
        requisitar: (m, c) async {
          pedido = Uri.parse(c);
          return RespostaApi(200, _periodoJson());
        },
      );
      await fonte.buscar(janela: janela, inicioGrafico: DateTime(2026, 8, 25));
      expect(pedido!.queryParameters.containsKey('anterior_inicio'), isFalse);
      expect(pedido!.queryParameters.containsKey('anterior_fim'), isFalse);
    });

    test('converte o JSON nas classes do app', () async {
      final ocorrencias = [
        {
          'data': '2026-08-02', 'linha': '10', 'tipo': 'naoIniciada',
          'atendimento': 'OSWALDO CRUZ SENTIDO ESTAÇÃO', 'prefixo': '1444', 'motorista': 'M-3fa9c1d2',
          'sentido': 'I', 'tabela': '1B',
          'inicioProgramado': '2026-08-02T14:35:00', 'inicioRealizado': null,
          'fimProgramado': '2026-08-02T15:00:00', 'fimRealizado': '2026-08-02T14:54:52',
        },
      ];
      final fonte = FonteDadosApi(
        requisitar: (m, c) async => RespostaApi(200, _periodoJson(ocorrencias: ocorrencias)),
      );
      final dados = await fonte.buscar(janela: janela, inicioGrafico: DateTime(2026, 8, 25));

      final d = dados.dias.single;
      expect(d.data, equals(DateTime(2026, 8, 31)));
      expect(d.kmProdutivo, equals(9560.0)); // veio como inteiro no JSON
      expect(d.kmImprodutivo, equals(490.4));
      expect(d.utilizacao, equals(12650.0));
      expect(d.passageirosTotal, equals(8861 + 2530 + 33467));
      expect(d.saldoSistema, equals(20270393.81));

      final o = dados.ocorrencias.single;
      expect(o.tipo, equals(TipoOcorrencia.naoIniciada));
      expect(o.motorista, equals('M-3fa9c1d2'));
      expect(o.inicioProgramado, equals(DateTime(2026, 8, 2, 14, 35)));
      expect(o.inicioRealizado, isNull);
      expect(o.fimRealizado, equals(DateTime(2026, 8, 2, 14, 54, 52)));

      expect(dados.kmLinhas.single.kmProdutivo, equals(808.0));
      expect(dados.faixasLinha.single.hora, equals(4));
      expect(dados.faixasSistema.single.hora, equals(0)); // hora 0 = madrugada
    });

    test('tipo de ocorrência desconhecido vira ErroApi (não quebra o app)', () async {
      final ruim = [
        {'data': '2026-08-02', 'linha': '10', 'tipo': 'inventado', 'atendimento': '', 'prefixo': '',
         'motorista': '', 'sentido': 'I', 'tabela': '1A',
         'inicioProgramado': null, 'inicioRealizado': null, 'fimProgramado': null, 'fimRealizado': null},
      ];
      final fonte = FonteDadosApi(requisitar: (m, c) async => RespostaApi(200, _periodoJson(ocorrencias: ruim)));
      ErroApi? erro;
      try {
        await fonte.buscar(janela: janela, inicioGrafico: DateTime(2026, 8, 25));
      } on ErroApi catch (e) {
        erro = e;
      }
      expect(erro, isNotNull);
    });
  });

  group('DadosServico com a fonte da API', () {
    test('período anterior só é pedido se estiver dentro dos dados', () async {
      final pedidos = <Uri>[];
      DadosServico.fonte = FonteDadosApi(
        requisitar: (m, c) async {
          if (c == '/dados/disponibilidade') return RespostaApi(200, _disponibilidade());
          pedidos.add(Uri.parse(c));
          return RespostaApi(200, _periodoJson());
        },
      );
      try {
        await DadosServico.inicializar();
        await DadosServico.carregarPeriodo(TipoPeriodo.semana, DateTime(2026, 8, 31));
        await DadosServico.carregarPeriodo(TipoPeriodo.mes, DateTime(2026, 8, 31));

        // semana: 25 a 31/08, comparada com 18 a 24/08 (que tem dados)
        expect(pedidos[0].queryParameters['anterior_inicio'], equals('2026-08-18'));
        // mês de agosto: o mês anterior (julho) está fora dos dados
        expect(pedidos[1].queryParameters.containsKey('anterior_inicio'), isFalse);
        expect(pedidos[1].queryParameters['inicio'], equals('2026-08-01'));
      } finally {
        DadosServico.fonte = FonteDadosExemplo();
      }
    });

    test('se a API falha, avisa e devolve um período vazio em vez de travar a tela', () async {
      final mensagens = <String>[];
      DadosServico.aoFalhar = mensagens.add;
      DadosServico.fonte = FonteDadosApi(
        requisitar: (m, c) async {
          if (c == '/dados/disponibilidade') return RespostaApi(200, _disponibilidade());
          return RespostaApi(401, {'detail': 'Sessão inválida ou expirada. Entre novamente.'});
        },
      );
      try {
        await DadosServico.inicializar();
        final dados = await DadosServico.carregarPeriodo(TipoPeriodo.dia, DateTime(2026, 8, 31));

        expect(mensagens, equals(['Sessão inválida ou expirada. Entre novamente.']));
        expect(dados.dias, isEmpty);
        expect(dados.resumo.viagensProgramadas, equals(0));
        expect(dados.janela.inicio, equals(DateTime(2026, 8, 31)));
      } finally {
        DadosServico.fonte = FonteDadosExemplo();
        DadosServico.aoFalhar = null;
      }
    });

    test('a fonte padrão é a de exemplo (é o que os testes de tela usam)', () {
      expect(DadosServico.fonte, isA<FonteDadosExemplo>());
      expect(DadosServico.temDados, isTrue);
    });
  });
}

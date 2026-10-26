import 'package:flutter_test/flutter_test.dart';

import 'package:semob/servicos/api_cliente.dart';


void main() {
  group('RespostaApi.ok', () {
    test('códigos 2xx são sucesso', () {
      for (final status in [200, 201, 204, 299]) {
        expect(RespostaApi(status, null).ok, isTrue, reason: 'código $status');
      }
    });

    test('outros códigos não são sucesso', () {
      for (final status in [199, 300, 400, 401, 403, 404, 422, 500]) {
        expect(RespostaApi(status, null).ok, isFalse, reason: 'código $status');
      }
    });
  });

  group('RespostaApi.mensagemErro', () {
    test('usa o campo detail quando ele é um texto', () {
      final resposta = RespostaApi(401, {'detail': 'Usuário ou senha incorretos.'});
      expect(resposta.mensagemErro, 'Usuário ou senha incorretos.');
    });

    test('detail em texto tem prioridade mesmo no código 422', () {
      final resposta = RespostaApi(422, {'detail': 'Texto vindo da API'});
      expect(resposta.mensagemErro, 'Texto vindo da API');
    });

    test('422 com detail em lista (formato padrão de validação) vira mensagem fixa', () {
      final resposta = RespostaApi(422, {
        'detail': [
          {'msg': 'Field required'},
        ],
      });
      expect(resposta.mensagemErro, 'Dados inválidos. Confira os campos.');
    });

    test('422 sem corpo vira mensagem fixa', () {
      expect(
        RespostaApi(422, null).mensagemErro,
        'Dados inválidos. Confira os campos.',
      );
    });

    test('outros códigos sem detail em texto mostram o código do erro', () {
      expect(
        RespostaApi(500, null).mensagemErro,
        'Erro inesperado na API (código 500).',
      );
      // corpo que não é um objeto JSON (aqui, uma lista)
      expect(
        RespostaApi(400, ['qualquer coisa']).mensagemErro,
        'Erro inesperado na API (código 400).',
      );
    });
  });

  group('ErroApi', () {
    test('toString devolve a mensagem, para poder ser mostrada na tela', () {
      expect(ErroApi('Sem conexão').toString(), 'Sem conexão');
    });
  });
}
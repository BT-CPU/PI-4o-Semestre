import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob/main.dart';
import 'package:semob/models/usuario.dart';
import 'package:semob/servicos/api_cliente.dart';
import 'package:semob/servicos/sessao.dart';
import 'package:semob/servicos/usuario_servico.dart';
import 'package:semob/telas/tela_login.dart';

import 'apoio/api_simulada.dart';

void main() {
  setUp(Sessao.sair);
  tearDown(Sessao.sair);

  test(
    'login sempre envia as credenciais à API e guarda o token recebido',
    () async {
      var chamadas = 0;
      Sessao.token = 'token-anterior';
      await http.runWithClient(
        () async {
          final usuario = await UsuarioServico.autenticar(
            'usuario-do-servidor',
            'senha-informada',
          );
          expect(usuario?.id, 'id-do-servidor');
          expect(usuario?.usuario, 'usuario-do-servidor');
          expect(Sessao.token, 'token-retornado-pela-api');
        },
        () => MockClient((requisicao) async {
          chamadas++;
          expect(requisicao.method, 'POST');
          expect(requisicao.url.path, '/login');
          expect(requisicao.headers['Authorization'], isNull);
          expect(jsonDecode(requisicao.body), {
            'usuario': 'usuario-do-servidor',
            'senha': 'senha-informada',
          });
          return http.Response(
            jsonEncode({
              'token': 'token-retornado-pela-api',
              'usuario': {
                ...usuarioApiDeTeste,
                'id': 'id-do-servidor',
                'usuario': 'usuario-do-servidor',
              },
            }),
            200,
          );
        }),
      );
      expect(chamadas, 1);
    },
  );

  test(
    'as antigas credenciais fixas não contornam uma recusa da API',
    () async {
      var chamadas = 0;
      Sessao.usuarioAtual = Usuario.doJson(usuarioApiDeTeste);
      Sessao.token = 'token-antigo';
      await http.runWithClient(
        () async {
          expect(await UsuarioServico.autenticar('admin', 'admin123'), isNull);
          expect(Sessao.usuarioAtual, isNull);
          expect(Sessao.token, isNull);
        },
        () => MockClient((_) async {
          chamadas++;
          return http.Response('', 401);
        }),
      );
      expect(chamadas, 1);
    },
  );

  test(
    'API indisponível impede autenticação e limpa a sessão anterior',
    () async {
      Sessao.usuarioAtual = Usuario.doJson(usuarioApiDeTeste);
      Sessao.token = 'token-antigo';
      await http.runWithClient(
        () async {
          await expectLater(
            UsuarioServico.autenticar('admin', senhaDeTeste),
            throwsA(isA<ErroApi>()),
          );
          expect(Sessao.usuarioAtual, isNull);
          expect(Sessao.token, isNull);
        },
        () =>
            MockClient((_) async => throw http.ClientException('Sem conexão')),
      );
    },
  );

  test('a lista de usuários vem da API com o token da sessão', () async {
    Sessao.token = 'token-valido';
    await http.runWithClient(
      () async {
        final usuarios = await UsuarioServico.listar();
        expect(usuarios.single.id, 'outro-id');
      },
      () => MockClient((requisicao) async {
        expect(requisicao.method, 'GET');
        expect(requisicao.url.path, '/usuarios');
        expect(requisicao.headers['Authorization'], 'Bearer token-valido');
        return http.Response(
          jsonEncode([
            {...usuarioApiDeTeste, 'id': 'outro-id'},
          ]),
          200,
        );
      }),
    );
  });

  test('cadastro, edição e exclusão voltam a ser enviados à API', () async {
    final chamadas = <String>[];
    Sessao.token = 'token-valido';
    final usuario = Usuario.doJson(usuarioApiDeTeste);
    await http.runWithClient(
      () async {
        expect(await UsuarioServico.criar(usuario, senhaDeTeste), isNull);
        expect(await UsuarioServico.atualizar(usuario), isNull);
        expect(await UsuarioServico.excluir(usuario.id), isNull);
      },
      () => MockClient((requisicao) async {
        chamadas.add('${requisicao.method} ${requisicao.url.path}');
        expect(requisicao.headers['Authorization'], 'Bearer token-valido');
        return http.Response('', 204);
      }),
    );
    expect(chamadas, [
      'POST /usuarios',
      'PUT /usuarios/admin-teste',
      'DELETE /usuarios/admin-teste',
    ]);
  });

  testWidgetsComApi('credenciais recusadas mantêm a tela de login aberta', (
    tester,
  ) async {
    await tester.pumpWidget(const MeuApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-incorreta');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.byType(TelaLogin), findsOneWidget);
    expect(find.text('Usuário ou senha incorretos.'), findsOneWidget);
    expect(Sessao.usuarioAtual, isNull);
    expect(Sessao.token, isNull);
  });
}

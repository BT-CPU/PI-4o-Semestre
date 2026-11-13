import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Exclusivo dos testes: o aplicativo sempre depende da API real.
const senhaDeTeste = 'senha-apenas-do-teste';
const usuarioApiDeTeste = <String, dynamic>{
  'id': 'admin-teste',
  'nome': 'Administrador de teste',
  'usuario': 'admin',
  'email': 'admin@example.com',
  'perfil': 'administrador',
};

http.Client criarApiSimulada() => MockClient((requisicao) async {
  final caminho = requisicao.url.path;
  Object corpo;
  if (requisicao.method == 'POST' && caminho == '/login') {
    final credenciais = jsonDecode(requisicao.body) as Map;
    if (credenciais['usuario'] != 'admin' ||
        credenciais['senha'] != senhaDeTeste) {
      return http.Response(
        jsonEncode({'detail': 'Usuário ou senha incorretos.'}),
        401,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    corpo = {'token': 'token-exclusivo-do-teste', 'usuario': usuarioApiDeTeste};
  } else if (requisicao.method == 'GET' && caminho == '/usuarios') {
    expect(
      requisicao.headers['Authorization'],
      'Bearer token-exclusivo-do-teste',
    );
    corpo = [usuarioApiDeTeste];
  } else {
    throw StateError(
      'Requisição inesperada no teste: ${requisicao.method} $caminho',
    );
  }
  return http.Response(
    jsonEncode(corpo),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

void testWidgetsComApi(
  String descricao,
  Future<void> Function(WidgetTester) testar,
) {
  testWidgets(
    descricao,
    (tester) => http.runWithClient(() => testar(tester), criarApiSimulada),
  );
}

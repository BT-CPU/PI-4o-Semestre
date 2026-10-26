import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sessao.dart';

// Endereço da API. Para trocar sem mexer no código:
//   flutter run -d chrome --dart-define=API_URL=http://192.168.0.10:8000
// (No emulador Android, o computador é http://10.0.2.2:8000.)
const String urlApi =
    String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

// Erro de comunicação (API fora do ar, sem rede, tempo esgotado...)
class ErroApi implements Exception {
  final String mensagem;

  ErroApi(this.mensagem);

  @override
  String toString() => mensagem;
}

class RespostaApi {
  final int status;
  final dynamic corpo; // JSON já decodificado (ou null)

  RespostaApi(this.status, this.corpo);

  bool get ok => status >= 200 && status < 300;

  // Mensagem de erro para mostrar ao usuário
  String get mensagemErro {
    final c = corpo;
    if (c is Map && c['detail'] is String) return c['detail'] as String;
    if (status == 422) return 'Dados inválidos. Confira os campos.';
    return 'Erro inesperado na API (código $status).';
  }
}

class ApiCliente {
  static Future<RespostaApi> requisitar(
    String metodo,
    String caminho, {
    Object? corpo,
  }) async {
    final requisicao = http.Request(metodo, Uri.parse('$urlApi$caminho'));
    requisicao.headers['Content-Type'] = 'application/json';
    final token = Sessao.token;
    if (token != null) {
      requisicao.headers['Authorization'] = 'Bearer $token';
    }
    if (corpo != null) {
      requisicao.body = jsonEncode(corpo);
    }

    try {
      final stream = await requisicao.send().timeout(const Duration(seconds: 15));
      final resposta = await http.Response.fromStream(stream);
      // utf8.decode no bodyBytes: sem isso os acentos podem sair errados
      final texto = utf8.decode(resposta.bodyBytes);
      final json = texto.isEmpty ? null : jsonDecode(texto);
      return RespostaApi(resposta.statusCode, json);
    } catch (e) {
      throw ErroApi('Não foi possível falar com o servidor. Tente novamente.');
    }
  }
}

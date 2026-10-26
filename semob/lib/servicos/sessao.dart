import '../models/usuario.dart';
import 'filtro_global.dart';

// Guarda QUEM está logado e o token de acesso devolvido pela API.
// O token fica só na memória: ao fechar o app, é preciso entrar de novo.
// ATENÇÃO: esconder um botão NÃO protege nada. A proteção de verdade
// (quem pode criar usuários, enviar arquivos, ver o motorista) é feita
// na API, que confere o token a cada requisição.
class Sessao {
  static Usuario? usuarioAtual;
  static String? token;

  static bool get ehAdmin => usuarioAtual?.ehAdmin ?? false;

  static void sair() {
    usuarioAtual = null;
    token = null;
    FiltroGlobal.redefinir();
  }
}

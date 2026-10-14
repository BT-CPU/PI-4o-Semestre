import '../models/usuario.dart';
import 'filtro_global.dart';

// Guarda QUEM está logado. TEMPORÁRIO: quando existir back end, aqui entra o
// token de acesso devolvido pela API. Serve para o menu mostrar a opção de
// administração só para administradores.
// ATENÇÃO: esconder um botão NÃO protege nada. A proteção de verdade
// (quem pode criar usuários, enviar arquivos, ver o motorista) tem que ser
// feita no back end.
class Sessao {
  static Usuario? usuarioAtual;

  static bool get ehAdmin => usuarioAtual?.ehAdmin ?? false;

  static void sair() {
    usuarioAtual = null;
    FiltroGlobal.redefinir();
  }
}

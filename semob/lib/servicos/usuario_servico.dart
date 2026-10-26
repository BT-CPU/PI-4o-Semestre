import '../models/usuario.dart';
import 'api_cliente.dart';
import 'sessao.dart';

// Fala com a API (FastAPI + MongoDB). Mesmos métodos de antes, então as
// telas quase não mudam.
//
// criar, atualizar e excluir devolvem:
//   null        -> deu certo
//   uma String  -> mensagem de erro
// listar e autenticar lançam ErroApi se a API não responder.
class UsuarioServico {
  static Future<List<Usuario>> listar() async {
    final r = await ApiCliente.requisitar('GET', '/usuarios');
    if (!r.ok) throw ErroApi(r.mensagemErro);
    return [
      for (final item in r.corpo as List)
        Usuario.doJson(item as Map<String, dynamic>),
    ];
  }

  // Usada pela tela de login. Devolve o usuário (e guarda o token na Sessao)
  // ou null se o usuário/senha estiverem errados.
  static Future<Usuario?> autenticar(String usuario, String senha) async {
    final r = await ApiCliente.requisitar(
      'POST',
      '/login',
      corpo: {'usuario': usuario, 'senha': senha},
    );
    if (r.status == 401) return null;
    if (!r.ok) throw ErroApi(r.mensagemErro);

    final dados = r.corpo as Map<String, dynamic>;
    Sessao.token = dados['token'] as String;
    return Usuario.doJson(dados['usuario'] as Map<String, dynamic>);
  }

  static Map<String, dynamic> _corpo(Usuario u, String? senha) {
    return {
      'nome': u.nome,
      'usuario': u.usuario,
      'email': u.email,
      'perfil': u.ehAdmin ? 'administrador' : 'funcionario',
      'senha': ?senha,
    };
  }

  static Future<String?> _executar(Future<RespostaApi> Function() acao) async {
    try {
      final r = await acao();
      return r.ok ? null : r.mensagemErro;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }

  static Future<String?> criar(Usuario novo, String senha) {
    return _executar(
      () => ApiCliente.requisitar('POST', '/usuarios', corpo: _corpo(novo, senha)),
    );
  }

  // senha null = manter a senha atual
  static Future<String?> atualizar(Usuario atualizado, {String? senha}) {
    return _executar(
      () => ApiCliente.requisitar(
        'PUT',
        '/usuarios/${atualizado.id}',
        corpo: _corpo(atualizado, senha),
      ),
    );
  }

  static Future<String?> excluir(String id) {
    return _executar(() => ApiCliente.requisitar('DELETE', '/usuarios/$id'));
  }
}

import '../models/usuario.dart';

// TEMPORÁRIO: guarda os usuários numa lista na memória.
// Quando fechar o app, tudo volta ao começo.
// Quando o back end em Python estiver pronto, só esta classe muda:
// em vez de mexer na lista, cada método vai chamar a API.
// Por isso os métodos já são "Future" (assíncronos), como serão com a API.
//
// Os métodos de criar, atualizar e excluir devolvem:
//   null        -> deu certo
//   uma String  -> mensagem de erro
class UsuarioServico {
  static final List<Usuario> _usuarios = [
    Usuario(
      id: '1',
      nome: 'Administrador do Sistema',
      usuario: 'admin',
      email: 'admin@semob.local',
      senha: 'admin123',
      ehAdmin: true,
    ),
    Usuario(
      id: '2',
      nome: 'Funcionário de Teste',
      usuario: 'func',
      email: 'func@semob.local',
      senha: '123456',
      ehAdmin: false,
    ),
    Usuario(
      id: '3',
      nome: 'Maria Souza',
      usuario: 'maria',
      email: 'maria@semob.local',
      senha: 'maria123',
      ehAdmin: false,
    ),
    Usuario(
      id: '4',
      nome: 'João Pereira',
      usuario: 'joao',
      email: 'joao@semob.local',
      senha: 'joao123',
      ehAdmin: false,
    ),
  ];

  static Future<List<Usuario>> listar() async {
    // Devolve uma cópia da lista
    return List<Usuario>.from(_usuarios);
  }

  // Usada pela tela de login. Devolve o usuário ou null se estiver errado.
  static Future<Usuario?> autenticar(String usuario, String senha) async {
    for (final u in _usuarios) {
      if (u.usuario == usuario && u.senha == senha) {
        return u;
      }
    }
    return null;
  }

  static int _contarAdmins() {
    return _usuarios.where((u) => u.ehAdmin).length;
  }

  // ignorarId serve para a edição: o próprio usuário não conta como repetido
  static bool _loginJaExiste(String login, {String? ignorarId}) {
    return _usuarios.any(
      (u) =>
          u.usuario.toLowerCase() == login.toLowerCase() && u.id != ignorarId,
    );
  }

  static Future<String?> criar(Usuario novo) async {
    if (_loginJaExiste(novo.usuario)) {
      return 'Já existe um usuário com este login.';
    }
    _usuarios.add(novo);
    return null;
  }

  static Future<String?> atualizar(Usuario atualizado) async {
    final posicao = _usuarios.indexWhere((u) => u.id == atualizado.id);
    if (posicao == -1) {
      return 'Usuário não encontrado.';
    }
    if (_loginJaExiste(atualizado.usuario, ignorarId: atualizado.id)) {
      return 'Já existe um usuário com este login.';
    }
    final antigo = _usuarios[posicao];
    if (antigo.ehAdmin && !atualizado.ehAdmin && _contarAdmins() == 1) {
      return 'O sistema precisa ter pelo menos um administrador.';
    }
    _usuarios[posicao] = atualizado;
    return null;
  }

  static Future<String?> excluir(String id) async {
    final posicao = _usuarios.indexWhere((u) => u.id == id);
    if (posicao == -1) {
      return 'Usuário não encontrado.';
    }
    if (_usuarios[posicao].ehAdmin && _contarAdmins() == 1) {
      return 'Não é possível excluir o único administrador.';
    }
    _usuarios.removeAt(posicao);
    return null;
  }
}

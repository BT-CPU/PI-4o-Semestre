// Representa um usuário do sistema.
// Mais tarde, cada Usuario vai virar um documento no MongoDB.
class Usuario {
  final String id;
  final String nome;
  final String usuario; // login
  final String email;
  final String senha;
  final bool ehAdmin; // true = administrador, false = funcionário

  Usuario({
    required this.id,
    required this.nome,
    required this.usuario,
    required this.email,
    required this.senha,
    required this.ehAdmin,
  });
}

// Representa um usuário do sistema, como a API devolve.
// A senha NÃO fica aqui: ela só é enviada ao criar/editar e nunca volta.
class Usuario {
  final String id;
  final String nome;
  final String usuario; // login
  final String email;
  final bool ehAdmin; // true = administrador, false = funcionário

  Usuario({
    required this.id,
    required this.nome,
    required this.usuario,
    required this.email,
    required this.ehAdmin,
  });

  factory Usuario.doJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nome: json['nome'] as String,
      usuario: json['usuario'] as String,
      email: json['email'] as String,
      ehAdmin: json['perfil'] == 'administrador',
    );
  }
}

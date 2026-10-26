import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/usuario.dart';
import '../servicos/usuario_servico.dart';

// Janelinha (dialog) usada para cadastrar OU editar um usuário.
// Se receber usuarioExistente, está editando; se for null, está criando.
// Fecha devolvendo true quando salvou e false quando cancelou.
class FormularioUsuario extends StatefulWidget {
  final Usuario? usuarioExistente;

  const FormularioUsuario({super.key, this.usuarioExistente});

  @override
  State<FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends State<FormularioUsuario> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _loginController;
  late final TextEditingController _emailController;
  late final TextEditingController _senhaController;

  late bool _ehAdmin;
  bool _esconderSenha = true;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.usuarioExistente != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuarioExistente;
    // Se estiver editando, já começa com os dados do usuário
    _nomeController = TextEditingController(text: u?.nome ?? '');
    _loginController = TextEditingController(text: u?.usuario ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _senhaController = TextEditingController();
    _ehAdmin = u?.ehAdmin ?? false;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _loginController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final antigo = widget.usuarioExistente;
    final senhaDigitada = _senhaController.text;

    final usuario = Usuario(
      id: antigo?.id ?? '', // o id definitivo é gerado pelo MongoDB
      nome: _nomeController.text.trim(),
      usuario: _loginController.text.trim(),
      email: _emailController.text.trim(),
      ehAdmin: _ehAdmin,
    );

    final String? erro;
    if (_editando) {
      // Na edição, senha em branco significa "manter a senha atual"
      erro = await UsuarioServico.atualizar(
        usuario,
        senha: senhaDigitada.isEmpty ? null : senhaDigitada,
      );
    } else {
      erro = await UsuarioServico.criar(usuario, senhaDigitada);
    }

    if (!mounted) return;

    if (erro != null) {
      setState(() {
        _salvando = false;
        _erro = erro;
      });
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        _editando ? 'Editar usuário' : 'Novo usuário',
        style: const TextStyle(
          color: Cores.azulEscuro,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nomeController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Digite o nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loginController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuário (login)',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Digite o usuário';
                    }
                    if (valor.trim().length < 3) {
                      return 'Use pelo menos 3 caracteres';
                    }
                    if (valor.contains(' ')) {
                      return 'Não use espaços';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Digite o e-mail';
                    }
                    if (!valor.contains('@') || !valor.contains('.')) {
                      return 'E-mail inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  obscureText: _esconderSenha,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    helperText: _editando
                        ? 'Deixe em branco para manter a senha atual'
                        : null,
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _esconderSenha
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _esconderSenha = !_esconderSenha;
                        });
                      },
                    ),
                  ),
                  validator: (valor) {
                    final texto = valor ?? '';
                    // Na criação a senha é obrigatória
                    if (texto.isEmpty && !_editando) {
                      return 'Digite a senha';
                    }
                    // Se digitou algo, precisa ter pelo menos 6 caracteres
                    if (texto.isNotEmpty && texto.length < 6) {
                      return 'Use pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Perfil de acesso',
                  style: TextStyle(color: Cores.azulEscuro),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SegmentedButton<bool>(
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Cores.azulMedio,
                    selectedForegroundColor: Colors.white,
                  ),
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Funcionário'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Administrador'),
                      icon: Icon(Icons.admin_panel_settings),
                    ),
                  ],
                  selected: {_ehAdmin},
                  onSelectionChanged: (selecionado) {
                    setState(() {
                      _ehAdmin = selecionado.first;
                    });
                  },
                ),
 ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Cores.erro),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Cores.azulEscuro,
            foregroundColor: Colors.white,
          ),
          onPressed: _salvando ? null : _salvar,
          child: Text(_salvando ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}

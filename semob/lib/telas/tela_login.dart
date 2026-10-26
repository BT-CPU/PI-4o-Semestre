import 'package:flutter/material.dart';

import '../cores.dart';
import '../servicos/sessao.dart';
import '../servicos/usuario_servico.dart';
import '../widgets/logo_semob.dart';
import 'tela_admin.dart';
import 'tela_visao_geral.dart';
import '../models/usuario.dart';
import '../servicos/api_cliente.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  // Chave que identifica o formulário (usada para chamar o validate)
  final _formKey = GlobalKey<FormState>();

  // Controllers guardam o texto digitado em cada campo
  final _usuarioController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _esconderSenha = true;
  bool _carregando = false;
  String? _mensagemErro;

  @override
  void dispose() {
    // Libera a memória dos controllers quando a tela fecha
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar({required bool comoAdmin}) async {
    // Se algum campo estiver inválido, para aqui
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    final usuarioDigitado = _usuarioController.text.trim();
    final senhaDigitada = _senhaController.text;

    // Pergunta à API se o usuário e a senha existem
    Usuario? usuarioEncontrado;
    try {
      usuarioEncontrado = await UsuarioServico.autenticar(
        usuarioDigitado,
        senhaDigitada,
      );
    } on ErroApi catch (e) {
      // API fora do ar, sem rede, tempo esgotado...
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _mensagemErro = e.mensagem;
      });
      return;
    }

    // Depois de um await, é bom conferir se a tela ainda existe
    if (!mounted) return;

    if (usuarioEncontrado == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Usuário ou senha incorretos.';
      });
      return;
    }

    if (comoAdmin && !usuarioEncontrado.ehAdmin) {
      Sessao.token = null; // <- linha nova
      setState(() {
        _carregando = false;
        _mensagemErro = 'Este usuário não tem acesso de administrador.';
      });
      return;
    }

    setState(() {
      _carregando = false;
    });

    // Login certo: guarda quem entrou e vai para a tela correspondente
    Sessao.usuarioAtual = usuarioEncontrado;
    if (comoAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TelaAdmin()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TelaVisaoGeral(nomeUsuario: usuarioDigitado),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // SingleChildScrollView evita erro de overflow em telas pequenas
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            // Limita a largura do cartão (fica bonito no navegador/desktop)
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo da SEMOB
                      const LogoSemob(altura: 170),
                      const SizedBox(height: 8),
                      const Text(
                        'Dashboard de Operação de Transporte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Cores.azulEscuro,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Campo de usuário
                      TextFormField(
                        controller: _usuarioController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return 'Digite o usuário';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo de senha
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _esconderSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          // Botão do olho para mostrar/esconder a senha
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
                          if (valor == null || valor.isEmpty) {
                            return 'Digite a senha';
                          }
                          return null;
                        },
                        // Apertar Enter no teclado também faz o login
                        onFieldSubmitted: (_) => _entrar(comoAdmin: false),
                      ),
                      const SizedBox(height: 16),

                      // Mensagem de erro (só aparece se existir)
                      if (_mensagemErro != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _mensagemErro!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Cores.erro),
                          ),
                        ),

                      // Botão Entrar
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Cores.azulEscuro,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed:
                            _carregando ? null : () => _entrar(comoAdmin: false),
                        child: _carregando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                      const SizedBox(height: 12),

                      // Botão de acesso do administrador
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Cores.azulMedio,
                          side: const BorderSide(color: Cores.azulMedio),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed:
                            _carregando ? null : () => _entrar(comoAdmin: true),
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Acesso do administrador'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

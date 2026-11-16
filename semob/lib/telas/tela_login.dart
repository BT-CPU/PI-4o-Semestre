
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
  final _formKey = GlobalKey<FormState>();

  final _usuarioController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _esconderSenha = true;
  bool _carregando = false;
  String? _mensagemErro;

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar({required bool comoAdmin}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    final usuarioDigitado = _usuarioController.text.trim();
    final senhaDigitada = _senhaController.text;

    Usuario? usuarioEncontrado;

    try {
      usuarioEncontrado = await UsuarioServico.autenticar(
        usuarioDigitado,
        senhaDigitada,
      );
    } on ErroApi catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
        _mensagemErro = e.mensagem;
      });
      return;
    }

    if (!mounted) return;

    if (usuarioEncontrado == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Usuário ou senha incorretos.';
      });
      return;
    }

    if (comoAdmin && !usuarioEncontrado.ehAdmin) {
      Sessao.token = null;

      setState(() {
        _carregando = false;
        _mensagemErro =
            'Este usuário não tem acesso de administrador.';
      });
      return;
    }

    setState(() {
      _carregando = false;
    });

    Sessao.usuarioAtual = usuarioEncontrado;

    if (comoAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const TelaAdmin(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TelaVisaoGeral(
            nomeUsuario: usuarioDigitado,
          ),
        ),
      );
    }
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    Widget? sufixo,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icone,
        color: Cores.azulMedio,
      ),
      suffixIcon: sufixo,
      filled: true,
      fillColor: const Color(0xFFF4F7FA),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE1E8EF),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Cores.azulMedio,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Cores.erro,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Cores.erro,
          width: 1.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF102B46),
              Color(0xFF173E60),
              Color(0xFF0B1D30),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                ),
                child: Card(
                  color: Colors.white,
                  elevation: 18,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 34,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const LogoSemob(altura: 150),

                          const SizedBox(height: 12),

                          const Text(
                            'Dashboard de Operação de Transporte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Cores.azulEscuro,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Acesse sua conta para continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF718096),
                            ),
                          ),

                          const SizedBox(height: 32),

                          const Text(
                            'Usuário',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Cores.azulEscuro,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _usuarioController,
                            textInputAction: TextInputAction.next,
                            decoration: _decoracaoCampo(
                              label: 'Digite seu usuário',
                              icone: Icons.person_outline,
                            ),
                            validator: (valor) {
                              if (valor == null ||
                                  valor.trim().isEmpty) {
                                return 'Digite o usuário';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Senha',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Cores.azulEscuro,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _senhaController,
                            obscureText: _esconderSenha,
                            decoration: _decoracaoCampo(
                              label: 'Digite sua senha',
                              icone: Icons.lock_outline,
                              sufixo: IconButton(
                                tooltip: _esconderSenha
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                icon: Icon(
                                  _esconderSenha
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.blueGrey,
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
                            onFieldSubmitted: (_) =>
                                _entrar(comoAdmin: false),
                          ),

                          const SizedBox(height: 18),

                          if (_mensagemErro != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFFD6D2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Cores.erro,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _mensagemErro!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Cores.erro,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Cores.azulEscuro,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _carregando
                                  ? null
                                  : () => _entrar(comoAdmin: false),
                              child: _carregando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Cores.azulMedio,
                                side: const BorderSide(
                                  color: Cores.azulMedio,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _carregando
                                  ? null
                                  : () => _entrar(comoAdmin: true),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              label: const Text(
                                'Acesso do administrador',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Divider(
                            color: Color(0xFFE8EDF2),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'SEMOB • Sistema de Mobilidade',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
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

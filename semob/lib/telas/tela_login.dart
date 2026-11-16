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
        _mensagemErro = 'Este usuário não tem acesso de administrador.';
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
    final bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildPainelAzul(),
                            ),
                            Expanded(
                              flex: 6,
                              child: _buildFormulario(context),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Painel Azul agora aparece no Mobile empilhado em cima
                            _buildPainelAzul(),
                            _buildFormulario(context),
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

  Widget _buildPainelAzul() {
    return Container(
      padding: const EdgeInsets.all(32),
      color: Cores.azulEscuro,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.directions_bus_rounded,
            size: 48,
            color: Colors.white70,
          ),
          SizedBox(height: 16),
          Text(
            'Gestão e Controle de Transporte',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Acesse o painel operacional para monitoramento em tempo real e gerenciamento de frotas.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: LogoSemob(altura: 100)),
            const SizedBox(height: 16),
            const Text(
              'Dashboard de Operação de Transporte',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Cores.azulEscuro,
              ),
            ),
            const SizedBox(height: 24),

            if (_mensagemErro != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mensagemErro!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            TextFormField(
              controller: _usuarioController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Usuário',
                hintText: 'Digite seu usuário',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Digite o usuário';
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
                hintText: '••••••',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                suffixIcon: IconButton(
                  icon: Icon(
                    _esconderSenha
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey,
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
              onFieldSubmitted: (_) => _entrar(comoAdmin: false),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Cores.azulEscuro,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _carregando ? null : () => _entrar(comoAdmin: false),
              child: _carregando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Cores.azulMedio,
                side: const BorderSide(color: Color(0xFF94A3B8)),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _carregando ? null : () => _entrar(comoAdmin: true),
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
              label: const Text(
                'Acesso do administrador',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
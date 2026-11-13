import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../servicos/api_cliente.dart';
import '../servicos/sessao.dart';
import '../servicos/usuario_servico.dart';
import '../widgets/configuracoes.dart';
import '../widgets/fundo_abstrato.dart';
import '../widgets/logo_semob.dart';
import '../widgets/notificacao.dart';
import 'tela_admin.dart';
import 'tela_visao_geral.dart';

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

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar({required bool comoAdmin}) async {
    if (_carregando || !_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    Usuario? usuario;
    try {
      usuario = await UsuarioServico.autenticar(
        _usuarioController.text.trim(),
        _senhaController.text,
      );
    } on ErroApi catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarNotificacao(context, e.mensagem, ehErro: true);
      return;
    }
    if (!mounted) return;
    setState(() => _carregando = false);
    if (usuario == null) {
      mostrarNotificacao(context, 'Usuário ou senha incorretos.', ehErro: true);
      return;
    }
    if (comoAdmin && !usuario.ehAdmin) {
      Sessao.sair();
      mostrarNotificacao(
        context,
        'Este usuário não tem acesso de administrador.',
        ehErro: true,
      );
      return;
    }
    Sessao.usuarioAtual = usuario;
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => comoAdmin
            ? const TelaAdmin()
            : TelaVisaoGeral(nomeUsuario: usuario!.usuario),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: cores.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 30),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Entre com seu usuário e senha.',
                style: TextStyle(fontSize: 13, color: cores.onSurfaceVariant),
              ),
              const SizedBox(height: 26),
              TextFormField(
                controller: _usuarioController,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Usuário',
                  prefixIcon: const Icon(Icons.person_outline, size: 19),
                  border: borda,
                  enabledBorder: borda,
                  focusedBorder: borda.copyWith(
                    borderSide: BorderSide(color: cores.primary, width: 1.5),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Digite o usuário' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: _esconderSenha,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline, size: 19),
                  border: borda,
                  enabledBorder: borda,
                  focusedBorder: borda.copyWith(
                    borderSide: BorderSide(color: cores.primary, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    tooltip: _esconderSenha ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(
                      _esconderSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _esconderSenha = !_esconderSenha),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Digite a senha' : null,
                onFieldSubmitted: (_) => _entrar(comoAdmin: false),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _carregando ? null : () => _entrar(comoAdmin: false),
                child: _carregando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Autenticando',
                        ),
                      )
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _carregando ? null : () => _entrar(comoAdmin: true),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 17),
                label: const Text('Acesso do administrador'),
              ),
              const SizedBox(height: 14),
              Text(
                'São Caetano do Sul',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cores.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      body: FundoAbstrato(
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, limites) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (limites.maxHeight - 96).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cores.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26082444),
                                  blurRadius: 48,
                                  offset: Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 180,
                                    width: double.infinity,
                                    child: ColoredBox(
                                      color: Colors.white,
                                      child: Center(
                                        child: LogoSemob(altura: 128),
                                      ),
                                    ),
                                  ),
                                  _formulario(context),
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
            ),
            Positioned(
              top: 12,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Configurações',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => abrirConfiguracoes(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

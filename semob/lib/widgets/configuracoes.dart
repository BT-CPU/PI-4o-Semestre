import 'package:flutter/material.dart';

import '../servicos/plataforma.dart' as plataforma;
import '../servicos/preferencias_visuais.dart';
import '../servicos/sessao.dart';
import '../telas/tela_admin.dart';
import '../telas/tela_upload.dart';
import 'notificacao.dart';

Future<void> abrirConfiguracoes(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _Configuracoes(),
);

class _Configuracoes extends StatefulWidget {
  const _Configuracoes();
  @override
  State<_Configuracoes> createState() => _ConfiguracoesState();
}

class _ConfiguracoesState extends State<_Configuracoes> {
  bool _telaCheia = false;
  bool _alterando = false;

  @override
  void initState() {
    super.initState();
    _consultarTelaCheia();
  }

  Future<void> _consultarTelaCheia() async {
    try {
      final cheia = await plataforma.emTelaCheia();
      if (mounted) setState(() => _telaCheia = cheia);
    } catch (_) {
      // Um teste de widget não possui a janela nativa.
    }
  }

  Future<void> _alternarTelaCheia() async {
    setState(() => _alterando = true);
    try {
      final cheia = await plataforma.definirTelaCheia(!_telaCheia);
      if (mounted) setState(() => _telaCheia = cheia);
    } catch (_) {
      if (mounted) {
        mostrarNotificacao(
          context,
          'Não foi possível alterar a tela cheia.',
          ehErro: true,
        );
      }
    } finally {
      if (mounted) setState(() => _alterando = false);
    }
  }

  void _abrirAdmin(Widget tela) {
    if (!Sessao.ehAdmin) return;
    final navegador = Navigator.of(context);
    navegador.pop();
    navegador.push(MaterialPageRoute<void>(builder: (_) => tela));
  }

  Widget _ajuste(
    String titulo,
    double valor,
    VoidCallback diminuir,
    VoidCallback aumentar,
    double minimo,
    double maximo,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(titulo)),
        IconButton(
          tooltip: 'Diminuir $titulo',
          onPressed: valor > minimo ? diminuir : null,
          icon: const Icon(Icons.remove, size: 19),
        ),
        SizedBox(
          width: 50,
          child: Text('${(valor * 100).round()}%', textAlign: TextAlign.center),
        ),
        IconButton(
          tooltip: 'Aumentar $titulo',
          onPressed: valor < maximo ? aumentar : null,
          icon: const Icon(Icons.add, size: 19),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final preferencias = PreferenciasVisuais.instancia;
    return AnimatedBuilder(
      animation: preferencias,
      builder: (context, _) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Configurações',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar configurações',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _ajuste(
                  'Zoom',
                  preferencias.zoom,
                  () => preferencias.ajustarZoom(-.1),
                  () => preferencias.ajustarZoom(.1),
                  .8,
                  1.3,
                ),
                _ajuste(
                  'Letras',
                  preferencias.letras,
                  () => preferencias.ajustarLetras(-.05),
                  () => preferencias.ajustarLetras(.05),
                  .85,
                  1.3,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Modo escuro'),
                  value: preferencias.escuro,
                  onChanged: preferencias.definirEscuro,
                ),
                ListTile(
                  leading: Icon(
                    _telaCheia ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  title: Text(_telaCheia ? 'Sair da tela cheia' : 'Tela cheia'),
                  subtitle: plataforma.suportaTelaCheia
                      ? const Text('Esc para sair')
                      : const Text('Indisponível nesta plataforma'),
                  enabled: plataforma.suportaTelaCheia && !_alterando,
                  onTap: _alternarTelaCheia,
                ),
                if (Sessao.ehAdmin) ...[
                  const Divider(height: 16),
                  ExpansionTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Admin'),
                    children: [
                      ListTile(
                        title: const Text('Administração de Usuários'),
                        leading: const Icon(Icons.manage_accounts_outlined),
                        onTap: () => _abrirAdmin(const TelaAdmin()),
                      ),
                      ListTile(
                        title: const Text('Enviar Arquivo'),
                        leading: const Icon(Icons.upload_file_outlined),
                        onTap: () => _abrirAdmin(const TelaUpload()),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 16),
                TextButton.icon(
                  onPressed: preferencias.restaurar,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restaurar zoom e letras'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

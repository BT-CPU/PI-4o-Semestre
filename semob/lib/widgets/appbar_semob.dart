import 'package:flutter/material.dart';

import '../servicos/sessao.dart';
import '../telas/tela_login.dart';
import 'configuracoes.dart';

class AppBarSemob extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final IconData? icone;
  final List<Widget>? actions;
  final VoidCallback? aoVoltar;

  const AppBarSemob({
    super.key,
    required this.titulo,
    this.icone,
    this.actions,
    this.aoVoltar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 700;
    final cores = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: 72,
      leading: aoVoltar == null
          ? null
          : IconButton(
              tooltip: 'Voltar ao menu',
              icon: const Icon(Icons.arrow_back),
              onPressed: aoVoltar,
            ),
      backgroundColor: cores.surface,
      foregroundColor: cores.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: largo ? 28 : 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: largo ? 21 : 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -.4,
            ),
          ),
          if (largo) ...[
            const SizedBox(height: 3),
            Text(
              'SEMOB · São Caetano do Sul',
              style: TextStyle(fontSize: 11, color: cores.onSurfaceVariant),
            ),
          ],
        ],
      ),
      actions: [
        ...?actions,
        if (Sessao.usuarioAtual != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: largo ? 140 : 52),
                child: Tooltip(
                  message: Sessao.usuarioAtual!.usuario,
                  child: Text(
                    Sessao.usuarioAtual!.usuario,
                    key: const ValueKey('usuario-na-barra'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: cores.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Configurações',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => abrirConfiguracoes(context),
        ),
        IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout_outlined),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            Sessao.sair();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute<void>(builder: (_) => const TelaLogin()),
              (_) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: cores.outlineVariant),
      ),
    );
  }
}

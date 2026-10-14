import 'package:flutter/material.dart';

import '../cores.dart';
import 'logo_semob.dart';

// Barra superior padrão das telas: logo da SEMOB (numa caixinha branca,
// porque a logo tem fundo branco) e o título da tela.
class AppBarSemob extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final List<Widget>? actions;

  const AppBarSemob({super.key, required this.titulo, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Cores.azulEscuro,
      foregroundColor: Colors.white, // ícone do menu e setinha brancos
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const LogoSemob(altura: 44),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(titulo, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: actions,
    );
  }
}

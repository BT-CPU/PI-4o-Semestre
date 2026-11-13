import 'package:flutter/material.dart';

import '../servicos/preferencias_visuais.dart';
import 'fundo_abstrato.dart';
import 'menu_dashboard.dart';

class EstruturaSemob extends StatelessWidget {
  final MenuDashboard? drawer;
  final PreferredSizeWidget appBar;
  final Widget body;

  const EstruturaSemob({
    super.key,
    this.drawer,
    required this.appBar,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final preferencias = PreferenciasVisuais.instancia;
    final menu = drawer;
    return AnimatedBuilder(
      animation: preferencias,
      builder: (context, _) {
        final fundo = FundoAbstrato(child: SizedBox.expand(child: body));
        if (MediaQuery.sizeOf(context).width >= 1120 && menu != null) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: preferencias.menuRecolhido ? 80 : 260,
                  child: MenuDashboard(
                    nomeUsuario: menu.nomeUsuario,
                    itemAtual: menu.itemAtual,
                    fixo: true,
                    recolhido: preferencias.menuRecolhido,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Scaffold(appBar: appBar, body: fundo),
                ),
              ],
            ),
          );
        }
        return Scaffold(drawer: menu, appBar: appBar, body: fundo);
      },
    );
  }
}

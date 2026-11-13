import 'package:flutter/material.dart';

import '../servicos/sessao.dart';
import '../telas/tela_visao_geral.dart';

void voltarAoMenu(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) =>
          TelaVisaoGeral(nomeUsuario: Sessao.usuarioAtual?.usuario ?? ''),
    ),
    (_) => false,
  );
}

/// A seta e o voltar do sistema têm o mesmo destino, inclusive após login admin.
class RetornoAoMenu extends StatelessWidget {
  final Widget child;
  const RetornoAoMenu({super.key, required this.child});

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (voltou, _) {
      if (!voltou) voltarAoMenu(context);
    },
    child: child,
  );
}

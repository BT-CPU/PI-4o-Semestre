import 'package:flutter/material.dart';

/// Versões próprias para cada tema; mantém a faixa na borda, sem esticar a arte.
class FundoAbstrato extends StatelessWidget {
  final Widget child;
  const FundoAbstrato({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: escuro ? const Color(0xFF0E1A28) : Colors.white,
        image: DecorationImage(
          image: AssetImage(
            escuro
                ? 'assets/images/fundo_institucional_escuro.png'
                : 'assets/images/fundo_institucional_claro.png',
          ),
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
        ),
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import 'logo_semob.dart';

/// Brasão original e assinatura textual, sem alterar o símbolo municipal.
class MarcaInstitucional extends StatelessWidget {
  final bool clara;
  final bool compacta;

  const MarcaInstitucional({
    super.key,
    this.clara = false,
    this.compacta = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = clara ? Colors.white : Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        LogoSemob(altura: compacta ? 44 : 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SÃO CAETANO\nDO SUL',
                style: TextStyle(
                  fontSize: compacta ? 12 : 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: 0.7,
                  color: cor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'MOBILIDADE URBANA',
                style: TextStyle(
                  fontSize: compacta ? 8 : 10,
                  letterSpacing: 0.7,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

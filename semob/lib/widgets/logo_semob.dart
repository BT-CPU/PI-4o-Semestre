import 'package:flutter/material.dart';

import '../cores.dart';

// Logo da SEMOB. Se o arquivo da logo não for encontrado (por exemplo, o
// pubspec.yaml sem a lista "assets" ou o arquivo fora de
// assets/images/logo_semob.png), mostra um ícone no lugar em vez de quebrar a
// tela. Assim o app e os testes continuam funcionando mesmo sem a logo.
class LogoSemob extends StatelessWidget {
  final double altura;

  const LogoSemob({super.key, required this.altura});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_semob.png',
      height: altura,
      errorBuilder: (context, erro, pilha) {
        return SizedBox(
          height: altura,
          width: altura,
          child: Icon(
            Icons.directions_bus,
            size: altura * 0.6,
            color: Cores.azulEscuro,
          ),
        );
      },
    );
  }
}

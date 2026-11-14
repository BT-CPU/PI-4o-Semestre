import 'package:flutter/material.dart';

import '../cores.dart';

// Comparação com o período anterior (ex.: "▲ +3,2% vs período anterior")
class Variacao {
  final String texto;
  final IconData icone;
  final Color cor;

  const Variacao(this.texto, this.icone, this.cor);
}

// Cartão de um indicador: título, número grande, detalhe e variação
class CartaoIndicador extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final String valor;
  final String detalhe;
  final Variacao? variacao; // null = não há período anterior
  final bool semComparacao; // true = não mostra a linha de comparação
  final Color corValor;
  final String? dica; // texto que aparece ao passar o mouse no "i"

  const CartaoIndicador({
    super.key,
    required this.titulo,
    required this.icone,
    required this.valor,
    required this.detalhe,
    this.variacao,
    this.semComparacao = false,
    this.corValor = Cores.azulEscuro,
    this.dica,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Cores.azulMedio, // azulClaro com texto branco tem pouco contraste
                  foregroundColor: Colors.white,
                  child: Icon(icone, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Cores.azulEscuro,
                    ),
                  ),
                ),
                if (dica != null)
                  Tooltip(
                    message: dica!,
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // FittedBox encolhe o número se faltar espaço (telas pequenas)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: corValor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detalhe,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            if (!semComparacao) const SizedBox(height: 10),
            if (!semComparacao)
              if (variacao == null)
                const Text(
                  'Sem período anterior nos dados',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Row(
                  children: [
                    Icon(variacao!.icone, size: 16, color: variacao!.cor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        variacao!.texto,
                        style: TextStyle(
                          color: variacao!.cor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

// Cartão genérico com título e subtítulo, usado pelos gráficos e alertas
class CartaoPainel extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget child;

  const CartaoPainel({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Cores.azulEscuro,
              ),
            ),
            if (subtitulo != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitulo!,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

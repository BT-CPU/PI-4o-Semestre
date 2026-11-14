import 'package:flutter/material.dart';

import '../cores.dart';
import 'logo_semob.dart';

// Barra superior padrão das telas: logo da SEMOB (numa caixinha branca,
// porque a logo tem fundo branco), ícone da seção e o título da tela.
// Fundo em degradê, sombra e uma faixa clara embaixo para dar destaque.
// Se adapta ao tamanho da tela (celular x computador).
class AppBarSemob extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final IconData? icone; // opcional: ícone da seção (o mesmo do menu lateral)
  final List<Widget>? actions;

  const AppBarSemob({
    super.key,
    required this.titulo,
    this.icone,
    this.actions,
  });

  // Altura da barra e da faixa de acabamento embaixo
  static const double _altura = 68;
  static const double _alturaFaixa = 3;

  // A altura total precisa incluir a faixa de baixo
  @override
  Size get preferredSize => const Size.fromHeight(_altura + _alturaFaixa);

  @override
  Widget build(BuildContext context) {
    // Abaixo de 600 px de largura consideramos "celular"
    final largo = MediaQuery.of(context).size.width >= 600;

    // No celular, se a tela tem botões na barra (ex.: administração),
    // o ícone da seção é escondido para sobrar espaço para o título
    final mostrarIcone = icone != null && (largo || actions == null);

    return AppBar(
      toolbarHeight: _altura,
      backgroundColor: Cores.azulEscuro,
      foregroundColor: Colors.white,
      // Ícone do menu (hambúrguer) e da setinha um pouco maiores
      iconTheme: const IconThemeData(color: Colors.white, size: 28),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      elevation: 4,
      scrolledUnderElevation: 4,
      shadowColor: Colors.black45,
      surfaceTintColor: Colors.transparent,
      titleSpacing: largo ? null : 4,
      // Degradê da esquerda para a direita
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Cores.azulEscuro, Cores.azulMedio],
          ),
        ),
      ),
      // Faixa fina na cor clara da paleta, como acabamento
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(_alturaFaixa),
        child: SizedBox(
          height: _alturaFaixa,
          width: double.infinity,
          child: ColoredBox(color: Cores.azulClaro),
        ),
      ),
      title: Row(
        children: [
          // Logo numa caixinha branca com sombra
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: LogoSemob(altura: largo ? 48 : 42),
          ),
          SizedBox(width: largo ? 14 : 10),

          // Ícone da seção (só se a tela passou o parâmetro "icone")
          if (mostrarIcone) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icone, size: 20, color: Colors.white),
            ),
            SizedBox(width: largo ? 14 : 10),
          ] else ...[
            // Sem ícone: um divisor vertical separa a logo do título
            Container(width: 1, height: 36, color: Colors.white38),
            SizedBox(width: largo ? 14 : 10),
          ],

          // Título e subtítulo
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: largo ? 20 : 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  largo ? 'SEMOB · Dashboard de Operação' : 'SEMOB · Dashboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}
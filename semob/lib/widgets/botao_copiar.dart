import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notificacao.dart';

/// Inclui textos, tabelas montadas e os valores das séries dos gráficos.
String textoDoPainel(BuildContext context) {
  final linhas = <String>[];
  void visitar(Element elemento) {
    final widget = elemento.widget;
    if (widget is Text) {
      final texto = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      if (texto.trim().isNotEmpty) linhas.add(texto.trim());
    } else if (widget is LineChart) {
      for (var i = 0; i < widget.data.lineBarsData.length; i++) {
        linhas.add('Série ${i + 1} — posição no eixo X; valor');
        for (final ponto in widget.data.lineBarsData[i].spots) {
          if (!ponto.isNull()) linhas.add('${ponto.x}; ${ponto.y}');
        }
      }
    } else if (widget is BarChart) {
      linhas.add('Grupo; série; valor');
      for (final grupo in widget.data.barGroups) {
        for (var i = 0; i < grupo.barRods.length; i++) {
          linhas.add('${grupo.x}; ${i + 1}; ${grupo.barRods[i].toY}');
        }
      }
    } else if (widget is PieChart) {
      for (final parte in widget.data.sections) {
        linhas.add('${parte.title}: ${parte.value}');
      }
    }
    elemento.visitChildElements(visitar);
  }

  (context as Element).visitChildElements(visitar);
  return linhas.join('\n');
}

class BotaoCopiar extends StatelessWidget {
  final String Function() obterTexto;
  const BotaoCopiar({super.key, required this.obterTexto});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Copiar informações',
    visualDensity: VisualDensity.compact,
    icon: const Icon(Icons.content_copy_outlined, size: 16),
    onPressed: () async {
      try {
        await Clipboard.setData(ClipboardData(text: obterTexto()));
        if (context.mounted) {
          mostrarNotificacao(context, 'Informações copiadas.');
        }
      } catch (_) {
        if (context.mounted) {
          mostrarNotificacao(
            context,
            'Não foi possível copiar as informações.',
            ehErro: true,
          );
        }
      }
    },
  );
}

import 'package:flutter/material.dart';

void mostrarNotificacao(
  BuildContext context,
  String texto, {
  bool ehErro = false,
}) {
  final mensagens = ScaffoldMessenger.of(context);
  mensagens.hideCurrentSnackBar();
  mensagens.showSnackBar(
    SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      closeIconColor: Colors.white,
      backgroundColor: ehErro
          ? const Color(0xFF9C2E39)
          : const Color(0xFF153E68),
      duration: const Duration(seconds: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

Future<void> abrirAviso(BuildContext context, String titulo, String texto) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(titulo)),
            IconButton(
              tooltip: 'Fechar notificação',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SingleChildScrollView(child: SelectableText(texto)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );

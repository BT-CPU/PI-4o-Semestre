import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cores.dart';
import 'servicos/dados_servico.dart';
import 'servicos/fonte_dados_api.dart';
import 'telas/tela_login.dart';

// Permite mostrar uma mensagem (SnackBar) de qualquer lugar do app, mesmo
// de fora das telas (ex.: quando não dá para buscar os dados).
final GlobalKey<ScaffoldMessengerState> chaveMensagens =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  // Os dados vêm do servidor (API). Sem esta linha o app usaria os dados de
  // exemplo, que é o que os testes usam.
  DadosServico.fonte = FonteDadosApi();
  DadosServico.aoFalhar = (mensagem) {
    chaveMensagens.currentState?.showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Cores.erro,
        duration: const Duration(seconds: 8),
      ),
    );
  };
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard SEMOB',
      scaffoldMessengerKey: chaveMensagens,
      debugShowCheckedModeBanner: false,
      // Deixa os textos do Flutter (calendário, botões) em português
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.azulMedio),
        scaffoldBackgroundColor: Cores.fundo,
      ),
      home: const TelaLogin(),
    );
  }
}

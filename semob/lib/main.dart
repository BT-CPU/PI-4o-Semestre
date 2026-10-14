import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cores.dart';
import 'telas/tela_login.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard SEMOB',
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

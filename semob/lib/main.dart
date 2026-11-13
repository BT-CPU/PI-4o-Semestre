import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'servicos/preferencias_visuais.dart';
import 'tema.dart';
import 'telas/tela_login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // O VLibras lê os textos expostos na árvore semântica do Flutter Web.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preferencias = PreferenciasVisuais.instancia;
    return AnimatedBuilder(
      animation: preferencias,
      builder: (context, _) => MaterialApp(
        title: 'SEMOB',
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: criarTema(),
        darkTheme: criarTema(escuro: true),
        themeMode: preferencias.escuro ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return Theme(
            data: criarTema(
              escuro: preferencias.escuro,
              reduzirMovimento: media.disableAnimations,
            ),
            child: LayoutBuilder(
              builder: (context, limites) {
                final tamanho = Size(
                  limites.maxWidth / preferencias.zoom,
                  limites.maxHeight / preferencias.zoom,
                );
                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: tamanho.width,
                      height: tamanho.height,
                      child: MediaQuery(
                        data: media.copyWith(
                          size: tamanho,
                          padding: media.padding / preferencias.zoom,
                          viewInsets: media.viewInsets / preferencias.zoom,
                          viewPadding: media.viewPadding / preferencias.zoom,
                          textScaler: TextScaler.linear(
                            media.textScaler.scale(1) * preferencias.letras,
                          ),
                        ),
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        home: const TelaLogin(),
      ),
    );
  }
}

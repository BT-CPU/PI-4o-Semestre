import 'package:flutter/material.dart';

import 'cores.dart';

ThemeData criarTema({bool reduzirMovimento = false, bool escuro = false}) {
  final duracao = Duration(milliseconds: reduzirMovimento ? 0 : 150);
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.azulMedio,
    brightness: escuro ? Brightness.dark : Brightness.light,
    primary: escuro ? const Color(0xFF9DCEFF) : Cores.azulEscuro,
    onPrimary: escuro ? const Color(0xFF082C51) : Colors.white,
    primaryContainer: escuro
        ? const Color(0xFF213E5D)
        : const Color(0xFFE9F1FA),
    onPrimaryContainer: escuro ? const Color(0xFFD4E8FF) : Cores.azulEscuro,
    surface: escuro ? const Color(0xFF172437) : Colors.white,
    onSurface: escuro ? const Color(0xFFE6EDF6) : Cores.texto,
    onSurfaceVariant: escuro ? const Color(0xFFAFBFD1) : Cores.textoSecundario,
    outlineVariant: escuro ? const Color(0xFF34455C) : Cores.borda,
    surfaceContainerLow: escuro
        ? const Color(0xFF1D2E44)
        : const Color(0xFFF4F7FA),
    error: escuro ? const Color(0xFFFFA5A5) : Cores.erro,
  );
  ButtonStyle estilo({bool preenchido = false}) => ButtonStyle(
    animationDuration: duracao,
    minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(forma),
    elevation: const WidgetStatePropertyAll(0),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (estados) => estados.contains(WidgetState.disabled)
          ? esquema.onSurface.withValues(alpha: .38)
          : preenchido
          ? esquema.onPrimary
          : esquema.primary,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (estados) => preenchido
          ? estados.contains(WidgetState.disabled)
                ? esquema.outlineVariant
                : esquema.primary
          : Colors.transparent,
    ),
    overlayColor: WidgetStateProperty.resolveWith((estados) {
      final cor = preenchido ? esquema.onPrimary : esquema.primary;
      if (estados.contains(WidgetState.pressed)) {
        return cor.withValues(alpha: .18);
      }
      if (estados.contains(WidgetState.focused)) {
        return cor.withValues(alpha: .16);
      }
      if (estados.contains(WidgetState.hovered)) {
        return cor.withValues(alpha: .08);
      }
      return Colors.transparent;
    }),
  );
  final texto = (escuro ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
    fontFamily: 'Inter',
    bodyColor: esquema.onSurface,
    displayColor: esquema.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: escuro ? const Color(0xFF111B2A) : Cores.fundo,
    fontFamily: 'Inter',
    textTheme: texto,
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(esquema.surfaceContainerLow),
      headingTextStyle: TextStyle(
        color: esquema.onSurface,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: TextStyle(color: esquema.onSurface, fontSize: 13),
      dataRowColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? esquema.primaryContainer
            : null,
      ),
      dividerThickness: 1,
    ),
    cardTheme: CardThemeData(
      color: esquema.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerLow,
      labelStyle: TextStyle(color: esquema.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: esquema.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: esquema.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: esquema.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: estilo(preenchido: true),
    ),
    filledButtonTheme: FilledButtonThemeData(style: estilo(preenchido: true)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: estilo().copyWith(
        side: WidgetStatePropertyAll(BorderSide(color: esquema.outlineVariant)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: estilo()),
    iconButtonTheme: IconButtonThemeData(
      style: estilo().copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
        foregroundColor: WidgetStatePropertyAll(esquema.onSurfaceVariant),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        animationDuration: duracao,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: esquema.outlineVariant)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? esquema.primary
              : esquema.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? esquema.primaryContainer
              : esquema.surface,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: esquema.onSurfaceVariant,
      textColor: esquema.onSurface,
      minLeadingWidth: 20,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
  );
}

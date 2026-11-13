import 'package:flutter/foundation.dart';

/// Preferências da sessão, compartilhadas por todas as rotas.
class PreferenciasVisuais extends ChangeNotifier {
  static final instancia = PreferenciasVisuais();
  bool escuro = false;
  bool menuRecolhido = false;
  double zoom = 1;
  double letras = 1;

  void definirEscuro(bool valor) {
    escuro = valor;
    notifyListeners();
  }

  void alternarMenu() {
    menuRecolhido = !menuRecolhido;
    notifyListeners();
  }

  void ajustarZoom(double passo) {
    zoom = ((zoom + passo).clamp(.8, 1.3) * 100).round() / 100;
    notifyListeners();
  }

  void ajustarLetras(double passo) {
    letras = ((letras + passo).clamp(.85, 1.3) * 100).round() / 100;
    notifyListeners();
  }

  void restaurar() {
    zoom = 1;
    letras = 1;
    notifyListeners();
  }
}

import '../models/periodo.dart';

// Guarda o período e a data escolhidos, para valerem em TODAS as telas do
// dashboard: quem escolhe "Semana" na Visão geral e abre "Passageiros" vê a
// mesma semana, sem escolher de novo. (Solução simples, sem pacote.)
class FiltroGlobal {
  static TipoPeriodo tipo = TipoPeriodo.mes;
  static DateTime? dataRef; // null = usar o último dia com dados

  static void redefinir() {
    tipo = TipoPeriodo.mes;
    dataRef = null;
  }
}

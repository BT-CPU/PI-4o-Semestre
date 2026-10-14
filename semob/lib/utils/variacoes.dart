import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/periodo.dart';
import '../widgets/cartao_indicador.dart';
import 'formatadores.dart';

// Texto que acompanha a variação: "vs período anterior"
String rotuloComparacao(TipoPeriodo tipo) {
  return tipo == TipoPeriodo.dia
      ? 'vs mesmo dia da semana anterior'
      : 'vs período anterior';
}

String _sinal(double valor) => valor > 0 ? '+' : (valor < 0 ? '-' : '');

// boaQuandoSobe: true = subir é bom (verde), false = subir é ruim (vermelho),
// null = neutro (cinza), quando não dá para dizer se é bom ou ruim
Variacao _criarVariacao(
  double diferenca,
  double limiteEstavel,
  String texto,
  bool? boaQuandoSobe,
  String rotulo,
) {
  if (diferenca.abs() < limiteEstavel) {
    return Variacao('Estável $rotulo', Icons.remove, Colors.grey.shade700);
  }
  final subiu = diferenca > 0;
  Color cor = Colors.grey.shade700;
  if (boaQuandoSobe != null) {
    cor = (subiu == boaQuandoSobe) ? Cores.sucesso : Cores.erro;
  }
  return Variacao(
    '$texto $rotulo',
    subiu ? Icons.arrow_upward : Icons.arrow_downward,
    cor,
  );
}

// Variação em % (ex.: passageiros subiram 3,2%).
// Devolve null quando não há período anterior.
Variacao? variacaoPercentual(
  double atual,
  double? anterior,
  String rotulo, {
  bool? boaQuandoSobe,
}) {
  if (anterior == null) return null;

  // Não dá para calcular % sobre zero
  if (anterior == 0) {
    if (atual == 0) {
      return Variacao('Estável $rotulo', Icons.remove, Colors.grey.shade700);
    }
    return _criarVariacao(atual, 0, 'Novo (era 0)', boaQuandoSobe, rotulo);
  }

  final pct = (atual - anterior) / anterior.abs() * 100;
  final texto = '${_sinal(pct)}${formatarDecimal(pct.abs(), casas: 1)}%';
  return _criarVariacao(pct, 0.05, texto, boaQuandoSobe, rotulo);
}

// Variação em pontos percentuais (para indicadores que já são %, como o FCV)
Variacao? variacaoPontos(
  double atual,
  double? anterior,
  String rotulo, {
  bool? boaQuandoSobe,
}) {
  if (anterior == null) return null;
  final dif = atual - anterior;
  final texto = '${_sinal(dif)}${formatarDecimal(dif.abs(), casas: 2)} p.p.';
  return _criarVariacao(dif, 0.005, texto, boaQuandoSobe, rotulo);
}

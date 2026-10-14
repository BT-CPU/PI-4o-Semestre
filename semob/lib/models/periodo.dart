enum TipoPeriodo { dia, semana, quinzena, mes }

// Um intervalo de datas (inclui o primeiro e o último dia)
class JanelaDatas {
  final DateTime inicio;
  final DateTime fim;

  JanelaDatas(this.inicio, this.fim);

  int get quantidadeDias {
    // Uso UTC para o horário de verão não atrapalhar a conta
    final a = DateTime.utc(inicio.year, inicio.month, inicio.day);
    final b = DateTime.utc(fim.year, fim.month, fim.day);
    return b.difference(a).inDays + 1;
  }
}

// Soma (ou subtrai, se negativo) dias a uma data
DateTime somarDias(DateTime data, int dias) {
  return DateTime(data.year, data.month, data.day + dias);
}

// Como cada período é calculado a partir da DATA DE REFERÊNCIA:
//   dia       -> só aquela data
//   semana    -> 7 dias terminando na data
//   quinzena  -> 14 dias terminando na data
//   mês       -> do dia 1 do mês até a data
JanelaDatas janelaAtual(TipoPeriodo tipo, DateTime ref) {
  switch (tipo) {
    case TipoPeriodo.dia:
      return JanelaDatas(ref, ref);
    case TipoPeriodo.semana:
      return JanelaDatas(somarDias(ref, -6), ref);
    case TipoPeriodo.quinzena:
      return JanelaDatas(somarDias(ref, -13), ref);
    case TipoPeriodo.mes:
      return JanelaDatas(DateTime(ref.year, ref.month, 1), ref);
  }
}

// Período usado para comparação (o "anterior" de mesmo tamanho):
//   dia       -> mesmo dia da semana anterior (segunda com segunda)
//   semana    -> os 7 dias antes
//   quinzena  -> os 14 dias antes
//   mês       -> mês anterior, até o mesmo dia
JanelaDatas janelaAnterior(TipoPeriodo tipo, DateTime ref) {
  switch (tipo) {
    case TipoPeriodo.dia:
      final mesmoDiaSemanaPassada = somarDias(ref, -7);
      return JanelaDatas(mesmoDiaSemanaPassada, mesmoDiaSemanaPassada);
    case TipoPeriodo.semana:
      return JanelaDatas(somarDias(ref, -13), somarDias(ref, -7));
    case TipoPeriodo.quinzena:
      return JanelaDatas(somarDias(ref, -27), somarDias(ref, -14));
    case TipoPeriodo.mes:
      // O dia 0 de um mês é o último dia do mês anterior
      final ultimoDiaMesAnterior = DateTime(ref.year, ref.month, 0).day;
      final dia = ref.day < ultimoDiaMesAnterior ? ref.day : ultimoDiaMesAnterior;
      return JanelaDatas(
        DateTime(ref.year, ref.month - 1, 1),
        DateTime(ref.year, ref.month - 1, dia),
      );
  }
}

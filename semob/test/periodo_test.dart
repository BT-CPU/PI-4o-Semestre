import 'package:flutter_test/flutter_test.dart';

import 'package:semob/models/periodo.dart';

void main() {
  final ref = DateTime(2026, 8, 31);

  group('janela do período escolhido', () {
    test('dia', () {
      final j = janelaAtual(TipoPeriodo.dia, ref);
      expect(j.inicio, ref);
      expect(j.fim, ref);
      expect(j.quantidadeDias, 1);
    });

    test('semana = 7 dias terminando na data', () {
      final j = janelaAtual(TipoPeriodo.semana, ref);
      expect(j.inicio, DateTime(2026, 8, 25));
      expect(j.quantidadeDias, 7);
    });

    test('quinzena = 14 dias terminando na data', () {
      final j = janelaAtual(TipoPeriodo.quinzena, ref);
      expect(j.inicio, DateTime(2026, 8, 18));
      expect(j.quantidadeDias, 14);
    });

    test('mês = do dia 1 até a data', () {
      final j = janelaAtual(TipoPeriodo.mes, ref);
      expect(j.inicio, DateTime(2026, 8, 1));
      expect(j.quantidadeDias, 31);
    });
  });

  group('janela usada na comparação', () {
    test('dia é comparado com o mesmo dia da semana anterior', () {
      final j = janelaAnterior(TipoPeriodo.dia, ref);
      expect(j.inicio, DateTime(2026, 8, 24));
      expect(j.fim, DateTime(2026, 8, 24));
    });

    test('semana e quinzena comparam com o período de mesmo tamanho antes', () {
      final s = janelaAnterior(TipoPeriodo.semana, ref);
      expect(s.inicio, DateTime(2026, 8, 18));
      expect(s.fim, DateTime(2026, 8, 24));

      final q = janelaAnterior(TipoPeriodo.quinzena, ref);
      expect(q.inicio, DateTime(2026, 8, 4));
      expect(q.fim, DateTime(2026, 8, 17));
    });

    test('mês compara com o mês anterior', () {
      final j = janelaAnterior(TipoPeriodo.mes, ref);
      expect(j.inicio, DateTime(2026, 7, 1));
      expect(j.fim, DateTime(2026, 7, 31));
    });

    test('mês anterior mais curto: 31/03 compara com fevereiro inteiro', () {
      final j = janelaAnterior(TipoPeriodo.mes, DateTime(2026, 3, 31));
      expect(j.inicio, DateTime(2026, 2, 1));
      expect(j.fim, DateTime(2026, 2, 28));
    });

    test('janeiro compara com dezembro do ano anterior', () {
      final j = janelaAnterior(TipoPeriodo.mes, DateTime(2027, 1, 15));
      expect(j.inicio, DateTime(2026, 12, 1));
      expect(j.fim, DateTime(2026, 12, 15));
    });
  });

  test('somarDias atravessa a virada de mês', () {
    expect(somarDias(DateTime(2026, 8, 1), -1), DateTime(2026, 7, 31));
    expect(somarDias(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 1));
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:semob/utils/formatadores.dart';

void main() {
  group('formatarInteiro', () {
    test('agrupa os milhares com ponto', () {
      expect(formatarInteiro(1050248), '1.050.248');
      expect(formatarInteiro(1000), '1.000');
      expect(formatarInteiro(999), '999');
      expect(formatarInteiro(0), '0');
    });

    test('números negativos', () {
      expect(formatarInteiro(-12345), '-12.345');
    });
  });

  group('formatarDecimal', () {
    test('vírgula decimal e ponto nos milhares', () {
      expect(formatarDecimal(275694.5), '275.694,5');
      expect(formatarDecimal(5253.0, casas: 0), '5.253');
      expect(formatarDecimal(99.8399, casas: 2), '99,84');
    });

    test('não mostra "-0,00"', () {
      expect(formatarDecimal(-0.004, casas: 2), '0,00');
    });

    test('negativos', () {
      expect(formatarDecimal(-3380, casas: 2), '-3.380,00');
    });

    test('divisão por zero (NaN ou infinito) vira um traço', () {
      expect(formatarDecimal(double.nan), '-');
      expect(formatarDecimal(double.infinity), '-');
      expect(formatarDecimal(0 / 0), '-');
    });
  });

  group('formatarMoeda', () {
    test('positivo e negativo', () {
      expect(formatarMoeda(368865.71), 'R\$ 368.865,71');
      expect(formatarMoeda(-3380), '-R\$ 3.380,00');
      expect(formatarMoeda(0), 'R\$ 0,00');
    });
  });

  group('formatarCompacto (rótulos dos eixos)', () {
    test('milhares', () {
      expect(formatarCompacto(138950), '139 mil');
      expect(formatarCompacto(12000), '12 mil');
      expect(formatarCompacto(2500), '2,5 mil'); // antes virava "3 mil"
      expect(formatarCompacto(999), '999');
    });

    test('milhões', () {
      expect(formatarCompacto(1200000), '1,2 mi');
    });
  });

  group('datas e horas', () {
    test('formatarData e formatarDataCurta', () {
      expect(formatarData(DateTime(2026, 8, 5)), '05/08/2026');
      expect(formatarDataCurta(DateTime(2026, 8, 5)), '05/08');
    });

    test('nomeDiaSemana', () {
      expect(nomeDiaSemana(DateTime(2026, 8, 1)), 'Sáb');
      expect(nomeDiaSemana(DateTime(2026, 8, 2)), 'Dom');
      expect(nomeDiaSemana(DateTime(2026, 8, 3)), 'Seg');
    });

    test('formatarHora', () {
      expect(formatarHora(DateTime(2026, 8, 2, 14, 35)), '14:35');
      expect(formatarHora(DateTime(2026, 8, 2, 14, 54, 52), segundos: true), '14:54:52');
      expect(formatarHora(null), '-');
    });
  });
}

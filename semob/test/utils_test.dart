import 'package:flutter_test/flutter_test.dart';

import 'package:semob/models/dia_operacao.dart';
import 'package:semob/utils/horas.dart';
import 'package:semob/utils/tipo_dia.dart';

  
void main() {
  group('tipoDia', () {
    test('sábado e domingo', () {
      expect(tipoDia(DateTime(2026, 8, 29)), 'Sábado');
      expect(tipoDia(DateTime(2026, 8, 30)), 'Domingo');
    });

    test('segunda a sexta são dia útil', () {
      // 24/08/2026 é segunda-feira e 28/08/2026 é sexta-feira
      for (var dia = 24; dia <= 28; dia++) {
        expect(tipoDia(DateTime(2026, 8, dia)), 'Dia útil', reason: 'dia $dia/08');
      }
    });

    test('feriado conta como o dia da semana em que cai', () {
      // 07/09/2026 (Independência) cai numa segunda-feira
      expect(tipoDia(DateTime(2026, 9, 7)), 'Dia útil');
    });
  });

  group('horas', () {
    test('a madrugada (0h a 3h) vem depois das 23h', () {
      expect(ordemHora(4), 4);
      expect(ordemHora(23), 23);
      expect(ordemHora(0), 24);
      expect(ordemHora(3), 27);
    });

    test('ordenar por ordemHora dá 4h ... 23h e, por último, 0h', () {
      final horas = [0, 23, 4, 7, 12];
      horas.sort((a, b) => ordemHora(a).compareTo(ordemHora(b)));
      expect(horas, [4, 7, 12, 23, 0]);
    });

    test('rotuloHora escreve a hora com "h"', () {
      expect(rotuloHora(7), '7h');
      expect(rotuloHora(0), '0h');
      expect(rotuloHora(23), '23h');
    });
  });

  
  group('faixaDoDia (limites inferidos, a confirmar)', () {
    test('manhã vai de 4h a 11h', () {
      expect(faixaDoDia(4), 'Manhã');
      expect(faixaDoDia(11), 'Manhã');
    });

    test('tarde vai de 12h a 17h', () {
      expect(faixaDoDia(12), 'Tarde');
      expect(faixaDoDia(17), 'Tarde');
    });

    test('noite vai de 18h a 23h e inclui a madrugada (0h a 3h)', () {
      expect(faixaDoDia(18), 'Noite');
      expect(faixaDoDia(23), 'Noite');
      expect(faixaDoDia(0), 'Noite');
      expect(faixaDoDia(3), 'Noite');
    });
  });

  group('calcularFcv', () {
    test('agosto/2026: 34.994 realizadas de 35.050 programadas dá cerca de 99,84%', () {
      expect(calcularFcv(35050, 34994), closeTo(99.84, 0.01));
    });

    test('nada programado conta como 100%', () {
      expect(calcularFcv(0, 0), 100);
    });

    test('tudo realizado dá 100% e nada realizado dá 0%', () {
      expect(calcularFcv(10, 10), 100);
      expect(calcularFcv(10, 0), 0);
    });
  });
}
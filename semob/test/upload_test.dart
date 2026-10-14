import 'package:flutter_test/flutter_test.dart';

import 'package:semob/models/arquivo_selecionado.dart';

void main() {
  group('InfoRelatorio.doNome reconhece os arquivos da Smart Data', () {
    // arquivo, periodicidade, tipo, período
    const casos = <List<String?>>[
      ['Mensal_202608.html', 'Mensal', 'Resumo geral', '2026-08'],
      ['Mensal_FCV_202608.html', 'Mensal', 'Fator de cumprimento de viagem', '2026-08'],
      ['Mensal_Linhas_202608.html', 'Mensal', 'Resumo por linha', '2026-08'],
      ['Mensal_FxHr_202608.html', 'Mensal', 'Partidas por faixa horária', '2026-08'],
      ['Mensal_Resumo_FxHr_202608.html', 'Mensal', 'Resumo por faixa horária', '2026-08'],
      ['Mensal_Viagens_202608.html', 'Mensal', 'Viagens (detalhe)', '2026-08'],
      ['Mensal_Viag_NRealiz_202608.html', 'Mensal', 'Viagens não realizadas', '2026-08'],
      ['Mensal_Viag_Ninic_202608.html', 'Mensal', 'Viagens não iniciadas', '2026-08'],
      ['Mensal_Viag_NTerm_202608.html', 'Mensal', 'Viagens não terminadas', '2026-08'],
      ['Passageiros_Mensal.html', 'Mensal', 'Passageiros', null],
      ['Saldos_Mensal.html', 'Mensal', 'Financeiro (saldos)', null],
      ['Quinzenal_202608.html', 'Quinzenal', 'Resumo geral', '2026-08'],
      ['Quinzenal_Resumo_FxHr_202608.html', 'Quinzenal', 'Resumo por faixa horária', '2026-08'],
      ['Passageiros_Quinzenal.html', 'Quinzenal', 'Passageiros', null],
      ['Saldos_Quinzenal.html', 'Quinzenal', 'Financeiro (saldos)', null],
    ];

    for (final caso in casos) {
      test(caso[0]!, () {
        final info = InfoRelatorio.doNome(caso[0]!);
        expect(info, isNotNull);
        expect(info!.periodicidade, caso[1]);
        expect(info.tipo, caso[2]);
        expect(info.periodo, caso[3]);
      });
    }

    test('recusa o que não é relatório conhecido', () {
      expect(InfoRelatorio.doNome('relatorio.html'), isNull);
      expect(InfoRelatorio.doNome('Mensal_xyz.html'), isNull);
      expect(InfoRelatorio.doNome('Mensal_Viagens_202608.pdf'), isNull);
    });
  });

  test('formatarTamanho', () {
    expect(formatarTamanho(500), '500 B');
    expect(formatarTamanho(1536), '1,5 KB');
    expect(formatarTamanho(2 * 1024 * 1024), '2,0 MB');
  });
}

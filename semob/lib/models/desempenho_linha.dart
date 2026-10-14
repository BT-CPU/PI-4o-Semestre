import 'dia_operacao.dart';
import 'km_linha.dart';

// Resultado de UMA linha em um período: viagens, km e ocorrências.
//
// Como o FCV por linha é calculado:
//   programadas = realizadas + não realizadas + não iniciadas + não terminadas
//   FCV = realizadas ÷ programadas
// Conferi com os relatórios de agosto/2026: essa soma fecha com as viagens
// programadas do Resumo Geral em todos os dias.
class DesempenhoLinha {
  final String linha;
  int viagensRealizadas = 0;
  double kmProdutivo = 0;
  int naoRealizadas = 0;
  int naoIniciadas = 0;
  int naoTerminadas = 0;

  DesempenhoLinha(this.linha);

  int get ocorrencias => naoRealizadas + naoIniciadas + naoTerminadas;

  int get viagensProgramadas => viagensRealizadas + ocorrencias;

  double get fcv => calcularFcv(viagensProgramadas, viagensRealizadas);

  double get kmPorViagem {
    if (viagensRealizadas == 0) return 0;
    return kmProdutivo / viagensRealizadas;
  }

  // Junta o km por linha/dia e as ocorrências e devolve um resultado por linha
  static Map<String, DesempenhoLinha> calcular(
    List<KmLinhaDia> km,
    List<Ocorrencia> ocorrencias,
  ) {
    final mapa = <String, DesempenhoLinha>{};

    DesempenhoLinha daLinha(String linha) {
      return mapa.putIfAbsent(linha, () => DesempenhoLinha(linha));
    }

    for (final k in km) {
      final d = daLinha(k.linha);
      d.viagensRealizadas += k.viagens;
      d.kmProdutivo += k.kmProdutivo;
    }

    for (final o in ocorrencias) {
      final d = daLinha(o.linha);
      switch (o.tipo) {
        case TipoOcorrencia.naoRealizada:
          d.naoRealizadas++;
          break;
        case TipoOcorrencia.naoIniciada:
          d.naoIniciadas++;
          break;
        case TipoOcorrencia.naoTerminada:
          d.naoTerminadas++;
          break;
      }
    }

    return mapa;
  }
}

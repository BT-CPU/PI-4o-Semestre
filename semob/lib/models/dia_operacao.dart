// FCV = viagens realizadas ÷ programadas, em %.
// Se nada foi programado, não há o que cumprir: considero 100%.
double calcularFcv(int programadas, int realizadas) {
  if (programadas == 0) return 100;
  return realizadas / programadas * 100;
}

// Tudo o que a operação registrou em UM dia.
// Cada objeto junta informações de vários relatórios da Smart Data:
// resumo geral (viagens, km e veículos), FCV por faixa do dia,
// passageiros e financeiro (saldos).
class DiaOperacao {
  final DateTime data;
  final int veiculos; // veículos que operaram no dia
  final int maxVeiculosFaixa; // máximo de veículos em uma faixa horária
  final int viagensProgramadas;
  final int viagensRealizadas;
  final int manhaProgramadas;
  final int manhaRealizadas;
  final int tardeProgramadas;
  final int tardeRealizadas;
  final int noiteProgramadas;
  final int noiteRealizadas;
  final double kmProdutivo;
  final double kmImprodutivo;
  final int passageirosCatraca;
  final int passageirosAntecipados;
  final int passageirosNaoPagantes;
  final double vendas; // venda de créditos no dia
  final double utilizacao; // uso de créditos no dia
  // Créditos transferidos para cartões no dia (0 nos dias sem lançamento)
  final double creditosTransferidos;
  // Saldo final do sistema no dia. Nos dias sem lançamento o saldo se mantém
  // (a cadeia saldo = saldo anterior - transferido confere em todos os dias).
  final double saldoSistema;

  DiaOperacao({
    required this.data,
    required this.veiculos,
    required this.maxVeiculosFaixa,
    required this.viagensProgramadas,
    required this.viagensRealizadas,
    required this.manhaProgramadas,
    required this.manhaRealizadas,
    required this.tardeProgramadas,
    required this.tardeRealizadas,
    required this.noiteProgramadas,
    required this.noiteRealizadas,
    required this.kmProdutivo,
    required this.kmImprodutivo,
    required this.passageirosCatraca,
    required this.passageirosAntecipados,
    required this.passageirosNaoPagantes,
    required this.vendas,
    required this.utilizacao,
    required this.creditosTransferidos,
    required this.saldoSistema,
  });

  double get kmTotal => kmProdutivo + kmImprodutivo;

  // Vendas menos utilização do dia (não é receita nem prejuízo!)
  double get creditoCirculante => vendas - utilizacao;

  int get passageirosTotal =>
      passageirosCatraca + passageirosAntecipados + passageirosNaoPagantes;

  // ATENÇÃO: estou considerando "pagantes" = catraca + antecipados.
  // Confirmar essa definição com a SEMOB.
  int get passageirosPagantes => passageirosCatraca + passageirosAntecipados;

  int get viagensNaoRealizadas => viagensProgramadas - viagensRealizadas;

  // Participação dos não pagantes no total de passageiros do dia, em %
  double get percentualNaoPagantes {
    if (passageirosTotal == 0) return 0;
    return passageirosNaoPagantes / passageirosTotal * 100;
  }

  double get passageirosPorViagem {
    if (viagensRealizadas == 0) return 0;
    return passageirosTotal / viagensRealizadas;
  }

  // Passageiros por km rodado (IPK), usando o km total do dia
  double get passageirosPorKm {
    if (kmTotal == 0) return 0;
    return passageirosTotal / kmTotal;
  }

  // Fator de Cumprimento de Viagem do dia e de cada faixa, em %
  double get fcv => calcularFcv(viagensProgramadas, viagensRealizadas);
  double get fcvManha => calcularFcv(manhaProgramadas, manhaRealizadas);
  double get fcvTarde => calcularFcv(tardeProgramadas, tardeRealizadas);
  double get fcvNoite => calcularFcv(noiteProgramadas, noiteRealizadas);

  double get percentualKmImprodutivo {
    if (kmTotal == 0) return 0;
    return kmImprodutivo / kmTotal * 100;
  }
}

enum TipoOcorrencia { naoRealizada, naoIniciada, naoTerminada }

// Uma viagem que teve problema (vem dos relatórios de viagens
// não realizadas, não iniciadas e não terminadas).
//   não realizada: sem registro de veículo, de saída nem de chegada
//   não iniciada:  tem registro de chegada, mas não de saída
//   não terminada: tem registro de saída, mas não de chegada
// As três contam como "não realizadas" no cálculo do FCV.
class Ocorrencia {
  final DateTime data;
  final String linha;
  final TipoOcorrencia tipo;
  final String atendimento; // nome da linha + sentido, como vem da Smart Data
  final String prefixo; // número do veículo (vazio nas não realizadas)
  // Número do motorista: é DADO PESSOAL. A tela só mostra se
  // exibirMotorista (em limites.dart) estiver ligado.
  final String motorista;
  final String sentido; // I = ida, V = volta
  final String tabela; // escala do veículo/motorista
  final DateTime? inicioProgramado;
  final DateTime? inicioRealizado;
  final DateTime? fimProgramado;
  final DateTime? fimRealizado;

  Ocorrencia({
    required this.data,
    required this.linha,
    required this.tipo,
    this.atendimento = '',
    this.prefixo = '',
    this.motorista = '',
    this.sentido = '',
    this.tabela = '',
    this.inicioProgramado,
    this.inicioRealizado,
    this.fimProgramado,
    this.fimRealizado,
  });
}

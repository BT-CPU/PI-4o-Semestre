import 'dia_operacao.dart';

// Soma de vários dias: é o que aparece nos cartões das telas
class ResumoPeriodo {
  final int quantidadeDias;
  final int viagensProgramadas;
  final int viagensRealizadas;
  final int manhaProgramadas;
  final int manhaRealizadas;
  final int tardeProgramadas;
  final int tardeRealizadas;
  final int noiteProgramadas;
  final int noiteRealizadas;
  final int somaVeiculos; // soma dos veículos de cada dia (para a média)
  final int veiculosMaximo; // maior nº de veículos em um dia do período
  final int maxVeiculosFaixa; // maior nº de veículos em uma faixa horária
  final double kmProdutivo;
  final double kmImprodutivo;
  final int passageirosCatraca;
  final int passageirosAntecipados;
  final int passageirosNaoPagantes;
  final double vendas;
  final double utilizacao;
  final double creditosTransferidos;
  final double saldoInicial; // saldo do sistema no começo do período
  final double saldoFinal; // saldo do sistema no fim do período
  final double maiorVenda; // maior venda de um dia no período
  final DateTime? diaMaiorVenda; // null se não houve venda

  ResumoPeriodo({
    required this.quantidadeDias,
    required this.viagensProgramadas,
    required this.viagensRealizadas,
    required this.manhaProgramadas,
    required this.manhaRealizadas,
    required this.tardeProgramadas,
    required this.tardeRealizadas,
    required this.noiteProgramadas,
    required this.noiteRealizadas,
    required this.somaVeiculos,
    required this.veiculosMaximo,
    required this.maxVeiculosFaixa,
    required this.kmProdutivo,
    required this.kmImprodutivo,
    required this.passageirosCatraca,
    required this.passageirosAntecipados,
    required this.passageirosNaoPagantes,
    required this.vendas,
    required this.utilizacao,
    required this.creditosTransferidos,
    required this.saldoInicial,
    required this.saldoFinal,
    required this.maiorVenda,
    required this.diaMaiorVenda,
  });

  factory ResumoPeriodo.dosDias(List<DiaOperacao> dias) {
    var programadas = 0;
    var realizadas = 0;
    var manhaP = 0;
    var manhaR = 0;
    var tardeP = 0;
    var tardeR = 0;
    var noiteP = 0;
    var noiteR = 0;
    var somaVeic = 0;
    var maxVeic = 0;
    var maxFaixa = 0;
    var kmProd = 0.0;
    var kmImprod = 0.0;
    var catraca = 0;
    var antecipados = 0;
    var naoPagantes = 0;
    var vendas = 0.0;
    var utilizacao = 0.0;
    var transferidos = 0.0;
    var maiorVenda = 0.0;
    DateTime? diaMaiorVenda;

    for (final d in dias) {
      programadas += d.viagensProgramadas;
      realizadas += d.viagensRealizadas;
      manhaP += d.manhaProgramadas;
      manhaR += d.manhaRealizadas;
      tardeP += d.tardeProgramadas;
      tardeR += d.tardeRealizadas;
      noiteP += d.noiteProgramadas;
      noiteR += d.noiteRealizadas;
      somaVeic += d.veiculos;
      if (d.veiculos > maxVeic) maxVeic = d.veiculos;
      if (d.maxVeiculosFaixa > maxFaixa) maxFaixa = d.maxVeiculosFaixa;
      kmProd += d.kmProdutivo;
      kmImprod += d.kmImprodutivo;
      catraca += d.passageirosCatraca;
      antecipados += d.passageirosAntecipados;
      naoPagantes += d.passageirosNaoPagantes;
      vendas += d.vendas;
      utilizacao += d.utilizacao;
      transferidos += d.creditosTransferidos;
      if (d.vendas > maiorVenda) {
        maiorVenda = d.vendas;
        diaMaiorVenda = d.data;
      }
    }

    return ResumoPeriodo(
      quantidadeDias: dias.length,
      viagensProgramadas: programadas,
      viagensRealizadas: realizadas,
      manhaProgramadas: manhaP,
      manhaRealizadas: manhaR,
      tardeProgramadas: tardeP,
      tardeRealizadas: tardeR,
      noiteProgramadas: noiteP,
      noiteRealizadas: noiteR,
      somaVeiculos: somaVeic,
      veiculosMaximo: maxVeic,
      maxVeiculosFaixa: maxFaixa,
      kmProdutivo: kmProd,
      kmImprodutivo: kmImprod,
      passageirosCatraca: catraca,
      passageirosAntecipados: antecipados,
      passageirosNaoPagantes: naoPagantes,
      vendas: vendas,
      utilizacao: utilizacao,
      creditosTransferidos: transferidos,
      // O saldo no começo do período é o saldo do 1º dia mais o que foi
      // transferido nesse dia (saldo = saldo anterior - transferido)
      saldoInicial:
          dias.isEmpty ? 0.0 : dias.first.saldoSistema + dias.first.creditosTransferidos,
      saldoFinal: dias.isEmpty ? 0.0 : dias.last.saldoSistema,
      maiorVenda: maiorVenda,
      diaMaiorVenda: diaMaiorVenda,
    );
  }

  int get viagensNaoRealizadas => viagensProgramadas - viagensRealizadas;

  double get fcv => calcularFcv(viagensProgramadas, viagensRealizadas);
  double get fcvManha => calcularFcv(manhaProgramadas, manhaRealizadas);
  double get fcvTarde => calcularFcv(tardeProgramadas, tardeRealizadas);
  double get fcvNoite => calcularFcv(noiteProgramadas, noiteRealizadas);

  // Média de veículos por dia no período
  double get veiculosMedia {
    if (quantidadeDias == 0) return 0;
    return somaVeiculos / quantidadeDias;
  }

  double get kmTotal => kmProdutivo + kmImprodutivo;

  double get percentualKmImprodutivo {
    if (kmTotal == 0) return 0;
    return kmImprodutivo / kmTotal * 100;
  }

  // Km produtivo médio de cada viagem realizada
  double get kmProdutivoPorViagem {
    if (viagensRealizadas == 0) return 0;
    return kmProdutivo / viagensRealizadas;
  }

  // Km total rodado por veículo em cada dia de operação
  // (km total ÷ soma dos veículos de cada dia)
  double get kmPorVeiculoDia {
    if (somaVeiculos == 0) return 0;
    return kmTotal / somaVeiculos;
  }

  int get passageirosTotal =>
      passageirosCatraca + passageirosAntecipados + passageirosNaoPagantes;

  int get passageirosPagantes => passageirosCatraca + passageirosAntecipados;

  double get percentualNaoPagantes {
    if (passageirosTotal == 0) return 0;
    return passageirosNaoPagantes / passageirosTotal * 100;
  }

  // Média de passageiros transportados em cada viagem realizada
  double get passageirosPorViagem {
    if (viagensRealizadas == 0) return 0;
    return passageirosTotal / viagensRealizadas;
  }

  // Passageiros por km rodado (IPK), usando o km total do período
  double get passageirosPorKm {
    if (kmTotal == 0) return 0;
    return passageirosTotal / kmTotal;
  }

  // Vendas menos utilização (não é receita nem prejuízo!)
  double get creditoCirculante => vendas - utilizacao;
}

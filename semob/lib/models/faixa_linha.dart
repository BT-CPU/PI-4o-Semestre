// Viagens e veículos de UMA linha em UMA faixa horária de UM dia
// (relatório "FxHr" da Smart Data).
// hora = 4 significa a faixa das 4h (de 4h00 a 4h59). A hora 0 é a madrugada
// depois da meia-noite, ainda parte do dia de operação anterior.
class FaixaLinhaDia {
  final DateTime data;
  final String linha;
  final int hora;
  final int veiculos;
  final int viagens;

  FaixaLinhaDia({
    required this.data,
    required this.linha,
    required this.hora,
    required this.veiculos,
    required this.viagens,
  });
}

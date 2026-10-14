// Veículos e viagens do SISTEMA TODO em uma faixa horária de um dia
// (relatório "Resumo FxHr" da Smart Data).
// hora = 4 significa a faixa das 4h (de 4h00 a 4h59). A hora 0 é a madrugada
// depois da meia-noite, ainda parte do dia de operação.
class FaixaSistemaDia {
  final DateTime data;
  final int hora;
  final int veiculos;
  final int viagens;

  FaixaSistemaDia({
    required this.data,
    required this.hora,
    required this.veiculos,
    required this.viagens,
  });
}

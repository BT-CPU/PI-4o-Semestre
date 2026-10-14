// Ordem de exibição das horas: 4h, 5h ... 23h e, por último, 0h
// (a madrugada depois da meia-noite pertence ao fim do dia de operação).
int ordemHora(int hora) => hora < 4 ? hora + 24 : hora;

String rotuloHora(int hora) => '${hora}h';

// Faixa do dia a que a hora pertence.
// ATENÇÃO: esses limites foram INFERIDOS dos relatórios (as viagens por hora
// somadas até 11h59 e até 17h59 batem com a manhã e a manhã+tarde do
// relatório de FCV). Falta confirmar com a Smart Data.
String faixaDoDia(int hora) {
  if (hora >= 4 && hora <= 11) return 'Manhã';
  if (hora >= 12 && hora <= 17) return 'Tarde';
  return 'Noite';
}

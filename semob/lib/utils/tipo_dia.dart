// Classifica uma data em "Dia útil", "Sábado" ou "Domingo".
// Os três têm programações e demandas diferentes, por isso as comparações
// e médias são feitas separadas por tipo de dia.
// (Feriados contam como o dia da semana em que caem.)
String tipoDia(DateTime data) {
  if (data.weekday == DateTime.saturday) return 'Sábado';
  if (data.weekday == DateTime.sunday) return 'Domingo';
  return 'Dia útil';
}

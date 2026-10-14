// Funções para mostrar números e datas no padrão brasileiro.
// (Escrevi à mão para não precisar de pacote extra.)

// 1050248 -> "1.050.248"
String formatarInteiro(int numero) {
  final texto = numero.abs().toString();
  final comPontos = texto.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => '.',
  );
  return numero < 0 ? '-$comPontos' : comPontos;
}

// 275694.5 -> "275.694,5"   (casas = quantidade de casas decimais)
String formatarDecimal(double valor, {int casas = 1}) {
  // Divisão por zero gera NaN ou infinito: mostra um traço em vez de dar erro
  if (valor.isNaN || valor.isInfinite) return '-';
  final texto = valor.abs().toStringAsFixed(casas);
  final partes = texto.split('.');
  final inteiro = formatarInteiro(int.parse(partes[0]));
  final resultado = casas > 0 ? '$inteiro,${partes[1]}' : inteiro;
  // Evita mostrar "-0,0" quando o valor arredonda para zero
  final ehZero = double.parse(texto) == 0;
  return (valor < 0 && !ehZero) ? '-$resultado' : resultado;
}

// 368865.71 -> "R$ 368.865,71"
String formatarMoeda(double valor) {
  final texto = formatarDecimal(valor.abs(), casas: 2);
  return valor < 0 ? '-R\$ $texto' : 'R\$ $texto';
}

// Para os eixos dos gráficos: 138950 -> "139 mil", 1200000 -> "1,2 mi"
String formatarCompacto(double valor) {
  final absoluto = valor.abs();
  if (absoluto >= 1000000) {
    return '${formatarDecimal(valor / 1000000, casas: 1)} mi';
  }
  if (absoluto >= 1000) {
    // Mostra uma casa decimal só quando ela existe: 2500 -> "2,5 mil",
    // 139000 -> "139 mil" (antes 2500 virava "3 mil", que está errado)
    final decimos = (valor / 100).round(); // em décimos de milhar
    final temDecimal = decimos % 10 != 0;
    return '${formatarDecimal(decimos / 10, casas: temDecimal ? 1 : 0)} mil';
  }
  return formatarDecimal(valor, casas: 0);
}

String doisDigitos(int numero) => numero.toString().padLeft(2, '0');

// "05/08"
String formatarDataCurta(DateTime data) {
  return '${doisDigitos(data.day)}/${doisDigitos(data.month)}';
}

// "05/08/2026"
String formatarData(DateTime data) {
  return '${formatarDataCurta(data)}/${data.year}';
}

String nomeDiaSemana(DateTime data) {
  const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  return nomes[data.weekday - 1];
}

// "14:35" ou, com segundos, "14:54:52". Devolve "-" se não houver horário.
String formatarHora(DateTime? data, {bool segundos = false}) {
  if (data == null) return '-';
  final base = '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';
  return segundos ? '$base:${doisDigitos(data.second)}' : base;
}

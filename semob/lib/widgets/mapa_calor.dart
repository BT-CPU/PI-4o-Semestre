import 'package:flutter/material.dart';

import '../cores.dart';
import '../utils/formatadores.dart';
import '../utils/horas.dart';

// Mapa de calor: uma linha por dia, uma coluna por hora.
// Quanto mais escura a célula, maior o valor. Feito só com Containers.
class MapaCalor extends StatelessWidget {
  final List<DateTime> dias;
  final List<int> horas; // já na ordem de exibição
  final double Function(DateTime dia, int hora) valor;
  final String Function(DateTime dia, int hora) textoDica;
  final Color cor;

  const MapaCalor({
    super.key,
    required this.dias,
    required this.horas,
    required this.valor,
    required this.textoDica,
    this.cor = Cores.azulEscuro,
  });

  static const double _larguraCelula = 36;
  static const double _alturaLinha = 26;
  static const double _alturaCabecalho = 22;
  static const double _larguraRotulo = 82;

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty || horas.isEmpty) {
      return const Text('Sem dados para o mapa de calor.');
    }

    // O maior valor define a cor mais escura
    var maximo = 0.0;
    for (final d in dias) {
      for (final h in horas) {
        final v = valor(d, h);
        if (v > maximo) maximo = v;
      }
    }

    // Agrupa horas seguidas da mesma faixa (Manhã, Tarde, Noite)
    final grupos = <MapEntry<String, int>>[];
    for (final h in horas) {
      final nome = faixaDoDia(h);
      if (grupos.isNotEmpty && grupos.last.key == nome) {
        grupos[grupos.length - 1] = MapEntry(nome, grupos.last.value + 1);
      } else {
        grupos.add(MapEntry(nome, 1));
      }
    }

    Widget celula(DateTime dia, int hora) {
      final v = valor(dia, hora);
      final intensidade = maximo == 0 ? 0.0 : (v / maximo).clamp(0.0, 1.0);
      final corCelula = v <= 0
          ? Colors.grey.shade100
          : Color.lerp(Cores.fundo, cor, intensidade)!;
      return Tooltip(
        message: textoDica(dia, hora),
        child: Container(
          width: _larguraCelula - 2,
          height: _alturaLinha - 2,
          margin: const EdgeInsets.all(1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: corCelula,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            v <= 0 ? '' : formatarInteiro(v.round()),
            style: TextStyle(
              fontSize: 10,
              color: intensidade > 0.55 ? Colors.white : Cores.azulEscuro,
            ),
          ),
        ),
      );
    }

    // Coluna fixa com as datas, à esquerda
    final rotulos = Column(
      children: [
        const SizedBox(width: _larguraRotulo, height: _alturaCabecalho * 2),
        for (final d in dias)
          SizedBox(
            width: _larguraRotulo,
            height: _alturaLinha,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatarDataCurta(d)} ${nomeDiaSemana(d)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );

    // Grade com as faixas, as horas e as células (rola para o lado)
    final grade = Column(
      children: [
        Row(
          children: [
            for (final g in grupos)
              Container(
                width: _larguraCelula * g.value,
                height: _alturaCabecalho,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: Cores.fundo,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  g.key,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Cores.azulEscuro,
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            for (final h in horas)
              SizedBox(
                width: _larguraCelula,
                height: _alturaCabecalho,
                child: Center(
                  child: Text(rotuloHora(h), style: const TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
        for (final d in dias)
          Row(children: [for (final h in horas) celula(d, h)]),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            rotulos,
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grade,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Legenda da escala de cores
        Row(
          children: [
            const Text('Menos', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              width: 120,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(colors: [Cores.fundo, cor]),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Mais (máximo: ${formatarInteiro(maximo.round())})',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/periodo.dart';
import '../servicos/dados_servico.dart';
import '../utils/formatadores.dart';

// Abre o calendário para escolher a data de referência.
// Devolve null se o usuário cancelar.
Future<DateTime?> escolherDataReferencia(
  BuildContext context,
  DateTime atual,
) async {
  final escolhida = await showDatePicker(
    context: context,
    initialDate: atual,
    firstDate: DadosServico.dataMinima,
    lastDate: DadosServico.dataMaxima,
    helpText: 'Data de referência',
  );
  if (escolhida == null) return null;
  return DateTime(escolhida.year, escolhida.month, escolhida.day);
}

String _textoPeriodo(JanelaDatas j) {
  if (j.quantidadeDias == 1) {
    return '${formatarData(j.inicio)} (${nomeDiaSemana(j.inicio)})';
  }
  return '${formatarData(j.inicio)} a ${formatarData(j.fim)}';
}

// Cartão do topo das telas: escolha do período (Dia/Semana/Quinzena/Mês),
// data de referência e o resumo do período mostrado.
class FiltroPeriodo extends StatelessWidget {
  final TipoPeriodo tipo;
  final DateTime dataRef;
  final JanelaDatas janela;
  final JanelaDatas? janelaAnterior;
  final bool carregando;
  final ValueChanged<TipoPeriodo> aoMudarTipo;
  final VoidCallback aoEscolherData;

  const FiltroPeriodo({
    super.key,
    required this.tipo,
    required this.dataRef,
    required this.janela,
    required this.janelaAnterior,
    required this.carregando,
    required this.aoMudarTipo,
    required this.aoEscolherData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SegmentedButton<TipoPeriodo>(
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Cores.azulMedio,
                    selectedForegroundColor: Colors.white,
                  ),
                  segments: const [
                    ButtonSegment<TipoPeriodo>(
                      value: TipoPeriodo.dia,
                      label: Text('Dia'),
                    ),
                    ButtonSegment<TipoPeriodo>(
                      value: TipoPeriodo.semana,
                      label: Text('Semana'),
                    ),
                    ButtonSegment<TipoPeriodo>(
                      value: TipoPeriodo.quinzena,
                      label: Text('Quinzena'),
                    ),
                    ButtonSegment<TipoPeriodo>(
                      value: TipoPeriodo.mes,
                      label: Text('Mês'),
                    ),
                  ],
                  selected: {tipo},
                  onSelectionChanged: (selecionado) {
                    aoMudarTipo(selecionado.first);
                  },
                ),
 ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Cores.azulEscuro,
                    side: const BorderSide(color: Cores.azulEscuro),
                  ),
                  onPressed: aoEscolherData,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Data: ${formatarData(dataRef)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Período: ${_textoPeriodo(janela)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Cores.azulEscuro,
              ),
            ),
            Text(
              janelaAnterior == null
                  ? 'Sem período anterior nos dados para comparação.'
                  : 'Comparado com: ${_textoPeriodo(janelaAnterior!)}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            if (carregando)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

// Faixa azul-clara avisando que os dados são de exemplo
class AvisoDadosExemplo extends StatelessWidget {
  const AvisoDadosExemplo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cores.azulClaro.withValues(alpha: 0.15),
        border: Border.all(color: Cores.azulClaro),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Cores.azulMedio, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dados de exemplo baseados nos relatórios de agosto/2026 '
              '(gerados pela Smart Data em ${DadosServico.atualizadoEm}). '
              'Passageiros e financeiro podem ser provisórios.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// Faixa de aviso com um texto qualquer (ex.: dados provisórios)
class AvisoInformativo extends StatelessWidget {
  final String texto;

  const AvisoInformativo({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cores.atencao.withValues(alpha: 0.10),
        border: Border.all(color: Cores.atencao),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule, color: Cores.atencao, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/periodo.dart';
import '../servicos/dados_servico.dart';
import '../utils/formatadores.dart';
import 'notificacao.dart';

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
  return escolhida == null
      ? null
      : DateTime(escolhida.year, escolhida.month, escolhida.day);
}

String _textoPeriodo(JanelaDatas j) => j.quantidadeDias == 1
    ? '${formatarData(j.inicio)} (${nomeDiaSemana(j.inicio)})'
    : '${formatarData(j.inicio)} a ${formatarData(j.fim)}';

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
    final cores = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Período',
                      style: TextStyle(
                        color: cores.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<TipoPeriodo>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: TipoPeriodo.dia,
                            label: Text('Dia'),
                          ),
                          ButtonSegment(
                            value: TipoPeriodo.semana,
                            label: Text('Semana'),
                          ),
                          ButtonSegment(
                            value: TipoPeriodo.quinzena,
                            label: Text('Quinzena'),
                          ),
                          ButtonSegment(
                            value: TipoPeriodo.mes,
                            label: Text('Mês'),
                          ),
                        ],
                        selected: {tipo},
                        onSelectionChanged: carregando
                            ? null
                            : (valores) => aoMudarTipo(valores.first),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Data de referência',
                      style: TextStyle(
                        color: cores.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: carregando ? null : aoEscolherData,
                      icon: const Icon(Icons.calendar_today_outlined, size: 17),
                      label: Text('Data: ${formatarData(dataRef)}'),
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Text(
              'Período: ${_textoPeriodo(janela)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              janelaAnterior == null
                  ? 'Sem período anterior nos dados para comparação.'
                  : 'Comparado com: ${_textoPeriodo(janelaAnterior!)}',
              style: TextStyle(color: cores.onSurfaceVariant, fontSize: 12),
            ),
            if (carregando)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class AvisoDadosExemplo extends StatelessWidget {
  const AvisoDadosExemplo({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      icon: const Icon(Icons.info_outline, size: 16),
      label: const Text('Dados de exemplo', style: TextStyle(fontSize: 12)),
      onPressed: () => abrirAviso(
        context,
        'Sobre os dados',
        'Dados de exemplo baseados nos relatórios de agosto/2026 '
            '(gerados pela Smart Data em ${DadosServico.atualizadoEm}). '
            'Passageiros e financeiro podem ser provisórios.',
      ),
    ),
  );
}

class AvisoInformativo extends StatelessWidget {
  final String texto;
  const AvisoInformativo({super.key, required this.texto});
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.notifications_none_outlined, size: 17),
    label: const Text('Ver aviso', style: TextStyle(fontSize: 12)),
    onPressed: () => abrirAviso(context, 'Aviso', texto),
  );
}

import 'dia_operacao.dart';
import 'faixa_linha.dart';
import 'faixa_sistema.dart';
import 'km_linha.dart';
import 'periodo.dart';
import 'resumo_periodo.dart';

// Tudo o que uma tela precisa para mostrar um período:
// os dias, os totais, o período anterior (para comparar), as ocorrências
// e o km por linha.
class DadosPeriodo {
  final JanelaDatas janela;
  final JanelaDatas? janelaAnterior; // null = sem dados do período anterior
  final List<DiaOperacao> dias; // dias do período escolhido
  final List<DiaOperacao> diasGrafico; // dias mostrados nos gráficos
  final List<Ocorrencia> ocorrencias;
  final List<KmLinhaDia> kmLinhas; // km produtivo por linha e dia
  final List<KmLinhaDia> kmLinhasAnterior; // o mesmo, no período anterior
  final List<Ocorrencia> ocorrenciasAnterior;
  final List<FaixaLinhaDia> faixasLinha; // viagens por linha e faixa horária
  final List<FaixaSistemaDia> faixasSistema; // viagens e veículos por faixa horária
  final ResumoPeriodo resumo;
  final ResumoPeriodo? resumoAnterior;

  DadosPeriodo({
    required this.janela,
    required this.janelaAnterior,
    required this.dias,
    required this.diasGrafico,
    required this.ocorrencias,
    required this.kmLinhas,
    required this.kmLinhasAnterior,
    required this.ocorrenciasAnterior,
    required this.faixasLinha,
    required this.faixasSistema,
    required this.resumo,
    required this.resumoAnterior,
  });
}

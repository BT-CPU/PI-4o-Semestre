import '../dados/dados_exemplo.dart';
import '../models/dados_periodo.dart';
import '../models/dia_operacao.dart';
import '../models/faixa_linha.dart';
import '../models/faixa_sistema.dart';
import '../models/km_linha.dart';
import '../models/periodo.dart';
import '../models/resumo_periodo.dart';

// TEMPORÁRIO: entrega os dados de exemplo de agosto/2026.
// Quando o back end em Python estiver pronto, cada método passa a chamar
// a API (que lê do MongoDB). As telas continuam iguais, porque já usam Future.
class DadosServico {
  // Horário em que a Smart Data gerou os relatórios de exemplo
  static const String atualizadoEm = '04/09/2026 08:00';

  static DateTime get dataMinima => diasDeExemplo.first.data;
  static DateTime get dataMaxima => diasDeExemplo.last.data;

  // Devolve os dias entre inicio e fim (incluindo os dois)
  static Future<List<DiaOperacao>> buscarDias(
    DateTime inicio,
    DateTime fim,
  ) async {
    return diasDeExemplo
        .where((d) => !d.data.isBefore(inicio) && !d.data.isAfter(fim))
        .toList();
  }

  static Future<List<Ocorrencia>> buscarOcorrencias(
    DateTime inicio,
    DateTime fim,
  ) async {
    return ocorrenciasDeExemplo
        .where((o) => !o.data.isBefore(inicio) && !o.data.isAfter(fim))
        .toList();
  }

  static Future<List<KmLinhaDia>> buscarKmLinhas(
    DateTime inicio,
    DateTime fim,
  ) async {
    return kmLinhasDeExemplo
        .where((k) => !k.data.isBefore(inicio) && !k.data.isAfter(fim))
        .toList();
  }

  static Future<List<FaixaLinhaDia>> buscarFaixasLinha(
    DateTime inicio,
    DateTime fim,
  ) async {
    return faixasLinhaDeExemplo
        .where((f) => !f.data.isBefore(inicio) && !f.data.isAfter(fim))
        .toList();
  }

  static Future<List<FaixaSistemaDia>> buscarFaixasSistema(
    DateTime inicio,
    DateTime fim,
  ) async {
    return faixasSistemaDeExemplo
        .where((f) => !f.data.isBefore(inicio) && !f.data.isAfter(fim))
        .toList();
  }

  // Monta tudo o que as telas precisam para um período
  // (usado pela Visão Geral e pela tela de Viagens).
  static Future<DadosPeriodo> carregarPeriodo(
    TipoPeriodo tipo,
    DateTime dataRef,
  ) async {
    final minima = dataMinima;
    final maxima = dataMaxima;

    // Período escolhido (sem passar do início dos dados)
    final bruta = janelaAtual(tipo, dataRef);
    final inicio = bruta.inicio.isBefore(minima) ? minima : bruta.inicio;
    final janela = JanelaDatas(inicio, bruta.fim);

    // Período anterior: só serve se estiver INTEIRO dentro dos dados
    final anterior = janelaAnterior(tipo, dataRef);
    final temAnterior =
        !anterior.inicio.isBefore(minima) && !anterior.fim.isAfter(maxima);

    final dias = await buscarDias(janela.inicio, janela.fim);
    final ocorrencias = await buscarOcorrencias(janela.inicio, janela.fim);
    final kmLinhas = await buscarKmLinhas(janela.inicio, janela.fim);

    final faixasLinha = await buscarFaixasLinha(janela.inicio, janela.fim);
    final faixasSistema = await buscarFaixasSistema(janela.inicio, janela.fim);

    var diasAnteriores = <DiaOperacao>[];
    var kmLinhasAnteriores = <KmLinhaDia>[];
    var ocorrenciasAnteriores = <Ocorrencia>[];
    if (temAnterior) {
      diasAnteriores = await buscarDias(anterior.inicio, anterior.fim);
      kmLinhasAnteriores = await buscarKmLinhas(anterior.inicio, anterior.fim);
      ocorrenciasAnteriores =
          await buscarOcorrencias(anterior.inicio, anterior.fim);
    }

    // Os gráficos precisam de pelo menos 7 dias para mostrar uma evolução.
    // Se o período é menor (ex.: "Dia"), mostra os 7 dias até a data.
    var inicioGrafico = janela.inicio;
    if (janela.quantidadeDias < 7) {
      inicioGrafico = somarDias(dataRef, -6);
      if (inicioGrafico.isBefore(minima)) inicioGrafico = minima;
    }
    final diasGrafico = await buscarDias(inicioGrafico, janela.fim);

    return DadosPeriodo(
      janela: janela,
      janelaAnterior: temAnterior ? anterior : null,
      dias: dias,
      diasGrafico: diasGrafico,
      ocorrencias: ocorrencias,
      kmLinhas: kmLinhas,
      kmLinhasAnterior: kmLinhasAnteriores,
      ocorrenciasAnterior: ocorrenciasAnteriores,
      faixasLinha: faixasLinha,
      faixasSistema: faixasSistema,
      resumo: ResumoPeriodo.dosDias(dias),
      resumoAnterior: temAnterior ? ResumoPeriodo.dosDias(diasAnteriores) : null,
    );
  }
}

import '../models/dados_periodo.dart';
import '../models/periodo.dart';
import '../models/resumo_periodo.dart';
import 'api_cliente.dart';
import 'fonte_dados.dart';

// Entrega às telas os dados de um período.
//
// De onde os dados vêm é escolhido em "fonte": o main.dart usa o servidor
// (FonteDadosApi). Se ninguém trocar, vale a fonte de exemplo, que é a que os
// testes usam. As telas não sabem a diferença.
class DadosServico {
  static FonteDados fonte = FonteDadosExemplo();

  // Chamada quando não dá para buscar os dados (servidor fora do ar, sessão
  // expirada...). O main.dart usa isto para mostrar a mensagem na tela.
  static void Function(String mensagem)? aoFalhar;

  // Depois do login: descobre o que o servidor tem (primeiro e último dia).
  static Future<void> inicializar() => fonte.inicializar();

  static bool get temDados => fonte.temDados;
  static DateTime get dataMinima => fonte.dataMinima;
  static DateTime get dataMaxima => fonte.dataMaxima;
  static String get textoAviso => fonte.textoAviso;

  // Monta tudo o que as telas precisam para um período
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

    // Os gráficos precisam de pelo menos 7 dias para mostrar uma evolução.
    // Se o período é menor (ex.: "Dia"), mostra os 7 dias até a data.
    var inicioGrafico = janela.inicio;
    if (janela.quantidadeDias < 7) {
      inicioGrafico = somarDias(dataRef, -6);
      if (inicioGrafico.isBefore(minima)) inicioGrafico = minima;
    }

    DadosBrutos brutos;
    try {
      brutos = await fonte.buscar(
        janela: janela,
        anterior: temAnterior ? anterior : null,
        inicioGrafico: inicioGrafico,
      );
    } on ErroApi catch (e) {
      aoFalhar?.call(e.mensagem);
      brutos = const DadosBrutos.vazio();
    }

    return DadosPeriodo(
      janela: janela,
      janelaAnterior: temAnterior ? anterior : null,
      dias: brutos.dias,
      diasGrafico: brutos.diasGrafico,
      ocorrencias: brutos.ocorrencias,
      kmLinhas: brutos.kmLinhas,
      kmLinhasAnterior: brutos.kmLinhasAnteriores,
      ocorrenciasAnterior: brutos.ocorrenciasAnteriores,
      faixasLinha: brutos.faixasLinha,
      faixasSistema: brutos.faixasSistema,
      resumo: ResumoPeriodo.dosDias(brutos.dias),
      resumoAnterior:
          temAnterior ? ResumoPeriodo.dosDias(brutos.diasAnteriores) : null,
    );
  }
}

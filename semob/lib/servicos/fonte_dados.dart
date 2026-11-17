import '../dados/dados_exemplo.dart';
import '../models/dia_operacao.dart';
import '../models/faixa_linha.dart';
import '../models/faixa_sistema.dart';
import '../models/km_linha.dart';
import '../models/periodo.dart';

// Tudo o que uma consulta de período devolve, ainda sem as contas (os resumos
// do período são calculados pelo DadosServico).
class DadosBrutos {
  final List<DiaOperacao> dias; // dias do período escolhido
  final List<DiaOperacao> diasAnteriores; // vazio se não há comparação
  final List<DiaOperacao> diasGrafico; // dias mostrados nos gráficos
  final List<Ocorrencia> ocorrencias;
  final List<Ocorrencia> ocorrenciasAnteriores;
  final List<KmLinhaDia> kmLinhas;
  final List<KmLinhaDia> kmLinhasAnteriores;
  final List<FaixaLinhaDia> faixasLinha;
  final List<FaixaSistemaDia> faixasSistema;

  const DadosBrutos({
    required this.dias,
    required this.diasAnteriores,
    required this.diasGrafico,
    required this.ocorrencias,
    required this.ocorrenciasAnteriores,
    required this.kmLinhas,
    required this.kmLinhasAnteriores,
    required this.faixasLinha,
    required this.faixasSistema,
  });

  // Usado quando não foi possível buscar os dados
  const DadosBrutos.vazio()
      : dias = const [],
        diasAnteriores = const [],
        diasGrafico = const [],
        ocorrencias = const [],
        ocorrenciasAnteriores = const [],
        kmLinhas = const [],
        kmLinhasAnteriores = const [],
        faixasLinha = const [],
        faixasSistema = const [];
}

// De onde vêm os dados do dashboard. Há duas fontes:
//   FonteDadosApi     -> o servidor (FastAPI + MongoDB): é a que o app usa.
//   FonteDadosExemplo -> os dados de agosto/2026 guardados no próprio app:
//                        usada pelos testes.
abstract class FonteDados {
  // Chamada depois do login: descobre o que existe no servidor.
  Future<void> inicializar();

  // false = o servidor ainda não tem nenhum dia com viagens
  bool get temDados;

  // Primeiro e último dia com dados
  DateTime get dataMinima;
  DateTime get dataMaxima;

  // Texto do aviso azul que aparece no topo das telas
  String get textoAviso;

  Future<DadosBrutos> buscar({
    required JanelaDatas janela,
    JanelaDatas? anterior,
    required DateTime inicioGrafico,
  });
}

// Os dados de exemplo (agosto/2026), guardados no próprio app.
class FonteDadosExemplo implements FonteDados {
  @override
  Future<void> inicializar() async {}

  @override
  bool get temDados => true;

  @override
  DateTime get dataMinima => diasDeExemplo.first.data;

  @override
  DateTime get dataMaxima => diasDeExemplo.last.data;

  @override
  String get textoAviso =>
      'Dados de exemplo baseados nos relatórios de agosto/2026 '
      '(gerados pela Smart Data em 04/09/2026 08:00). '
      'Passageiros e financeiro podem ser provisórios.';

  bool _entre(DateTime data, DateTime inicio, DateTime fim) {
    return !data.isBefore(inicio) && !data.isAfter(fim);
  }

  List<DiaOperacao> _dias(DateTime inicio, DateTime fim) {
    return diasDeExemplo.where((d) => _entre(d.data, inicio, fim)).toList();
  }

  List<Ocorrencia> _ocorrencias(DateTime inicio, DateTime fim) {
    return ocorrenciasDeExemplo.where((o) => _entre(o.data, inicio, fim)).toList();
  }

  List<KmLinhaDia> _km(DateTime inicio, DateTime fim) {
    return kmLinhasDeExemplo.where((k) => _entre(k.data, inicio, fim)).toList();
  }

  @override
  Future<DadosBrutos> buscar({
    required JanelaDatas janela,
    JanelaDatas? anterior,
    required DateTime inicioGrafico,
  }) async {
    return DadosBrutos(
      dias: _dias(janela.inicio, janela.fim),
      diasAnteriores: anterior == null ? [] : _dias(anterior.inicio, anterior.fim),
      diasGrafico: _dias(inicioGrafico, janela.fim),
      ocorrencias: _ocorrencias(janela.inicio, janela.fim),
      ocorrenciasAnteriores:
          anterior == null ? [] : _ocorrencias(anterior.inicio, anterior.fim),
      kmLinhas: _km(janela.inicio, janela.fim),
      kmLinhasAnteriores: anterior == null ? [] : _km(anterior.inicio, anterior.fim),
      faixasLinha: faixasLinhaDeExemplo
          .where((f) => _entre(f.data, janela.inicio, janela.fim))
          .toList(),
      faixasSistema: faixasSistemaDeExemplo
          .where((f) => _entre(f.data, janela.inicio, janela.fim))
          .toList(),
    );
  }
}

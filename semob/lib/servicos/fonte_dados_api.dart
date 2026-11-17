import '../models/dia_operacao.dart';
import '../models/faixa_linha.dart';
import '../models/faixa_sistema.dart';
import '../models/km_linha.dart';
import '../models/periodo.dart';
import '../utils/formatadores.dart';
import 'api_cliente.dart';
import 'fonte_dados.dart';

// Função que faz uma requisição à API. Normalmente é o ApiCliente; os testes
// trocam por uma que devolve respostas prontas.
typedef Requisitar = Future<RespostaApi> Function(String metodo, String caminho);

// Busca os dados no servidor (FastAPI + MongoDB).
//   GET /dados/disponibilidade -> primeiro e último dia com dados
//   GET /dados/periodo         -> tudo o que uma tela precisa de um período
class FonteDadosApi implements FonteDados {
  final Requisitar _requisitar;

  FonteDadosApi({Requisitar? requisitar})
      : _requisitar = requisitar ?? ((m, c) => ApiCliente.requisitar(m, c));

  static const String _formatoInesperado =
      'O servidor devolveu dados em um formato inesperado.';

  bool _temDados = false;
  DateTime _minima = _hoje();
  DateTime _maxima = _hoje();
  String _aviso = '';

  static DateTime _hoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  @override
  bool get temDados => _temDados;

  @override
  DateTime get dataMinima => _minima;

  @override
  DateTime get dataMaxima => _maxima;

  @override
  String get textoAviso => _aviso;

  @override
  Future<void> inicializar() async {
    final r = await _requisitar('GET', '/dados/disponibilidade');
    if (!r.ok) throw ErroApi(r.mensagemErro);

    try {
      final c = r.corpo as Map<String, dynamic>;
      _temDados = c['temDados'] == true;
      if (!_temDados) {
        _minima = _hoje();
        _maxima = _minima;
        _aviso = 'Ainda não há dados no sistema. Use "Enviar arquivos" para '
            'enviar os relatórios da Smart Data.';
        return;
      }
      _minima = _data(c['dataMinima']);
      _maxima = _data(c['dataMaxima']);
      _aviso = _montarAviso(c);
    } on TypeError {
      throw ErroApi(_formatoInesperado);
    } on FormatException {
      throw ErroApi(_formatoInesperado);
    }
  }

  String _montarAviso(Map<String, dynamic> c) {
    final texto = StringBuffer(
      'Dados da Smart Data de ${formatarData(_minima)} a ${formatarData(_maxima)}',
    );
    final geradoEm = c['atualizadoEm'];
    if (geradoEm is String) {
      final g = DateTime.parse(geradoEm);
      texto.write(
        ' (relatório mais recente gerado em ${formatarData(g)} '
        '${doisDigitos(g.hour)}:${doisDigitos(g.minute)})',
      );
    }
    texto.write('. ');

    // Passageiros e saldo podem começar depois do primeiro dia de viagens
    final passageiros = c['passageirosDesde'];
    if (passageiros is String && _data(passageiros).isAfter(_minima)) {
      texto.write('Passageiros disponíveis a partir de '
          '${formatarData(_data(passageiros))}. ');
    }
    final saldo = c['saldoDesde'];
    if (saldo is String && _data(saldo).isAfter(_minima)) {
      texto.write('Saldo do sistema a partir de ${formatarData(_data(saldo))}. ');
    }
    texto.write('Os últimos dias podem ser provisórios.');
    return texto.toString();
  }

  @override
  Future<DadosBrutos> buscar({
    required JanelaDatas janela,
    JanelaDatas? anterior,
    required DateTime inicioGrafico,
  }) async {
    final parametros = <String, String>{
      'inicio': _texto(janela.inicio),
      'fim': _texto(janela.fim),
      'grafico_inicio': _texto(inicioGrafico),
    };
    if (anterior != null) {
      parametros['anterior_inicio'] = _texto(anterior.inicio);
      parametros['anterior_fim'] = _texto(anterior.fim);
    }

    final caminho = Uri(path: '/dados/periodo', queryParameters: parametros).toString();
    final r = await _requisitar('GET', caminho);
    if (!r.ok) throw ErroApi(r.mensagemErro);

    try {
      final c = r.corpo as Map<String, dynamic>;
      return DadosBrutos(
        dias: _lista(c['dias'], _dia),
        diasAnteriores: _lista(c['diasAnteriores'], _dia),
        diasGrafico: _lista(c['diasGrafico'], _dia),
        ocorrencias: _lista(c['ocorrencias'], _ocorrencia),
        ocorrenciasAnteriores: _lista(c['ocorrenciasAnteriores'], _ocorrencia),
        kmLinhas: _lista(c['kmLinhas'], _kmLinha),
        kmLinhasAnteriores: _lista(c['kmLinhasAnteriores'], _kmLinha),
        faixasLinha: _lista(c['faixasLinha'], _faixaLinha),
        faixasSistema: _lista(c['faixasSistema'], _faixaSistema),
      );
    } on TypeError {
      throw ErroApi(_formatoInesperado);
    } on FormatException {
      throw ErroApi(_formatoInesperado);
    } on ArgumentError {
      throw ErroApi(_formatoInesperado); // ex.: tipo de ocorrência desconhecido
    }
  }

  // ------------------------------------------------------------
  // JSON -> classes do app
  // ------------------------------------------------------------
  static String _texto(DateTime data) {
    return '${data.year.toString().padLeft(4, '0')}-${doisDigitos(data.month)}-${doisDigitos(data.day)}';
  }

  // "2026-08-01" -> 01/08/2026 à meia-noite, no horário local
  static DateTime _data(Object? valor) => DateTime.parse(valor as String);

  static DateTime? _dataHora(Object? valor) {
    return valor == null ? null : DateTime.parse(valor as String);
  }

  static double _dec(Object? valor) => (valor as num).toDouble();

  static int _int(Object? valor) => (valor as num).toInt();

  static List<T> _lista<T>(Object? json, T Function(Map<String, dynamic>) converter) {
    return [for (final item in json as List) converter(item as Map<String, dynamic>)];
  }

  static DiaOperacao _dia(Map<String, dynamic> j) {
    return DiaOperacao(
      data: _data(j['data']),
      veiculos: _int(j['veiculos']),
      maxVeiculosFaixa: _int(j['maxVeiculosFaixa']),
      viagensProgramadas: _int(j['viagensProgramadas']),
      viagensRealizadas: _int(j['viagensRealizadas']),
      manhaProgramadas: _int(j['manhaProgramadas']),
      manhaRealizadas: _int(j['manhaRealizadas']),
      tardeProgramadas: _int(j['tardeProgramadas']),
      tardeRealizadas: _int(j['tardeRealizadas']),
      noiteProgramadas: _int(j['noiteProgramadas']),
      noiteRealizadas: _int(j['noiteRealizadas']),
      kmProdutivo: _dec(j['kmProdutivo']),
      kmImprodutivo: _dec(j['kmImprodutivo']),
      passageirosCatraca: _int(j['passageirosCatraca']),
      passageirosAntecipados: _int(j['passageirosAntecipados']),
      passageirosNaoPagantes: _int(j['passageirosNaoPagantes']),
      vendas: _dec(j['vendas']),
      utilizacao: _dec(j['utilizacao']),
      creditosTransferidos: _dec(j['creditosTransferidos']),
      saldoSistema: _dec(j['saldoSistema']),
    );
  }

  static Ocorrencia _ocorrencia(Map<String, dynamic> j) {
    return Ocorrencia(
      data: _data(j['data']),
      linha: j['linha'] as String,
      tipo: TipoOcorrencia.values.byName(j['tipo'] as String),
      atendimento: j['atendimento'] as String,
      prefixo: j['prefixo'] as String,
      motorista: j['motorista'] as String,
      sentido: j['sentido'] as String,
      tabela: j['tabela'] as String,
      inicioProgramado: _dataHora(j['inicioProgramado']),
      inicioRealizado: _dataHora(j['inicioRealizado']),
      fimProgramado: _dataHora(j['fimProgramado']),
      fimRealizado: _dataHora(j['fimRealizado']),
    );
  }

  static KmLinhaDia _kmLinha(Map<String, dynamic> j) {
    return KmLinhaDia(
      data: _data(j['data']),
      linha: j['linha'] as String,
      kmProdutivo: _dec(j['kmProdutivo']),
      viagens: _int(j['viagens']),
    );
  }

  static FaixaLinhaDia _faixaLinha(Map<String, dynamic> j) {
    return FaixaLinhaDia(
      data: _data(j['data']),
      linha: j['linha'] as String,
      hora: _int(j['hora']),
      veiculos: _int(j['veiculos']),
      viagens: _int(j['viagens']),
    );
  }

  static FaixaSistemaDia _faixaSistema(Map<String, dynamic> j) {
    return FaixaSistemaDia(
      data: _data(j['data']),
      hora: _int(j['hora']),
      veiculos: _int(j['veiculos']),
      viagens: _int(j['viagens']),
    );
  }
}

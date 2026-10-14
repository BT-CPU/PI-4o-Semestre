import 'package:file_picker/file_picker.dart';

// Situação de cada arquivo na lista de envio
enum StatusEnvio { pendente, enviando, enviado, erro }

// Informações descobertas a partir do NOME do arquivo.
// Exemplo: "Mensal_Viagens_202608.html" -> Mensal, Viagens (detalhe), 2026-08
class InfoRelatorio {
  final String periodicidade; // Mensal, Quinzenal ou Semanal
  final String tipo; // Qual relatório é
  final String? periodo; // "2026-08" (null quando o nome não traz a data)

  InfoRelatorio({
    required this.periodicidade,
    required this.tipo,
    required this.periodo,
  });

  // Devolve null se o nome não for de um relatório conhecido.
  static InfoRelatorio? doNome(String nomeArquivo) {
    final nome = nomeArquivo.toLowerCase();

    if (!nome.endsWith('.html') && !nome.endsWith('.htm')) {
      return null;
    }

    // 1) Periodicidade
    String? periodicidade;
    if (nome.contains('mensal')) {
      periodicidade = 'Mensal';
    } else if (nome.contains('quinzenal')) {
      periodicidade = 'Quinzenal';
    } else if (nome.contains('semanal')) {
      periodicidade = 'Semanal';
    }
    if (periodicidade == null) {
      return null;
    }

    // 2) Tipo do relatório.
    // A ordem importa: "resumo_fxhr" precisa ser testado antes de "fxhr",
    // porque o nome do primeiro também contém o segundo.
    String? tipo;
    if (nome.contains('passageiros')) {
      tipo = 'Passageiros';
    } else if (nome.contains('saldos')) {
      tipo = 'Financeiro (saldos)';
    } else if (nome.contains('resumo_fxhr')) {
      tipo = 'Resumo por faixa horária';
    } else if (nome.contains('fxhr')) {
      tipo = 'Partidas por faixa horária';
    } else if (nome.contains('viag_nrealiz')) {
      tipo = 'Viagens não realizadas';
    } else if (nome.contains('viag_ninic')) {
      tipo = 'Viagens não iniciadas';
    } else if (nome.contains('viag_nterm')) {
      tipo = 'Viagens não terminadas';
    } else if (nome.contains('viagens')) {
      tipo = 'Viagens (detalhe)';
    } else if (nome.contains('linhas')) {
      tipo = 'Resumo por linha';
    } else if (nome.contains('fcv')) {
      tipo = 'Fator de cumprimento de viagem';
    } else if (RegExp(r'^(mensal|quinzenal|semanal)_\d{6}\.html?$')
        .hasMatch(nome)) {
      // Ex.: mensal_202608.html (só a periodicidade e a data)
      tipo = 'Resumo geral';
    }
    if (tipo == null) {
      return null;
    }

    // 3) Período (AAAAMM no nome), se existir
    String? periodo;
    final achou = RegExp(r'_(\d{4})(\d{2})\.').firstMatch(nome);
    if (achou != null) {
      periodo = '${achou.group(1)}-${achou.group(2)}';
    }

    return InfoRelatorio(
      periodicidade: periodicidade,
      tipo: tipo,
      periodo: periodo,
    );
  }
}

// Um arquivo escolhido pelo funcionário, esperando para ser enviado
class ArquivoSelecionado {
  final PlatformFile arquivo;
  final int tamanhoBytes;
  final InfoRelatorio info;
  StatusEnvio status = StatusEnvio.pendente;
  String? mensagem; // mensagem de erro, se houver

  ArquivoSelecionado({
    required this.arquivo,
    required this.tamanhoBytes,
    required this.info,
  });

  String get nome => arquivo.name;
}

// Transforma bytes em texto legível: 1536 -> "1,5 KB"
String formatarTamanho(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

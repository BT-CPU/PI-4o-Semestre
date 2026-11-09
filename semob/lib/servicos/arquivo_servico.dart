import 'dart:convert';

import '../models/arquivo_selecionado.dart';
import 'api_cliente.dart';

// Envia o relatório para a API (POST /importacoes). É a API que lê o HTML,
// confere os números e grava no MongoDB.
//
// Devolve:
//   null        -> deu certo (os avisos da API ficam em item.avisos)
//   uma String  -> mensagem de erro
class ArquivoServico {
  static Future<String?> enviar(
    ArquivoSelecionado item, {
    bool forcar = false,
  }) async {
    item.avisos = [];
    item.resultado = null;

    final List<int> bytes;
    try {
      bytes = await item.arquivo.readAsBytes();
    } catch (_) {
      return 'Não foi possível ler o arquivo.';
    }

    if (bytes.isEmpty) {
      return 'O arquivo está vazio.';
    }

    // Confere rápido, antes de enviar, se parece mesmo um relatório da Smart
    // Data: todos trazem o nome "SmartDataSource" logo no começo. Os arquivos
    // usam a codificação Cp1252, por isso uso latin1 aqui. (A API confere de
    // novo, com mais rigor.)
    final tamanhoInicio = bytes.length < 4000 ? bytes.length : 4000;
    final inicio = latin1.decode(bytes.sublist(0, tamanhoInicio));
    if (!inicio.contains('SmartDataSource')) {
      return 'O conteúdo não parece um relatório da Smart Data.';
    }

    try {
      final r = await ApiCliente.enviarArquivo(
        '/importacoes',
        nomeArquivo: item.nome,
        bytes: bytes,
        parametros: forcar ? {'forcar': 'true'} : const {},
      );
      if (!r.ok) return r.mensagemErro;

      final corpo = r.corpo;
      if (corpo is Map) {
        final avisos = corpo['avisos'];
        if (avisos is List) {
          item.avisos = [for (final a in avisos) a.toString()];
        }
        item.resultado = corpo['status'] == 'duplicada'
            ? 'Este arquivo já tinha sido enviado antes: nada foi alterado.'
            : 'Enviado com sucesso';
      }
      return null;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }
}

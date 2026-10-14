import 'dart:convert';

import '../models/arquivo_selecionado.dart';

// TEMPORÁRIO: simula o envio do arquivo para o servidor.
// Quando o back end em Python estiver pronto, o trecho "simula o envio"
// vira uma requisição HTTP (multipart) mandando os bytes para a API,
// e é a API que lê o HTML e grava os dados no MongoDB.
//
// Devolve:
//   null        -> deu certo
//   uma String  -> mensagem de erro
class ArquivoServico {
  static Future<String?> enviar(ArquivoSelecionado item) async {
    try {
      final bytes = await item.arquivo.readAsBytes();

      if (bytes.isEmpty) {
        return 'O arquivo está vazio.';
      }

      // Confere se parece mesmo um relatório da Smart Data:
      // todos eles trazem o nome "SmartDataSource" logo no começo.
      // Os arquivos usam a codificação Cp1252, por isso uso latin1 aqui.
      final tamanhoInicio = bytes.length < 4000 ? bytes.length : 4000;
      final inicio = latin1.decode(bytes.sublist(0, tamanhoInicio));
      if (!inicio.contains('SmartDataSource')) {
        return 'O conteúdo não parece um relatório da Smart Data.';
      }
    } catch (e) {
      return 'Não foi possível ler o arquivo.';
    }

    // Simula o envio para o servidor
    await Future.delayed(const Duration(milliseconds: 700));
    return null;
  }
}

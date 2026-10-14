import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/dia_operacao.dart';

// Cor de cada tipo de ocorrência (usada nos gráficos, na legenda e na tabela)
Color corTipoOcorrencia(TipoOcorrencia tipo) {
  switch (tipo) {
    case TipoOcorrencia.naoRealizada:
      return Cores.atencao;
    case TipoOcorrencia.naoIniciada:
      return Cores.azulClaro;
    case TipoOcorrencia.naoTerminada:
      return Cores.azulEscuro;
  }
}

String nomeTipoOcorrencia(TipoOcorrencia tipo) {
  switch (tipo) {
    case TipoOcorrencia.naoRealizada:
      return 'Não realizada';
    case TipoOcorrencia.naoIniciada:
      return 'Não iniciada';
    case TipoOcorrencia.naoTerminada:
      return 'Não terminada';
  }
}

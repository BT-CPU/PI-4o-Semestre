import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _janela = MethodChannel('semob/janela');
bool _imersivo = false;

bool get suportaTelaCheia => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.android ||
  TargetPlatform.iOS => true,
  _ => false,
};

Future<bool> emTelaCheia() async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return await _janela.invokeMethod<bool>('emTelaCheia') ?? false;
  }
  return _imersivo;
}

Future<bool> definirTelaCheia(bool ativar) async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return await _janela.invokeMethod<bool>('telaCheia', ativar) ?? false;
  }
  await SystemChrome.setEnabledSystemUIMode(
    ativar ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  );
  _imersivo = ativar;
  return ativar;
}

import 'dart:js_interop';

@JS('semobTelaCheia')
external JSPromise<JSBoolean> _telaCheia(JSBoolean ativar);

@JS('semobEmTelaCheia')
external JSBoolean _emTelaCheia();

@JS('semobSuportaTelaCheia')
external JSBoolean _suportaTelaCheia();

bool get suportaTelaCheia => _suportaTelaCheia().toDart;
Future<bool> emTelaCheia() async => _emTelaCheia().toDart;
Future<bool> definirTelaCheia(bool ativar) async =>
    (await _telaCheia(ativar.toJS).toDart).toDart;

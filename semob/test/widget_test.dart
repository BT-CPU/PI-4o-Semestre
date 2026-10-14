import 'package:flutter_test/flutter_test.dart';

import 'package:semob/main.dart';

// Este arquivo SUBSTITUI o widget_test.dart que o "flutter create" gera
// (aquele testa um contador e não funciona mais neste projeto).
// Se a logo não estiver nos "assets" do pubspec.yaml, o app mostra um ícone no
// lugar (veja LogoSemob), e estes testes continuam passando.
void main() {
  testWidgets('a tela de login aparece ao abrir o app', (tester) async {
    await tester.pumpWidget(const MeuApp());

    expect(find.text('Dashboard de Operação de Transporte'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Acesso do administrador'), findsOneWidget);
  });

  testWidgets('login sem preencher mostra os avisos de campo obrigatório', (tester) async {
    await tester.pumpWidget(const MeuApp());

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Digite o usuário'), findsOneWidget);
    expect(find.text('Digite a senha'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';

import '../cores.dart';
import '../servicos/sessao.dart';
import '../telas/tela_admin.dart';
import '../telas/tela_faixas.dart';
import '../telas/tela_financeiro.dart';
import '../telas/tela_linhas.dart';
import '../telas/tela_login.dart';
import '../telas/tela_ocorrencias.dart';
import '../telas/tela_passageiros.dart';
import '../telas/tela_quilometragem.dart';
import '../telas/tela_upload.dart';
import '../telas/tela_viagens.dart';
import '../telas/tela_visao_geral.dart';
import 'logo_semob.dart';

class _ItemMenu {
  final IconData icone;
  final String titulo;

  const _ItemMenu(this.icone, this.titulo);
}

// Menu lateral (gaveta) usado em todas as telas do dashboard.
// Os itens ainda sem tela mostram o aviso "em construção".
class MenuDashboard extends StatelessWidget {
  final String nomeUsuario;
  final String itemAtual; // título do item que está aberto

  const MenuDashboard({
    super.key,
    required this.nomeUsuario,
    this.itemAtual = 'Visão geral',
  });

  static const List<_ItemMenu> _itens = [
    _ItemMenu(Icons.dashboard, 'Visão geral'),
    _ItemMenu(Icons.directions_bus, 'Viagens e cumprimento'),
    _ItemMenu(Icons.route, 'Quilometragem'),
    _ItemMenu(Icons.groups, 'Passageiros'),
    _ItemMenu(Icons.attach_money, 'Financeiro'),
    _ItemMenu(Icons.alt_route, 'Linhas'),
    _ItemMenu(Icons.schedule, 'Faixas horárias'),
    _ItemMenu(Icons.report_problem, 'Ocorrências'),
  ];

  // Devolve a tela do item, ou null se ela ainda não foi feita
  Widget? _telaDoItem(String titulo) {
    switch (titulo) {
      case 'Visão geral':
        return TelaVisaoGeral(nomeUsuario: nomeUsuario);
      case 'Viagens e cumprimento':
        return TelaViagens(nomeUsuario: nomeUsuario);
      case 'Quilometragem':
        return TelaQuilometragem(nomeUsuario: nomeUsuario);
      case 'Passageiros':
        return TelaPassageiros(nomeUsuario: nomeUsuario);
      case 'Financeiro':
        return TelaFinanceiro(nomeUsuario: nomeUsuario);
      case 'Linhas':
        return TelaLinhas(nomeUsuario: nomeUsuario);
      case 'Faixas horárias':
        return TelaFaixas(nomeUsuario: nomeUsuario);
      case 'Ocorrências':
        return TelaOcorrencias(nomeUsuario: nomeUsuario);
      default:
        return null;
    }
  }

  void _abrirItem(BuildContext context, _ItemMenu item) {
    // Guarda antes de fechar o menu, porque depois o context some
    final navegador = Navigator.of(context);
    final mensagens = ScaffoldMessenger.of(context);
    navegador.pop(); // fecha o menu

    if (item.titulo == itemAtual) return; // já está nesta tela

    final tela = _telaDoItem(item.titulo);
    if (tela == null) {
      mensagens.showSnackBar(
        SnackBar(
          content: Text('${item.titulo}: tela em construção.'),
          backgroundColor: Cores.azulEscuro,
        ),
      );
      return;
    }

    // pushReplacement troca a tela atual pela nova (não empilha telas)
    navegador.pushReplacement(MaterialPageRoute(builder: (context) => tela));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: const LogoSemob(altura: 120),
            ),
            Text(
              'Olá, $nomeUsuario',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Cores.azulEscuro,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  for (final item in _itens)
                    ListTile(
                      leading: Icon(item.icone),
                      title: Text(item.titulo),
                      selected: item.titulo == itemAtual,
                      selectedColor: Cores.azulEscuro,
                      selectedTileColor: Cores.fundo,
                      onTap: () => _abrirItem(context, item),
                    ),
                ],
              ),
            ),
            const Divider(),
            // Só administradores veem esta opção (a proteção de verdade
            // precisa ser feita no back end)
            if (Sessao.ehAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Administração de usuários'),
                onTap: () {
                  final navegador = Navigator.of(context);
                  navegador.pop(); // fecha o menu
                  navegador.push(
                    MaterialPageRoute(builder: (context) => const TelaAdmin()),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Enviar arquivos'),
              onTap: () {
                final navegador = Navigator.of(context);
                navegador.pop(); // fecha o menu
                navegador.push(
                  MaterialPageRoute(builder: (context) => const TelaUpload()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () {
                Sessao.sair();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaLogin()),
                  (rota) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

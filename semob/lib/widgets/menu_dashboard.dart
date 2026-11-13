import 'package:flutter/material.dart';

import '../servicos/preferencias_visuais.dart';
import '../telas/tela_faixas.dart';
import '../telas/tela_financeiro.dart';
import '../telas/tela_linhas.dart';
import '../telas/tela_ocorrencias.dart';
import '../telas/tela_passageiros.dart';
import '../telas/tela_quilometragem.dart';
import '../telas/tela_viagens.dart';
import '../telas/tela_visao_geral.dart';
import 'logo_semob.dart';
import 'marca_institucional.dart';

class _ItemMenu {
  final IconData icone;
  final String titulo;
  const _ItemMenu(this.icone, this.titulo);
}

class MenuDashboard extends StatelessWidget {
  final String nomeUsuario;
  final bool fixo;
  final bool recolhido;
  final String itemAtual;

  const MenuDashboard({
    super.key,
    required this.nomeUsuario,
    this.itemAtual = 'Visão Geral',
    this.fixo = false,
    this.recolhido = false,
  });

  static const _itens = [
    _ItemMenu(Icons.space_dashboard_outlined, 'Visão Geral'),
    _ItemMenu(Icons.directions_bus_outlined, 'Viagens e Cumprimentos'),
    _ItemMenu(Icons.route_outlined, 'Quilometragem'),
    _ItemMenu(Icons.groups_outlined, 'Passageiros'),
    _ItemMenu(Icons.account_balance_wallet_outlined, 'Financeiro'),
    _ItemMenu(Icons.alt_route, 'Linhas'),
    _ItemMenu(Icons.schedule_outlined, 'Faixas Horárias'),
    _ItemMenu(Icons.report_problem_outlined, 'Ocorrências'),
  ];

  Widget _telaDoItem(String titulo) => switch (titulo) {
    'Visão Geral' => TelaVisaoGeral(nomeUsuario: nomeUsuario),
    'Viagens e Cumprimentos' => TelaViagens(nomeUsuario: nomeUsuario),
    'Quilometragem' => TelaQuilometragem(nomeUsuario: nomeUsuario),
    'Passageiros' => TelaPassageiros(nomeUsuario: nomeUsuario),
    'Financeiro' => TelaFinanceiro(nomeUsuario: nomeUsuario),
    'Linhas' => TelaLinhas(nomeUsuario: nomeUsuario),
    'Faixas Horárias' => TelaFaixas(nomeUsuario: nomeUsuario),
    _ => TelaOcorrencias(nomeUsuario: nomeUsuario),
  };

  void _abrirItem(BuildContext context, _ItemMenu item) {
    final navegador = Navigator.of(context);
    if (!fixo) Scaffold.of(context).closeDrawer();
    if (item.titulo == itemAtual) return;
    navegador.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => _telaDoItem(item.titulo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: cores.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            if (recolhido)
              const Padding(
                padding: EdgeInsets.only(top: 22, bottom: 12),
                child: LogoSemob(altura: 36),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 26, 20, 16),
                child: MarcaInstitucional(compacta: true),
              ),
            Align(
              alignment: recolhido ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                tooltip: fixo
                    ? (recolhido ? 'Expandir menu' : 'Minimizar menu')
                    : 'Fechar menu',
                icon: Icon(
                  recolhido
                      ? Icons.menu_open
                      : fixo
                      ? Icons.chevron_left
                      : Icons.close,
                ),
                onPressed: () => fixo
                    ? PreferenciasVisuais.instancia.alternarMenu()
                    : Scaffold.of(context).closeDrawer(),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final item in _itens)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: recolhido ? 12 : 14,
                        vertical: 3,
                      ),
                      child: recolhido
                          ? IconButton(
                              tooltip: item.titulo,
                              style: IconButton.styleFrom(
                                foregroundColor: item.titulo == itemAtual
                                    ? cores.primary
                                    : cores.onSurfaceVariant,
                                backgroundColor: item.titulo == itemAtual
                                    ? cores.primaryContainer
                                    : Colors.transparent,
                                minimumSize: const Size(52, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(item.icone, size: 22),
                              onPressed: () => _abrirItem(context, item),
                            )
                          : ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(item.icone, size: 21),
                              title: Text(
                                item.titulo,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              selected: item.titulo == itemAtual,
                              selectedColor: cores.primary,
                              selectedTileColor: cores.primaryContainer,
                              onTap: () => _abrirItem(context, item),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

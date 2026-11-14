import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/usuario.dart';
import '../servicos/sessao.dart';
import '../servicos/usuario_servico.dart';
import '../widgets/appbar_semob.dart';
import 'formulario_usuario.dart';
import 'tela_login.dart';
import 'tela_upload.dart';
import 'tela_visao_geral.dart';
import '../servicos/api_cliente.dart';

// Tela do administrador: CRUD de usuários
// C = criar (botão "Novo usuário")
// R = ler (a lista, com busca)
// U = atualizar (ícone de lápis)
// D = deletar (ícone de lixeira)
class TelaAdmin extends StatefulWidget {
  const TelaAdmin({super.key});

  @override
  State<TelaAdmin> createState() => _TelaAdminState();
}

class _TelaAdminState extends State<TelaAdmin> {
  final _buscaController = TextEditingController();

  List<Usuario> _usuarios = [];
  bool _carregando = true;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final lista = await UsuarioServico.listar();
      if (!mounted) return;
      setState(() {
        _usuarios = lista;
        _carregando = false;
      });
    } on ErroApi catch (e) {
      // API fora do ar, sem rede, sessão expirada...
      if (!mounted) return;
      setState(() {
        _carregando = false;
      });
      _mostrarMensagem(e.mensagem, ehErro: true);
    }
  }

  // Lista já filtrada pelo texto da busca (nome ou login)
  List<Usuario> get _usuariosFiltrados {
    final termo = _busca.toLowerCase();
    return _usuarios
        .where(
          (u) =>
              u.nome.toLowerCase().contains(termo) ||
              u.usuario.toLowerCase().contains(termo),
        )
        .toList();
  }

  void _mostrarMensagem(String texto, {bool ehErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: ehErro ? Cores.erro : Cores.azulEscuro,
      ),
    );
  }

  // Abre o formulário. Sem parâmetro = novo usuário; com usuário = edição.
  Future<void> _abrirFormulario({Usuario? usuario}) async {
    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FormularioUsuario(usuarioExistente: usuario),
    );

    if (salvou == true) {
      await _carregarUsuarios();
      if (!mounted) return;
      _mostrarMensagem(
        usuario == null
            ? 'Usuário cadastrado com sucesso.'
            : 'Usuário atualizado com sucesso.',
      );
    }
  }

  Future<void> _confirmarExclusao(Usuario usuario) async {
    // Quem está logado não pode apagar a si mesmo (ficaria sem acesso)
    if (usuario.id == Sessao.usuarioAtual?.id) {
      _mostrarMensagem('Você não pode excluir o seu próprio usuário.', ehErro: true);
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Excluir usuário'),
        content: Text(
          'Deseja realmente excluir "${usuario.nome}"? '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Cores.erro,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    final erro = await UsuarioServico.excluir(usuario.id);
    if (!mounted) return;

    if (erro != null) {
      _mostrarMensagem(erro, ehErro: true);
      return;
    }

    await _carregarUsuarios();
    if (!mounted) return;
    _mostrarMensagem('Usuário excluído.');
  }

  Widget _cartaoUsuario(Usuario u) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: u.ehAdmin ? Cores.azulEscuro : Cores.azulMedio,
          foregroundColor: Colors.white,
          child: Icon(u.ehAdmin ? Icons.admin_panel_settings : Icons.person),
        ),
        title: Text(
          u.nome,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Usuário: ${u.usuario}  |  ${u.email}\n'
          'Perfil: ${u.ehAdmin ? 'Administrador' : 'Funcionário'}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Cores.azulMedio),
              tooltip: 'Editar',
              onPressed: () => _abrirFormulario(usuario: u),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Cores.erro),
              tooltip: 'Excluir',
              onPressed: () => _confirmarExclusao(u),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _usuariosFiltrados;

    return Scaffold(
      appBar: AppBarSemob(
        titulo: 'Administração de usuários',
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Ir para o dashboard',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaVisaoGeral(
                    nomeUsuario: Sessao.usuarioAtual?.usuario ?? '',
                  ),
                ),
                (rota) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Enviar arquivos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaUpload()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              Sessao.sair();
              // Remove todas as telas da pilha e volta para o login
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const TelaLogin()),
                (rota) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha com a busca e o botão de novo usuário
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscaController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome ou usuário',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (texto) {
                          setState(() {
                            _busca = texto;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Cores.azulEscuro,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: () => _abrirFormulario(),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Novo usuário'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${lista.length} usuário(s)',
                  style: const TextStyle(color: Cores.azulEscuro),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _carregando
                      ? const Center(child: CircularProgressIndicator())
                      : lista.isEmpty
                          ? const Center(
                              child: Text('Nenhum usuário encontrado.'),
                            )
                          : ListView.builder(
                              itemCount: lista.length,
                              itemBuilder: (context, indice) {
                                return _cartaoUsuario(lista[indice]);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

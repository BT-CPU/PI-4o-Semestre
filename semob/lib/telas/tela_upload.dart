import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../cores.dart';
import '../models/arquivo_selecionado.dart';
import '../servicos/arquivo_servico.dart';
import '../servicos/sessao.dart';
import '../widgets/appbar_semob.dart';
import 'tela_login.dart';

// Tela onde os funcionários escolhem os relatórios da Smart Data (.html)
// e enviam para o sistema gravar no banco de dados.
class TelaUpload extends StatefulWidget {
  const TelaUpload({super.key});

  @override
  State<TelaUpload> createState() => _TelaUploadState();
}

class _TelaUploadState extends State<TelaUpload> {
  final List<ArquivoSelecionado> _arquivos = [];
  bool _enviando = false;

  // Arquivos que ainda precisam ser enviados (novos ou que deram erro)
  List<ArquivoSelecionado> get _paraEnviar {
    return _arquivos
        .where(
          (a) =>
              a.status == StatusEnvio.pendente || a.status == StatusEnvio.erro,
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

  Future<void> _selecionarArquivos() async {
    // Abre a janela do sistema para escolher os arquivos.
    // Se o usuário cancelar, a lista volta vazia.
    final escolhidos = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
    );

    if (escolhidos.isEmpty) return;

    final novos = <ArquivoSelecionado>[];
    final naoReconhecidos = <String>[];
    var repetidos = 0;

    for (final f in escolhidos) {
      // Não deixa colocar o mesmo arquivo duas vezes
      final jaExiste = _arquivos.any((a) => a.nome == f.name) ||
          novos.any((a) => a.nome == f.name);
      if (jaExiste) {
        repetidos++;
        continue;
      }

      // Descobre o tipo de relatório pelo nome do arquivo
      final info = InfoRelatorio.doNome(f.name);
      if (info == null) {
        naoReconhecidos.add(f.name);
        continue;
      }

      final tamanho = await f.length();
      novos.add(
        ArquivoSelecionado(arquivo: f, tamanhoBytes: tamanho, info: info),
      );
    }

    if (!mounted) return;

    setState(() {
      _arquivos.addAll(novos);
    });

    // Avisa o que foi deixado de fora
    final avisos = <String>[];
    if (naoReconhecidos.isNotEmpty) {
      avisos.add('Nome não reconhecido: ${naoReconhecidos.join(', ')}.');
    }
    if (repetidos > 0) {
      avisos.add('$repetidos arquivo(s) já estava(m) na lista.');
    }
    if (avisos.isNotEmpty) {
      _mostrarMensagem(avisos.join(' '), ehErro: true);
    }
  }

  Future<void> _enviarTodos() async {
    final pendentes = _paraEnviar;
    if (pendentes.isEmpty) return;

    setState(() {
      _enviando = true;
    });

    var certos = 0;
    var falhas = 0;

    // Envia um de cada vez, atualizando o status na tela
    for (final a in pendentes) {
      setState(() {
        a.status = StatusEnvio.enviando;
        a.mensagem = null;
      });

      final erro = await ArquivoServico.enviar(a);
      if (!mounted) return;

      setState(() {
        if (erro == null) {
          a.status = StatusEnvio.enviado;
          certos++;
        } else {
          a.status = StatusEnvio.erro;
          a.mensagem = erro;
          falhas++;
        }
      });
    }

    setState(() {
      _enviando = false;
    });

    if (falhas == 0) {
      _mostrarMensagem('$certos arquivo(s) enviado(s) com sucesso.');
    } else {
      _mostrarMensagem(
        '$certos enviado(s) e $falhas com erro. Veja os detalhes na lista.',
        ehErro: true,
      );
    }
  }

  void _remover(ArquivoSelecionado a) {
    setState(() {
      _arquivos.remove(a);
    });
  }

  void _limparEnviados() {
    setState(() {
      _arquivos.removeWhere((a) => a.status == StatusEnvio.enviado);
    });
  }

  Widget _iconeStatus(ArquivoSelecionado a) {
    switch (a.status) {
      case StatusEnvio.pendente:
        return const Icon(Icons.insert_drive_file, color: Cores.azulMedio);
      case StatusEnvio.enviando:
        return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case StatusEnvio.enviado:
        return const Icon(Icons.check_circle, color: Cores.sucesso);
      case StatusEnvio.erro:
        return const Icon(Icons.error, color: Cores.erro);
    }
  }

  Widget _itemArquivo(ArquivoSelecionado a) {
    final periodo = a.info.periodo ?? 'indicado dentro do arquivo';
    final podeRemover = !_enviando && a.status != StatusEnvio.enviando;

    return Card(
      color: Colors.white,
      child: ListTile(
        leading: _iconeStatus(a),
        title: Text(
          a.nome,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${a.info.periodicidade}  |  ${a.info.tipo}\n'
              'Período: $periodo  |  ${formatarTamanho(a.tamanhoBytes)}',
            ),
            if (a.status == StatusEnvio.enviado)
              const Text(
                'Enviado com sucesso',
                style: TextStyle(color: Cores.sucesso),
              ),
            if (a.status == StatusEnvio.erro && a.mensagem != null)
              Text(a.mensagem!, style: const TextStyle(color: Cores.erro)),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Remover da lista',
          onPressed: podeRemover ? () => _remover(a) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantidadeParaEnviar = _paraEnviar.length;
    final temEnviados = _arquivos.any((a) => a.status == StatusEnvio.enviado);

    return Scaffold(
      appBar: AppBarSemob(
        titulo: 'Envio de arquivos',
        actions: [
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
                // Instruções
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info, color: Cores.azulMedio),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Selecione os relatórios em HTML gerados pela '
                            'Smart Data (mensais, quinzenais ou semanais). '
                            'O sistema identifica o tipo e o período pelo '
                            'nome do arquivo, por exemplo: '
                            'Mensal_Viagens_202608.html',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botões de seleção
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Cores.azulMedio,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _enviando ? null : _selecionarArquivos,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Selecionar arquivos'),
                    ),
                    if (temEnviados)
                      TextButton.icon(
                        onPressed: _enviando ? null : _limparEnviados,
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Limpar enviados'),
                      ),
                    Text(
                      '${_arquivos.length} arquivo(s) na lista',
                      style: const TextStyle(color: Cores.azulEscuro),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lista de arquivos (ou mensagem de lista vazia)
                Expanded(
                  child: _arquivos.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 64,
                                color: Cores.azulClaro,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Nenhum arquivo selecionado',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Cores.azulEscuro,
                                ),
                              ),
                              Text(
                                'Use o botão "Selecionar arquivos" para começar.',
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _arquivos.length,
                          itemBuilder: (context, indice) {
                            return _itemArquivo(_arquivos[indice]);
                          },
                        ),
                ),
                const SizedBox(height: 12),

                // Botão de enviar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Cores.azulEscuro,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: (_enviando || quantidadeParaEnviar == 0)
                        ? null
                        : _enviarTodos,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      _enviando
                          ? 'Enviando...'
                          : 'Enviar $quantidadeParaEnviar arquivo(s)',
                    ),
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

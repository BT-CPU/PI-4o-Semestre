// Km produtivo e viagens de UMA linha em UM dia (relatório "Linhas").
// ATENÇÃO: nesse relatório da Smart Data a coluna se chama "kmTotal", mas a
// soma dela é igual ao km PRODUTIVO do Resumo Geral. Por isso aqui o nome é
// kmProdutivo. O km improdutivo não é separado por linha nos relatórios.
class KmLinhaDia {
  final DateTime data;
  final String linha;
  final double kmProdutivo;
  final int viagens;

  KmLinhaDia({
    required this.data,
    required this.linha,
    required this.kmProdutivo,
    required this.viagens,
  });
}

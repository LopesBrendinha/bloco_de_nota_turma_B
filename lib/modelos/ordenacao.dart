enum Ordenacao {
  atualizacao('Última atualização', 'atualizadaEm DESC'),
  criacao('Data de criação', 'criadaEm DESC');

  final String rotulo;
  final String clausula;

  const Ordenacao(this.rotulo, this.clausula);
}

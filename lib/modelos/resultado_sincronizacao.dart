enum ResultadoSincronizacao {
  concluida('Notas sincronizadas com a nuvem.'),
  semConexao('Sem conexão com a nuvem. As notas continuam salvas no aparelho.'),
  acessoNegado('A nuvem recusou o acesso. Verifique as regras do Firestore.'),
  falha('Não foi possível sincronizar agora. Tente novamente.');

  final String mensagem;

  const ResultadoSincronizacao(this.mensagem);

  bool get sucesso => this == concluida;

  static ResultadoSincronizacao doCodigo(String codigo) {
    return switch (codigo) {
      'unavailable' || 'deadline-exceeded' => semConexao,
      'permission-denied' || 'unauthenticated' => acessoNegado,
      _ => falha,
    };
  }
}

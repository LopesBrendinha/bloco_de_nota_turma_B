/// Critérios de ordenação da lista de notas.
///
/// A ordenação é feita no `ORDER BY` do SQLite (e não em memória) para que
/// continue correta mesmo com muitas notas.
enum NoteSort {
  updatedDesc('Atualizadas primeiro', 'updated_at DESC'),
  updatedAsc('Atualizadas por último', 'updated_at ASC'),
  createdDesc('Mais recentes', 'created_at DESC'),
  createdAsc('Mais antigas', 'created_at ASC'),
  titleAsc('Título (A-Z)', 'title COLLATE NOCASE ASC');

  const NoteSort(this.label, this.orderBy);

  /// Texto exibido no menu de ordenação.
  final String label;

  /// Trecho usado diretamente na cláusula `ORDER BY`.
  final String orderBy;
}

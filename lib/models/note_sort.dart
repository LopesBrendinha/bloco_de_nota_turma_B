enum SortField {
  updated('updated_at', 'Última atualização'),
  created('created_at', 'Data de criação');

  const SortField(this.column, this.label);

  final String column;
  final String label;
}

/// Critério de ordenação escolhido pelo usuário (funcionalidade adicional).
/// Fica salvo na tabela `settings` do SQLite.
class NoteSort {
  final SortField field;
  final bool newestFirst;

  const NoteSort({this.field = SortField.updated, this.newestFirst = true});

  String get orderBy => '${field.column} ${newestFirst ? 'DESC' : 'ASC'}';

  String get label =>
      '${field.label} · ${newestFirst ? 'recentes primeiro' : 'antigas primeiro'}';

  String encode() => '${field.name}:${newestFirst ? 'desc' : 'asc'}';

  static NoteSort decode(String? value) {
    if (value == null) return const NoteSort();
    final parts = value.split(':');
    final field = SortField.values.firstWhere(
      (f) => f.name == parts.first,
      orElse: () => SortField.updated,
    );
    return NoteSort(field: field, newestFirst: parts.last != 'asc');
  }

  @override
  bool operator ==(Object other) =>
      other is NoteSort &&
      other.field == field &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode => Object.hash(field, newestFirst);
}

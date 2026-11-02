import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/utils/date_utils.dart';
import 'package:blocodenotasturmab/utils/text_normalizer.dart';
import 'package:blocodenotasturmab/widgets/highlight_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pesquisa', () {
    test('ignora maiúsculas e acentos', () {
      expect(
        normalizeForSearch('Ação PRÁTICA de Física'),
        'acao pratica de fisica',
      );
    });

    test('mantém o tamanho do texto para o destaque', () {
      const text = 'Reunião às 14h — São Paulo';
      expect(normalizeForSearch(text).length, text.length);
    });

    test('nota grava título e conteúdo normalizados em search_text', () {
      const note = Note(
        id: '1',
        uid: 'u',
        title: 'Lição',
        content: 'Exercícios',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(note.toMap()['search_text'], 'licao\nexercicios');
    });

    test('trecho começa perto da palavra encontrada', () {
      final content = '${'palavra ' * 20}alvo no fim';
      final snippet = snippetAround(content, 'ALVO');
      expect(snippet.startsWith('…'), isTrue);
      expect(snippet.contains('alvo no fim'), isTrue);
    });
  });

  group('ordenação por data', () {
    test('gera o ORDER BY correto', () {
      expect(const NoteSort().orderBy, 'updated_at DESC');
      expect(
        const NoteSort(field: SortField.created, newestFirst: false).orderBy,
        'created_at ASC',
      );
    });

    test('preferência salva e restaurada', () {
      const sort = NoteSort(field: SortField.created, newestFirst: false);
      expect(NoteSort.decode(sort.encode()), sort);
      expect(NoteSort.decode(null), const NoteSort());
    });

    test('agrupa por período', () {
      final now = DateTime(2026, 11, 20, 15);
      int at(DateTime d) => d.millisecondsSinceEpoch;
      expect(dateGroupLabel(at(DateTime(2026, 11, 20, 8)), now: now), 'Hoje');
      expect(dateGroupLabel(at(DateTime(2026, 11, 19, 23)), now: now), 'Ontem');
      expect(
        dateGroupLabel(at(DateTime(2026, 11, 16)), now: now),
        'Últimos 7 dias',
      );
      expect(dateGroupLabel(at(DateTime(2026, 11, 2)), now: now), 'Este mês');
      expect(dateGroupLabel(at(DateTime(2026, 3, 2)), now: now), 'Março');
      expect(
        dateGroupLabel(at(DateTime(2025, 3, 2)), now: now),
        'Março de 2025',
      );
    });
  });

  test('status de sincronização desconhecido é tratado como pendente', () {
    expect(SyncStatus.parse('???'), SyncStatus.pendingUpsert);
    expect(SyncStatus.parse('synced'), SyncStatus.synced);
  });
}

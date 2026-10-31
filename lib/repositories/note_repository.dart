import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../models/note_category.dart';
import '../models/note_sort.dart';
import '../models/sync_status.dart';
import '../services/firestore_service.dart';
import 'sync_outcome.dart';

/// Coordena o banco local e o Cloud Firestore.
///
/// Padrão **Repository**: as telas conversam apenas com esta classe e não
/// sabem se um dado veio do SQLite ou da nuvem. Isso concentra num único
/// lugar a decisão mais delicada do aplicativo — quando gravar onde, e qual
/// versão vence num conflito.
///
/// ## Estratégia: *offline-first* com fila de pendências
///
/// 1. **Toda escrita vai primeiro para o SQLite**, marcada com
///    [SyncStatus.pendingUpsert] ou [SyncStatus.pendingDelete]. Como o banco
///    local não depende de rede, a operação do usuário nunca falha.
/// 2. Em seguida tenta-se replicar no Firestore. Se der certo, a linha é
///    marcada como [SyncStatus.synced]. Se falhar, ela **permanece pendente**
///    e será reenviada na próxima sincronização.
/// 3. [synchronize] faz o ciclo completo: primeiro **push** da fila local,
///    depois **pull** da nuvem.
///
/// ## Resolução de conflitos: *last write wins* por `updatedAt`
///
/// Na etapa de pull, cada documento remoto é comparado com a linha local:
///
/// * não existe localmente -> é inserido;
/// * existe e está pendente -> o local vence (ele já foi enviado no push);
/// * existe, está sincronizado e o remoto é mais novo -> o remoto substitui;
/// * caso contrário -> nada muda.
///
/// Linhas locais já sincronizadas que **desapareceram** da nuvem foram
/// excluídas definitivamente em outro aparelho, então são removidas aqui
/// também.
class NoteRepository {
  NoteRepository({DatabaseHelper? local, FirestoreService? cloud})
      : _local = local ?? DatabaseHelper.instance,
        _cloud = cloud ?? FirestoreService();

  final DatabaseHelper _local;
  final FirestoreService _cloud;

  static const _uuid = Uuid();

  /// Cores sugeridas ao criar uma categoria.
  static const categoryPalette = <int>[
    0xFF6C4AB6,
    0xFF2F9E7E,
    0xFFD9822B,
    0xFF2E7BC4,
    0xFFB4456B,
    0xFF7A8A3C,
  ];

  /// Categorias sugeridas na primeira vez que o usuário abre o gerenciador.
  static const suggestedCategories = <String>[
    'Estudos',
    'Trabalho',
    'Pessoal',
    'Ideias',
  ];

  // ---------------------------------------------------------------------------
  // Leitura (sempre local)
  // ---------------------------------------------------------------------------

  /// Lista as notas ativas do usuário.
  ///
  /// A leitura nunca toca a rede: o SQLite já contém tudo que foi baixado da
  /// nuvem na última sincronização, então a pesquisa e os filtros funcionam
  /// igual online e offline.
  Future<List<Note>> getNotes({
    required String uid,
    String? categoryId,
    String query = '',
    NoteSort sort = NoteSort.updatedDesc,
  }) {
    return _local.getNotes(
      uid: uid,
      categoryId: categoryId,
      query: query,
      sort: sort,
    );
  }

  /// Lista as notas que estão na lixeira.
  Future<List<Note>> getTrashedNotes({
    required String uid,
    String query = '',
    NoteSort sort = NoteSort.updatedDesc,
  }) {
    return _local.getNotes(
      uid: uid,
      onlyDeleted: true,
      query: query,
      sort: sort,
    );
  }

  Future<List<NoteCategory>> getCategories(String uid) =>
      _local.getCategories(uid);

  Future<Map<String, int>> countNotesByCategory(String uid) =>
      _local.countNotesByCategory(uid);

  Future<int> countTrashedNotes(String uid) => _local.countTrashedNotes(uid);

  Future<int> countPendingNotes(String uid) => _local.countPendingNotes(uid);

  // ---------------------------------------------------------------------------
  // Escrita de notas
  // ---------------------------------------------------------------------------

  /// Cria uma nota nova ou atualiza uma existente.
  ///
  /// Quando [existing] é nulo, um UUID é gerado aqui e usado tanto como
  /// chave no SQLite quanto como ID do documento no Firestore.
  ///
  /// Retorna o resultado da tentativa de envio para a nuvem. A nota já está
  /// salva localmente mesmo quando o retorno indica falha.
  Future<SyncOutcome> saveNote({
    required String uid,
    required String title,
    required String content,
    String? categoryId,
    Note? existing,
  }) async {
    final now = DateTime.now().toUtc();

    final note = (existing ?? _emptyNote(uid, now)).copyWith(
      title: title,
      content: content,
      categoryId: categoryId,
      clearCategory: categoryId == null,
      updatedAt: now,
      syncStatus: SyncStatus.pendingUpsert,
    );

    await _local.upsertNote(note);

    return _tryPush(() async {
      await _cloud.upsertNote(note);
      await _local.markNoteSynced(note.id);
    });
  }

  Note _emptyNote(String uid, DateTime now) {
    return Note(
      id: _uuid.v4(),
      uid: uid,
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Move a nota para a lixeira (funcionalidade adicional).
  ///
  /// Não é um `DELETE`: a linha continua no SQLite com `is_deleted = 1`, e o
  /// documento continua no Firestore com `isDeleted: true`. Por ser um campo
  /// sincronizado, a lixeira é a mesma em todos os aparelhos do usuário.
  Future<SyncOutcome> moveToTrash(Note note) async {
    final now = DateTime.now().toUtc();

    final trashed = note.copyWith(
      isDeleted: true,
      deletedAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingUpsert,
    );

    await _local.upsertNote(trashed);

    return _tryPush(() async {
      await _cloud.upsertNote(trashed);
      await _local.markNoteSynced(trashed.id);
    });
  }

  /// Restaura uma nota da lixeira.
  Future<SyncOutcome> restoreFromTrash(Note note) async {
    final now = DateTime.now().toUtc();

    final restored = note.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      updatedAt: now,
      syncStatus: SyncStatus.pendingUpsert,
    );

    await _local.upsertNote(restored);

    return _tryPush(() async {
      await _cloud.upsertNote(restored);
      await _local.markNoteSynced(restored.id);
    });
  }

  /// Exclusão definitiva: apaga a linha local e o documento remoto.
  ///
  /// Se a remoção na nuvem falhar, a linha local é mantida marcada como
  /// [SyncStatus.pendingDelete] em vez de ser apagada. Apagar só o local
  /// faria o documento remoto voltar no próximo pull — a nota "ressuscitaria".
  Future<SyncOutcome> deleteForever(Note note) async {
    final pending = note.copyWith(syncStatus: SyncStatus.pendingDelete);

    await _local.upsertNote(pending);

    final outcome = await _tryPush(() async {
      await _cloud.deleteNote(uid: note.uid, id: note.id);
      await _local.hardDeleteNote(note.id);
    });

    return outcome;
  }

  /// Esvazia a lixeira, excluindo cada nota em definitivo.
  Future<SyncOutcome> emptyTrash(String uid) async {
    final trashed = await _local.getNotes(uid: uid, onlyDeleted: true);

    var worst = const SyncOutcome(state: SyncState.synced);

    for (final note in trashed) {
      final outcome = await deleteForever(note);

      if (!outcome.isSynced && worst.isSynced) worst = outcome;
    }

    return worst.copyWithPending(await _local.countPendingNotes(uid));
  }

  // ---------------------------------------------------------------------------
  // Escrita de categorias
  // ---------------------------------------------------------------------------

  Future<SyncOutcome> saveCategory({
    required String uid,
    required String name,
    required int colorValue,
    NoteCategory? existing,
  }) async {
    final now = DateTime.now().toUtc();

    final category = existing == null
        ? NoteCategory(
            id: _uuid.v4(),
            uid: uid,
            name: name,
            colorValue: colorValue,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: name,
            colorValue: colorValue,
            updatedAt: now,
            syncStatus: SyncStatus.pendingUpsert,
          );

    await _local.upsertCategory(category);

    return _tryPush(() async {
      await _cloud.upsertCategory(category);
      await _local.markCategorySynced(category.id);
    });
  }

  /// Exclui a categoria e desassocia as notas que a usavam.
  ///
  /// As notas **não** são excluídas: elas voltam para "sem categoria" e são
  /// marcadas como pendentes para que a nuvem receba o novo `categoryId`.
  Future<SyncOutcome> deleteCategory(NoteCategory category) async {
    await _local.detachCategoryFromNotes(category.id);

    final pending = category.copyWith(syncStatus: SyncStatus.pendingDelete);
    await _local.upsertCategory(pending);

    return _tryPush(() async {
      await _cloud.deleteCategory(uid: category.uid, id: category.id);
      await _local.hardDeleteCategory(category.id);

      // As notas desassociadas também precisam subir.
      await _pushPendingNotes(category.uid);
    });
  }

  // ---------------------------------------------------------------------------
  // Sincronização
  // ---------------------------------------------------------------------------

  /// Ciclo completo de sincronização: envia a fila local e baixa a nuvem.
  ///
  /// Chamado ao abrir a tela de notas (login ou nova instalação) e no
  /// "arraste para atualizar". O push vem antes do pull de propósito: assim
  /// o que o usuário escreveu offline não é sobrescrito por uma versão
  /// antiga que ainda está na nuvem.
  Future<SyncOutcome> synchronize(String uid) async {
    try {
      final pushed = await _pushPending(uid);
      final pulled = await _pull(uid);

      return SyncOutcome(
        state: SyncState.synced,
        pushed: pushed,
        pulled: pulled,
        pending: await _local.countPendingNotes(uid),
      );
    } on CloudException catch (error) {
      return SyncOutcome(
        state: error.isOffline ? SyncState.offline : SyncState.failed,
        message: error.message,
        pending: await _local.countPendingNotes(uid),
      );
    }
  }

  /// Envia tudo que está na fila local (notas e categorias).
  Future<int> _pushPending(String uid) async {
    // Categorias primeiro: uma nota pode apontar para uma categoria que
    // ainda não existe na nuvem.
    final categories = await _pushPendingCategories(uid);
    final notes = await _pushPendingNotes(uid);

    return categories + notes;
  }

  Future<int> _pushPendingCategories(String uid) async {
    final pending = await _local.getPendingCategories(uid);

    for (final category in pending) {
      if (category.syncStatus == SyncStatus.pendingDelete) {
        await _cloud.deleteCategory(uid: uid, id: category.id);
        await _local.hardDeleteCategory(category.id);
      } else {
        await _cloud.upsertCategory(category);
        await _local.markCategorySynced(category.id);
      }
    }

    return pending.length;
  }

  Future<int> _pushPendingNotes(String uid) async {
    final pending = await _local.getPendingNotes(uid);

    for (final note in pending) {
      if (note.syncStatus == SyncStatus.pendingDelete) {
        await _cloud.deleteNote(uid: uid, id: note.id);
        await _local.hardDeleteNote(note.id);
      } else {
        await _cloud.upsertNote(note);
        await _local.markNoteSynced(note.id);
      }
    }

    return pending.length;
  }

  /// Baixa a nuvem e mescla no SQLite.
  ///
  /// É esta etapa que permite "recuperar as notas após entrar novamente no
  /// aplicativo ou em outra instalação": num aparelho novo o SQLite está
  /// vazio e todos os documentos remotos são inseridos.
  Future<int> _pull(String uid) async {
    final remoteCategories = await _cloud.fetchCategories(uid);
    final remoteNotes = await _cloud.fetchNotes(uid);

    var changed = 0;

    changed += await _mergeCategories(uid, remoteCategories);
    changed += await _mergeNotes(uid, remoteNotes);

    return changed;
  }

  Future<int> _mergeCategories(
    String uid,
    List<NoteCategory> remote,
  ) async {
    final localList = await _local.getPendingCategories(uid);
    final pendingIds = localList.map((category) => category.id).toSet();

    final toWrite = <NoteCategory>[];

    for (final category in remote) {
      if (pendingIds.contains(category.id)) continue;

      final local = await _local.getCategoryById(category.id);

      if (local == null || category.updatedAt.isAfter(local.updatedAt)) {
        toWrite.add(category.copyWith(localId: local?.localId));
      }
    }

    await _local.upsertCategories(toWrite);

    // Categoria que saiu da nuvem e já estava sincronizada aqui.
    final remoteIds = remote.map((category) => category.id).toSet();
    final all = await _local.getCategories(uid);

    for (final category in all) {
      final isOrphan = !remoteIds.contains(category.id) &&
          category.syncStatus == SyncStatus.synced;

      if (isOrphan) {
        await _local.detachCategoryFromNotes(category.id);
        await _local.hardDeleteCategory(category.id);
      }
    }

    return toWrite.length;
  }

  Future<int> _mergeNotes(String uid, List<Note> remote) async {
    final pendingIds =
        (await _local.getPendingNotes(uid)).map((note) => note.id).toSet();

    final toWrite = <Note>[];

    for (final note in remote) {
      // Já enviamos nossa versão no push; ela é a mais nova.
      if (pendingIds.contains(note.id)) continue;

      final local = await _local.getNoteById(note.id);

      if (local == null || note.updatedAt.isAfter(local.updatedAt)) {
        toWrite.add(note.copyWith(localId: local?.localId));
      }
    }

    await _local.upsertNotes(toWrite);

    // Notas excluídas em definitivo em outro aparelho.
    final remoteIds = remote.map((note) => note.id).toSet();

    final localNotes = <Note>[
      ...await _local.getNotes(uid: uid),
      ...await _local.getNotes(uid: uid, onlyDeleted: true),
    ];

    for (final note in localNotes) {
      final isOrphan = !remoteIds.contains(note.id) &&
          note.syncStatus == SyncStatus.synced;

      if (isOrphan) await _local.hardDeleteNote(note.id);
    }

    return toWrite.length;
  }

  /// Executa uma gravação remota já sabendo que o local está salvo.
  ///
  /// Qualquer [CloudException] é transformada em [SyncOutcome] em vez de ser
  /// propagada: a operação do usuário já foi concluída no SQLite, então a
  /// falha de rede é um aviso, não um erro fatal.
  Future<SyncOutcome> _tryPush(Future<void> Function() action) async {
    try {
      await action();

      return const SyncOutcome(state: SyncState.synced, pushed: 1);
    } on CloudException catch (error) {
      return SyncOutcome(
        state: error.isOffline ? SyncState.offline : SyncState.failed,
        message: error.message,
      );
    }
  }
}

extension on SyncOutcome {
  SyncOutcome copyWithPending(int pending) {
    return SyncOutcome(
      state: state,
      message: message,
      pushed: pushed,
      pulled: pulled,
      pending: pending,
    );
  }
}

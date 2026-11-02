import 'dart:async';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NoteRepository {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final FirestoreService _firestore = FirestoreService();

  static const _defaultCategories = ['Estudos', 'Trabalho', 'Pessoal', 'Outros'];

  Future<List<Note>> getNotes(String uid) async {
    return _database.getNotes(uid);
  }

  Future<bool> saveNote(Note note) async {
    final remoteId = note.remoteId ?? _firestore.newId(note.uid);

    var local = note.copyWith(remoteId: remoteId, synced: false);

    if (local.id == null) {
      final id = await _database.insertNote(local);
      local = local.copyWith(id: id);
    } else {
      await _database.updateNote(local);
    }

    return _push(local);
  }

  Future<bool> deleteNote(Note note) async {
    if (note.remoteId == null) {
      await _database.deleteNote(note.id!, note.uid);
      return true;
    }

    final pending = note.copyWith(deleted: true, synced: false);
    await _database.updateNote(pending);

    return _push(pending);
  }

  Future<bool> sync(String uid) async {
    final pending = await _database.getPendingNotes(uid);

    for (var note in pending) {
      if (note.remoteId == null) {
        note = note.copyWith(remoteId: _firestore.newId(uid));
        await _database.updateNote(note);
      }

      final sent = await _push(note);

      if (!sent) return false;
    }

    try {
      final remoteNotes = await _firestore.getNotes(uid);
      final localNotes = await _database.getAllNotes(uid);

      final localByRemoteId = {
        for (final note in localNotes)
          if (note.remoteId != null) note.remoteId! : note,
      };

      final remoteIds = <String>{};

      for (final remote in remoteNotes) {
        remoteIds.add(remote.remoteId!);

        final local = localByRemoteId[remote.remoteId];

        if (local == null) {
          await _database.insertNote(remote);
        } else if (local.synced) {
          await _database.updateNote(remote.copyWith(id: local.id));
        }
      }

      for (final local in localNotes) {
        final deletedElsewhere = local.synced &&
            local.remoteId != null &&
            !remoteIds.contains(local.remoteId);

        if (deletedElsewhere) {
          await _database.deleteNote(local.id!, uid);
        }
      }

      return true;
    } on FirebaseException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> _push(Note note) async {
    try {
      if (note.deleted) {
        await _firestore.deleteNote(note);
        await _database.deleteNote(note.id!, note.uid);
      } else {
        await _firestore.saveNote(note);
        await _database.updateNote(note.copyWith(synced: true));
      }

      return true;
    } on FirebaseException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<List<String>> getCategories(String uid) async {
    final saved = await _database.getCategories(uid);

    final categories = <String, String>{};

    for (final category in [..._defaultCategories, ...saved]) {
      categories.putIfAbsent(category.toLowerCase(), () => category);
    }

    return categories.values.toList();
  }
}
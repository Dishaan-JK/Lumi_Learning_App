import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class WorkspaceNote {
  const WorkspaceNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'folderId': folderId,
      };

  factory WorkspaceNote.fromJson(Map<String, dynamic> json) => WorkspaceNote(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        folderId: json['folderId'] as String?,
      );
}

/// Local JSON-backed workspace store shared by the web UI and agent tools.
final class WorkspaceNotes {
  WorkspaceNotes(this.file);

  final File file;
  final Map<String, WorkspaceNote> _notes = {};
  Future<void> _writeQueue = Future<void>.value();

  Future<void> load() async {
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    for (final value in decoded) {
      final note = WorkspaceNote.fromJson(value as Map<String, dynamic>);
      _notes[note.id] = note;
    }
  }

  Future<void> reload() async {
    _notes.clear();
    await load();
  }

  List<WorkspaceNote> list() => _notes.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  WorkspaceNote? get(String id) => _notes[id];

  List<WorkspaceNote> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return list()
        .where(
          (note) =>
              note.title.toLowerCase().contains(needle) ||
              note.content.toLowerCase().contains(needle),
        )
        .toList();
  }

  /// Returns note links written as [[Exact note title]].
  List<Map<String, String>> links() {
    final allNotes = list();
    final byTitle = <String, List<WorkspaceNote>>{};
    for (final note in allNotes) {
      byTitle.putIfAbsent(note.title.toLowerCase(), () => []).add(note);
    }
    final edges = <Map<String, String>>[];
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    for (final note in allNotes) {
      for (final match in pattern.allMatches(note.content)) {
        final candidates = byTitle[match.group(1)!.trim().toLowerCase()];
        if (candidates?.length == 1 && candidates!.single.id != note.id) {
          final target = candidates.single;
          edges.add({'from': note.id, 'to': target.id});
        }
      }
    }
    return edges;
  }

  Future<WorkspaceNote> save(
      {String? id,
      required String title,
      required String content,
      String? folderId,
      bool clearFolder = false}) async {
    final now = DateTime.now().toUtc();
    final previous = id == null ? null : _notes[id];
    final note = WorkspaceNote(
      id: id ?? now.microsecondsSinceEpoch.toRadixString(36),
      title: title.trim().isEmpty ? 'Untitled note' : title.trim(),
      content: content,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      folderId: clearFolder ? null : folderId ?? previous?.folderId,
    );
    _notes[note.id] = note;
    await _persist();
    return note;
  }

  Future<bool> delete(String id) async {
    if (_notes.remove(id) == null) return false;
    await _persist();
    return true;
  }

  Future<void> _persist() {
    final write = _writeQueue.catchError((_) {}).then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(list().map((n) => n.toJson()).toList()),
      );
      await temporary.rename(file.path);
    });
    _writeQueue = write;
    return write;
  }
}

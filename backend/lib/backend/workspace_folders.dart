import 'dart:convert';
import 'dart:io';

final class WorkspaceFolder {
  const WorkspaceFolder({required this.id, required this.name, this.parentId});
  final String id;
  final String name;
  final String? parentId;

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'parentId': parentId};
  factory WorkspaceFolder.fromJson(Map<String, dynamic> json) =>
      WorkspaceFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
      );
}

/// Small local JSON store. Folder deletion is non-destructive to notes.
final class WorkspaceFolders {
  WorkspaceFolders(this.file);
  final File file;
  final Map<String, WorkspaceFolder> _folders = {};

  Future<void> load() async {
    if (!await file.exists()) return;
    final rows = jsonDecode(await file.readAsString()) as List<dynamic>;
    for (final row in rows) {
      final folder = WorkspaceFolder.fromJson(row as Map<String, dynamic>);
      _folders[folder.id] = folder;
    }
  }

  Future<void> reload() async {
    _folders.clear();
    await load();
  }

  List<WorkspaceFolder> list() => _folders.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  WorkspaceFolder? get(String id) => _folders[id];

  Future<WorkspaceFolder> save(
      {String? id, required String name, String? parentId}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const FormatException('Folder name is required');
    if (parentId != null && !_folders.containsKey(parentId)) {
      throw const FormatException('Parent folder does not exist');
    }
    if (id != null) {
      var ancestorId = parentId;
      final visited = <String>{};
      while (ancestorId != null && visited.add(ancestorId)) {
        if (ancestorId == id) {
          throw const FormatException(
              'A folder cannot be nested inside itself');
        }
        ancestorId = _folders[ancestorId]?.parentId;
      }
    }
    final folder = WorkspaceFolder(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: clean,
      parentId: parentId,
    );
    _folders[folder.id] = folder;
    await _persist();
    return folder;
  }

  Future<bool> delete(String id) async {
    if (_folders.remove(id) == null) return false;
    for (final folder in _folders.values.toList()) {
      if (folder.parentId == id) {
        _folders[folder.id] = WorkspaceFolder(id: folder.id, name: folder.name);
      }
    }
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(list().map((f) => f.toJson()).toList()));
    await tmp.rename(file.path);
  }
}

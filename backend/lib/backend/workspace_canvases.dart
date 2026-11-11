import 'dart:convert';
import 'dart:io';

final class WorkspaceCanvas {
  const WorkspaceCanvas({
    required this.id,
    required this.title,
    required this.description,
    required this.noteIds,
    this.quizzes = const [],
    this.positions = const {},
    this.connections = const [],
    required this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final List<String> noteIds;
  final List<Map<String, Object?>> quizzes;
  final Map<String, CanvasPosition> positions;
  final List<CanvasConnection> connections;
  final DateTime updatedAt;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'noteIds': noteIds,
        'quizzes': quizzes.map(_publicQuiz).toList(),
        'positions': {
          for (final entry in positions.entries)
            entry.key: entry.value.toJson(),
        },
        'connections':
            connections.map((connection) => connection.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': (createdAt ?? updatedAt).toIso8601String(),
      };

  factory WorkspaceCanvas.fromJson(Map<String, dynamic> json) =>
      WorkspaceCanvas(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        noteIds: (json['noteIds'] as List<dynamic>).cast<String>(),
        quizzes: _readQuizzes(json['quizzes']),
        positions: _readPositions(json['positions']),
        connections: _readConnections(json['connections']),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        createdAt:
            DateTime.parse((json['createdAt'] ?? json['updatedAt']) as String),
      );

  Map<String, Object?> toStorageJson() => {
        ...toJson(),
        'quizzes': quizzes,
      };

  static List<Map<String, Object?>> _readQuizzes(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((quiz) => Map<String, Object?>.from(quiz))
          .toList()
      : const [];

  static Map<String, Object?> _publicQuiz(Map<String, Object?> quiz) => {
        for (final entry in quiz.entries)
          if (entry.key != 'questions') entry.key: entry.value,
        'questions': (quiz['questions'] as List? ?? const []).map((question) {
          final item = Map<String, Object?>.from(question as Map);
          item.remove('answerIndex');
          return item;
        }).toList(),
      };

  static Map<String, CanvasPosition> _readPositions(Object? raw) {
    if (raw is! Map) return const {};
    final positions = <String, CanvasPosition>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final point = entry.value as Map;
      final x = point['x'];
      final y = point['y'];
      if (x is num && y is num) {
        positions[entry.key as String] =
            CanvasPosition(x.toDouble(), y.toDouble());
      }
    }
    return positions;
  }

  static List<CanvasConnection> _readConnections(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((connection) => CanvasConnection(
                sourceId: connection['sourceId'] as String? ?? '',
                targetId: connection['targetId'] as String? ?? '',
              ))
          .where((connection) =>
              connection.sourceId.isNotEmpty && connection.targetId.isNotEmpty)
          .toList()
      : const [];
}

final class CanvasConnection {
  const CanvasConnection({required this.sourceId, required this.targetId});
  final String sourceId;
  final String targetId;

  Map<String, String> toJson() => {'sourceId': sourceId, 'targetId': targetId};
}

final class CanvasPosition {
  const CanvasPosition(this.x, this.y);
  final double x;
  final double y;

  Map<String, double> toJson() => {'x': x, 'y': y};
}

/// JSON-backed named collections of note cards shown in the Canvas view.
final class WorkspaceCanvases {
  WorkspaceCanvases(this.file);

  final File file;
  final Map<String, WorkspaceCanvas> _canvases = {};
  Future<void> _writeQueue = Future<void>.value();

  Future<void> load() async {
    if (!await file.exists()) return;
    final rows = jsonDecode(await file.readAsString()) as List<dynamic>;
    for (final row in rows) {
      final canvas = WorkspaceCanvas.fromJson(row as Map<String, dynamic>);
      _canvases[canvas.id] = canvas;
    }
  }

  Future<void> reload() async {
    _canvases.clear();
    await load();
  }

  List<WorkspaceCanvas> list() => _canvases.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> detachNote(String noteId) async {
    var changed = false;
    for (final canvas in _canvases.values.toList()) {
      if (!canvas.noteIds.contains(noteId)) continue;
      _canvases[canvas.id] = WorkspaceCanvas(
        id: canvas.id,
        title: canvas.title,
        description: canvas.description,
        noteIds: canvas.noteIds.where((id) => id != noteId).toList(),
        quizzes: canvas.quizzes,
        positions: Map.fromEntries(
            canvas.positions.entries.where((entry) => entry.key != noteId)),
        connections: canvas.connections
            .where((edge) => edge.sourceId != noteId && edge.targetId != noteId)
            .toList(),
        updatedAt: DateTime.now().toUtc(),
        createdAt: canvas.createdAt ?? canvas.updatedAt,
      );
      changed = true;
    }
    if (changed) await _persist();
  }

  Future<WorkspaceCanvas> updatePositions(
    String id,
    Map<String, CanvasPosition> positions,
  ) async {
    return update(id, positions: positions, existingNoteIds: const {});
  }

  Future<WorkspaceCanvas> update(
    String id, {
    String? title,
    String? description,
    List<String>? noteIds,
    Map<String, CanvasPosition>? positions,
    List<CanvasConnection>? connections,
    required Set<String> existingNoteIds,
  }) async {
    final current = _canvases[id];
    if (current == null) throw const FormatException('Canvas not found.');
    final cleanTitle = title?.trim() ?? current.title;
    final cleanDescription = description?.trim() ?? current.description;
    if (cleanTitle.isEmpty || cleanTitle.length > 120) {
      throw const FormatException('Canvas title must be 1 to 120 characters.');
    }
    if (cleanDescription.length > 500) {
      throw const FormatException(
          'Canvas description must be 500 characters or less.');
    }
    final nextNoteIds = noteIds ?? current.noteIds;
    final uniqueIds = nextNoteIds.toSet();
    if (uniqueIds.length != nextNoteIds.length || uniqueIds.length > 30) {
      throw const FormatException(
          'A canvas can contain up to 30 unique notes.');
    }
    if (noteIds != null && !existingNoteIds.containsAll(uniqueIds)) {
      throw const FormatException('Every canvas note must already exist.');
    }
    final nextConnections = connections ?? current.connections;
    if (nextConnections.length > 300 ||
        nextConnections.any((edge) =>
            edge.sourceId == edge.targetId ||
            !uniqueIds.contains(edge.sourceId) ||
            !uniqueIds.contains(edge.targetId)) ||
        nextConnections
                .map((edge) => '${edge.sourceId}\u0000${edge.targetId}')
                .toSet()
                .length !=
            nextConnections.length) {
      throw const FormatException(
          'Canvas connections must join two different linked notes without duplicates.');
    }
    final nextPositions = <String, CanvasPosition>{
      for (final entry in current.positions.entries)
        if (uniqueIds.contains(entry.key)) entry.key: entry.value,
      ...?positions,
    };
    if (!uniqueIds.containsAll(nextPositions.keys)) {
      throw const FormatException(
          'Layout contains a note outside this canvas.');
    }
    for (final point in nextPositions.values) {
      if (!point.x.isFinite ||
          !point.y.isFinite ||
          point.x < 0 ||
          point.y < 0 ||
          point.x > 10000 ||
          point.y > 10000) {
        throw const FormatException('Canvas positions are out of range.');
      }
    }
    final updated = WorkspaceCanvas(
      id: current.id,
      title: cleanTitle,
      description: cleanDescription,
      noteIds: List.unmodifiable(nextNoteIds),
      quizzes: current.quizzes,
      positions: nextPositions,
      connections: List.unmodifiable(nextConnections),
      updatedAt: DateTime.now().toUtc(),
      createdAt: current.createdAt ?? current.updatedAt,
    );
    _canvases[id] = updated;
    await _persist();
    return updated;
  }

  Future<WorkspaceCanvas> create({
    required String title,
    String description = '',
    required List<String> noteIds,
    required Set<String> existingNoteIds,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 120) {
      throw const FormatException('Canvas title must be 1 to 120 characters.');
    }
    if (description.length > 500) {
      throw const FormatException(
          'Canvas description must be 500 characters or less.');
    }
    final uniqueIds = noteIds.toSet();
    if (uniqueIds.length != noteIds.length || uniqueIds.length > 30) {
      throw const FormatException(
          'A canvas can contain up to 30 unique notes.');
    }
    if (!existingNoteIds.containsAll(uniqueIds)) {
      throw const FormatException('Every canvas note must already exist.');
    }
    final now = DateTime.now().toUtc();
    final canvas = WorkspaceCanvas(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      title: cleanTitle,
      description: description.trim(),
      noteIds: noteIds,
      quizzes: const [],
      connections: const [],
      updatedAt: now,
      createdAt: now,
    );
    _canvases[canvas.id] = canvas;
    await _persist();
    return canvas;
  }

  Future<WorkspaceCanvas> addQuiz(
    String canvasId, {
    required String title,
    required String description,
    required List<Map<String, Object?>> questions,
  }) async {
    final canvas = _canvases[canvasId];
    if (canvas == null) throw const FormatException('Canvas not found.');
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty ||
        cleanTitle.length > 120 ||
        description.length > 500 ||
        questions.isEmpty ||
        questions.length > 20) {
      throw const FormatException(
          'Quiz title, description, or question count is invalid.');
    }
    final validated = <Map<String, Object?>>[];
    for (final question in questions) {
      final prompt = (question['prompt'] as String? ?? '').trim();
      final options = question['options'];
      final answerIndex = question['answerIndex'];
      if (prompt.isEmpty ||
          prompt.length > 500 ||
          options is! List ||
          options.length != 4 ||
          answerIndex is! int ||
          answerIndex < 0 ||
          answerIndex > 3 ||
          options.any((option) =>
              option is! String ||
              option.trim().isEmpty ||
              option.length > 200)) {
        throw const FormatException(
            'Each quiz question needs a prompt, four options, and a valid answer index.');
      }
      validated.add({
        'prompt': prompt,
        'options':
            options.cast<String>().map((option) => option.trim()).toList(),
        'answerIndex': answerIndex,
        'explanation': (question['explanation'] as String? ?? '').trim(),
      });
    }
    final now = DateTime.now().toUtc();
    final quiz = <String, Object?>{
      'id': now.microsecondsSinceEpoch.toRadixString(36),
      'title': cleanTitle,
      'description': description.trim(),
      'questions': validated,
      'createdAt': now.toIso8601String(),
    };
    final updated = WorkspaceCanvas(
      id: canvas.id,
      title: canvas.title,
      description: canvas.description,
      noteIds: canvas.noteIds,
      quizzes: [...canvas.quizzes, quiz],
      positions: canvas.positions,
      connections: canvas.connections,
      updatedAt: now,
      createdAt: canvas.createdAt ?? canvas.updatedAt,
    );
    _canvases[canvasId] = updated;
    await _persist();
    return updated;
  }

  Map<String, Object?> gradeQuiz(
    String canvasId,
    String quizId,
    List<int> answers,
  ) {
    final canvas = _canvases[canvasId];
    if (canvas == null) throw const FormatException('Canvas not found.');
    final quiz =
        canvas.quizzes.where((item) => item['id'] == quizId).firstOrNull;
    if (quiz == null) throw const FormatException('Quiz not found.');
    final questions = (quiz['questions'] as List).cast<Map>();
    if (answers.length != questions.length ||
        answers.any((answer) => answer < 0 || answer > 3)) {
      throw const FormatException('Choose one option for every quiz question.');
    }
    var correct = 0;
    final results = <Map<String, Object?>>[];
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      final answerIndex = question['answerIndex'] as int;
      final isCorrect = answers[index] == answerIndex;
      if (isCorrect) correct++;
      results.add({
        'correct': isCorrect,
        'answerIndex': answerIndex,
        'explanation': question['explanation'] ?? '',
      });
    }
    return {
      'title': quiz['title'],
      'topic': canvas.title,
      'score': correct,
      'total': questions.length,
      'results': results,
    };
  }

  Future<void> _persist() {
    final write = _writeQueue.catchError((_) {}).then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
          jsonEncode(list().map((c) => c.toStorageJson()).toList()));
      await temporary.rename(file.path);
    });
    _writeQueue = write;
    return write;
  }
}

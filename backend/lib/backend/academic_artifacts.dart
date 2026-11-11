import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:genkit/experimental.dart';
import 'package:genkit/experimental_io.dart';

/// Durable library, independent of source-note and conversation deletion.
final class AcademicArtifacts {
  AcademicArtifacts(this.file);
  final File file;
  final Map<String, Map<String, Object?>> _items = {};
  Future<void> _queue = Future.value();

  Future<void> load() async {
    if (!await file.exists()) return;
    for (final row in jsonDecode(await file.readAsString()) as List) {
      final item = Map<String, Object?>.from(row as Map);
      _items[item['id'] as String] = item;
    }
  }

  Future<void> reload() async {
    _items.clear();
    await load();
  }

  List<Map<String, Object?>> list() => _items.values
      .map((item) => Map<String, Object?>.unmodifiable(item))
      .toList()
    ..sort((a, b) =>
        (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));

  /// Question keys stay on the server until the student submits an attempt.
  List<Map<String, Object?>> publicList() => list().map((item) {
        final copy = Map<String, Object?>.from(item);
        final object = copy['learningObject'];
        if (object is Map && object['type'] == 'quiz') {
          copy['learningObject'] = {
            'type': 'quiz',
            'questions': [
              for (final question in object['questions'] as List)
                {'prompt': question['prompt'], 'options': question['options']}
            ],
          };
        }
        return copy;
      }).toList();

  Future<Map<String, Object?>> submitQuiz(String id, Object? answers) async {
    final item = _items[id];
    final object = item?['learningObject'];
    if (object is! Map || object['type'] != 'quiz') {
      throw const FormatException('Interactive quiz not found.');
    }
    final questions = object['questions'] as List;
    if (answers is! List ||
        answers.length != questions.length ||
        answers.any((a) => a is! int || a < 0 || a > 3)) {
      throw const FormatException(
          'Answer every question with one of its four options.');
    }
    final feedback = [
      for (var i = 0; i < questions.length; i++)
        {
          'correct': answers[i] == questions[i]['answerIndex'],
          'answerIndex': questions[i]['answerIndex'],
          'explanation': questions[i]['explanation'],
        }
    ];
    return {
      'score': feedback.where((q) => q['correct'] == true).length,
      'total': questions.length,
      'feedback': feedback,
    };
  }

  Future<Map<String, Object?>> create({
    required String kind,
    required String title,
    required String content,
    required String source,
    Map<String, Object?>? learningObject,
  }) async {
    const kinds = {
      'Quizzes',
      'Test papers',
      'Revision exams',
      'Revision plans',
      'Lessons',
      'Flashcards',
    };
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (!kinds.contains(kind) ||
        cleanTitle.isEmpty ||
        cleanTitle.length > 160 ||
        cleanContent.isEmpty ||
        cleanContent.length > 30000) {
      throw const FormatException(
          'Choose a supported learning artifact and provide a title and content within the length limits.');
    }
    final object = learningObject == null
        ? null
        : validateLearningObject(kind, learningObject);
    final now = DateTime.now().toUtc();
    final digest = sha256.convert(utf8.encode(
        '$kind:$cleanTitle:${now.microsecondsSinceEpoch}:$cleanContent'));
    final item = <String, Object?>{
      'id': 'generated:$digest',
      'kind': kind,
      'title': cleanTitle,
      'content': cleanContent,
      'source': source,
      'sourceId': 'generated',
      'updatedAt': now.toIso8601String(),
      if (object != null) 'learningObject': object,
    };
    await collect([item]);
    return Map.unmodifiable(item);
  }

  static Map<String, Object?> validateLearningObject(
      String kind, Map<String, Object?> object) {
    String text(Object? value, int limit) {
      if (value is! String || value.trim().isEmpty || value.length > limit) {
        throw const FormatException(
            'Learning object text is empty or too long.');
      }
      return value.trim();
    }

    if (kind == 'Quizzes' && object['type'] == 'quiz') {
      final questions = object['questions'];
      if (questions is! List || questions.isEmpty || questions.length > 20) {
        throw const FormatException('Provide between 1 and 20 quiz questions.');
      }
      return {
        'type': 'quiz',
        'questions': [
          for (final question in questions)
            if (question is Map &&
                question['options'] is List &&
                (question['options'] as List).length == 4 &&
                question['answerIndex'] is int &&
                (question['answerIndex'] as int) >= 0 &&
                (question['answerIndex'] as int) < 4)
              {
                'prompt': text(question['prompt'], 500),
                'options': [
                  for (final option in question['options'] as List)
                    text(option, 200)
                ],
                'answerIndex': question['answerIndex'],
                'explanation': text(question['explanation'], 2000),
              }
            else
              throw const FormatException(
                  'Each quiz question needs four options, an answer index, and feedback.')
        ],
      };
    }
    if (kind == 'Flashcards' && object['type'] == 'flashcards') {
      final cards = object['cards'];
      if (cards is! List || cards.isEmpty || cards.length > 100) {
        throw const FormatException('Provide between 1 and 100 flashcards.');
      }
      return {
        'type': 'flashcards',
        'cards': [
          for (final card in cards)
            if (card is Map)
              {
                'front': text(card['front'], 2000),
                'back': text(card['back'], 4000)
              }
            else
              throw const FormatException(
                  'Each flashcard needs a front and back.')
        ],
      };
    }
    throw const FormatException(
        'Learning object type does not match its artifact kind.');
  }

  Future<void> collect(Iterable<Map<String, Object?>> items) {
    // Serialize mutation and disk writes together, so failed writes can retry.
    final write = _queue.catchError((Object _) {}).then((_) async {
      final next = Map<String, Map<String, Object?>>.from(_items);
      var changed = false;
      for (final item in items) {
        final id = item['id'] as String;
        if (jsonEncode(next[id]) == jsonEncode(item)) continue;
        next[id] = Map.of(item);
        changed = true;
      }
      if (!changed) return;
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(next.values.toList()),
          flush: true);
      await temporary.rename(file.path);
      _items
        ..clear()
        ..addAll(next);
    });
    _queue = write;
    return write;
  }

  /// Archives final text from completed turns; excludes tool calls and secrets
  /// in system/user/tool messages. Stable content IDs deduplicate history scans.
  Future<void> captureSnapshot(Map<String, dynamic> snapshot) async {
    if (snapshot['status'] != 'completed') return;
    final state = snapshot['state'];
    if (state is! Map) return;
    final session = snapshot['sessionId'] ?? state['sessionId'];
    if (session is! String) return;
    final messages = state['messages'];
    if (messages is! List) return;
    final items = <Map<String, Object?>>[];
    var prompt = '';
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message is! Map) continue;
      final parts = message['content'];
      if (parts is! List) continue;
      final text = parts
          .whereType<Map>()
          .map((p) => p['text'])
          .whereType<String>()
          .join('\n')
          .trim();
      if (message['role'] == 'user') {
        prompt = text.split('Student request: ').last;
        continue;
      }
      if (!['model', 'assistant'].contains(message['role']) ||
          text.isEmpty ||
          parts.whereType<Map>().any((p) => p.containsKey('toolRequest'))) {
        continue;
      }
      final kind = _kind(prompt, text);
      final heading = text
          .split('\n')
          .map((s) => s.replaceFirst(RegExp(r'^#+\s*'), '').trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => 'Learning material');
      final title =
          heading.length > 100 ? '${heading.substring(0, 97)}…' : heading;
      final digest = sha256.convert(utf8.encode('$session:$i:$text'));
      items.add({
        'id': 'response:$digest',
        'kind': kind,
        'title': title,
        'content': text,
        'source': 'Lumi Coach',
        'sourceId': session,
        'updatedAt':
            snapshot['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
      });
    }
    // Existing records retain their original date when replayed in later turns.
    await collect(items.where((item) => !_items.containsKey(item['id'])));
  }

  Future<void> backfill(Directory sessions) async {
    if (!await sessions.exists()) return;
    await for (final entry in sessions.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final snapshot = jsonDecode(await entry.readAsString());
        if (snapshot is Map<String, dynamic>) await captureSnapshot(snapshot);
      } on FormatException {
        // A damaged legacy snapshot must not hide the rest of the library.
      }
    }
  }

  static String _kind(String prompt, String text) {
    final request = prompt.toLowerCase();
    for (final (pattern, kind) in [
      (r'revision\s+(exam|test|paper)', 'Revision exams'),
      (r'flash\s*cards?', 'Flashcards'),
      (r'\b(mock|test|exam|paper)\b', 'Test papers'),
      (r'quiz', 'Quizzes'),
      (r'revision|study plan', 'Revision plans'),
      (r'review|progress', 'Reviews'),
      (r'lesson|teach', 'Lessons'),
    ]) {
      if (RegExp(pattern).hasMatch(request)) return kind;
    }
    if (RegExp(r'front\s*:.*', caseSensitive: false).hasMatch(text)) {
      return 'Flashcards';
    }
    return 'Explanations';
  }
}

/// Archive at the backend's session persistence boundary, including turns
/// completed after the browser closes or navigates away.
class ArchivingSessionStore extends FileSessionStore {
  ArchivingSessionStore(super.path, this.artifacts)
      : super(maxPersistedChainLength: 160);
  final AcademicArtifacts artifacts;

  @override
  Future<String?> saveSnapshot(String? snapshotId, SnapshotMutator mutator,
      {Map<String, dynamic>? context}) async {
    final id = await super.saveSnapshot(snapshotId, mutator, context: context);
    if (id != null) {
      final snapshot = await getSnapshot(snapshotId: id, context: context);
      if (snapshot != null) await artifacts.captureSnapshot(snapshot.toJson());
    }
    return id;
  }
}

import 'dart:convert';
import 'dart:io';

/// Shared, local-first evidence used by Lumi's teaching, testing, and review agents.
final class LearningRecord {
  LearningRecord(this.file);

  final File file;
  final List<Map<String, Object?>> _events = [];
  Future<void> _writeQueue = Future<void>.value();

  Future<void> load() async {
    if (!await file.exists()) return;
    final value = jsonDecode(await file.readAsString());
    if (value is! List) return;
    for (final row in value) {
      if (row is Map) _events.add(Map<String, Object?>.from(row));
    }
  }

  Future<void> reload() async {
    _events.clear();
    await load();
  }

  List<Map<String, Object?>> get events =>
      _events.map((event) => Map<String, Object?>.unmodifiable(event)).toList();

  List<Map<String, Object?>> forTopic(String topic) {
    final key = topic.trim().toLowerCase();
    if (key.isEmpty) return events;
    return events
        .where((event) =>
            (event['topic'] as String? ?? '').toLowerCase().contains(key))
        .toList();
  }

  List<Map<String, Object?>> dueReviews({DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    final latestByTopic = <String, Map<String, Object?>>{};
    for (final event in _events) {
      final topic = event['topic'] as String? ?? '';
      final due = event['reviewAt'] as String?;
      if (topic.isEmpty || due == null) continue;
      final key = topic.trim().toLowerCase();
      final previous = latestByTopic[key];
      if (previous == null ||
          DateTime.parse(event['recordedAt'] as String)
              .isAfter(DateTime.parse(previous['recordedAt'] as String))) {
        latestByTopic[key] = event;
      }
    }
    return latestByTopic.values
        .where((event) => !DateTime.parse(event['reviewAt'] as String)
            .toUtc()
            .isAfter(current))
        .toList();
  }

  /// Deterministic summaries help the reviewer distinguish patterns from
  /// isolated results. The underlying evidence remains available to agents.
  List<Map<String, Object?>> patterns({String topic = ''}) {
    final filter = topic.trim().toLowerCase();
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final event in _events) {
      final label = event['topic'] as String? ?? '';
      final key = label.trim().toLowerCase();
      if (key.isEmpty || (filter.isNotEmpty && !key.contains(filter))) continue;
      grouped.putIfAbsent(key, () => []).add(event);
    }
    final summaries = <Map<String, Object?>>[];
    for (final events in grouped.values) {
      events.sort((a, b) => DateTime.parse(a['recordedAt'] as String)
          .compareTo(DateTime.parse(b['recordedAt'] as String)));
      final recent = events.reversed.take(5).toList().reversed.toList();
      final scores = recent
          .map((event) => event['score'])
          .whereType<num>()
          .map((score) => score.toDouble())
          .toList();
      final olderScores = events
          .take(
              events.length > recent.length ? events.length - recent.length : 0)
          .map((event) => event['score'])
          .whereType<num>()
          .map((score) => score.toDouble())
          .toList();
      final misconceptionCounts = <String, int>{};
      for (final event in events) {
        final misconception = (event['misconception'] as String? ?? '').trim();
        if (misconception.isNotEmpty) {
          final key = misconception.toLowerCase();
          misconceptionCounts.update(key, (count) => count + 1,
              ifAbsent: () => 1);
        }
      }
      double? average(List<double> values) {
        if (values.isEmpty) return null;
        return values.reduce((a, b) => a + b) / values.length;
      }

      final olderAverage = average(olderScores);
      final recentAverage = average(scores);
      final trend = olderAverage == null || recentAverage == null
          ? 'insufficient scored history'
          : recentAverage - olderAverage >= .08
              ? 'improving'
              : olderAverage - recentAverage >= .08
                  ? 'needs attention'
                  : 'steady';
      summaries.add({
        'topic': events.last['topic'],
        'attempts': events.length,
        'scoredAttempts': scores.length + olderScores.length,
        'recentAverage': recentAverage,
        'trend': trend,
        'recurringMisconceptions': misconceptionCounts.entries
            .where((entry) => entry.value > 1)
            .map((entry) => {
                  'misconception': entry.key,
                  'occurrences': entry.value,
                })
            .toList(),
        'nextReviewAt': events.last['reviewAt'],
      });
    }
    return summaries;
  }

  Future<Map<String, Object?>> record({
    required String agent,
    required String kind,
    required String topic,
    required String evidence,
    double? score,
    String? misconception,
    int? reviewDays,
  }) async {
    final cleanTopic = topic.trim();
    final cleanEvidence = evidence.trim();
    if (cleanTopic.isEmpty ||
        cleanTopic.length > 160 ||
        cleanEvidence.isEmpty ||
        cleanEvidence.length > 4000) {
      throw const FormatException('Topic or evidence is empty or too long.');
    }
    if (!const {'teacher', 'tester', 'reviewer'}.contains(agent) ||
        !const {'lesson', 'quiz', 'test', 'review'}.contains(kind)) {
      throw const FormatException(
          'Learning evidence has an invalid agent or type.');
    }
    if (score != null && (!score.isFinite || score < 0 || score > 1)) {
      throw const FormatException('Score must be between 0 and 1.');
    }
    final now = DateTime.now().toUtc();
    final topicKey = cleanTopic.toLowerCase();
    final history = _events
        .where((event) =>
            (event['topic'] as String? ?? '').trim().toLowerCase() == topicKey)
        .toList()
      ..sort((a, b) => DateTime.parse(b['recordedAt'] as String)
          .compareTo(DateTime.parse(a['recordedAt'] as String)));
    final previousScore = history.isEmpty ? null : history.first['score'];
    final previousInterval = history.isEmpty
        ? null
        : DateTime.parse(history.first['reviewAt'] as String)
            .difference(DateTime.parse(history.first['recordedAt'] as String))
            .inDays;
    final interval = reviewDays ??
        (misconception?.trim().isNotEmpty == true || score == null || score < .5
            ? 1
            : score < .8
                ? 3
                : previousScore is num && previousScore >= .8
                    ? ((previousInterval ?? 7) * 2).clamp(7, 30)
                    : 7);
    if (reviewDays != null && (reviewDays < 1 || reviewDays > 60)) {
      throw const FormatException(
          'Review interval must be between 1 and 60 days.');
    }
    final event = <String, Object?>{
      'id': now.microsecondsSinceEpoch.toRadixString(36),
      'agent': agent,
      'kind': kind,
      'topic': cleanTopic,
      'evidence': cleanEvidence,
      if (score != null) 'score': score,
      if (misconception?.trim().isNotEmpty == true)
        'misconception': misconception!.trim(),
      'recordedAt': now.toIso8601String(),
      'reviewAt':
          now.add(Duration(days: interval.clamp(1, 60))).toIso8601String(),
    };
    _events.add(event);
    if (_events.length > 2000) _events.removeRange(0, _events.length - 2000);
    await _persist();
    return Map.unmodifiable(event);
  }

  Future<void> clear() async {
    _events.clear();
    await _persist();
  }

  Future<void> _persist() {
    final write = _writeQueue.catchError((_) {}).then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(_events));
      await temporary.rename(file.path);
    });
    _writeQueue = write;
    return write;
  }
}

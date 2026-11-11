import 'workspace_notes.dart';

/// Recover the student's request without treating attached context as intent.
String studentRequestFromMessages(List<Map<String, dynamic>> messages) {
  for (final message in messages.reversed) {
    if (message['role'] != 'user') {
      continue;
    }
    final parts = message['content'];
    if (parts is! List ||
        parts.any((part) =>
            part is Map &&
            (part.containsKey('toolResponse') ||
                part.containsKey('toolRequest')))) {
      continue;
    }
    final metadata = message['metadata'];
    final lumi = metadata is Map ? metadata['lumi'] : null;
    if (lumi is Map &&
        lumi['version'] == 1 &&
        lumi['studentPrompt'] is String) {
      return lumi['studentPrompt'] as String;
    }
    final text = parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
    if (text.isEmpty) {
      continue;
    }
    if (text.startsWith('Use this open note if relevant.') ||
        text.startsWith('Use the currently open canvas as context.') ||
        text.startsWith('Browser capability:')) {
      const marker = '\n\nRequest: ';
      final index = text.lastIndexOf(marker);
      if (index >= 0) {
        return text.substring(index + marker.length);
      }
    }
    return text;
  }
  return '';
}

/// A conservative write gate: viewing a Canvas does not request a new Canvas.
bool requestsCanvasCreation(String request) {
  if (RegExp(
          r"\b(?:without|no|not|instead of|rather than)\s+(?:(?:a|any|new)\s+)?canvas(?:es)?\b|\b(?:don't|do not|never)\s+(?:create|make|build|generate|add)\s+(?:(?:a|any|new)\s+)?canvas(?:es)?\b",
          caseSensitive: false)
      .hasMatch(request)) {
    return false;
  }
  return RegExp(
          r'\b(?:create|make|build|generate|start|add|open|set up)\b(?:(?!\b(?:note|notes|on|in|to|existing|current)\b)[^.!?\n]){0,80}\bcanvas(?:es)?\b|\b(?:and|with)\s+(?:a\s+)?(?:new\s+)?canvas\b|\b(?:put|organize|place)\b[^.!?\n]{0,80}\b(?:on|onto|into|in)\s+(?:a|new)\s+canvas\b',
          caseSensitive: false)
      .hasMatch(request);
}

/// A note-only write path: no Canvas store or Canvas creation operation exists here.
Future<WorkspaceNote> createAgentWorkspaceNote(
    WorkspaceNotes notes, Map<String, dynamic> input) async {
  final title = input['title'];
  final content = input['content'];
  if (title is! String ||
      title.trim().isEmpty ||
      title.trim().length > 120 ||
      content is! String ||
      content.trim().isEmpty ||
      content.trim().length > 12000) {
    throw const FormatException(
        'Note not created: provide a meaningful title up to 120 characters and the complete requested content up to 12000 characters. Empty notes are not allowed.');
  }
  return notes.save(title: title.trim(), content: content.trim());
}

import 'dart:convert';
import 'dart:io';

/// Removes one Genkit session and every persisted snapshot in its history.
class AgentSessions {
  AgentSessions(Directory storeDirectory)
      : _globalDirectory = Directory(
          '${storeDirectory.path}${Platform.pathSeparator}global',
        );

  final Directory _globalDirectory;

  Future<bool> delete(String sessionId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(sessionId)) {
      throw const FormatException('Invalid conversation ID.');
    }

    var deleted = false;
    if (await _globalDirectory.exists()) {
      await for (final entity in _globalDirectory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final value = jsonDecode(await entity.readAsString());
          if (value is! Map<String, dynamic>) continue;
          final state = value['state'];
          final storedId = value['sessionId'] ??
              (state is Map<String, dynamic> ? state['sessionId'] : null);
          if (storedId == sessionId) {
            await entity.delete();
            deleted = true;
          }
        } on FormatException {
          // Ignore damaged snapshots and continue deleting the known session.
        }
      }
    }

    final pointer = File(
      '${_globalDirectory.path}${Platform.pathSeparator}.pointers'
      '${Platform.pathSeparator}$sessionId.json',
    );
    if (await pointer.exists()) {
      await pointer.delete();
      deleted = true;
    }
    return deleted;
  }
}

import 'dart:convert';
import 'dart:io';

/// A small local profile containing only preferences the user has shared.
final class UserProfile {
  UserProfile(this.file);

  static const maxPreferences = 20;
  static const maxPreferenceLength = 180;

  final File file;
  final List<String> _preferences = [];
  Future<void> _writeQueue = Future<void>.value();

  List<String> get preferences => List.unmodifiable(_preferences);

  Future<void> load() async {
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _preferences
      ..clear()
      ..addAll(
          (json['preferences'] as List<dynamic>? ?? const []).cast<String>());
  }

  Future<void> reload() async {
    _preferences.clear();
    await load();
  }

  Future<bool> remember(String preference) async {
    final clean = preference.trim();
    if (clean.isEmpty || clean.length > maxPreferenceLength) {
      throw const FormatException('Preference must be 1 to 180 characters.');
    }
    if (!RegExp(r'^(?:I prefer|I learn best|I like|Please use|Avoid)\b',
            caseSensitive: false)
        .hasMatch(clean)) {
      throw const FormatException(
          'Save only a clear learning or communication preference.');
    }
    if (RegExp(r'\b(password|api key|access token|secret|credential)\b',
            caseSensitive: false)
        .hasMatch(clean)) {
      throw const FormatException('Sensitive credentials cannot be saved.');
    }
    if (_preferences
        .any((saved) => saved.toLowerCase() == clean.toLowerCase())) {
      return false;
    }
    if (_preferences.length >= maxPreferences) {
      throw const FormatException(
          'The preference list is full; remove one first.');
    }
    _preferences.add(clean);
    await _persist();
    return true;
  }

  Future<bool> forget(String preference) async {
    final index = _preferences.indexWhere(
      (saved) => saved.toLowerCase() == preference.trim().toLowerCase(),
    );
    if (index < 0) return false;
    _preferences.removeAt(index);
    await _persist();
    return true;
  }

  Future<void> clear() async {
    _preferences.clear();
    await _persist();
  }

  Future<void> _persist() {
    final write = _writeQueue.catchError((_) {}).then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode({'preferences': _preferences}));
      await temporary.rename(file.path);
    });
    _writeQueue = write;
    return write;
  }
}

import 'dart:convert';
import 'dart:io';
import '../data/app_settings.dart';

class AppSettingsStore {
  AppSettingsStore(this.file);
  final File file;
  AppSettings _settings = AppSettings();
  Future<void> _queue = Future.value();
  AppSettings get settings => _settings;

  Future<void> load() async {
    if (await file.exists()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'Application preferences must be an object');
      }
      _settings = AppSettings(decoded);
    }
  }

  Future<void> reload() async {
    _settings = AppSettings();
    await load();
  }

  Future<void> save(Map<String, dynamic> patch) {
    AppSettings.validate(patch);
    final operation = _queue.then((_) async {
      final next = AppSettings({..._settings.values, ...patch});
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(next.values), flush: true);
      await temporary.rename(file.path);
      _settings = next;
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }
}

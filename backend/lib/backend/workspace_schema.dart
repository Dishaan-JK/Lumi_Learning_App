import 'dart:convert';
import 'dart:io';

/// A forward-only manifest for the JSON workspace file set.
///
/// Existing workspaces without a manifest are the legacy v0 shape and are
/// adopted as v1 without changing their content. Future changes add immutable
/// migration steps here before a store is loaded.
final class WorkspaceSchema {
  WorkspaceSchema(this.dataDirectory);

  static const currentVersion = 1;
  static const storeVersions = <String, int>{
    'workspace-notes.json': 1,
    'workspace-folders.json': 1,
    'workspace-canvases.json': 1,
    'academic-artifacts.json': 1,
    'user-profile.json': 1,
    'student-learning-record.json': 1,
    'application-settings.json': 1,
  };
  final Directory dataDirectory;

  File get _manifest => File(
      '${dataDirectory.path}${Platform.pathSeparator}workspace-schema.json');

  Future<void> prepare() async {
    await dataDirectory.create(recursive: true);
    if (!await _manifest.exists()) {
      await _writeManifest(currentVersion, migratedFrom: 0);
      return;
    }
    final decoded = jsonDecode(await _manifest.readAsString());
    if (decoded is! Map || decoded['version'] is! int) {
      throw const FormatException('Workspace schema manifest is invalid.');
    }
    final version = decoded['version'] as int;
    if (version > currentVersion) {
      throw FormatException('This workspace needs Lumi $version or newer.');
    }
    var migrated = version;
    while (migrated < currentVersion) {
      // Keep migrations explicit and forward-only. v0 was the unmanifested
      // legacy collection layout, so adoption has no data rewrite.
      if (migrated == 0) {
        migrated = 1;
      } else {
        throw FormatException(
            'No migration is available from workspace schema $migrated.');
      }
    }
    final rawStores = decoded['stores'];
    final validStores = rawStores is Map &&
        rawStores.length == storeVersions.length &&
        storeVersions.entries
            .every((entry) => rawStores[entry.key] == entry.value);
    if (migrated != version || !validStores) {
      await _writeManifest(migrated, migratedFrom: version);
    }
  }

  Future<void> _writeManifest(int version, {required int migratedFrom}) async {
    final temporary = File('${_manifest.path}.tmp');
    await temporary.writeAsString(
        jsonEncode({
          'version': version,
          'migratedFrom': migratedFrom,
          'stores': storeVersions,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true);
    await temporary.rename(_manifest.path);
  }

  /// Quarantines a malformed store instead of preventing every other local
  /// workspace collection from opening. The original bytes remain recoverable.
  Future<void> loadWithRecovery(
      String fileName, Future<void> Function() load) async {
    try {
      await load();
    } on FormatException catch (_) {
      await _quarantine(fileName);
      await load();
    } on TypeError catch (_) {
      await _quarantine(fileName);
      await load();
    }
  }

  Future<void> _quarantine(String fileName) async {
    final source =
        File('${dataDirectory.path}${Platform.pathSeparator}$fileName');
    if (!await source.exists()) {
      throw StateError('Workspace data disappeared while recovering it.');
    }
    final recovered =
        File('${source.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}');
    await source.rename(recovered.path);
    stderr.writeln(
        'Lumi quarantined malformed workspace data at ${recovered.path}.');
  }
}

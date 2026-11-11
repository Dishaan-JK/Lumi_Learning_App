import 'dart:convert';
import 'dart:io';

/// Crash-recoverable transaction for a related set of local workspace files.
///
/// The journal is removed only after every write completes. If the process or
/// machine stops during the operation, startup restores the pre-operation file
/// set before any store reads it. This deliberately favors the previous valid
/// workspace over a potentially mixed generation.
final class WorkspaceTransaction {
  WorkspaceTransaction({
    required this.dataDirectory,
    required this.fileNames,
    this.includeAttachments = false,
  });

  static const journalFileName = '.workspace-transaction.json';
  final Directory dataDirectory;
  final List<String> fileNames;
  final bool includeAttachments;

  File get _journal =>
      File('${dataDirectory.path}${Platform.pathSeparator}$journalFileName');

  Future<T> run<T>(Future<T> Function() operation) async {
    await dataDirectory.create(recursive: true);
    final recoveryName =
        '.workspace-recovery-${DateTime.now().microsecondsSinceEpoch}';
    final recovery = Directory(
        '${dataDirectory.path}${Platform.pathSeparator}$recoveryName');
    await recovery.create();
    final existing = <String, bool>{};
    try {
      for (final name in fileNames) {
        final source =
            File('${dataDirectory.path}${Platform.pathSeparator}$name');
        final present = await source.exists();
        existing[name] = present;
        if (present) {
          await source.copy('${recovery.path}${Platform.pathSeparator}$name');
        }
      }
      final attachmentSource = Directory(
          '${dataDirectory.path}${Platform.pathSeparator}attachments');
      final attachmentsPresent =
          includeAttachments && await attachmentSource.exists();
      if (attachmentsPresent) {
        await _copyDirectory(attachmentSource,
            Directory('${recovery.path}${Platform.pathSeparator}attachments'));
      }
      await _journal.writeAsString(
          jsonEncode({
            'version': 1,
            'recovery': recoveryName,
            'files': existing,
            'attachmentsPresent': attachmentsPresent,
          }),
          flush: true);

      final value = await operation();
      await _journal.delete();
      await recovery.delete(recursive: true);
      return value;
    } catch (_) {
      await restoreIfNeeded(dataDirectory, fileNames);
      rethrow;
    }
  }

  static Future<void> restoreIfNeeded(
      Directory dataDirectory, List<String> allowedFiles) async {
    final journal =
        File('${dataDirectory.path}${Platform.pathSeparator}$journalFileName');
    if (!await journal.exists()) {
      return;
    }
    final decoded = jsonDecode(await journal.readAsString());
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['recovery'] is! String ||
        decoded['files'] is! Map ||
        decoded['attachmentsPresent'] is! bool) {
      throw const FormatException('Workspace recovery journal is invalid.');
    }
    final recoveryName = decoded['recovery'] as String;
    if (!RegExp(r'^\.workspace-recovery-[0-9]+$').hasMatch(recoveryName)) {
      throw const FormatException('Workspace recovery journal is invalid.');
    }
    final files = Map<String, dynamic>.from(decoded['files'] as Map);
    if (files.keys.any((name) => !allowedFiles.contains(name)) ||
        files.values.any((present) => present is! bool)) {
      throw const FormatException('Workspace recovery journal is invalid.');
    }
    final recovery = Directory(
        '${dataDirectory.path}${Platform.pathSeparator}$recoveryName');
    if (!await recovery.exists()) {
      throw const FormatException('Workspace recovery data is missing.');
    }

    // Prove the entire rollback generation is available before touching the
    // current files. A damaged recovery directory must not cause a second,
    // partial loss while attempting to recover it.
    for (final name in allowedFiles) {
      if (files[name] != true) {
        continue;
      }
      final backup = File('${recovery.path}${Platform.pathSeparator}$name');
      if (!await backup.exists()) {
        throw const FormatException('Workspace recovery data is missing.');
      }
    }
    if (decoded['attachmentsPresent'] == true) {
      final backup =
          Directory('${recovery.path}${Platform.pathSeparator}attachments');
      if (!await backup.exists()) {
        throw const FormatException(
            'Workspace attachment recovery data is missing.');
      }
    }

    for (final name in allowedFiles) {
      final destination =
          File('${dataDirectory.path}${Platform.pathSeparator}$name');
      if (await destination.exists()) {
        await destination.delete();
      }
      if (files[name] == true) {
        final backup = File('${recovery.path}${Platform.pathSeparator}$name');
        await backup.copy(destination.path);
      }
    }
    final attachments =
        Directory('${dataDirectory.path}${Platform.pathSeparator}attachments');
    if (await attachments.exists()) {
      await attachments.delete(recursive: true);
    }
    if (decoded['attachmentsPresent'] == true) {
      final backup =
          Directory('${recovery.path}${Platform.pathSeparator}attachments');
      await _copyDirectory(backup, attachments);
    }
    await journal.delete();
    await recovery.delete(recursive: true);
  }

  static Future<void> _copyDirectory(
      Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relative = entity.path.substring(source.path.length + 1);
      final target =
          File('${destination.path}${Platform.pathSeparator}$relative');
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }
}

import 'dart:io';
import 'dart:math' as math;

const gibibyte = 1024 * 1024 * 1024;
typedef HardwareCommand = Future<ProcessResult> Function(String, List<String>);

/// Read-only Linux inventory. A detected device is not a verified Ollama device.
class HardwareProbe {
  HardwareProbe(
      {this.procRoot = '/proc',
      this.sysRoot = '/sys',
      this.modelDirectory,
      HardwareCommand? command})
      : command = command ?? ((name, args) => Process.run(name, args));
  final String procRoot, sysRoot;
  String? modelDirectory;
  final HardwareCommand command;

  /// The user chooses the existing Ollama model directory before download so
  /// Lumi can validate the filesystem that will receive the checkpoint.
  Future<void> selectModelDirectory(String path) async {
    if (!path.startsWith('/') || path.length > 4096) {
      throw const FormatException('Choose an absolute local folder path.');
    }
    if (!await Directory(path).exists()) {
      throw const FormatException(
          'That model folder does not exist on this computer.');
    }
    modelDirectory = path;
  }

  Future<String> _read(String path) async {
    try {
      return await File(path).readAsString();
    } on FileSystemException {
      return '';
    }
  }

  Future<String> _run(String name, List<String> args) async {
    try {
      final result =
          await command(name, args).timeout(const Duration(seconds: 5));
      return result.exitCode == 0 ? result.stdout.toString().trim() : '';
    } on Object {
      return '';
    }
  }

  static Map<String, int> parseMemory(String text) => {
        for (final match in RegExp(r'^(\w+):\s+(\d+)\s+kB', multiLine: true)
            .allMatches(text))
          match[1]!: int.parse(match[2]!) * 1024,
      };
  static (int, int)? _cpuTicks(String text) {
    final line = text.split('\n').firstOrNull ?? '';
    final ticks = line
        .trim()
        .split(RegExp(r'\s+'))
        .skip(1)
        .take(8)
        .map(int.tryParse)
        .toList();
    if (ticks.length < 5 || ticks.any((v) => v == null)) return null;
    return (ticks.fold(0, (a, b) => a + b!), ticks[3]! + ticks[4]!);
  }

  Future<Map<String, dynamic>> inspect() async {
    if (!Platform.isLinux && procRoot == '/proc') {
      return {
        'supported': false,
        'reason':
            'Automatic hardware validation currently requires a Linux backend host.',
        'gpus': <Map<String, dynamic>>[]
      };
    }
    final memory = parseMemory(await _read('$procRoot/meminfo'));
    final limit =
        int.tryParse((await _read('$sysRoot/fs/cgroup/memory.max')).trim()) ??
            int.tryParse(
                (await _read('$sysRoot/fs/cgroup/memory/memory.limit_in_bytes'))
                    .trim());
    final current = int.tryParse(
            (await _read('$sysRoot/fs/cgroup/memory.current')).trim()) ??
        int.tryParse(
            (await _read('$sysRoot/fs/cgroup/memory/memory.usage_in_bytes'))
                .trim());
    final physicalTotal = memory['MemTotal'];
    if (limit != null &&
        limit > 0 &&
        current != null &&
        limit < (physicalTotal ?? 0)) {
      memory['MemTotal'] = limit;
      memory['MemAvailable'] =
          math.min(memory['MemAvailable'] ?? 0, math.max(0, limit - current));
    }
    final info = await _read('$procRoot/cpuinfo');
    final before = _cpuTicks(await _read('$procRoot/stat'));
    final pci = await _run('lspci', ['-Dnn']);
    final devices = <Map<String, dynamic>>[];
    for (final line in pci.split('\n').where((s) => RegExp(
            r'VGA compatible|3D controller|Display controller',
            caseSensitive: false)
        .hasMatch(s))) {
      final address = line.split(' ').first;
      final ids =
          RegExp(r'\[([0-9a-f]{4}):([0-9a-f]{4})\]', caseSensitive: false)
              .allMatches(line)
              .lastOrNull;
      final vendor = switch (ids?[1]?.toLowerCase()) {
        '10de' => 'NVIDIA',
        '1002' => 'AMD',
        '8086' => 'Intel',
        _ => 'Unknown'
      };
      devices.add({
        'id': address,
        'name': line.substring(address.length).trim(),
        'vendor': vendor,
        'memoryType': 'unknown',
        'totalBytes': null,
        'availableBytes': null,
        'usagePercent': null,
        'runtimeVerified': false
      });
    }
    final drm = Directory('$sysRoot/class/drm');
    if (await drm.exists()) {
      await for (final card in drm.list()) {
        if (!RegExp(r'^card\d+$').hasMatch(card.path.split('/').last)) continue;
        final path = '${card.path}/device';
        String address;
        try {
          address =
              (await Directory(path).resolveSymbolicLinks()).split('/').last;
        } on FileSystemException {
          address = card.path.split('/').last;
        }
        final vendorId = (await _read('$path/vendor')).trim().toLowerCase();
        final vendor = switch (vendorId) {
          '0x10de' => 'NVIDIA',
          '0x1002' => 'AMD',
          '0x8086' => 'Intel',
          _ => 'Unknown'
        };
        final existing = devices.where((d) => d['id'] == address).firstOrNull;
        final device = existing ??
            {
              'id': address,
              'name':
                  '$vendor graphics (${(await _read('$path/device')).trim()})',
              'vendor': vendor,
              'runtimeVerified': false
            };
        final total =
            int.tryParse((await _read('$path/mem_info_vram_total')).trim());
        final used =
            int.tryParse((await _read('$path/mem_info_vram_used')).trim());
        final name = device['name'].toString();
        final shared = vendor == 'Intel' &&
                RegExp(r'Intel Graphics|UHD|Iris|HD Graphics|Integrated',
                        caseSensitive: false)
                    .hasMatch(name) ||
            vendor == 'AMD' &&
                RegExp(r'Renoir|Cezanne|Raphael|Phoenix|Strix|Rembrandt|Raven|Picasso|Lucienne|Mendocino|Radeon Graphics|Integrated',
                        caseSensitive: false)
                    .hasMatch(name);
        String? driver;
        try {
          driver = (await Directory('$path/driver').resolveSymbolicLinks())
              .split('/')
              .last;
        } on FileSystemException {/* Optional driver detail. */}
        device.addAll({
          'driver': driver,
          'memoryType': shared
              ? 'shared'
              : total != null && total > 0
                  ? 'dedicated'
                  : 'unknown',
          'totalBytes': shared ? null : total,
          'availableBytes': shared || total == null || used == null
              ? null
              : math.max(0, total - used),
          'usagePercent':
              int.tryParse((await _read('$path/gpu_busy_percent')).trim()),
          'note': shared
              ? 'Uses system RAM; not additional memory.'
              : 'GPU use must be verified by Ollama after loading.'
        });
        if (existing == null) devices.add(device);
      }
    }
    final smi = await _run('nvidia-smi', [
      '--query-gpu=pci.bus_id,name,memory.total,memory.free,utilization.gpu,driver_version',
      '--format=csv,noheader,nounits'
    ]);
    for (final row in smi.split('\n').where((s) => s.trim().isNotEmpty)) {
      final fields = row.split(',').map((s) => s.trim()).toList();
      if (fields.length != 6) continue;
      final id =
          fields[0].toLowerCase().replaceFirst(RegExp(r'^00000000:'), '0000:');
      final gpu = devices
              .where((d) => d['id'].toString().toLowerCase() == id)
              .firstOrNull ??
          <String, dynamic>{'id': id};
      gpu.addAll({
        'name': fields[1],
        'vendor': 'NVIDIA',
        'memoryType': 'dedicated',
        'totalBytes': int.tryParse(fields[2]) == null
            ? null
            : int.parse(fields[2]) * 1024 * 1024,
        'availableBytes': int.tryParse(fields[3]) == null
            ? null
            : int.parse(fields[3]) * 1024 * 1024,
        'usagePercent': int.tryParse(fields[4]),
        'driverVersion': fields[5],
        'runtimeVerified': false
      });
      if (!devices.contains(gpu)) devices.add(gpu);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final after = _cpuTicks(await _read('$procRoot/stat'));
    double? cpuUsage;
    if (before != null && after != null && after.$1 > before.$1) {
      cpuUsage = (100 * (1 - (after.$2 - before.$2) / (after.$1 - before.$1)))
          .clamp(0, 100);
    }
    final storage = await _storage();
    return {
      'supported':
          (memory['MemTotal'] ?? 0) > 0 && memory.containsKey('MemAvailable'),
      'cpu': {
        'name': RegExp(r'^model name\s*:\s*(.+)$', multiLine: true)
                .firstMatch(info)?[1] ??
            Platform.operatingSystem,
        'vendor': RegExp(r'^vendor_id\s*:\s*(.+)$', multiLine: true)
                .firstMatch(info)?[1] ??
            'Unknown',
        'threads': Platform.numberOfProcessors,
        'usagePercent': cpuUsage
      },
      'memory': {
        'totalBytes': memory['MemTotal'] ?? 0,
        'physicalTotalBytes': physicalTotal,
        'containerLimitBytes':
            limit != null && limit < (physicalTotal ?? 0) ? limit : null,
        'availableBytes': memory['MemAvailable'] ?? 0
      },
      'gpus': devices,
      'storage': storage,
      'checkedAt': DateTime.now().toUtc().toIso8601String()
    };
  }

  Future<List<String>> _daemonModelDirectories() async {
    final found = <String>{};
    try {
      await for (final process in Directory(procRoot).list()) {
        if (!RegExp(r'^\d+$').hasMatch(process.path.split('/').last)) continue;
        if ((await _read('${process.path}/comm')).trim() != 'ollama') continue;
        // Read only these two non-secret path values; never return environment contents.
        final environment = (await _read('${process.path}/environ'))
            .split(String.fromCharCode(0));
        final models = environment
            .where((s) => s.startsWith('OLLAMA_MODELS='))
            .firstOrNull;
        final home =
            environment.where((s) => s.startsWith('HOME=')).firstOrNull;
        if (models != null) {
          found.add(models.substring('OLLAMA_MODELS='.length));
        } else if (home != null) {
          found.add('${home.substring(5)}/.ollama/models');
        }
      }
    } on FileSystemException {
      /* Explicit directory configuration remains available. */
    }
    return found.toList();
  }

  Future<Map<String, dynamic>> _storage() async {
    // Explicit configuration is preferred. The service may run as another user.
    final daemonPaths = await _daemonModelDirectories();
    final candidates = [
      if (modelDirectory != null) modelDirectory!,
      if (Platform.environment['OLLAMA_MODELS'] != null)
        Platform.environment['OLLAMA_MODELS']!,
      if (daemonPaths.length == 1) daemonPaths.single,
      '/var/lib/ollama/models',
      '/var/lib/ollama/.ollama/models',
      '/usr/share/ollama/.ollama/models',
      '${Platform.environment['HOME']}/.ollama/models'
    ];
    for (final path in candidates) {
      try {
        if (!await Directory(path).exists()) continue;
      } on FileSystemException {
        continue;
      }
      final df = await _run('df', ['-PB1', path]);
      final line = df.split('\n').lastOrNull?.trim().split(RegExp(r'\s+'));
      if (line != null && line.length >= 6 && int.tryParse(line[3]) != null) {
        return {
          'path': path,
          'availableBytes': int.parse(line[3]),
          'source': modelDirectory != null ||
                  Platform.environment['OLLAMA_MODELS'] != null
              ? 'configured'
              : 'inferred default'
        };
      }
    }
    return {
      'path': null,
      'availableBytes': null,
      'source': 'unknown',
      'note':
          'Set LUMI_OLLAMA_MODELS_DIR to the Ollama server model directory to validate disk space.'
    };
  }
}

/// FP16 K+V allocation for conventional transformer attention, when exposed by
/// Ollama. Hybrid/state-space models fall back to the provisional allowance.
int? modelKvCacheBytes(Map info, int context) {
  final architecture = info['general.architecture'];
  if (architecture is! String) return null;
  final layers = info['$architecture.block_count'];
  final embedding = info['$architecture.embedding_length'];
  final heads = info['$architecture.attention.head_count'];
  final kvHeads = info['$architecture.attention.head_count_kv'] ?? heads;
  if ([layers, embedding, heads, kvHeads].any((n) => n is! num || n <= 0)) {
    return null;
  }
  return (4 *
          (layers as num) *
          context *
          (kvHeads as num) *
          (embedding as num) /
          (heads as num))
      .ceil();
}

/// RAM-first admission. Current available RAM is the only live headroom input;
/// the UI warns rather than reserving capacity for the OS or other processes.
Map<String, dynamic> assessModel(
    {required Map<String, dynamic> hardware,
    required int fileBytes,
    required int context,
    required String execution,
    bool includeDownload = true,
    int? cacheBytes}) {
  if (![2048, 4096, 8192].contains(context) ||
      !['auto', 'cpu', 'gpu'].contains(execution) ||
      fileBytes <= 0) {
    throw const FormatException(
        'Choose a valid file, context length and execution mode.');
  }
  final memory = hardware['memory'] as Map? ?? {};
  final total = (memory['totalBytes'] as num?)?.toInt() ?? 0;
  final available = (memory['availableBytes'] as num?)?.toInt() ?? 0;
  final gpus = (hardware['gpus'] as List? ?? []).cast<Map>();
  final overhead = math.max(gibibyte, (fileBytes * .25).ceil());
  // Before GGUF is available locally, use a generous cache allowance. Actual
  // allocation is measured after loading at this exact context length.
  final cache =
      math.max(cacheBytes ?? 0, (2 * gibibyte * context / 4096).ceil());
  final required = fileBytes + overhead + cache;
  final disk = (hardware['storage'] as Map?)?['availableBytes'] as num?;
  final blocks = <String>[];
  final warnings = <String>[
    'Memory estimates include weights, a conservative KV-cache allowance and runtime overhead. They are not a throughput or utilisation guarantee.'
  ];
  if (hardware['supported'] != true) {
    blocks.add('Reliable host RAM detection is unavailable.');
  }
  if (fileBytes > total) {
    blocks.add(
        'This GGUF file is larger than this computer’s total RAM and cannot be downloaded for Lumi.');
  }
  final caution = overhead > gibibyte || required > available;
  if (overhead > gibibyte) {
    warnings.add(
        'This model needs more than 1 GiB of runtime overhead. Running it may freeze the system.');
  }
  if (required > available) {
    warnings.add(
        'The estimated loaded model size exceeds RAM currently available. Downloading is allowed, but loading it may freeze the system.');
  }
  if (includeDownload && disk == null) {
    warnings.add(
        'Ollama storage free space is unavailable to this backend user. Ollama will enforce disk capacity during download; configure LUMI_OLLAMA_MODELS_DIR for a pre-download disk check.');
  } else if (includeDownload &&
      disk != null &&
      disk < fileBytes * 1.2 + gibibyte) {
    blocks
        .add('Insufficient free space in the Ollama model storage filesystem.');
  }
  if (execution == 'gpu' && gpus.isEmpty) {
    blocks.add('No GPU was detected. Choose CPU mode or repair GPU discovery.');
  }
  final dedicated = gpus.where((g) => g['memoryType'] == 'dedicated').toList();
  final bestVram = dedicated.fold<int>(
      0, (a, g) => math.max(a, (g['availableBytes'] as num?)?.toInt() ?? 0));
  if (execution == 'gpu' &&
      dedicated.isNotEmpty &&
      !gpus.any((g) => g['memoryType'] != 'dedicated') &&
      dedicated.every((g) => g['availableBytes'] is num) &&
      bestVram < required) {
    blocks.add(
        'The estimated model allocation exceeds the largest available dedicated GPU memory budget. Use Auto for partial offload or choose a smaller model.');
  }
  if (gpus.any((g) => g['memoryType'] == 'shared')) {
    warnings.add(
        'Integrated graphics share system RAM. This capacity is counted only once.');
  }
  if (gpus.any((g) => g['usagePercent'] == null)) {
    warnings.add(
        'Live utilisation is unavailable for one or more GPUs; it will not be estimated as a percentage.');
  }
  final cpu = hardware['cpu'] as Map? ?? {};
  if ((cpu['usagePercent'] as num? ?? 0) > 75) {
    warnings.add(
        'The CPU is already busy. Inference may compete with current work.');
  }
  final ratio = available == 0 ? 1.0 : required / available;
  final cpuPath = execution == 'cpu' || gpus.isEmpty;
  return {
    'allowed': blocks.isEmpty,
    'blocks': blocks,
    'warnings': warnings,
    'fileBytes': fileBytes,
    'estimatedRamBytes': required,
    'runtimeOverheadBytes': overhead,
    'cacheAllowanceBytes': cache,
    'requiresCaution': caution,
    'currentAvailableRamBytes': available,
    'availableRamAfterLoadBytes': math.max(0, available - required),
    'difficulty': ratio > .8
        ? 'High memory pressure'
        : cpuPath && fileBytes > 4 * gibibyte
            ? 'Heavy CPU workload'
            : cpuPath
                ? 'CPU inference; latency depends on model size'
                : 'GPU candidate; runtime verification required',
    'expectedCpuLoad': cpuPath
        ? 'High while generating'
        : 'Low to high, depending on GPU offload',
    'expectedGpuLoad': execution == 'cpu'
        ? 'Not requested'
        : 'High if acceleration is supported; otherwise CPU fallback in Auto mode',
    'context': context,
    'execution': execution
  };
}

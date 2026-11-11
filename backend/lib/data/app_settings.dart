/// Shared, validated application preferences. Provider credentials live separately.
class AppSettings {
  AppSettings([Map<String, dynamic> values = const {}])
      : values = Map.unmodifiable({...defaults, ...validate(values)});
  final Map<String, dynamic> values;

  static const defaults = <String, dynamic>{
    'displayName': '',
    'studentClass': '',
    'schoolName': '',
    'studentProfileCompleted': false,
    'workspaceName': 'My workspace',
    'startPage': 'artifacts',
    'theme': 'light',
    'accent': 'sage',
    'rotateAccent': true,
    'textSize': 'standard',
    'density': 'comfortable',
    'reduceMotion': false,
    'canvasPattern': 'dots',
    'canvasBackgroundLight': '#F4F1E8',
    'canvasBackgroundDark': '#191C19',
    'canvasPatternLight': '#C4C7BC',
    'canvasPatternDark': '#465046',
    'teachingStyle': 'balanced',
    'difficulty': 'adaptive',
    'questionCount': 5,
    'coachContext': true,
    'rememberPreferences': true,
    'autoUnloadModelOnLowRam': false,
    'editorMode': 'edit',
    'editorWidth': 'focused',
    'autosaveDelay': 700,
    'spellcheck': true,
    'artifactLayout': 'grid',
    'artifactSort': 'Newest first',
    'recentLimit': 12,
  };
  static const choices = <String, List<String>>{
    'startPage': ['home', 'artifacts', 'canvas', 'notes'],
    'theme': ['light', 'dark', 'system'],
    'accent': ['sage', 'blue', 'lightOrange', 'maroon'],
    'textSize': ['small', 'standard', 'large'],
    'density': ['comfortable', 'compact'],
    'canvasPattern': ['dots', 'grid', 'none'],
    'teachingStyle': ['balanced', 'concise', 'step-by-step', 'socratic'],
    'difficulty': ['adaptive', 'beginner', 'intermediate', 'advanced'],
    'editorMode': ['edit', 'preview'],
    'editorWidth': ['focused', 'wide'],
    'artifactLayout': ['grid', 'list'],
    'artifactSort': ['Newest first', 'Oldest first', 'Title A–Z'],
  };
  static const canvasColorKeys = {
    'canvasBackgroundLight',
    'canvasBackgroundDark',
    'canvasPatternLight',
    'canvasPatternDark',
  };

  static Map<String, dynamic> validate(Map<String, dynamic> patch) {
    for (final entry in patch.entries) {
      final key = entry.key, value = entry.value;
      if (!defaults.containsKey(key)) {
        throw FormatException('Unknown preference: $key');
      }
      final initial = defaults[key];
      if (initial is bool && value is! bool ||
          initial is int && value is! int ||
          initial is String && value is! String) {
        throw FormatException('Invalid value for $key');
      }
      if (choices.containsKey(key) && !choices[key]!.contains(value)) {
        throw FormatException('Choose a supported value for $key');
      }
      if (value is String &&
          (value.length > 80 || value.contains(RegExp(r'[\x00-\x1f]')))) {
        throw FormatException(
            '$key must contain at most 80 printable characters');
      }
      if (canvasColorKeys.contains(key) &&
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value as String)) {
        throw const FormatException(
            'Canvas colours must use six hex digits, such as #F4F1E8.');
      }
      if (key == 'workspaceName' && (value as String).trim().isEmpty) {
        throw const FormatException('Enter a workspace name');
      }
      if (key == 'questionCount' && (value < 1 || value > 20) ||
          key == 'recentLimit' && ![5, 12, 20].contains(value) ||
          key == 'autosaveDelay' && ![500, 700, 1500, 3000].contains(value)) {
        throw FormatException('Value outside the supported range for $key');
      }
    }
    if (patch['studentProfileCompleted'] == true &&
        ['displayName', 'studentClass', 'schoolName'].any((key) =>
            patch[key] is! String || (patch[key] as String).trim().isEmpty)) {
      throw const FormatException('Enter your name, class, and school name.');
    }
    return Map<String, dynamic>.from(patch);
  }

  String text(String key) => values[key] as String;
  bool flag(String key) => values[key] as bool;
  int number(String key) => values[key] as int;
}

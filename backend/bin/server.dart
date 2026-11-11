import 'dart:convert';
import 'dart:async';
import 'package:lumi_backend/backend/app_settings_store.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:lumi_backend/data/app_settings.dart';
import 'package:genkit/experimental.dart';
import 'package:genkit/experimental_io.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart' as claude_provider;
import 'package:genkit_google_genai/genkit_google_genai.dart'
    as gemini_provider;
import 'package:genkit_openai/genkit_openai.dart' as openai_provider;
import 'package:schemantic/schemantic.dart';

import 'package:lumi_backend/backend/workspace_notes.dart';
import 'package:lumi_backend/backend/agent_workspace_actions.dart';
import 'package:lumi_backend/backend/workspace_folders.dart';
import 'package:lumi_backend/backend/workspace_canvases.dart';
import 'package:lumi_backend/backend/user_profile.dart';
import 'package:lumi_backend/backend/provider_settings.dart';
import 'package:lumi_backend/backend/agent_sessions.dart';
import 'package:lumi_backend/backend/learning_record.dart';
import 'package:lumi_backend/backend/academic_artifacts.dart';
import 'package:lumi_backend/backend/local_models.dart';
import 'package:lumi_backend/backend/origin_policy.dart';
import 'package:lumi_backend/backend/workspace_schema.dart';
import 'package:lumi_backend/backend/workspace_transaction.dart';

final dataDirectory = Directory(
  Platform.environment['LUMI_DATA_DIR'] ?? '${Directory.current.path}/.data',
);
final applicationSettings =
    AppSettingsStore(File('${dataDirectory.path}/application-settings.json'));
final academicArtifacts = AcademicArtifacts(
  File('${dataDirectory.path}/academic-artifacts.json'),
);
final agentSessionStore = ArchivingSessionStore(
  '${dataDirectory.path}/agent-sessions',
  academicArtifacts,
);
final agentSessions = AgentSessions(
  Directory('${dataDirectory.path}/agent-sessions'),
);
final providerSettingsFile =
    File('${dataDirectory.path}/provider-settings.json');
final localModels = LocalModels(
    jobFile: File('${dataDirectory.path}/local-model-job.json'),
    providerFile: providerSettingsFile,
    automaticSafetyEnabled: () =>
        applicationSettings.settings.flag('autoUnloadModelOnLowRam'));
final providerSettings = ProviderSettings.load(
  file: providerSettingsFile,
  environment: Platform.environment,
);
final apiMode = providerSettings.usesApi;
final configuredModel = providerSettings.model;
final configuredBaseUrl = providerSettings.baseUrl;
final configuredApiKey = apiMode ? providerSettings.apiKey : 'ollama';
final notes = WorkspaceNotes(
  File('${dataDirectory.path}/workspace-notes.json'),
);
final folders = WorkspaceFolders(
  File('${dataDirectory.path}/workspace-folders.json'),
);
final canvases = WorkspaceCanvases(
  File('${dataDirectory.path}/workspace-canvases.json'),
);
final userProfile = UserProfile(
  File('${dataDirectory.path}/user-profile.json'),
);
final learningRecord = LearningRecord(
  File('${dataDirectory.path}/student-learning-record.json'),
);
final attachmentsDirectory = Directory('${dataDirectory.path}/attachments');
final originPolicy = OriginPolicy.fromEnvironment(Platform.environment);
final workspaceSchema = WorkspaceSchema(dataDirectory);
Future<void> _workspaceMutationQueue = Future<void>.value();

final ai = Genkit(
  plugins: [
    if (providerSettings.provider == 'ollama' ||
        providerSettings.provider == 'openai' ||
        providerSettings.provider == 'compatible')
      openai_provider.openAI(
        apiKey: configuredApiKey,
        baseUrl: configuredBaseUrl,
        models: [
          openai_provider.CustomModelDefinition(
            name: configuredModel,
            info: ModelInfo(
              label: '${providerSettings.provider} model ($configuredModel)',
              supports: {
                'multiturn': true,
                'systemRole': true,
                'tools': true,
              },
            ),
          ),
        ],
      ),
    if (providerSettings.provider == 'anthropic')
      claude_provider.anthropic(
        apiKey: configuredApiKey,
        baseUrl: configuredBaseUrl,
      ),
    if (providerSettings.provider == 'gemini')
      gemini_provider.googleAI(apiKey: configuredApiKey),
  ],
  model: switch (providerSettings.provider) {
    'anthropic' => claude_provider.anthropic.model(configuredModel),
    'gemini' => gemini_provider.googleAI.gemini(configuredModel),
    _ => openai_provider.openAI.model(configuredModel),
  },
);

int _agentCapabilityToolExecutions = 0;

final agentCapabilityProbeTool = ai.defineTool<Map<String, String>, String>(
  name: 'lumiAgentCapabilityCheck',
  description:
      'Mandatory capability-check tool. Call it exactly once with the one-time marker supplied by the user.',
  inputSchema: _stringInput('marker'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final marker = input['marker'] ?? '';
    if (!RegExp(r'^lumi-agent-check-[a-f0-9]{16}$').hasMatch(marker)) {
      return ToolResult<String>.response('LUMI_AGENT_TOOL_MARKER_INVALID');
    }
    _agentCapabilityToolExecutions++;
    return ToolResult<String>.response('LUMI_AGENT_TOOL_EXECUTED:$marker');
  },
);

final agentCapabilityProbe = ai.defineAgent(
  name: 'agentCapabilityProbe',
  description: 'Runs a synthetic, side-effect-free agent tool-call check.',
  system:
      'You are checking Lumi agent capability. The user supplies a one-time '
      'marker. Call lumiAgentCapabilityCheck exactly once using that marker. '
      'The check passes only when the tool is actually called; never claim it '
      'passed without doing so. After it returns, reply with a short confirmation '
      'that repeats the tool result. Do not call any other tools.',
  tools: [agentCapabilityProbeTool],
  maxTurns: 2,
);

SchemanticType<Map<String, String>> _stringInput(String field) =>
    SchemanticType.from(
      jsonSchema: {
        'type': 'object',
        'properties': {
          field: {'type': 'string'}
        },
        'required': [field],
        'additionalProperties': false,
      },
      parse: (json) => (json as Map).map((key, value) => MapEntry(
          key.toString(),
          value is String || value is num || value is bool
              ? value.toString()
              : '')),
    );

SchemanticType<Map<String, dynamic>> _objectInput(
  Map<String, Object?> properties,
  List<String> required,
) =>
    SchemanticType.from(
      jsonSchema: {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': false,
      },
      parse: (json) => (json as Map).cast<String, dynamic>(),
    );

final searchNotesTool = ai.defineTool<Map<String, String>, String>(
  name: 'searchWorkspaceNotes',
  description:
      'Search local notes by title and content. Input is an object with a short search phrase in the query field.',
  inputSchema: _stringInput('query'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final query = input['query'] ?? '';
    final matches = notes.search(query).take(8).toList();
    if (matches.isEmpty) {
      return ToolResult<String>.response('No notes matched "$query".');
    }
    return ToolResult<String>.response(
      matches.map((note) {
        final excerpt = note.content.length > 500
            ? note.content.substring(0, 500)
            : note.content;
        return '[${note.id}] ${note.title}\n$excerpt';
      }).join('\n\n'),
    );
  },
);

final readNoteTool = ai.defineTool<Map<String, String>, String>(
  name: 'readWorkspaceNote',
  description:
      'Read one local note. Provide its note ID or a unique part of its title in the reference field.',
  inputSchema: _stringInput('reference'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final reference = input['reference'] ?? '';
    final key = reference.trim();
    if (key.isEmpty) {
      return ToolResult<String>.response('Provide a note ID or title.');
    }
    var note = notes.get(key);
    if (note == null) {
      final candidates = notes.list();
      final normalized = key.toLowerCase();
      note = candidates
          .where((candidate) => normalized.contains(candidate.id.toLowerCase()))
          .firstOrNull;
      final titleReference = key.split(RegExp(r'\s*\(id\s*:')).first.trim();
      note ??= candidates.where((candidate) {
        final title = candidate.title.toLowerCase();
        final reference = titleReference.toLowerCase();
        return title == reference ||
            title.contains(reference) ||
            reference.contains(title);
      }).firstOrNull;
    }
    if (note == null) {
      return ToolResult<String>.response('No matching note was found.');
    }
    return ToolResult<String>.response(
      '[${note.id}] ${note.title}\n\n${note.content}',
    );
  },
);

const _originalStudentRequest = #lumiOriginalStudentRequest;

String _studentRequest() =>
    Zone.current[_originalStudentRequest] as String? ??
    studentRequestFromMessages(ai
            .currentSession()
            ?.getMessages()
            .map((message) => message.toJson())
            .toList() ??
        []);

Future<T> _withStudentRequest<T>(Future<T> Function() action) => runZoned(
      action,
      zoneValues: {_originalStudentRequest: _studentRequest()},
    );

final createWorkspaceNoteTool = ai.defineTool<Map<String, dynamic>, String>(
  name: 'createWorkspaceNote',
  description:
      'Create one standalone note with its requested title and complete written content. Use for requests to create, save, or write a note. This tool never creates a Canvas. Write the requested explanation in content, not only in the chat reply.',
  inputSchema: _objectInput({
    'title': {'type': 'string', 'minLength': 1, 'maxLength': 120},
    'content': {'type': 'string', 'minLength': 1, 'maxLength': 12000},
  }, [
    'title',
    'content'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    try {
      final note = await createAgentWorkspaceNote(notes, input);
      return ToolResult<String>.response(_toolJson(
        status: 'success',
        summary:
            'Created note "${note.title}" with ${note.content.length} characters of saved content.',
        artifacts: [
          {'type': 'note', 'id': note.id, 'title': note.title}
        ],
      ));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

final createLearningWorkspaceTool = ai.defineTool<Map<String, dynamic>, String>(
  name: 'createLearningWorkspace',
  description:
      'Create a learning workspace only for an explicitly requested Canvas. For standalone notes use createWorkspaceNote instead. If they ask for a canvas, create useful notes and attach all of them to it in this one call. Only fill preferencesToRemember when the user explicitly states a durable preference or asks Lumi to remember it; otherwise use an empty list.',
  inputSchema: _objectInput({
    'canvasTitle': {
      'type': 'string',
      'description':
          'Name of the explicitly requested Canvas. For standalone note requests use createWorkspaceNote instead.'
    },
    'description': {
      'type': 'string',
      'description':
          'One sentence describing the learning goal; empty if not needed.'
    },
    'notes': {
      'type': 'array',
      'maxItems': 12,
      'items': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['title', 'content'],
        'additionalProperties': false,
      },
    },
    'preferencesToRemember': {
      'type': 'array',
      'maxItems': 5,
      'items': {'type': 'string', 'maxLength': UserProfile.maxPreferenceLength},
    },
  }, [
    'canvasTitle',
    'description',
    'notes',
    'preferencesToRemember'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final title = _textField(input, 'canvasTitle');
    if (title != null && !requestsCanvasCreation(_studentRequest())) {
      return ToolResult<String>.response(_toolJson(
        status: 'error',
        summary:
            'Canvas not created: the Student did not request a new Canvas. For a note request, use createWorkspaceNote with a meaningful title and complete content.',
      ));
    }
    final description = _textField(input, 'description') ?? '';
    final rawNotes = input['notes'];
    final rawPreferences = input['preferencesToRemember'];
    if (rawNotes is! List ||
        rawNotes.length > 12 ||
        rawNotes.any((item) => item is! Map) ||
        rawPreferences is! List ||
        rawPreferences.length > 5 ||
        rawPreferences.any((item) => item is! String)) {
      return ToolResult<String>.response(_toolJson(
        status: 'error',
        summary:
            'Workspace not created: supply up to 12 note objects and a preference list.',
      ));
    }
    final noteInputs = <Map<String, dynamic>>[];
    final seenNotes = <String>{};
    for (final value in rawNotes.cast<Map>()) {
      final item = value.cast<String, dynamic>();
      final key =
          '${_textField(item, 'title')?.toLowerCase()}\n${_textField(item, 'content')?.trim()}';
      if (seenNotes.add(key)) noteInputs.add(item);
    }
    if (noteInputs.any((item) =>
        _textField(item, 'title') == null ||
        _textField(item, 'content') == null ||
        _textField(item, 'title')!.length > 120 ||
        _textField(item, 'content')!.length > 12000)) {
      return ToolResult<String>.response(_toolJson(
        status: 'error',
        summary:
            'Workspace not created: each note needs a title up to 120 characters and content up to 12000 characters.',
      ));
    }
    if ((title != null && title.length > 120) || noteInputs.isEmpty) {
      return ToolResult<String>.response(_toolJson(
        status: 'error',
        summary:
            'Workspace not created: provide either note content or a canvas with at least one note, and keep the title within 120 characters.',
      ));
    }
    try {
      final createdNotes = <WorkspaceNote>[];
      for (final item in noteInputs) {
        createdNotes.add(await notes.save(
          title: _textField(item, 'title')!,
          content: _textField(item, 'content')!,
        ));
      }
      final canvas = title == null
          ? null
          : await canvases.create(
              title: title,
              description: description,
              noteIds: createdNotes.map((note) => note.id).toList(),
              existingNoteIds: notes.list().map((note) => note.id).toSet(),
            );
      final savedPreferences = <String>[];
      for (final preference in rawPreferences.cast<String>()) {
        try {
          if (applicationSettings.settings.flag('rememberPreferences') &&
              await userProfile.remember(preference)) {
            savedPreferences.add(preference);
          }
        } on FormatException {
          // Invalid or excess preferences do not discard the requested notes/canvas.
        }
      }
      return ToolResult<String>.response(_toolJson(
        status: 'success',
        summary: canvas == null
            ? 'Created ${createdNotes.length} note${createdNotes.length == 1 ? '' : 's'}.'
            : 'Created canvas "${canvas.title}" with ${createdNotes.length} note cards.',
        artifacts: [
          if (canvas != null)
            {'type': 'canvas', 'id': canvas.id, 'title': canvas.title},
          ...createdNotes.map(
              (note) => {'type': 'note', 'id': note.id, 'title': note.title}),
        ],
        preferences: savedPreferences,
      ));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

final readProfileTool = ai.defineTool<Map<String, dynamic>, String>(
  name: 'readUserPreferences',
  description: 'Read preferences the user explicitly asked Lumi to remember.',
  inputSchema: _objectInput({
    'reason': {'type': 'string'}
  }, [
    'reason'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (_, __) async => ToolResult<String>.response(_toolJson(
    status: 'success',
    summary: !applicationSettings.settings.flag('rememberPreferences') ||
            userProfile.preferences.isEmpty
        ? 'Remembered preferences are empty or disabled.'
        : 'Saved user preferences.',
    preferences: applicationSettings.settings.flag('rememberPreferences')
        ? userProfile.preferences
        : const [],
  )),
);

final readLearningContextTool = ai.defineTool<Map<String, String>, String>(
  name: 'readStudentLearningRecord',
  description:
      'Read shared learning evidence and due reviews for a topic. Use before planning a lesson, assessment, or progress review.',
  inputSchema: _stringInput('topic'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final topic = input['topic'] ?? '';
    final events = learningRecord.forTopic(topic);
    final due = learningRecord
        .dueReviews()
        .where((event) =>
            topic.trim().isEmpty ||
            (event['topic'] as String)
                .toLowerCase()
                .contains(topic.trim().toLowerCase()))
        .toList();
    return ToolResult<String>.response(_toolJson(
      status: 'success',
      summary: 'Shared learning evidence and due reviews.',
      extra: {
        'events': events.take(80).toList(),
        'patterns': learningRecord.patterns(topic: topic),
        'dueReviews': due,
      },
    ));
  },
);

final createAssessmentArtifactTool =
    ai.defineTool<Map<String, dynamic>, String>(
  name: 'saveLearningArtifact',
  description:
      'Save a finished quiz, test paper, revision exam, revision plan, or lesson in the student library. Assessment content must not include an answer key.',
  inputSchema: _objectInput({
    'kind': {
      'type': 'string',
      'enum': [
        'Quizzes',
        'Test papers',
        'Revision exams',
        'Revision plans',
        'Lessons'
      ]
    },
    'title': {'type': 'string'},
    'content': {
      'type': 'string',
      'description':
          'Complete student-facing artifact in Markdown. Do not include answers or marking key.'
    },
  }, [
    'kind',
    'title',
    'content'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    try {
      final kind = input['kind']?.toString() ?? '';
      final title = input['title']?.toString() ?? '';
      final content = input['content']?.toString() ?? '';
      _validateStudentArtifact(kind, content);
      final artifact = await academicArtifacts.create(
        kind: kind,
        title: title,
        content: content,
        source: kind == 'Quizzes' ||
                kind == 'Test papers' ||
                kind == 'Revision exams'
            ? 'Lumi Tester'
            : 'Lumi Teacher',
      );
      return ToolResult<String>.response(_toolJson(
        status: 'success',
        summary: 'Saved "${artifact['title']}" to the learning library.',
        artifacts: [
          {
            'id': artifact['id'] as String,
            'type': artifact['kind'] as String,
            'title': artifact['title'] as String,
          }
        ],
      ));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

void _validateStudentArtifact(String kind, String content) {
  final normalized = content.toLowerCase();
  if (RegExp(r'\b(answer key|marking key|correct answers?)\b')
      .hasMatch(normalized)) {
    throw const FormatException(
        'Student-facing learning material must not include an answer or marking key.');
  }
  if (kind != 'Test papers') return;
  final missing = <String>[];
  if (!RegExp(r'\bduration\b|\btime allowed\b|\btime:\b')
      .hasMatch(normalized)) {
    missing.add('an explicit duration');
  }
  if (!RegExp(r'\btotal marks?\b').hasMatch(normalized)) {
    missing.add('total marks');
  }
  if (!RegExp(r'\bquestion\s*\d+\b|^\s*\d+[\).:]', multiLine: true)
      .hasMatch(normalized)) {
    missing.add('numbered questions');
  }
  if (!RegExp(r'\b\d+\s*marks?\b').hasMatch(normalized)) {
    missing.add('marks per question');
  }
  if (!RegExp(r'\bsubmit\b.{0,100}\banswer|\banswer.{0,100}\bsubmit',
          dotAll: true)
      .hasMatch(normalized)) {
    missing.add('an answer-submission format');
  }
  if (missing.isNotEmpty) {
    throw FormatException(
        'A mock test paper needs ${missing.join(', ')} before it can be saved.');
  }
}

final createLearningObjectTool = ai.defineTool<Map<String, dynamic>, String>(
  name: 'createLearningObject',
  description:
      'Create and save a reusable interactive quiz or flashcard deck in Artifacts for later review. Use real structured questions or front/back cards, not Markdown alone.',
  inputSchema: _objectInput({
    'kind': {
      'type': 'string',
      'enum': ['Quizzes', 'Flashcards']
    },
    'title': {'type': 'string', 'minLength': 1, 'maxLength': 160},
    'questions': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 20,
      'items': {
        'type': 'object',
        'properties': {
          'prompt': {'type': 'string'},
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
            'minItems': 4,
            'maxItems': 4
          },
          'answerIndex': {'type': 'integer', 'minimum': 0, 'maximum': 3},
          'explanation': {'type': 'string'},
        },
        'required': ['prompt', 'options', 'answerIndex', 'explanation'],
        'additionalProperties': false,
      },
    },
    'cards': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 100,
      'items': {
        'type': 'object',
        'properties': {
          'front': {'type': 'string', 'minLength': 1, 'maxLength': 2000},
          'back': {'type': 'string', 'minLength': 1, 'maxLength': 4000},
        },
        'required': ['front', 'back'],
        'additionalProperties': false,
      },
    },
  }, [
    'kind',
    'title'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    try {
      final kind = input['kind'] as String? ?? '';
      final object = AcademicArtifacts.validateLearningObject(kind, {
        'type': kind == 'Quizzes' ? 'quiz' : 'flashcards',
        if (kind == 'Quizzes') 'questions': input['questions'],
        if (kind == 'Flashcards') 'cards': input['cards'],
      });
      final content = kind == 'Flashcards'
          ? (object['cards'] as List)
              .map((c) => 'Front: ${c['front']}\nBack: ${c['back']}')
              .join('\n\n')
          : (object['questions'] as List)
              .map(
                  (q) => '${q['prompt']}\n${(q['options'] as List).join('\n')}')
              .join('\n\n');
      final artifact = await academicArtifacts.create(
        kind: kind,
        title: input['title'] as String? ?? '',
        content: content,
        source: kind == 'Quizzes' ? 'Lumi Tester' : 'Lumi Teacher',
        learningObject: object,
      );
      return ToolResult<String>.response(_toolJson(
        status: 'success',
        summary:
            'Saved interactive ${artifact['title']} to Artifacts. Open it there to practice and review later.',
        artifacts: [
          {
            'id': artifact['id'] as String,
            'type': kind,
            'title': artifact['title'] as String
          }
        ],
      ));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

final createInteractiveCanvasQuizTool =
    ai.defineTool<Map<String, dynamic>, String>(
  name: 'createInteractiveCanvasQuiz',
  description:
      'Create a new, descriptively named Canvas for the requested topic and add a real interactive four-option MCQ quiz to it. Derive both titles from the Student request, ground questions in the selected study note, and never use generic titles.',
  inputSchema: _objectInput({
    'canvasTitle': {
      'type': 'string',
      'description':
          'Descriptive new Canvas name based on the requested topic and purpose.'
    },
    'canvasDescription': {'type': 'string'},
    'quizTitle': {'type': 'string'},
    'quizDescription': {'type': 'string'},
    'questions': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 20,
      'items': {
        'type': 'object',
        'properties': {
          'prompt': {'type': 'string'},
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
            'minItems': 4,
            'maxItems': 4
          },
          'answerIndex': {'type': 'integer', 'minimum': 0, 'maximum': 3},
          'explanation': {'type': 'string'},
        },
        'required': ['prompt', 'options', 'answerIndex', 'explanation'],
        'additionalProperties': false,
      },
    },
  }, [
    'canvasTitle',
    'canvasDescription',
    'quizTitle',
    'quizDescription',
    'questions'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    try {
      final questions = (input['questions'] as List)
          .map((question) => Map<String, Object?>.from(question as Map))
          .toList();
      AcademicArtifacts.validateLearningObject(
          'Quizzes', {'type': 'quiz', 'questions': questions});
      final canvas = await canvases.create(
        title: input['canvasTitle'] as String? ?? '',
        description: input['canvasDescription'] as String? ?? '',
        noteIds: const [],
        existingNoteIds: notes.list().map((note) => note.id).toSet(),
      );
      final updated = await canvases.addQuiz(
        canvas.id,
        title: input['quizTitle'] as String? ?? '',
        description: input['quizDescription'] as String? ?? '',
        questions: questions,
      );
      final quiz = updated.quizzes.last;
      final quizQuestions = (quiz['questions'] as List).cast<Map>();
      final studentCopy = [
        '# ${quiz['title']}',
        if ((quiz['description'] as String).isNotEmpty)
          quiz['description'] as String,
        for (var i = 0; i < quizQuestions.length; i++) ...[
          '\n${i + 1}. ${quizQuestions[i]['prompt']}',
          for (var option = 0; option < 4; option++)
            '${String.fromCharCode(65 + option)}. ${(quizQuestions[i]['options'] as List)[option]}',
        ],
      ].join('\n');
      await academicArtifacts.create(
        kind: 'Quizzes',
        title: quiz['title'] as String,
        content: studentCopy,
        source: 'Lumi Tester · Canvas ${canvas.title}',
        learningObject: {'type': 'quiz', 'questions': quizQuestions},
      );
      return ToolResult<String>.response(_toolJson(
        status: 'success',
        summary:
            'Created Canvas "${canvas.title}" with interactive quiz "${quiz['title']}" and saved a reusable interactive copy to Artifacts.',
        artifacts: [
          {'type': 'canvas', 'id': canvas.id, 'title': canvas.title},
          {
            'type': 'quiz',
            'id': quiz['id'] as String,
            'title': quiz['title'] as String,
          },
        ],
      ));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

final recordLearningEvidenceTool = ai.defineTool<Map<String, dynamic>, String>(
  name: 'recordStudentLearningEvidence',
  description:
      'Record observed learning evidence after a lesson, quiz, test, or review. Evidence must describe observed answers or outcomes, not assumptions.',
  inputSchema: _objectInput({
    'agent': {
      'type': 'string',
      'enum': ['teacher', 'tester', 'reviewer']
    },
    'kind': {
      'type': 'string',
      'enum': ['lesson', 'quiz', 'test', 'review']
    },
    'topic': {'type': 'string'},
    'evidence': {'type': 'string'},
    'score': {
      'type': 'string',
      'description': 'Optional fraction from 0 to 1, or empty.'
    },
    'misconception': {
      'type': 'string',
      'description': 'Observed misconception, or empty.'
    },
    'reviewDays': {
      'type': 'string',
      'description': 'Optional days until next review.'
    },
  }, [
    'agent',
    'kind',
    'topic',
    'evidence',
    'score',
    'misconception',
    'reviewDays'
  ]),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    try {
      final rawScore = input['score']?.toString().trim() ?? '';
      final score = rawScore.isEmpty ? null : double.tryParse(rawScore);
      if (rawScore.isNotEmpty && score == null) {
        throw const FormatException('Score must be numeric.');
      }
      final rawDays = input['reviewDays']?.toString().trim() ?? '';
      final days = rawDays.isEmpty ? null : int.tryParse(rawDays);
      if (rawDays.isNotEmpty && days == null) {
        throw const FormatException('Review days must be a whole number.');
      }
      final event = await learningRecord.record(
        agent: input['agent']?.toString() ?? '',
        kind: input['kind']?.toString() ?? '',
        topic: input['topic']?.toString() ?? '',
        evidence: input['evidence']?.toString() ?? '',
        score: score,
        misconception: input['misconception']?.toString(),
        reviewDays: days,
      );
      return ToolResult<String>.response(_toolJson(
          status: 'success',
          summary: 'Learning evidence saved to the shared Student record.',
          extra: {'event': event}));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

final rememberPreferenceTool = ai.defineTool<Map<String, String>, String>(
  name: 'rememberUserPreference',
  description:
      'Save one durable preference only when the user explicitly states it or asks Lumi to remember it. Never infer preferences or save sensitive traits.',
  inputSchema: _stringInput('preference'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final preference = input['preference'] ?? '';
    if (!applicationSettings.settings.flag('rememberPreferences')) {
      return ToolResult<String>.response(_toolJson(
          status: 'disabled',
          summary: 'Remembered preferences are disabled in settings.'));
    }
    try {
      final added = await userProfile.remember(preference);
      return ToolResult<String>.response(_toolJson(
        status: 'success',
        summary:
            added ? 'Saved preference.' : 'That preference is already saved.',
        preferences: userProfile.preferences,
      ));
    } on FormatException catch (error) {
      return ToolResult<String>.response(
          _toolJson(status: 'error', summary: error.message));
    }
  },
);

final forgetPreferenceTool = ai.defineTool<Map<String, String>, String>(
  name: 'forgetUserPreference',
  description:
      'Remove one exact saved preference when the user asks Lumi to forget it.',
  inputSchema: _stringInput('preference'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final preference = input['preference'] ?? '';
    final removed = await userProfile.forget(preference);
    return ToolResult<String>.response(_toolJson(
      status: 'success',
      summary:
          removed ? 'Removed preference.' : 'No matching preference was saved.',
      preferences: userProfile.preferences,
    ));
  },
);

final studyAgent = ai.defineAgent(
  name: 'teacher',
  description:
      'Teaches the Student using workspace notes and shared learning evidence.',
  system: 'You are Lumi Teacher. Use searchWorkspaceNotes and '
      'readWorkspaceNote to ground study materials in the user’s notes. '
      'Read the shared Student learning record before planning. Adapt explanations to observed evidence and save concise lesson evidence with recordStudentLearningEvidence. '
      'Use readUserPreferences when personalization matters. '
      'For a request to create or save a note, use createWorkspaceNote with a meaningful title and complete requested content; do not create a Canvas. '
      'Use createLearningWorkspace only for an explicit request to create a Canvas, with populated notes. Otherwise keep ordinary explanations in chat. '
      'For a requested lesson or revision plan artifact, save the student-facing material with saveLearningArtifact. Use retrieval practice: ask the Student to explain or recall a concept, wait for their attempt, then give feedback. For requested flashcards, always use createLearningObject with kind Flashcards and structured front/back cards. Tell the Student they can reveal and review the saved deck in Artifacts; plain chat text is insufficient. '
      'Never claim to have seen note content unless a tool returned it.',
  tools: [
    searchNotesTool,
    readNoteTool,
    readProfileTool,
    createWorkspaceNoteTool,
    createLearningWorkspaceTool,
    rememberPreferenceTool,
    forgetPreferenceTool,
    readLearningContextTool,
    recordLearningEvidenceTool,
    createAssessmentArtifactTool,
    createLearningObjectTool,
  ],
  maxTurns: 6,
  store: agentSessionStore,
);

final connectionsAgent = ai.defineAgent(
  name: 'connectionsGuide',
  description:
      'Finds relationships and explains concepts across workspace notes.',
  system: 'You are Lumi Connections Guide. Search the workspace before making '
      'claims about it. Compare evidence across notes, name the source notes, '
      'and distinguish direct evidence from your inference. Use readUserPreferences when personalization matters. You are read-only.',
  tools: [searchNotesTool, readNoteTool, readProfileTool],
  maxTurns: 6,
  store: agentSessionStore,
);

final testerAgent = ai.defineAgent(
  name: 'tester',
  description:
      'Creates quizzes and mock tests, then evaluates completed answers.',
  system:
      'You are Lumi Tester, an assessment specialist. Read the shared Student learning record and relevant notes before writing assessments. If no relevant note has usable content, ask the Student to add or choose study material; do not invent a note-based test. For a quiz requested in Artifacts or without a Canvas request, use createLearningObject with kind Quizzes and structured four-option questions, answerIndex, and explanation. It saves an interactive quiz directly in Artifacts. For a newly requested Canvas quiz, ground it in the relevant note, then use createInteractiveCanvasQuiz to create a new Canvas whose descriptive name is derived from the requested topic and purpose, and add a real visual MCQ quiz with four options and answer feedback. Generate a clear, student-friendly title from the Student request, never a generic or blank title. Do not merely write quiz questions in chat: use a structured interactive tool. The Canvas tool also saves a reusable interactive quiz in Artifacts. Tell the Student where the generated object is saved and ready to open. For a newly requested mock test, create and save a properly titled paper with instructions, duration, total marks, numbered questions, marks per question, and an answer submission format; mix MCQs with short answers when the material supports both. For a newly requested revision exam, read the learning record patterns, recurring misconceptions, and due reviews; create and save a cumulative paper focused on studied topics, giving extra practice to weak or overdue areas. Never put correct answers or a marking key in student-facing Markdown or chat. Provide keys only in structured quiz tool fields so the backend can grade submitted answers. Accept answers in chat, then mark the completed paper by concepts, required keywords, reasoning, and demonstrated understanding without requiring exact wording. Show a question-by-question rubric, award and lost marks, score, feedback, and next steps. Record only observed student answers and outcomes with recordStudentLearningEvidence, including misconception and review interval when justified. Do not create another copy of an existing paper while marking it. Do not claim to have saved an artifact unless the tool confirms it.',
  tools: [
    searchNotesTool,
    readNoteTool,
    readLearningContextTool,
    recordLearningEvidenceTool,
    createAssessmentArtifactTool,
    createLearningObjectTool,
    createInteractiveCanvasQuizTool,
  ],
  maxTurns: 8,
  store: agentSessionStore,
);

final reviewerAgent = ai.defineAgent(
  name: 'progressReviewer',
  description: 'Reviews learning evidence and plans spaced reviews.',
  system:
      'You are Lumi Progress Reviewer. Read the shared Student learning evidence before making claims, including deterministic topic patterns, due-review dates, score history, and recurring misconceptions. Distinguish repeated evidence from a one-off result; if there is not enough evidence, say so and offer a short baseline recall check. When a topic is due, invite the Student to answer one recall question at a time, then give feedback and record the observed review result. Recommend a practical next step and explain the evidence behind progress claims. Never invent progress or claim a review happened before the Student answers.',
  tools: [readLearningContextTool, recordLearningEvidenceTool],
  maxTurns: 6,
  store: agentSessionStore,
);

final delegateStudyTool = ai.defineTool<Map<String, String>, String>(
  name: 'delegateStudyTask',
  description:
      'Delegate a lesson, flashcard, or revision-plan request in the task field to Lumi Study Coach.',
  inputSchema: _stringInput('task'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final task = input['task'] ?? '';
    final result =
        await _withStudentRequest(() => studyAgent.chat().send(text: task));
    return ToolResult<String>.response(result.text);
  },
);

final delegateTestingTool = ai.defineTool<Map<String, String>, String>(
  name: 'delegateStudentAssessment',
  description:
      'Delegate quiz, test-paper, mock-test, or answer-marking work to Lumi Tester.',
  inputSchema: _stringInput('task'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final result = await _withStudentRequest(
        () => testerAgent.chat().send(text: input['task'] ?? ''));
    return ToolResult<String>.response(result.text);
  },
);

final delegateProgressReviewTool = ai.defineTool<Map<String, String>, String>(
  name: 'delegateStudentProgressReview',
  description:
      'Delegate progress summaries, due reviews, or learning-pattern analysis to Progress Reviewer.',
  inputSchema: _stringInput('task'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final result = await _withStudentRequest(
        () => reviewerAgent.chat().send(text: input['task'] ?? ''));
    return ToolResult<String>.response(result.text);
  },
);

final delegateConnectionsTool = ai.defineTool<Map<String, String>, String>(
  name: 'delegateConnectionAnalysis',
  description:
      'Delegate a cross-note relationship analysis request in the task field to Connections Guide.',
  inputSchema: _stringInput('task'),
  outputSchema: SchemanticType.string(),
  fn: (input, _) async {
    final task = input['task'] ?? '';
    final result = await _withStudentRequest(
        () => connectionsAgent.chat().send(text: task));
    return ToolResult<String>.response(result.text);
  },
);

final assistant = ai.defineAgent(
  name: 'assistant',
  description: 'Lumi learning coach for questions grounded in workspace notes.',
  system: 'You are Lumi, a thoughtful learning coach. Help the student learn '
      'from their workspace. Use searchWorkspaceNotes before answering questions '
      'about their notes, and readWorkspaceNote when you need full note details. '
      'Route each request to the appropriate specialist without asking the Student to choose an agent: '
      'delegate a request to learn a new topic, receive a lesson, or make flashcards to Teacher; '
      'handle a revision or recap request as Coach; '
      'delegate a test, quiz, assignment, grading, or marking request to Tester; '
      'delegate a request to diagnose learning, identify strengths or weaknesses, or analyse progress to Progress Reviewer. '
      'Delegate progress reviews and spaced review planning to delegateStudentProgressReview. '
      'Delegate comparisons across several notes to delegateConnectionAnalysis. '
      'Use readUserPreferences when tailoring help, and apply those preferences. '
      'Only remember a durable preference when the user explicitly states or asks '
      'you to remember it; never infer sensitive traits. Use forgetUserPreference '
      'when asked to forget one. When the Student asks to create, write, or save a note, use createWorkspaceNote, with a meaningful title and the complete requested explanation in content. Do not create a Canvas for a note request, even when the current view is a Canvas. '
      'Use createLearningWorkspace only when the Student explicitly requests a new Canvas. For canvas '
      'requests, include the requested notes in that call so they are attached '
      'to the canvas. Delegate interactive quizzes, MCQ quizzes, mock tests, '
      'revision exams, and answer marking to delegateStudentAssessment. '
      'Delegate lessons, flashcards, and revision plans to delegateStudyTask. '
      'For a follow-up assessment turn, include the prior paper and Student answers '
      'in the delegated task so the Tester can mark the intended questions. '
      'Do not create artifacts for ordinary Q&A. Report only '
      'artifacts tools confirm. Never '
      'claim to have accessed a note unless a tool returned it. Be concise and '
      'encourage understanding.',
  tools: [
    searchNotesTool,
    readNoteTool,
    delegateStudyTool,
    delegateConnectionsTool,
    delegateTestingTool,
    delegateProgressReviewTool,
    createWorkspaceNoteTool,
    createLearningWorkspaceTool,
    readProfileTool,
    rememberPreferenceTool,
    forgetPreferenceTool,
    readLearningContextTool,
    recordLearningEvidenceTool,
  ],
  maxTurns: 6,
  store: agentSessionStore,
);

Future<void> main() async {
  await dataDirectory.create(recursive: true);
  await WorkspaceTransaction.restoreIfNeeded(
      dataDirectory, _workspaceExportFiles);
  await workspaceSchema.prepare();
  await _reloadWorkspaceState(recoverMalformed: true);
  await localModels.load();
  localModels.startSafetyMonitor();
  await academicArtifacts
      .backfill(Directory('${dataDirectory.path}/agent-sessions/global'));
  await _archiveWorkspace();
  final genkit = GenkitRouter()
    ..addAgent(assistant, path: '/api/assistant')
    ..addAgent(studyAgent, path: '/api/agents/study')
    ..addAgent(connectionsAgent, path: '/api/agents/connections')
    ..addAgent(testerAgent, path: '/api/agents/tester')
    ..addAgent(reviewerAgent, path: '/api/agents/reviewer');
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  late final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException catch (error) {
    if (error.message.toLowerCase().contains('address already in use')) {
      stderr.writeln(
        'Lumi could not start: 127.0.0.1:$port is already in use. '
        'Check whether another Lumi backend is running before starting a second one. '
        'To use another port, set PORT and match it with '
        '--dart-define=LUMI_SERVICE_URL=http://127.0.0.1:<port> for Flutter.',
      );
    }
    rethrow;
  }
  stdout.writeln('Lumi local service listening on http://127.0.0.1:$port');
  await for (final request in server) {
    if (!originPolicy.allows(request.headers.value('origin'))) {
      await _rejectOrigin(request);
      continue;
    }
    if (await genkit.handleHttpRequest(
      request,
      basePath: '',
      cors: CorsOptions(
        allowedOrigins: originPolicy.allowedOrigins,
        allowedHeaders: const [
          'Content-Type',
          'Authorization',
          'X-Genkit-Stream-Id'
        ],
      ),
    )) {
      await _archiveWorkspace();
      continue;
    }
    final restart = await _handleApiRequest(request);
    if (restart) {
      await server.close(force: true);
      await Process.start(
        Platform.resolvedExecutable,
        [Platform.script.toFilePath()],
        workingDirectory: Directory.current.path,
        environment: Platform.environment,
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }
  }
}

Future<void> _rejectOrigin(HttpRequest request) async {
  request.response
    ..statusCode = HttpStatus.forbidden
    ..headers.contentType = ContentType.json;
  _json(request.response, HttpStatus.forbidden, {
    'error': 'Cross-origin access is not allowed for this local workspace.'
  });
  await request.response.close();
}

Future<void> _reloadWorkspaceState({bool recoverMalformed = false}) async {
  Future<void> load(String fileName, Future<void> Function() reload) {
    if (!recoverMalformed) return reload();
    return workspaceSchema.loadWithRecovery(fileName, reload);
  }

  await load('application-settings.json', applicationSettings.reload);
  await load('workspace-notes.json', notes.reload);
  await load('workspace-folders.json', folders.reload);
  await load('workspace-canvases.json', canvases.reload);
  await load('user-profile.json', userProfile.reload);
  await load('student-learning-record.json', learningRecord.reload);
  await load('academic-artifacts.json', academicArtifacts.reload);
}

Future<T> _runWorkspaceTransaction<T>(
  List<String> fileNames,
  Future<T> Function() operation, {
  bool includeAttachments = false,
}) {
  final queued = _workspaceMutationQueue.then((_) async {
    final transaction = WorkspaceTransaction(
      dataDirectory: dataDirectory,
      fileNames: fileNames,
      includeAttachments: includeAttachments,
    );
    try {
      return await transaction.run(operation);
    } catch (_) {
      await _reloadWorkspaceState();
      rethrow;
    }
  });
  _workspaceMutationQueue = queued.then<void>(
    (_) {},
    onError: (Object _, StackTrace __) {},
  );
  return queued;
}

Future<bool> _handleApiRequest(HttpRequest request) async {
  final origin = request.headers.value('origin');
  final response = request.response;
  if (!originPolicy.allows(origin)) {
    await _rejectOrigin(request);
    return false;
  }
  if (origin != null) {
    response.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..set('Vary', 'Origin');
  }
  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.noContent;
    await response.close();
    return false;
  }
  response.headers.contentType = ContentType.json;
  final segments = request.uri.pathSegments;
  var restart = false;
  try {
    await _archiveWorkspace();
    if (request.uri.path == '/api/application-settings' &&
        request.method == 'GET') {
      _json(response, HttpStatus.ok, applicationSettings.settings.values);
    } else if (request.uri.path == '/api/application-settings' &&
        request.method == 'PUT') {
      await applicationSettings.save(await _readJson(request));
      _json(response, HttpStatus.ok, applicationSettings.settings.values);
    } else if (request.uri.path == '/api/workspace/status' &&
        request.method == 'GET') {
      var bytes = 0;
      if (await dataDirectory.exists()) {
        await for (final entry
            in dataDirectory.list(recursive: true, followLinks: false)) {
          if (entry is File) bytes += await entry.length();
        }
      }
      _json(response, HttpStatus.ok, {
        'version': '0.1.0+1',
        'service': 'Online',
        'provider': providerSettings.provider,
        'model': configuredModel,
        'notes': notes.list().length,
        'folders': folders.list().length,
        'canvases': canvases.list().length,
        'artifacts': academicArtifacts.list().length,
        'storageBytes': bytes,
      });
    } else if (request.uri.path == '/api/workspace/export' &&
        request.method == 'GET') {
      // Explicit allowlist: never export provider credentials or environment values.
      final files = <String, dynamic>{};
      for (final name in [
        'workspace-notes.json',
        'workspace-folders.json',
        'workspace-canvases.json',
        'academic-artifacts.json',
        'user-profile.json',
        'student-learning-record.json',
        'application-settings.json'
      ]) {
        final file = File('${dataDirectory.path}/$name');
        if (await file.exists()) {
          files[name] = jsonDecode(await file.readAsString());
        }
      }
      final images = <String, String>{};
      if (await attachmentsDirectory.exists()) {
        await for (final entry
            in attachmentsDirectory.list(followLinks: false)) {
          if (entry is File &&
              RegExp(r'^[a-f0-9]{32}\.(png|jpg|gif|webp)$')
                  .hasMatch(entry.uri.pathSegments.last)) {
            images[entry.uri.pathSegments.last] =
                base64Encode(await entry.readAsBytes());
          }
        }
      }
      _json(response, HttpStatus.ok, {
        'format': 'lumi-workspace',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'files': files,
        'attachments': images
      });
    } else if (request.uri.path == '/api/workspace/import' &&
        request.method == 'POST') {
      _json(
          response,
          HttpStatus.ok,
          await _importWorkspace(
              await _readJson(request, maximumBytes: 300 * 1024 * 1024)));
    } else if (request.uri.path == '/api/artifacts' &&
        request.method == 'GET') {
      _json(response, HttpStatus.ok, academicArtifacts.publicList());
    } else if (segments.length == 4 &&
        segments[0] == 'api' &&
        segments[1] == 'artifacts' &&
        segments[3] == 'attempt' &&
        request.method == 'POST') {
      final body = await _readJson(request);
      _json(response, HttpStatus.ok,
          await academicArtifacts.submitQuiz(segments[2], body['answers']));
    } else if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'agent-sessions' &&
        request.method == 'DELETE') {
      final deleted = await agentSessions.delete(segments[2]);
      _json(response, HttpStatus.ok, {'deleted': deleted});
    } else if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'attachments') {
      final id = segments[2];
      final match =
          RegExp(r'^([a-f0-9]{32})\.(png|jpg|gif|webp)$').firstMatch(id);
      if (request.method == 'GET' && match != null) {
        final file = File('${attachmentsDirectory.path}/$id');
        if (!await file.exists()) {
          _json(response, HttpStatus.notFound, {'error': 'Image not found'});
        } else {
          response.headers
            ..contentType = ContentType(
                'image', match.group(2) == 'jpg' ? 'jpeg' : match.group(2)!)
            ..set('X-Content-Type-Options', 'nosniff')
            ..set(HttpHeaders.cacheControlHeader, 'private, max-age=86400');
          await response.addStream(file.openRead());
        }
      } else if (request.method == 'POST' && id == 'upload') {
        final body = await _readJson(request);
        final encoded = body['data'] as String? ?? '';
        final declaredType = body['contentType'] as String? ?? '';
        late final List<int> bytes;
        try {
          bytes = base64Decode(encoded);
        } on FormatException {
          throw const FormatException('The selected image could not be read.');
        }
        if (bytes.isEmpty || bytes.length > 700 * 1024) {
          throw const FormatException('Choose an image smaller than 700 KB.');
        }
        final type = _sniffImageType(bytes);
        if (type == null || type.$1 != declaredType) {
          throw const FormatException(
              'Choose a PNG, JPEG, GIF, or WebP image.');
        }
        final geometry = _imageGeometry(bytes, type.$2);
        if (geometry == null ||
            geometry.$1 <= 0 ||
            geometry.$2 <= 0 ||
            geometry.$1 > 8192 ||
            geometry.$2 > 8192 ||
            geometry.$1 > (16 * 1024 * 1024) ~/ geometry.$2 ||
            geometry.$3 != 1) {
          throw const FormatException(
              'Choose a static image no larger than 8192 pixels per side or 16 megapixels.');
        }
        final currentAttachmentBytes = await _collectUnusedAttachments();
        if (currentAttachmentBytes + bytes.length > 200 * 1024 * 1024) {
          throw const FormatException(
              'Local image storage is full. Remove unused images before adding more.');
        }
        final random = math.Random.secure();
        final attachmentId =
            '${List<int>.generate(16, (_) => random.nextInt(256)).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}.${type.$2}';
        await attachmentsDirectory.create(recursive: true);
        await File('${attachmentsDirectory.path}/$attachmentId')
            .writeAsBytes(bytes, flush: true);
        _json(response, HttpStatus.created,
            {'id': attachmentId, 'contentType': type.$1});
      } else if (match == null) {
        _json(response, HttpStatus.notFound, {'error': 'Image not found'});
      } else {
        _json(response, HttpStatus.methodNotAllowed,
            {'error': 'Method not allowed'});
      }
    } else if (request.method == 'GET' && request.uri.path == '/api/settings') {
      _json(response, HttpStatus.ok, {
        ...providerSettings.toPublicJson(),
        'restartRequired': false,
      });
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/settings/models') {
      final body = await _readJson(request);
      final provider = body['provider'] as String? ?? '';
      if (!const {'openai', 'anthropic', 'gemini', 'compatible'}
          .contains(provider)) {
        throw const FormatException('Choose an API provider to list models.');
      }
      final apiKey = (body['apiKey'] as String? ?? '').trim().isNotEmpty
          ? (body['apiKey'] as String).trim()
          : provider == providerSettings.provider
              ? providerSettings.apiKey
              : ProviderSettings.keyForProvider(Platform.environment, provider);
      if (apiKey.isEmpty) {
        throw const FormatException(
            'Enter an API key to list available models.');
      }
      final baseUrl = (body['baseUrl'] as String? ?? '').trim();
      final uri = Uri.tryParse(baseUrl);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException('Enter a valid model API URL.');
      }
      final rootUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
      final endpoint = Uri.parse('$rootUrl/models');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final outgoing = await client.getUrl(endpoint);
        outgoing.followRedirects = false;
        if (provider == 'anthropic') {
          outgoing.headers
            ..set('x-api-key', apiKey)
            ..set('anthropic-version', '2023-06-01');
        } else if (provider == 'gemini') {
          outgoing.headers.set('x-goog-api-key', apiKey);
        } else {
          outgoing.headers
              .set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
        }
        final upstream = await outgoing.close().timeout(
              const Duration(seconds: 20),
            );
        final responseBody = await utf8.decoder.bind(upstream).join();
        if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
          _json(response, HttpStatus.badGateway, {
            'error':
                'The provider returned HTTP ${upstream.statusCode} while listing models.'
          });
        } else {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          final rawModels = provider == 'gemini'
              ? (decoded['models'] as List<dynamic>? ?? const [])
              : (decoded['data'] as List<dynamic>? ?? const []);
          final models = rawModels
              .whereType<Map>()
              .where((item) {
                if (provider != 'gemini') return item['id'] is String;
                final methods = item['supportedGenerationMethods'];
                return item['name'] is String &&
                    (methods is! List || methods.contains('generateContent'));
              })
              .map((item) {
                final name = (provider == 'gemini' ? item['name'] : item['id'])
                    as String;
                return name.startsWith('models/') ? name.substring(7) : name;
              })
              .toSet()
              .toList()
            ..sort();
          _json(response, HttpStatus.ok, {'models': models});
        }
      } finally {
        client.close(force: true);
      }
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/settings/test') {
      final body = await _readJson(request);
      final provider = body['provider'] as String? ?? '';
      final apiKey = provider == 'ollama'
          ? 'ollama'
          : (body['apiKey'] as String? ?? '').trim().isNotEmpty
              ? (body['apiKey'] as String).trim()
              : provider == providerSettings.provider
                  ? providerSettings.apiKey
                  : ProviderSettings.keyForProvider(
                      Platform.environment, provider);
      final model = (body['model'] as String? ?? '').trim();
      final baseUrl = (body['baseUrl'] as String? ?? '').trim();
      if (provider != 'ollama' && apiKey.isEmpty) {
        throw const FormatException('Enter an API key before testing.');
      }
      if (!const {'ollama', 'openai', 'anthropic', 'gemini', 'compatible'}
          .contains(provider)) {
        throw const FormatException('Choose a supported model provider.');
      }
      if (model.isEmpty || model.length > 160) {
        throw const FormatException('Enter a valid model name before testing.');
      }
      final uri = Uri.tryParse(baseUrl);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException(
            'Enter a valid model API URL before testing.');
      }
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final rootUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
        final endpoint = switch (provider) {
          'anthropic' => Uri.parse('$rootUrl/messages'),
          'gemini' => Uri.parse(
              '$rootUrl/models/${Uri.encodeComponent(model)}:generateContent'),
          _ => Uri.parse('$rootUrl/chat/completions'),
        };
        final outgoing = await client.postUrl(endpoint);
        outgoing.followRedirects = false;
        outgoing.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        if (provider == 'anthropic') {
          outgoing.headers
            ..set('x-api-key', apiKey)
            ..set('anthropic-version', '2023-06-01');
        } else if (provider == 'gemini') {
          outgoing.headers.set('x-goog-api-key', apiKey);
        } else {
          outgoing.headers
              .set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
        }
        final payload = switch (provider) {
          'anthropic' => {
              'model': model,
              'max_tokens': 8,
              'messages': [
                {'role': 'user', 'content': 'Reply with OK.'}
              ],
            },
          'gemini' => {
              'contents': [
                {
                  'parts': [
                    {'text': 'Reply with OK.'}
                  ]
                }
              ],
              'generationConfig': {'maxOutputTokens': 8},
            },
          _ => {
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'Reply with OK.'}
              ],
            },
        };
        final testPayload = utf8.encode(jsonEncode(payload));
        outgoing.contentLength = testPayload.length;
        outgoing.add(testPayload);
        final upstream = await outgoing.close().timeout(
              const Duration(seconds: 35),
            );
        await upstream.drain<void>().timeout(const Duration(seconds: 10));
        if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
          _json(response, HttpStatus.badGateway, {
            'connected': false,
            'message': 'The provider returned HTTP ${upstream.statusCode}.',
          });
        } else {
          _json(response, HttpStatus.ok, {
            'connected': true,
            'message': 'Connection and model access verified.',
          });
        }
      } on Object {
        _json(response, HttpStatus.badGateway, {
          'connected': false,
          'message': 'Could not reach the provider. Check the URL and network.',
        });
      } finally {
        client.close(force: true);
      }
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/settings') {
      final body = await _readJson(request);
      final provider = body['provider'] as String? ?? '';
      final existingKey = provider == providerSettings.provider
          ? providerSettings.apiKey
          : ProviderSettings.keyForProvider(Platform.environment, provider);
      await ProviderSettings.save(
        file: providerSettingsFile,
        provider: provider,
        model: body['model'] as String? ?? '',
        baseUrl: body['baseUrl'] as String? ?? '',
        apiKey: body['apiKey'] as String? ?? '',
        existingApiKey: existingKey,
      );
      _json(response, HttpStatus.ok, {
        'saved': true,
        'restartRequired': false,
        'reconnecting': true,
        'apiKeyConfigured': provider != 'ollama' &&
            ((body['apiKey'] as String? ?? '').isNotEmpty ||
                existingKey.isNotEmpty),
      });
      restart = true;
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/agent-capability-test') {
      await _readJson(request);
      _json(response, HttpStatus.ok, await _runAgentCapabilityTest());
    } else if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'local-models') {
      final action = segments[2];
      if (request.method == 'POST' && action == 'agent-capability-test') {
        // Kept for existing local-model clients. Agent capability is provider
        // agnostic and is also exposed at /api/agent-capability-test.
        await _readJson(request);
        _json(response, HttpStatus.ok, await _runAgentCapabilityTest());
      } else if (request.method == 'GET' && action == 'hardware') {
        _json(response, HttpStatus.ok, await localModels.inventory());
      } else if (request.method == 'GET' && action == 'job') {
        _json(response, HttpStatus.ok, {'job': localModels.job});
      } else if (request.method == 'GET' && action == 'status') {
        _json(response, HttpStatus.ok, await localModels.status());
      } else if (request.method == 'POST' && action == 'clear') {
        await localModels.clearInterruptedJob();
        _json(response, HttpStatus.ok, {'cleared': true});
      } else if (request.method == 'POST' && action == 'catalog') {
        _json(response, HttpStatus.ok,
            await localModels.catalog(await _readJson(request)));
      } else if (request.method == 'POST' && action == 'inspect') {
        _json(response, HttpStatus.ok,
            await localModels.inspect((await _readJson(request))['repo']));
      } else if (request.method == 'POST' && action == 'pick-folder') {
        _json(
            response,
            HttpStatus.ok,
            await localModels
                .pickModelDirectory((await _readJson(request))['initialPath']));
      } else if (request.method == 'POST' && action == 'check') {
        _json(response, HttpStatus.ok,
            await localModels.check(await _readJson(request)));
      } else if (request.method == 'POST' && action == 'download') {
        _json(response, HttpStatus.accepted,
            await localModels.start((await _readJson(request))['checkId']));
      } else if (request.method == 'POST' && action == 'cancel') {
        await localModels.cancel();
        _json(response, HttpStatus.ok, {'job': localModels.job});
      } else if (request.method == 'POST' && action == 'emergency-stop') {
        _json(response, HttpStatus.ok, await localModels.emergencyStop());
      } else if (request.method == 'POST' && action == 'activate') {
        _json(response, HttpStatus.ok, await localModels.activate());
        restart = true;
      } else {
        _json(response, HttpStatus.methodNotAllowed,
            {'error': 'Unsupported local model operation.'});
      }
    } else if (request.method == 'GET' && request.uri.path == '/api/config') {
      _json(response, HttpStatus.ok, {
        'provider': providerSettings.displayName,
        'providerId': providerSettings.provider,
        'model': configuredModel,
      });
    } else if (request.method == 'GET' && request.uri.path == '/api/canvases') {
      _json(response, HttpStatus.ok,
          canvases.list().map((canvas) => canvas.toJson()).toList());
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/canvases') {
      final body = await _readJson(request);
      final canvas = await canvases.create(
        title: body['title'] as String? ?? '',
        description: body['description'] as String? ?? '',
        noteIds: (body['noteIds'] as List<dynamic>? ?? const []).cast<String>(),
        existingNoteIds: notes.list().map((note) => note.id).toSet(),
      );
      _json(response, HttpStatus.created, canvas.toJson());
    } else if (segments.length == 6 &&
        segments[0] == 'api' &&
        segments[1] == 'canvases' &&
        segments[3] == 'quizzes' &&
        segments[5] == 'submit' &&
        request.method == 'POST') {
      final body = await _readJson(request);
      final rawAnswers = body['answers'];
      if (rawAnswers is! List || rawAnswers.any((answer) => answer is! int)) {
        throw const FormatException(
            'Quiz answers must be a list of option indexes.');
      }
      final result = canvases.gradeQuiz(
        segments[2],
        segments[4],
        rawAnswers.cast<int>(),
      );
      final score = (result['score'] as int) / (result['total'] as int);
      final missed = (result['results'] as List)
          .whereType<Map>()
          .where((answer) => answer['correct'] != true)
          .length;
      await learningRecord.record(
        agent: 'tester',
        kind: 'quiz',
        topic: result['topic'] as String,
        evidence:
            'Completed ${result['title']} in Canvas: ${result['score']}/${result['total']} correct.',
        score: score,
        misconception: missed == 0
            ? null
            : 'Missed $missed quiz question${missed == 1 ? '' : 's'}; review the explanations.',
      );
      _json(response, HttpStatus.ok, result);
    } else if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'canvases') {
      final canvasId = segments[2];
      final canvasExists = canvases.list().any((item) => item.id == canvasId);
      if (!canvasExists) {
        _json(response, HttpStatus.notFound, {'error': 'Canvas not found'});
      } else if (request.method == 'PUT') {
        final body = await _readJson(request);
        final rawTitle = body['title'];
        final rawDescription = body['description'];
        if (rawTitle != null && rawTitle is! String ||
            rawDescription != null && rawDescription is! String) {
          throw const FormatException('Invalid canvas details.');
        }
        final rawNoteIds = body['noteIds'];
        if (rawNoteIds != null &&
            (rawNoteIds is! List || rawNoteIds.any((id) => id is! String))) {
          throw const FormatException(
              'Canvas note IDs must be a list of strings.');
        }
        final rawPositions = body['positions'];
        if (rawPositions != null && rawPositions is! Map) {
          throw const FormatException('Canvas positions must be an object.');
        }
        final positions = <String, CanvasPosition>{};
        for (final entry in (rawPositions as Map? ?? const {}).entries) {
          if (entry.key is! String || entry.value is! Map) {
            throw const FormatException('Invalid canvas position.');
          }
          final point = entry.value as Map;
          final x = point['x'];
          final y = point['y'];
          if (x is! num || y is! num) {
            throw const FormatException(
                'Canvas position needs numeric x and y.');
          }
          positions[entry.key as String] =
              CanvasPosition(x.toDouble(), y.toDouble());
        }
        final rawConnections = body['connections'];
        if (rawConnections != null &&
            (rawConnections is! List ||
                rawConnections.length > 300 ||
                rawConnections.any((edge) =>
                    edge is! Map ||
                    edge['sourceId'] is! String ||
                    edge['targetId'] is! String))) {
          throw const FormatException(
              'Canvas connections must be a list of note pairs.');
        }
        final connections = (rawConnections as List? ?? const [])
            .map((edge) => CanvasConnection(
                sourceId: edge['sourceId'] as String,
                targetId: edge['targetId'] as String))
            .toList();
        final canvas = await canvases.update(
          canvasId,
          title: rawTitle as String?,
          description: rawDescription as String?,
          noteIds: (rawNoteIds as List?)?.cast<String>(),
          positions: rawPositions == null ? null : positions,
          connections: rawConnections == null ? null : connections,
          existingNoteIds: notes.list().map((note) => note.id).toSet(),
        );
        _json(response, HttpStatus.ok, canvas.toJson());
      } else {
        _json(response, HttpStatus.methodNotAllowed,
            {'error': 'Method not allowed'});
      }
    } else if (request.method == 'GET' && request.uri.path == '/api/profile') {
      _json(response, HttpStatus.ok, {'preferences': userProfile.preferences});
    } else if (request.method == 'GET' &&
        request.uri.path == '/api/learning-record') {
      _json(response, HttpStatus.ok, {
        'events': learningRecord.events,
        'patterns': learningRecord.patterns(),
        'dueReviews': learningRecord.dueReviews(),
      });
    } else if (request.method == 'DELETE' &&
        request.uri.path == '/api/learning-record') {
      await learningRecord.clear();
      _json(response, HttpStatus.ok,
          {'events': [], 'patterns': [], 'dueReviews': []});
    } else if (request.method == 'DELETE' &&
        request.uri.path == '/api/profile') {
      await userProfile.clear();
      _json(response, HttpStatus.ok, {'preferences': userProfile.preferences});
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/profile/preferences') {
      final body = await _readJson(request);
      await userProfile.remember(body['preference'] as String? ?? '');
      _json(response, HttpStatus.ok, {'preferences': userProfile.preferences});
    } else if (request.method == 'DELETE' &&
        request.uri.path == '/api/profile/preferences') {
      final body = await _readJson(request);
      await userProfile.forget(body['preference'] as String? ?? '');
      _json(response, HttpStatus.ok, {'preferences': userProfile.preferences});
    } else if (request.method == 'GET' && request.uri.path == '/api/notes') {
      _json(response, HttpStatus.ok,
          notes.list().map((note) => note.toJson()).toList());
    } else if (request.method == 'GET' && request.uri.path == '/api/graph') {
      _json(response, HttpStatus.ok, {
        'nodes': notes.list().map((note) => note.toJson()).toList(),
        'edges': notes.links(),
      });
    } else if (request.method == 'GET' && request.uri.path == '/api/folders') {
      _json(response, HttpStatus.ok,
          folders.list().map((folder) => folder.toJson()).toList());
    } else if (request.method == 'POST' && request.uri.path == '/api/folders') {
      final body = await _readJson(request);
      final folder = await folders.save(
        name: body['name'] as String? ?? '',
        parentId: body['parentId'] as String?,
      );
      _json(response, HttpStatus.created, folder.toJson());
    } else if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'folders') {
      final id = segments[2];
      if (request.method == 'PUT') {
        if (folders.get(id) == null) {
          _json(response, HttpStatus.notFound, {'error': 'Folder not found'});
        } else {
          final body = await _readJson(request);
          final folder = await folders.save(
            id: id,
            name: body['name'] as String? ?? '',
            parentId: body['parentId'] as String?,
          );
          _json(response, HttpStatus.ok, folder.toJson());
        }
      } else if (request.method == 'DELETE') {
        final deleted = await _runWorkspaceTransaction(
          ['workspace-folders.json', 'workspace-notes.json'],
          () async {
            final removed = await folders.delete(id);
            if (removed) {
              for (final note
                  in notes.list().where((item) => item.folderId == id)) {
                await notes.save(
                  id: note.id,
                  title: note.title,
                  content: note.content,
                  clearFolder: true,
                );
              }
            }
            return removed;
          },
        );
        _json(response, HttpStatus.ok, {'deleted': deleted});
      } else {
        _json(response, HttpStatus.methodNotAllowed,
            {'error': 'Method not allowed'});
      }
    } else if (request.method == 'POST' && request.uri.path == '/api/notes') {
      final body = await _readJson(request);
      final folderId = body['folderId'] as String?;
      if (folderId != null && folders.get(folderId) == null) {
        throw const FormatException('Folder not found');
      }
      final note = await notes.save(
        title: body['title'] as String? ?? '',
        content: body['content'] as String? ?? '',
        folderId: folderId,
      );
      await _tryCollectUnusedAttachments();
      _json(response, HttpStatus.created, note.toJson());
    } else if (request.method == 'GET' && request.uri.path == '/api/search') {
      _json(
        response,
        HttpStatus.ok,
        notes
            .search(request.uri.queryParameters['q'] ?? '')
            .map((note) => note.toJson())
            .toList(),
      );
    } else if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'notes') {
      final id = segments[2];
      if (request.method == 'GET') {
        final note = notes.get(id);
        if (note == null) {
          _json(response, HttpStatus.notFound, {'error': 'Note not found'});
        } else {
          _json(response, HttpStatus.ok, note.toJson());
        }
      } else if (request.method == 'PUT') {
        if (notes.get(id) == null) {
          _json(response, HttpStatus.notFound, {'error': 'Note not found'});
        } else {
          final body = await _readJson(request);
          final folderId = body['folderId'] as String?;
          if (folderId != null && folders.get(folderId) == null) {
            throw const FormatException('Folder not found');
          }
          final note = await notes.save(
            id: id,
            title: body['title'] as String? ?? '',
            content: body['content'] as String? ?? '',
            folderId: folderId,
            clearFolder: body.containsKey('folderId'),
          );
          await _tryCollectUnusedAttachments();
          _json(response, HttpStatus.ok, note.toJson());
        }
      } else if (request.method == 'DELETE') {
        final deleted = await _runWorkspaceTransaction(
          ['workspace-notes.json', 'workspace-canvases.json'],
          () async {
            final removed = await notes.delete(id);
            if (removed) await canvases.detachNote(id);
            return removed;
          },
        );
        if (deleted) await _tryCollectUnusedAttachments();
        _json(response, HttpStatus.ok, {'deleted': deleted});
      } else {
        _json(response, HttpStatus.methodNotAllowed,
            {'error': 'Method not allowed'});
      }
    } else {
      _json(response, HttpStatus.notFound, {'error': 'Not found'});
    }
  } on FormatException catch (error) {
    _json(response, HttpStatus.badRequest, {
      'error': error.message.isEmpty ? 'Invalid request body' : error.message
    });
  } on Object catch (error) {
    stderr.writeln('Local API error: $error');
    _json(response, HttpStatus.internalServerError,
        {'error': 'Local request failed'});
  }
  await _archiveWorkspace();
  await response.close();
  return restart;
}

Future<Map<String, dynamic>> _runAgentCapabilityTest() async {
  try {
    final random = math.Random.secure();
    final marker = 'lumi-agent-check-${List<int>.generate(
      8,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final executionsBefore = _agentCapabilityToolExecutions;
    final turn = agentCapabilityProbe.chat().sendStream(
        text: 'Run the mandatory Lumi agent capability check. Use marker: '
            '$marker');
    await turn.stream.timeout(const Duration(seconds: 90)).drain<void>();
    final response = await turn.response.timeout(const Duration(seconds: 90));
    // Check the actual callback rather than model text: a model could imitate
    // a fixed success string without invoking a tool.
    final toolExecuted = _agentCapabilityToolExecutions > executionsBefore;
    return {
      'passed': toolExecuted,
      'provider': providerSettings.displayName,
      'model': configuredModel,
      'toolCall': toolExecuted,
      'message': toolExecuted
          ? 'Lumi completed a Genkit agent turn and executed its test tool.'
          : 'The model responded without executing the required tool call. Check tool-call support and context capacity for this model.',
      if (!toolExecuted && response.text.trim().isNotEmpty)
        'response': response.text
            .trim()
            .substring(0, math.min(240, response.text.trim().length)),
    };
  } on Object catch (error) {
    final details = error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(configuredApiKey, '[redacted]');
    return {
      'passed': false,
      'provider': providerSettings.displayName,
      'model': configuredModel,
      'toolCall': false,
      'message': details.length > 600 ? details.substring(0, 600) : details,
    };
  }
}

Future<Map<String, dynamic>> _readJson(HttpRequest request,
    {int maximumBytes = 1024 * 1024}) async {
  if (request.contentLength > maximumBytes) {
    throw const FormatException('Request too large');
  }
  final chunks = <int>[];
  await for (final chunk in request) {
    chunks.addAll(chunk);
    if (chunks.length > maximumBytes) {
      throw const FormatException('Request too large');
    }
  }
  final decoded = jsonDecode(utf8.decode(chunks));
  if (decoded is! Map) {
    throw const FormatException('Request body must be a JSON object.');
  }
  try {
    return Map<String, dynamic>.from(decoded);
  } on TypeError {
    throw const FormatException('Request body must use string keys.');
  }
}

const _workspaceExportFiles = [
  'workspace-notes.json',
  'workspace-folders.json',
  'workspace-canvases.json',
  'academic-artifacts.json',
  'user-profile.json',
  'student-learning-record.json',
  'application-settings.json',
];

Map<String, dynamic> _workspaceObject(Object? value, String message) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException(message);
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _workspaceList(Object? value, String message) {
  if (value is! List) throw FormatException(message);
  return value;
}

void _validateWorkspaceExportFile(String name, Object? value) {
  try {
    switch (name) {
      case 'workspace-notes.json':
        for (final row in _workspaceList(value, 'Notes must be a JSON list.')) {
          WorkspaceNote.fromJson(_workspaceObject(row, 'A note is invalid.'));
        }
      case 'workspace-folders.json':
        for (final row
            in _workspaceList(value, 'Folders must be a JSON list.')) {
          WorkspaceFolder.fromJson(
              _workspaceObject(row, 'A folder is invalid.'));
        }
      case 'workspace-canvases.json':
        for (final row
            in _workspaceList(value, 'Canvases must be a JSON list.')) {
          WorkspaceCanvas.fromJson(
              _workspaceObject(row, 'A canvas is invalid.'));
        }
      case 'academic-artifacts.json':
        for (final row
            in _workspaceList(value, 'Artifacts must be a JSON list.')) {
          final artifact = _workspaceObject(row, 'An artifact is invalid.');
          if (artifact['id'] is! String ||
              artifact['kind'] is! String ||
              artifact['title'] is! String ||
              artifact['content'] is! String ||
              artifact['source'] is! String ||
              artifact['sourceId'] is! String ||
              artifact['updatedAt'] is! String) {
            throw const FormatException('An artifact is invalid.');
          }
        }
      case 'user-profile.json':
        final profile = _workspaceObject(value, 'Profile data is invalid.');
        final preferences =
            _workspaceList(profile['preferences'], 'Profile data is invalid.');
        if (preferences.length > UserProfile.maxPreferences ||
            preferences.any((item) =>
                item is! String ||
                item.length > UserProfile.maxPreferenceLength)) {
          throw const FormatException('Profile data is invalid.');
        }
      case 'student-learning-record.json':
        for (final row
            in _workspaceList(value, 'Learning records must be a JSON list.')) {
          _workspaceObject(row, 'A learning record is invalid.');
        }
      case 'application-settings.json':
        AppSettings(
            _workspaceObject(value, 'Application settings are invalid.'));
    }
  } on FormatException {
    rethrow;
  } on Object {
    throw FormatException('The $name data is invalid.');
  }
}

Future<Map<String, dynamic>> _importWorkspace(
    Map<String, dynamic> export) async {
  if (export['format'] != 'lumi-workspace' || export['version'] != 1) {
    throw const FormatException('Choose a Lumi workspace export JSON file.');
  }
  final rawFiles =
      _workspaceObject(export['files'], 'Workspace files are invalid.');
  if (rawFiles.keys.any((name) => !_workspaceExportFiles.contains(name))) {
    throw const FormatException(
        'The export contains unsupported workspace files.');
  }
  final encodedFiles = <String, String>{};
  for (final entry in rawFiles.entries) {
    _validateWorkspaceExportFile(entry.key, entry.value);
    encodedFiles[entry.key] = jsonEncode(entry.value);
  }

  final rawAttachments = _workspaceObject(
      export['attachments'], 'Workspace attachments are invalid.');
  final attachments = <String, List<int>>{};
  var attachmentBytes = 0;
  for (final entry in rawAttachments.entries) {
    final match =
        RegExp(r'^([a-f0-9]{32})\.(png|jpg|gif|webp)$').firstMatch(entry.key);
    if (match == null || entry.value is! String) {
      throw const FormatException('An exported attachment is invalid.');
    }
    late final List<int> bytes;
    try {
      bytes = base64Decode(entry.value as String);
    } on FormatException {
      throw const FormatException('An exported attachment could not be read.');
    }
    final type = _sniffImageType(bytes);
    final geometry = type == null ? null : _imageGeometry(bytes, type.$2);
    if (bytes.isEmpty ||
        type == null ||
        type.$2 != match.group(2) ||
        geometry == null ||
        geometry.$1 <= 0 ||
        geometry.$2 <= 0 ||
        geometry.$1 > 8192 ||
        geometry.$2 > 8192 ||
        geometry.$1 > (16 * 1024 * 1024) ~/ geometry.$2 ||
        geometry.$3 != 1) {
      throw const FormatException('An exported attachment is invalid.');
    }
    attachmentBytes += bytes.length;
    if (attachmentBytes > 200 * 1024 * 1024) {
      throw const FormatException(
          'Workspace attachments exceed the 200 MiB limit.');
    }
    attachments[entry.key] = bytes;
  }

  final staging = Directory(
      '${dataDirectory.path}${Platform.pathSeparator}.workspace-import-${DateTime.now().microsecondsSinceEpoch}');
  try {
    await staging.create();
    for (final entry in encodedFiles.entries) {
      await File('${staging.path}${Platform.pathSeparator}${entry.key}')
          .writeAsString(entry.value, flush: true);
    }
    final stagedAttachments =
        Directory('${staging.path}${Platform.pathSeparator}attachments');
    await stagedAttachments.create();
    for (final entry in attachments.entries) {
      await File(
              '${stagedAttachments.path}${Platform.pathSeparator}${entry.key}')
          .writeAsBytes(entry.value, flush: true);
    }

    await _runWorkspaceTransaction(
      _workspaceExportFiles,
      () async {
        for (final name in _workspaceExportFiles) {
          final destination =
              File('${dataDirectory.path}${Platform.pathSeparator}$name');
          if (await destination.exists()) await destination.delete();
          if (encodedFiles.containsKey(name)) {
            await File('${staging.path}${Platform.pathSeparator}$name')
                .rename(destination.path);
          }
        }
        if (await attachmentsDirectory.exists()) {
          await attachmentsDirectory.delete(recursive: true);
        }
        await stagedAttachments.rename(attachmentsDirectory.path);
        await _reloadWorkspaceState();
      },
      includeAttachments: true,
    );
    await _archiveWorkspace();
    return {
      'imported': true,
      'notes': notes.list().length,
      'folders': folders.list().length,
      'canvases': canvases.list().length,
      'artifacts': academicArtifacts.list().length,
      'attachments': attachments.length,
    };
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

(String, String)? _sniffImageType(List<int> bytes) {
  bool startsWith(List<int> signature) =>
      bytes.length >= signature.length &&
      List<int>.generate(signature.length, (index) => bytes[index])
              .toString() ==
          signature.toString();
  if (startsWith([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return ('image/png', 'png');
  }
  if (startsWith([0xff, 0xd8, 0xff])) return ('image/jpeg', 'jpg');
  if (startsWith([0x47, 0x49, 0x46, 0x38]) &&
      (String.fromCharCodes(bytes.take(6)) == 'GIF87a' ||
          String.fromCharCodes(bytes.take(6)) == 'GIF89a')) {
    return ('image/gif', 'gif');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return ('image/webp', 'webp');
  }
  return null;
}

(int, int, int)? _imageGeometry(List<int> bytes, String extension) {
  int read16le(int offset) => bytes[offset] | (bytes[offset + 1] << 8);
  int read16be(int offset) => (bytes[offset] << 8) | bytes[offset + 1];
  int read24le(int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
  int read32be(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  if (extension == 'png' && bytes.length >= 24) {
    if (String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') return null;
    final width = read32be(16);
    final height = read32be(20);
    var frames = 1;
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final chunkLength = read32be(offset);
      if (chunkLength < 0 || chunkLength > bytes.length - offset - 12) {
        return null;
      }
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (type == 'acTL' && chunkLength >= 8) {
        frames = read32be(offset + 8);
      }
      offset += chunkLength + 12;
      if (type == 'IEND') break;
    }
    return (width, height, frames);
  }

  if (extension == 'jpg') {
    var offset = 2;
    while (offset + 4 < bytes.length) {
      while (offset < bytes.length && bytes[offset] != 0xff) {
        offset++;
      }
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return null;
      final marker = bytes[offset++];
      if (marker == 0xd9 || marker == 0xda) break;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd8)) continue;
      if (offset + 1 >= bytes.length) return null;
      final length = read16be(offset);
      if (length < 2 || offset + length > bytes.length) return null;
      if (const {
        0xc0,
        0xc1,
        0xc2,
        0xc3,
        0xc5,
        0xc6,
        0xc7,
        0xc9,
        0xca,
        0xcb,
        0xcd,
        0xce,
        0xcf
      }.contains(marker)) {
        if (length < 8) return null;
        return (read16be(offset + 5), read16be(offset + 3), 1);
      }
      offset += length;
    }
    return null;
  }

  if (extension == 'gif' && bytes.length >= 13) {
    final width = read16le(6);
    final height = read16le(8);
    var offset = 13;
    final packed = bytes[10];
    if (packed & 0x80 != 0) offset += 3 * (1 << ((packed & 0x07) + 1));
    var frames = 0;
    while (offset < bytes.length) {
      final marker = bytes[offset++];
      if (marker == 0x3b) break;
      if (marker == 0x21) {
        if (offset >= bytes.length) return null;
        offset++;
        while (offset < bytes.length) {
          final blockSize = bytes[offset++];
          if (blockSize == 0) break;
          offset += blockSize;
          if (offset > bytes.length) return null;
        }
      } else if (marker == 0x2c) {
        frames++;
        if (offset + 9 > bytes.length) return null;
        final imagePacked = bytes[offset + 8];
        offset += 9;
        if (imagePacked & 0x80 != 0) {
          offset += 3 * (1 << ((imagePacked & 0x07) + 1));
        }
        if (offset >= bytes.length) return null;
        offset++;
        while (offset < bytes.length) {
          final blockSize = bytes[offset++];
          if (blockSize == 0) break;
          offset += blockSize;
          if (offset > bytes.length) return null;
        }
      } else {
        return null;
      }
    }
    return (width, height, frames);
  }

  if (extension == 'webp' && bytes.length >= 20) {
    final chunk = String.fromCharCodes(bytes.sublist(12, 16));
    if (chunk == 'VP8X' && bytes.length >= 30) {
      final animated = bytes[20] & 0x02 != 0;
      return (read24le(24) + 1, read24le(27) + 1, animated ? 2 : 1);
    }
    if (chunk == 'VP8 ' &&
        bytes.length >= 30 &&
        bytes[23] == 0x9d &&
        bytes[24] == 0x01 &&
        bytes[25] == 0x2a) {
      return (
        ((bytes[27] & 0x3f) << 8) | bytes[26],
        ((bytes[29] & 0x3f) << 8) | bytes[28],
        1
      );
    }
    if (chunk == 'VP8L' && bytes.length >= 25 && bytes[20] == 0x2f) {
      final width = 1 + bytes[21] + ((bytes[22] & 0x3f) << 8);
      final height =
          1 + (bytes[22] >> 6) + (bytes[23] << 2) + ((bytes[24] & 0x0f) << 10);
      return (width, height, 1);
    }
  }
  return null;
}

Future<int> _collectUnusedAttachments() async {
  if (!await attachmentsDirectory.exists()) return 0;
  final referenced = <String>{};
  final referencePattern = RegExp(
    r'!\[[^\]]*\]\(/api/attachments/([a-f0-9]{32}\.(?:png|jpg|gif|webp))\)',
  );
  for (final note in notes.list()) {
    for (final match in referencePattern.allMatches(note.content)) {
      referenced.add(match.group(1)!);
    }
  }
  for (final artifact in academicArtifacts.list()) {
    for (final match
        in referencePattern.allMatches(artifact['content'] as String? ?? '')) {
      referenced.add(match.group(1)!);
    }
  }
  final expiry = DateTime.now().subtract(const Duration(days: 7));
  var totalBytes = 0;
  await for (final entity in attachmentsDirectory.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final stat = await entity.stat();
    if (!referenced.contains(name) && stat.modified.isBefore(expiry)) {
      await entity.delete();
    } else {
      totalBytes += stat.size;
    }
  }
  return totalBytes;
}

Future<void> _tryCollectUnusedAttachments() async {
  try {
    await _collectUnusedAttachments();
  } on Object {
    // Attachment cleanup is best effort and never blocks note persistence.
  }
}

String? _textField(Map<String, dynamic> input, String field) {
  final value = input[field];
  if (value is! String) return null;
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

String _toolJson({
  required String status,
  required String summary,
  List<Map<String, String>> artifacts = const [],
  List<String> preferences = const [],
  Map<String, Object?> extra = const {},
}) =>
    jsonEncode({
      'status': status,
      'summary': summary,
      'artifacts': artifacts,
      'preferences': preferences,
      ...extra,
    });

void _json(HttpResponse response, int status, Object? value) {
  response.statusCode = status;
  response.write(jsonEncode(value));
}

Future<void> _archiveWorkspace() => academicArtifacts.collect([
      for (final note in notes.list())
        {
          'id': 'note:${note.id}',
          'kind': 'Notes',
          'title': note.title,
          'content': note.content,
          'source': 'Workspace',
          'sourceId': note.id,
          'updatedAt': note.updatedAt.toIso8601String(),
        },
      for (final canvas in canvases.list())
        {
          'id': 'canvas:${canvas.id}',
          'kind': 'Canvases',
          'title': canvas.title,
          'content': [
            canvas.description,
            for (final id in canvas.noteIds)
              if (notes.get(id) case final note?)
                '# ${note.title}\n\n${note.content}'
          ].join('\n\n'),
          'source': 'Workspace',
          'sourceId': canvas.id,
          'updatedAt': canvas.updatedAt.toIso8601String(),
        },
      for (final event in learningRecord.events)
        {
          'id': 'review:${event['id']}',
          'kind': 'Reviews',
          'title': event['topic'],
          'content': event['evidence'],
          'source': event['agent'] ?? 'Learning record',
          'sourceId': event['id'],
          'updatedAt': event['recordedAt'],
        },
    ]);

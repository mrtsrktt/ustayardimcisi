/// AI service abstraction layer for MarangozAI.
///
/// All AI integrations go through these interfaces — this allows swapping
/// models (Gemini ↔ Claude ↔ local) without touching UI code.
///
/// Per CLAUDE.md Altın Kural 3: AI measurements must pass master approval.
/// Per Altın Kural 1: AI visuals are NEVER used for production data.

import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Data types ──────────────────────────────────────────────────────────────

class SketchResult {
  final List<WallResult> walls;
  final List<OpeningResult> openings;
  final double? ceilingMm;
  final Map<String, double> confidence; // field → 0.0-1.0

  const SketchResult({
    this.walls = const [],
    this.openings = const [],
    this.ceilingMm,
    this.confidence = const {},
  });

  factory SketchResult.fromJson(Map<String, dynamic> json) {
    return SketchResult(
      walls: (json['walls'] as List<dynamic>?)
          ?.map((w) => WallResult.fromJson(w))
          .toList() ?? [],
      openings: (json['openings'] as List<dynamic>?)
          ?.map((o) => OpeningResult.fromJson(o))
          .toList() ?? [],
      ceilingMm: (json['ceiling_mm'] as num?)?.toDouble(),
      confidence: (json['confidence'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
    );
  }

  /// Fields with confidence < threshold need manual approval (red highlight).
  List<String> get lowConfidenceFields {
    return confidence.entries
        .where((e) => e.value < 0.8)
        .map((e) => e.key)
        .toList();
  }
}

class WallResult {
  final String label;     // A, B, C...
  final double? lengthMm; // null if unreadable

  const WallResult({required this.label, this.lengthMm});

  factory WallResult.fromJson(Map<String, dynamic> json) =>
      WallResult(label: json['label'] as String,
          lengthMm: (json['length_mm'] as num?)?.toDouble());
}

class OpeningResult {
  final String type;          // window|door|column
  final String wall;          // wall label
  final double? fromLeftMm;
  final double? widthMm;
  final double? heightMm;

  const OpeningResult({
    required this.type, required this.wall,
    this.fromLeftMm, this.widthMm, this.heightMm,
  });

  factory OpeningResult.fromJson(Map<String, dynamic> json) =>
      OpeningResult(
        type: json['type'] as String,
        wall: json['wall'] as String,
        fromLeftMm: (json['from_left_mm'] as num?)?.toDouble(),
        widthMm: (json['width_mm'] as num?)?.toDouble(),
        heightMm: (json['height_mm'] as num?)?.toDouble(),
      );
}

class RevisionCommand {
  final List<RevisionAction> actions;
  final List<String> unclear;   // anlaşılmayan kısımlar

  const RevisionCommand({this.actions = const [], this.unclear = const []});

  factory RevisionCommand.fromJson(Map<String, dynamic> json) {
    return RevisionCommand(
      actions: (json['actions'] as List<dynamic>?)
          ?.map((a) => RevisionAction.fromJson(a))
          .toList() ?? [],
      unclear: (json['belirsiz'] as List<dynamic>?)
          ?.cast<String>() ?? [],
    );
  }

  bool get hasUnclear => unclear.isNotEmpty;
}

class RevisionAction {
  final String target;      // module code or position description
  final String field;       // tip|kapak_rengi|malzeme|cekmece_sayisi|cam|kulp|genislik
  final String value;

  const RevisionAction({
    required this.target, required this.field, required this.value,
  });

  factory RevisionAction.fromJson(Map<String, dynamic> json) =>
      RevisionAction(
        target: json['target'] as String,
        field: json['field'] as String,
        value: json['value'] as String,
      );
}

class RenderRequest {
  final List<String> photoPaths;          // reference photos
  final String planSummary;               // module layout description
  final String materialPrompt;            // material & color details
  final String? previousRenderPath;       // for revision consistency

  const RenderRequest({
    required this.photoPaths,
    required this.planSummary,
    required this.materialPrompt,
    this.previousRenderPath,
  });
}

// ─── Abstract Interfaces ─────────────────────────────────────────────────────

/// Image generation service — pluggable (Gemini, Stable Diffusion, etc.)
abstract class ImageGenService {
  /// Generate a photorealistic render from reference photos + plan.
  /// Returns path to saved image.
  Future<String> generateRender(RenderRequest request);

  /// Apply revision changes to previous render.
  Future<String> generateRevision({
    required String previousRenderPath,
    required List<RevisionAction> changes,
    required String planSummary,
  });

  /// Whether the service is available (has API key, network, etc.)
  Future<bool> isAvailable();
}

/// Sketch/measurement reading service.
abstract class SketchReaderService {
  /// Read measurements from a hand-drawn sketch photo.
  /// Returns structured measurements with confidence scores.
  Future<SketchResult> readSketch(String sketchPath);

  /// Whether the service is available.
  Future<bool> isAvailable();
}

/// Revision interpreter — converts voice/text commands to structured actions.
abstract class RevisionInterpreter {
  /// Parse a voice/text command into RevisionCommand.
  /// [planJson] is the current cabinet plan serialized to JSON.
  Future<RevisionCommand> interpret(String command, String planJson);

  /// Whether the service is available.
  Future<bool> isAvailable();
}

// ─── Prompt Builders (AI_RENDER_PROMPT.md templates) ─────────────────────────

class RenderPromptBuilder {
  /// Build initial render prompt per AI_RENDER_PROMPT.md §1.
  static String buildInitialPrompt({
    required double altHatUzunlukCm,
    required double ustHatUzunlukCm,
    required String modulListesi,
    required String ustModulListesi,
    required String boyModuller,
    required String kapakMalzeme,
    required String kapakRenk,
    required String govdeRenk,
    required String tezgah,
    required String kulpTipi,
    required String bazaRenk,
  }) {
    return '''
You are rendering a photorealistic kitchen cabinet installation proposal for a carpenter.

REFERENCE: Image 1 shows the customer's actual empty/old kitchen. Keep the EXACT same
camera angle, room geometry, walls, ceiling, floor, window and door positions, and
natural lighting as Image 1. Do not move or resize any architectural element.

TASK: Replace/install fitted kitchen cabinets according to this plan:
- Lower cabinet run: ${altHatUzunlukCm.toStringAsFixed(0)} cm long, counter height ~90 cm.
  Modules left to right: $modulListesi.
- Upper cabinet run: ${ustHatUzunlukCm.toStringAsFixed(0)} cm, depth ~32 cm, mounted ~55 cm above counter.
  Modules: $ustModulListesi.
- Tall units: ${boyModuller.isEmpty ? "none" : boyModuller}.

MATERIALS & COLORS:
- Door fronts: $kapakMalzeme in $kapakRenk.
- Carcass/visible sides: $govdeRenk.
- Countertop: $tezgah. Handles: $kulpTipi. Plinth: $bazaRenk, 10 cm.

CONSTRAINTS:
- Proportions must match the stated centimeter dimensions relative to the room.
- Realistic materials: correct gloss/matte reflectance, visible door gaps (~3 mm),
  edge-banded panel edges. No people, no text, no watermark logos, no brand names.
- Keep existing appliances visible only where the plan specifies gaps for them.
Output: one photorealistic image, same resolution/aspect as Image 1.
''';
  }

  /// Build revision prompt per AI_RENDER_PROMPT.md §2.
  static String buildRevisionPrompt({
    required List<String> changes,
  }) {
    final changeText = changes.map((c) => '- $c').join('\n');
    return '''
Image 1 is the previously approved kitchen render. Apply ONLY the following changes and
keep everything else pixel-consistent (camera, lighting, untouched cabinets, room):

CHANGES:
$changeText

Do not alter dimensions, module positions, countertop, or any element not listed above.
''';
  }

  /// Build sketch reading prompt per AI_RENDER_PROMPT.md §4.
  static String buildSketchPrompt() {
    return '''
Task: Extract measurements from a hand-drawn kitchen sketch photo.
Output JSON: { "walls": [{"label":"A","length_mm":0}], "openings":
[{"type":"window|door|column","wall":"A","from_left_mm":0,"width_mm":0,"height_mm":0,
"sill_mm":0}], "ceiling_mm":0, "confidence": {"<field>": 0.0-1.0} }
Rules: If a number is unreadable, set it to null and confidence<0.5. If values are
written in cm (common: 3-digit and >100), convert to mm (multiply by 10).
NEVER fabricate measurements. Reflect arrow directions and corner relationships
in wall order.
''';
  }

  /// Build command interpretation prompt per AI_RENDER_PROMPT.md §3.
  static String buildCommandPrompt(String command, String planJson) {
    return '''
Task: Convert the carpenter's spoken/written command into the following JSON schema.
Schema: { "actions": [ { "target": "<module code|position description>",
        "field": "tip|kapak_rengi|malzeme|cekmece_sayisi|cam|kulp|genislik",
        "value": "<new value>" } ], "belirsiz": ["unclear parts"] }
Rules: Resolve position descriptions to module IDs using the plan (JSON attached).
If unsure about the target, list it in "belirsiz" — NEVER guess module changes.
For dimension changes, convert value to mm. Tolerate Turkish dialect variations.

PLAN JSON:
$planJson

COMMAND: $command
''';
  }
}

// ─── Stub Implementations (replace with real API calls in production) ─────────

/// Stub image gen service — returns placeholder.
class StubImageGenService implements ImageGenService {
  @override
  Future<String> generateRender(RenderRequest request) async {
    // TODO: Integrate Gemini Flash Image API
    return 'placeholder_render.png';
  }

  @override
  Future<String> generateRevision({
    required String previousRenderPath,
    required List<RevisionAction> changes,
    required String planSummary,
  }) async {
    // TODO: Integrate Gemini image editing
    return 'placeholder_revision.png';
  }

  @override
  Future<bool> isAvailable() async => false; // stub: not available
}

/// Stub sketch reader — simulates AI reading.
class StubSketchReaderService implements SketchReaderService {
  @override
  Future<SketchResult> readSketch(String sketchPath) async {
    // TODO: Integrate Gemini Vision / Claude Vision
    return const SketchResult();
  }

  @override
  Future<bool> isAvailable() async => false;
}

/// Stub revision interpreter.
class StubRevisionInterpreter implements RevisionInterpreter {
  @override
  Future<RevisionCommand> interpret(String command, String planJson) async {
    // TODO: Integrate LLM function calling
    return const RevisionCommand();
  }

  @override
  Future<bool> isAvailable() async => false;
}

// ─── Gemini Implementation (F2) ──────────────────────────────────────────────

class GeminiImageGenService implements ImageGenService {
  final String apiKey;
  final http.Client _client;

  GeminiImageGenService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<String> generateRender(RenderRequest request) async {
    // Gemini 2.5/3.x Flash Image API endpoint
    // Uses multi-image input: reference photos + texture images
    final uri = Uri.https('generativelanguage.googleapis.com',
        '/v1beta/models/gemini-2.5-flash-image:generateContent');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [{
          'parts': [
            {'text': request.materialPrompt},
            // Images would be base64-encoded here
          ]
        }],
        'generationConfig': {
          'responseModalities': ['Text', 'Image'],
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Extract and save image from response
      // TODO: Parse Gemini response, save image, return path
      return 'render_output.png';
    } else {
      throw Exception('Gemini API error: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<String> generateRevision({
    required String previousRenderPath,
    required List<RevisionAction> changes,
    required String planSummary,
  }) async {
    final prompt = RenderPromptBuilder.buildRevisionPrompt(
      changes: changes.map((a) =>
          '${a.field} of ${a.target} → ${a.value}').toList(),
    );
    // Same API call with previous render as reference image
    return 'revision_output.png';
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final uri = Uri.https('generativelanguage.googleapis.com',
          '/v1beta/models/gemini-2.5-flash-image');
      final response = await _client.get(uri, headers: {'x-goog-api-key': apiKey});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class GeminiSketchReaderService implements SketchReaderService {
  final String apiKey;
  final http.Client _client;

  GeminiSketchReaderService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<SketchResult> readSketch(String sketchPath) async {
    final prompt = RenderPromptBuilder.buildSketchPrompt();

    // Read sketch image as base64
    final bytes = await _readFileBytes(sketchPath);
    final base64Image = base64Encode(bytes);

    final uri = Uri.https('generativelanguage.googleapis.com',
        '/v1beta/models/gemini-2.5-flash:generateContent');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [{
          'parts': [
            {'text': prompt},
            {'inlineData': {'mimeType': 'image/jpeg', 'data': base64Image}},
          ]
        }],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return SketchResult.fromJson(json);
    } else {
      throw Exception('Sketch reader error: ${response.statusCode}');
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final uri = Uri.https('generativelanguage.googleapis.com',
          '/v1beta/models/gemini-2.5-flash');
      final response = await _client.get(uri, headers: {'x-goog-api-key': apiKey});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<int>> _readFileBytes(String path) async {
    final file = await _client.get(Uri.parse('file://$path'));
    return file.bodyBytes;
  }
}

class GeminiRevisionInterpreter implements RevisionInterpreter {
  final String apiKey;
  final http.Client _client;

  GeminiRevisionInterpreter({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<RevisionCommand> interpret(String command, String planJson) async {
    final prompt = RenderPromptBuilder.buildCommandPrompt(command, planJson);

    final uri = Uri.https('generativelanguage.googleapis.com',
        '/v1beta/models/gemini-2.5-flash:generateContent');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [{
          'parts': [{'text': prompt}]
        }],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return RevisionCommand.fromJson(json);
    } else {
      throw Exception('Revision interpreter error: ${response.statusCode}');
    }
  }

  @override
  Future<bool> isAvailable() async => true;
}

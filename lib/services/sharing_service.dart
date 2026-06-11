/// WhatsApp sharing and version history service for MarangozAI.
///
/// Uses wa.me links for WhatsApp sharing (no API key needed).
/// Plan version history stored in database for revision rollback.

import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';

// ─── WhatsApp Sharing ────────────────────────────────────────────────────────

class WhatsAppService {
  /// Open WhatsApp chat with a pre-filled message.
  /// Falls back to system share sheet if WhatsApp not installed.
  static Future<void> shareToWhatsApp({
    required String phoneNumber,     // with country code, e.g. "905551234567"
    required String message,
    List<String>? filePaths,        // PDF, Excel, images
  }) async {
    // Clean phone number
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Try WhatsApp first
    final waUrl = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback: share via system
    if (filePaths != null && filePaths.isNotEmpty) {
      await Share.shareXFiles(
        filePaths.map((p) => XFile(p)).toList(),
        text: message,
      );
    } else {
      await Share.share(message);
    }
  }

  /// Generate customer approval message.
  static String buildApprovalMessage({
    required String customerName,
    required String projectSummary,
    String? renderCaption,
  }) {
    return '''
Merhaba $customerName,

Mutfak dolabı tasarımınız hazır! 🎉

$projectSummary

${renderCaption ?? 'Tasarım görseli ekte.'}

Beğendiyseniz onay verir misiniz? Değişiklik isterseniz belirtebilirsiniz.
''';
  }

  /// Generate cut list sharing message.
  static String buildCutListMessage({
    required String customerName,
    required int plateCount,
    required double wastePct,
  }) {
    return '''
$customerName - Kesim Planı ✂️

Toplam: $plateCount plaka
Fire oranı: %${wastePct.toStringAsFixed(1)}

Kesim listesi ve plaka şeması ekte.
''';
  }

  /// Generate offer/quote message.
  static String buildOfferMessage({
    required String customerName,
    required double totalPrice,
    required String tl,
  }) {
    return '''
$customerName - Teklif 📋

Toplam Fiyat: ${totalPrice.toStringAsFixed(0)} $tl

Detaylı teklif PDF'i ekte.
''';
  }
}

// ─── Version History ─────────────────────────────────────────────────────────

class VersionHistoryService {
  final AppDatabase _db;

  VersionHistoryService(this._db);

  /// Get all plan versions for a project, newest first.
  List<CabinetPlanRow> getVersions(int projectId) {
    final rows = _db.db.select(
      'SELECT * FROM cabinet_plans WHERE project_id = ? ORDER BY version DESC',
      [projectId],
    );
    return rows.map(_planFromRow).toList();
  }

  /// Create a new plan version (increments version number).
  Future<int> createVersion(int projectId, {double ceilingMm = 2700}) async {
    final current = getVersions(projectId);
    final nextVersion = current.isEmpty ? 1 : current.first.version + 1;

    final stmt = _db.db.prepare(
      'INSERT INTO cabinet_plans (project_id, version, ceiling_height_mm) VALUES (?, ?, ?)');
    stmt.execute([projectId, nextVersion, ceilingMm]);
    stmt.dispose();
    return _db.db.lastInsertRowId;
  }

  /// Save modules for a plan version.
  Future<void> saveModules(int planId, List<ModuleData> modules) async {
    // Clear existing modules for this plan
    _db.db.execute('DELETE FROM plan_modules WHERE plan_id = ?', [planId]);

    final stmt = _db.db.prepare(
      'INSERT INTO plan_modules (plan_id, code, x_pos_mm, width_mm, height_mm, depth_mm, wall_label, params_json) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)');

    for (final m in modules) {
      stmt.execute([
        planId, m.code, m.xPosMm, m.widthMm, m.heightMm, m.depthMm,
        m.wallLabel, m.paramsJson,
      ]);
    }
    stmt.dispose();
  }

  /// Get modules for a plan version.
  List<ModuleData> getModules(int planId) {
    final rows = _db.db.select(
      'SELECT * FROM plan_modules WHERE plan_id = ? ORDER BY x_pos_mm',
      [planId],
    );
    return rows.map((r) => ModuleData(
      code: r['code'] as String,
      xPosMm: (r['x_pos_mm'] as num).toDouble(),
      widthMm: (r['width_mm'] as num).toDouble(),
      heightMm: (r['height_mm'] as num).toDouble(),
      depthMm: (r['depth_mm'] as num).toDouble(),
      wallLabel: r['wall_label'] as String,
      paramsJson: r['params_json'] as String?,
    )).toList();
  }

  CabinetPlanRow _planFromRow(Map<String, Object?> row) => CabinetPlanRow(
    id: row['id'] as int,
    projectId: row['project_id'] as int,
    version: row['version'] as int,
    ceilingHeightMm: (row['ceiling_height_mm'] as num).toDouble(),
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  /// Save a render for a plan version.
  Future<void> saveRender(int projectId, int planVersion, String filePath, String? prompt) async {
    _db.db.execute(
      'INSERT INTO renders (project_id, plan_version, file_path, prompt_used) VALUES (?, ?, ?, ?)',
      [projectId, planVersion, filePath, prompt],
    );
  }

  /// Get renders for a project.
  List<RenderRow> getRenders(int projectId) {
    final rows = _db.db.select(
      'SELECT * FROM renders WHERE project_id = ? ORDER BY created_at DESC',
      [projectId],
    );
    return rows.map((r) => RenderRow(
      id: r['id'] as int,
      projectId: r['project_id'] as int,
      planVersion: r['plan_version'] as int,
      filePath: r['file_path'] as String,
      promptUsed: r['prompt_used'] as String?,
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();
  }
}

// ─── Row types ───────────────────────────────────────────────────────────────

class CabinetPlanRow {
  final int id;
  final int projectId;
  final int version;
  final double ceilingHeightMm;
  final DateTime createdAt;

  CabinetPlanRow({
    required this.id, required this.projectId, required this.version,
    required this.ceilingHeightMm, required this.createdAt,
  });
}

class ModuleData {
  final String code;
  final double xPosMm;
  final double widthMm;
  final double heightMm;
  final double depthMm;
  final String wallLabel;
  final String? paramsJson;

  ModuleData({
    required this.code, required this.xPosMm, required this.widthMm,
    required this.heightMm, required this.depthMm,
    this.wallLabel = 'A', this.paramsJson,
  });
}

class RenderRow {
  final int id;
  final int projectId;
  final int planVersion;
  final String filePath;
  final String? promptUsed;
  final DateTime createdAt;

  RenderRow({
    required this.id, required this.projectId, required this.planVersion,
    required this.filePath, this.promptUsed, required this.createdAt,
  });
}

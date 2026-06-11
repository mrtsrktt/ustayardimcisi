/// SQLite database wrapper for MarangozAI.
/// Uses raw SQL with sqlite3 — no code generation needed.

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

// ─── Row types ───────────────────────────────────────────────────────────────

class CustomerRow {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  CustomerRow({
    this.id, required this.name, this.phone, this.address, this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CustomerRow.fromMap(Map<String, Object?> map) => CustomerRow(
    id: map['id'] as int?, name: map['name'] as String,
    phone: map['phone'] as String?, address: map['address'] as String?,
    notes: map['notes'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, 'name': name,
    'phone': phone, 'address': address, 'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };
}

class ProjectRow {
  final int? id;
  final int customerId;
  final String status;   // draft|designed|approved|cut_ready|quoted
  final String? sketchPath;
  final String? measurementsJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectRow({
    this.id, required this.customerId, this.status = 'draft',
    this.sketchPath, this.measurementsJson,
    DateTime? createdAt, DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ProjectRow.fromMap(Map<String, Object?> map) => ProjectRow(
    id: map['id'] as int?, customerId: map['customer_id'] as int,
    status: map['status'] as String,
    sketchPath: map['sketch_path'] as String?,
    measurementsJson: map['measurements_json'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, 'customer_id': customerId,
    'status': status, 'sketch_path': sketchPath,
    'measurements_json': measurementsJson,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class PhotoRow {
  final int? id;
  final int projectId;
  final String filePath;
  final int sortOrder;
  final bool isReference;

  PhotoRow({
    this.id, required this.projectId, required this.filePath,
    this.sortOrder = 0, this.isReference = false,
  });

  factory PhotoRow.fromMap(Map<String, Object?> map) => PhotoRow(
    id: map['id'] as int?, projectId: map['project_id'] as int,
    filePath: map['file_path'] as String,
    sortOrder: map['sort_order'] as int? ?? 0,
    isReference: (map['is_reference'] as int?) == 1,
  );
}

class ProjectWithCustomer {
  final ProjectRow project;
  final CustomerRow? customer;
  ProjectWithCustomer({required this.project, this.customer});
}

// ─── Database ────────────────────────────────────────────────────────────────

class AppDatabase {
  late final Database _db;
  bool _initialized = false;

  AppDatabase();

  Future<void> initialize() async {
    if (_initialized) return;
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, 'marangozai.db');
    _db = sqlite3.open(path);
    _createTables();
    _insertDefaults();
    _initialized = true;
  }

  Database get db {
    if (!_initialized) throw StateError('Call initialize() first');
    return _db;
  }

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
        status TEXT NOT NULL DEFAULT 'draft',
        sketch_path TEXT,
        measurements_json TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        is_reference INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS wall_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        length_mm REAL NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS openings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        wall_label TEXT NOT NULL,
        type TEXT NOT NULL,
        from_left_mm REAL NOT NULL,
        width_mm REAL NOT NULL,
        height_mm REAL NOT NULL,
        sill_mm REAL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS cabinet_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        version INTEGER DEFAULT 1,
        ceiling_height_mm REAL DEFAULT 2700,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS plan_modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL REFERENCES cabinet_plans(id) ON DELETE CASCADE,
        code TEXT NOT NULL,
        x_pos_mm REAL NOT NULL,
        width_mm REAL NOT NULL,
        height_mm REAL NOT NULL,
        depth_mm REAL NOT NULL,
        wall_label TEXT DEFAULT 'A',
        params_json TEXT
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS material_specs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        body_material TEXT DEFAULT 'mdflam',
        body_color TEXT DEFAULT 'Beyaz',
        door_material TEXT DEFAULT 'high_gloss',
        door_color TEXT DEFAULT 'Beyaz',
        edge_band_thickness_mm REAL DEFAULT 2,
        edge_band_color TEXT,
        panel_width_mm REAL DEFAULT 2100,
        panel_length_mm REAL DEFAULT 2800,
        thickness_mm REAL DEFAULT 18
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS renders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        plan_version INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        prompt_used TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS price_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT UNIQUE NOT NULL,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        price REAL NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL
      )
    ''');
  }

  void _insertDefaults() {
    final count = _db.select('SELECT COUNT(*) FROM app_settings').first.values.first;
    if (count == 0) {
      final defaults = {
        'kerf_mm': '4.8',
        'trim_mm': '10',
        'plate_width_mm': '2100',
        'plate_length_mm': '2800',
        'arkalik_tip': 'cakma',
        'min_serit_mm': '50',
        'use_band_deduction': 'true',
        'default_body_thickness_mm': '18',
        'alt_yukseklik_mm': '740',
        'alt_derinlik_mm': '560',
        'ust_yukseklik_mm': '720',
        'ust_derinlik_mm': '320',
        'boy_yukseklik_mm': '2080',
        'baza_yukseklik_mm': '100',
      };
      final stmt = _db.prepare('INSERT INTO app_settings (key, value) VALUES (?, ?)');
      for (final e in defaults.entries) {
        stmt.execute([e.key, e.value]);
      }
      stmt.dispose();
    }
  }

  // ─── Customer CRUD ──────────────────────────────────────────────────────

  Future<int> insertCustomer(CustomerRow c) {
    final stmt = _db.prepare(
      'INSERT INTO customers (name, phone, address, notes) VALUES (?, ?, ?, ?)');
    stmt.execute([c.name, c.phone, c.address, c.notes]);
    stmt.dispose();
    return Future.value(_db.lastInsertRowId);
  }

  Future<void> updateCustomer(CustomerRow c) {
    _db.execute(
      'UPDATE customers SET name=?, phone=?, address=?, notes=? WHERE id=?',
      [c.name, c.phone, c.address, c.notes, c.id]);
    return Future.value();
  }

  Future<void> deleteCustomer(int id) {
    _db.execute('DELETE FROM customers WHERE id=?', [id]);
    return Future.value();
  }

  List<CustomerRow> getAllCustomers() {
    return _db.select('SELECT * FROM customers ORDER BY name').map(CustomerRow.fromMap).toList();
  }

  CustomerRow? getCustomer(int id) {
    final rows = _db.select('SELECT * FROM customers WHERE id=?', [id]);
    return rows.isEmpty ? null : CustomerRow.fromMap(rows.first);
  }

  // ─── Project CRUD ───────────────────────────────────────────────────────

  Future<int> insertProject(ProjectRow p) {
    final stmt = _db.prepare(
      'INSERT INTO projects (customer_id, status, sketch_path, measurements_json) VALUES (?, ?, ?, ?)');
    stmt.execute([p.customerId, p.status, p.sketchPath, p.measurementsJson]);
    stmt.dispose();
    return Future.value(_db.lastInsertRowId);
  }

  Future<void> updateProject(ProjectRow p) {
    _db.execute(
      "UPDATE projects SET customer_id=?, status=?, sketch_path=?, measurements_json=?, updated_at=datetime('now') WHERE id=?",
      [p.customerId, p.status, p.sketchPath, p.measurementsJson, p.id]);
    return Future.value();
  }

  Future<void> deleteProject(int id) {
    _db.execute('DELETE FROM projects WHERE id=?', [id]);
    return Future.value();
  }

  List<ProjectWithCustomer> getAllProjects() {
    final rows = _db.select('''
      SELECT p.*, c.name as customer_name, c.phone as customer_phone
      FROM projects p
      LEFT JOIN customers c ON p.customer_id = c.id
      ORDER BY p.updated_at DESC
    ''');
    return rows.map((row) {
      final proj = ProjectRow.fromMap({
        'id': row['id'], 'customer_id': row['customer_id'],
        'status': row['status'], 'sketch_path': row['sketch_path'],
        'measurements_json': row['measurements_json'],
        'created_at': row['created_at'], 'updated_at': row['updated_at'],
      });
      final cust = row['customer_name'] != null ? CustomerRow(
        id: row['customer_id'] as int, name: row['customer_name'] as String,
        phone: row['customer_phone'] as String?,
      ) : null;
      return ProjectWithCustomer(project: proj, customer: cust);
    }).toList();
  }

  ProjectWithCustomer? getProject(int id) {
    final rows = _db.select('''
      SELECT p.*, c.name as customer_name, c.phone as customer_phone
      FROM projects p
      LEFT JOIN customers c ON p.customer_id = c.id
      WHERE p.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final proj = ProjectRow.fromMap({
      'id': row['id'], 'customer_id': row['customer_id'],
      'status': row['status'], 'sketch_path': row['sketch_path'],
      'measurements_json': row['measurements_json'],
      'created_at': row['created_at'], 'updated_at': row['updated_at'],
    });
    final cust = row['customer_name'] != null ? CustomerRow(
      id: row['customer_id'] as int, name: row['customer_name'] as String,
      phone: row['customer_phone'] as String?,
    ) : null;
    return ProjectWithCustomer(project: proj, customer: cust);
  }

  // ─── Settings ───────────────────────────────────────────────────────────

  Future<Map<String, String>> getSettings() async {
    return getAllSettings();
  }

  Map<String, String> getAllSettings() {
    final rows = _db.select('SELECT key, value FROM app_settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<String?> getSetting(String key) async {
    final rows = _db.select('SELECT value FROM app_settings WHERE key=?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    _db.execute(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      [key, value]);
  }

  // ─── Cleanup ────────────────────────────────────────────────────────────

  void close() {
    _db.dispose();
    _initialized = false;
  }
}

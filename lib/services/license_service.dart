/// License and activation service for MarangozAI.
///
/// Device-bound license with offline tolerance (14 days).
/// Simple key validation — in production, this would use a proper
/// license server with RSA signature verification.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import '../database/database.dart';

// ─── License Status ──────────────────────────────────────────────────────────

enum LicenseStatus {
  unlicensed,    // no license key entered
  trial,         // 30-day trial
  active,        // valid license
  expired,       // license expired
  gracePeriod,   // within 14-day offline grace period
}

class LicenseInfo {
  final LicenseStatus status;
  final String? key;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final int daysRemaining;
  final String? deviceId;

  const LicenseInfo({
    this.status = LicenseStatus.unlicensed,
    this.key,
    this.activatedAt,
    this.expiresAt,
    this.daysRemaining = 0,
    this.deviceId,
  });

  bool get isActive =>
      status == LicenseStatus.active || status == LicenseStatus.trial;

  bool get canUseOffline =>
      status == LicenseStatus.active || status == LicenseStatus.gracePeriod;
}

// ─── License Service ─────────────────────────────────────────────────────────

class LicenseService {
  final AppDatabase _db;
  LicenseInfo? _cached;

  LicenseService(this._db);

  /// Check current license status.
  Future<LicenseInfo> checkStatus() async {
    if (_cached != null) return _cached!;

    try {
      final settings = await _db.getSettings();
      final key = settings['license_key'];
      final activatedStr = settings['license_activated_at'];
      final deviceId = settings['license_device_id'];
      final lastCheckStr = settings['license_last_check'];

      if (key == null || key.isEmpty) {
        return _cache(LicenseInfo(
          status: LicenseStatus.trial,
          daysRemaining: _trialDaysRemaining(settings),
        ));
      }

      final activatedAt = activatedStr != null ? DateTime.tryParse(activatedStr) : null;
      final lastCheck = lastCheckStr != null ? DateTime.tryParse(lastCheckStr) : null;
      final expiresAt = activatedAt?.add(const Duration(days: 365));

      // Check if expired
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        if (lastCheck != null &&
            DateTime.now().difference(lastCheck).inDays < 14) {
          return _cache(LicenseInfo(
            status: LicenseStatus.gracePeriod,
            key: key, activatedAt: activatedAt, expiresAt: expiresAt,
            daysRemaining: 14 - DateTime.now().difference(lastCheck).inDays,
            deviceId: deviceId,
          ));
        }
        return _cache(LicenseInfo(
          status: LicenseStatus.expired,
          key: key, activatedAt: activatedAt, expiresAt: expiresAt,
          deviceId: deviceId,
        ));
      }

      // Active license
      final daysLeft = expiresAt != null
          ? expiresAt.difference(DateTime.now()).inDays
          : 365;

      return _cache(LicenseInfo(
        status: LicenseStatus.active,
        key: key, activatedAt: activatedAt, expiresAt: expiresAt,
        daysRemaining: max(0, daysLeft),
        deviceId: deviceId,
      ));
    } catch (_) {
      return _cache(const LicenseInfo(status: LicenseStatus.trial, daysRemaining: 30));
    }
  }

  /// Activate a license key.
  Future<ActivationResult> activate(String key) async {
    // Basic format validation: XXXX-XXXX-XXXX-XXXX
    final cleaned = key.replaceAll('-', '').toUpperCase();
    if (cleaned.length != 16) {
      return ActivationResult(
        success: false,
        message: 'Gecersiz lisans anahtari. 16 haneli kod giriniz.',
      );
    }

    // Validate checksum (simple: last 4 chars = hash of first 12)
    final payload = cleaned.substring(0, 12);
    final checksum = cleaned.substring(12);
    final expected = _computeChecksum(payload);
    if (checksum != expected) {
      return ActivationResult(
        success: false,
        message: 'Lisans anahtari dogrulanamadi.',
      );
    }

    // Save to DB
    final deviceId = _generateDeviceId();
    await _db.setSetting('license_key', key);
    await _db.setSetting('license_activated_at', DateTime.now().toIso8601String());
    await _db.setSetting('license_device_id', deviceId);
    await _db.setSetting('license_last_check', DateTime.now().toIso8601String());

    // Update trial info
    await _db.setSetting('trial_started', 'false');

    _cached = null; // force refresh
    return ActivationResult(success: true, message: 'Lisans basariyla aktif edildi!');
  }

  /// Record an online check-in (resets grace period).
  Future<void> recordCheckIn() async {
    await _db.setSetting('license_last_check', DateTime.now().toIso8601String());
    _cached = null;
  }

  /// Start trial.
  Future<void> startTrial() async {
    await _db.setSetting('trial_started', DateTime.now().toIso8601String());
    _cached = null;
  }

  /// Check if a feature requires an active license.
  Future<bool> canAccess({bool requireOnline = false}) async {
    final status = await checkStatus();
    if (!status.isActive) return false;
    if (requireOnline && !status.canUseOffline) return false;
    return true;
  }

  int _trialDaysRemaining(Map<String, String> settings) {
    final started = settings['trial_started'];
    if (started == null) return 30;
    final startDate = DateTime.tryParse(started);
    if (startDate == null) return 30;
    final remaining = 30 - DateTime.now().difference(startDate).inDays;
    return max(0, remaining);
  }

  LicenseInfo _cache(LicenseInfo info) {
    _cached = info;
    return info;
  }

  String _computeChecksum(String payload) {
    final bytes = utf8.encode('MARANGOZAI$payload');
    final digest = crypto.sha256.convert(bytes);
    return digest.toString().substring(0, 4).toUpperCase();
  }

  String _generateDeviceId() {
    // Simple device fingerprint (in production: hardware-based)
    final r = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

// ─── Activation Result ───────────────────────────────────────────────────────

class ActivationResult {
  final bool success;
  final String message;

  const ActivationResult({required this.success, required this.message});
}

/// Settings screen — Usta ayarlari.
/// Kerf, arkalik tipi, varsayilan olculer, bant dusumu.
/// Buyuk form elemanlari, usta Turkcesi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  Map<String, String> _settings = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    try {
      _settings = await db.getSettings();
    } catch (_) {
      _settings = {};
    }
    _initControllers();
    setState(() => _loading = false);
  }

  void _initControllers() {
    final defaults = {
      'kerf_mm': '4.8',
      'trim_mm': '10',
      'plate_width_mm': '2100',
      'plate_length_mm': '2800',
      'alt_yukseklik_mm': '740',
      'alt_derinlik_mm': '560',
      'ust_yukseklik_mm': '720',
      'ust_derinlik_mm': '320',
      'boy_yukseklik_mm': '2080',
      'baza_yukseklik_mm': '100',
      'tezgah_payi_mm': '35',
      'kapak_boslugu_mm': '3',
      'kapak_kenar_payi_mm': '2',
      'raf_cekme_mm': '30',
      'kayit_yuksekligi_mm': '100',
    };
    for (final e in defaults.entries) {
      _controllers[e.key] = TextEditingController(
        text: _settings[e.key] ?? e.value);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _sectionTitle('Kesim Ayarlari'),
              _numberField('kerf_mm', 'Testere payi (kerf)', 'mm', '4.8'),
              _numberField('trim_mm', 'Tras payi', 'mm', '10'),
              _numberField('plate_width_mm', 'Plaka eni', 'mm', '2100'),
              _numberField('plate_length_mm', 'Plaka boyu', 'mm', '2800'),
              const SizedBox(height: 16),

              _sectionTitle('Alt Dolap Varsayilanlari'),
              _numberField('alt_yukseklik_mm', 'Alt dolap yuksekligi', 'mm', '740'),
              _numberField('alt_derinlik_mm', 'Alt dolap derinligi', 'mm', '560'),
              _numberField('baza_yukseklik_mm', 'Baza yuksekligi', 'mm', '100'),
              _numberField('tezgah_payi_mm', 'Tezgah payi', 'mm', '35'),
              const SizedBox(height: 16),

              _sectionTitle('Ust Dolap Varsayilanlari'),
              _numberField('ust_yukseklik_mm', 'Ust dolap yuksekligi', 'mm', '720'),
              _numberField('ust_derinlik_mm', 'Ust dolap derinligi', 'mm', '320'),
              const SizedBox(height: 16),

              _sectionTitle('Boy Dolap Varsayilanlari'),
              _numberField('boy_yukseklik_mm', 'Boy dolap yuksekligi', 'mm', '2080'),
              const SizedBox(height: 16),

              _sectionTitle('Kapak ve Raf'),
              _numberField('kapak_boslugu_mm', 'Kapak arasi bosluk', 'mm', '3'),
              _numberField('kapak_kenar_payi_mm', 'Kapak kenar payi (reveal)', 'mm', '2'),
              _numberField('raf_cekme_mm', 'Raf ondan geri cekme', 'mm', '30'),
              _numberField('kayit_yuksekligi_mm', 'Kayit yuksekligi', 'mm', '100'),
              const SizedBox(height: 16),

              // Arkalik tipi
              _sectionTitle('Arkalik'),
              _dropdownField(
                'arkalik_tip',
                'Arkalik montaj tipi',
                {'cakma': 'Ustten cakma', 'kanal': 'Kanal (groove)'},
              ),
              const SizedBox(height: 16),

              _sectionTitle('Bant'),
              _dropdownField(
                'use_band_deduction',
                'Bant dusumu uygula',
                {'true': 'Evet (>=1mm bantta zorunlu)', 'false': 'Hayir'},
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text('KAYDET'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }

  Widget _numberField(String key, String label, String suffix, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          prefixIcon: const Icon(Icons.straighten, size: 28),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _dropdownField(String key, String label, Map<String, String> options) {
    final currentValue = _settings[key] ?? options.keys.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: options.containsKey(currentValue) ? currentValue : options.keys.first,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.tune, size: 28),
        ),
        items: options.entries.map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, style: const TextStyle(fontSize: 16)),
            )).toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _settings[key] = v);
          }
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final db = ref.read(databaseProvider);
      for (final entry in _controllers.entries) {
        await db.setSetting(entry.key, entry.value.text);
      }
      // Also save dropdown values
      if (_settings.containsKey('arkalik_tip')) {
        await db.setSetting('arkalik_tip', _settings['arkalik_tip']!);
      }
      if (_settings.containsKey('use_band_deduction')) {
        await db.setSetting('use_band_deduction', _settings['use_band_deduction']!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayarlar kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayit hatasi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

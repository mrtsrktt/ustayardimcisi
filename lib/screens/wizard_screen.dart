/// Tasarım sihirbazı — Adım adım proje oluşturma.
/// 6 adım: müşteri ✓ → foto → kroki → malzeme/renk → detay → tasarım

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../modules/module_engine.dart';

class WizardScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String customerName;

  const WizardScreen({super.key, required this.projectId, required this.customerName});

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  int _adim = 0; // 0 .. 4
  static const toplamAdim = 5;

  // Adım verileri
  List<String> _photos = [];
  String? _sketchPath;

  // Malzeme seçimleri
  String _bodyMaterial = 'mdflam';
  String _bodyColor = 'Beyaz';
  String _doorMaterial = 'high_gloss';
  String _doorColor = 'Beyaz';
  double _edgeBandThickness = 2;
  int _cekmeceSayisi = 3;
  bool _camli = false;
  String _kulpTipi = 'modern';

  double _wallLength = 3000; // cm olarak gösterilir, mm saklanır

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        centerTitle: true,
        leading: _adim > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: () => setState(() => _adim--),
              )
            : IconButton(
                icon: const Icon(Icons.close, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // İlerleme
              _ilerlemeCubugu(),
              const SizedBox(height: 24),

              // Adım içeriği
              Expanded(child: _adimIcerik()),

              // Alt butonlar
              _altButonlar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ilerlemeCubugu() {
    final labels = ['Müşteri', 'Fotoğraf', 'Kroki', 'Malzeme', 'Tasarım'];
    return Column(
      children: [
        Row(
          children: List.generate(toplamAdim, (i) {
            final done = i < _adim;
            final active = i == _adim;
            return Expanded(
              child: Row(
                children: [
                  if (i > 0) Expanded(child: Container(height: 3, color: done ? Colors.blue : Colors.grey[300])),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? Colors.blue : done ? Colors.green : Colors.grey[300],
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (i < toplamAdim - 1) Expanded(child: Container(height: 3, color: done ? Colors.green : Colors.grey[300])),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: labels.map((l) => Expanded(
            child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          )).toList(),
        ),
      ],
    );
  }

  Widget _adimIcerik() {
    return switch (_adim) {
      0 => _adimFoto(),
      1 => _adimKroki(),
      2 => _adimMalzeme(),
      3 => _adimDetay(),
      4 => _adimTasarim(),
      _ => const SizedBox(),
    };
  }

  // ─── Adım 1: Fotoğraf ──────────────────────────────────────────────────

  Widget _adimFoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mutfak Fotoğrafları', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Mutfağın farklı açılardan 3-6 fotoğrafını çekin veya yükleyin.',
            style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        const SizedBox(height: 24),

        Expanded(
          child: _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Henüz fotoğraf yok', style: TextStyle(fontSize: 18, color: Colors.grey[400])),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_photos[i]), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: const CircleAvatar(radius: 14, backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ─── Adım 2: Kroki ─────────────────────────────────────────────────────

  final _duvarCtrl = TextEditingController(text: '300');

  @override
  void dispose() {
    _duvarCtrl.dispose();
    super.dispose();
  }

  Widget _adimKroki() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ölçü Krokisi', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('El çizimi krokinizin fotoğrafını yükleyin veya ölçüleri girin.',
            style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        const SizedBox(height: 24),

        if (_sketchPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_sketchPath!), height: 200, fit: BoxFit.cover),
            ),
          ),

        // Duvar uzunluğu girişi
        Text('Duvar Uzunluğu', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _duvarCtrl,
                decoration: const InputDecoration(
                  hintText: 'örn. 300',
                  prefixIcon: Icon(Icons.straighten, size: 28),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Text('cm', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),

        // Ölçü onay uyarısı
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI kroki okuma özelliği yakında eklenecek. Şimdilik ölçüleri yukarıdan girebilirsiniz.',
                  style: TextStyle(fontSize: 14, color: Colors.amber[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Adım 3: Malzeme & Renk ────────────────────────────────────────────

  Widget _adimMalzeme() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Malzeme ve Renk', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),

          // Gövde malzemesi
          Text('Gövde Malzemesi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            _malzemeKart('MDFlam', 'mdflam', Icons.grid_view),
            _malzemeKart('Suntalam', 'suntalam', Icons.grid_view),
            _malzemeKart('MDF', 'mdf', Icons.grid_view),
          ]),
          const SizedBox(height: 24),

          // Kapak malzemesi
          Text('Kapak Malzemesi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            _malzemeKart('High Gloss', 'high_gloss', Icons.auto_awesome),
            _malzemeKart('Membran', 'membran', Icons.texture),
            _malzemeKart('Akrilik', 'akrilik', Icons.invert_colors),
          ]),
          const SizedBox(height: 24),

          // Renk seçimi (basitleştirilmiş)
          Text('Renk Seçimi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            _renkKart('Beyaz', 'Beyaz', Colors.white),
            _renkKart('Krem', 'Krem', Color(0xFFFFF8E7)),
            _renkKart('Antrasit', 'Antrasit', Color(0xFF383838)),
            _renkKart('Meşe', 'Meşe', Color(0xFFD2B48C)),
            _renkKart('Ceviz', 'Ceviz', Color(0xFF8B5A2B)),
            _renkKart('Gri', 'Gri', Color(0xFF808080)),
          ]),
        ],
      ),
    );
  }

  Widget _malzemeKart(String label, String value, IconData icon) {
    final selected = (_adim == 2) ? (_bodyMaterial == value || _doorMaterial == value) : false;
    return GestureDetector(
      onTap: () => setState(() {
        if (_bodyMaterial == value || _doorMaterial == value) return;
        _doorMaterial = value;
      }),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!, width: selected ? 3 : 1),
          color: selected ? Colors.blue.withAlpha(15) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: selected ? Colors.blue : Colors.grey[600]),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _renkKart(String label, String value, Color color) {
    final selected = _doorColor == value || _bodyColor == value;
    return GestureDetector(
      onTap: () => setState(() => _doorColor = value),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!, width: selected ? 3 : 1),
              boxShadow: selected ? [BoxShadow(color: Colors.blue.withAlpha(60), blurRadius: 8)] : [],
            ),
            child: selected ? const Icon(Icons.check, color: Colors.blue, size: 32) : null,
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // ─── Adım 4: Detaylar ──────────────────────────────────────────────────

  Widget _adimDetay() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detaylar', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),

          // Çekmece sayısı
          Text('Alt Çekmece Sayısı', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((n) {
              final selected = _cekmeceSayisi == n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _cekmeceSayisi = n),
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!, width: selected ? 3 : 1),
                      color: selected ? Colors.blue.withAlpha(15) : null,
                    ),
                    child: Center(
                      child: Text('$n', style: TextStyle(fontSize: 32, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Camlı kapak
          Text('Üst Dolaplar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Camlı kapak istiyorum', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Üst dolapların bir kısmı camlı olur'),
            value: _camli,
            onChanged: (v) => setState(() => _camli = v),
          ),

          const SizedBox(height: 16),
          // Kulp
          Text('Kulp Tipi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            _kulpKart('Modern', 'modern', Icons.remove),
            _kulpKart('Klasik', 'klasik', Icons.circle),
            _kulpKart('Profilsiz', 'profilsiz', Icons.touch_app),
          ]),
        ],
      ),
    );
  }

  Widget _kulpKart(String label, String value, IconData icon) {
    final selected = _kulpTipi == value;
    return GestureDetector(
      onTap: () => setState(() => _kulpTipi = value),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!, width: selected ? 3 : 1),
          color: selected ? Colors.blue.withAlpha(15) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: selected ? Colors.blue : Colors.grey[600]),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  // ─── Adım 5: Tasarım Özeti ─────────────────────────────────────────────

  Widget _adimTasarim() {
    final wallLengthCm = double.tryParse(_duvarCtrl.text) ?? 300;
    _wallLength = wallLengthCm * 10; // cm → mm

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasarım Özeti', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Aşağıdaki bilgilerle tasarım oluşturulacak.',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),

          // Özet kartı
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ozetSatir('Müşteri', widget.customerName),
                  const Divider(),
                  _ozetSatir('Duvar Uzunluğu', '${wallLengthCm.toStringAsFixed(0)} cm'),
                  _ozetSatir('Fotoğraf', '${_photos.length} adet'),
                  _ozetSatir('Kroki', _sketchPath != null ? 'Yüklendi' : 'Ölçü girildi'),
                  const Divider(),
                  _ozetSatir('Kapak', '$_doorMaterial — $_doorColor'),
                  _ozetSatir('Gövde', '$_bodyMaterial — $_bodyColor'),
                  _ozetSatir('Çekmece', '$_cekmeceSayisi çekmeceli modül'),
                  _ozetSatir('Camlı', _camli ? 'Evet' : 'Hayır'),
                  _ozetSatir('Kulp', _kulpTipi),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          // AI uyarısı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI tasarım özelliği yakında eklenecek. Şimdilik bu bilgilerle kesim planı oluşturulabilir.',
                    style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ozetSatir(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Alt Butonlar ───────────────────────────────────────────────────────

  Widget _altButonlar() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_adim > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _adim--),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('← GERİ'),
              ),
            ),
          if (_adim > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _ileri,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(56, 56),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_adim < toplamAdim - 1 ? 'DEVAM →' : 'TASARIMI OLUŞTUR'),
            ),
          ),
        ],
      ),
    );
  }

  void _ileri() async {
    if (_adim == 1) {
      // Fotoğraf adımı: fotoğraf yükle
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _photos.addAll(result.files.map((f) => f.path!).where((p) => p != null));
        });
      }
    }

    if (_adim == 2) {
      // Kroki adımı: kroki yükle
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _sketchPath = result.files.first.path);
      }
    }

    if (_adim < toplamAdim - 1) {
      setState(() => _adim++);
    } else {
      // TASARIM OLUŞTUR
      _tasarimOlustur();
    }
  }

  Future<void> _tasarimOlustur() async {
    // Malzeme spec'ini DB'ye kaydet
    final db = ref.read(databaseProvider);

    // Duvar uzunluğuna göre basit modül yerleşimi
    final wallLengthCm = double.tryParse(_duvarCtrl.text) ?? 300;
    final wallMm = (wallLengthCm * 10).round();
    _wallLength = wallMm.toDouble();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // TODO: AI render entegrasyonu (F2)
      // Şimdilik sadece kesim planına geçebilir duruma getir
      await db.updateProject(ProjectRow(
        id: widget.projectId,
        customerId: 0, // updated from DB
        status: 'designed',
        measurementsJson: '{"wall_mm": $_wallLength}',
      ));

      if (!mounted) return;
      Navigator.pop(context); // loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tasarım oluşturuldu! Kesim planı hazır.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }
}

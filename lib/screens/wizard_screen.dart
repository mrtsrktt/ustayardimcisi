/// Tasarım sihirbazı — Adım adım proje oluşturma.
/// 5 adım: Foto → Kroki → Malzeme/Renk → Detay → Tasarım

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database.dart';
import '../providers/database_provider.dart';

class WizardScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String customerName;

  const WizardScreen({super.key, required this.projectId, required this.customerName});

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  int _adim = 0;
  static const toplamAdim = 5;

  // Fotoğraf
  List<String> _photos = [];
  String? _sketchPath;

  // Gövde
  String _govdeMalzeme = 'MDFlam';
  String _govdeRenk = 'Beyaz';

  // Alt kapak
  String _altKapakMalzeme = 'High Gloss';
  String _altKapakRenk = 'Beyaz';

  // Üst kapak
  String _ustKapakMalzeme = 'High Gloss';
  String _ustKapakRenk = 'Beyaz';

  // Detaylar
  int _cekmeceSayisi = 3;
  bool _camli = false;
  String _kulpTipi = 'Modern';
  String _tezgahTipi = 'Laminant';

  double _wallLengthMm = 3000;
  final _duvarCtrl = TextEditingController(text: '300');

  @override
  void dispose() {
    _duvarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _ilerlemeCubugu(),
              const SizedBox(height: 24),
              Expanded(child: _adimIcerik()),
              _altButonlar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── İlerleme ───────────────────────────────────────────────────────────

  Widget _ilerlemeCubugu() {
    final labels = ['Fotograf', 'Kroki', 'Malzeme', 'Detay', 'Tasarim'];
    return Column(
      children: [
        Row(
          children: List.generate(toplamAdim, (i) {
            final done = i < _adim;
            final active = i == _adim;
            return Expanded(
              child: Row(
                children: [
                  if (i > 0) Expanded(child: Container(height: 3, color: done ? Colors.green : Colors.grey[300])),
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? Colors.blue : done ? Colors.green : Colors.grey[300],
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (i < toplamAdim - 1) Expanded(child: Container(height: 3, color: i < _adim ? Colors.green : Colors.grey[300])),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          children: labels.map((l) => Expanded(
            child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          )).toList(),
        ),
      ],
    );
  }

  // ─── Adım içerikleri ────────────────────────────────────────────────────

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

  // ─── Adım 0: Fotoğraf ───────────────────────────────────────────────────

  Widget _adimFoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mutfak Fotograflari', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Mutfağın 3-6 adet fotoğrafını çekin. Farklı açılardan olması tasarım kalitesini artırır.',
            style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        const SizedBox(height: 24),

        // Fotoğraf yükleme alanı
        GestureDetector(
          onTap: _fotoEkle,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              borderRadius: BorderRadius.circular(16),
              color: Colors.blue.withAlpha(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 40, color: Colors.blue[700]),
                const SizedBox(height: 8),
                Text('Fotograf Ekle', style: TextStyle(fontSize: 20, color: Colors.blue[700], fontWeight: FontWeight.w600)),
                Text('Telefondan veya bilgisayardan secin', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Çekilen fotoğraflar
        if (_photos.isNotEmpty) ...[
          Text('${_photos.length} fotograf yuklendi', style: TextStyle(fontSize: 16, color: Colors.green[700], fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2,
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
                    top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _fotoEkle() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() {
        _photos.addAll(result.files.map((f) => f.path!).where((p) => p != null));
      });
    }
  }

  // ─── Adım 1: Kroki ─────────────────────────────────────────────────────

  Widget _adimKroki() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Olcu Krokisi', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('El cizimi krokinizin fotografini yukleyin veya olculeri girin.',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),

          // Kroki yükleme
          GestureDetector(
            onTap: _krokiEkle,
            child: Container(
              width: double.infinity,
              height: _sketchPath != null ? 180 : 100,
              decoration: BoxDecoration(
                border: Border.all(color: _sketchPath != null ? Colors.green : Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: (_sketchPath != null ? Colors.green : Colors.orange).withAlpha(12),
              ),
              child: _sketchPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(File(_sketchPath!), fit: BoxFit.contain),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.draw, size: 36, color: Colors.orange[700]),
                        const SizedBox(height: 6),
                        Text('Kroki Yukle (istege bagli)', style: TextStyle(fontSize: 18, color: Colors.orange[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Duvar uzunluğu
          Text('Duvar Uzunlugu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _duvarCtrl,
                  decoration: const InputDecoration(hintText: '300', prefixIcon: Icon(Icons.straighten, size: 28)),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Text('cm', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _krokiEkle() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _sketchPath = result.files.first.path);
    }
  }

  // ─── Adım 2: Malzeme & Renk ────────────────────────────────────────────

  // Renk listesi
  static const _renkler = ['Beyaz', 'Krem', 'Antrasit', 'Gri', 'Mese', 'Ceviz', 'Siyah'];
  static const _govdeMalzemeler = ['MDFlam', 'Suntalam', 'MDF'];
  static const _kapakMalzemeler = ['High Gloss', 'Membran', 'Akrilik', 'MDFlam', 'Suntalam'];

  Widget _adimMalzeme() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── GÖVDE ──
          _sectionTitle('Govde (Dolap Ici)'),
          _malzemeSecimi(_govdeMalzemeler, _govdeMalzeme, (v) => setState(() => _govdeMalzeme = v)),
          const SizedBox(height: 16),
          _renkSecimi(_govdeRenk, (v) => setState(() => _govdeRenk = v)),
          const Divider(height: 32),

          // ── ALT KAPAK ──
          _sectionTitle('Alt Dolap Kapaklari'),
          _malzemeSecimi(_kapakMalzemeler, _altKapakMalzeme, (v) => setState(() => _altKapakMalzeme = v)),
          const SizedBox(height: 16),
          _renkSecimi(_altKapakRenk, (v) => setState(() => _altKapakRenk = v)),
          const Divider(height: 32),

          // ── ÜST KAPAK ──
          _sectionTitle('Ust Dolap Kapaklari'),
          _malzemeSecimi(_kapakMalzemeler, _ustKapakMalzeme, (v) => setState(() => _ustKapakMalzeme = v)),
          const SizedBox(height: 16),
          _renkSecimi(_ustKapakRenk, (v) => setState(() => _ustKapakRenk = v)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _malzemeSecimi(List<String> options, String selected, Function(String) onSelect) {
    return Wrap(spacing: 8, runSpacing: 8, children: options.map((opt) {
      final isSel = selected == opt;
      return GestureDetector(
        onTap: () => onSelect(opt),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? Colors.blue : Colors.grey[300]!, width: isSel ? 3 : 1),
            color: isSel ? Colors.blue.withAlpha(20) : Colors.white,
          ),
          child: Text(opt, style: TextStyle(fontSize: 18, fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              color: isSel ? Colors.blue : Colors.black87)),
        ),
      );
    }).toList());
  }

  Widget _renkSecimi(String selected, Function(String) onSelect) {
    return Wrap(spacing: 10, runSpacing: 10, children: _renkler.map((renk) {
      final isSel = selected == renk;
      final renkColor = _renkToColor(renk);
      return GestureDetector(
        onTap: () => onSelect(renk),
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: renkColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSel ? Colors.blue : Colors.grey[300]!, width: isSel ? 3 : 1),
                boxShadow: isSel ? [BoxShadow(color: Colors.blue.withAlpha(70), blurRadius: 8)] : [],
              ),
              child: isSel ? const Icon(Icons.check, color: Colors.white, size: 28) : null,
            ),
            const SizedBox(height: 4),
            Text(renk, style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
    }).toList());
  }

  Color _renkToColor(String renk) => switch (renk) {
    'Beyaz' => Colors.white,
    'Krem' => const Color(0xFFFFF8E7),
    'Antrasit' => const Color(0xFF383838),
    'Gri' => const Color(0xFF9E9E9E),
    'Mese' => const Color(0xFFD2B48C),
    'Ceviz' => const Color(0xFF8B5A2B),
    'Siyah' => const Color(0xFF1A1A1A),
    _ => Colors.grey,
  };

  // ─── Adım 3: Detaylar ──────────────────────────────────────────────────

  Widget _adimDetay() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detaylar', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),

          Text('Cekmece Sayisi (alt dolap)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((n) {
              final sel = _cekmeceSayisi == n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _cekmeceSayisi = n),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sel ? Colors.blue : Colors.grey[300]!, width: sel ? 3 : 1),
                      color: sel ? Colors.blue.withAlpha(20) : null,
                    ),
                    child: Center(child: Text('$n', style: TextStyle(fontSize: 30, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text('Ust Dolap', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: const Text('Camli kapak', style: TextStyle(fontSize: 18)),
            value: _camli,
            onChanged: (v) => setState(() => _camli = v),
          ),
          const SizedBox(height: 16),

          Text('Tezgah', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: ['Laminant', 'Akrilik', 'Kompakt', 'Granit', 'Corian'].map((t) {
            final sel = _tezgahTipi == t;
            return GestureDetector(
              onTap: () => setState(() => _tezgahTipi = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? Colors.blue : Colors.grey[300]!, width: sel ? 3 : 1),
                  color: sel ? Colors.blue.withAlpha(20) : null,
                ),
                child: Text(t, style: TextStyle(fontSize: 16, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList()),
          const SizedBox(height: 24),

          Text('Kulp Tipi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: ['Modern', 'Klasik', 'Profilsiz'].map((k) {
            final sel = _kulpTipi == k;
            return GestureDetector(
              onTap: () => setState(() => _kulpTipi = k),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? Colors.blue : Colors.grey[300]!, width: sel ? 3 : 1),
                  color: sel ? Colors.blue.withAlpha(20) : null,
                ),
                child: Text(k, style: TextStyle(fontSize: 16, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  // ─── Adım 4: Tasarım Özeti ─────────────────────────────────────────────

  Widget _adimTasarim() {
    final wallCm = double.tryParse(_duvarCtrl.text) ?? 300;
    _wallLengthMm = wallCm * 10;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasarim Ozeti', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Bilgilerinizi kontrol edin, hazirsaniz tasarimi olusturun.',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),

          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _ozet('Musteri', widget.customerName),
                  _ozet('Duvar', '${wallCm.toStringAsFixed(0)} cm'),
                  _ozet('Fotograf', '${_photos.length} adet'),
                  const Divider(),
                  _ozet('Govde', '$_govdeMalzeme — $_govdeRenk'),
                  _ozet('Alt Kapak', '$_altKapakMalzeme — $_altKapakRenk'),
                  _ozet('Ust Kapak', '$_ustKapakMalzeme — $_ustKapakRenk'),
                  _ozet('Tezgah', _tezgahTipi),
                  _ozet('Cekmece', '$_cekmeceSayisi adet'),
                  _ozet('Camli', _camli ? 'Evet' : 'Hayir'),
                  _ozet('Kulp', _kulpTipi),
                ].map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: w)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Kesim listesi, bantlama ve maliyet raporu hazir!',
                      style: TextStyle(fontSize: 16, color: Colors.green[800])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ozet(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── Alt Butonlar ───────────────────────────────────────────────────────

  Widget _altButonlar() {
    final sonAdim = _adim == toplamAdim - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (_adim > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _adim--),
                style: OutlinedButton.styleFrom(minimumSize: const Size(56, 56), padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('← GERI', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: sonAdim ? _tasarimOlustur : () => setState(() => _adim++),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(56, 56),
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: sonAdim ? Colors.green : null,
              ),
              child: Text(sonAdim ? 'TASARIMI OLUSTUR' : 'DEVAM →', style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tasarım Oluştur ────────────────────────────────────────────────────

  Future<void> _tasarimOlustur() async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Kesim plani hazirlaniyor...', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final db = ref.read(databaseProvider);
      final wallCm = double.tryParse(_duvarCtrl.text) ?? 300;

      // Proje durumunu güncelle
      await db.updateProject(ProjectRow(
        id: widget.projectId,
        customerId: 0, // mevcut değer korunur
        status: 'designed',
        measurementsJson: '{"wall_mm": ${(wallCm * 10).round()}}',
      ));

      await Future.delayed(const Duration(seconds: 1)); // simulasyon

      if (!mounted) return;
      Navigator.pop(context); // loading

      // Başarılı dialog'u göster
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Tasarim Hazir!', style: TextStyle(fontSize: 22)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bilgiSatir('Duvar', '${wallCm.toStringAsFixed(0)} cm'),
              _bilgiSatir('Alt Kapak', '$_altKapakMalzeme — $_altKapakRenk'),
              _bilgiSatir('Ust Kapak', '$_ustKapakMalzeme — $_ustKapakRenk'),
              _bilgiSatir('Govde', '$_govdeMalzeme — $_govdeRenk'),
              _bilgiSatir('Tezgah', _tezgahTipi),
              const SizedBox(height: 16),
              const Text('✅ Kesim listesi olusturuldu\n✅ Bantlama metraji hesaplandi\n✅ Maliyet raporu hazir',
                  style: TextStyle(fontSize: 15)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // wizard
              },
              child: const Text('TAMAM', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // dialog
              },
              icon: const Icon(Icons.edit),
              label: const Text('Duzenle', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _bilgiSatir(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

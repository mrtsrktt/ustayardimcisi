/// Tasarım sihirbazı — Adım adım proje oluşturma.
/// 5 adım: Foto → Kroki → Malzeme/Renk → Detay → Tasarım

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../models/project.dart';
import '../modules/cut_optimizer.dart';
import '../modules/placement_engine.dart';
import 'result_screen.dart';

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
  double _arkalikKalinlik = 8; // 3 veya 8 mm
  double _govdeBant = 1;   // Govde bant kalinligi (0.4 / 1 / 2)
  double _kapakBant = 2;   // Kapak bant kalinligi (0.4 / 1 / 2)

  // Cihaz konumlari (cm, 0 = isaretlenmemis)
  final _evyeCtrl = TextEditingController();
  final _ocakCtrl = TextEditingController();
  final _buzdolabiCtrl = TextEditingController();

  double _wallLengthMm = 3000;
  final _duvarCtrl = TextEditingController(text: '300');

  @override
  void dispose() {
    _duvarCtrl.dispose();
    _evyeCtrl.dispose();
    _ocakCtrl.dispose();
    _buzdolabiCtrl.dispose();
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

  Widget _arkalikKart(String label, double value) {
    final sel = _arkalikKalinlik == value;
    return GestureDetector(
      onTap: () => setState(() => _arkalikKalinlik = value),
      child: Container(
        width: 100, height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? Colors.blue : Colors.grey[300]!, width: sel ? 3 : 1),
          color: sel ? Colors.blue.withAlpha(20) : null,
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 20, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
      ),
    );
  }

  Widget _bantKart(String label, double value, double current, Function(double) onTap) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        width: 90, height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? Colors.blue : Colors.grey[300]!, width: sel ? 3 : 1),
          color: sel ? Colors.blue.withAlpha(20) : null,
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 17, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
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

          Text('Arkalik Kalinligi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _arkalikKart('3 mm', 3),
              const SizedBox(width: 16),
              _arkalikKart('8 mm', 8),
            ],
          ),
          const SizedBox(height: 16),

          Text('Cihaz Konumlari (bos birakilabilir)', style: Theme.of(context).textTheme.titleMedium),
          Text('Soldan kac cm? Girilmezse otomatik yerlestirilir.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _evyeCtrl,
                  decoration: const InputDecoration(labelText: 'Evye', hintText: 'cm', prefixIcon: Icon(Icons.water_drop, size: 22)),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ocakCtrl,
                  decoration: const InputDecoration(labelText: 'Ocak/Firin', hintText: 'cm', prefixIcon: Icon(Icons.local_fire_department, size: 22)),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _buzdolabiCtrl,
                  decoration: const InputDecoration(labelText: 'Buzdolabi', hintText: 'cm', prefixIcon: Icon(Icons.kitchen, size: 22)),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Govde Bant Kalinligi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _bantKart('0.4 mm', 0.4, _govdeBant, (v) => setState(() => _govdeBant = v)),
            const SizedBox(width: 12),
            _bantKart('1 mm', 1, _govdeBant, (v) => setState(() => _govdeBant = v)),
            const SizedBox(width: 12),
            _bantKart('2 mm', 2, _govdeBant, (v) => setState(() => _govdeBant = v)),
          ]),
          const SizedBox(height: 16),

          Text('Kapak Bant Kalinligi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _bantKart('0.4 mm', 0.4, _kapakBant, (v) => setState(() => _kapakBant = v)),
            const SizedBox(width: 12),
            _bantKart('1 mm', 1, _kapakBant, (v) => setState(() => _kapakBant = v)),
            const SizedBox(width: 12),
            _bantKart('2 mm', 2, _kapakBant, (v) => setState(() => _kapakBant = v)),
          ]),
          const SizedBox(height: 16),
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

    // Build anchors from user input (cm → mm)
    final anchors = WallAnchors(
      sinkCenterMm: (_evyeCtrl.text.isEmpty ? null : (double.tryParse(_evyeCtrl.text) ?? 0) * 10),
      cooktopCenterMm: (_ocakCtrl.text.isEmpty ? null : (double.tryParse(_ocakCtrl.text) ?? 0) * 10),
      fridgeCenterMm: (_buzdolabiCtrl.text.isEmpty ? null : (double.tryParse(_buzdolabiCtrl.text) ?? 0) * 10),
    );

    // Run placement engine with anchors
    final altResult = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: _wallLengthMm, isLower: true, anchors: anchors));
    final ustResult = PlacementEngine.placeUpper(PlacementInput(
        wallLengthMm: _wallLengthMm, isLower: false, anchors: anchors));
    final totalAlt = altResult.modules.fold<double>(0, (s, m) => s + m.widthMm);
    final totalUst = ustResult.modules.fold<double>(0, (s, m) => s + m.widthMm);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasarim Ozeti', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Duvar uzerinde modullerinizin on gorunusu:',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 16),

          // 2D Preview
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final previewW = constraints.maxWidth;
                  final scale = previewW / _wallLengthMm;
                  const altH = 100.0, ustH = 70.0, tezgahH = 8.0, bazaH = 14.0, boslukH = 40.0;
                  final totalH = bazaH + altH + tezgahH + boslukH + ustH;
                  return Column(
                    children: [
                      SizedBox(
                        width: previewW, height: totalH,
                        child: CustomPaint(
                          painter: _DuvarOnizleme(
                            altModules: altResult.modules,
                            ustModules: ustResult.modules,
                            wallMm: _wallLengthMm,
                            scale: scale,
                            altH: altH, ustH: ustH, tezgahH: tezgahH, bazaH: bazaH, boslukH: boslukH,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Duvar bilgisi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Duvar: ${wallCm.toStringAsFixed(0)} cm', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('Alt: ${(totalAlt / 10).toStringAsFixed(0)} cm', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          Text('Ust: ${(totalUst / 10).toStringAsFixed(0)} cm', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                      // Kalan bosluk uyarisi
                      if ((_wallLengthMm - totalAlt).abs() > 10 || (_wallLengthMm - totalUst).abs() > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            (_wallLengthMm - totalAlt) > 10 ? 'Alt sırada ${((_wallLengthMm - totalAlt) / 10).toStringAsFixed(0)} cm boşluk var' : (_wallLengthMm - totalAlt) < -10 ? 'Alt sıra ${((totalAlt - _wallLengthMm) / 10).toStringAsFixed(0)} cm taştı!' : 'Ust sırada boşluk/taşma var',
                            style: TextStyle(fontSize: 13, color: (_wallLengthMm - totalAlt) < -10 ? Colors.red : Colors.orange),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ozet metni
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ozet('Musteri', widget.customerName),
                  _ozet('Fotograf', '${_photos.length} adet'),
                  const Divider(),
                  _ozet('Govde', '$_govdeMalzeme — $_govdeRenk'),
                  _ozet('Alt Kapak', '$_altKapakMalzeme — $_altKapakRenk'),
                  _ozet('Ust Kapak', '$_ustKapakMalzeme — $_ustKapakRenk'),
                  _ozet('Cekmece', '$_cekmeceSayisi adet'),
                  _ozet('Camli', _camli ? 'Evet' : 'Hayir'),
                  _ozet('Kulp', _kulpTipi),
                ].map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: w)).toList(),
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

  void _tasarimOlustur() {
    final wallCm = double.tryParse(_duvarCtrl.text) ?? 300;
    _ebatSecimiDialog(wallCm);
  }

  void _ebatSecimiDialog(double wallCm) {
    // Default selections
    String govdeEbat = '2100×2800';
    String kapakEbat = (_altKapakMalzeme == 'High Gloss' || _altKapakMalzeme == 'Akrilik')
        ? '1220×2800' : '2100×2800';
    String arkalikEbat = '2100×2800';

    final isKapakOzel = _altKapakMalzeme == 'High Gloss' || _altKapakMalzeme == 'Akrilik';
    final govdeOpts = ['2100×2800', '1830×3660'];
    final kapakOpts = isKapakOzel ? ['1220×2800', '2100×2800'] : ['2100×2800', '1830×3660'];
    final arkalikOpts = ['2100×2800', '1830×3660'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Plaka Ebat Secimi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kesime baslamadan once plaka ebatlarini secin. '
                    'Varsayilan degerler isaretli geldi.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 20),

                // Govde
                Text('GOVDE (${_govdeMalzeme} ${_govdeRenk})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...govdeOpts.map((e) => RadioListTile<String>(
                  title: Text(e, style: const TextStyle(fontSize: 18)),
                  value: e, groupValue: govdeEbat,
                  onChanged: (v) => setDlg(() => govdeEbat = v!),
                )),
                const Divider(),

                // Kapak
                Text('KAPAK (${_altKapakMalzeme} ${_altKapakRenk})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (isKapakOzel) Text('Piyasa standardi: 1220×2800',
                    style: TextStyle(fontSize: 14, color: Colors.orange[700])),
                const SizedBox(height: 8),
                ...kapakOpts.map((e) => RadioListTile<String>(
                  title: Text(e, style: const TextStyle(fontSize: 18)),
                  value: e, groupValue: kapakEbat,
                  onChanged: (v) => setDlg(() => kapakEbat = v!),
                )),
                const Divider(),

                // Arkalik
                Text('ARKALIK',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...arkalikOpts.map((e) => RadioListTile<String>(
                  title: Text(e, style: const TextStyle(fontSize: 18)),
                  value: e, groupValue: arkalikEbat,
                  onChanged: (v) => setDlg(() => arkalikEbat = v!),
                )),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _goToResult(wallCm, govdeEbat, kapakEbat, arkalikEbat);
                },
                child: const Text('DEVAM — Kesimi Hesapla', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToResult(double wallCm, String govdeEbat, String kapakEbat, String arkalikEbat) {
    // Parse ebat strings to PlateSize
    PlateSize parse(String s) {
      final parts = s.split('×');
      return PlateSize(
        widthMm: double.parse(parts[0]),
        lengthMm: double.parse(parts[1]),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(
        wallLengthMm: wallCm * 10,
        govdeMalzeme: _govdeMalzeme,
        govdeRenk: _govdeRenk,
        altKapakMalzeme: _altKapakMalzeme,
        altKapakRenk: _altKapakRenk,
        ustKapakMalzeme: _ustKapakMalzeme,
        ustKapakRenk: _ustKapakRenk,
        cekmeceSayisi: _cekmeceSayisi,
        camli: _camli,
        kulpTipi: _kulpTipi,
        arkalikKalinlik: _arkalikKalinlik,
        govdePlateSize: parse(govdeEbat),
        kapakPlateSize: parse(kapakEbat),
        arkalikPlateSize: parse(arkalikEbat),
        customerName: widget.customerName,
      )),
    );
  }
}

// ─── 2D Duvar Onizleme CustomPainter ─────────────────────────────────────

class _DuvarOnizleme extends CustomPainter {
  final List<PlacedModule> altModules;
  final List<PlacedModule> ustModules;
  final double wallMm, scale, altH, ustH, tezgahH, bazaH, boslukH;

  _DuvarOnizleme({
    required this.altModules, required this.ustModules,
    required this.wallMm, required this.scale,
    required this.altH, required this.ustH,
    required this.tezgahH, required this.bazaH, required this.boslukH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallW = wallMm * scale;
    double y = 0;

    // Üst modüller
    for (final m in ustModules) {
      final x = m.xPosMm * scale, w = m.widthMm * scale;
      final isCamli = m.code == ModuleCode.u3;
      canvas.drawRect(Rect.fromLTWH(x, y, w, ustH),
          Paint()..color = isCamli ? const Color(0xFFBBDEFB) : const Color(0xFFE0E0E0));
      canvas.drawRect(Rect.fromLTWH(x, y, w, ustH),
          Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 0.5);
      // Çift kapak çizgisi
      if (m.code == ModuleCode.u2 && w > 20) {
        canvas.drawLine(Offset(x + w / 2, y), Offset(x + w / 2, y + ustH),
            Paint()..color = Colors.black38..strokeWidth = 0.5);
      }
      _drawLabel(canvas, m.code.name.toUpperCase(), x + w / 2, y + ustH / 2, w);
      _drawLabel(canvas, '${(m.widthMm / 10).toStringAsFixed(0)}', x + w / 2, y + ustH - 12, w, size: 6);
    }

    // Üst-alt boşluğu
    y += ustH + boslukH;
    canvas.drawLine(Offset(0, y - boslukH / 2), Offset(wallW, y - boslukH / 2),
        Paint()..color = Colors.grey[400]!..strokeWidth = 1);

    // Tezgah çizgisi
    canvas.drawRect(Rect.fromLTWH(0, y - 2, wallW, tezgahH),
        Paint()..color = Colors.grey[600]!);
    canvas.drawRect(Rect.fromLTWH(0, y - 2, wallW, tezgahH),
        Paint()..color = Colors.grey[700]!..style = PaintingStyle.stroke..strokeWidth = 1);

    // Alt modüller
    y += tezgahH;
    for (final m in altModules) {
      final x = m.xPosMm * scale, w = m.widthMm * scale;
      final color = m.code == ModuleCode.a3 ? const Color(0xFFFFF3E0) : const Color(0xFFE8E8E8);
      canvas.drawRect(Rect.fromLTWH(x, y, w, altH), Paint()..color = color);
      canvas.drawRect(Rect.fromLTWH(x, y, w, altH),
          Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 0.5);
      // Çekmeceli yatay çizgiler
      if (m.code == ModuleCode.a3 && w > 10) {
        for (var cy = y + altH / 3; cy < y + altH; cy += altH / 3) {
          canvas.drawLine(Offset(x, cy), Offset(x + w, cy),
              Paint()..color = Colors.black26..strokeWidth = 0.5);
        }
      }
      // Çift kapak dikey çizgi
      if (m.code == ModuleCode.a2 && w > 20) {
        canvas.drawLine(Offset(x + w / 2, y), Offset(x + w / 2, y + altH),
            Paint()..color = Colors.black38..strokeWidth = 0.5);
      }
      _drawLabel(canvas, m.code.name.toUpperCase(), x + w / 2, y + altH / 2, w);
      _drawLabel(canvas, '${(m.widthMm / 10).toStringAsFixed(0)}', x + w / 2, y + altH - 12, w, size: 6);
    }

    // Baza
    y += altH;
    canvas.drawRect(Rect.fromLTWH(0, y, wallW, bazaH),
        Paint()..color = Colors.grey[800]!);
    _drawLabel(canvas, 'BAZA', wallW / 2, y + bazaH / 2, wallW, size: 8);

    // Duvar çerçevesi
    canvas.drawRect(Rect.fromLTWH(0, 0, wallW, y + bazaH),
        Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 2);
    // Duvar uzunluğu etiketi
    _drawLabel(canvas, '${(wallMm / 10).toStringAsFixed(0)} cm', wallW / 2, y + bazaH + 14, wallW);
  }

  void _drawLabel(Canvas c, String text, double cx, double cy, double maxW, {double size = 9}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.black87, fontSize: size, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…',
    )..layout(maxWidth: maxW - 4);
    tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DuvarOnizleme old) => old.wallMm != wallMm || old.scale != scale;
}

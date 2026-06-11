/// Müşteri formu — Adım 1: Müşteri bilgileri.
/// Tek ekran, tek soru: ad + telefon, büyük alanlar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import 'wizard_screen.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Proje'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İlerleme göstergesi
              _ProgressDots(current: 0, total: 6),
              const SizedBox(height: 32),

              Text('Müşteri Bilgileri', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Kime iş yapıyorsunuz?', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              const SizedBox(height: 32),

              // İsim
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Müşteri Adı *',
                  hintText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person, size: 28),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // Telefon
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  hintText: '05XX XXX XX XX',
                  prefixIcon: Icon(Icons.phone, size: 28),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // Adres (opsiyonel)
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adres (isteğe bağlı)',
                  hintText: 'Proje adresi',
                  prefixIcon: Icon(Icons.location_on, size: 28),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Not
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notlar (isteğe bağlı)',
                  hintText: 'Özel istekler, hatırlatmalar...',
                  prefixIcon: Icon(Icons.note, size: 28),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 40),

              // Devam butonu
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _saving ? null : _devam,
                  child: _saving
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text('DEVAM'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _devam() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen müşteri adını girin')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final db = ref.read(databaseProvider);
      final customer = CustomerRow(
        name: name,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      final customerId = await db.insertCustomer(customer);

      // Proje oluştur
      final project = ProjectRow(customerId: customerId);
      final projectId = await db.insertProject(project);

      if (!mounted) return;

      // Sihirbaza geç
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WizardScreen(projectId: projectId, customerName: name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Sihirbaz ilerleme noktaları
class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i <= current;
        return Container(
          width: 12, height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
          ),
        );
      }),
    );
  }
}

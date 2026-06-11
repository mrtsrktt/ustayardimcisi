/// Ana ekran — proje listesi ve yeni proje başlatma.
/// KULLANILABILIRLIK_RAPORU.md §3'teki akışa uygun.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import 'customer_form_screen.dart';
import 'wizard_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final projects = _loadProjects(db);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Text('Usta Yardımcısı', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Projeleriniz', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  )),
              const SizedBox(height: 24),

              // Yeni Proje butonu — büyük, ekranın yarısı kadar
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton.icon(
                  onPressed: () => _yeniProje(context),
                  icon: const Icon(Icons.add_circle_outline, size: 36),
                  label: const Text('+ YENİ PROJE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Proje listesi
              if (projects.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Henüz proje yok',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey[400],
                                )),
                        const SizedBox(height: 8),
                        Text('Yukarıdaki butona basarak başlayın',
                            style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final p = projects[index];
                      return _ProjeKarti(proje: p);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<ProjectWithCustomer> _loadProjects(AppDatabase db) {
    try {
      return db.getAllProjects();
    } catch (_) {
      return [];
    }
  }

  void _yeniProje(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );
  }
}

/// Proje kartı bileşeni
class _ProjeKarti extends StatelessWidget {
  final ProjectWithCustomer proje;
  const _ProjeKarti({required this.proje});

  @override
  Widget build(BuildContext context) {
    final p = proje.project;
    final c = proje.customer;
    final durumText = _durumText(p.status);
    final durumRenk = _durumRenk(p.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WizardScreen(projectId: p.id!, customerName: c?.name ?? ''),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Durum rozeti
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: durumRenk.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_durumIcon(p.status), color: durumRenk, size: 32),
              ),
              const SizedBox(width: 16),
              // Proje bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c?.name ?? 'İsimsiz Müşteri',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(durumText,
                        style: TextStyle(fontSize: 16, color: durumRenk, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(_tarihFormat(p.updatedAt),
                        style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _durumText(String status) => switch (status) {
    'draft' => 'Taslak',
    'designed' => 'Tasarım Hazır',
    'approved' => 'Müşteri Onayladı',
    'cut_ready' => 'Kesime Hazır',
    'quoted' => 'Teklif Verildi',
    _ => status,
  };

  Color _durumRenk(String status) => switch (status) {
    'draft' => Colors.orange,
    'designed' => Colors.blue,
    'approved' => Colors.green,
    'cut_ready' => Colors.teal,
    'quoted' => Colors.purple,
    _ => Colors.grey,
  };

  IconData _durumIcon(String status) => switch (status) {
    'draft' => Icons.edit_note,
    'designed' => Icons.design_services,
    'approved' => Icons.thumb_up,
    'cut_ready' => Icons.cut,
    'quoted' => Icons.description,
    _ => Icons.folder,
  };

  String _tarihFormat(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

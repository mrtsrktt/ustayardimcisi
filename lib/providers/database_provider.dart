/// Riverpod providers for the AppDatabase singleton and core state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

/// Database instance provider — initialized once at app startup.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Database must be initialized before use. '
      'Call initializeDatabase() in main() and override this provider.');
});

/// Override this provider after initialization.
final databaseInstance = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Customer list provider.
final customersProvider = Provider<List<CustomerRow>>((ref) {
  final db = ref.watch(databaseProvider);
  try {
    return db.getAllCustomers();
  } catch (_) {
    return [];
  }
});

/// Projects list provider.
final projectsProvider = Provider<List<ProjectWithCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  try {
    return db.getAllProjects();
  } catch (_) {
    return [];
  }
});

/// Single project provider.
final projectProvider = Provider.family<ProjectWithCustomer?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  try {
    return db.getProject(id);
  } catch (_) {
    return null;
  }
});

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustayardimcisi/database/database.dart';
import 'package:ustayardimcisi/providers/database_provider.dart';
import 'package:ustayardimcisi/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders correctly', (WidgetTester tester) async {
    final db = AppDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    // Main UI elements should be present
    expect(find.text('Projeleriniz'), findsOneWidget);
    expect(find.text('+ YENİ PROJE'), findsOneWidget);
  });
}

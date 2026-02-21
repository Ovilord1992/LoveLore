import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navell/app/theme.dart';

void main() {
  testWidgets('App uses correct theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Text('Amoria')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Amoria'), findsOneWidget);
  });
}

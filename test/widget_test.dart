import 'package:flutter_test/flutter_test.dart';

import 'package:navell/app/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const NavellApp());
    expect(find.text('Navell'), findsOneWidget);
  });
}

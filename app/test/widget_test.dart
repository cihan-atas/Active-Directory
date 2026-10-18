import 'package:flutter_test/flutter_test.dart';
import 'package:active_directory_vault/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ActiveDirectoryApp());
    expect(find.byType(ActiveDirectoryApp), findsOneWidget);
  });
}

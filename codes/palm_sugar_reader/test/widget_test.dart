import 'package:flutter_test/flutter_test.dart';
import 'package:palm_sugar_reader/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PalmSugarReaderApp());
    expect(find.text('PalmSugarReader'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:palm_sugar_reader/main.dart';
import 'package:palm_sugar_reader/services/settings_service.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(PalmSugarReaderApp(settings: AppSettings()));
    expect(find.text('PalmSugarReader'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:e_commerce_app/main.dart'; // Apnar project name check koren

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MegaMart()); // MyApp er jaygay MegaMart

    expect(find.text('0'), findsOneWidget);
  });
}
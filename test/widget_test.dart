import 'package:flutter_test/flutter_test.dart';
import 'package:kryzit_rider/main.dart';

void main() {
  testWidgets('Rider App launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const KryzitRiderApp());
  });
}
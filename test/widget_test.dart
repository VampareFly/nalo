import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tester_kit/app/app.dart';

void main() {
  testWidgets('shows the application name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TesterKitApp()));
    await tester.pumpAndSettle();

    expect(find.text('TesterKit'), findsOneWidget);
  });
}

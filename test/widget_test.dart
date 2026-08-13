import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalo/app/app.dart';

void main() {
  testWidgets('shows the application name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NaloApp()));
    await tester.pumpAndSettle();

    expect(find.text('Nalo'), findsOneWidget);
  });
}

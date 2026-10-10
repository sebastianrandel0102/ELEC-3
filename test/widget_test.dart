import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';

void main() {
  testWidgets('Firebase setup failure is explained to the user', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SaveTrackApp(startupError: 'configuration missing'),
    );

    expect(find.text('Connect your Firebase project'), findsOneWidget);
    expect(find.textContaining('configuration missing'), findsOneWidget);
  });
}

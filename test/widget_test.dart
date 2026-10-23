import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';

void main() {
  testWidgets('Firebase setup failure is explained to the user', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SaveTrackApp(startupError: 'configuration missing'),
    );

    expect(find.text('We could not connect to SaveTrack.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('configuration missing'), findsNothing);
  });
}

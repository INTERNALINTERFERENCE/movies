import 'package:flutter_test/flutter_test.dart';

import 'package:viewsync/main.dart'; // Corrected import path

void main() {
  testWidgets('LandingScreen renders RoomHub title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ViewSyncApp());

    // Verify that the "RoomHub" text is present.
    expect(find.text('RoomHub'), findsOneWidget);
  });
}
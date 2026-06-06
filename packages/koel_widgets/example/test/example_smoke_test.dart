import 'package:flutter_test/flutter_test.dart';
import 'package:koel_widgets/koel_widgets.dart' show MessageBubble;

import 'package:koel_widgets_example/main.dart';

void main() {
  // Architecture §6 smoke: the example builds and runs the demo turn to
  // completion without throwing, and the composed surface renders bubbles.
  // Pumps the real root — the same widget `main()` hands to `runApp` — so the
  // app's own client/session/controller wiring (and its teardown on unmount) is
  // what gets exercised.
  testWidgets('example app builds, settles, and renders bubbles', (
    tester,
  ) async {
    await tester.pumpWidget(const KoelWidgetsExampleApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The seed turn + the agent's "Hello, world!" reply ⇒ ≥1 bubble.
    expect(find.byType(MessageBubble), findsWidgets);
  });
}

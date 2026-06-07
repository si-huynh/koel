import 'package:flutter_test/flutter_test.dart';
import 'package:koel/koel.dart';

void main() {
  // The assertion is COMPILE-TIME: this file imports only `package:koel/koel.dart`
  // and names one public symbol from each re-exported package — HttpAgent
  // (koel_http), KoelClient (koel_core), KoelChatController (koel_flutter). If any
  // re-export is dropped from the barrel, this file fails to compile. Building the
  // real three-layer chain (agent → client → session → controller) also proves the
  // public constructors line up across the layers, not just that the names resolve.
  test('barrel re-exports koel_core + koel_http + koel_flutter', () {
    final agent = HttpAgent(url: Uri.parse('https://example.test/agui'));
    final client = KoelClient(agent: agent);
    final controller = KoelChatController(session: client.newSession());
    // Teardowns run LIFO: controller (cancels its session subscription) before
    // client (which owns session disposal) — the correct ownership order.
    addTearDown(client.dispose);
    addTearDown(controller.dispose);

    expect(agent, isA<HttpAgent>());
    expect(client, isA<KoelClient>());
    expect(controller, isA<KoelChatController>());
  });
}

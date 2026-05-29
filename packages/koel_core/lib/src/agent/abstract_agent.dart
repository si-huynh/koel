import '../event/ag_ui_event.dart';
import '../input/run_agent_input.dart';

/// Backend-bridge SPI: the single contract every transport/backend adapter
/// implements.
///
/// Adapters NEVER throw `KoelError` — they emit `RunErrorEvent`. The
/// `interface class` marker prevents accidental instance construction; consumers
/// reach for `KoelClient` instead.
abstract interface class AbstractAgent {
  /// Initiates a run and returns the canonical event stream. Cancelling the
  /// subscription cancels the run.
  Stream<AgUiEvent> run(RunAgentInput input);
}

// Fixture for koel_lints `exhaustive_switch_must_have_default` rule.
// The local AgUiEvent declared here intentionally collides with koel_core's
// future AgUiEvent by name — that's what the rule keys off (Story 1.3 §5.1).

sealed class AgUiEvent {
  const AgUiEvent();
}

final class RunStartedEvent extends AgUiEvent {
  const RunStartedEvent();
}

final class RunFinishedEvent extends AgUiEvent {
  const RunFinishedEvent();
}

final class RunErrorEvent extends AgUiEvent {
  const RunErrorEvent();
}

void describe(AgUiEvent event) {
  // expect_lint: exhaustive_switch_must_have_default
  switch (event) {
    case RunStartedEvent _:
      print('started');
    case RunFinishedEvent _:
      print('finished');
    case RunErrorEvent _:
      print('error');
  }
}

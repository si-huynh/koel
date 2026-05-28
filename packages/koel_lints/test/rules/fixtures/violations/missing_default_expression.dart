// Switch-EXPRESSION analog of `missing_default.dart`. Same sealed shape,
// same intentional name-collision with koel_core's future AgUiEvent
// (Story 1.3 Dev Notes §"Critical AST nuance"). Three subtypes covered
// explicitly with no `_ =>` arm — rule must fire exactly once.

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

String describe(AgUiEvent event) {
  // expect_lint: exhaustive_switch_must_have_default
  return switch (event) {
    RunStartedEvent _ => 'started',
    RunFinishedEvent _ => 'finished',
    RunErrorEvent _ => 'error',
  };
}

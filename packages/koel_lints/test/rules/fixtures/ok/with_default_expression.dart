// Switch-EXPRESSION analog of `with_default.dart`. Two subtypes covered
// explicitly; `_ =>` catches the third — keeps the wildcard reachable
// (mirrors statement-form Deviation 4 reasoning).

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
  return switch (event) {
    RunStartedEvent _ => 'started',
    RunFinishedEvent _ => 'finished',
    _ => 'other',
  };
}

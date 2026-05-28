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
  switch (event) {
    case RunStartedEvent _:
      print('started');
    case RunFinishedEvent _:
      print('finished');
    default:
      print('other');
  }
}

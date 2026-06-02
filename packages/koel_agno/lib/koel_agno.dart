/// AG-UI adapter for Agno backends.
library;

export 'src/agno_agent.dart';
// Only the options type is public surface — it is an `AgnoAgent` constructor
// param. `agnoMessageToWire` stays internal (consumers configure via the agent,
// not by calling the converter directly).
export 'src/conversion/message_conversion.dart' show AgnoConversionOptions;

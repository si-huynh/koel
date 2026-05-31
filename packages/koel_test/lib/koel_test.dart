/// Test fixtures, MockAgent, and ConformanceRunner for koel adapters.
library;

// Surfaces both MockAgent and MockAgentBuilder (the return type of the public
// programmatic()). koel_core is NOT re-exported — consumers depend on it
// directly; the meta-package is the only re-exporter.
export 'src/mock_agent.dart';

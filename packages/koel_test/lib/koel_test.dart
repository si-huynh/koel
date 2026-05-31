/// Test fixtures, MockAgent, and ConformanceRunner for koel adapters.
library;

// Surfaces both MockAgent and MockAgentBuilder (the return type of the public
// programmatic()). koel_core is NOT re-exported — consumers depend on it
// directly; the meta-package is the only re-exporter.
export 'src/mock_agent.dart';

// Surfaces FixtureLoader (the four static loaders) and FixtureSession.
// MockAgent.fromFixture is already reachable through the mock_agent export.
export 'src/fixture_loader.dart';

// Surfaces ToolHandlerTestHarness and the ToolHandler typedef (FR-G3).
export 'src/tool_handler_test_harness.dart';

// Surfaces ConformanceReport and ConformanceFailure (the runner's result types).
export 'src/conformance_report.dart';

// Surfaces ConformanceRunner (FR-G4 — the backend-agnostic conformance check).
export 'src/conformance_runner.dart';

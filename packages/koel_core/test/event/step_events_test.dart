import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

void main() {
  group('StepStartedEvent', () {
    test('const construction + type membership', () {
      const event = StepStartedEvent(stepName: 'plan');
      expect(event.stepName, 'plan');
      expect(event, isA<AgUiEvent>());
      expect(event, isA<StepStartedEvent>());
    });

    test('structural equality + copyWith', () {
      const a = StepStartedEvent(stepName: 'plan');
      expect(a, equals(const StepStartedEvent(stepName: 'plan')));
      expect(
        a.hashCode,
        equals(const StepStartedEvent(stepName: 'plan').hashCode),
      );
      expect(a, isNot(equals(const StepStartedEvent(stepName: 'act'))));
      expect(a.copyWith(stepName: 'act').stepName, 'act');
    });

    test('fromJson + dual round-trip', () {
      final event = StepStartedEvent.fromJson({
        'type': 'STEP_STARTED',
        'stepName': 'plan',
      });
      expect(event, const StepStartedEvent(stepName: 'plan'));
      expect(event.toJson(), {'type': 'STEP_STARTED', 'stepName': 'plan'});
      expect(StepStartedEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing stepName throws ProtocolError(protocolMalformed)', () {
      expect(
        () => StepStartedEvent.fromJson({'type': 'STEP_STARTED'}),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('StepFinishedEvent', () {
    test('const construction + type membership', () {
      const event = StepFinishedEvent(stepName: 'plan');
      expect(event.stepName, 'plan');
      expect(event, isA<AgUiEvent>());
    });

    test('fromJson + dual round-trip', () {
      final event = StepFinishedEvent.fromJson({
        'type': 'STEP_FINISHED',
        'stepName': 'plan',
      });
      expect(event, const StepFinishedEvent(stepName: 'plan'));
      expect(event.toJson(), {'type': 'STEP_FINISHED', 'stepName': 'plan'});
      expect(StepFinishedEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing stepName throws ProtocolError(protocolMalformed)', () {
      expect(
        () => StepFinishedEvent.fromJson({'type': 'STEP_FINISHED'}),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });
}

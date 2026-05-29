/// Root of the AG-UI event union — the canonical stream element every
/// [AbstractAgent] emits.
///
/// This story (2.1) lands the **sealed root only**, with no concrete subtypes:
/// [AbstractAgent.run] returns `Stream<AgUiEvent>`, so the type must exist for
/// `koel_core` to analyze clean. Story 2.2 expands this union — the per-family
/// subtypes, `UnknownAgUiEvent`, and the JSON deserializer dispatcher — by
/// extending this file, not recreating it.
///
/// `sealed` restricts subtyping to this library, which is what lets downstream
/// `switch`es over the union be exhaustive (enforced by the `koel_lints`
/// `exhaustive_switch_must_have_default` rule once subtypes exist).
sealed class AgUiEvent {
  const AgUiEvent();
}

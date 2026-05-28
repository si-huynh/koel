---
name: feedback-brainstorming-explain-deeply
description: In brainstorming/design sessions on unfamiliar tech domains, user wants deep explanations + Flutter analogies + concrete code sketches BEFORE being asked to judge an idea
metadata:
  type: feedback
---

When facilitating brainstorming or design sessions that involve technical domains the user is not deeply experienced in (e.g., SDK design, protocols, infra patterns), do NOT pose binary "đồng ý / không đồng ý?" questions on raw ideas. Instead, for each prompt:

1. Explain the concept in plain Vietnamese / English with no jargon left undefined.
2. Anchor it in something user already knows — Flutter patterns (Bloc/Cubit, Retrofit + Repository, GoRouter, DI/injectable), familiar OSS packages, or other domains they have hands-on with.
3. Sketch a concrete short code shape (pseudocode is fine) so the trade-off is visible, not abstract.
4. Lay out 2–3 alternatives side by side with pros/cons before asking for a reaction.
5. Then invite reaction by feeling ("which feels right?") rather than by expertise ("which is technically correct?").

**Why:** User said directly during the 2026-05-27 brainstorming session on the Dart AG-UI client design: *"tôi cũng chưa có nhiều kinh nghiệm về làm cái này á nên phiền bạn giúp tôi giải nghĩa kĩ hơn ở mỗi prompt. ví dụ prompt này, tôi không đủ kiến thức để đánh giá là ok hay không nữa."* Without context, they cannot meaningfully participate and revert to fast "agree" answers that aren't real consent.

**How to apply:** Trigger whenever the session topic is outside user's stated expertise (deep Flutter app dev is core expertise; SDK/protocol design is not). Inside their core expertise, the lighter facilitator style is fine. Pace will be slower and idea count lower — that's correct; quality of understanding beats quantity of ideas.

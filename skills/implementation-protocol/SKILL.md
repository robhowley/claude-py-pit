---
name: implementation-protocol
description: Orchestrate feature implementation with a behavior-first, minimal-patch discipline. Use this skill whenever the user asks you to implement a feature, add functionality, build an endpoint, wire up a new capability, or make any non-trivial code change in a Python/FastAPI project. Also use when the user says "build this", "add support for X", "implement X", or describes a feature they want working. This skill is about the *process* of turning intent into a verified, reviewable change - not about any single framework or tool.
disable-model-invocation: false
---

# implementation-protocol

This skill orchestrates how you turn a feature request into a verified, reviewable change. It is not about writing code — it is about enforcing a contract between **intent**, **change**, and **proof**.

The discipline here exists because the most common failure mode for AI-driven implementation is *overbuilding*: hallucinated architecture, speculative abstractions, scope creep, and "looks correct" completion without proof. This skill prevents all of that by anchoring every action to observable behavior and failing signals.

## When to use

- User asks you to implement a feature, endpoint, capability, or behavior
- User describes something they want working and expects you to build it
- Any non-trivial code change (more than a one-line fix)

## When not to use

- Pure refactoring with no behavior change (use code-quality or simplify)
- Scaffolding a new project from scratch (use fastapi-init)
- One-line bug fixes where the fix is obvious

---

## Phase 1 — Define the behavior

Never start with implementation. Start by defining what success looks like in concrete, observable terms.

Before touching any code, establish:

1. **Inputs and outputs** — what goes in, what comes out. Be specific: request shape, response shape, status codes, return types.
2. **API contract** — if this is an endpoint, what's the route, method, request/response schema?
3. **Side effects** — what changes in the world? DB writes, log entries, events emitted, files created.
4. **Error cases** — what happens when inputs are invalid, dependencies are unavailable, or preconditions aren't met?

### The implementation ledger

Before proceeding, produce a short ledger that makes the rest of the process auditable. Write it in conversation (or in `.dev/todos/<feature>.md` if the user prefers a file). The ledger has four sections:

```
## Behaviors
- [ ] B1: POST /items returns 201 with created item
- [ ] B2: POST /items with missing name returns 422
- ...

## Files to change
- src/api/routes/items.py (new router)
- src/models/item.py (new model)
- ...

## Tests to add/update
- tests/test_items.py::test_create_item (B1)
- tests/test_items.py::test_create_item_missing_name (B2)
- ...

## Proof commands
- uv run pytest tests/test_items.py
- uv run pytest tests/ (full suite)
- uv run ruff check .
```

Every behavior gets an ID (B1, B2, ...). Every test references the behavior it proves. Every file references the behavior it serves. In Phase 3, every diff line must trace back to a behavior ID in this ledger. In Phase 6, every behavior must have a passing test.

This is what makes "every diff line maps to a behavior" auditable instead of rhetorical.

### Handling ambiguity

Not every request arrives fully specified. The rule for ambiguity:

- **Clarify only if the ambiguity changes the contract materially.** If the answer determines different endpoints, different DB schemas, or different error semantics, ask.
- **Otherwise, choose the most conservative interpretation and state it.** Say "I'm interpreting X as Y because Z" and proceed. The user can correct you, and the ledger makes it easy to trace the impact.

This preserves momentum. Models tend to over-ask, and premature clarification stalls more implementations than it saves. When in doubt, pick the simpler reading, document it, and move.

### Write tests first

The ledger's `## Tests to add/update` section is your test plan. Write those tests now - they should **fail**, confirming the behavior doesn't exist yet. If they pass before you've written any implementation, either the tests are wrong or the feature already exists. Treat these tests as hypotheses until Phase 4 validates them.

---

## Phase 2 — Discover the repo's patterns

Before writing any implementation, understand how the codebase already does things. Search before you infer. Infer before you invent.

Specifically, answer:

- **Where does similar code live?** Find the closest existing feature and study its structure.
- **What patterns are canonical?** Router registration, dependency injection, model definitions, service layers — match whatever the repo already does.
- **What naming conventions are used?** File names, function names, variable names, module organization.
- **What dependencies are already available?** Don't add a library when the project already has one that does the job.

If the repo has a `skills/` plugin or `CLAUDE.md` with conventions, follow those. If a sibling skill (uv, click-cli, fastapi-errors, sqlalchemy-models, pydantic-schemas, etc.) covers part of the work, defer to it rather than reinventing.

### The canonical-path tie-breaker

When multiple plausible implementation paths exist, prefer the one most consistent with the nearest existing feature, even if another path seems cleaner. "Nearest" means: same domain, same module, or most similar in shape to what you're building.

This is a hard tie-breaker, not a suggestion. If the repo puts business logic in route handlers and you think it belongs in a service layer, you put it in route handlers. The time to introduce a new pattern is when the user explicitly asks for one, not when you're implementing a feature.

---

## Phase 3 — Minimal patch

The first implementation must be the **smallest change that plausibly satisfies the behavior**. This is a hard constraint, not a suggestion.

Concretely:

- No preemptive abstractions. If you only need one implementation, don't write an interface.
- No "while I'm here" refactors. If adjacent code is messy, leave it messy.
- No new architectural layers unless the behavior literally cannot be expressed without one.
- No speculative future-proofing. Build for the requirement in front of you.

Every line in your diff must map to a required behavior from Phase 1. If a change cannot be justified by a specific behavior — remove it. This is the single most important discipline in this entire skill. Scope creep is how agents drift, and it happens silently, one "helpful" addition at a time.

If your diff introduces changes that are not referenced in the ledger, you are overbuilding. Stop and remove them.

### Writing the code

- Follow the repo's existing patterns (Phase 2)
- Keep changes localized - avoid entangled edits that touch unrelated modules
- Optimize for reviewability: small diffs, clear intent per change, no mixed concerns
- Every change should be independently reversible
- For multi-layer features, implement bottom-up: data layer → business logic → API surface → tests

---

## Phase 4 — Prove it works

Verification is adversarial. Your job is to try to break your own solution.

Run, in order:

1. **The new behavior tests** — they should now pass. If they were failing before (Phase 1) and pass now, that's a real signal.
2. **The existing test suite** — nothing should have broken. Run the full relevant test scope, not just your new tests.
3. **Edge cases** — exercise the error paths and boundary conditions you identified in Phase 1.
4. **Static checks** — lint, type checking, whatever the project uses. Run them.

If anything fails, you are now in the iteration loop (Phase 5). Do not declare the task done because "the main path works."

### Skepticism toward your own tests

Tests you just wrote might be:
- Testing the wrong thing (asserting on implementation details instead of behavior)
- Too permissive (passing even when the feature is broken)
- Too tightly coupled to your implementation (breaking if the approach changes)

If a test passed suspiciously easily, or if it tests something trivial, examine it critically. A good test would fail if the feature were removed.

---

## Phase 5 — Failure-driven iteration

Progress is driven by **failing signals**, not intuition.

The loop:
1. Identify the specific failing behavior (test failure, lint error, type error)
2. Apply the minimal fix — only address what failed
3. Re-run verification (all of Phase 4, not just the thing that failed)
4. Repeat until green

Do not wander. Do not fix things that aren't failing. Do not "improve" code that passes its tests. The failing signal tells you exactly where to focus.

If you find yourself making changes without a corresponding failing signal, stop and ask: what behavior am I trying to satisfy? If you can't name one, you're drifting.

---

## Phase 6 — Completion check

The task is done when — and only when — all of these are true:

- [ ] All existing tests pass
- [ ] New behavior is covered by tests that fail without the implementation
- [ ] No unrelated diffs exist in the changeset
- [ ] Lint and type checks pass
- [ ] Every diff line maps to a required behavior

The task is **not** done when:
- "Feature implemented" (says who?)
- "Code looks correct" (prove it)
- "Tests pass" (are they testing the right thing?)

If you cannot check a box, go back to the relevant phase.

---

## Ground rules (always active)

- **No hidden assumptions.** Ground every assumption in a file you've read or a pattern you've found. No imaginary services, configs, or dependencies.
- **No hallucinated architecture.** If you haven't seen it in the codebase, don't assume it exists.
- **Rollback mindset.** Keep changes localized and independently reversible.
- **Diff quality > code quality.** A direct implementation touching 3 files beats an elegant abstraction touching 15.

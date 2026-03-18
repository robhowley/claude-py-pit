---
name: code-quality
description: Opinionated code health stack for Python repos using Ruff, pre-commit, and Markdown linting. Prefers consolidation over redundant tooling, preserves working repos unless migration is requested, and provides a simple adoption path for both new and existing projects.
disable-model-invocation: false
---

# code-quality

Opinionated guidance for adopting a **small, high-signal code health stack** in Python repositories.

This skill standardizes on:

- **Ruff** for Python linting and formatting
- **pre-commit** for local enforcement
- **Markdown linting** for docs quality
- a small set of **file-sanity hooks**

This skill is intentionally opinionated.
It favors **consolidation, low redundancy, fast feedback, and easy adoption**.

It is designed for both:

- **new repos** that need a clean default stack
- **existing repos** that want to add, simplify, or migrate code-quality tooling

This skill does **not** assume the repo must be 0→1.
It should be applied tactically in real repos with existing constraints.

---

# Apply this Skill When

Apply this skill when the user:

- asks to add linting, formatting, hooks, or repo hygiene
- wants to standardize or simplify Python quality tooling
- wants to add or improve pre-commit
- wants to move to Ruff
- wants to reduce overlapping tools such as Black + isort + Flake8
- wants docs quality checks such as Markdown linting
- asks what local and CI checks a Python repo should run

Trigger phrases: "my CI keeps failing on style checks", "can I replace Black and Flake8 with
something simpler?", "what pre-commit hooks should I be using?", "how do I
set up linting for a new Python project?", "our repo has no formatting
enforcement, where do I start?"

Do **not** apply this skill when:

- the task is unrelated to repo tooling or code health
- the user explicitly wants a different stack
- the repo is constrained by external rules the user wants preserved

---

# Mission

When this skill is active, the model's job is to assess the repo's current
code health tooling, produce concrete ready-to-use config that installs the
preferred stack or closes the gap from where the repo is, and leave the
developer with exact commands to verify it works.

---

# Hard Rules

**MUST:**

- Prefer a **small number of high-leverage tools** over overlapping tool chains.
- Use **Ruff as the preferred Python lint + format target** unless the user explicitly wants something else.
- Keep the quality contract **easy to run locally** and **easy to mirror in CI**.
- Prefer **incremental adoption** in existing repos when a big-bang migration is unnecessary.
- Keep configuration centralized where practical, preferably in `pyproject.toml`.
- Prefer narrow rule-level ignores over broad file-level ignores. Document non-obvious ignores briefly. A large ignore list signals stack drift.

**MUST NOT:**

- Introduce redundant Python tooling without a clear reason.
- Treat pre-commit as a kitchen-sink dumping ground.
- Add CI-only quality checks that are not part of the repo's local development contract.
- Replace a working stack silently; migration should be explicit when meaningful change is involved.
- Spread config across unnecessary files when one canonical location is sufficient.
- Add mypy, pyright, Black, isort, Flake8, autoflake, or similar tools "just because."
- Preserve overlapping tools after migrating to Ruff unless a specific gap requires it.
- Propose type-checking as part of the default code-health stack.

---

# Core Position

The recommended default stack is:

- **Ruff** as the single Python lint + format tool
- **pre-commit** as the local enforcement layer
- **Markdown linting** for human-facing docs
- a few **boring sanity hooks** for common repo mistakes

This stack is preferred because it is:

- fast
- simple
- low-overhead
- easy to understand
- easy to adopt incrementally

---

# SOP

1. **Inspect existing tooling** — look for `.pre-commit-config.yaml`,
   `pyproject.toml` tool sections, existing linters/formatters, CI config.
2. **Assess the state** — healthy / partial / messy / missing. Identify
   redundant tools (Black + isort + Flake8, etc.).
3. **Recommend the smallest coherent path** — full install for green-field,
   targeted extension or migration for existing repos.
4. **Generate config** — use the canonical templates below as the starting
   point; adapt rev pins and rule selections to match the repo's Python version
   and existing suppressions.
5. **Call out removals** — explicitly name overlapping tools to delete and why.
6. **End with verification commands** — exact `ruff`, `pre-commit`, and
   markdownlint commands to confirm the stack is working. CI quality steps
   should mirror these: Ruff check, Ruff format check, Markdown lint, and
   tests (if present).

---

# Preferred Stack

## Python quality

Use Ruff for:

- linting
- formatting
- import sorting
- common modernization and cleanup checks

Preferred commands:

```bash
ruff check .
ruff format .
```

Ruff is the preferred consolidation target for Python code health.

---

## Local enforcement

Use pre-commit to run:

- Ruff check
- Ruff format check or formatter hook
- Markdown lint
- basic file-sanity hooks

Pre-commit should enforce the repo contract locally, not invent a second policy.

---

## Documentation quality

Use a Markdown linter for:

- `README.md`
- docs files
- contribution docs
- workflow docs
- skill docs or similar human-facing instructions

Docs are part of repo quality and must not be ignored.

---

## Basic sanity hooks

Prefer a small set of high-signal hooks such as:

- trailing whitespace cleanup
- end-of-file newline
- mixed line ending normalization
- YAML validation
- TOML validation
- merge conflict marker detection
- large file checks when appropriate

Keep this list short and boring.

---

# Canonical Config Templates

Use these as the blessed starting point. Adapt rev pins and rule selections to the repo — the structure is the stable part.

## `.pre-commit-config.yaml`

> **Note:** rev pins go stale — update to current stable versions before committing. The structure is the stable part.

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-toml
      - id: check-merge-conflict

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.41.0
    hooks:
      - id: markdownlint
```

## `pyproject.toml` Ruff block

> **Note:** adjust `target-version` to match the repo's Python version.
> `select` covers errors, pyflakes, import sorting, and pyupgrade — a
> high-signal low-noise default. Expand only when there's a clear reason.

```toml
[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]
```

---

# Existing Repo Strategy

This skill should be used **opportunistically and tactically** in existing repos.

General approach:

1. identify the repo's current tooling
2. determine whether it is healthy, partial, messy, or missing
3. recommend the **smallest coherent path** toward a cleaner stack
4. prefer consolidation when the repo is already paying complexity costs

This skill should **not** read like a rigid if/else decision tree.
It should behave like a practical engineer improving the repo from where it is.

Examples:

- a repo with no linting can adopt the preferred stack directly
- a repo with Black + isort + Flake8 can migrate toward Ruff if the user wants simplification
- a repo with partial pre-commit can add Ruff and Markdown lint without a full tooling reset
- a repo with a working non-Ruff stack should not be rewritten unless the user wants the change

---

# Verification Expectations

When proposing or applying this stack, end with exact commands such as:

```bash
ruff check .
ruff format --check .
pre-commit run --all-files
```

Include Markdown lint commands if configured, plus test commands if relevant.

---

# Completion Checklist

- [ ] Existing tooling was inspected before generating config
- [ ] Redundant tools (Black, isort, Flake8, autoflake) were called out for removal
- [ ] Config is centralized in `pyproject.toml` where possible
- [ ] `.pre-commit-config.yaml` uses the canonical structure as the base
- [ ] Pre-commit hooks are limited to high-signal checks
- [ ] CI steps mirror the local contract (no CI-only quality checks)
- [ ] Response ends with exact verification commands

---

# Outcome

Applying this skill should produce a repo with:

- one clear Python quality toolchain
- one clear local enforcement path
- one clear CI quality contract
- less overlapping tooling
- better documentation hygiene
- lower maintenance overhead

---
description: Production-ready SQLAlchemy 2.x model patterns for Python backend projects. Use this skill when the user needs to define ORM models, add relationships, introduce a canonical DeclarativeBase, create shared mixins, organize a models package, or fix inconsistent SQLAlchemy model structure in a FastAPI or Python backend.
disable-model-invocation: false
---

# Skill: sqlalchemy-models

## Core position

This skill creates **clean, production-ready SQLAlchemy 2.x ORM models**
for Python backend projects.

It enforces disciplined model patterns that prevent common problems such as:

- inconsistent base/model definitions
- broken or asymmetric relationships
- circular imports
- weak typing
- migration-hostile schema definitions
- persistence and API schema concerns getting mixed together

The skill favors **explicit, typed, migration-friendly ORM design** and
ensures model code is:

- SQLAlchemy 2.x native
- typed
- composable
- easy to migrate
- easy to review

------------------------------------------------------------------------

## Goals

Produce a model layer that:

1. Uses **SQLAlchemy 2.x canonical style**
2. Centralizes model infrastructure around a **single DeclarativeBase**
3. Defines columns and relationships with **explicit typing**
4. Organizes models in a **predictable package structure**
5. Avoids **circular import traps**
6. Stays **compatible with Alembic autogenerate**
7. Keeps **ORM models separate from Pydantic/API schemas**

------------------------------------------------------------------------

## Step 0 — Inspect the existing project first

Before generating anything:

1.  Check whether a `models/` package or existing model files already exist. If
    they do, extend the existing structure rather than creating a parallel one.
2.  Note the existing package layout. If the project was scaffolded with
    `fastapi-init`, the package root is `{pkg_name}/{pkg_name}/` — place models
    at `{pkg_name}/models/`, not `app/models/`.
3.  Check whether a `DeclarativeBase` subclass already exists anywhere. If one
    does, adopt it rather than introducing a second base.
4.  Check whether an Alembic `env.py` is present and how it imports
    `Base.metadata` — preserve that import path.
5.  Only create new files if the relevant structure is absent.

------------------------------------------------------------------------

## When to use this skill

Use this skill when the user:

- wants to add SQLAlchemy models to a backend project
- needs to define new ORM entities or relationships
- wants to migrate older SQLAlchemy code to 2.x style
- has inconsistent model layout or imports
- needs timestamp/base mixins
- wants model patterns that work well with FastAPI
- needs the model layer cleaned up before adding Alembic migrations or CRUD routes

------------------------------------------------------------------------

## When not to use this skill

Do not use this skill when:

- the user is asking for Pydantic request/response schemas only
- the user is not using SQLAlchemy
- the task is about Alembic migration authoring rather than model design
- the user explicitly wants a different ORM

------------------------------------------------------------------------

## Non-goals

This skill does **not**:

- invent unrelated tables or domain entities
- generate large CRUD/service layers unless the user asks
- merge ORM models with transport schemas
- introduce async/session architecture changes unless required by the repo
- rewrite the database stack beyond what the current project calls for

------------------------------------------------------------------------

## Required stance

When applying this skill:

- prefer **minimal patches** over broad rewrites
- preserve the repo's existing architectural direction when sane
- standardize on **one canonical model pattern**
- fix root-cause structure issues rather than layering aliases or compatibility shims
- optimize for maintainability, migration safety, and correctness over cleverness

------------------------------------------------------------------------

## Canonical output requirements

A correct solution produced by this skill should usually include:

- a single shared `DeclarativeBase`
- SQLAlchemy 2.x typed fields with `Mapped[...]`
- `mapped_column(...)` for columns
- explicit `relationship(...)` declarations
- symmetric `back_populates` for bidirectional relationships
- a predictable `models/` package structure
- import patterns that avoid circular dependencies
- optional shared mixins only when they reduce duplication cleanly

------------------------------------------------------------------------

## Preferred patterns

### 1) Base class

Prefer a single canonical base:

```python
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
```

Do not create multiple unrelated declarative bases unless the repo already
intentionally uses them.

------------------------------------------------------------------------

### 2) SQLAlchemy 2.x typed columns

Prefer:

```python
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column


email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
```

Avoid legacy untyped declarations like:

```python
email = Column(String, unique=True)
```

unless the repo is explicitly locked to an older SQLAlchemy style and the
user did not ask for modernization.

------------------------------------------------------------------------

### 3) Primary key convention

Default to a simple explicit primary key:

```python
id: Mapped[int] = mapped_column(primary_key=True)
```

Only introduce UUIDs or custom identifiers when the repo already uses them or
there is a clear requirement.

------------------------------------------------------------------------

### 4) Relationship symmetry

Prefer fully paired relationships:

```python
class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="author")


class Post(Base):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    author: Mapped["User"] = relationship(back_populates="posts")
```

Avoid one-sided relationships unless intentionally required.

------------------------------------------------------------------------

### 5) Forward references to reduce import pressure

Prefer string references in relationships when models live in separate files:

```python
posts: Mapped[list["Post"]] = relationship(back_populates="author")
```

This helps avoid circular imports and keeps modules loosely coupled.

------------------------------------------------------------------------

### 6) Explicit nullability and constraints

Be deliberate about nullability, uniqueness, indexes, and defaults.

Prefer model fields that make schema intent obvious.

Do not rely on vague or accidental defaults.

------------------------------------------------------------------------

### 7) Mixins

Use mixins only where they reduce obvious duplication.

Typical good candidates:

- timestamp fields
- soft-delete marker fields
- small shared utility methods

Example:

```python
from datetime import datetime, timezone
from sqlalchemy import DateTime
from sqlalchemy.orm import Mapped, mapped_column


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )
```

Do not add mixins that obscure the real model shape.

------------------------------------------------------------------------

## Package structure

Prefer a predictable model package. Adapt the root to the actual project layout
found in Step 0 — for `fastapi-init` projects this is `{pkg_name}/models/`, for
other layouts it may be `app/models/` or similar.

```text
{pkg_name}/
  models/
    __init__.py
    base.py
    user.py
    post.py
```

Where appropriate:

- `base.py` contains `Base` and small shared mixins
- each entity gets its own module
- `models/__init__.py` should import all model classes so that
  `Base.metadata` is fully populated when Alembic (or any other tool)
  imports it — this is what makes autogenerate reliable

Avoid dumping all models into one huge file once the project has more than a
few entities.

------------------------------------------------------------------------

## Import discipline

Prefer explicit imports.

Good:

```python
from app.models.user import User
from app.models.post import Post
```

Avoid wildcard imports:

```python
from app.models import *
```

Also avoid tangled cross-import chains between model modules.

------------------------------------------------------------------------

## Model vs schema boundary

Keep ORM models and Pydantic schemas separate.

ORM models represent:

- persistence
- relationships
- table structure

Pydantic schemas represent:

- request validation
- response serialization
- transport contracts

Do not collapse both concerns into the same class structure.

------------------------------------------------------------------------

## Alembic compatibility requirements

Model code should be written so Alembic autogenerate can reason about it
cleanly.

Prefer:

- explicit table names
- explicit foreign keys
- explicit constraints where needed
- stable import paths for model metadata discovery

Avoid patterns that obscure metadata registration or hide model definitions.

------------------------------------------------------------------------

## FastAPI integration stance

This skill does not redesign session management unless necessary, but it should
produce model code that fits normal FastAPI backend usage.

Assume the expected separation is:

- model definitions in `models/`
- DB session lifecycle elsewhere
- Pydantic schemas elsewhere
- route/service layers consume ORM models without redefining them

------------------------------------------------------------------------

## Review checklist

Before finishing, verify:

- all models inherit from the same `Base`
- columns use `Mapped[...]` and `mapped_column(...)`
- relationships are typed and symmetric where applicable
- foreign keys are explicit
- `__tablename__` is defined consistently
- imports do not create obvious circular dependency risks
- model files are organized predictably
- ORM models are not mixed with request/response schema logic
- patterns are migration-friendly

------------------------------------------------------------------------

## Common failure modes this skill should prevent

- legacy `Column(...)` style mixed inconsistently with 2.x style
- missing `back_populates`
- broken relationship typing
- circular imports between model files
- multiple competing base classes
- hidden metadata registration issues
- nullable/unique/index behavior implied rather than stated
- putting API serialization concerns directly into ORM model code

------------------------------------------------------------------------

## Execution pattern

When using this skill, the assistant should usually:

1. Inspect the repo's existing DB/model/session conventions
2. Identify the canonical path already present or the smallest sound pattern to add
3. Normalize model definitions toward SQLAlchemy 2.x style
4. Add or clean up base/mixin structure only as much as needed
5. Keep patches compact and easy to review
6. Call out any follow-on work that belongs in adjacent skills

------------------------------------------------------------------------

## Adjacent skills

This skill pairs naturally with others in this plugin and anticipated future
skills. Not all of these exist yet — treat them as integration points, not
dependencies.

- `settings-config` — database URL and other config values come from here
- `pydantic-schemas` — API request/response schemas that mirror (but stay
  separate from) the ORM models
- `alembic-migrations` *(future)* — migration authoring from model metadata
- `crud-route-builder` *(future)* — service/route layer that consumes models
- `pytest-backend` *(future)* — test fixtures that use SQLite in-memory DB

Typical order when building from scratch:

1. `settings-config`
2. `sqlalchemy-models`
3. `pydantic-schemas`
4. `alembic-migrations`
5. `crud-route-builder`

------------------------------------------------------------------------

## Subtle rules

- Prefer **canonical path enforcement**: if the repo already has one clearly intended place for model infrastructure, use it rather than creating a parallel pattern.
- Prefer **minimal patch first**: do not reorganize every model file if a smaller change can establish a clean standard.
- Prefer **verify before hand-off**: sanity-check imports, typing shape, and relationship symmetry before concluding the model layer is correct.

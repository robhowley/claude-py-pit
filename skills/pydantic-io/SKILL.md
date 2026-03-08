---
description: Opinionated schema architecture for Python API projects
  using Pydantic v2. Defines schema taxonomy, base model config, update
  semantics, response envelopes, and serialization rules to prevent
  schema drift in new projects.
disable-model-invocation: false
---

# pydantic-io

Opinionated guidance for designing **API request/response schemas**
using **Pydantic v2** in new Python backend projects.

This skill is optimized for **0→1 API projects** where schema
conventions have not yet been established.\
Its purpose is to prevent **schema drift**, eliminate repeated
architectural decisions, and enforce a consistent API boundary between
domain models and external representations.

This skill **does not teach Pydantic basics**.\
Instead it constrains architectural decisions so the model consistently
generates predictable schema structures.

------------------------------------------------------------------------

# Apply this Skill When

Apply this skill when the user:

-   asks how to structure API schemas
-   asks for request or response models
-   asks about Pydantic models in a FastAPI or API backend
-   is creating a new resource schema
-   is designing pagination or response envelopes
-   is implementing create/update/read models

**Trigger phrases (user language):**

> "add a schema for orders", "how should I structure my Pydantic
> models?", "I need a request body for creating a user", "what's the
> right way to do partial updates?", "how do I return paginated
> results?", "should I use the same model for create and update?"

------------------------------------------------------------------------

# Mission

When this skill is active, the model's job is to **produce or extend
schema code that follows this taxonomy without deviation**, ask no
unnecessary questions, and leave the caller with working, importable
schema classes.

------------------------------------------------------------------------

# Hard Rules

These rules prevent the most common schema mistakes in early-stage API
projects.

**MUST NOT:**

-   Use ORM models as request or response schemas.
-   Reuse a single schema for create, update, and read roles.
-   Accept unknown request fields silently.
-   Apply partial updates from full model dumps.
-   Invent new pagination or envelope formats per endpoint.
-   Place validation or normalization logic in routers when it belongs
    in schema validators.
-   Introduce advanced configuration (alias generators, strict mode,
    etc.) unless explicitly required.
-   Create multiple competing base schema classes without clear
    responsibility boundaries.

If the repository already has established schema conventions, follow
those conventions unless the user asks to refactor toward this
structure.

------------------------------------------------------------------------

# Standard Operating Procedure

**Step 1 — Inspect existing schemas**

Before generating anything, check whether the repo already has a
`schemas/` directory or existing Pydantic models. If it does:

-   Identify the base class in use (if any).
-   Check whether Create/Update/Read roles are already separated.
-   Extend that pattern if it is coherent; do not introduce a parallel
    taxonomy on top of it.
-   Only propose migration toward this skill's taxonomy if the user
    explicitly asks or the existing pattern violates a Hard Rule.

**Step 2 — Generate or extend schemas**

-   If starting fresh: create `schemas/base.py` first, then the
    resource module.
-   If extending: add only the new schema classes needed; do not
    rewrite existing ones without being asked.
-   Apply the taxonomy (`Create`, `Update`, `Read`) and base classes
    from the sections below.
-   Include `model_dump(exclude_unset=True)` usage in the service layer
    whenever an `Update` schema is generated.

**Step 3 — Verify and present**

-   Confirm code is importable with no circular dependencies.
-   Show only the files that changed or were created.
-   Call out any deviation from defaults and why it was made.

------------------------------------------------------------------------

# Default Schema Layout

For new projects schemas SHOULD follow this layout:

```
schemas/
    base.py
    user.py
    order.py
    pagination.py
```

`base.py` defines shared base schema types:

-   APIModel
-   CreateModel
-   UpdateModel
-   ReadModel

Resource schemas should live in their own module (e.g. `schemas/user.py`).

------------------------------------------------------------------------

# Schema Taxonomy

Each resource MUST define separate schema roles.

Example:

```python
class UserCreate(CreateModel):
    ...

class UserUpdate(UpdateModel):
    ...

class UserRead(ReadModel):
    ...
```

Schema roles:

| Schema            | Purpose                  |
|-------------------|--------------------------|
| Create            | Request body for POST    |
| Update            | Partial update payload   |
| Read              | Response serialization   |
| Internal (optional) | Service-layer DTO      |

Rules:

-   ORM models MUST NOT cross the API boundary
-   Read models MUST NOT be reused for input
-   Create models MUST declare required fields explicitly
-   Update models MUST represent partial updates

------------------------------------------------------------------------

# Base Model Configuration

All schemas MUST inherit from a shared base class.

Example:

```python
from pydantic import BaseModel, ConfigDict

class APIModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
        validate_assignment=True,
        use_enum_values=True,
        populate_by_name=True,
    )
```

These defaults enforce:

-   strict request validation
-   consistent whitespace normalization
-   safe mutation in service-layer logic
-   predictable enum serialization

------------------------------------------------------------------------

# Read Model (ORM Serialization)

Response models MUST support serialization from ORM objects.

```python
class ReadModel(APIModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
        validate_assignment=True,
        use_enum_values=True,
        populate_by_name=True,
        from_attributes=True,
    )
```

ORM objects SHOULD be converted using:

```python
UserRead.model_validate(user)
```

Avoid:

-   manual dict conversion
-   returning ORM objects directly
-   mixing serialization logic in routers

------------------------------------------------------------------------

# Create Models

Create models represent **new resource creation**.

Rules:

-   required fields MUST be explicit
-   optional fields SHOULD only be used when necessary
-   defaults belong in the schema, not router logic

Example:

```python
class UserCreate(CreateModel):
    email: EmailStr
    name: str
```

------------------------------------------------------------------------

# Update Models

Update models represent **partial updates**.

Fields SHOULD be optional:

```python
class UserUpdate(UpdateModel):
    name: str | None = None
    email: EmailStr | None = None
```

Updates MUST apply only provided fields:

```python
updates = update.model_dump(exclude_unset=True)

for field, value in updates.items():
    setattr(user, field, value)
```

Full model dumps MUST NOT be used for partial updates.

------------------------------------------------------------------------

# Response Envelopes

APIs SHOULD use a consistent pagination structure.

```python
from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    limit: int
    offset: int
```

Endpoints SHOULD return:

```python
Page[UserRead]
```

Resource-specific pagination types MUST NOT be created unless necessary.

------------------------------------------------------------------------

# Validation Location

Normalization and validation SHOULD live in **Pydantic validators**, not
routers or services.

Example:

```python
@field_validator("email")
def normalize_email(cls, value):
    return value.lower()
```

Routers and services SHOULD assume validated input.

------------------------------------------------------------------------

# Naming Conventions

Schemas MUST follow this naming pattern:

`{Resource}Create`, `{Resource}Update`, `{Resource}Read`

Avoid ambiguous names such as:

-   UserSchema
-   UserDTO
-   UserResponse

Schema names should clearly communicate their role.

------------------------------------------------------------------------

# Completion Checklist

Before responding, verify:

-   [ ] Existing schemas were inspected before generating new ones
-   [ ] Create, Update, and Read roles are separated (no shared schemas)
-   [ ] All schemas inherit from `APIModel` or `ReadModel`
-   [ ] Update logic uses `model_dump(exclude_unset=True)`
-   [ ] No ORM models cross the API boundary
-   [ ] Pagination uses `Page[T]`, not a resource-specific type
-   [ ] No new base classes were introduced without clear purpose
-   [ ] Code shown is importable as written

------------------------------------------------------------------------

# Outcome

Applying this skill ensures:

-   predictable schema architecture
-   strict request validation
-   safe ORM serialization
-   consistent response structures
-   maintainable API evolution

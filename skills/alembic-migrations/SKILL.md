---
name: alembic-migrations
description: Production-safe Alembic migration workflows for SQLAlchemy
  2.x projects. Use this skill when adding Alembic, generating
  migrations, reviewing autogenerate diffs, fixing broken migrations, or
  establishing a safe schema evolution workflow in a Python backend.
disable-model-invocation: false
---

# Skill: alembic-migrations

## Core position

This skill establishes **safe, disciplined database migration
workflows** using **Alembic** in SQLAlchemy 2.x projects.

Autogenerate output is treated as **a draft**, never final truth.
All migrations must be **reviewable, deterministic, and safe for
production.**

The skill prevents common failures such as:

- empty autogenerate revisions
- rename → drop/create data loss
- broken env.py metadata wiring
- migration history divergence
- unsafe schema changes

------------------------------------------------------------------------

# Py-pit enforcement rules

These rules are **always applied** when generating or reviewing
migrations.

## 1. Model import guarantee

Alembic only detects models that are **imported at runtime**.

A canonical module must import every ORM model so metadata is complete.

Do not assume `app/`. Use the project's existing `Base` definition --
typically at `{pkg_name}/db/base.py` (see sqlalchemy-models skill).

Example:

```python
# {pkg_name}/models/__init__.py
from {pkg_name}.models.user import User
from {pkg_name}.models.order import Order
```

Alembic must reference:

```python
from {pkg_name}.db.base import Base

target_metadata = Base.metadata
```

This prevents **empty migrations**, the most common Alembic failure.

------------------------------------------------------------------------

## 2. Rename correction rule

Alembic **cannot detect column renames**.

If autogenerate emits:

```
drop_column
add_column
```

for the same table in one revision, treat it as a **rename**.

Replace with:

```python
op.alter_column("table", "old_name", new_column_name="new_name")
```

This prevents silent data loss.

------------------------------------------------------------------------

## 3. Applied migration immutability

Never edit a migration that has already been applied.

Correct pattern:

```
revision A (applied)
revision B (fix)
```

Never:

```
edit revision A
```

Editing applied migrations breaks migration graphs across environments.

------------------------------------------------------------------------

## 4. Migration round-trip rule

Every migration must succeed on a **fresh database** using:

```
upgrade head
downgrade base
upgrade head
```

This guarantees migrations are:

- replayable
- CI safe
- environment independent

------------------------------------------------------------------------

# Trigger

Use this skill when the user wants to:

- add Alembic to a Python project
- initialize migrations
- generate migration revisions
- review autogenerate diffs
- fix broken migrations
- establish safe schema evolution workflows

------------------------------------------------------------------------

# Migration workflow

Correct workflow:

```
edit models
↓
generate revision
↓
review migration
↓
fix migration
↓
run upgrade
```

Never:

```
generate → immediately run
```

Autogenerate output **must be reviewed before execution**.

------------------------------------------------------------------------

# Step 0 --- Inspect existing project

Before generating anything:

1. Check whether `alembic/`, `alembic.ini`, and `alembic/env.py` already
   exist. If they do, **modify the existing configuration** rather than
   reinitializing. Never run `alembic init` if `alembic/` already exists.
2. Identify where `Base` is defined. If the project used the
   sqlalchemy-models skill, it will be at `{pkg_name}/db/base.py`.
3. Identify which module imports all models (typically
   `{pkg_name}/models/__init__.py`). This is the module env.py must import.
4. Note the existing package root. For fastapi-init projects it is
   `{pkg_name}/{pkg_name}/` -- never assume `app/`.
5. Only create new files if the relevant structure is absent.

------------------------------------------------------------------------

# Step 1 --- Initialize Alembic

If no `alembic/` directory exists, initialize:

```
alembic init alembic
```

Project layout after initialization:

```text
project/
  alembic/
    env.py
    versions/
  alembic.ini
```

------------------------------------------------------------------------

# Step 2 --- Configure database connection

Leave `sqlalchemy.url` in `alembic.ini` blank or as a placeholder.
Provide the URL at runtime via the application's settings system.

Example in `env.py`:

```python
from {pkg_name}.core.config import settings

DATABASE_URL = settings.database_url
```

This pattern defers to the settings-config skill and avoids embedding
credentials in version-controlled files.

------------------------------------------------------------------------

# Step 3 --- Configure env.py for SQLAlchemy 2.x

Provide a minimal complete `env.py`. Replace `{pkg_name}` with the
actual package name found in Step 0.

```python
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from {pkg_name}.core.config import settings
from {pkg_name}.db.base import Base
import {pkg_name}.models  # noqa: F401 — ensures all models are imported

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

**Naming conventions**: The naming convention is defined on `Base` in
`db/base.py` (see sqlalchemy-models skill) and is picked up
automatically by Alembic through `target_metadata = Base.metadata`.

**Async note**: Alembic migrations run synchronously even in async
applications.

------------------------------------------------------------------------

# Step 4 --- Generate migrations

Create a migration revision:

```
alembic revision --autogenerate -m "add users table"
```

Migration files appear in:

```
alembic/versions/
```

------------------------------------------------------------------------

# Step 5 --- Review migration output

Review the migration carefully before running it.

Check for:

- rename mis-detections
- destructive column drops
- type conversion safety
- nullable constraint changes
- missing indexes or constraints

Autogenerate is **a starting point, not a final migration.**

------------------------------------------------------------------------

# Step 6 --- Apply migration

Apply migrations:

```
alembic upgrade head
```

Inspect state:

```
alembic current
```

View revision history:

```
alembic history
```

------------------------------------------------------------------------

# Migration safety heuristics

Carefully review migrations involving:

- column drops
- table drops
- type changes
- nullability changes
- constraint removal
- index removal

These operations require deliberate review.

------------------------------------------------------------------------

# Anti-patterns

Avoid:

- Blind autogenerate upgrades
- Empty migrations caused by missing model imports
- Hardcoded database URLs
- Editing already-applied migrations

------------------------------------------------------------------------

# Adjacent skills

This skill typically follows:

- `sqlalchemy-models` — establishes `Base`, model package structure, and
  the import module that env.py must reference
- `settings-config` — establishes the `settings` object and
  `database_url` that env.py uses for the connection string

------------------------------------------------------------------------

# Outcome

After applying this skill the project will have:

- correctly wired Alembic configuration
- reliable SQLAlchemy metadata discovery
- disciplined migration workflows
- safer schema evolution
- deterministic revision history

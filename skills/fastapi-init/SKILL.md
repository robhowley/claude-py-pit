---
name: fastapi-init
description: Scaffold a complete, production-ready FastAPI project from scratch. Use this skill whenever the user wants to create, initialize, start, or bootstrap a FastAPI service, REST API, or Python web service — even if they just say "new service", "new API", or "new microservice". Handles uv setup, standard FastAPI directory layout, uvicorn runner, click CLI entry point, and a full pytest suite with DI overrides, TestClient, and SQLite fixtures. Always invoke for new Python API projects.
disable-model-invocation: false
---

# fastapi-init

Scaffold a new FastAPI project end-to-end. This skill coordinates with others in the plugin — invoke them at the right steps rather than reinventing what they already encode.

## Prerequisite skills

- **uv skill**: use for all `uv add`, `uv run`, and environment commands — never fall back to pip
- **click-cli skill**: consult if the user wants an extended CLI beyond the basic server entry point
- **fastapi-errors skill**: the authority on the full error architecture — domain subclasses, error codes, auth error patterns, and existing-repo strategy

---

## Step 1 — Confirm the service name

Ask: **"What's the name of this service?"**

Use a single snake_case variable `{pkg_name}` for everything — the project directory, the Python package, the `pyproject.toml` name, and the CLI command (e.g. `my_service`). The `uv run {pkg_name} serve` command will use it directly. Derive `{PkgName}` as the PascalCase form of `{pkg_name}` (e.g. `my_service` → `MyService`) — used only for the exception class name.

---

## Step 2 — Initialize with uv

```bash
uv init {pkg_name} --app --no-workspace
cd {pkg_name}
```

Remove the stub file uv generates (`hello.py`), then add dependencies:

```bash
uv add fastapi "uvicorn[standard]" sqlalchemy "pydantic-settings" click
uv add --dev pytest pytest-asyncio httpx
```

After `uv init`, add the hatchling build backend to `pyproject.toml` so `[project.scripts]` works:

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["{pkg_name}"]
```

---

## Step 3 — Directory structure

Build this layout under the project root:

```
{pkg_name}/
├── pyproject.toml
├── uv.lock
├── {pkg_name}/                         ← Python package, same name as project root
│   ├── __init__.py
│   ├── main.py                # FastAPI app + lifespan
│   ├── cli.py                 # click entry point
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py          # pydantic-settings Settings
│   │   └── exceptions.py      # {PkgName}Error base + usage note
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py            # shared Annotated Depends providers
│   │   └── v1/
│   │       ├── __init__.py
│   │       └── routes/
│   │           ├── __init__.py
│   │           └── health.py
│   ├── db/
│   │   ├── __init__.py
│   │   └── session.py         # engine + SessionLocal + get_db
│   ├── models/
│   │   └── __init__.py        # SQLAlchemy declarative models
│   └── schemas/
│       ├── __init__.py
│       └── base.py            # APIModel + ReadModel base schemas
└── tests/
    ├── __init__.py
    ├── conftest.py
    └── api/
        └── v1/
            ├── __init__.py
            └── test_health.py
```

---

## Step 4 — File templates

### pyproject.toml

After `uv init`, add these sections (the build-system block from Step 2 plus):

```toml
[project.scripts]
{pkg_name} = "{pkg_name}.cli:cli"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

### {pkg_name}/core/config.py

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="{PKG_NAME}_", env_file=".env")

    app_name: str = "{pkg_name}"
    debug: bool = False
    database_url: str = "sqlite:///./app.db"


settings = Settings()
```

### {pkg_name}/db/session.py

`get_db` is the single canonical source of truth for database sessions in routes and tests — this is what makes DI overrides in tests work cleanly. Background tasks run outside the FastAPI DI lifecycle and must open sessions via `SessionLocal` directly.

```python
from datetime import datetime, timezone
from typing import Generator

from sqlalchemy import DateTime, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

from {pkg_name}.core.config import settings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow,
    )


engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(bind=engine)


def get_db() -> Generator[Session, None, None]:
    with SessionLocal() as session:
        yield session
```

### {pkg_name}/api/deps.py

```python
from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from {pkg_name}.db.session import get_db

DbSession = Annotated[Session, Depends(get_db)]
```

Use `DbSession` as a type annotation on route parameters — it's self-documenting and avoids repeating `Depends(get_db)` everywhere.

### {pkg_name}/core/exceptions.py

Base class with `status_code` and `detail` as class-level defaults, overridable per-instance. Subclasses only need to override the class attributes — no `__init__` boilerplate needed.

```python
class {PkgName}Error(Exception):
    status_code: int = 500
    detail: str = "An unexpected error occurred."

    def __init__(self, detail: str | None = None, status_code: int | None = None, **context):
        self.detail = detail if detail is not None else self.__class__.detail
        self.status_code = status_code if status_code is not None else self.__class__.status_code
        self.context = context
```

Example subclass:
```python
class NotFoundError({PkgName}Error):
    status_code = 404
    detail = "Resource not found."
```

See the **fastapi-errors** skill for the full error architecture: domain subclasses, error codes, auth error patterns, and existing-repo strategy.

### {pkg_name}/schemas/base.py

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


class ReadModel(APIModel):
    model_config = APIModel.model_config.copy()
    model_config["from_attributes"] = True
```

### {pkg_name}/main.py

Use the lifespan pattern — `on_event` is deprecated.

```python
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from {pkg_name}.api.v1.routes import health
from {pkg_name}.core.config import settings
from {pkg_name}.core.exceptions import {PkgName}Error


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup: run migrations, warm caches, etc.
    yield
    # shutdown: close connections, flush buffers, etc.


app = FastAPI(title=settings.app_name, lifespan=lifespan)
app.include_router(health.router, prefix="/api/v1")


# see fastapi-errors skill for extended patterns (context logging, error codes, auth errors)
@app.exception_handler({PkgName}Error)
async def {pkg_name}_error_handler(request: Request, exc: {PkgName}Error) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(status_code=422, content={"detail": "Invalid request data", "details": exc.errors()})


@app.exception_handler(Exception)
async def unexpected_error_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(status_code=500, content={"detail": "An unexpected error occurred."})
```

### {pkg_name}/api/v1/routes/health.py

```python
from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check():
    return {"status": "ok"}
```

### {pkg_name}/cli.py

```python
import click
import uvicorn

from {pkg_name}.core.config import settings


@click.group()
def cli():
    """{pkg_name} service CLI."""


@cli.command()
@click.option("--host", default="0.0.0.0", show_default=True, help="Bind host.")
@click.option("--port", default=8000, show_default=True, type=int, help="Bind port.")
@click.option("--reload", is_flag=True, default=settings.debug, help="Enable hot reload.")
def serve(host: str, port: int, reload: bool):
    """Start the uvicorn server."""
    uvicorn.run("{pkg_name}.main:app", host=host, port=port, reload=reload)
```

---

## Step 5 — Test setup

### tests/conftest.py

The test suite is built around three layered fixtures. The design principle: never hit a real database, never reach outside the process, override DI at the boundary.

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from {pkg_name}.db.session import Base, get_db
from {pkg_name}.main import app

TEST_DATABASE_URL = "sqlite:///:memory:"


@pytest.fixture(scope="session")
def engine():
    """One engine for the whole test session — schema created once.

    Assumes serial execution (no pytest-xdist). For parallel workers, switch to
    a file-based SQLite (e.g. sqlite:///tmp/test_{worker_id}.db) or a per-worker engine.
    """
    eng = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(eng)
    yield eng
    Base.metadata.drop_all(eng)


@pytest.fixture
def db_session(engine) -> Session:
    """Per-test transaction that always rolls back — tests never bleed into each other."""
    connection = engine.connect()
    transaction = connection.begin()
    TestSession = sessionmaker(bind=connection)
    session = TestSession()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session: Session) -> TestClient:
    """TestClient with the real DB dependency swapped for the test SQLite session."""
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
```

### tests/api/v1/test_health.py

```python
from fastapi.testclient import TestClient


def test_health_returns_ok(client: TestClient):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

---

## Test invariants

Hold these across every test file in the project:

1. **No test classes** — top-level `test_*` functions only; pytest fixtures handle all setup and teardown
2. **No real databases** — all DB-touching tests use the `db_session` fixture; SQLite in-memory only
3. **DI overrides, not patches** — swap behavior via `app.dependency_overrides`; don't mock internals
4. **Shared fixtures in conftest.py** — test files stay clean; fixtures go in conftest
5. **Transaction-per-test isolation** — the rollback in `db_session` ensures tests never affect each other even if they write data

---

## Step 6 — Verify the scaffold

```bash
uv run pytest
uv run {pkg_name} serve --help
```

Both should succeed with no errors before handing the project to the user.

---

## What's next

The scaffold is ready to extend. Common next steps:

- **Add models** - use the `sqlalchemy-models` skill to define ORM entities under `models/`
- **Initialize migrations** - use the `alembic-migrations` skill to set up Alembic after adding models
- **Add schemas** - use the `pydantic-schemas` skill for request/response schemas beyond the base classes

---

## Completion checklist

- [ ] `[project.scripts]` entry in pyproject.toml points to `{pkg_name}.cli:cli`
- [ ] `asyncio_mode = "auto"` set in `[tool.pytest.ini_options]`
- [ ] hatchling build backend present with `packages = ["{pkg_name}"]`
- [ ] `get_db` is the single source of truth for DB sessions — routes and tests both go through it
- [ ] `app.dependency_overrides` is cleared after every test fixture that sets it
- [ ] No test touches a real database, network socket, or Docker container
- [ ] All test functions are top-level — no test classes
- [ ] `{PkgName}Error` base class present in `core/exceptions.py` and handler registered in `main.py`
- [ ] `uv run pytest` passes from the project root

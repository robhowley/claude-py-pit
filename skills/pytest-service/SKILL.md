---
description: Write disciplined backend tests for FastAPI services with pytest. Use
  this skill when adding tests to a Python/FastAPI service, setting up SQLAlchemy
  test fixtures, wiring TestClient with DI overrides, mocking external clients, or
  improving test maintainability. Covers fixture design, factory patterns, SQLite
  in-memory databases, app.dependency_overrides, and avoiding fragile or redundant
  tests.
disable-model-invocation: false
---

# Skill: pytest-service

## Core position

This skill establishes **clean, reliable backend testing using pytest**.

The goal is to produce tests that are:

-   fast
-   deterministic
-   easy to read
-   easy to extend
-   free of infrastructure dependencies

Tests should **optimize for scanability and maintainability**, not
clever abstractions.

## Core testing stance

Prefer **simple local tests with minimal infrastructure**.

Rules:

-   Prefer **`TestClient`** for FastAPI endpoint tests whenever possible
-   Use **async clients only when the test genuinely requires async behavior**
-   Default test databases to **SQLite via SQLAlchemy fixtures**
-   Do **not introduce Docker databases** unless the repository already uses them for testing
-   External clients must be **mocked**, not called
-   **No test classes** — top-level `test_*` functions only; fixtures handle all setup
-   Each test covers a **distinct behavior** — no redundant assertions across tests
-   Avoid mutable default arguments in fixtures and helpers

Tests must run reliably with a simple `pytest`. No external services required.

## Project structure

Tests should live in a `tests/` directory.

    tests/
      conftest.py
      test_health.py
      test_users.py
      factories/
        user_factory.py

-   `conftest.py` holds shared fixtures
-   test files mirror application modules when possible
-   factory fixtures may live in `tests/factories/` or `conftest.py`

## Fixture discipline

Shared setup belongs in **pytest fixtures**, not duplicated code.

-   Use `@pytest.fixture` for reusable setup
-   Inspect existing fixtures **before creating new ones**
-   Prefer **composing fixtures** instead of duplicating setup logic
-   Keep fixture responsibilities narrow and clearly named

Avoid inline setup repeated across tests.

## Fixture scope

Choose fixture scope based on what the fixture creates and how expensive it is.

-   `scope="session"` — for things that are expensive to create and safe to share (e.g., the SQLAlchemy engine, schema creation)
-   `scope="function"` (default) — for anything that holds mutable state or must be isolated per test (e.g., sessions, clients, mocks)

A common pattern: session-scoped engine, function-scoped session with rollback.

``` python
@pytest.fixture(scope="session")
def engine():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(eng)
    yield eng
    Base.metadata.drop_all(eng)


@pytest.fixture
def db_session(engine) -> Session:
    connection = engine.connect()
    transaction = connection.begin()
    TestSession = sessionmaker(bind=connection)
    session = TestSession()
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

The rollback in teardown means tests never bleed into each other even when they write data.

## Factory fixtures

Use **factory fixtures** when tests require variations of objects. Factories are appropriate for sample data, request payloads, ORM objects, mocked clients, and service configurations — not just data.

``` python
@pytest.fixture
def user_payload_factory():
    def _factory(**overrides):
        payload = {
            "email": "test@example.com",
            "name": "Test User",
        }
        payload.update(overrides)
        return payload

    return _factory
```

## Avoid branching logic in fixtures

Fixtures should configure objects, not contain decision trees.

Bad:

``` python
if status == "ok":
    client.charge.return_value = ...
elif status == "declined":
    ...
```

Good:

``` python
@pytest.fixture
def payment_client_factory():
    def _factory(charge_response=None):
        charge_response = charge_response or {"status": "ok"}

        client = MagicMock(spec=PaymentClient)
        client.charge.return_value = charge_response
        return client

    return _factory
```

Tests should control behavior explicitly rather than relying on fixture branching.

## FastAPI dependency overrides

Use **`app.dependency_overrides`** to swap FastAPI dependencies in tests. Do not patch internals directly.

``` python
@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
```

Always clear `dependency_overrides` in teardown so overrides don't leak between tests.

## FastAPI testing

Prefer `TestClient` for endpoint tests.

``` python
def test_health_endpoint(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
```

## External client mocking

External services must be mocked.

-   use `MagicMock(spec=ClientType)` or `create_autospec`
-   do not make real network calls in unit tests
-   assert the application's behavior, not the external service behavior

Shared mock setups should be implemented as **fixtures or factory fixtures**.

## Parametrization

Use pytest parametrization when only inputs vary.

``` python
@pytest.mark.parametrize(
    "email",
    [
        "user@example.com",
        "admin@example.com",
    ],
)
def test_email_validation(email):
    ...
```

## Deterministic time and data

Tests should not depend on the system clock or random values. Freeze time with `freezegun`; use explicit, stable inputs rather than `uuid4()` or `random`.

``` python
@freeze_time("2025-01-01")
def test_token_expiry():
    ...
```

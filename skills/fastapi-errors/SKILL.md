---
description: Opinionated error architecture for FastAPI services. Enforces a single internal exception hierarchy, constructor-based messages, consistent API error responses, and centralized logging for unexpected failures.
disable-model-invocation: false
---

# fastapi-errors

Defines a **simple, consistent error architecture** for FastAPI backend services.

This skill standardizes the flow:

```text
service/domain failure
→ application exception
→ global FastAPI exception handler
→ consistent JSON response
```

The goal is to prevent common FastAPI problems:

- `HTTPException` raised deep in service logic
- inconsistent error response formats
- duplicated status code logic
- domain failures implemented with builtin exceptions
- unexpected exceptions leaking poor diagnostics

---

# Apply this Skill When

Apply when the user:

- asks how to structure FastAPI error handling
- is adding domain exceptions
- is designing service-layer failures
- is implementing API error responses
- is building a new FastAPI service
- is adding new domain errors in an existing repo

Do **not** apply when:

- the task is unrelated to application error handling
- the user explicitly wants a different architecture

---

# Base Exception

The service defines one base exception for intentional application failures.

Preferred naming pattern:

```text
<PackageName>Error
```

Examples:

```text
BillingError
UserServiceError
InventoryError
```

If the package name cannot be determined, use:

```text
AppError
```

Define all exceptions in a single module — `errors.py` or `exceptions.py` at the package root. Do not scatter them across feature files.

Example base implementation:

```python
class AppError(Exception):
    status_code = 500

    def __init__(self, message: str | None = None, **context):
        self.message = message or "Unhandled application error"
        self.context = context
        super().__init__(self.message)

    def __str__(self) -> str:
        return self.message
```

Key characteristics:

- default HTTP status = **500**
- default message provided in the constructor
- optional context data for logging
- subclasses override `status_code` or pass formatted messages

---

# Domain Exception Pattern

Application/domain errors should subclass the base error.

Example:

```python
class UserNotFoundError(AppError):
    status_code = 404

    def __init__(self, user_id: int):
        super().__init__(f"User {user_id} not found", user_id=user_id)
```

Example usage in service code:

```python
if user is None:
    raise UserNotFoundError(user_id)
```

---

# Global FastAPI Exception Handler

The API boundary converts internal exceptions into HTTP responses.

Example:

```python
@app.exception_handler(AppError)
async def handle_app_error(request: Request, exc: AppError):
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": str(exc)},
    )
```

Response format is intentionally simple:

```json
{
  "error": "User 123 not found"
}
```

---

# Unexpected Exception Handling

Unexpected exceptions should be handled consistently.

Use a fallback handler for uncaught exceptions:

```python
@app.exception_handler(Exception)
async def handle_unexpected_error(request: Request, exc: Exception):
    wrapped = AppError()

    logger.exception(
        "Unhandled exception",
        extra={
            "path": str(request.url.path),
            "method": request.method,
            "error_type": type(exc).__name__,
        },
    )

    return JSONResponse(
        status_code=wrapped.status_code,
        content={"error": str(wrapped)},
    )
```

This does three things:

- preserves a stable client-facing response
- ensures unexpected failures are logged centrally
- treats uncaught exceptions consistently through the base application-error contract

Do not leak raw internal exception details to clients.

Log at minimum: request path, HTTP method, exception type, and correlation ID if the repo uses one. Follow existing structured logging conventions if present.

---

# Existing Repository Strategy

In existing repositories, **inspect current error patterns before introducing new ones**.

Follow these rules:

- Look for an existing internal base exception.
- If one exists and is coherent, **extend it instead of creating a new base class**.
- Integrate with existing exception handlers when possible.
- Only introduce the recommended base-exception pattern if the repo lacks a clear contract or the user asks to refactor.

Do **not** create parallel exception hierarchies in a mature codebase.

---

# Validation Errors

FastAPI raises `RequestValidationError` for malformed or invalid request bodies. This is framework-level — it does not subclass your app's base exception. Without a handler, FastAPI emits its default 422 response with a raw Pydantic error blob, which breaks response shape consistency.

Add a dedicated handler:

```python
from fastapi.exceptions import RequestValidationError

@app.exception_handler(RequestValidationError)
async def handle_validation_error(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={"error": "Invalid request data", "details": exc.errors()},
    )
```

Including `exc.errors()` in a `details` field is recommended — validation errors are client-fixable and surfacing them helps the caller correct the request.

---

# Auth Errors

Auth handling involves two distinct cases. Don't conflate them.

**FastAPI security dependencies** (`HTTPBearer`, `OAuth2PasswordBearer`, `Depends(security_scheme)`, etc.) raise `HTTPException` internally. This is expected framework behavior — do not fight it or try to wrap it in domain exceptions.

**Custom auth logic** (token validation, permission checks) belongs in service code and should use domain exceptions:

```python
class UnauthenticatedError(AppError):
    status_code = 401

    def __init__(self):
        super().__init__("Authentication required")


class UnauthorizedError(AppError):
    status_code = 403

    def __init__(self, action: str | None = None):
        msg = f"Not authorized to {action}" if action else "Not authorized"
        super().__init__(msg)
```

These flow through the global `AppError` handler like any other domain exception.

---

# Error Codes (Optional)

For APIs consumed by clients that need to branch on error type — public APIs, client SDKs, multi-error workflows — a machine-readable `code` field is useful. Skip this for internal services or simple CRUD APIs where string parsing is acceptable.

Pattern: add an optional `code` class attribute to the base exception; domain subclasses override it.

```python
class AppError(Exception):
    status_code = 500
    code: str | None = None  # add this
    ...

class UserNotFoundError(AppError):
    status_code = 404
    code = "user_not_found"  # subclasses set a value
    ...
```

Update the global handler to include `code` when present:

```python
@app.exception_handler(AppError)
async def handle_app_error(request: Request, exc: AppError):
    content = {"error": str(exc)}
    if exc.code:
        content["code"] = exc.code
    return JSONResponse(status_code=exc.status_code, content=content)
```

Response shape when `code` is set:

```json
{
  "error": "User 123 not found",
  "code": "user_not_found"
}
```

---

# Hard Rules

**MUST**

- Define a single internal base exception for application failures.
- Subclass that base exception for domain errors.
- Declare `status_code` on exception classes.
- Handle the internal exception hierarchy in one global FastAPI handler.
- Return a consistent JSON error response.
- Log unexpected exceptions centrally in the fallback handler.
- Add a `RequestValidationError` handler when response shape consistency matters.

**MUST NOT**

- Raise `HTTPException` in service or domain code. Exception: `HTTPException` raised internally by FastAPI security dependencies (`HTTPBearer`, `OAuth2PasswordBearer`, etc.) is acceptable — that is the framework's designed behavior.
- Use builtin exceptions (`ValueError`, `RuntimeError`, etc.) for intentional domain failures.
- Invent new error response formats per endpoint.
- Duplicate HTTP status logic outside the exception classes.
- Introduce a second application error hierarchy when one already exists.
- Leak raw internal exception messages or stack traces to clients.

---

# Outcome

Applying this skill results in:

- one coherent application error hierarchy
- clear separation between service failures and HTTP responses
- consistent API error responses
- centralized logging for true unexpected failures
- predictable error handling across the entire service

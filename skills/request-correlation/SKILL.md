---
name: request-correlation
description: Enforce end-to-end request correlation across HTTP handlers,
  services, outbound HTTP calls, background jobs, and async tasks using
  contextvars. Use this skill whenever request tracing, correlation IDs,
  observability wiring, or propagating context across task/job boundaries
  is involved — even outside FastAPI (Celery workers, CLI tasks, plain
  asyncio apps). Ensures correlation IDs propagate across boundaries and
  exceptions are logged exactly once.
disable-model-invocation: false
---

# Skill: request-correlation

## Core stance

Every request or job must produce a **traceable log story**.

A single **correlation ID** must propagate through:

-   HTTP handlers
-   service functions
-   outbound HTTP calls
-   background jobs and async tasks

The correlation ID must appear automatically in logs.

**Infrastructure vs. convention:** Some rules are wired once at app startup
(middleware, logging config, HTTP client factory). Others are conventions
followed everywhere (raise don't log in services, never pass correlation as
a function argument). Keep them separate in your mental model -- the
infrastructure makes the conventions effortless.

## Canonical locations

Correlation infrastructure must live in predictable modules.

Use:

app/observability/correlation.py\
app/observability/logging.py

Do not duplicate correlation logic elsewhere.

## Rules

**1. Wire correlation at entrypoints**

Entrypoints include HTTP requests, background job workers, CLI tasks, and
async task roots.

For HTTP requests, use a functional middleware to read `x-request-id` if
present, otherwise generate one, then set it into context:

``` python
import uuid
from fastapi import Request
from app.observability.correlation import correlation_id

@app.middleware("http")
async def correlation_middleware(request: Request, call_next):
    cid = request.headers.get("x-request-id") or str(uuid.uuid4())
    correlation_id.set(cid)
    response = await call_next(request)
    response.headers["x-request-id"] = cid
    return response
```

Prefer `@app.middleware("http")` over `BaseHTTPMiddleware` — the class-based
approach can swallow exceptions and interfere with streaming responses.

For job workers and CLI entrypoints, set `correlation_id` before executing
the task -- either from a passed value or a freshly generated one.

**2. Store correlation in `contextvars`**

Correlation must live in a `contextvars.ContextVar`.

Never store it on request objects or pass it through every function
argument.

Example:

``` python
from contextvars import ContextVar

correlation_id: ContextVar[str | None] = ContextVar("correlation_id", default=None)
```

**3. Inject correlation into all log records**

Logging configuration must automatically attach the correlation ID.

Example:

``` python
class CorrelationFilter(logging.Filter):
    def filter(self, record):
        record.correlation_id = correlation_id.get()
        return True
```

Log format must include it (use structured/JSON output if the project
already does):

    %(levelname)s [cid=%(correlation_id)s] %(message)s

**4. Log exceptions only at boundaries**

Exceptions are logged exactly once at system boundaries:

-   HTTP exception handlers
-   job worker wrapper
-   CLI entrypoint

Service functions should raise errors but **not log them**. Log calls
inside service internals to "track" correlation add noise without value --
the boundary log with the shared correlation ID tells the whole story.

**5. Propagate correlation to outbound HTTP calls**

All outbound HTTP clients must include the correlation ID.

Example:

``` python
headers={"x-request-id": correlation_id.get()}
```

Centralize HTTP client creation so headers are applied automatically.

**6. Propagate correlation to background jobs**

If a request schedules a queue-based job, pass the correlation ID
explicitly.

Example:

``` python
queue.enqueue(task, correlation_id=correlation_id.get())
```

The worker must restore it before executing the task.

**7. Be explicit about context propagation for spawned async tasks**

Do not assume task boundaries preserve correlation in every execution
model. Use `copy_context()` as the safe pattern:

``` python
import contextvars
import asyncio

ctx = contextvars.copy_context()
loop.run_in_executor(None, ctx.run, task)
# or for coroutines:
asyncio.get_running_loop().call_soon(ctx.run, task)
```

This applies the same principle as Rule 6 -- correlation must be
deliberately carried across any execution boundary, not assumed to be
inherited.

**8. Never log secrets**

Never log:

-   authorization headers
-   tokens
-   passwords
-   cookies
-   session IDs

## Success signal

A request should produce logs that share one correlation ID:

    INFO request.start cid=abc123 path=/orders
    INFO http.outbound cid=abc123 service=payments
    ERROR request.failed cid=abc123 error=PaymentError

One request → one correlation ID → one coherent trace.

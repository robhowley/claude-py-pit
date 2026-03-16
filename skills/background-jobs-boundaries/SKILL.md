---
name: background-jobs-boundaries
description: Guardrails for background work in FastAPI and Python services. Prevent misuse of in-process background execution (e.g. FastAPI BackgroundTasks).
disable-model-invocation: false
---

# Skill: background-jobs-boundaries

## Core stance

In-process background tasks are **best-effort follow-ups**, not job infrastructure.

Use them only for **small, fast, non-critical work** after a request completes.

---

## Do not use background tasks when the work is:

- long-running
- business-critical
- requires retries
- requires durability
- must run exactly once

These require a **real job system**.

---

## Hard rules

- Never pass `Request`, DB sessions, ORM objects, or DI state.
- Persist domain state **before** triggering background work.
- Do not implement retry logic inside tasks.
- Do not spawn threads or `asyncio.create_task()` inside handlers.
- Pass **IDs or payloads**, reload resources inside the task.

---

## Acceptable uses

Small follow-up work such as:

- email
- analytics
- cache invalidation
- webhooks
- audit logging

Tasks must be **fast, idempotent, and failure-tolerant**.

---

## Correct shape

Background tasks should accept **identifiers or simple payloads only**
and load resources inside the task itself.

Example pattern:

```python
from fastapi import BackgroundTasks

@app.post("/users/{user_id}/welcome")
def send_welcome(user_id: int, background_tasks: BackgroundTasks):
    background_tasks.add_task(send_welcome_email, user_id)
    return {"status": "scheduled"}


def send_welcome_email(user_id: int):
    with SessionLocal() as session:
        user = session.get(User, user_id)
        if not user:
            return

        email_service.send_welcome(user.email)
```

Key properties:

- Task arguments are **IDs or primitives**
- The task **opens its own DB session**
- The task is **idempotent and failure-tolerant**
- Failures **must not affect request behavior**
- No retry logic is implemented inside the task

---

## Summary

Background tasks are **best-effort helpers**.

If the work must be **reliable or durable**, use a **real queue or job system**.

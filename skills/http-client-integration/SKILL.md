---
name: http-client-integration
description: Production-ready async HTTP client integration for Python backend services. Use this skill when adding or refactoring outbound API calls, building a vendor client, introducing retries and timeouts, validating external payloads, or replacing ad-hoc HTTP usage with a disciplined integration boundary.
---

# Skill: http-client-integration

## Core position

Treat external HTTP APIs as **infrastructure boundaries**, not ad-hoc utility calls.

This skill creates a **centralized async integration layer** using `httpx.AsyncClient`, explicit timeout policy, `tenacity`-based retries, typed payload validation, structured error mapping, and testable client design.

The goal is not merely to make a request, but to make outbound HTTP calls **safe, observable, reusable, and easy to test**.

## Inspect first

Before changing code, inspect the repo for:

- Existing HTTP client patterns or a shared base client
- Dependency injection or app lifecycle conventions
- Existing configuration patterns for base URLs, timeouts, retries, and credentials
- Logging, metrics, tracing, and error-handling conventions
- Existing tests and mocking style for integrations

Reuse the repo's established patterns when they are sound. Do not introduce a second HTTP client architecture without a clear reason.

## Core rules

- Put outbound HTTP calls behind a dedicated client or integration module
- Use `httpx.AsyncClient`, not `requests` or sync clients in async apps
- Reuse a managed client instance; do not create a fresh client per call
- Vendor clients should be constructed once during application startup or service initialization and reused rather than instantiated at call sites
- Manage AsyncClient lifecycle using the application's startup/lifespan mechanism rather than module-level globals
- Always configure explicit timeouts
- Use `tenacity` for retries; do not hand-roll retry loops
- Retry only transient failures and only idempotent operations by default
- Validate external payloads into typed schemas before broader app use
- Map upstream failures into domain-specific integration errors
- Log and instrument at the integration boundary without leaking secrets
- Keep auth, base URL, headers, and user agent construction centralized
- Make the integration layer easy to mock in tests
- Fail clearly on malformed upstream data
- Source timeout values, retry counts, base URLs, and credentials from application configuration, not hardcoded constants

## Preferred structure

When the repo already has a sound shared base client, reuse it.

When the repo has multiple integrations or repeated transport concerns, factor common behavior into a **small base client**. Keep vendor clients thin and focused on endpoint methods, payload validation, and domain mapping.

### Base client owns

- Shared `httpx.AsyncClient`
- Timeout configuration
- Retry wrapper
- Request sending
- Common logging / instrumentation
- Shared error translation helpers
- Centralized auth / header hooks

### Vendor client owns

- Endpoint paths
- Query / body construction
- Response schema validation
- Vendor-specific status handling
- Domain mapping methods such as `get_entity()` or `get_entities()`

Do not build a large framework for a single simple integration. Prefer the smallest structure that cleanly enforces the boundary.

## Canonical shapes

```python
class BaseHttpClient:
    async def get(...): ...
    async def post(...): ...
    def validate(...): ...
```

```python
class EntitiesClient(BaseHttpClient):
    async def get_entity(self, entity_id: str) -> Entity: ...
    async def get_entities(self, ids: list[str]) -> list[Entity]: ...
```

```python
timeout = httpx.Timeout(
    connect=settings.http_connect_timeout,
    read=settings.http_read_timeout,
    write=settings.http_write_timeout,
    pool=settings.http_pool_timeout,
)
```

```python
async for attempt in AsyncRetrying(
    stop=stop_after_attempt(settings.http_retry_attempts),
    wait=wait_exponential_jitter(initial=settings.http_retry_base, max=settings.http_retry_max),
):
    with attempt:
        response = await self._request_once(...)
```

```python
response = await self._request_with_retry(...)
payload = self.validate(response, EntityPayload)
return self._to_domain(payload)
```

## Retry policy

- Retry transport errors, timeouts, and selected 5xx failures
- Do not retry most `4xx` responses (`400`, `401`, `403`, `404`)
- Treat `429 Too Many Requests` as a special case: retry only with deliberate backoff and respect `Retry-After` when provided
- Prefer bounded exponential backoff with jitter
- Wrap only the transport call in retry logic, not response parsing or schema validation
- Prefer explicit status handling over `raise_for_status()` when integrations require domain error mapping

## Must not

- Must not perform outbound HTTP inline in routes, services, or helpers
- Must not use `requests` in async services
- Must not instantiate `AsyncClient` per request
- Must not instantiate vendor clients at call sites
- Must not hand-roll retry loops
- Must not pass raw JSON beyond the integration boundary unless it is the explicit contract

## Testing stance

- Unit tests should mock the integration layer or transport boundary
- Prefer `respx` or `httpx.MockTransport`
- Do not make real network calls in unit tests
- Test timeout, retry, non-retry, malformed payload, and upstream-error behavior


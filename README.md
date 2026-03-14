# py-pit

![version](https://img.shields.io/github/v/tag/robhowley/py-pit-skills)

Opinionated Python backend workflows for Claude Code.

`py-pit` encodes common backend development workflows as Claude/Pi skills for the modern Python API stack: FastAPI services, uv environments, SQLAlchemy models, Alembic migrations, configuration management, and CLI tooling.

## Install

### Claude Code

Add the plugin marketplace, then install py-pit:

```
/plugin marketplace add robhowley/py-pit-skills
/plugin install py-pit@py-pit-skills
```

### pi

Install from npm:

```bash
pi install npm:@robhowley/py-pit-skills
```

Or directly from GitHub:

```bash
pi install https://github.com/robhowley/py-pit-skills
```

## Skills

| Skill                | Activates when LLM detects                                                              |
|----------------------|--------------------------------------------------------------------------------------------|
| `fastapi-init`       | new FastAPI service, scaffold an API, new microservice                                     |
| `uv`                 | dependency management, lockfiles, env setup, migration from pip/poetry                     |
| `click-cli`          | designing or generating a new Click CLI                                                    |
| `click-cli-linter`   | auditing or improving an existing Click CLI                                                |
| `pydantic-schemas`   | request/response schema design, Pydantic v2 models, schema patterns                        |
| `code-quality`       | linting setup, Ruff, pre-commit, code health tooling                                       |
| `dockerize-service`  | local dev Docker Compose setup, containerizing a project                                   |
| `settings-config`    | environment variable management, pydantic-settings, replacing os.getenv                    |
| `sqlalchemy-models`  | ORM model design, SQLAlchemy 2.x patterns, relationships, migration-ready schema           |
| `alembic-migrations` | adding Alembic, generating migrations, reviewing autogenerate diffs, safe schema evolution |
| `fastapi-errors`     | FastAPI error handling, exception hierarchy, consistent API error responses                 |
| `pytest-service`     | writing tests for a FastAPI service, SQLAlchemy test fixtures, DI overrides, test setup    |


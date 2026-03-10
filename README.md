# py-pit

Claude Code plugin for Python backend development with FastAPI, uv workflows, and Click CLI tooling.

Provides Claude skills for common Python backend tasks that automatically activate when relevant work is detected in your repository.

## Install

Add the plugin marketplace, then install py-pit:

```
/plugin marketplace add robhowley/claude-py-pit
/plugin install py-pit@claude-py-pit
```

## Skills

| Skill             | Trigger on                                                             |
| ----------------- | ---------------------------------------------------------------------- |
| fastapi-init      | new FastAPI service, scaffold an API, new microservice                 |
| uv                | dependency management, lockfiles, env setup, migration from pip/poetry |
| click-cli         | designing or generating a new Click CLI                                |
| click-cli-linter  | auditing or improving an existing Click CLI                            |
| pydantic-schemas  | request/response schema design, Pydantic v2 models, schema patterns    |
| code-quality      | linting setup, Ruff, pre-commit, code health tooling                   |
| docker-compose    | local dev Docker Compose setup, containerizing a project               |
| settings-config   | environment variable management, pydantic-settings, replacing os.getenv |


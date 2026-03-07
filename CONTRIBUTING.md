# Contributing

## PR Titles

PR titles must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification. This is enforced by CI and drives automatic version bumping on merge to main.

### Format

```
<type>[optional scope][optional !]: <description>
```

### Types and version impact

| Type | Description | Version bump |
|------|-------------|--------------|
| `feat` | New feature | minor |
| `feat!` | Breaking change | major |
| `fix` | Bug fix | patch |
| `docs` | Documentation only | patch |
| `chore` | Maintenance, dependencies | patch |
| `refactor` | Code restructure, no behavior change | patch |
| `test` | Adding or updating tests | patch |
| `ci` | CI/CD changes | patch |
| `perf` | Performance improvement | patch |
| `style` | Formatting, whitespace | patch |
| `build` | Build system changes | patch |
| `revert` | Revert a previous commit | patch |

### Examples

```
feat: add fastapi-init skill
fix: correct uv run command in skill prompt
feat!: rename {app_name} variable to {pkg_name}
docs: update contributing guide
chore: upgrade uv version in check script
```

A breaking change can also be indicated by including `BREAKING CHANGE` in the PR description, which will also trigger a major bump.

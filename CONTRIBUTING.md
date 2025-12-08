# Contributing

Thanks for your interest in contributing! This project demonstrates deploying Azure Policy via Bicep and GitHub Actions. Please follow these guidelines to keep contributions consistent and easy to review.

## Prerequisites
- Azure CLI (`az`) with Bicep support (`az bicep version`).
- GitHub account with access to this repo.
- Access to an Azure tenant/subscription suitable for testing (RBAC scoped appropriately).

## Development Setup
- Clone the repo and explore:
  - `bicep/` for templates/modules and parameters
  - `policies/` for policy definitions and initiatives
  - `.github/workflows/templates/deploy-template.yaml` for deployment flow
- Validate builds locally:
```zsh
./scripts/test-build.sh
```
- Prepare parameters if needed:
```zsh
./scripts/prep-params.sh
```

## Branching and Commits
- Create a feature branch from `main`: `feature/<short-topic>` or `fix/<short-topic>`.
- Write clear commit messages using imperative style, e.g., `Add initiative for location restrictions`.
- Keep changes focused; avoid unrelated refactors.

## Code Style and Structure
- Bicep modules: prefer small, composable modules under `bicep/modules/`.
- Policy JSON: keep definitions under `policies/custom-policy-definitions/`, initiatives under `policies/custom-policy-initiatives/`.
- Parameters: avoid secrets in repo; reference environment-specific files (`*.bicepparam`, `*.parameters.json`).
- Scripts: keep cross-platform where feasible; for PowerShell scripts, set `$ErrorActionPreference = 'stop'`.

## Policy Authoring Tips
- Use `loadTextContent()` sparingly; large JSON policy rules should be validated and linted.
- Prefer explicit module references rather than attempting dynamic folder enumeration (Bicep limitation).
- Document parameter intent and default values.

## Tests and Validation
- Run local compile checks before opening a PR:
```zsh
az bicep build --file bicep/main.bicep --outfile compiled/main.json
```
- If you add policy files, validate JSON schema and policy aliases.

## Pull Requests
- Describe the change, scope, and any inputs required (e.g., `az_deployment_type`, `location`).
- Include screenshots or CLI output for test deployments if applicable.
- Ensure CI passes (artifact creation, compile, lint if configured).

## CI/CD Notes
- The reusable workflow logs in to Azure via OIDC; no secrets should be committed.
- The deployment step expects exactly one `*.parameters.json` in the `deploy/` artifact; if you need multiple environments, publish separate artifacts.

## Reporting Issues
- Provide steps to reproduce, relevant logs, and scope (tenant/mg/sub/rg).
- Note any environment differences (Azure location, subscription, RBAC).

## License
By contributing, you agree that your contributions will be licensed under the MIT License.

# Azure Policy Engine Bicep

A concise, repeatable workflow to define, package, and deploy Azure Policy assets (custom policy definitions, initiatives, assignments, and exemptions) using Bicep and GitHub Actions with OIDC. Making policy-as-code easier to manage across multiple scopes and environments.

**Highlights**
- Organized policy sources under `policies/` (custom + built-in examples).
- Modular Bicep for definitions, initiatives, assignments, and exemptions.
- CI/CD via reusable GitHub Actions workflow and OIDC authentication.
- Works across tenant, management group, subscription, and resource group scopes.

## Quickstart

- Prerequisites:
  - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) with Bicep support.
  - GitHub account with access to this repo.
  - Azure tenant/subscription for testing.
  - (Optional) Install `envsubst` for parameter preparation. Already comes with latest ubuntu/macOS.
  -  For local development, ensure you are logged in to the target Azure tenant:
  ```zsh
  az login --tenant "<TENANT_ID>"
  ```
  - Ensure the target Management Group / Subscription exists and you have sufficient RBAC permissions.

- Add your policy files and configs:
  - Custom policy definitions: add JSON files under `policies/custom-policy-definitions/` (e.g., `definition.function.app.https.only.json`).
  - Custom initiatives: add JSON under `policies/custom-policy-initiatives/` (e.g., `locations-initiative.json`).
  - Built-in initiatives: reference or place example JSON under `policies/builtin-policy-initiatives/` (e.g., `example.json`).
  - Remediation templates: edit `policies/policy-remediations/policy-remediations.jsonc` as needed.
  - Parameters/configs: use `bicep/main.parameters.json` (generate from `bicep/main.parameters.json.tmpl`) and `bicep/policy-exemption.bicepparam` for environment-specific values.

- Build Bicep to ARM JSON (using make):
```zsh
make build
make whatif
```

- Deploy (subscription scope example):
```zsh
az account set --subscription "<SUBSCRIPTION_ID>"
az deployment sub create \
  --name "deploy_policy" \
  --location "westeurope" \
  --template-file compiled/main.json \
  --parameters @bicep/main.parameters.json
```

## Concepts
- **Policy Assets:** JSON files for custom definitions and initiatives, plus assignments and exemptions modeled via Bicep.
- **Modules:** Bicep modules compose policy resources and can be reused per environment/scope.
- **Parameters:** Environment-specific values provided via `bicep/main.parameters.json` or `.bicepparam`.
- **Scopes:** Deploy at `tenant`, `managementgroup`, `subscription`, or `resourcegroup` using the corresponding `az deployment` command.
- **CI/CD:** A reusable workflow builds, prepares artifacts, authenticates via OIDC, and deploys.

## Repository Layout
- `bicep/`: Core templates and modules
  - `main.bicep`, `bicepconfig.json`, `main.parameters.json(.tmpl)`
  - `modules/`: `deploy-custom-initiative.bicep`, `deploy-custom-policy-definition.bicep`, `deploy-policy-assignment.bicep`, `deploy-policy-exemption.bicep`, `policy-exemption-resource.bicep`
- `compiled/`: Compiled ARM JSON (`main.json`)
- `policies/`: Policy sources
  - `custom-policy-definitions/`, `custom-policy-initiatives/`, `builtin-policy-initiatives/`, `policy-remediations/`
- `scripts/`: Helpers (`prep-params.sh`, `test-build.sh`, `policy-remediations.ps1`)
- `.github/workflows/templates/deploy-template.yaml`: Reusable deployment workflow
- `Makefile`: Convenience tasks

## Workflow Overview
```
Edit policies (JSON) + Bicep modules
            |
            v
      Build (bicep -> json)
            |
            v
 Prepare parameters/artifacts (scripts)
            |
            v
 Publish deployable artifact (template + params)
            |
            v
 GitHub Actions: OIDC login to Azure
            |
            v
 Select scope: tenant | mg | sub | rg
            |
            v
  run what-if to validate (optional)
            |
            v
   az deployment <scope> create
            |
            v
 Policy defs/initiatives/assignments/exemptions
            |
            v
 Optional: Remediations (policy-remediations)
```

## Tools: Parameter Preparation (`scripts/prep-params.sh`)
This helper prepares `bicep/main.parameters.json` from `bicep/main.parameters.json.tmpl` by discovering policy files under `policies/`, aggregating them into JSON arrays, and substituting environment-driven variables.

- **What it does:**
  - Scans `policies/` subfolders (one level deep) for `*.json`.
  - Aggregates per group based on `DEPLOY_*` flags and exports `*_CONTENTS` arrays.
  - Copies template to `bicep/main.parameters.json` and applies selective `envsubst` based on `ENV_PATTERNS`.
- **Usage:**
```zsh
zsh scripts/prep-params.sh \
  --policy-dir ./policies \
  --file-extension .json \
  --output-param-file ./bicep/main.parameters.json
```
- **Flow:**
```
policies/* -> collect -> group/filter -> aggregate JSON -> copy template -> envsubst -> bicep/main.parameters.json
```
- **Notes:** Requires `envsubst`; template must exist; ensure valid JSON files.

## GitHub Actions Workflow Inputs
- `environment`: GitHub environment (e.g., `policy`, `staging`).
- `location`: Azure location for tenant/mg/sub deployments.
- `subscription_id`: Subscription used for sub/rg deployments.
- `template_file_name`: Base template name (e.g., `main.bicep`).
- `deployment_name`: Name of the Azure deployment operation.
- `az_deployment_type`: `tenant` | `managementgroup` | `subscription` | `resourcegroup`.
- `management_group_id`: Required for management group scope.
- `resource_group_name`: Required for resource group scope.
- `oidc_app_reg_client_id`, `azure_tenant_id`: OIDC configuration.

## Technical Details
- **Modules:**
  - `deploy-custom-policy-definition.bicep`: Creates/updates custom policy definitions.
  - `deploy-custom-initiative.bicep`: Groups policies with parameters.
  - `deploy-policy-assignment.bicep`: Assigns policies/initiatives at scope.
  - `deploy-policy-exemption.bicep`, `policy-exemption-resource.bicep`: Exemptions.
- **Parameterization:** Values provided via JSON/`.bicepparam` reused across scopes.
- **Authentication:** `azure/login@v2` with OIDC (no long-lived secrets).

## Limitations and Notes
- Bicep cannot dynamically import folders; use explicit modules or pre-build generation.
- Large JSON rules may need `loadTextContent()` and proper escaping.
- `.bicepparam` for env values; CI resolves env names/branches.
- Workflow assumes a single parameters file per artifact.
- Ensure correct scope and provider registrations.
- 
## Troubleshooting
- when you get the following error:
  - "The content for this response was already consumed" => Run `az deployment <scope> what-if` first to validate before create.
- OIDC login: verify GitHub federation in Azure AD app registration.
- Wrong scope: check `az_deployment_type` and required IDs.
- Parameter mismatches: align template schema and parameters.
- Bicep errors: run `az bicep build` or `scripts/test-build.sh`.

## Security and Compliance
- No secrets in repo; use GitHub environments/Azure Key Vault.
- Least privilege for the OIDC service principal.
  
## Future Improvements (TODOs)
- Support reading env variables from .env files instead of hardcoding in scripts.
- Enhance policy remediation script for more scenarios.
- Add linting/validation for policy JSON files in CI.
- Expand examples for different scopes/environments.
- Improve documentation with more detailed walkthroughs.

## CONTRIBUTING
See `CONTRIBUTING.md` for guidelines.

## License
MIT License — see `LICENSE`.

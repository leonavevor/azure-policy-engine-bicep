# Quickstart

## Purpose

A compact, copy-pasteable quickstart to build and deploy the Azure Policy Engine Bicep project for azure cloud environments. This file assumes a technician who has CLI access and RBAC permissions to the target tenant/management group/subscription/resource group.

## Prerequisites (Linux / zsh)

- OS & shell
  - Tested on Linux (Ubuntu/Debian/CentOS) with zsh/bash. Commands below assume a POSIX shell (zsh shown in examples).

- Azure CLI with Bicep support
  - Check: `az --version`
  - Ensure the CLI has Bicep available (either via `az bicep` or a standalone bicep binary)
  - Install / update (Debian/Ubuntu example):

```zsh
# Install/update Azure CLI (Debian/Ubuntu example)
# See https://learn.microsoft.com/cli/azure/install-azure-cli for other platforms
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# Ensure Bicep tooling is available via az
az bicep install || az bicep upgrade
```

- jq (for JSON sanity checks)
  - Check: `jq --version`
  - Install (Debian/Ubuntu): `sudo apt-get update && sudo apt-get install -y jq`

- envsubst (from gettext) — used by `scripts/prep-params.sh`
  - Check: `envsubst --version` (or `envsubst --help`)
  - Install (Debian/Ubuntu): `sudo apt-get update && sudo apt-get install -y gettext-base`

- GNU make
  - Check: `make --version`
  - Install (Debian/Ubuntu): `sudo apt-get update && sudo apt-get install -y make`

- Git and repository checkout
  - Check: `git --version`

- Required RBAC / permissions
  - You must have sufficient RBAC at the target scope to create policy definitions, initiatives, assignments, exemptions, and (optionally) management groups.
  - Typical roles: `Owner` or `Policy Contributor` + `Contributor` at the target scope. For tenant-level operations, a Global Administrator and appropriate Azure AD consent may be required for some automation.

- Optional / recommended
  - `az account management-group show` requires permission to read management groups; creating management groups requires appropriate management group RBAC.
  - For CI (GitHub Actions) ensure the identity (service principal / federated credential) has the same RBAC at the deployment target and that OIDC is configured if using `azure/login@v2`.


## Quick setup

1. Login to Azure and set the tenant/subscription you will use:

```zsh
az login --tenant "<TENANT_ID>"
az account set --subscription "<SUBSCRIPTION_ID>"
```

2. Verify management group (if deploying to MG scope):

```zsh
az account management-group show --name "<MG_ID>"
# If it doesn't exist, create it (requires appropriate permissions):
# az account management-group create --name "<MG_ID>" --display-name "My MG"
```

Note: creating or performing a what-if against management groups is a separate operation from deploying policies (see below). The policy deployment steps in this guide assume target management groups already exist. If you need to create management groups as part of your rollout, run the management-group creation/what-if steps before executing the policy deployment commands or CI jobs.

### Parameter preparation (optional, since it is auto handled when using make build)

This repo uses template parameter files. Prepare `bicep/main.parameters.json` (and `bicep/mg.parameters.json` if desired) using the included helper which aggregates JSON policy files under `policies/`.

```zsh
# from repo root
scripts/prep-params.sh \
  --policy-dir ./policies \
  --file-extension .json \
  --output-param-file ./bicep/main.parameters.json

# Verify the files were created
ls -l bicep/main.parameters.json bicep/mg.parameters.json
jq . bicep/main.parameters.json | head -n 40
```

Note: `bicep/main.parameters.json.tmpl` and `bicep/mg.parameters.json.tmpl` are the templates. `bicep/policy-exemption.bicepparam` contains optional exemption values.

MG parameter precedence: if `policies/mg.parameters.json` exists, it is copied to `bicep/mg.parameters.json` as-is and no templating/defaults are applied. If it does not exist, defaults from `.default.envs` are used to render `bicep/mg.parameters.json` from the template.

Build (Bicep -> compiled ARM template)

```zsh
# Build compiled/main.json
make build
# Dry-run what-if
make whatif

# Output
# compiled/main.json  <-- use this file for az deployment commands
```

### Deploy examples (zsh) — use the appropriate scope

Tenant scope

```zsh
az deployment tenant create \
  --name "deploy_policy_tenant" \
  --location "westeurope" \
  --template-file compiled/main.json \
  --parameters @bicep/main.parameters.json
```

Management group scope

```zsh
az.deployment mg create \
  --name "deploy_policy_mg" \
  --location "westeurope" \
  --management-group-id "<MG_ID>" \
  --template-file compiled/main.json \
  --parameters @bicep/main.parameters.json
```

Subscription scope

```zsh
az deployment sub create \
  --name "deploy_policy_sub" \
  --location "westeurope" \
  --template-file compiled/main.json \
  --parameters @bicep/main.parameters.json
```

Resource group scope

```zsh
az deployment group create \
  --resource-group "<RG_NAME>" \
  --name "deploy_policy_rg" \
  --template-file compiled/main.json \
  --parameters @bicep/main.parameters.json
```

Notes on parameters

- If you have a `.bicepparam` file for exemptions, pass it with `--parameters @bicep/policy-exemption.bicepparam` in addition to `@bicep/main.parameters.json` or merge into a single parameters file.
- For large policy JSON rules, the templates may use `loadTextContent()`; ensure values are valid JSON strings.

Management group nested creation (create-mg)

This repo includes a convenience Make target and a Bicep module to create management groups in a nested structure.

- Prepare a parameters file `bicep/mg.parameters.json` (generated from `bicep/mg.parameters.json.tmpl`). The file should contain `managementGroupNamesToCreate` as an array of objects with keys `name`, optional `displayName`, and optional `parent`.
- Order matters: list parents before their children inside the array when creating both in the same deployment.

Important: separation of concerns — management groups vs policy deployment

Example parameter file (repo includes `bicep/mg.parameters.json`):

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "creatManagementGroups": { "value": true },
    "managementGroupNamesToCreate": {
      "value": [
        { "name": "mg-corp", "displayName": "Corp", "parent": "mg-landing-zones" },
        { "name": "mg-online", "displayName": "Online", "parent": "mg-corp" }
      ]
    },
    "parentManagementGroupName": { "value": "mg-landing-zones" }
  }
}
```

- Management group creation/what-if is separate from policy deployment.
  - Why: management group operations modify the tenant-level management group hierarchy and often require different permissions (tenant-level or management-group RBAC) than policy authoring/assignment operations.
  - When to run: if your deployment needs new management groups, run `make create-mg` (or the `az deployment mg` call below) and verify success before running policy deployments that target those groups.
  - What-if vs policy what-if: use `az deployment mg what-if` to preview changes to the management-group hierarchy (Bicep `mg.bicep`), and use `az deployment <scope> what-if` against the compiled policy template (`compiled/main.json`) to preview policy assignments/definitions. They are distinct operations.

Example commands (run these before policy deployments if you will create MGs):
# Deploy management groups

```zsh  
make create-mg debugEnabled=false
```

If you prefer to call `az` directly, use:

```zsh
az deployment mg what-if --name "whatif-mg" --location westeurope --management-group-id "<MG_ID>" --template-file bicep/mg.bicep --parameters @bicep/mg.parameters.json
```


Permissions note

- Management group creation typically requires higher privileges (e.g., `Owner` at the tenant root or `Management Group Contributor` on the parent management group). Policy deployment (definitions/assignments) may be performed by `Policy Contributor`/`Contributor` depending on scope.
- In azure cloud environments these differences are more sensitive: ensure your operator identity (user or service principal) has the correct RBAC and that any cross-tenant or privileged operations are planned and approved.

Common troubleshooting

- envsubst not found -> install `gettext-base` (Ubuntu/Debian): `sudo apt-get install -y gettext-base`.
- Permission denied / 403 -> verify your service principal or user has required RBAC at target scope.
- "The content for this response was already consumed" -> retry with debug to get detailed logs:
  - `az deployment <scope> create ... --debug`
- Template/parameter mismatch -> validate compiled template and parameters:
  - `az deployment sub validate --template-file compiled/main.json --parameters @bicep/main.parameters.json`
- Large JSON rules failing -> ensure files are valid JSON and encoded correctly. Use `jq . file.json` to validate.

Quick pre-deploy checklist (copy/paste)

```zsh
# 1. Logged in and correct tenant/subscription
az account show
# 2. params file exists
test -f bicep/main.parameters.json || echo "Run scripts/prep-params.sh"
# 3. build compiled template
make build || (echo "make build failed"; exit 1)
# 4. validate template (subscription example)
az deployment sub validate --template-file compiled/main.json --parameters @bicep/main.parameters.json || echo "Validation failed"
```
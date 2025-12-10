## **2025-12-09**

- **Prep script: smarter defaults**: Apply defaults only when corresponding `*_CONTENTS` is empty; respect deploy flags unless `--force-defaults`.
- **Template-driven placeholders**: Detect `${VAR}` directly from `bicep/main.parameters.json.tmpl` instead of fixed patterns, ensuring variables like `CUSTOM_POLICY_INITIATIVES_CONTENTS` are substituted.
- **JSON-safe empty contents**: When `*_CONTENTS` remains empty after defaults, set to `[]` to keep `bicep/main.parameters.json` valid.
- **Default envs support**: Auto-load `.default.envs` from repo root when `--defaults-env` is not provided; still supports `--defaults-env` override and JSON defaults file.
- **Safer logging**: Final variable resolution output no longer relies on `printenv`, avoiding failures under `set -e` for unset vars.
- **Verification**: `make deploy` succeeds; parameters resolve correctly with placeholders replaced and arrays valid.
 
Files impacted:
- `scripts/prep-params.sh` (logic updates for defaults, placeholder detection, JSON handling, logging)
- `bicep/main.parameters.json` (generated output now consistently valid JSON)

## **2025-12-10**

### Commits
- `9c26fc3` — fix default envs to work as expected
	- **Changes**: `.default.envs`, `.gitignore`, `Makefile`, `bicep/main.bicep`, `bicep/main.parameters.json`, `bicep/main.parameters.json.tmpl`, `scripts/prep-params.sh`
	- **Notes**: Align default env handling with parameters template; ensure generated parameters stay valid.

- `6fe868a` — improved MG creation module with array outputs
	- **Changes**: `README.md`, `bicep/main.bicep`, `bicep/modules/create-management-groups.bicep`
	- **Notes**: Management group module now returns arrays for downstream consumption.

- `4775d3d` — intergrated mg create into main also
	- **Changes**: `Makefile`, `bicep/main.bicep`
	- **Notes**: Wired the MG creation into main orchestration.

- `a399581` — add mg creation module
	- **Changes**: `.default.envs`, `Makefile`, `README.md`, `bicep/main.parameters.json`, `bicep/mg.bicep`, `bicep/modules/create-management-groups.bicep`, `bicep/modules/deploy-custom-policy-definition.bicep`, `policies/custom-policy-initiatives/locations-initiative.json`
	- **Notes**: Introduced MG creation and related scaffolding.

### Fixes
- **Policy assignment parameters**: Updated `bicep/main.bicep` to pass initiative `assignmentParameters` (values) to policy assignments instead of the parameter schema. Prevents `InvalidRequestContent: Could not find member 'type'...` errors.
- **Outcome**: `properties.parameters` serialize correctly as `{ parameterName: { value: ... } }`.

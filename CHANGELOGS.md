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

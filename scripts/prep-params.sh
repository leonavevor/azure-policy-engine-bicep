#!/usr/bin/env bash

# Purpose: Prepare/Parse policy definition and initiative files into Bicep parameter files. NOTE: This script requires 
set -euo pipefail

POLICY_DIR="${POLICY_DIR:-./policies}"
FILE_EXTENSION="${FILE_EXTENSION:-.json}"
OUTPUT_PARAM_FILE="${OUTPUT_PARAM_FILE:-./bicep/main.parameters.json}"
TEMPLATE_PARAM_FILE="${OUTPUT_PARAM_FILE}.tmpl"

# Patterns to match environment variables for substitution
ENV_PATTERNS=("_POLICY_" "_SOME_ENV_")

export DEPLOY_CUSTOM_POLICY_DEFINITIONS=true
export DEPLOY_CUSTOM_POLICY_INITIATIVES=true
export ASSIGN_CUSTOM_POLICY_INITIATIVES=true
export ASSIGN_BUILTIN_POLICY_INITIATIVES=true

declare -A DEPLOY_FLAGS=(
    [BUILTIN_POLICY_INITIATIVES]="${DEPLOY_BUILTIN_POLICY_INITIATIVES:-true}"
    [CUSTOM_POLICY_DEFINITIONS]="${DEPLOY_CUSTOM_POLICY_DEFINITIONS:-true}"
    [CUSTOM_POLICY_INITIATIVES]="${DEPLOY_CUSTOM_POLICY_INITIATIVES:-true}"
)

usage() {
    echo "Usage: $0 [--policy-dir <path>] [--file-extension <ext>] [--output-param-file <path>] [--defaults-env <path>] [--defaults-json <path>] [--force-defaults]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --policy-dir)        POLICY_DIR="${2:-}"; shift 2;;
        --file-extension)    FILE_EXTENSION="${2:-}"; shift 2;;
        --output-param-file) OUTPUT_PARAM_FILE="${2:-}"; TEMPLATE_PARAM_FILE="${OUTPUT_PARAM_FILE}.tmpl"; shift 2;;
        --defaults-env)      DEFAULTS_ENV_PATH="${2:-}"; shift 2;;
        --defaults-json)     DEFAULTS_JSON_PATH="${2:-}"; shift 2;;
        --force-defaults)    FORCE_DEFAULTS=true; shift 1;;
        -h|--help)           usage;;
        *)                   echo "Unknown option: $1" >&2; usage;;
    esac
done

sanitize() { echo "${1//[^a-zA-Z0-9]/_}"; }

collect_policy_files() {
    local category_dir event files=()
    while IFS= read -r -d '' event; do
        files+=("$event")
    done < <(find "$1" -type f -name "*$FILE_EXTENSION" -print0)
    printf '%s\0' "${files[@]}"
}

declare -A CATEGORY_FILE_EXPORTS

while IFS= read -r -d '' CATEGORY_DIR; do
    category="$(basename "$CATEGORY_DIR")"
    safe_name="$(sanitize "$category")"
    mapfile -d '' files < <(collect_policy_files "$CATEGORY_DIR")
    ((${#files[@]})) || continue

    var_name="${safe_name^^}_FILES"
    joined="$(printf '%s,' "${files[@]}")"
    joined="${joined%,}"
    export "$var_name=$joined"
    CATEGORY_FILE_EXPORTS["$var_name"]="$joined"
done < <(find "$POLICY_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

aggregate_policy_group() {
    local group="$1" deploy="${DEPLOY_FLAGS[$group]}"
    local files_var="${group}_FILES"
    local contents_var="${group}_CONTENTS"
    local files_string="${!files_var:-}"

    if [[ "${deploy,,}" != "true" || -z "$files_string" ]]; then
        unset "$contents_var"
        return
    fi

    IFS=',' read -ra file_list <<< "$files_string"
    local aggregated=()
    for file in "${file_list[@]}"; do
        [[ -f "$file" ]] && aggregated+=("$(<"$file")")
    done
    ((${#aggregated[@]})) || { unset "$contents_var"; return; }

    printf -v "$contents_var" '[%s]' "$(IFS=','; echo "${aggregated[*]}")"
    export "$contents_var"
}

for group in "${!DEPLOY_FLAGS[@]}"; do
    aggregate_policy_group "$group"
done

# Load defaults from env-style file
# Priority: --defaults-env > repo .default.envs > none
if [[ -z "${DEFAULTS_ENV_PATH:-}" ]]; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    DEFAULTS_ENV_PATH="$REPO_ROOT/.default.envs"
fi
if [[ -n "${DEFAULTS_ENV_PATH:-}" ]]; then
    if [[ -r "$DEFAULTS_ENV_PATH" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$DEFAULTS_ENV_PATH"
        set +a
        echo "Loaded defaults env: $DEFAULTS_ENV_PATH" >&2
    else
        echo "Info: defaults env file not readable or missing: $DEFAULTS_ENV_PATH" >&2
    fi
fi

# Load defaults from JSON file if provided (expects keys matching *_CONTENTS) using jq if available
declare -A JSON_DEFAULTS
if [[ -n "${DEFAULTS_JSON_PATH:-}" ]]; then
    if [[ -r "$DEFAULTS_JSON_PATH" ]]; then
        if command -v jq >/dev/null 2>&1; then
            while IFS=$'\t' read -r k v; do
                JSON_DEFAULTS["$k"]="$v"
            done < <(jq -r 'to_entries[] | select(.value != null) | "\(.key)\t\(.value)"' "$DEFAULTS_JSON_PATH")
        else
            echo "Warning: jq not found; skipping JSON defaults parsing for $DEFAULTS_JSON_PATH" >&2
        fi
    else
        echo "Warning: defaults JSON file not readable: $DEFAULTS_JSON_PATH" >&2
    fi
fi

apply_default_if_empty() {
    local var_name="$1" deploy_flag="$2"
    # Respect deploy flag unless FORCE_DEFAULTS
    if [[ "${deploy_flag,,}" != "true" && "${FORCE_DEFAULTS:-false}" != true ]]; then
        return
    fi

    local current_value="${!var_name-}"
    if [[ -n "$current_value" ]]; then
        return
    fi

    local default_env_name="DEFAULT_${var_name}"
    local default_value="${!default_env_name-}"

    if [[ -z "$default_value" ]]; then
        default_value="${JSON_DEFAULTS[$var_name]:-}"
    fi

    if [[ -n "$default_value" ]]; then
        printf -v "$var_name" '%s' "$default_value"
        export "$var_name"
    fi
}

[[ -f "$TEMPLATE_PARAM_FILE" ]] || { echo "Template $TEMPLATE_PARAM_FILE not found" >&2; exit 1; }
cp "$TEMPLATE_PARAM_FILE" "$OUTPUT_PARAM_FILE"

declare -a policy_vars=()
declare -A seen_policy_vars=()
# Extract placeholders from the output param file content: ${VAR}
while IFS= read -r line; do
    while [[ $line =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
        var_name="${BASH_REMATCH[1]}"
        [[ -n "${seen_policy_vars[$var_name]:-}" ]] || {
            policy_vars+=("$var_name")
            seen_policy_vars["$var_name"]=1
        }
        # strip first match and continue scanning the rest of the line
        line="${line#*\${${var_name}}}"
    done
done < "$OUTPUT_PARAM_FILE"

# Apply defaults just before substitution
# 1) For each *_CONTENTS, apply its default only if empty.
for group in "${!DEPLOY_FLAGS[@]}"; do
    contents_var="${group}_CONTENTS"
    apply_default_if_empty "$contents_var" "${DEPLOY_FLAGS[$group]}"
    # Ensure JSON validity: if still empty, default to an empty array
    if [[ -z "${!contents_var-}" ]]; then
        printf -v "$contents_var" '[]'
        export "$contents_var"
    fi
done

# 2) For each policy var used in envsubst, only apply its respective default
#    if the related *_CONTENTS for its group is empty. We infer the group by
#    substring matching the var name with the group key.
for name in "${policy_vars[@]}"; do
    # Skip if already has a value
    if [[ -n "${!name-}" ]]; then
        continue
    fi
    matched_group=false
    for group in "${!DEPLOY_FLAGS[@]}"; do
        if [[ "$name" == *"$group"* ]]; then
            matched_group=true
            contents_var="${group}_CONTENTS"
            if [[ -z "${!contents_var-}" ]]; then
                apply_default_if_empty "$name" "${DEPLOY_FLAGS[$group]}"
            fi
            break
        fi
    done
    # If no group match, still attempt to apply a DEFAULT_<VAR> or JSON default
    if [[ "$matched_group" == false ]]; then
        apply_default_if_empty "$name" true
    fi
done

if ((${#policy_vars[@]})); then
    vars="$(printf '$%s ' "${policy_vars[@]}")"
    envsubst "$vars" < "$OUTPUT_PARAM_FILE" > "${OUTPUT_PARAM_FILE}.tmp"
else
    cp "$OUTPUT_PARAM_FILE" "${OUTPUT_PARAM_FILE}.tmp"
fi

mv "${OUTPUT_PARAM_FILE}.tmp" "$OUTPUT_PARAM_FILE"

printf 'Resolved policy variables (from template placeholders):\n'
if ((${#policy_vars[@]})); then
    for name in "${policy_vars[@]}"; do
        printf '%s=%s\n' "$name" "${!name-}"
    done
else
    printf '  (none found)\n'
fi
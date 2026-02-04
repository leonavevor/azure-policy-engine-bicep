#!/usr/bin/env bash

# Purpose: Prepare/Parse policy definition and initiative files into Bicep parameter files. NOTE: This script requires 
set -xeuo pipefail

POLICY_DIR="${POLICY_DIR:-./policies}"
FILE_EXTENSION="${FILE_EXTENSION:-.json}"
OUTPUT_PARAM_FILE="${OUTPUT_PARAM_FILE:-./bicep/main.parameters.json}"
TEMPLATE_PARAM_FILE="${OUTPUT_PARAM_FILE}.tmpl"
MG_OUTPUT_PARAM_FILE="${MG_OUTPUT_PARAM_FILE:-./bicep/mg.parameters.json}"
MG_TEMPLATE_PARAM_FILE="${MG_TEMPLATE_PARAM_FILE:-${MG_OUTPUT_PARAM_FILE}.tmpl}"
MG_PARAMS_FILE_EXISTS=false
MG_USE_EXISTING_MG_PARAMS=false
[[ -f "$MG_OUTPUT_PARAM_FILE" ]] && MG_PARAMS_FILE_EXISTS=true

# Patterns to match environment variables for substitution
ENV_PATTERNS=("_POLICY_" "_")

# Moved to .default.envs
# Default deployment flags (can be overridden via environment variables)
# export DEPLOY_CUSTOM_POLICY_DEFINITIONS=true
# export DEPLOY_CUSTOM_POLICY_INITIATIVES=true
# export ASSIGN_ALL_POLICY_INITIATIVES=true

DEFAULTS_FILE_PATH="${DEFAULTS_ENV:-./.default.envs}"
if [[ -r "$DEFAULTS_FILE_PATH" ]]; then
    # Safely source defaults: auto-export and temporarily allow unset references
    set -a
    set +u
    source "$DEFAULTS_FILE_PATH"
    set -u
    set +a
else
    echo "Defaults file not found or unreadable: $DEFAULTS_FILE_PATH" >&2
fi

declare -A DEPLOY_FLAGS=(
    [BUILTIN_POLICY_INITIATIVES]="${ASSIGN_BUILTIN_POLICY_INITIATIVES:-true}"
    [CUSTOM_POLICY_DEFINITIONS]="${DEPLOY_CUSTOM_POLICY_DEFINITIONS:-true}"
    [CUSTOM_POLICY_INITIATIVES]="${DEPLOY_CUSTOM_POLICY_INITIATIVES:-true}"
)

usage() {
    echo "Usage: $0 [--policy-dir <path>] [--file-extension <ext>] [--output-param-file <path>] [--mg-output-param-file <path>] [--mg-template-param-file <path>]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --policy-dir)        POLICY_DIR="${2:-}"; shift 2;;
        --file-extension)    FILE_EXTENSION="${2:-}"; shift 2;;
        --output-param-file) OUTPUT_PARAM_FILE="${2:-}"; TEMPLATE_PARAM_FILE="${OUTPUT_PARAM_FILE}.tmpl"; shift 2;;
        --mg-output-param-file) MG_OUTPUT_PARAM_FILE="${2:-}"; shift 2;;
        --mg-template-param-file) MG_TEMPLATE_PARAM_FILE="${2:-}"; shift 2;;
        -h|--help)           usage;;
        *)                   echo "Unknown option: $1" >&2; usage;;
    esac
done

POLICY_MG_PARAMS_FILE="${POLICY_MG_PARAMS_FILE:-${POLICY_DIR}/mg.parameters.json}"
if [[ -f "$POLICY_MG_PARAMS_FILE" ]]; then
    if command -v jq >/dev/null 2>&1 && ! jq empty "$POLICY_MG_PARAMS_FILE" >/dev/null 2>&1; then
        echo "Policies MG params file is not valid JSON: $POLICY_MG_PARAMS_FILE" >&2
        exit 1
    fi
    cp "$POLICY_MG_PARAMS_FILE" "$MG_OUTPUT_PARAM_FILE"
    MG_USE_EXISTING_MG_PARAMS=true
    MG_PARAMS_FILE_EXISTS=true
fi

[[ -f "$MG_OUTPUT_PARAM_FILE" ]] && MG_PARAMS_FILE_EXISTS=true

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

declare -A SUBSTITUTION_DEFAULTS=(
    [CREATE_MANAGEMENT_GROUPS]=false
    [DEPLOY_CUSTOM_POLICY_DEFINITIONS]=false
    [DEPLOY_CUSTOM_POLICY_INITIATIVES]=false
    [ASSIGN_CUSTOM_POLICY_INITIATIVES]=false
    [ASSIGN_BUILTIN_POLICY_INITIATIVES]=false
    [CUSTOM_POLICY_DEFINITIONS_CONTENTS]='[]'
    [CUSTOM_POLICY_INITIATIVES_CONTENTS]='[]'
    [BUILTIN_POLICY_INITIATIVES_CONTENTS]='[]'
    [MG_MANAGEMENT_GROUPS_TO_CREATE]='[]'
    [MG_PARENT_MANAGEMENT_GROUP_NAME]='""'
)

is_mg_param_var() {
    case "$1" in
        CREATE_MANAGEMENT_GROUPS|MG_MANAGEMENT_GROUPS_TO_CREATE|MG_PARENT_MANAGEMENT_GROUP_NAME) return 0;;
        *) return 1;;
    esac
}

for var in "${!SUBSTITUTION_DEFAULTS[@]}"; do
    current_value="${!var:-}"
    if [[ -z "$current_value" ]]; then
        export "$var=${SUBSTITUTION_DEFAULTS[$var]}"
    fi
done

load_existing_mg_params() {
    local existing_file="$MG_OUTPUT_PARAM_FILE"
    [[ -f "$existing_file" ]] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        echo "Warning: jq not found; skipping MG parameter overrides from $existing_file" >&2
        return 0
    fi

    if ! jq empty "$existing_file" >/dev/null 2>&1; then
        echo "Warning: existing MG params file is not valid JSON; ignoring $existing_file" >&2
        return 0
    fi

    if jq -e '.parameters.creatManagementGroups | has("value")' "$existing_file" >/dev/null 2>&1; then
        export CREATE_MANAGEMENT_GROUPS="$(jq -r '.parameters.creatManagementGroups.value' "$existing_file")"
    fi

    if jq -e '.parameters.managementGroupNamesToCreate | has("value")' "$existing_file" >/dev/null 2>&1; then
        export MG_MANAGEMENT_GROUPS_TO_CREATE="$(jq -c '.parameters.managementGroupNamesToCreate.value' "$existing_file")"
    fi

    if jq -e '.parameters.parentManagementGroupName | has("value")' "$existing_file" >/dev/null 2>&1; then
        export MG_PARENT_MANAGEMENT_GROUP_NAME="$(jq -c '.parameters.parentManagementGroupName.value' "$existing_file")"
    fi
}

normalize_json_string() {
    local raw="$1"

    if [[ -z "$raw" ]]; then
        printf '""'
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        if jq -e . >/dev/null 2>&1 <<<"$raw"; then
            if [[ "$(jq -r 'type' <<<"$raw")" == "string" ]]; then
                printf '%s' "$raw"
                return
            fi
        fi
        jq -Rn --arg v "$raw" '$v'
        return
    fi

    local escaped="$raw"
    escaped="${escaped//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    printf '"%s"' "$escaped"
}

# Prepare main parameters from template
if [[ -f "$TEMPLATE_PARAM_FILE" ]]; then
    cp "$TEMPLATE_PARAM_FILE" "$OUTPUT_PARAM_FILE"
    echo "Using template: $TEMPLATE_PARAM_FILE -> $OUTPUT_PARAM_FILE" >&2

    load_existing_mg_params

    mapfile -t discovered_vars < <({ grep -hoE '\$\{?[A-Za-z_][A-Za-z0-9_]*\}?' "$OUTPUT_PARAM_FILE" || true; } | sed 's/[${}]//g' | sort -u)

    filtered_vars=()
    for var in "${discovered_vars[@]}"; do
        [[ "$var" =~ ^[A-Z0-9_]+$ ]] || continue
        filtered_vars+=("$var")
    done

    echo "Discovered variables in template (count: ${#discovered_vars[@]}). Using filtered set (uppercase only) count: ${#filtered_vars[@]}" >&2
    printf ' - %s\n' "${filtered_vars[@]}" >&2

    if ((${#filtered_vars[@]})); then
        vars="$(printf '$%s ' "${filtered_vars[@]}")"
        echo "Running envsubst for main params with restricted set: $vars" >&2
        envsubst "$vars" < "$OUTPUT_PARAM_FILE" > "${OUTPUT_PARAM_FILE}.tmp"
    else
        echo "No variables discovered; running envsubst without a restricted list" >&2
        envsubst < "$OUTPUT_PARAM_FILE" > "${OUTPUT_PARAM_FILE}.tmp"
    fi

    mv "${OUTPUT_PARAM_FILE}.tmp" "$OUTPUT_PARAM_FILE"

    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$OUTPUT_PARAM_FILE" >/dev/null 2>&1; then
            echo "Generated parameters file is not valid JSON: $OUTPUT_PARAM_FILE" >&2
            exit 1
        fi
    else
        echo "Warning: jq not found; skipping JSON validation for main params" >&2
    fi
fi

# Prepare management group parameters if a template is present
if [[ -f "$MG_TEMPLATE_PARAM_FILE" ]]; then
    if [[ "$MG_USE_EXISTING_MG_PARAMS" != "true" ]]; then
        cp "$MG_TEMPLATE_PARAM_FILE" "$MG_OUTPUT_PARAM_FILE"
        echo "Using template: $MG_TEMPLATE_PARAM_FILE -> $MG_OUTPUT_PARAM_FILE" >&2

        mapfile -t mg_discovered_vars < <({ grep -hoE '\$\{?[A-Za-z_][A-Za-z0-9_]*\}?' "$MG_OUTPUT_PARAM_FILE" || true; } | sed 's/[${}]//g' | sort -u)

        mg_filtered_vars=()
        for var in "${mg_discovered_vars[@]}"; do
            [[ "$var" =~ ^[A-Z0-9_]+$ ]] || continue
            mg_filtered_vars+=("$var")
        done

        echo "Discovered MG variables in template (count: ${#mg_discovered_vars[@]}). Using filtered set (uppercase only) count: ${#mg_filtered_vars[@]}" >&2
        printf ' - %s\n' "${mg_filtered_vars[@]}" >&2

        if ((${#mg_filtered_vars[@]})); then
            mg_vars="$(printf '$%s ' "${mg_filtered_vars[@]}")"
            echo "Running envsubst for MG params with restricted set: $mg_vars" >&2
            envsubst "$mg_vars" < "$MG_OUTPUT_PARAM_FILE" > "${MG_OUTPUT_PARAM_FILE}.tmp"
        else
            echo "No MG variables discovered; running envsubst without a restricted list" >&2
            envsubst < "$MG_OUTPUT_PARAM_FILE" > "${MG_OUTPUT_PARAM_FILE}.tmp"
        fi

        mv "${MG_OUTPUT_PARAM_FILE}.tmp" "$MG_OUTPUT_PARAM_FILE"

        if command -v jq >/dev/null 2>&1; then
            if ! jq empty "$MG_OUTPUT_PARAM_FILE" >/dev/null 2>&1; then
                echo "Generated MG parameters file is not valid JSON: $MG_OUTPUT_PARAM_FILE" >&2
                exit 1
            fi
        else
            echo "Warning: jq not found; skipping JSON validation for MG params" >&2
        fi
    fi
fi


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
export ASSIGN_ALL_POLICY_INITIATIVES=true

declare -A DEPLOY_FLAGS=(
    [BUILTIN_POLICY_INITIATIVES]="${DEPLOY_BUILTIN_POLICY_INITIATIVES:-true}"
    [CUSTOM_POLICY_DEFINITIONS]="${DEPLOY_CUSTOM_POLICY_DEFINITIONS:-true}"
    [CUSTOM_POLICY_INITIATIVES]="${DEPLOY_CUSTOM_POLICY_INITIATIVES:-true}"
)

usage() {
    echo "Usage: $0 [--policy-dir <path>] [--file-extension <ext>] [--output-param-file <path>]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --policy-dir)        POLICY_DIR="${2:-}"; shift 2;;
        --file-extension)    FILE_EXTENSION="${2:-}"; shift 2;;
        --output-param-file) OUTPUT_PARAM_FILE="${2:-}"; TEMPLATE_PARAM_FILE="${OUTPUT_PARAM_FILE}.tmpl"; shift 2;;
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

[[ -f "$TEMPLATE_PARAM_FILE" ]] || { echo "Template $TEMPLATE_PARAM_FILE not found" >&2; exit 1; }
cp "$TEMPLATE_PARAM_FILE" "$OUTPUT_PARAM_FILE"

declare -a policy_vars=()
declare -A seen_policy_vars=()
for pattern in "${ENV_PATTERNS[@]:-}"; do
    [[ -z "$pattern" ]] && continue
    while IFS='=' read -r name _; do
        [[ "$name" == *"$pattern"* ]] || continue
        [[ -n "${seen_policy_vars[$name]:-}" ]] && continue
        policy_vars+=("$name")
        seen_policy_vars["$name"]=1
    done < <(env)
done

if ((${#policy_vars[@]})); then
    vars="$(printf '$%s ' "${policy_vars[@]}")"
    envsubst "$vars" < "$OUTPUT_PARAM_FILE" > "${OUTPUT_PARAM_FILE}.tmp"
else
    cp "$OUTPUT_PARAM_FILE" "${OUTPUT_PARAM_FILE}.tmp"
fi

mv "${OUTPUT_PARAM_FILE}.tmp" "$OUTPUT_PARAM_FILE"

printf 'Resolved policy variables (patterns: %s):\n' "${ENV_PATTERNS[*]:-}"
if ((${#policy_vars[@]})); then
    for name in "${policy_vars[@]}"; do
        printenv "$name"
    done
else
    printf '  (none matched)\n'
fi
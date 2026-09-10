#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
readonly TEST_SOURCE_DIRECTORY="${REPOSITORY_ROOT}/MangaLibraryTests"
readonly TEST_PLAN_DIRECTORY="${REPOSITORY_ROOT}/TestPlans"
readonly SHARED_SCHEME_DIRECTORY="${REPOSITORY_ROOT}/MangaLibrary.xcodeproj/xcshareddata/xcschemes"
readonly SHARED_SCHEME="${SHARED_SCHEME_DIRECTORY}/MangaLibrary.xcscheme"

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

require_file() {
    [[ -f "$1" ]] || fail "No existe $1."
}

require_plist_value() {
    local file="$1"
    local key="$2"
    local expected="$3"
    local actual

    actual="$(/usr/bin/plutil -extract "${key}" raw -o - "${file}" 2>/dev/null)" || \
        fail "${file#"${REPOSITORY_ROOT}/"}: falta ${key}."
    [[ "${actual}" == "${expected}" ]] || \
        fail "${file#"${REPOSITORY_ROOT}/"}: ${key} debe ser ${expected}, no ${actual}."
}

reject_plist_key() {
    local file="$1"
    local key="$2"

    if /usr/bin/plutil -extract "${key}" raw -o - "${file}" >/dev/null 2>&1; then
        fail "${file#"${REPOSITORY_ROOT}/"}: ${key} no debe existir."
    fi
}

reject_target_filters() {
    local file="$1"
    local target_index="$2"

    reject_plist_key "${file}" "testTargets.${target_index}.skippedTags"
    reject_plist_key "${file}" "testTargets.${target_index}.selectedTests"
    reject_plist_key "${file}" "testTargets.${target_index}.skippedTests"
}

validate_filtered_plan() {
    local name="$1"
    local tag="$2"
    local file="${TEST_PLAN_DIRECTORY}/${name}.xctestplan"

    require_file "${file}"
    require_plist_value "${file}" testTargets.0.target.name MangaLibraryTests
    require_plist_value "${file}" testTargets.0.parallelizable true
    require_plist_value "${file}" testTargets.0.selectedTags.mode or
    require_plist_value "${file}" testTargets.0.selectedTags.tags.0 "${tag}"
    reject_plist_key "${file}" testTargets.0.selectedTags.tags.1
    reject_target_filters "${file}" 0
    reject_plist_key "${file}" testTargets.1
}

validate_unfiltered_plan() {
    local name="$1"
    local target_index="$2"
    local target_name="$3"
    local parallelizable="$4"
    local file="${TEST_PLAN_DIRECTORY}/${name}.xctestplan"

    require_file "${file}"
    require_plist_value "${file}" "testTargets.${target_index}.target.name" "${target_name}"
    require_plist_value "${file}" "testTargets.${target_index}.parallelizable" "${parallelizable}"
    reject_plist_key "${file}" "testTargets.${target_index}.selectedTags"
    reject_target_filters "${file}" "${target_index}"
}

validate_suite_classification() {
    local suite_declarations
    local classification_traits
    local declaration
    local fast_count=0
    local integration_count=0
    local fast_occurrences
    local integration_occurrences

    suite_declarations="$(
        find "${TEST_SOURCE_DIRECTORY}" -name '*.swift' -type f -print0 \
            | xargs -0 /usr/bin/grep -Hn '^@Suite' || true
    )"
    [[ -n "${suite_declarations}" ]] || fail "MangaLibraryTests no contiene suites Swift Testing."

    while IFS= read -r declaration; do
        fast_occurrences="$(/usr/bin/awk -F '\\.tags\\(\\.fast\\)' '{ print NF - 1 }' <<< "${declaration}")"
        integration_occurrences="$(
            /usr/bin/awk -F '\\.tags\\(\\.integration\\)' '{ print NF - 1 }' <<< "${declaration}"
        )"

        ((fast_occurrences + integration_occurrences == 1)) || \
            fail "Cada @Suite debe declarar exactamente un tag fast o integration: \
${declaration#"${REPOSITORY_ROOT}/"}"
        ((fast_occurrences == 1)) && ((fast_count += 1))
        ((integration_occurrences == 1)) && ((integration_count += 1))
    done <<< "${suite_declarations}"

    classification_traits="$(
        find "${TEST_SOURCE_DIRECTORY}" -name '*.swift' -type f -print0 \
            | xargs -0 /usr/bin/grep -hE '\.tags\(\.(fast|integration)\)' || true
    )"

    while IFS= read -r declaration; do
        [[ -z "${declaration}" || "${declaration}" == @Suite* ]] || \
            fail "Los tags fast e integration se heredan desde @Suite; no deben repetirse en @Test."
    done <<< "${classification_traits}"

    printf 'Clasificación Swift Testing: %s suites Fast y %s suites Integration.\n' \
        "${fast_count}" "${integration_count}"
}

validate_scheme() {
    local default_count
    local plan_count

    require_file "${SHARED_SCHEME}"
    default_count="$(/usr/bin/grep -c 'default = "YES"' "${SHARED_SCHEME}")"
    [[ "${default_count}" == 1 ]] || fail "El scheme debe declarar un único plan predeterminado."
    plan_count="$(/usr/bin/grep -c '<TestPlanReference' "${SHARED_SCHEME}")"
    [[ "${plan_count}" == 4 ]] || fail "El scheme MangaLibrary debe referenciar exactamente cuatro planes."

    /usr/bin/grep -A1 'reference = "container:TestPlans/Fast.xctestplan"' "${SHARED_SCHEME}" \
        | /usr/bin/grep -Fq 'default = "YES"' \
        || fail "Fast debe ser el plan predeterminado del scheme MangaLibrary."

    for name in Fast Integration UI ReleaseGate; do
        /usr/bin/grep -Fq "reference = \"container:TestPlans/${name}.xctestplan\"" "${SHARED_SCHEME}" \
            || fail "El scheme MangaLibrary no referencia ${name}.xctestplan."
    done
}

[[ -f "${REPOSITORY_ROOT}/AGENTS.md" ]] || fail "No se reconoce la raíz del repositorio."
[[ -d "${TEST_SOURCE_DIRECTORY}" ]] || fail "No existe MangaLibraryTests."
[[ -d "${TEST_PLAN_DIRECTORY}" ]] || fail "No existe TestPlans."

validate_filtered_plan Fast fast
validate_filtered_plan Integration integration
for name in Fast Integration ReleaseGate; do
    require_plist_value "${TEST_PLAN_DIRECTORY}/${name}.xctestplan" \
        defaultOptions.commandLineArgumentEntries.0.argument -ui-testing
done
validate_unfiltered_plan UI 0 MangaLibraryUITests false
reject_plist_key "${TEST_PLAN_DIRECTORY}/UI.xctestplan" testTargets.1
validate_unfiltered_plan ReleaseGate 0 MangaLibraryTests true
validate_unfiltered_plan ReleaseGate 1 MangaLibraryUITests false
reject_plist_key "${TEST_PLAN_DIRECTORY}/ReleaseGate.xctestplan" testTargets.2
validate_suite_classification
validate_scheme

printf 'Planes de test: filtros, targets, partición y plan predeterminado válidos.\n'

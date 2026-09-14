#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
readonly PROJECT_PATH="${REPOSITORY_ROOT}/MangaLibrary.xcodeproj"
readonly PROJECT_RELATIVE_PATH="MangaLibrary.xcodeproj"
readonly SCHEME="MangaLibrary"
readonly TEST_PLAN="ReleaseGate"
readonly DESTINATION="generic/platform=iOS Simulator"
readonly SELECTED_DEVELOPER_DIRECTORY="${MANGALIBRARY_DEVELOPER_DIR:-}"
readonly XCODEBUILD="${SELECTED_DEVELOPER_DIRECTORY}/usr/bin/xcodebuild"
readonly SWIFTC="${SELECTED_DEVELOPER_DIRECTORY}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
readonly GATE_MODE="${1:-advanced}"
readonly TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/mangalibrary-advanced-build.XXXXXX")"

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

cleanup() {
    if [[ -d "${TEMPORARY_DIRECTORY}" ]]; then
        rm -rf -- "${TEMPORARY_DIRECTORY}"
    fi
}

redact_output() {
    sed \
        -e "s#${REPOSITORY_ROOT}#<repository>#g" \
        -e "s#${TEMPORARY_DIRECTORY}#<temporary>#g" \
        -e "s#${HOME}#<home>#g"
}

validate_output() {
    local output="$1"
    local configuration="$2"
    local diagnostics

    diagnostics="$(grep -E '(^|[[:space:]])(warning|error):' <<< "${output}" || true)"
    if [[ -n "${diagnostics}" ]]; then
        printf 'Diagnósticos bloqueantes (%s):\n' "${configuration}" >&2
        printf '%s\n' "${diagnostics}" | redact_output >&2
        fail "El build-for-testing ${configuration} emitió warnings o errores."
    fi

    if grep -Eq 'ExtractAppIntentsMetadata|appintentsmetadataprocessor' <<< "${output}"; then
        fail "El build-for-testing ${configuration} todavía construye la extracción de App Intents."
    fi

    if [[ "${GATE_MODE}" == "--deluxe" ]]; then
        local target
        for target in MangaLibrary MangaLibraryTests MangaLibraryUITests \
            MangaLibraryWidgetExtension "MangaLibraryWatch Watch App"; do
            grep -Fq "Target '${target}' in project 'MangaLibrary'" <<< "${output}" || \
                fail "El grafo de build ${configuration} no acredita ${target}."
        done
    fi
}

trap cleanup EXIT

[[ "$#" -le 1 && ( "${GATE_MODE}" == advanced || "${GATE_MODE}" == --deluxe ) ]] || \
    fail "Uso: Scripts/validate-advanced-build.sh [--deluxe]"
[[ -n "${SELECTED_DEVELOPER_DIRECTORY}" ]] || \
    fail "Indica MANGALIBRARY_DEVELOPER_DIR con el Developer directory de Xcode 27 verificado en el preflight."
export DEVELOPER_DIR="${SELECTED_DEVELOPER_DIRECTORY}"

if [[ "${GATE_MODE}" == "--deluxe" ]]; then
    "${SCRIPT_DIRECTORY}/validate-test-plans.sh"
    python3 "${SCRIPT_DIRECTORY}/validate-deluxe-configuration.py"
fi

[[ -f "${REPOSITORY_ROOT}/AGENTS.md" ]] || fail "No se reconoce la raíz del repositorio."
[[ -d "${PROJECT_PATH}" ]] || fail "No existe ${PROJECT_RELATIVE_PATH}."
[[ -x "${XCODEBUILD}" ]] || fail "No existe un xcodebuild ejecutable en el Xcode seleccionado."
[[ -x "${SWIFTC}" ]] || fail "No existe un swiftc ejecutable en el Xcode seleccionado."

readonly XCODE_VERSION="$("${XCODEBUILD}" -version)"
readonly SWIFT_VERSION="$("${SWIFTC}" -version)"

grep -Eq '^Xcode 27([.]|$)' <<< "${XCODE_VERSION}" || fail "El toolchain seleccionado no es Xcode 27."
grep -Eq 'Apple Swift version 6[.]4([ .(]|$)' <<< "${SWIFT_VERSION}" || fail "El compilador seleccionado no es Apple Swift 6.4."

printf '%s\n' "${XCODE_VERSION}"
printf '%s\n' "${SWIFT_VERSION}"
printf 'Proyecto: %s\n' "${PROJECT_RELATIVE_PATH}"
printf 'Scheme: %s\n' "${SCHEME}"
printf 'Plan: %s\n' "${TEST_PLAN}"
printf 'Destino: %s\n' "${DESTINATION}"
printf 'Gate: %s\n' "${GATE_MODE}"

for configuration in Debug Release; do
    printf 'Build-for-testing: %s\n' "${configuration}"
    build_output=""

    if ! build_output="$("${XCODEBUILD}" build-for-testing \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -testPlan "${TEST_PLAN}" \
        -configuration "${configuration}" \
        -destination "${DESTINATION}" \
        -derivedDataPath "${TEMPORARY_DIRECTORY}/DerivedData-${configuration}" \
        ENABLE_TESTABILITY=YES \
        CODE_SIGNING_ALLOWED=NO 2>&1)"; then
        printf '%s\n' "${build_output}" | tail -200 | redact_output >&2
        fail "El build-for-testing ${configuration} no terminó correctamente."
    fi

    validate_output "${build_output}" "${configuration}"
    printf 'Resultado %s: build limpio, cero warnings y cero errores.\n' "${configuration}"
done

printf 'Política: cualquier warning, error o tarea de metadata de App Intents hace fallar el gate.\n'
printf 'Testabilidad: habilitada solo como override de esta compilación local para permitir @testable en Release.\n'
printf 'Excluido: ejecución de tests, archive, publicación, hardware e integración live.\n'

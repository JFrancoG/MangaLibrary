#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
readonly PROJECT_RELATIVE_PATH="MangaLibrary.xcodeproj"
readonly PROJECT_PATH="${REPOSITORY_ROOT}/${PROJECT_RELATIVE_PATH}"
readonly SCHEME="MangaLibrary"
readonly SHARED_SCHEME_PATH="${PROJECT_PATH}/xcshareddata/xcschemes/${SCHEME}.xcscheme"
readonly DESTINATION="generic/platform=iOS"
readonly OUTPUT_DIRECTORY="${REPOSITORY_ROOT}/.build/docc"
readonly OUTPUT_ARCHIVE="${OUTPUT_DIRECTORY}/MangaLibrary.doccarchive"
readonly DEFAULT_DEVELOPER_DIRECTORY="/Applications/Xcode-beta.app/Contents/Developer"
readonly SELECTED_DEVELOPER_DIRECTORY="${MANGALIBRARY_DEVELOPER_DIR:-${DEFAULT_DEVELOPER_DIRECTORY}}"
readonly XCODEBUILD="${SELECTED_DEVELOPER_DIRECTORY}/usr/bin/xcodebuild"
readonly ALLOWED_TOOL_WARNING_XCODE_BUILD="27A5252f"
readonly ALLOWED_TOOL_WARNING_MESSAGE="Metadata extraction skipped, no AppIntents.framework dependency found"
readonly TOOL_DIAGNOSTIC_PRODUCER_PATTERN='appintentsmetadataprocessor\[[^]]+\]'
readonly TOOL_DIAGNOSTIC_MESSAGE_PATTERN='Metadata extraction skipped, no AppIntents\.framework dependency found'
readonly KNOWN_TOOL_DIAGNOSTIC_PATTERN="(^|[[:space:]])${TOOL_DIAGNOSTIC_PRODUCER_PATTERN}[[:space:]][[:alpha:]][[:alpha:]-]*:[[:space:]]${TOOL_DIAGNOSTIC_MESSAGE_PATTERN}$"
readonly ALLOWED_TOOL_WARNING_PATTERN="(^|[[:space:]])${TOOL_DIAGNOSTIC_PRODUCER_PATTERN}[[:space:]]warning:[[:space:]]${TOOL_DIAGNOSTIC_MESSAGE_PATTERN}$"

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

require_text() {
    local content="$1"
    local expected="$2"
    local context="$3"

    grep -Fq -- "${expected}" <<< "${content}" || fail "${context}: falta '${expected}'."
}

require_setting() {
    local settings="$1"
    local name="$2"
    local expected="$3"
    local context="$4"

    grep -Eq "^[[:space:]]*${name}[[:space:]]*=[[:space:]]*${expected}[[:space:]]*$" <<< "${settings}" || \
        fail "${context}: ${name} no evalúa a ${expected}."
}

require_setting_contains() {
    local settings="$1"
    local name="$2"
    local expected="$3"
    local context="$4"

    grep -Eq "^[[:space:]]*${name}[[:space:]]*=.*${expected}([[:space:]]|$)" <<< "${settings}" || \
        fail "${context}: ${name} no contiene ${expected}."
}

redact_output() {
    sed -e "s#${REPOSITORY_ROOT}#<repository>#g" \
        -e "s#${TEMPORARY_DIRECTORY:-<no-temporary-directory>}#<temporary>#g" \
        -e "s#${HOME}#<home>#g"
}

collect_tool_diagnostic_lines() {
    local build_output="$1"

    grep -E "(^|[[:space:]])(warning|error):|${KNOWN_TOOL_DIAGNOSTIC_PATTERN}" <<< "${build_output}" || true
}

count_severity_markers() {
    local diagnostic="$1"
    local markers

    markers="$(grep -Eo '(^|[[:space:]])(warning|error):' <<< "${diagnostic}" || true)"
    if [[ -z "${markers}" ]]; then
        printf '0\n'
    else
        wc -l <<< "${markers}" | tr -d '[:space:]'
        printf '\n'
    fi
}

classify_tool_diagnostics() {
    local build_output="$1"
    local xcode_build="$2"
    local diagnostic
    local severity_marker_count
    local allowed_warning_count=0
    local unexpected_diagnostic_count=0

    while IFS= read -r diagnostic; do
        [[ -n "${diagnostic}" ]] || continue

        severity_marker_count="$(count_severity_markers "${diagnostic}")"

        if [[ "${diagnostic}" =~ ${ALLOWED_TOOL_WARNING_PATTERN} ]] && ((severity_marker_count == 1)); then
            ((allowed_warning_count += 1))
        else
            ((unexpected_diagnostic_count += 1))
        fi
    done < <(collect_tool_diagnostic_lines "${build_output}")

    if ((unexpected_diagnostic_count > 0)); then
        printf 'unexpected\n'
    elif ((allowed_warning_count > 1)); then
        printf 'too-many:%s\n' "${allowed_warning_count}"
    elif ((allowed_warning_count == 1)) && [[ "${xcode_build}" != "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" ]]; then
        printf 'wrong-build\n'
    elif ((allowed_warning_count == 1)); then
        printf 'allowed\n'
    else
        printf 'clean\n'
    fi
}

require_diagnostic_classification() {
    local output="$1"
    local xcode_build="$2"
    local expected="$3"
    local context="$4"
    local actual

    actual="$(classify_tool_diagnostics "${output}" "${xcode_build}")"
    [[ "${actual}" == "${expected}" ]] || \
        fail "Autotest del clasificador (${context}): se esperaba ${expected} y se obtuvo ${actual}."
}

self_test_tool_diagnostic_classifier() {
    local allowed_warning="appintentsmetadataprocessor[123:456] warning: ${ALLOWED_TOOL_WARNING_MESSAGE}"
    local changed_severity="appintentsmetadataprocessor[123:456] note: ${ALLOWED_TOOL_WARNING_MESSAGE}"
    local unexpected_warning="otherprocessor[123:456] warning: Unexpected diagnostic"
    local unexpected_error="otherprocessor[123:456] error: Unexpected diagnostic"
    local hidden_diagnostic="otherprocessor[123:456] warning: hidden ${allowed_warning}"

    require_diagnostic_classification "" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" clean "cero diagnósticos"
    require_diagnostic_classification "${allowed_warning}" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" allowed "una emisión exacta"
    require_diagnostic_classification "${allowed_warning}"$'\n'"${allowed_warning}" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" too-many:2 "dos emisiones exactas"
    require_diagnostic_classification "${allowed_warning}"$'\n'"${unexpected_warning}" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" unexpected "warning adicional"
    require_diagnostic_classification "${unexpected_error}" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" unexpected "error adicional"
    require_diagnostic_classification "${changed_severity}" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" unexpected "severidad modificada"
    require_diagnostic_classification "${hidden_diagnostic}" "${ALLOWED_TOOL_WARNING_XCODE_BUILD}" unexpected "dos diagnósticos en una línea"
    require_diagnostic_classification "${allowed_warning}" "different-build" wrong-build "build no autorizado"

    printf 'Clasificador de diagnósticos: 8 escenarios deterministas aprobados.\n'
}

validate_tool_diagnostics() {
    local build_output="$1"
    local classification

    classification="$(classify_tool_diagnostics "${build_output}" "${XCODE_BUILD}")"

    case "${classification}" in
        clean)
            printf 'Diagnósticos: cero warnings y cero errores. La excepción temporal no fue necesaria.\n'
            ;;
        allowed)
            printf 'Diagnóstico externo autorizado por ADR-0011:\n'
            printf 'appintentsmetadataprocessor warning: %s\n' "${ALLOWED_TOOL_WARNING_MESSAGE}"
            printf 'Límite: exactamente una emisión en Xcode build %s; no es un warning de Swift, Clang ni DocC.\n' \
                "${ALLOWED_TOOL_WARNING_XCODE_BUILD}"
            ;;
        unexpected)
            printf 'Diagnósticos no autorizados:\n' >&2
            collect_tool_diagnostic_lines "${build_output}" | redact_output >&2
            fail "xcodebuild docbuild emitió warnings o errores no autorizados."
            ;;
        too-many:*)
            fail "Se esperaba como máximo un warning externo autorizado y se encontraron ${classification#too-many:}."
            ;;
        wrong-build)
            fail "El warning externo solo está autorizado para Xcode build ${ALLOWED_TOOL_WARNING_XCODE_BUILD}; el build actual es ${XCODE_BUILD}."
            ;;
        *)
            fail "El clasificador de diagnósticos devolvió un estado desconocido: ${classification}."
            ;;
    esac
}

[[ -f "${REPOSITORY_ROOT}/AGENTS.md" ]] || fail "No se reconoce la raíz del repositorio."
[[ -d "${PROJECT_PATH}" ]] || fail "No existe ${PROJECT_RELATIVE_PATH}."
[[ -f "${SHARED_SCHEME_PATH}" ]] || fail "No existe el scheme compartido ${SCHEME}."
[[ -x "${XCODEBUILD}" ]] || fail "No existe xcodebuild en el Xcode seleccionado: ${SELECTED_DEVELOPER_DIRECTORY}."
[[ "${OUTPUT_DIRECTORY}" == "${REPOSITORY_ROOT}/.build/docc" ]] || fail "La ruta de salida no es la aprobada."

export DEVELOPER_DIR="${SELECTED_DEVELOPER_DIRECTORY}"

readonly XCODE_VERSION="$("${XCODEBUILD}" -version)"
readonly SWIFT_VERSION="$(/usr/bin/xcrun swift --version 2>&1)"
readonly XCODE_BUILD="$(/usr/bin/awk '/^Build version / { print $3; exit }' <<< "${XCODE_VERSION}")"

grep -Eq '^Xcode 27([.]|$)' <<< "${XCODE_VERSION}" || fail "El toolchain seleccionado no es Xcode 27."
[[ -n "${XCODE_BUILD}" ]] || fail "No se pudo determinar el build del Xcode seleccionado."
grep -Eq 'Apple Swift version 6[.]4([ .(]|$)' <<< "${SWIFT_VERSION}" || fail "El compilador seleccionado no es Apple Swift 6.4."
self_test_tool_diagnostic_classifier

readonly XCODEBUILD_HELP="$("${XCODEBUILD}" -help 2>&1)"
for option in -project -scheme -configuration -destination -derivedDataPath -sdk -json; do
    require_text "${XCODEBUILD_HELP}" "${option}" "Ayuda instalada de xcodebuild"
done

readonly XCODEBUILD_MANUAL="$(MANPATH="${SELECTED_DEVELOPER_DIRECTORY}/usr/share/man" /usr/bin/man xcodebuild | /usr/bin/col -b)"
require_text "${XCODEBUILD_MANUAL}" "docbuild" "Manual instalado de xcodebuild"

readonly DOCC_HELP="$(/usr/bin/xcrun docc convert --help 2>&1)"
require_text "${DOCC_HELP}" "--warnings-as-errors" "Ayuda instalada de DocC"

readonly PROJECT_LIST="$("${XCODEBUILD}" -list -json -project "${PROJECT_PATH}")"
readonly SCHEMES="$(printf '%s\n' "${PROJECT_LIST}" | /usr/bin/plutil -extract project.schemes json -o - -)"
require_text "${SCHEMES}" "\"${SCHEME}\"" "Schemes de ${PROJECT_RELATIVE_PATH}"

readonly TARGETS=(MangaLibrary MangaLibraryTests MangaLibraryUITests)
readonly CONFIGURATIONS=(Debug Release)

for target in "${TARGETS[@]}"; do
    for configuration in "${CONFIGURATIONS[@]}"; do
        settings="$("${XCODEBUILD}" \
            -project "${PROJECT_PATH}" \
            -target "${target}" \
            -configuration "${configuration}" \
            -sdk iphoneos \
            -showBuildSettings)"
        context="${target} ${configuration}"

        require_setting "${settings}" GCC_TREAT_WARNINGS_AS_ERRORS YES "${context}"
        require_setting "${settings}" SWIFT_TREAT_WARNINGS_AS_ERRORS YES "${context}"
        require_setting "${settings}" SWIFT_STRICT_CONCURRENCY complete "${context}"
        require_setting "${settings}" SWIFT_DEFAULT_ACTOR_ISOLATION nonisolated "${context}"
        require_setting_contains "${settings}" OTHER_DOCC_FLAGS --warnings-as-errors "${context}"
    done
done

readonly TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/mangalibrary-docc.XXXXXX")"
trap 'rm -rf "${TEMPORARY_DIRECTORY}"' EXIT

rm -rf "${OUTPUT_DIRECTORY}"
mkdir -p "${OUTPUT_DIRECTORY}"

printf '%s\n' "${XCODE_VERSION}"
printf '%s\n' "${SWIFT_VERSION}"
printf 'Destino: %s\n' "${DESTINATION}"
printf 'Acción: xcodebuild docbuild -project %s -scheme %s -configuration Release -destination %s -derivedDataPath <temporal> CODE_SIGNING_ALLOWED=NO\n' \
    "${PROJECT_RELATIVE_PATH}" "${SCHEME}" "${DESTINATION}"

build_output=""
if ! build_output="$("${XCODEBUILD}" docbuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination "${DESTINATION}" \
    -derivedDataPath "${TEMPORARY_DIRECTORY}/DerivedData" \
    CODE_SIGNING_ALLOWED=NO 2>&1)"; then
    printf '%s\n' "${build_output}" | redact_output >&2
    fail "xcodebuild docbuild no terminó correctamente."
fi

validate_tool_diagnostics "${build_output}"

shopt -s nullglob
archives=("${TEMPORARY_DIRECTORY}"/DerivedData/Build/Products/*/MangaLibrary.doccarchive)
[[ "${#archives[@]}" -eq 1 ]] || fail "Se esperaba un único MangaLibrary.doccarchive y se encontraron ${#archives[@]}."

/usr/bin/ditto "${archives[0]}" "${OUTPUT_ARCHIVE}"
[[ -d "${OUTPUT_ARCHIVE}" ]] || fail "No se generó .build/docc/MangaLibrary.doccarchive."

printf 'Archive: .build/docc/MangaLibrary.doccarchive\n'
printf 'Resultado: archive generado con los warnings de DocC tratados como errores.\n'
printf 'Política: cualquier warning o error no autorizado, deriva de firma o exceso de emisiones hace fallar el gate.\n'
printf 'Excluido: publicación, GitHub Pages, tutoriales, hardware e integración live.\n'

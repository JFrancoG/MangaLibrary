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

[[ -f "${REPOSITORY_ROOT}/AGENTS.md" ]] || fail "No se reconoce la raíz del repositorio."
[[ -d "${PROJECT_PATH}" ]] || fail "No existe ${PROJECT_RELATIVE_PATH}."
[[ -f "${SHARED_SCHEME_PATH}" ]] || fail "No existe el scheme compartido ${SCHEME}."
[[ -x "${XCODEBUILD}" ]] || fail "No existe xcodebuild en el Xcode seleccionado: ${SELECTED_DEVELOPER_DIRECTORY}."
[[ "${OUTPUT_DIRECTORY}" == "${REPOSITORY_ROOT}/.build/docc" ]] || fail "La ruta de salida no es la aprobada."

export DEVELOPER_DIR="${SELECTED_DEVELOPER_DIRECTORY}"

readonly XCODE_VERSION="$("${XCODEBUILD}" -version)"
readonly SWIFT_VERSION="$(/usr/bin/xcrun swift --version)"

grep -Eq '^Xcode 27([.]|$)' <<< "${XCODE_VERSION}" || fail "El toolchain seleccionado no es Xcode 27."
grep -Eq 'Apple Swift version 6[.]4([ .(]|$)' <<< "${SWIFT_VERSION}" || fail "El compilador seleccionado no es Apple Swift 6.4."

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
    printf '%s\n' "${build_output}" | \
        sed -e "s#${REPOSITORY_ROOT}#<repository>#g" \
            -e "s#${TEMPORARY_DIRECTORY}#<temporary>#g" \
            -e "s#${HOME}#<home>#g" >&2
    fail "xcodebuild docbuild no terminó correctamente."
fi

diagnostics="$(grep -E '(^|[[:space:]])(warning|error):' <<< "${build_output}" || true)"
if [[ -n "${diagnostics}" ]]; then
    printf 'Diagnósticos de herramientas conservados por el gate:\n'
    printf '%s\n' "${diagnostics}" | \
        sed -e "s#${REPOSITORY_ROOT}#<repository>#g" \
            -e "s#${TEMPORARY_DIRECTORY}#<temporary>#g" \
            -e "s#${HOME}#<home>#g"
fi

shopt -s nullglob
archives=("${TEMPORARY_DIRECTORY}"/DerivedData/Build/Products/*/MangaLibrary.doccarchive)
[[ "${#archives[@]}" -eq 1 ]] || fail "Se esperaba un único MangaLibrary.doccarchive y se encontraron ${#archives[@]}."

/usr/bin/ditto "${archives[0]}" "${OUTPUT_ARCHIVE}"
[[ -d "${OUTPUT_ARCHIVE}" ]] || fail "No se generó .build/docc/MangaLibrary.doccarchive."

printf 'Archive: .build/docc/MangaLibrary.doccarchive\n'
printf 'Resultado: archive generado con los warnings de DocC tratados como errores.\n'
printf 'Nota: los diagnósticos ajenos a DocC se conservan en la salida para atribuirlos a su herramienta de origen.\n'
printf 'Excluido: publicación, GitHub Pages, tutoriales, hardware e integración live.\n'

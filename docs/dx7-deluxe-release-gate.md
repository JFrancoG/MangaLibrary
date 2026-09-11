# DX7 — Deluxe Release Gate

**Fecha:** 2026-09-11
**Issue:** [#90](https://github.com/JFrancoG/MangaLibrary/issues/90), subissue del
[plan #77](https://github.com/JFrancoG/MangaLibrary/issues/77).
**Base:** `main@681ea6d8022ed6cae883b5b5ec2eb57adc459633`, merge de DX6 por PR #89.
**Rama:** `codex/90-dx7-deluxe-release-gate`.
**Estado actual (2026-09-11):** corte técnico entregado mediante [PR #91](https://github.com/JFrancoG/MangaLibrary/pull/91), merge `5e1fb14`; #90 cerrado y su rama retirada. El Deluxe Release Gate completo permanece pendiente en #88/#77.

La ejecución descrita abajo pertenece a DX7 sobre su base y commit `c68fe92`.
A01–A03 se entregaron después, con evidencia propia en [Progress](Progress.md).
Los recuentos históricos de este informe no se actualizan con tests posteriores
ni se presentan como ejecución de la futura candidata final.

## Alcance aprobado

### Checkpoints de autorización del 2026-09-11, previos a la entrega

El propietario autoriza iniciar DX7 tras integrar el corte técnico DX6. Se
consolidan los gates de Advanced y Deluxe sin añadir funcionalidades de producto.
El inicio no cierra #88 ni aprueba H01 o las pruebas físicas Watch diferidas.
Commit, push, PR, merge, publicación y borrados no forman parte de este permiso.

El propietario autoriza posteriormente commit, push, creación de PR y cierre
de issue/rama. La PR conservará H01 y H02/H03/H04 pendientes y referenciará
#90 sin cierre automático. El resultado efectivo de publicación y cualquier
merge posterior se registran en el tracker canónico; no se anticipan aquí.

### Resultado posterior verificado

La autorización posterior de entrega culmina en PR #91 integrada y #90 cerrado
como corte técnico. El merge `5e1fb14` conserva H01 y H02/H03/H04 pendientes en
#88/#77; no cierra el gate completo ni cambia 5/7. Las autorizaciones iniciales
anteriores describen su momento y no sustituyen este resultado.

Las fuentes normativas son SDD [05](specs/05-deluxe-watch-and-widget.md),
[06](specs/06-testing-quality-and-accessibility.md),
[07](specs/07-documentation-and-docc.md) y
[09](specs/09-deluxe-reading-contract.md). La matriz
[DX6](dx6-integration-accessibility.md) conserva las observaciones anteriores.
Este informe registra ejecución; no modifica los criterios de esas fuentes.

## Inventario y cambios del gate

| Target real | Evidencia que le corresponde |
| --- | --- |
| `MangaLibrary` | Build Debug/Release, host sintético de tests, UI y archive DocC canónico. |
| `MangaLibraryTests` | Swift Testing Advanced y lógica compartida Deluxe, planes Fast/Integration y ReleaseGate sin filtros. |
| `MangaLibraryUITests` | XCUITest aprobado, incluido completo en UI y ReleaseGate. |
| `MangaLibraryWidgetExtension` | Build por dependencia de la app; superficies y runtime en matrices DX4/DX6. |
| `MangaLibraryWatch Watch App` | Build por dependencia y scheme propio; matrices DX5/DX6 y hardware pendiente. |

No existen targets independientes de tests para Watch o widget. Las pruebas
compartidas ejecutadas en iOS no se presentan como ejecución en watchOS.

- `Scripts/validate-test-plans.sh` conserva la partición Fast/Integration, los
  filtros esperados, UI y ReleaseGate completos y Fast predeterminado.
- `Scripts/validate-deluxe-configuration.py` añade inventario real, tipos,
  dependencias app→widget/Watch, identidades de schemes/planes, targets
  habilitados y argumentos del host sintético. Requiere Python 3 y solo su
  biblioteca estándar, además de `plutil` de macOS.
- `Scripts/validate-advanced-build.sh --deluxe` ejecuta esas comprobaciones y
  exige los cinco targets en el grafo de cada build-for-testing limpio. Conserva
  cero warnings/errores, ausencia de extracción App Intents y testabilidad
  habilitada solo para compilar tests en esa acción local.
- `Scripts/validate-docc.sh` ya comprueba los cinco targets en ambos modos.
  SDD 07 se reconcilia con ese comportamiento; solo se exige el archive canónico
  `MangaLibrary.doccarchive`, sin duplicar documentación por target.

Se conservan proyecto, schemes, planes, entitlements, fuentes Swift y recursos
de producto. README actualiza el estado que todavía presentaba DX5 como futuro.

## Ejecución técnica

El MCP original de Codex devolvió `Transport closed`, incluso tras la reconexión
comunicada por el propietario. Se abrió una sesión nueva del **bridge oficial
de Apple** con selección local del proceso Xcode RC, se redescubrieron sus
herramientas y se confirmó MangaLibrary mediante `XcodeListWindows`. No se
cambió `xcode-select`, la configuración persistente de Codex ni permisos globales.

Preflight efectivo: Xcode 27 RC `27A266a`, Apple Swift 6.4
`swiftlang-6.4.0.34.1`, servidor `xcode-tools` 25317, scheme `MangaLibrary`,
plan `Fast`, iPhone 17 Simulator/iOS 27, cero issues del navegador. Ese preflight
no demuestra por sí solo un nuevo build limpio.

| Gate | Resultado DX7 | Límite |
| --- | --- | --- |
| Partición de planes | Aprobada: 28 suites Fast y 39 Integration. | Inventario estático, no ejecución. |
| Configuración Deluxe | Aprobada sobre los cinco targets y los schemes reales. | No prueba runtime o firma física. |
| Pruebas negativas del validador | Baseline aceptado y siete derivas rechazadas en copias temporales. | Comprobaciones del gate, no tests de producto. |
| Sintaxis shell y diff | `bash -n` y `git diff --check` aprobados. | No sustituye builds. |
| Builds Debug/Release `--deluxe` | Aprobados: cinco targets presentes en ambos grafos, cero warnings/errores, sin extracción App Intents. | No ejecución de tests, archive de distribución ni hardware. |
| ReleaseGate completo por MCP | Aprobado: 811/811 declaraciones, 1.160/1.160 invocaciones; cero fallos, skips, expected failures o casos no ejecutados. | iPhone 17 Simulator/iOS 27; no acredita hardware. |
| Archive DocC Release | Aprobado: exit 0, archive canónico generado, cero warnings/errores. | Archive local; sin publicación. |
| Revisión iOS independiente | Aprobada en scripts, especificaciones, informe y reconciliación de artefactos; sin hallazgos pendientes. | Build/tests sujetos a su evidencia real. |
| Swift Source Style / SwiftUI | N/A en el delta: no hay Swift ni cambios de UI. | No equivale a repetir toda la auditoría histórica. |

Las derivas inyectadas son target omitido, dependencia Watch omitida, identidad
de test incorrecta, target deshabilitado, target excluido, host sintético
deshabilitado y override por configuración. Se ejecutan fuera del worktree y no
añaden fixtures de producto ni dependencias externas. Una comprobación adicional
del clasificador de build acepta el grafo completo y rechaza el mismo grafo sin
Watch. La revisión independiente añade ocho mutaciones en memoria rechazadas;
no se suman a los siete casos como una suite de producto.

El log local `dx7-validation-build.log` acredita Debug/Release en Xcode
27 RC `27A266a`, destino `generic/platform=iOS Simulator`, plan `ReleaseGate`.
El inventario MCP `88D08233-3A10-4958-B8F3-4B450A72E000.txt` enumera las 811
declaraciones. La ejecución posterior produce
`Test-MangaLibrary-2026.09.11_02-00-34-+0200.xcresult`: 800 declaraciones Swift
Testing y 11 UI, 1.149 + 11 invocaciones. El árbol nativo contiene exactamente
los 811 identificadores del inventario, sin ausentes ni adicionales, todos
`Passed`. Sus 137 tests parametrizados generan 486 invocaciones; los otros 674
completan las 1.160. El resumen nativo informa cero runtime warnings.

`GetBuildLog` devuelve cero issues, sin truncado; el log completo
`51FE9605-0201-4CC2-8F23-9A5BC076A4B2.txt`, de 681 líneas, no contiene warnings
ni errores. El resumen MCP es `6553A5F1-1FF3-4B5C-AA53-F0A9089093B2.txt`.
El destino real del `.xcresult` es iPhone 17/iOS 27 build `24A434`, arm64.
El plan `Fast` queda restaurado después de ejecutar `ReleaseGate` y confirmado
por una nueva lectura MCP; el navegador conserva cero issues.

`dx7-validation-docc.log` acredita la nueva generación Release de
`.build/docc/MangaLibrary.doccarchive`, exit 0 y cero warnings/errores. El script
comprueba antes los ajustes efectivos de los cinco targets en Debug/Release.
Proyecto, ambos schemes y cuatro planes permanecen byte a byte iguales a HEAD;
la sesión temporal del bridge se cierra al terminar. No se generan cambios de
producto ni se publican los artefactos.

Para reproducir los gates CLI aprobados, seleccionar mediante
`MANGALIBRARY_DEVELOPER_DIR` el Xcode verificado en el preflight y ejecutar:

```sh
Scripts/validate-test-plans.sh
python3 Scripts/validate-deluxe-configuration.py
Scripts/validate-advanced-build.sh --deluxe
Scripts/validate-docc.sh
```

Para tests, seleccionar `MangaLibrary` → `ReleaseGate` y el destino concreto
mediante Xcode MCP, obtener inventario y ejecutar `RunAllTests`. Inspeccionar
el `.xcresult`, distinguir declaraciones/invocaciones y registrar cualquier
skip, fallo esperado o test no ejecutado. Restaurar después la selección previa.

## Pendientes que el gate técnico no resuelve

- **H01:** protección física antes del primer desbloqueo del iPhone; intento
  limitado/no observable. No lo sustituyen RocketSim, un estado inyectado ni
  bloquear de nuevo después de desbloquear. No tiene aplazamiento aprobado.
- **H02/H03/H04:** pairing/reconexión, suspensión/background y VoiceOver/uso
  físico del Watch. Diferidos para después de entregar el proyecto, anticipables
  con pareja compatible prestada. No se declaran aprobados ni tienen fecha fija.
- I02 adicional, arranque frío I03 y caracterización de coalescencia/reconexión
  I04 de Simulator conservan su carácter exploratorio descrito en DX6. Disponer
  de RocketSim no obliga a repetir las muestras válidas ni completa hardware.

El avance de scripts o un ReleaseGate automatizado aprobado no significa que
el **Deluxe Release Gate completo** esté verde. #90 está cerrado por su corte
técnico; #88 y #77 conservan los pendientes físicos y el seguimiento del gate.
El plan mantiene DX1–DX5 entregadas (5/7).

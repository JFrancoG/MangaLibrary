# T01–T02 — Revisión y validación de tests

Fecha: 2026-09-11. Unidad [#104](https://github.com/JFrancoG/MangaLibrary/issues/104),
rama `codex/104-t01-t02-test-oracles`, base `main@967a4aa`.

La petición del propietario autoriza implementar los 25 casos del informe:
dos retiradas T01 y 23 revisiones T02. La autoridad de comportamiento sigue en
las SDD 01/03/04/05/06/09 y los ADR aceptados; el informe no modifica contratos.
La revisión aplica `tests-de-verdad`, `swift-source-style` y `swift-concurrency`.
No constituye una nueva auditoría de las restantes declaraciones del proyecto.

## Resolución por declaración

La primera columna conserva el identificador del informe para evitar perder la
trazabilidad de los renombrados. Todos los archivos pertenecen a
`MangaLibraryTests`; se indica la suite cuando la función no es única.

| Caso original | Resolución y oráculo final |
| --- | --- |
| T01 · `CatalogAPIClientTests.pageRequestDefaultsToFirstPage` | Retirado: construcción y lectura de defaults. Se conserva `fetch` con comprobación efectiva de la petición HTTP y su paginación. |
| T01 · `SessionPersistenceStoreTests.liveStoreUsesTheVersionedNamespaces` | Retirado: comparación de cadenas de wiring. Se conservan almacenamiento real aislado, sustitución, lectura, borrado y retirada de namespaces legacy. |
| T02 · `ReadingCoverStorageTests.reader treats invalid identifiers as placeholders` | Renombrado `invalid identifiers return no cover from an empty directory`. Acredita ausencia de portada en ese directorio; no se atribuye detección de traversal con archivos adversarios. |
| T02 · `ReadingSnapshotCodecTests.constructors reject empty content and absent session` | Dos argumentos independientes: contenido vacío con sesión válida y contenido válido sin sesión. Retirar cualquiera de las condiciones deja su caso sin el error esperado. |
| T02 · `ReadingSnapshotCodecTests.nullable fields remain mandatory wire keys` | Renombrado `a nullable item title remains a mandatory wire key`. El wire elimina únicamente `title`; el nombre ya no promete comprobar todas las claves nullable. |
| T02 · `WatchReadingSnapshotStorageTests.an atomic replacement survives recreation and a discard removes it` | Renombrado sin `atomic`. Prueba reemplazo, recreación y borrado de archivos; no interrupción o lectura concurrente. |
| T02 · `invalidSignInRevealsErrorsWithoutRemoteWork` | Espera `waitForPendingOperation()` antes de comprobar ausencia de llamadas remotas; conserva errores y foco. |
| T02 · `invalidRegistrationFocusesPasswordWithoutRemoteWork` | Mismo drenaje de la operación antes de afirmar ausencia; conserva validación de contraseña y foco. |
| T02 · `nullPublishedVolumeTotalRemainsUnknown` | Exige una fila, existencia mediante `#require`, identidad 42 y total nil. Una página vacía ya falla. |
| T02 · `maximumPublishedVolumeTotalRemainsKnown` | Exige fila e identidad; esperado literal 300 independiente de la constante productiva. |
| T02 · `missingPublishedVolumeTotalRemainsUnknown` | Exige fila e identidad antes del total nil. |
| T02 · `rejectsUnsafeCover` | Cada URL inválida conserva el manga 42 sin portada; perder la fila ya no equivale a degradar la portada. |
| T02 · `sequenceExhaustionRollsBackEverything` | Readback con otro `ModelContext`: una entrada y una operación, identidad, estado local, base confirmada, metadata y fence originales. |
| T02 · `changedCloudVersionRequiresAnotherReview` | Comprueba fallo, evidencia `.absent` y contexto directamente, sin construir el esperado con `replacingEvidence`. Una segunda confirmación no invoca la capacidad. |
| T02 · `editingDuringBackoffCoalescesTheRetry` | Resultado, outbox y entrada leída en otro contexto deben contener el estado explícito con tomos `[1, 2]`; conserva UUID, secuencia y limpieza del backoff. |
| T02 · `invalidatedAuthorizationPreventsTheWrite` | Cuenta intentos de claim en su frontera y exige cero, además de ausencia de transporte y commit. |
| T02 · `existingLaterIntentReportsDurableContinuation` | Renombrado `existingLaterIntentPropagatesStoreContinuation`. Acredita propagación del resultado del store y de `.keepDevice`; no afirma persistencia N+1 desde un doble. |
| T02 · `staleAuthorityAfterGetPreventsCommit` | Primero obtiene revisión válida; la respuesta del segundo GET invalida la autoridad. Resolver debe fallar sin invocar el store, con dos GET observados. |
| T02 · `loginActivatesOnlyAfterIdentity` | Suspende la identidad remota; durante esa fase exige almacenamiento vacío, ningún save y estado signedOut. Tras liberarla conserva los oráculos finales. |
| T02 · `commitAuthorizationSerializesInvalidation` | Sustituido por `invalidationFencesSubsequentCommitEffects` con dos órdenes secuenciales. Comprueba efecto autorizado previo y ausencia de efectos posteriores a invalidación. Límite de contención explicado debajo. |
| T02 · `logoutDeletesTheCurrentSession` | Suspende el borrado de Keychain; exige que registro y estado activo permanezcan hasta liberarlo. Después verifica signedOut y registro ausente. |
| T02 · `failedKeychainDeletionDoesNotResurrectDiscardedWork` | Renombrado `failedKeychainDeletionDoesNotRepeatTheDiscard`: un retry no repite el descarte confirmado por el colaborador. No afirma readback de una outbox que este caso no crea. |
| T02 · `cancelledRestoreWaiterDoesNotCancelTheFlight` | El segundo consumidor captura el vuelo antes de cancelar el primero y liberar la identidad. Transporte cooperativo solo en este caso; primer consumidor cancelado, segundo activo, un load y un GET de identidad. |
| T02 · `accessReplacementIsConditional` | Otro actor lee Keychain tras reemplazo y rechazo. El intento obsoleto lleva credencial distinta para detectar una escritura indebida seguida de nil. |
| T02 · `activationRequiresAnEmptyAuthority` | Otro actor lee la sesión A tras cada rechazo de activación B; lanzar el error después de escribir ya no pasa. |

## Concurrencia y límites de los oráculos

La bandera anterior a `invalidate` no demostraba que el hilo hubiera intentado
adquirir el mutex. Se elimina esa afirmación temporal. La revisión de
`SessionCommitGate` comprueba que validación, efecto síncrono e invalidación
usan el mismo mutex; los dos órdenes secuenciales prueban las consecuencias
observables. **No se acredita contención concurrente en runtime.** No se cambia
el algoritmo de exclusión ni se añaden sleeps para simular esa evidencia.

`SessionController` añade únicamente el punto interno
`restorationAwaitingRestore` al observador de sincronización existente, después
de capturar el vuelo. Su implementación normal sigue siendo vacía. El segundo
consumidor del test debe alcanzar ese punto antes de liberar el GET. El loader
de este caso comprueba cancelación tras la respuesta controlada, de modo que
cancelar por error el vuelo compartido afecte al consumidor restante. Los
otros dobles mantienen sus respuestas tardías no cooperativas cuando forman
parte del contrato que prueban.

Las cinco acotaciones de nombre conservan los límites reales del caso: lectura
en directorio vacío, una clave nullable, reemplazo sin prueba de atomicidad,
propagación de continuación y ausencia de un segundo descarte. La acotación
adicional del mutex hace explícita la evidencia secuencial. No cambia ningún
requisito de persistencia, seguridad o sincronización del producto.

## Evidencia de ejecución

Xcode 27 RC `27A266a`, Swift 6.4 `swiftlang-6.4.0.34.1`, Swift 6 y concurrencia
`complete`, aislamiento predeterminado `nonisolated`. Xcode MCP confirmó el
proyecto/scheme MangaLibrary, iPhone 17 Simulator, iOS 27.0 `24A434` y Fast.

- `Scripts/validate-test-plans.sh`: 28 suites Fast y 40 Integration, partición
  disjunta válida y Fast predeterminado.
- Script aprobado `Scripts/validate-advanced-build.sh --deluxe`, con
  `MANGALIBRARY_DEVELOPER_DIR` apuntando al Xcode RC verificado: build limpio de
  cinco targets en Debug y Release, cero warnings/errores y cero tareas de
  extracción de App Intents. La validación inicial precede a los tests; la
  repetición sobre el loader final también pasa ambas configuraciones.
- `BuildProject(buildForTesting: true)` final a las 20:55:17 y
  `GetBuildLog(severity: warning)`: build correcto, cero diagnósticos. Las
  mutaciones controladas compilaron antes de ejecutarse.
- `RunAllTests` final, confirmado mediante `xcresulttool get test-results
  summary` y el árbol `test-results tests` de cada bundle:

| Plan y comienzo (Europe/Madrid) | Declaraciones aprobadas | Invocaciones aprobadas | Fallos / skips / fallos esperados / runtime warnings |
| --- | --- | --- | --- |
| Fast · 20:55:17 | 358/358 | 568/568 | 0 / 0 / 0 / 0 |
| Integration · 20:55:24 | 454/454 | 629/629 | 0 / 0 / 0 / 0 |
| Total disjunto | 812/812 | 1.197/1.197 | 0 / 0 / 0 / 0 |

Bundles finales: `Test-MangaLibrary-2026.09.11_20-55-17-+0200.xcresult` y
`Test-MangaLibrary-2026.09.11_20-55-24-+0200.xcresult`. Los artefactos y logs
completos permanecen fuera de Git. El cruce del inventario con ambos árboles
nativos confirma **23 declaraciones revisadas aprobadas** y la ausencia de
las dos retiradas. El total no suma ejecuciones repetidas ni incluye UI.

### Sensibilidad comprobada mediante regresiones compilables

| Regresión temporal en producción | Evidencia de fallo del oráculo revisado |
| --- | --- |
| `CatalogAPIClient.fetch` devuelve una página sin filas y conserva metadata | Fallan los cuatro casos de Catálogo señalados: null, máximo, campo ausente y cada portada insegura. |
| El constructor de `ReadingSnapshot.content` conserva la comprobación de items pero omite exigir sesión | Falla el argumento sin sesión y contenido válido; el caso de contenido vacío sigue rechazado. Ya no se oculta una condición detrás de la otra. |
| `SessionPersistenceActor.replaceAccess` devuelve el reemplazo sin guardarlo | `accessReplacementIsConditional` falla en los readbacks del actor nuevo, antes y después del rechazo obsoleto. |
| `awaitRestore` propaga cancelación de cada consumidor a la task compartida | `cancelledRestoreWaiterDoesNotCancelTheFlight` falla porque el segundo consumidor recibe `.unavailable`, en vez de la cuenta activa. |

La corrida Integration de las 20:50:29 detectó cinco declaraciones afectadas
por omitir el save, incluida la revisada. Fast de las 20:54:13 detectó nueve
declaraciones/18 invocaciones ante página vacía y falta de sesión. Fast de las
20:54:49 detectó exactamente una declaración/invocación ante cancelación del
vuelo. Estas corridas RED no se suman a los resultados finales. Se restauró
el contenido exacto de los cuatro archivos antes de los dos planes GREEN.
No se presenta esta muestra como una campaña de mutaciones de todos los tests.

### Incidencias de herramienta y revisión

`GetTestList` informó las 812 declaraciones como deshabilitadas;
`RunSomeTests` rechazó la selección individual. Retirar temporalmente el
filtro de etiquetas y refrescar el plan no corrigió ese inventario; el archivo
se restauró byte a byte. Se usaron planes completos mediante Xcode MCP. Una
primera corrida Fast con varias regresiones combinadas se detuvo con
`StopProject` al prolongarse las esperas; no se contabiliza como prueba de
fallo. Separar las regresiones produjo las tres corridas concluyentes descritas.
La primera variante del handler de cancelación no compilaba por capturar el
vuelo completo; se corrigió capturando solo su task antes de ejecutar el RED.

Los agregados MCP también arrastraron resultados de otro plan, incluidos
fallos de una corrida anterior. Por eso los conteos, fallos y estados finales
se obtienen de cada `.xcresult`, contrastando sus tiempos y plan. La selección
activa se devuelve a Fast y `TestPlans/Fast.xctestplan` permanece idéntico al
original.

Revisión iOS/testing independiente del diff completo, los 25 casos y helpers:
un P2 sobre cooperación de cancelación en el doble, corregido y reauditorado
sin hallazgos pendientes. Audit de estilo manual y recall sobre los 14 Swift
modificados: los 12 candidatos son previos o construcciones verticales
justificadas, sin cambios de estilo ajenos. `git diff --check` limpio.

## Alcance excluido

No se cambia UI, localización, configuración, dependencias o contratos DocC.
No se genera un nuevo archive DocC en esta unidad de tests.
Se compilan todos los targets, pero no se atribuye ejecución a UI, hardware,
VoiceOver físico, WatchConnectivity real ni backend. #77 y #88 conservan el
estado 5/7 y sus pendientes físicos. Esta unidad no cierra el Deluxe Release
Gate. Tras validar la implementación, el propietario autoriza expresamente
commit, push, PR, merge, cierre de #104 y borrado de su rama. El issue conserva
los enlaces definitivos de entrega; se reutiliza esta evidencia sin atribuir
una ejecución nueva a los cambios documentales de cierre.

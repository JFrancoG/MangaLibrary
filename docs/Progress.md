# Progreso y evidencia

**Última actualización:** 2026-09-02
**Estado general:** G0, Catálogo C1–C4, D1, Q1, P1, Library Red, S1, S2, S2.1, S2.2, L1, L2 y R1 entregados; R1 se incorpora mediante la PR #54

## Lectura e importación remota R1 — issue #53

- El [issue #53 — R1: implementar lectura e importación remota de Colección](https://github.com/JFrancoG/MangaLibrary/issues/53) se abrió después de comprobar que no existían issues, PR o ramas equivalentes. La rama `codex/53-r1-remote-collection-import` parte de `main@a68a3ecc40387dad519ea35ef115f13f0e5b988f`, limpio y sincronizado con `origin/main` en el preflight aprobado.
- `/docs` volvió a descubrir `/openapi/openapi.json`. Su forma canónica saneada coincide con el snapshot versionado y conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no se realizó una petición funcional autenticada ni se usaron cuentas, tokens o datos live.
- R1 consume únicamente `GET /collection/manga` con Bearer vigente y status exacto `200`, reutiliza el DTO real de Manga e interpreta el array como snapshot remoto completo. La raíz estable lo inicia al restaurar o confirmar sesión, sin esperar a que se visite Colección, y la UI continúa observando exclusivamente SwiftData mediante `@Query`.
- El coordinador mantiene la red fuera de `CollectionMutationActor`, propaga cancelación y exige que la misma generación siga autorizada antes de aplicar. La importación valida el lote entero y usa la instancia compartida del actor y un único commit; error, deriva, duplicado, cancelación o fallo de persistencia conservan store y outbox previos.
- Sin intención pendiente, una presencia remota sustituye estado, base confirmada y presentación; con intención pendiente solo actualiza base y presentación. Una ausencia retira únicamente estado confirmado sin pendiente, conserva y registra la base ausente cuando hay pendiente y falla cerrado ante un huérfano sin confirmación ni outbox.
- R1 valida el UUID remoto pero reconcilia por usuario + manga y no persiste ni interpreta todavía ese UUID como `{id}`. `POST`, `DELETE`, GET individual, worker, envío, retry, transiciones `blockedAuth`/`blockedOutcome`, reversión, UI de conflictos, escrituras live y todo Deluxe permanecen fuera y corresponden a R2 o fases posteriores.

### RED / GREEN y validación local de R1

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial falla al compilar por la ausencia deliberada de las superficies R1. El GREEN focal cubre request, DTO, importación, rollback, sesión y carreras; las regresiones finales de logout/401, payload, `401`/`403`, cancelación postmutación y trigger UI aprueban sus selecciones sin fallos. Todos los tokens, UUID, respuestas y containers son sintéticos. |
| Contrato e invariantes | `/docs` descubre el OpenAPI vivo y el snapshot saneado conserva el mismo hash. La ruta rechaza UUID o manga duplicados, UUID wire o enums malformados, identidad y volúmenes no positivos, valores superiores al total, complete sin total, huérfanos y fallo o cancelación parcial; el store y la outbox se comparan desde otro contexto después del rollback. |
| Sesión y concurrencia | La gate de commit linealiza invalidación y transacción sin cruzar procesos. Los tests cubren A→B y ABA, refresh concurrente, rechazo ligado a generación + access exactos, logout fallido concurrente con `401`, sustitución de vuelo, trigger precancelado y mutación local suspendida. |
| Xcode MCP — build y diagnósticos | Build-for-testing final aprobado en 3,625 s sobre iPhone 17 Simulator con iOS 27. El log estructurado y el Issue Navigator devuelven cero warnings y cero errores. |
| Xcode MCP — `ReleaseGate` | 293/293 resultados aprobados, sin fallos, skips, expected failures o casos no ejecutados. Incluye el flujo UI Debug que confirma login sintético → trigger R1 → fila remota observada por `@Query` y después una mutación local por la capacidad de producción; no usa red, Keychain ni disco live. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente una emisión externa acotada por ADR 0011 para Xcode build `27A5252f`. El archive permanece local y no se publica. |
| Integridad y estilo | `git diff --check` y el Audit del diff Swift quedan limpios. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`; no cambian test plans, targets, dependencias ni entitlements. Xcode queda restaurado al scheme `MangaLibrary`, plan `Fast` y destino iPhone 17 Simulator. |
| Revisiones independientes | Las revisiones finales iOS/arquitectura/concurrencia y especificación/tests cierran sin hallazgos P0–P3 sobre el snapshot validado. La revisión SwiftUI/accesibilidad no encuentra cambios visuales o semánticos que justifiquen render; no se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado ni Accessibility Inspector. |

### Riesgo transversal y estado de entrega de R1

SDD 03 exige que una colección completa materialice `1...total`, pero el contrato
no publica un máximo para `totalVolumes`. Un total positivo extremo puede agotar
recursos en R1 y en las rutas L1/L2 preexistentes que aplican la misma invariante.
Fijar una cota solo en R1 inventaría una política incoherente; su resolución
requiere una decisión normativa transversal, error tipado y cobertura local,
remota y de UI. No se oculta como gate superado ni se amplía este diff con una
cota arbitraria.

La implementación se versiona inicialmente en `6298255` y se entrega mediante la
[PR #54](https://github.com/JFrancoG/MangaLibrary/pull/54), cuya fusión cierra el
issue #53. El cierre autorizado incluye retirar después la rama local y remota.

## Limpieza de conformidades `Sendable` redundantes — issue #51

- El [issue #51 — retirar conformidades Sendable explícitas redundantes](https://github.com/JFrancoG/MangaLibrary/issues/51) no tenía un issue, PR o rama equivalente. La rama `codex/51-remove-redundant-sendable-conformances` partió de `main@202d2f73489bfbae415bf88a651348d93357f22c`, limpio y sincronizado con `origin/main`. La implementación se entrega mediante la [PR #52](https://github.com/JFrancoG/MangaLibrary/pull/52).
- El inventario completo de 78 archivos Swift identificó 42 conformidades explícitas redundantes en tipos de valor internos: 32 en 10 archivos de producto y 10 en 5 archivos de tests. Swift 6.4 infiere esas conformidades porque todos sus miembros o valores asociados son enviables, por lo que retirarlas no cambia comportamiento, API interna, aislamiento ni persistencia.
- Permanecen exactamente las tres clases sincronizadas de tests que necesitan declarar `Sendable`: `ControlledSessionPersistenceStorage`, `SynchronousPersistenceGate` y `TestSessionClock`. También se conservan todos los atributos `@Sendable` de closures y typealiases que expresan fronteras concurrentes reales.
- La regla ya está recogida por `ios-development-standards`, `swift-concurrency` y el gate independiente de `review-ios-standards`: los `struct` y `enum` internos confían en la inferencia y una conformidad explícita requiere una frontera pública o genérica demostrada. No se modifica ninguna skill, SDD o ADR.

### Validación local de la limpieza `Sendable`

| Herramienta y acción | Resultado |
| --- | --- |
| Inventario estructural | Cero conformidades explícitas restantes en `struct` o `enum`; exactamente tres clases justificadas. Los atributos `@Sendable` coinciden con `main` y no existen `@unchecked Sendable`, `@preconcurrency` o `nonisolated(unsafe)`. |
| Xcode MCP — build y diagnósticos | Build aprobado sobre iPhone 17 Simulator con iOS 27; log estructurado e Issue Navigator con cero warnings y cero errores. El proyecto conserva Swift 6, concurrencia estricta completa, aislamiento predeterminado `nonisolated` y warnings como errores. |
| Xcode MCP — `ReleaseGate` | 241/241 casos aprobados, sin fallos, skips, expected failures o casos no ejecutados. No se añaden tests que solo comprueben una conformidad inferida por el compilador, de acuerdo con SDD 06. |
| Revisiones independientes | Las auditorías iOS/concurrencia, gobernanza e inventario y `swift-source-style` cierran sin hallazgos. La revisión SwiftUI/accesibilidad no aplica porque no cambia ninguna View, recurso ni semántica de presentación. |
| Integridad y restauración | El diff funcional queda limitado a 15 archivos Swift y la entrada obligatoria de changelog; `git diff --check` está limpio y no cambian `project.pbxproj`, test plans, targets, dependencias o entitlements. Xcode queda restaurado al scheme `MangaLibrary`, plan `Fast` y destino iPhone 17 Simulator. |

La implementación se versiona inicialmente en `0d39c67` y se entrega mediante la [PR #52](https://github.com/JFrancoG/MangaLibrary/pull/52), cuya fusión cierra el issue #51. El cierre autorizado incluye retirar después la rama local y remota. R1, R2 y las capacidades Deluxe permanecen como unidades separadas.

## Colección local y offline L2 — issue #49

- El [issue #49 — L2: implementar Colección local y offline](https://github.com/JFrancoG/MangaLibrary/issues/49) no tenía issues, PR o ramas equivalentes. La rama `codex/49-l2-offline-collection` partió de `main@3fe8b236f68d08b2174cb907f2c332061e49a812`, limpio y sincronizado con `origin/main`. El propietario aprobó las seis decisiones, el plan y después el cierre completo el 2026-09-01. La implementación se entrega mediante la [PR #50](https://github.com/JFrancoG/MangaLibrary/pull/50).
- `MangaLibrarySchema.V2` añade a Colección un snapshot `Codable` de presentación offline y conserva V1 congelado dentro de un plan explícito de migración lightweight `1.0.0 → 2.0.0`. Una entrada migrada sin snapshot muestra ausencia explícita y su `mangaID`; no inventa datos de Catálogo. El composition root continúa creando una sola vez el `ModelContainer` live y el mismo `CollectionMutationActor`.
- La capacidad `@ModelActor` acepta el comando completo del editor por valores `Sendable`, valida el snapshot de la primera alta y extiende la única transacción semántica a reemplazo integral, reactivación y eliminación. Colección y outbox se guardan o coalescen juntas; eliminar persiste una tombstone y su intención, sin `insert`, `delete` o `save` desde una View.
- La raíz de Colección usa `@Query` con predicate de store por usuario y `isTombstone == false`. Posee `NavigationStack` compacto y `NavigationSplitView` regular, selección propia por `Manga.ID` y limpieza al cambiar de identidad. El alta reutiliza el detalle de Catálogo ya cargado; no añade búsqueda, segunda autoridad, router global, Repository o UseCase.
- `authenticationRequired`, reautenticación con identidad conocida y `signingOut` conservan lectura con mutaciones bloqueadas. Restauración, fallo de restauración, autenticación sin identidad y `signedOut` muestran indisponibilidad explícita. `CollectionMutation` relee `AccountModel` justo antes de enviar al actor, por lo que solo la cuenta autenticada coincidente puede crear trabajo `queued`.
- El DTO caracteriza `volumes` nullable: solo un entero positivo se convierte en total conocido. El editor conserva tomos exactos y huecos; usa selección con total conocido y entrada numérica validada cuando es desconocido, mantiene lectura independiente y solo permite completar cuando existe un total válido.
- En el editor con total conocido, `isComplete` deja de duplicar estado y se deriva del conjunto de tomos. Marcar el último tomo activa “Colección completa”, retirar cualquiera la desactiva y el control actúa como selección total: al apagarlo vacía los tomos del borrador sin alterar la lectura. El guardado continúa usando la única mutación atómica de Colección y outbox.
- Cada preview con SwiftData crea mediante `PreviewModifier` un único container V2 real y aislado para su escenario; `@Query` y la capacidad de producción comparten ese container. Los subcomponentes sin persistencia no crean infraestructura ceremonial. Los fixtures son locales y nunca alcanzan red, Keychain, cuentas o disco live.
- En el detalle, `Mi colección` usa un `DisclosureGroup` nativo, expandido por defecto y con un objetivo vertical mínimo de 44 pt. Los mensajes vacío, sin sesión y de solo lectura quedan centrados; las acciones son botones prominentes grandes, centrados y solo con texto. Cada fila prueba primero etiqueta y valor en horizontal y, cuando el valor no cabe —como una propiedad extensa—, `ViewThatFits` conserva la lista completa bajo su etiqueta; en tamaños de accesibilidad todas se apilan. El editor sustituye Cancelar y Guardar por `xmark` y `checkmark` en la toolbar nativa, sin material manual, y mantiene sus nombres localizados, identificadores y progreso accesibles.
- L2 no incorpora R1/R2, endpoints, importación, worker, retry, reconciliación, estados remotos nuevos, entitlements, App Group, CloudKit, WidgetKit, watchOS ni targets adicionales.

### RED / GREEN y validación local de L2

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial falla al compilar por la ausencia deliberada de las superficies L2. El GREEN original selecciona 39 declaraciones focales de Colección y obtiene 44/44 resultados. La regresión posterior del control “Colección completa” reproduce ambos defectos con 0/2 y queda en 2/2; las nueve declaraciones del modelo aprueban 9/9. Usa containers V2 reales en memoria y stores temporales en disco, sin sleeps, serialización artificial, red, Keychain o datos live. |
| Invariantes, autorización y atomicidad | Los oráculos cubren canonicalización también por `replaceState`, valores inválidos y rollback, unicidad, A/B, todos los estados no autenticados, guard/éxito/fallo del borrado del editor, coalescencia, tombstone y reactivación con `desiredState` vigente. |
| Migración y reapertura | Un store V1 temporal migra campo a campo a V2 conservando Colección y outbox y dejando el snapshot ausente. Otro store real demuestra alta A/B, edición no tombstone, aislamiento, eliminación y consultas activas después de tres reaperturas. |
| Xcode MCP — build y diagnósticos | Build-for-testing final aprobado en 3,449 s sobre iPhone 17 Simulator con iOS 27. Los diagnósticos focales de `CollectionStateSummary.swift`, `CollectionEditorView.swift` y `MangaLibraryUITests.swift`, además del resultado estructurado del build, devuelven cero incidencias. |
| Xcode MCP — `ReleaseGate` | El snapshot final ejecuta y aprueba 241/241 casos: cero fallos, skips, expected failures o casos no ejecutados. Incluye los cinco smokes UI; el detalle sin sesión verifica expandir y contraer `Mi colección`, y el flujo autenticado cubre Catálogo → detalle → mutación de producción → fila observada por `@Query`. Ese flujo aprueba también 1/1 de forma focal después de exigir los nombres accesibles Cancelar/Guardar de los botones icon-only. |
| Xcode MCP — previews | Tras hacer al trait autoridad del único container, se rerenderizan e inspeccionan sin errores shell EN, contenido y vacío aislados, editor con total EN y entrada V1 migrada ES en AX 3 sobre iPhone 17 Pro. Las cuatro variantes de la tarjeta —contenido, vacío, sin sesión y solo lectura— se inspeccionan además en Large, XXX Large y AX 5; EN/AX 5 y Dark + Increased Contrast/Large permanecen sin truncado, solapamiento o pérdida de acciones. La regresión visual añade una propiedad de 15 tomos e inspecciona su resumen en español Dark con Large, XXX Large y AX 5: conserva la lista completa y alinea el resto de filas. El editor se inspecciona en las mismas tres escalas y también en Dark + Increased Contrast; AX 5 detecta que una `Image` desnuda podía perder Guardar, y la repetición final con un `Label` icon-only mantiene `xmark`, título y `checkmark` visibles. La matriz editorial anterior cubrió también total desconocido, título largo e iPad landscape. No se ejecutaron VoiceOver, Voice Control, Switch Control, Acceso total con teclado ni Accessibility Inspector. |
| String Catalog | `Localizable.xcstrings` contiene 176 claves, cero valores ausentes en inglés o español, cero comentarios vacíos y cero entradas stale. La única traducción idéntica es `No`, correcta en ambos idiomas. La herramienta de traducción especializada no estaba expuesta; el JSON se editó de forma conservadora y se validó con `jq`. |
| `Scripts/validate-docc.sh` | Ocho escenarios del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente una emisión externa acotada por ADR 0011 para Xcode build `27A5252f`. El archive permanece local y no se publica. |
| Revisiones independientes | Las revisiones iOS/arquitectura, datos/concurrencia, tests, SwiftUI/accesibilidad y el Audit final de `swift-source-style` cierran sin hallazgos. Los revisores hicieron cerrar oráculos de reapertura, autorización y editor, detectaron antes del cierre el segundo container ceremonial de previews y reauditaron el layout adaptativo, la toolbar icon-only y sus labels sobre el snapshot final. |
| Integridad y restauración | `git diff --check` queda limpio, no hay cambios en `project.pbxproj`, test plans, dependencias, targets o entitlements, y no existe contenido staged. Tras el último ajuste visual, Xcode queda restaurado al scheme `MangaLibrary`, plan `Fast` y destino iPhone 17 Simulator vigentes al iniciarlo. |

### Estado de entrega de L2

La implementación se entrega mediante la [PR #50](https://github.com/JFrancoG/MangaLibrary/pull/50), cuya fusión cierra el issue #49. El cierre autorizado incluye retirar después la rama local y remota. R1, R2 y las capacidades Deluxe siguen siendo unidades separadas.

## Simplificación contextual de recursos Color — issue #47

- El [issue #47 — eliminar wrappers Color innecesarios en SwiftUI](https://github.com/JFrancoG/MangaLibrary/issues/47) no tenía issues ni PR equivalentes. La rama `codex/47-remove-redundant-color-wrappers` partió de `main@4df94b8bc480d56bf7d1cf76d4b6021c00672432`, limpio y sincronizado con `origin/main` después de entregar #45. La implementación se entrega mediante la [PR #48](https://github.com/JFrancoG/MangaLibrary/pull/48).
- El inventario completo de 61 archivos Swift localiza 55 wrappers `Color(.token)` en 11 archivos de producción y ninguno en tests. Xcode 27 confirma 40 miembros contextuales seguros para `foregroundStyle`, `background` y `strokeBorder`; los nueve `tint` necesitan `Color.token` para conservar el overload genérico `ShapeStyle`, y los seis `listRowBackground(Color(.canvas))` necesitan `Color.canvas` porque `.canvas` no permite inferir su `View` genérica. Los cuatro `listRowBackground(Color.clear)` existentes expresan esa misma necesidad de tipo y se conservan.
- La implementación sustituye exactamente los 55 wrappers sin cambiar el asset semántico, el modificador, los argumentos, el orden del árbol SwiftUI, los traits o el comportamiento visual intencionado. No modifica tests, assets, String Catalogs, SDD, ADR, arquitectura, configuración Xcode ni `project.pbxproj`, y no introduce una regla textual global.

### Validación local de la simplificación Color

| Herramienta y acción | Resultado |
| --- | --- |
| Inventario y equivalencia estática | Transformación exacta en 11/11 archivos: 55 eliminaciones se corresponden con 40 miembros contextuales, nueve `Color.token` en `tint` y seis `Color.canvas` en `listRowBackground`; quedan cero `Color(.token)` y se conservan cuatro `Color.clear`. `git diff --check` termina limpio. |
| Xcode MCP — diagnósticos focalizados | Los 11 archivos Swift modificados actualizan sus diagnósticos con éxito y devuelven cero incidencias. |
| Xcode MCP — build | Tras corregir los nueve `tint`, build-for-testing de `ReleaseGate` aprobado en 0,711 s sobre iPhone 17 Pro Simulator con iOS 27; cero warnings o errores en el log estructurado. |
| Xcode MCP — `ReleaseGate` | En el snapshot corregido, los 198 casos Swift Testing aprueban en las dos ejecuciones completas. La primera queda en 201/202 porque el smoke histórico de registro no encuentra `tab.account` tras lanzar la app y aprueba 1/1 al repetirlo; la segunda queda en 200/202 por el mismo fallo de arranque en los dos smokes de Cuenta, que aprueban juntos 2/2 al repetirlos sin cambios. No se realizan más repeticiones UI ni se presenta el gate como 202/202 limpio. |
| Xcode MCP — previews | Antes de la corrección de overload, 16/16 snapshots representativas se renderizan e inspeccionan sin errores para shell, Cuenta autenticada, Catálogo y detalle: iPhone en Light/Large, Dark/XXX Large y Dark + Increased Contrast/AX 5, además de iPad en Light + Increased Contrast/Large. La corrección final conserva los mismos recursos y el overload original, compila limpia y no vuelve a renderizarse para evitar validación UI desproporcionada. No se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado o Accessibility Inspector y no se atribuye esa cobertura. |
| Revisiones independientes | Las reauditorías iOS, SwiftUI/accesibilidad y `swift-source-style` cierran sin hallazgos sobre el diff Swift final `75ad23e…`. La revisión SwiftUI detecta antes del cierre que nueve miembros desnudos en `tint` seleccionaban `tint(Color?)`; la corrección a `Color.token` restaura el overload genérico `tint<S: ShapeStyle>` del código original. El `ReleaseGate` UI no limpio permanece documentado como limitación ajena al diff, no como gate completo superado. |
| Restauración Xcode | Scheme `MangaLibrary`, destino físico iPhone 11 y plan `Fast` restaurados y verificados después de la validación. |

La implementación se versiona inicialmente en `4dbfeed` y se entrega mediante la [PR #48](https://github.com/JFrancoG/MangaLibrary/pull/48), cuya fusión cierra el issue #47. El cierre autorizado incluye retirar después la rama local y remota.

## Normalización histórica de layout Swift — issue #45

- El [issue #45 — normalizar el layout Swift histórico](https://github.com/JFrancoG/MangaLibrary/issues/45) no tenía duplicados. La rama `codex/45-normalize-swift-source-style` partió de `main@5a78084c6c2a`, limpio y sincronizado con `origin/main` después de entregar L1. La implementación se entrega mediante la [PR #46](https://github.com/JFrancoG/MangaLibrary/pull/46).
- El normalize repositorio-wide de `$ios-development-kit:swift-source-style` inventaría 61/61 archivos Swift y modifica 44: 30 de aplicación, 13 de tests y uno de UI tests. Una segunda auditoría exhaustiva corrige omisiones sistemáticas de la primera pasada en previews, result builders, llamadas anidadas, tests y fixtures; ningún archivo o categoría queda exento y cada construcción se juzga de forma independiente. Se conservan verticales closures, function types, construcciones de cuatro o más argumentos, condiciones complejas y excepciones donde el formato horizontal superaría 120 columnas o reduciría claridad.
- El cambio es exclusivamente lexical: no modifica tokens, strings, comentarios, interpolaciones, operadores, overloads, orden de evaluación o comportamiento. Tampoco cambia `project.pbxproj`, assets, String Catalogs, contratos, arquitectura, persistencia o tests. La simplificación contextual de wrappers como `Color(.brandPrimary)` quedó expresamente fuera de esta entrega y se aborda como unidad semántica separada mediante el [issue #47 — eliminar wrappers Color innecesarios en SwiftUI](https://github.com/JFrancoG/MangaLibrary/issues/47).

### Validación local de la normalización

| Herramienta y acción | Resultado |
| --- | --- |
| Integridad Swift | Los 44 archivos coinciden con `HEAD` al eliminar whitespace. Ambos snapshots parsean y producen la misma salida canónica de `swift-format` con 120 columnas y sin conservar saltos existentes; no cambian literales, comentarios, identificadores, firmas, operadores ni puntuación. El diff Swift es `+487/-1632`, con SHA-256 `06bb784f0c252f09d3cbde848690ca7d97e28a3968b9503f64465daab7905251`. |
| Xcode MCP — build | Build-for-testing final de `ReleaseGate` aprobado en 3,711 s sobre iPhone 17 Pro Simulator con iOS 27. El log estructurado contiene cero warnings y cero errores. |
| Xcode MCP — `ReleaseGate` | El snapshot final ejecuta y aprueba 202/202 casos: cero fallos, skips, expected failures o casos no ejecutados. |
| Revisiones independientes | La reauditoría final de estilo cierra sin hallazgos después de adjudicar los 41 candidatos del detector de recall; permanecen solo excepciones justificadas por closures, function types, construcciones de cuatro o más argumentos, cadenas semánticas, predicates y tuplas complejas. La auditoría semántica confirma equivalencia canónica 44/44. La revisión SwiftUI/accesibilidad comprueba estáticamente 39/39 previews afectadas y no encuentra cambios en árboles declarativos, textos, colores, identificadores o semántica. No se renderizan previews ni se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado o Accessibility Inspector; no se atribuye cobertura runtime. |
| Integridad del repositorio | `git diff --check` queda limpio y no hay archivos staged. Solo permanecen tres líneas visuales superiores a 120: la regex de email y dos fixtures JSON atómicas; las tres son excepciones deliberadas. Xcode queda restaurado al destino físico iPhone 11 y al plan `Fast` encontrados en el preflight. |

La implementación se versiona inicialmente en `b4a54e0` y se entrega mediante la [PR #46](https://github.com/JFrancoG/MangaLibrary/pull/46), cuya fusión cierra el issue #45. El cierre autorizado incluye retirar después la rama local y remota. La limpieza semántica de wrappers `Color(...)` se ejecuta como unidad posterior y separada mediante el [issue #47](https://github.com/JFrancoG/MangaLibrary/issues/47).

## Núcleo SwiftData de Colección L1 — issue #41

- El [issue #41 — L1: núcleo SwiftData de Colección y outbox atómica](https://github.com/JFrancoG/MangaLibrary/issues/41) no tenía duplicados. La rama `codex/41-l1-swiftdata-collection-core` partió de `main@2d5cb06bd879eb2876ea30e93438fe89a33e7df7`; el merge previo solo añadió gobernanza de estilo y no alteró Swift, proyecto o contratos de L1. La implementación se entrega mediante la [PR #44](https://github.com/JFrancoG/MangaLibrary/pull/44).
- `AppComposition.live()` crea un único `ModelContainer` persistente y un único `CollectionMutationActor` sobre ese container. `MangaLibraryApp` conserva ambos durante la vida de la app y adjunta el container al `Scene`; la ruta sintética de UI crea una sola composición equivalente en memoria. No se añade un singleton global ni un service locator.
- `MangaLibrarySchema.V1` declara versión `1.0.0`, modelos anidados y un `SchemaMigrationPlan` explícito sin etapas porque no existe un esquema de producto anterior. La configuración desactiva explícitamente App Group y CloudKit. Los aliases vigentes permiten usar los tipos actuales sin hacer mutable retrospectivamente el esquema V1.
- Colección refuerza la identidad compuesta usuario + manga y persiste volúmenes propios canónicos, progreso independiente, total conocido, estado completo, último snapshot confirmado y tombstone. Outbox conserva UUID, identidad compuesta, secuencia monotónica, estado deseado, los siete estados normativos, reintento y tombstone, con constraints de unicidad propios.
- `CollectionMutationActor.apply` recibe comando y UUID por valor `Sendable`, valida identidad, total, propiedad, lectura y colección completa, y devuelve solo un snapshot por valor. Una única transacción actualiza o crea Colección y crea o coalesce exclusivamente la operación `queued` de la misma pareja. Una operación `sending` permanece intacta y la siguiente intención conserva orden independiente. Cualquier validación, cancelación observada, agotamiento de secuencia, colisión de UUID o fallo de persistencia ejecuta rollback explícito.
- La implementación no introduce Repository, UseCase, protocolos, mappers o stores ceremoniales. Tampoco incorpora `@Query`, UI de Colección, worker, reconciliación remota, requests, entitlements, App Group, WidgetKit o watchOS.

### RED / GREEN y validación local de L1

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial falló al compilar por la ausencia deliberada de esquema, modelos, comando y actor. GREEN ejecuta 21 invocaciones focales con un `ModelContainer` V1 real y aislado en memoria por caso, y verifica el resultado desde otro `ModelContext`: 21/21 aprobadas en el iPhone 11 físico con iOS 27. |
| Invariantes y aislamiento | Se cubren identidad de manga, total y volúmenes positivos, límites del total, orden y deduplicación, lectura independiente, semántica completa, cambios de total incompatibles, unicidad del constraint, dos usuarios con el mismo manga y un usuario con mangas distintos. |
| Outbox y atomicidad | Se prueban coalescencia con UUID estable y secuencia creciente, preservación de `sending`, nueva `queued`, colisión de UUID entre identidades, concurrencia serializada, rollback postmutación por agotamiento de secuencia y un guardado posterior limpio. La cancelación se caracteriza antes del commit; no se introduce un hook de producción ni un test dependiente de timing para forzar exactamente el checkpoint posterior a la mutación. |
| Xcode MCP — build y `ReleaseGate` | Build-for-testing final aprobado en 2,259 s con warnings como errores. `ReleaseGate` aprueba 202/202 en iPhone 17 Pro Simulator con iOS 27: cero fallos, skips, expected failures o casos no ejecutados. Una repetición final obtiene 201/202 por el smoke histórico de alta de Cuenta, que aprueba 1/1 al repetirlo sin cambios; los 21 casos L1 pasan en ambas ejecuciones completas. En el destino físico, L1 aprueba 21/21 focales; el gate completo obtiene 191/195 porque tres tests históricos de color intentan leer desde el dispositivo un JSON del checkout y otro smoke de Cuenta falla su aserción. Ninguno de esos fallos pertenece a L1. |
| `Scripts/validate-docc.sh` | Ocho escenarios del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011. El archive permanece local y no se publica. |
| Planes y clasificación | La suite usa el tag `integration`. El plan `Integration` descubre las declaraciones nuevas pero las mantiene deshabilitadas por la regresión transversal ya registrada; no se presenta como una ejecución independiente. `ReleaseGate` sí las habilita y ejecuta. |
| Revisiones independientes | Arquitectura, SwiftData, concurrencia y composición cierran sin hallazgos. La revisión de tests detectó y cerró cobertura de mangas distintos, `sending` y bordes de total/lectura; conserva como límite honesto el checkpoint exacto de cancelación postmutación. El Audit final de `swift-source-style` cierra sin hallazgos en los seis Swift de L1. |

### Estado de entrega de L1

La implementación se versiona inicialmente en `f2b0b10` y se entrega mediante la [PR #44](https://github.com/JFrancoG/MangaLibrary/pull/44), cuya fusión cierra el issue #41. El cierre autorizado incluye retirar después la rama local y remota. L2 y cualquier integración remota o Deluxe requieren unidades y autorizaciones posteriores.

## Corrección de persistencia de sesión — 2026-09-01

- Durante el login manual posterior al alta, el diagnóstico local saneado alcanzó la activación de sesión y registró `stage=write-ledger` con `code=file-system-failure`. Esa evidencia sitúa el fallo histórico en la escritura del ledger de Application Support, después del pipeline remoto refresh → access → `/me`; no registra status HTTP, email, credenciales, tokens, payloads ni rutas privadas.
- La corrección posterior no reescribe la entrega original de S1 mediante la PR #34, documentada más abajo. Sustituye en el estado vigente el ledger y los bundles Keychain V1 por un único ítem Keychain V2 `WhenUnlockedThisDeviceOnly`, no sincronizable y con `kSecAttrAccount = current-session`, fijo y no identificador. Su valor versionado reúne UUID, generación, access y refresh con sus expiraciones; no persiste email, contraseña o roles. La limpieza también retira el namespace Keychain V1 conocido.
- Login activa una generación únicamente después de guardar el registro completo. Refresh reemplaza el mismo ítem solo si continúa perteneciendo a la generación esperada y conserva el refresh vigente; un fallo de escritura deja intacta la sesión anterior.
- Logout relee y compara UUID y generación antes de borrar. Solo publica `signedOut` cuando la eliminación condicionada termina; un fallo conserva la sesión activa y permite repetir logout. Una eliminación o refresh tardíos de A se convierten en no-op cuando B ya es la autoridad.
- Un refresh expirado o rechazado permanentemente deja de autorizar inmediatamente la generación en memoria y proyecta `authenticationRequired(userID)`. Después intenta retirar su registro; si Keychain falla, la incidencia permanece visible y el proceso no vuelve a entregar el access rechazado, aunque el envelope residual solo podrá distinguirse tras relanzar mediante otra revalidación remota. Sin registro, la restauración termina en `signedOut`.
- Las pruebas actualizadas separan capacidades deterministas y Keychain sintético: cubren escritura completa, reemplazo V2 con un solo ítem, atributos no identificadores, corrupción fail-closed, indisponibilidad sin falsa salida, refresh condicionado, borrado reintentable, limpieza del namespace legacy y protección frente a efectos tardíos. No usan cuentas, tokens o red live.

### Validación de la corrección de sesión

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | Las regresiones reprodujeron que persistían varias generaciones, que un rechazo permanente podía seguir entregando la sesión si fallaba su limpieza y que el envelope residual impedía una nueva autenticación. GREEN conserva un solo registro V2, invalida inmediatamente la generación rechazada y permite sustituir únicamente ese residual exacto. Las caracterizaciones finales añaden relanzamiento con registro presente y ausente, cancelación posterior al commit de borrado y exclusión determinista de un login B mientras logout elimina A. |
| Xcode MCP — build y `ReleaseGate` | El snapshot final compila con warnings como errores y ejecuta 181/181 casos en iPhone 17 Simulator con iOS 27: cero fallos, skips, expected failures o casos no ejecutados. |
| Xcode MCP — iPhone 11 físico | 30/30 casos de sesión aprobados en iOS 27. Incluyen el propietario de sesión, serialización, fallos inyectados y el service Keychain V2 sintético con atributos protegidos; no usan credenciales, cuenta o red live. El build normal y el lanzamiento del producto se repiten después del gate para dejar instalada la versión comprobada. |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y exactamente la emisión externa autorizada por ADR 0011. El archive permanece local y no se publica. |
| Revisiones independientes | La revisión SwiftUI/accesibilidad no encuentra regresiones en Cuenta. La revisión iOS cierra la reutilización del token rechazado, la reautenticación sobre un residual exacto, los inicializadores redundantes y la exclusión A/B; conserva como límites explícitos el relanzamiento offline tras un borrado fallido y los artefactos inertes de instalaciones anteriores. |

La instalación física demuestra build, lanzamiento y las integraciones sintéticas
anteriores; no demuestra por sí sola login, logout, AutoFill, dispositivo bloqueado,
VoiceOver, Voice Control, Switch Control, Acceso total con teclado, landscape o
multitarea. El propietario confirmó por separado un login live correcto; no se ha
comprobado manualmente el logout ni se registran datos de esa cuenta.

## Formularios de credenciales S2.2 — issue #39

- La implementación se versiona inicialmente en `190dea2` y se entrega mediante la [PR #40](https://github.com/JFrancoG/MangaLibrary/pull/40), cuya fusión cierra el [issue #39 — S2.2: completar Cuenta, alta HTTP y sesión segura](https://github.com/JFrancoG/MangaLibrary/issues/39); el cierre autorizado incluye retirar después la rama local y remota.
- La rama `codex/39-s22-credential-forms` nació desde `main@289fff7ad54c50b5459a9d834bcdec97875694b5`. Antes del primer commit, el issue se reconcilió con HTTP, Keychain, logout, estado autenticado y el criterio final `.fitted` aprobados durante la validación.
- SDD 01 v1.4 y SDD 04 v1.13 mantienen una gramática conservadora de email compartida y definen una instancia observable por presencia de cada formulario. ADR 0017 versiona la frontera de respuesta HTTP con status y conserva el resto de decisiones adaptativas de ADR 0015. Login exige contraseña no vacía y alta conserva el mínimo de ocho caracteres; ninguna entrada inválida inicia trabajo remoto.
- `AccountModel` conserva la política tipada y la autoridad compartida de sesión/workflow. `SignInViewModel` y `RegisterViewModel` poseen borradores, presentación de errores, visibilidad, intención de foco, tarea y limpieza; las Views conservan bindings y el adaptador `@FocusState`. Cada modelo es una instancia por presencia de pantalla creada y retenida con `@State`; `AccountRoute` continúa siendo solo un valor de navegación.
- `SecureField` y `TextField`, ambos de SwiftUI, comparten el mismo `Binding` y `textContentType`; casos de foco diferenciados trasladan el foco modelado al alternar presentación oculta y visible sin introducir UIKit. La credencial desactiva capitalización y autocorrección y continúa limpiándose al enviar o abandonar.
- Iniciar sesión y Crear cuenta usan acciones primarias nativas, grandes, centradas y ajustadas al contenido mediante `.buttonSizing(.fitted)`, sin fijarlas al borde inferior ni conservar el fondo automático de la fila. Crecen con Dynamic Type y mantienen los márgenes de iOS sin imponer un ancho o una altura rígidos. Email y contraseña comparten una superficie de al menos 48 pt, radio continuo de 12 pt y `ControlBorder`; el control de visibilidad conserva un objetivo mínimo de 44 pt. Inglés y español, previews y los dos smokes sintéticos existentes cubren la superficie sin añadir un quinto recorrido UI.
- El propietario realizó manualmente un alta live en el iPhone 11 y observó `201 Created`, coherente con el enunciado pero no con el OpenAPI vivo, que continúa declarando solo `200` con `integer/int64`. No se registra email, `App-Token`, body ni otro dato de la cuenta. `HTTPClient` conserva su API de status único y añade una respuesta validada para que Registro acepte exactamente `200` y `201`: el primero exige el `Int64` publicado y el segundo confirma sin depender de un body no caracterizado; `202` y cualquier otro status siguen sin confirmar.
- La incertidumbre real se presenta una sola vez dentro de Crear cuenta, sin código HTTP ni detalle técnico redundante. Sus dos acciones forman el único par contiguo del flujo: `ViewThatFits` las presenta con igual reparto horizontal cuando caben y las refluye centradas y ajustadas al contenido cuando la localización o Dynamic Type necesitan una columna. Volver muestra el landing inicial de Cuenta sin borrar la protección del workflow; al entrar otra vez en Crear cuenta reaparece el resultado y solo la acción explícita de reintento permite preparar otro `POST`.
- El estado autenticado deja de presentar datos y logout como filas automáticas de `Form`: muestra el estado de sesión, el email seguro en una tarjeta vertical y cualquier aviso en una tarjeta independiente. `Cerrar sesión` continúa siendo un `Button(role: .destructive)` nativo y prominente mediante `DangerFill`/`OnDanger`, pero queda solo con texto, centrado y `.fitted`, igual que las acciones aisladas de login y alta. El contenido conserva scroll en Dynamic Type y un ancho legible centrado en iPad. Las previews sintéticas añaden los casos sin email y con aviso sin exponer una cuenta real.
- Codex y las pruebas herméticas no repiten la escritura live ni ejecutan login o Keychain de producción. No se modifica SwiftData, Colección u outbox y L1 no se ha iniciado.

### RED / GREEN y validación local de S2.2

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing focal y `ReleaseGate` | El RED inicial falla porque aún no existen los dos ViewModels. Un segundo RED demuestra que `submit → disappear` inmediato podía iniciar login remoto; el guard de cancelación previo a `operations.login` lo cierra. La regresión adicional reproduce el `201` como `.statusCode(201)` mientras el control `202` ya permanece sin confirmar; después de separar status y bytes, las 16 declaraciones focales de transporte/alta aprueban. La ejecución final posterior al rediseño autenticado aprueba 181/181 en iPhone 17 Simulator, iOS 27, sin fallos, omisiones o casos no ejecutados. `Fast` e `Integration` siguen descubriendo 0 habilitados y no se presentan como ejecuciones independientes. |
| Xcode MCP — UI | El plan `UI` final aprueba 4/4 en el iPhone 11 físico con iOS 27; incluye los dos recorridos sintéticos de Cuenta y la comprobación del nuevo botón de logout como control pulsable de al menos 44 pt. Tras retirar su icono y adoptar el ancho ajustado común, ambos recorridos de Cuenta se repiten de forma focal y aprueban 2/2. Cubren además errores inline vacíos, permanencia del teclado al volver a ocultar, conservación del contenido en alternancias enfocadas y sin foco y edición antes y después de un recorrido oculto-visible. No usan cuentas, red, Keychain o almacenamiento live. |
| Xcode MCP — build y diagnósticos | El build normal definitivo tras el ajuste de botones aprueba en 2,435 s sobre el iPhone 11 físico con iOS 27, sin warnings ni errores; el build físico anterior posterior al rediseño aprobó en 2,626 s y el control previo en iPhone 17 Simulator en 1,405 s. Los diagnósticos focales de `AccountRootView`, `SignInView` y `RegisterView` quedan en cero después del cambio. El gate DocC contiene únicamente la emisión externa exacta de App Intents admitida por ADR 0011, nunca un warning de Swift, Clang o DocC. |
| Xcode MCP — previews | Login, alta y el estado autenticado se repiten tras adoptar botones `.fitted`: en iPhone 17 Pro, español Large, XXX Large y AX5 confirma acciones aisladas centradas, de ancho moderado y sin truncado; AX5 se inspecciona además en Dark y contraste aumentado. El par de recuperación usa columna ajustada en portrait y reparto horizontal equivalente en landscape. Las tres acciones aisladas se vuelven a inspeccionar también en iPad Pro 13-inch tras el último ajuste y conservan ancho moderado y centrado. Se mantiene la matriz anterior del estado autenticado en inglés/español, Large/XXX Large/AX5, portrait/landscape, Light/Dark y contraste aumentado. Las snapshots no prueban interacción ni tecnologías de asistencia. |
| Localización e integridad | String Catalog JSON válido: 106/106 claves activas completas en inglés y español, sin valores incompletos ni entradas stale; se retiran diez claves obsoletas de la antigua máquina de logout. `git diff --check` y los enlaces Markdown locales quedan limpios; el diff no incorpora secretos, credenciales o datos personales. `project.pbxproj` no cambia. |
| `Scripts/validate-docc.sh` | La repetición final aprueba 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011. No se publica el archive. |
| Revisiones independientes | La revisión documental corrige el alcance de ARCH-013/021 y el propietario de Cuenta. Arquitectura/iOS detecta y cierra la carrera de cancelación previa, dos oráculos de limpieza insuficientes, el test ausente del pipeline `200`, la conformance `Sendable` redundante y la cadena normativa de ADR. La revisión final iOS no encuentra desviaciones P0–P2 y su P3 documental queda resuelto al sincronizar SDD, localización y gates; SwiftUI/accesibilidad cierra sin hallazgos tras inspeccionar iPhone e iPad. El issue #39 queda reconciliado antes del primer commit con HTTP, Keychain, logout, estado autenticado y el criterio final `.fitted`. No se extrapolan previews o UI tests a VoiceOver, Voice Control, Switch Control o Acceso total con teclado. |

El plan físico acredita cuatro recorridos UI sintéticos, incluidos los dos de Cuenta. La observación manual adicional del propietario acredita el status `201` de un alta real y un login live posterior correcto; no caracteriza el body, el almacenamiento interno ni el logout. La implementación no valida AutoFill o gestor de contraseñas real, tecnologías de asistencia, interacción runtime en landscape o multitarea. `SecureField` no expone a SwiftUI la posición de cursor o selección, por lo que el gate acredita contenido y foco modelado al alternar, no una posición concreta del cursor. Esas exclusiones no se presentan como evidencia superada. La PR #40 entrega el corte con el cierre completo autorizado por el propietario.

## Acciones accesibles de Cuenta S2.1 — issue #37

- Tracker: [GitHub Issue #37 — S2.1: mejorar jerarquía y áreas táctiles de acceso en Cuenta](https://github.com/JFrancoG/MangaLibrary/issues/37), cerrado por la entrega.
- Rama de entrega: `codex/37-account-actions-accessibility`, creada desde `main@45ce7a0c7db74c726049cdeb9ec0909e764b720f` limpio y sincronizado.
- La implementación se versiona inicialmente en `e19c7f1` y se entrega mediante la [PR #38](https://github.com/JFrancoG/MangaLibrary/pull/38), cuya fusión cierra el issue #37; el cierre autorizado incluye retirar después la rama local y remota.
- `AccountRootView` conserva dos `Button` semánticos y sus rutas existentes. Iniciar sesión mantiene jerarquía primaria y Crear cuenta pasa a secundaria bordeada; ambas usan texto `.headline` y control grande y flexible. El frame runtime estándar queda acotado entre 44 y 56 pt de alto, sin sumar otro mínimo a la etiqueta. La acción primaria aplica la pareja semántica `OnBrandPrimary` sobre `BrandPrimary` para adaptar el contraste a cada apariencia. El prompt `Don't have an account?` / `¿No tienes cuenta?` usa `.body`, aparece solo cuando el alta está disponible y el ajuste visual final conserva 16 pt extra tras la acción primaria y 16 pt entre el prompt y Crear cuenta.
- El smoke de login existente incorpora el oráculo independiente de pulsabilidad, tamaño y orden vertical; no se añade un quinto recorrido UI. El String Catalog queda completo en 113/113 claves inglesas y españolas.
- SDD 06 y ADR 0015 continúan siendo la autoridad aplicable y no cambian. No se modifica modelo, sesión, red, configuración, persistencia ni navegación; no se realiza login, alta o escritura live y L1 no se ha iniciado.

### RED / GREEN y validación local de S2.1

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — RED / GREEN focalizado | El primer RED midió `28,0 pt`, menos de los `44 pt` exigidos. La primera GREEN sumó el mínimo de la etiqueta al control grande y el nuevo RED de calibración midió `74,0 pt`, por encima del máximo estándar de `56 pt`. Tras retirar ese doble escalado y aplicar el espaciado final, login y alta sintéticos aprueban 2/2: ambas acciones permanecen pulsables y entre 44 y 56 pt, y Crear cuenta conserva al menos 12 pt respecto al prompt. |
| Xcode MCP — build y diagnósticos | Build normal final aprobado en 1,748 s sobre iPhone 17 Simulator, iOS 27; log de build, Issue Navigator y diagnósticos focales de View y UI test quedan en cero warnings y cero errores. |
| Xcode MCP — `ReleaseGate` | 166 aprobadas, 0 fallos y 1 omisión de 167, limitada al test preexistente que requiere un dispositivo físico. No se atribuye a S2.1 una ejecución independiente de `Fast` o `Integration`. |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011. No se publica el archive. |
| Xcode MCP — previews | Estado sin sesión final inspeccionado en iPhone 17 Pro con inglés y español Large, español XXX Large y AX5; la corrección cromática final se volvió a renderizar en español Large bajo Light/Dark × contraste estándar/aumentado y conserva la pareja adaptativa clara u oscura. En iPad Pro 13-inch (M5) se inspeccionó español Large y AX5. Las acciones quedan completas en iPad AX5 y continúan bajo el primer viewport dentro del `ScrollView` en iPhone AX5; la preview no acredita desplazamiento runtime, estados pulsado/deshabilitado/foco ni tecnologías de asistencia. |
| Localización e integridad | String Catalog JSON válido y completo en 113/113 claves inglesas y españolas, sin textos vacíos ni comentarios ausentes; `git diff --check` limpio. El diff no incluye proyecto, configuración, sesión, red, persistencia, secretos ni datos personales. |
| Revisiones independientes | Arquitectura, alcance/privacidad y SwiftUI/accesibilidad cierran sin hallazgos P0–P3. La primera revisión visual detectó contraste insuficiente del texto blanco sobre `BrandPrimary` claro; se corrigió aplicando `OnBrandPrimary` y la reauditoría de las cuatro apariencias resolvió el P2 sin regresiones. La inspección estática y las previews no se presentan como evidencia runtime de VoiceOver, Voice Control, Switch Control o Acceso total con teclado. |

La evidencia anterior se entrega mediante la PR #38. Al entregarse S2.1, S2.2 quedó como una unidad posterior y separada antes de L1; su implementación local actual se registra arriba y nunca formó parte de S2.1.

## Alta de usuario S2 — issue #35

- Tracker: [GitHub Issue #35 — S2: implementar alta de usuario con App-Token y enlazar login](https://github.com/JFrancoG/MangaLibrary/issues/35), cerrado por la entrega.
- Rama de entrega: `codex/35-s2-user-registration`, creada desde `main@422ffbb6abd723f41899d0d047417d9777ad4158`, limpio y sincronizado con `origin/main` al comenzar.
- La implementación se versiona inicialmente en `dd0f139` y se entrega mediante la [PR #36](https://github.com/JFrancoG/MangaLibrary/pull/36), cuya fusión cierra el issue #35; el cierre autorizado incluye retirar después la rama local y remota.
- El propietario aprobó la implementación hermética. `/docs` volvió a descubrir `/openapi/openapi.json`; el contrato vivo y el snapshot coinciden con SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`: `POST /users`, JSON requerido `email/password`, seguridad exclusiva `App-Token` y única respuesta declarada `200` con `integer/int64` opaco.
- `UserRegistrationClient` limita esa cabecera al alta, valida el status mediante el transporte común y descarta el entero después de confirmar el contrato. Configuración ausente, vacía o sin expandir falla antes del loader sin impedir Catálogo o login. `Shared.xcconfig` carga primero el `Local.xcconfig` ignorado y el repositorio conserva solo un ejemplo vacío; Xcode MCP añadió la clave propia al Info.plist del target app.
- En el corte S2, `AccountModel` mantenía separado el estado de sesión S1 del workflow de alta y validaba entonces únicamente email normalizado no vacío y contraseña de ocho caracteres; la política vigente queda ampliada por S2.2 arriba. S2 distingue no enviado, incierto y confirmado, enlaza una sola vez con el login existente y conserva «cuenta creada» si esa segunda fase falla o se cancela. Abandonar un alta no confirmada invalida efectos tardíos; si el login ya empezó, la cancelación reconcilia primero cualquier commit durable de S1. Nunca repite automáticamente el `POST` y una respuesta A tardía no puede iniciar login ni sustituir una sesión B posterior.
- Cuenta ofrece alta solo desde `signedOut`, nunca desde `authenticationRequired`. El formulario nativo usa `.newPassword`, limpia la contraseña antes de suspender y al abandonar, y representa progreso, fallo local, incertidumbre y cuenta creada sin depender solo del color. Inglés y español quedan completos en las 112 claves del String Catalog.
- Previews y UI tests usan composición sintética directa: no leen Info.plist, `App-Token`, Keychain o almacenamiento live y no alcanzan producción.

### RED / GREEN de S2

- RED del cliente: 10 instancias fallaron contra el stub por request ausente, configuración mal clasificada y resultados no tipados. GREEN cubre request exacto, cuatro configuraciones inválidas, status, timeout, payload, cancelación antes y después del transporte y fallo desconocido.
- RED de `AccountModel`: las nuevas caracterizaciones detectaron los stubs en validación, secuencia `register → login`, estados no enviado/incierto/creado y protección de respuesta tardía. GREEN cubre además la cancelación antes de entrar en el modelo y la carrera en la que S1 ya confirmó durablemente la sesión, incluida la traza exacta `register(A), login(B)` cuando A termina después de autenticar B. La suite focal completa de `AccountModel` termina 19/19.
- El primer XCUITest de alta llegó al formulario, pero iOS 27 abrió el panel del generador de contraseña segura y dejó el botón deshabilitado. La automatización final conserva `.newPassword`, cierra condicionalmente esa sugerencia del sistema y aprueba 1/1 el recorrido Cuenta → alta sintética → login S1 → identidad fija.

### Validación local de S2

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build normal final aprobado en 1,237 s sobre iPad Air 11-inch (M4), iOS 27; Issue Navigator y log de build quedan en cero warnings y cero errores. El target efectivo conserva Swift 6, concurrencia estricta completa, aislamiento predeterminado `nonisolated`, warnings como errores y ningún entitlement. |
| Xcode MCP — pruebas focalizadas | `AccountModelTests` finaliza 19/19. `ReleaseGate` ejecuta además 11/11 invocaciones de `UserRegistrationClientTests`, incluidas cuatro configuraciones inválidas y cancelación pretransporte con cero requests. |
| Xcode MCP — UI | El único smoke nuevo aprueba 1/1 con bootstrap Debug sintético y sin red o persistencia live, y vuelve a pasar dentro del gate final. |
| Xcode MCP — previews | Formulario inspeccionado en iPad y en iPhone con Dynamic Type XXX Large; incertidumbre en español e iPad con AX5 conserva texto y ambas acciones visibles. La preview base se vuelve a renderizar con locale inglés explícito. Ninguna preview acredita VoiceOver físico. |
| Localización y privacidad | JSON válido, 112/112 claves con inglés y español; no se incorpora un token utilizable, cuenta real, payload sensible o log de credenciales. |
| Gate completo | `ReleaseGate`: 166 aprobadas, 0 fallos y 1 omisión de 167, limitada al test preexistente «Requires a physical iOS device». DocC genera el archive con warnings como errores y solo la emisión externa exacta de ADR-0011. Integridad documental limpia y las revisiones finales de arquitectura/concurrencia, SwiftUI/accesibilidad y contrato/privacidad cierran sin hallazgos P0–P3 después de corregir los detectados. |

No se atribuye a S2 una ejecución independiente de `Fast` o `Integration`: esos
planes conservan la regresión transversal de descubrimiento ya registrada. Los
comportamientos afectados sí quedan incluidos en `ReleaseGate`.

Durante la implementación y entrega original de S2 no se realizó ningún alta,
login o escritura live; la observación manual posterior de `201` se registra en
S2.2 sin reescribir aquella evidencia histórica. S2 no incorpora SwiftData,
`ModelContainer`, outbox, Colección, sincronización, entitlements, recuperación o
eliminación de cuenta, App Group, WidgetKit ni watchOS. La eliminación de cuenta
deberá resolverse antes de distribuir una app que permita crearla; no amplía este
issue. La evidencia visual no demuestra VoiceOver, Voice Control, Switch Control
o Acceso total con teclado en runtime.

## Identidad y sesión dual S1 — issue #33

- Tracker: [GitHub Issue #33 — S1: implementar identidad estable y sesión dual recuperable](https://github.com/JFrancoG/MangaLibrary/issues/33), cerrado por la entrega.
- Rama de entrega: `codex/33-s1-dual-session`, creada desde `main@0c250d423244cadaf15280758e06c452d2790f41`, limpio y sincronizado con `origin/main`.
- La implementación se versiona en `f1c8629` y se entrega mediante la [PR #34](https://github.com/JFrancoG/MangaLibrary/pull/34), cuya fusión cierra el issue #33; el cierre autorizado incluye retirar después la rama local y remota.
- El propietario aprobó continuar el 2026-08-30. Xcode MCP confirmó `MangaLibrary.xcodeproj` en Xcode Beta, scheme `MangaLibrary`, iOS 27, los tres targets, los cuatro planes y cero issues de navegador antes del primer cambio.
- `/docs` volvió a descubrir `/openapi/openapi.json`; la forma canónica viva conserva el SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`.
- [ADR-0016](adr/0016-versioned-session-ledger-and-keychain-boundary.md) acepta Keychain por generación y un ledger protegido en Application Support como autoridad durable. Persiste solo versión, UUID, generación opcional, revisión, fase y destino de limpieza opcional; no adelanta SwiftData, Colección, App Group, entitlements ni capacidades Deluxe.
- La implementación materializa el cliente de sesión vivo, Keychain y ledger versionados, actor de persistencia, controller de sesión, modelo de Cuenta, estados recuperables, localización, previews y bootstrap UI sintético. No incorpora SwiftData, Colección, sincronización, entitlements ni escrituras live.
- Xcode Beta 27A5252f construye app y tests para iPad Air 11-inch (M4) e iPhone 11, iOS 27, con Swift 6.4. No aparecen warnings de Swift o Clang ni issues estructurados; el full log conserva las tres emisiones externas —una por target— acotadas por ADR 0011, por lo que esta evidencia no acredita aún el Advanced Release Gate limpio. `ReleaseGate` en el simulador produjo 146 invocaciones: 145 pasaron, ninguna falló y se omitió únicamente la comprobación declarada como exclusiva de dispositivo físico. `Fast` continúa mostrando la regresión transversal conocida de 0 habilitados y 117 deshabilitados; no existe una ejecución independiente acreditada de `Integration`, aunque sus comportamientos sí quedaron cubiertos por `ReleaseGate`.
- `Scripts/validate-docc.sh` genera `.build/docc/MangaLibrary.doccarchive` con warnings DocC como errores y admite exactamente la única emisión externa acotada por ADR 0011. No publica el archive.
- En el iPhone 11 físico, una ejecución dirigida con `RunSomeTests` bajo el plan `ReleaseGate` seleccionó sin omisiones el ciclo Keychain sintético por generación y la restauración de `completeFileProtection` del ledger: 2/2 pasaron. La evidencia no incluye credenciales o red reales, lectura con el dispositivo bloqueado ni validación física de accesibilidad.

## Reconciliación de documentación y hoja de ruta — issue #31

- Tracker: [GitHub Issue #31 — Reconciliar documentación y hoja de ruta tras Catálogo C4 y Library Red](https://github.com/JFrancoG/MangaLibrary/issues/31), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/31-reconcile-roadmap-docs`, creada desde `main@1839c296c78cff47f4fd40b7ef51db42a65db64c`, limpio y sincronizado con `origin/main`.
- Esta unidad cierra el estado histórico de C4 y Library Red y sustituye el siguiente paso ya ejecutado por una secuencia operativa explícita para identidad, Keychain, SwiftData, outbox, Colección local y sincronización remota.
- El enunciado permite una colección básica solo local, pero el producto Advanced aprobado identifica cada entrada mediante usuario + manga y no define una colección anónima ni su migración posterior. Por eso S1 precede a la Colección expuesta al usuario.
- No cambia SDD, ADR, OpenAPI ni arquitectura: la hoja de ruta aplica las decisiones vigentes. Tampoco crea el issue de S1, inicia código de producto, ejecuta credenciales o realiza escrituras live.

### Validación documental local

- El diff queda limitado a `README.md`, `CHANGELOG.md` y este registro de progreso; `git diff --check` no encuentra errores y permanecen intactos código, proyecto, SDD, ADR y OpenAPI.
- Los enlaces y anchors locales de los 39 archivos Markdown resuelven sin roturas. El enlace del README alcanza esta hoja de ruta.
- El escaneo acotado de líneas añadidas no encuentra rutas privadas, correos, credenciales, secretos ni tokens.
- Dos revisiones independientes contrastaron Git/GitHub, SDD 00/01/03/04, el enunciado y el OpenAPI vivo. La revisión de alcance detectó el cierre histórico incompleto de C4 y se corrigió con sus commits y PR reales; el read-back final no mantiene hallazgos abiertos.
- No se ejecutan build, tests, previews ni archive DocC porque esta unidad solo modifica Markdown y no cambia comportamiento, configuración o catálogo DocC.

## Library Red ejecutable — issue #29

- Tracker: [GitHub Issue #29 — Implementar Library Red en Asset Catalog y la UI actual](https://github.com/JFrancoG/MangaLibrary/issues/29), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/29-library-red-assets`, creada desde `main@0b398841b64f27071ac22a133b00dd3a72b7c2ce`, limpio y sincronizado con `origin/main` después de entregar C4.
- El JSON canónico materializa 29 color sets universales sRGB opacos. Cada uno contiene Any/Light, Dark, Increased Contrast Light e Increased Contrast Dark; el placeholder `AccentColor` se retira y `BrandPrimary` queda como único origen de identidad cromática.
- `MainShellView` establece el tint global mediante `.tint(Color.brandPrimary)`. La UI con superficie final controlada adopta `Canvas`, `BackgroundElevated`, `Surface`, `SurfaceStrong`, `ControlBorder`, `TextPrimary`, `TextSecondary` y `TextTertiary`. Las filas de `List` y `Form` conservan `.primary`/`.secondary` porque su selección o material final pertenece a SwiftUI; así sus estados nativos no quedan forzados a una pareja opaca que deja de ser cierta durante la interacción.
- Los nombres tipados se generan únicamente para `ColorResource` y SwiftUI mediante `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI`. Así se conserva el nombre normativo `Link` sin colisionar con `UIColor.link` ni renombrar el contrato.
- Por autorización expresa del propietario, Debug y Release sustituyen en el target `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` por `BrandPrimary`. El diff de `project.pbxproj` se limita a esas dos líneas y `actool` recibe ahora `--accent-color BrandPrimary`.
- La validación manual descubrió que el `inspector` adaptado a sheet en compacto no permitía una segunda apertura después de descartarlo con el gesto. `EnvironmentValues.isPresented`, el ciclo de vida del formulario y un nuevo flanco manual tampoco resolvieron de forma válida el cierre real; el ciclo de vida además se dispara al navegar dentro de los pickers. La solución usa la API nativa adecuada en cada tamaño: sheet en compacto e inspector en regular, ambos con el mismo `CatalogFiltersView` y la misma consulta vigente. El `Binding` de la sheet recibe su cierre interactivo sin estado interno adaptado. Un cambio entre clase horizontal compacta y regular cierra explícitamente Filtros y descarta la copia no aplicada, evitando trasladar parcialmente borrador, picker o foco entre hosts con identidades distintas. El botón usa el símbolo sin círculo cuando no hay filtros y conserva el círculo relleno con filtros activos.
- No se añade wrapper cromático, dependencia, endpoint, target, entitlement, persistencia, autenticación, sincronización, gradiente, alpha o material personalizado. No cambian la consulta ni las rutas de navegación y Colección no se inicia como efecto lateral.

### RED / GREEN de Library Red

- RED: las tres caracterizaciones nuevas se escribieron contra `library-color-tokens.json` como oráculo independiente y fallaron 3/3 bajo `ReleaseGate` porque solo existía el placeholder `AccentColor` y faltaban los 29 recursos contractuales. `Fast` no pudo acreditar el RED por la regresión ya registrada de tags heredados en Q1: descubre cero tests habilitados y este issue no modifica los planes.
- La primera compilación GREEN reveló una colisión generada entre el asset normativo `Link` y `UIColor.link`. Limitar la generación al framework SwiftUI conserva `ColorResource`, `SwiftUI.Color` y los 29 nombres exactos sin desactivar los símbolos tipados.
- Retirar `AccentColor` reveló en el gate DocC que el target aún pasaba ese nombre a `actool`. La configuración autorizada lo sustituye por `BrandPrimary` en Debug y Release; el siguiente build confirmó `--accent-color BrandPrimary` y cero warnings.
- GREEN final: las tres pruebas aprueban inventario fuente, ausencia de `AccentColor`, resolución runtime en los cuatro traits, componentes sRGB, opacidad y las 56 parejas por apariencia —224 en total— comparadas con sus umbrales sin redondeo previo.
- RED de presentación: el propietario reprodujo dos veces que, después del arrastre real sobre la sheet, el botón no volvía a presentarla. El primer XCUITest arrastraba sobre el botón Cancelar y produjo un falso GREEN; se corrige para arrastrar desde la propia presentación.
- GREEN de presentación: la sheet compacta posee directamente el estado de su presentación y el inspector regular conserva su columna nativa; ambos reutilizan el mismo formulario. El propietario confirmó manualmente en iPhone que, tras descartarla con el gesto, una única pulsación vuelve a abrir Filtros.

### Validación local de Library Red

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing final aprobado en 5,618 s sobre iPhone 17 Pro; la misma separación sheet/inspector aprobó antes en 5,039 s sobre iPad Air 11-inch (M4), ambos con iOS 27. `CatalogRootView.swift`, `CatalogFiltersView.swift` y `MangaLibraryUITests.swift` muestran cero diagnósticos y el Issue Navigator conserva cero warnings o errores. El helper cromático moderno crea un entorno UIKit con `traitOverrides` y fuerza su actualización mediante `updateTraitsIfNeeded()`, sin inicializadores deprecados ni escapes de aislamiento |
| Xcode MCP — pruebas focalizadas | 3/3 pruebas de `LibraryColorTests` aprobadas: inventario/catálogo fuente, resolución compilada exacta y umbrales de todas las parejas autorizadas |
| Xcode MCP — UI y `ReleaseGate` | El test corregido arrastra la propia sheet y demuestra RED 0/1 tanto con `EnvironmentValues.isPresented` como con el flanco manual; con sheet compacta nativa aprueba 1/1 y el plan UI completo aprueba 2/2 en iPhone 17 Pro. La repetición regular de iPad no devolvió resultado por bloqueo de Xcode MCP, aunque su build-for-testing sí aprobó. El `ReleaseGate` final, posterior a la corrección y a la matriz manual, aprueba 81/81 en iPhone 17 Pro: cero fallos, omisiones o tests no ejecutados |
| Xcode MCP — previews | El shell se inspeccionó en español y tamaño Large en iPad y en iPhone 17 Pro para Light, Dark, Increased Contrast Light e Increased Contrast Dark. En iPhone se inspeccionaron además cuadrícula y detalle en Dark + Increased Contrast. La comprobación final muestra el símbolo sin círculo sin filtros, el círculo relleno con filtros activos y la cabecera regular de iPad intacta. El tint rojo coral, fondos cálidos, superficies, texto y bordes se resuelven de forma coherente en las cuatro apariencias |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011. Ya no existe el warning de `AccentColor` |
| Localización | No se añaden textos visibles; `Localizable.xcstrings` conserva 68/68 claves con valor manual en inglés y español y cero entradas stale |
| Integridad | 29 color sets y ausencia de `AccentColor`; JSON válido; cero colores RGB/HEX hardcodeados en Swift de producción; `git diff --check` limpio y 215 enlaces Markdown locales sin roturas. OpenAPI conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; `project.pbxproj` queda en `c52c7a23ebc51f075ec1f5e83291288e78d28a679f3c019b4b05f4d166c9b735` tras sus dos sustituciones autorizadas |
| Revisiones independientes | Los read-backs de Library Red y la reauditoría final quedan sin hallazgos pendientes. El primer read-back del cierre interactivo rechazó correctamente `onDisappear` porque también responde a la navegación interna de los pickers; el siguiente detectó la pérdida implícita del borrador entre hosts, cerrada mediante cancelación explícita al cambiar de size class. Los revisores no sustituyen la evidencia runtime del propietario |
| Restauración Xcode | Tras el `ReleaseGate` final se restauraron el scheme `MangaLibrary`, el plan `Fast` y el simulador iPad Air 11-inch (M4) con iOS 27 al estado encontrado al comenzar esa comprobación. `Fast` mantiene la limitación conocida de Q1 —0 habilitados y 60 deshabilitados por los tags heredados—; la actualización explícita de diagnósticos de `LibraryColorTests.swift` y el Issue Navigator quedan en cero |

Las pruebas demuestran los recursos opacos y las parejas contractuales; el
propietario confirmó manualmente la reapertura de la sheet corregida. Las previews demuestran composición estática
representativa. El propietario confirmó en modo claro y oscuro que la interfaz permanece
legible y operable al combinar Increased Contrast, Reduce Transparency y Bold
Text, además de los recorridos ya aprobados de VoiceOver, Voice Control y Switch
Control. También confirmó en escala de grises que el contenido y los estados de
Lista, Cuadrícula y Filtros permanecen legibles y distinguibles sin depender solo
del color. Asimismo, aprobó en iPad el recorrido completo con Acceso total con
teclado: el foco permanece visible, Espacio o Retorno activan los controles y no
existen trampas al abrir, recorrer y cerrar Filtros. Esta evidencia no constituye
una medición píxel a píxel de todos los estados nativos ni acredita hardware
físico, que no es una condición de este cambio al no incorporar capacidades que
dependan de él. La matriz manual de Library Red queda completa para el alcance
del issue #29. La implementación `ef770f0` se entregó mediante la PR #30,
fusionada en `f2aaf2b`; el issue quedó cerrado y las ramas local y remota se
eliminaron. Esta entrega no inicia Colección ni otra fase como efecto lateral.

## Catálogo C4 — detalle enriquecido y precarga fluida

- Tracker: [GitHub Issue #27 — Catálogo C4: enriquecer el detalle y anticipar la paginación](https://github.com/JFrancoG/MangaLibrary/issues/27), abierto después de comprobar que no existía un issue o una PR equivalente.
- El cuerpo del issue se reconcilió el 2026-08-28 con la petición actual del propietario, SDD 02 v1.11 y ADR 0015: animación local de escala de la portada, reset de scroll regular, cabecera compactada de iPad y tres botones nativos de toolbar. La descripción anterior del `zoom` de navegación completo ya no figura como plan vigente.
- Rama local: `codex/27-catalog-detail-prefetch`, creada desde `main@76ab2707241ac13b21e3e70b3edaca0383a2b23d`, limpio y sincronizado con `origin/main`.
- El OpenAPI vivo se descubrió desde `/docs` y su forma canónica volvió a coincidir con el snapshot saneado, SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`. Las páginas ya contienen el manga completo necesario y no se añadió una segunda petición de detalle ni se hicieron llamadas funcionales al servicio.
- `Manga` conserva ahora estado editorial, autoría con UUID y rol cerrado, y demografías, géneros y temas con identidad UUID. El cliente tipado trata relaciones requeridas ausentes, UUID inválidos y vocabulario cerrado desconocido como deriva contractual.
- El detalle presenta la portada con una variante propia claramente mayor, estado, autoría, clasificaciones y sinopsis disponibles. La raíz de Catálogo usa un `NavigationStack` tipado por `Manga.ID` en compacto y conserva el `NavigationSplitView` regular; ambas presentaciones derivan de la misma selección. Al abrir en compacto, solo la portada del destino aplica `scaleEffect`: `0,1 → 1,25` con `easeIn` en `0,3 s` y `1,25 → 1` con `easeOut` en `0,08 s`. Ya no existen copia visual, geometría global ni coordinación manual; el regreso conserva el pop nativo y Reduce Motion usa `crossFade` sin escala. En regular no se repite la animación y un nuevo `Manga.ID` restablece inmediatamente el scroll arriba sin recrear el detalle ni forzar el foco.
- C3 conserva su inspector adaptativo, presentado como sheet en compacto. En iOS 27 compacto, Filtros ocupa un `ToolbarItem` propio; un `ToolbarSpacer(.fixed)` lo separa del `ToolbarItemGroup` de Lista y Cuadrícula. En regular, Filtros permanece arriba y la pareja de layout pasa a una franja propia para que el título de la columna no se trunque; el título usa modo inline para no apilar además la reserva expandida del título grande sobre la búsqueda. Se retiran el menú de desbordamiento de un único elemento y el `Picker` segmentado. El formulario expone conjuntamente título, modo «Contiene/Empieza por», nombre y apellidos de autoría y selección múltiple de demografía, género y tema. El servidor combina las dimensiones mediante AND; no existe una búsqueda genérica por palabra fuera de los campos declarados.
- La lista muestra título y todos los nombres de autoría disponibles con formato sensible al locale; el bloque textual se centra verticalmente junto a la portada y conserva reflow en tamaños de accesibilidad. La cuadrícula muestra solo portada y título, reserva dos líneas tipográficas centradas y trunca el exceso, por lo que todas las tarjetas mantienen la misma altura sin reducir la fuente.
- Por decisión del propietario durante la implementación, la siguiente página se agenda al aparecer cualquiera de los dos últimos resultados, no cinco. La petición sigue siendo idempotente y el footer existente conserva progreso, error recuperable y fin.
- No se añadieron Repository, UseCase, Store, router global, dependencia externa, endpoint, target, entitlement ni cambio de configuración.

### RED / GREEN de C4

- RED de contrato: el primer build-for-testing falló al exigir en los tests el mapping de estado, autoría y las tres taxonomías, además de deriva por relación ausente, UUID inválido y enum desconocido.
- GREEN de contrato: el DTO mínimo se amplió solo con los campos ahora presentados y todos los valores se traducen a tipos de producto antes de llegar a SwiftUI. La caracterización parametrizada cubre los cuatro roles y los cinco estados válidos, además de mantener separados los casos desconocidos que representan deriva.
- La caracterización de paginación se escribió antes del cambio, pero su RED no se aisló en ejecución porque el build conjunto ya estaba detenido por los nuevos tipos de `Manga`. Tras la aclaración del propietario, el umbral se fijó en los dos últimos elementos y el caso focalizado se volvió a ejecutar 1/1.
- GREEN de paginación: el elemento anterior al umbral no agenda; cualquiera de los dos últimos agenda exactamente la página preparada y las apariciones repetidas no duplican trabajo.
- RED de navegación: el propietario confirmó primero que el `zoom` no se producía en el split compacto y después que la alternativa geométrica no daba un resultado runtime convincente. La prueba visual también mostró el `Picker` segmentado anidado con la acción de Filtros en una cápsula poco clara.
- GREEN de navegación y presentación: lista y cuadrícula compactas vuelven a `NavigationLink(value:)` dentro de un `NavigationStack` cuyo path `[Manga.ID]` se deriva de `selectedMangaID`; la portada del destino posee el único estado de animación. La toolbar declara un corte fijo entre Filtros y el grupo de layout. Lista conserva título y autoría centrados respecto a la portada; cuadrícula reserva dos líneas de título y elimina metadata secundaria para igualar tarjetas. La cabecera regular mantiene búsqueda y controles en franjas propias, pero cambia únicamente el título de `.large` a `.inline` para retirar la reserva vertical expandida. El detalle regular usa una `ScrollPosition` local y vuelve sin animación al borde superior solo cuando cambia `Manga.ID`, sin reiniciar el árbol completo. Estos ajustes editoriales no poseen una aserción unitaria significativa; se validan mediante compilador, previews y recorrido UI, mientras que la secuencia temporal de escala permanece excluida de la evidencia runtime. ADR 0015 supersede la cláusula incompatible de ADR 0014 sin cambiar sus decisiones de composición, transporte o dobles.

### Validación local de C4

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing del snapshot final aprobado en 2,981 s sobre el simulador iPad Air 11-inch (M4); `CatalogRootView.swift` muestra cero diagnósticos y el Issue Navigator contiene cero warnings |
| Xcode MCP — `ReleaseGate` | 77/77 casos aprobados sobre el simulador iPad Air 11-inch (M4): cero fallos, skips, expected failures o casos no ejecutados |
| Xcode MCP — previews | Lista y cuadrícula compactas inspeccionadas en español con Large, XXX Large y AX5; la cuadrícula también en modo oscuro con contraste aumentado, y ambas presentaciones en split regular de iPad. La lista muestra título y uno o varios autores centrados junto a la portada y refluye en AX; la cuadrícula conserva alturas uniformes, centra títulos cortos y trunca los largos dentro de dos líneas reservadas. El detalle regular final se volvió a renderizar en iPad con Large y con español AX5 desde el borde superior. La cabecera regular final se inspeccionó de nuevo en español con Large, XXX Large y AX5: título inline, acciones, búsqueda y selector permanecen visibles y desaparece la reserva expandida anterior |
| Recorrido de detalle | El smoke determinista `testMockCatalogOpensMangaDetail()` aprobó 1/1 en el simulador iPad Air 11-inch (M4) y vuelve a aprobar dentro de `ReleaseGate`. Abre el mismo detalle por `Manga.ID`, pero no desplaza el detalle y selecciona otro manga; por tanto, no acredita por sí solo el reset de scroll ni la secuencia temporal de los dos tramos de escala |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011 |
| Localización | `Localizable.xcstrings` válido; 68/68 claves traducidas manualmente en inglés y español, sin entradas stale o incompletas |
| Integridad | `git diff --check` limpio; 216 enlaces Markdown locales sin roturas; cero patrones sensibles en líneas añadidas; snapshot OpenAPI y `project.pbxproj` conservan sus SHA-256 esperados; sin configuración, scheme o planes en el diff |
| Revisiones independientes | El read-back de SDD 02 y ADR 0015 y las reauditorías finales de composición y SwiftUI/accesibilidad no encuentran defectos en `ToolbarItem` + spacer + `ToolbarItemGroup`, lista, cuadrícula, stack compacto, escala local, Reduce Motion, semántica estática, contraste o Dynamic Type. La evidencia runtime de tecnologías de asistencia permanece excluida |
| Accesibilidad interactiva | **Pasa con observación.** El árbol accesible del Simulator iPad expone Lista y Cuadrícula como botones con identificadores estables, marca Lista como seleccionada y conserva tabs y contenido. El propietario confirmó manualmente que VoiceOver entra por Filtros, Lista y Cuadrícula y alcanza después el encabezamiento Catálogo según su posición visual; al volver arriba tras desplazar la lista, anuncia también el encabezamiento colapsado. En el inspector anuncia Cancelar antes de Filtros por su posición de cierre. El recorrido no queda atrapado y los controles conservan nombres comprensibles. Device Interaction no sustituyó esta comprobación: su skill obligatorio no estaba disponible para el revisor |
| Restauración Xcode | Plan activo `Fast` y destino simulador iPad Air 11-inch (M4) con iOS 27 restaurados y verificados mediante Xcode MCP |

La observación runtime anterior acreditaba una transición ya retirada y no la
nueva escala local. La preview estática y el smoke existente tampoco reproducen
el desplazamiento seguido de un cambio de selección regular; la interacción
dinámica no pudo añadirse a esta evidencia porque el skill requerido por Xcode
no estaba disponible. Build, previews y revisión estructural no constituyen
por sí solos una medición de fluidez frame a frame ni un recorrido manual con
VoiceOver, Voice Control, Switch Control, Full Keyboard Access o Accessibility
Inspector. Tampoco existe evidencia física ni integración live. La implementación
`8b2bb3` y la evidencia manual `98b0bae` se entregaron mediante la PR #28,
fusionada en `0b39884`; el issue #27 quedó cerrado y las ramas local y remota se
eliminaron. El read-back manual de VoiceOver quedó aprobado con el orden
geométrico observado; esta entrega no inició Colección ni Library Red como efecto
lateral.

## Catálogo C3 — búsqueda avanzada y filtros

- Tracker: [GitHub Issue #25 — Catálogo C3: añadir búsqueda avanzada paginada y filtros](https://github.com/JFrancoG/MangaLibrary/issues/25), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/25-catalog-search-filters`, creada desde `main@1d91d1026bedea25367b4f78eb8917cfb89395ca`, limpio y sincronizado con `origin/main`.
- El OpenAPI vivo se descubrió de nuevo desde `/docs` hacia `/openapi/openapi.json`. Su forma canónica coincide byte a byte con el snapshot saneado y conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no se hicieron llamadas funcionales.
- La consulta distingue catálogo, «Mejores» y búsqueda avanzada. Texto, modo contiene/empieza por, nombre y apellidos de autoría y selecciones de demografía, género y tema forman una identidad canónica; cambiarla reinicia la página, limpia la selección e invalida respuestas tardías.
- `POST /search/manga` conserva la paginación y omite dimensiones vacías del body. `GET /list/bestMangas` es un conjunto paginado exclusivo ordenado por puntuación por el servidor: no es una ordenación configurable ni se combina con texto o filtros. El contrato no expone «Destacados».
- Demografías, géneros y temas cargan perezosamente desde sus tres operaciones públicas mediante un estado independiente con carga, vacío, error recuperable y contenido. La UI representa la combinación AND que recibe el servidor sin atribuir una semántica local no declarada a varios valores de una lista.
- Lista y cuadrícula continúan consumiendo el mismo `CatalogModel`, resultados, consulta, selección y cursor. El inspector edita una copia y solo cambia la consulta al aplicar o restablecer; la barra de búsqueda envía la misma identidad avanzada.
- `AppComposition` sigue siendo exclusivamente live. `HTTPClient` continúa validando transporte y devolviendo `Data`; `CatalogAPIClient` construye y decodifica las operaciones verificadas. Previews y tests inyectan loaders de dominio directos y deterministas. No se añade Repository, UseCase, Store, protocolo de transporte, catálogo global de endpoints ni ordenación anticipada.

### RED / GREEN de C3

- RED: después de añadir primero las caracterizaciones de request, identidad y propietario de estado, `BuildProject(buildForTesting: true)` falló por la ausencia de `CatalogSearch` y `CatalogQuery`.
- GREEN: los requests exactos de búsqueda, «Mejores» y vocabularios, la canonicalización, el reset de página y selección, la preservación en retry/página adicional, las carreras entre consultas y el estado independiente de filtros quedaron implementados solo hasta satisfacer esas pruebas.
- RED de revisión: una carrera determinista reprodujo que reentrar en filtros mientras la carga anterior se cancelaba podía dejar el vocabulario en reposo sin iniciar una petición nueva; el caso falló 0/1 antes de corregir la identidad de la carga activa.
- RED de presentación: la prueba que conserva selecciones ausentes de un vocabulario refrescado no compiló hasta mover esa unión canónica desde la View a `CatalogFilterOptions`.
- RED de reauditoría: dos caracterizaciones nuevas demostraron 0/2 que mover el algoritmo no bastaba mientras el builder siguiera ejecutándolo; cubren tanto recibir vocabularios como cambiar la consulta.
- GREEN de revisión: las selecciones se incorporan ahora en `CatalogModel` solo al recibir vocabularios o cambiar la consulta, sin acumular valores exclusivos de identidades anteriores; las dos últimas pruebas pasan 2/2 y la carga preparada de previews permanece estable sin confundirse con una petición cancelable en curso.
- La inspección iPad en XXX Large detectó que el nuevo botón de filtros volvía a truncar el título de Catálogo. En anchura regular, el selector lista/cuadrícula pasa a una franja propia; la repetición en iPhone e iPad conserva título y controles completos.

### Validación local de C3

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing tras el último cambio de producción aprobado en 2,153 s y comprobación incremental final en 0,193 s; Issue Navigator y build log con cero warnings estructurados |
| Xcode MCP — `ReleaseGate` | 63/63 casos aprobados: 62 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o casos no ejecutados |
| Xcode MCP — previews | Resultados, vacío, carga, error, filtros activos y «Mejores» inspeccionados en iPhone e iPad; Large, XXX Large y AX5; inglés y español; modo oscuro con contraste aumentado |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011 |
| Localización | `Localizable.xcstrings` válido; 56/56 claves traducidas manualmente en inglés y español, sin entradas stale o incompletas |
| Integridad | `git diff --check` limpio; snapshot OpenAPI y `project.pbxproj` conservan sus SHA-256 esperados; sin configuración, scheme, planes o fixture contractual en el diff |
| Revisiones independientes | Reauditorías iOS, SwiftUI/accesibilidad y contrato/gobernanza cerradas sin hallazgos después de las correcciones; la evidencia manual de tecnologías de asistencia permanece excluida |
| Restauración Xcode | Plan activo `Fast` y destino físico `iPhone 11` con iOS 27 restaurados y verificados mediante Xcode MCP |

Las previews y el smoke UI no acreditan un recorrido manual con VoiceOver, Voice Control, Switch Control, Full Keyboard Access o Accessibility Inspector. Después de validar esta limitación y la regresión Q1 separada, el propietario autorizó expresamente commit, push, PR, merge, cierre del issue y borrado de las ramas local y remota. La autorización no repara Q1 ni inicia SwiftData, colección, autenticación, sincronización, Library Red ejecutable, WidgetKit, watchOS, App Group, entitlements o el Advanced Release Gate.

## P1 — composición live, red y pruebas directas

- Tracker: [GitHub Issue #23 — P1: simplificar composición, red y pruebas del catálogo](https://github.com/JFrancoG/MangaLibrary/issues/23), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/23-simplify-catalog-flow`, creada desde `main@e6dbfdae6655c48aac73834812c6fa594882b919`, limpio y sincronizado con `origin/main`.
- Xcode MCP oficial se conectó a Xcode-beta y confirmó `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, los cuatro planes, iOS 27, concurrencia estricta y cero diagnósticos antes de editar.
- [ADR 0014](adr/0014-native-flows-live-composition-and-direct-doubles.md) supersede ADR 0009 sin cambiar su navegación local: `AppComposition` crea únicamente dependencias live; previews y el único bootstrap Debug de UI tests inyectan un loader de dominio directo y fail-closed.
- `HTTPClient` conserva `URLSession` inyectada, valida respuesta HTTP y status y devuelve bytes. `NetworkError` retiene categorías seguras y descripciones localizables; cancelar sigue siendo `CancellationError`.
- `CatalogAPIClient` recibe `@Sendable (URLRequest) async throws -> Data`, decodifica solo los campos consumidos y valida metadata e identidades. Sus tests inyectan JSON crudo y registran la request; `FixtureURLProtocol` queda exclusivamente en `HTTPClientTests`.
- No se introduce `ResultRequest<T>`, decoding genérico en transporte, catálogo global de endpoints, Repository, UseCase, Store, protocolo o builder anticipado. La construcción tipada permanece en `CatalogPageRequest` hasta que una segunda operación real demuestre duplicación.

### RED / GREEN de P1

- RED: `BuildProject(buildForTesting: true)` falló por la ausencia de `NetworkError` y de la costura directa del cliente tipado después de añadir las nuevas caracterizaciones.
- GREEN: el transporte mapea respuesta no HTTP, status, fallo de URL loading y cancelación; el cliente de Catálogo construye página 1/2, decodifica un payload mínimo con campos remotos desconocidos, preserva categorías de red y detecta metadata, identidad y campos consumidos inválidos.
- `AppCompositionTests`, el test de vocabulario remoto no consumido y el getter aislado de selección se eliminan. La garantía de no recargar se integra en la transición inicial; los tests restantes conservan estado, retry, paginación, cancelación y carreras de C2.
- El XCUITest se reduce al recorrido determinista `-ui-testing` → primera fila → detalle de la misma `Manga.ID`; no prueba tabs placeholder, alternancia visual ni wiring garantizado por compilación.

### Validación local de P1

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing aprobado; build log e Issue Navigator con cero warnings estructurados |
| Xcode MCP — `ReleaseGate` | 42/42 casos aprobados: 41 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o casos no ejecutados |
| Xcode MCP — previews | Shell y contenido renderizados; error inicial y fallo de página adicional inspeccionados en Large, XXX Large y AX 5. El truncado español detectado en AX 5 se corrigió y ambos estados conservan título, descripción y acción completas |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011 |
| Localización | `Localizable.xcstrings` válido; 29/29 claves traducidas manualmente en inglés y español, sin entradas stale o incompletas |
| Revisiones independientes | Arquitectura/concurrencia/testing y SwiftUI/accesibilidad terminaron sin hallazgos abiertos tras corregir request, fixture OpenAPI, conformidades redundantes, reflow AX 5 e iconografía semántica |
| Límite Q1 | `Fast` continúa descubriendo 0 tests habilitados por la regresión conocida de tags; P1 no modifica planes, scheme ni `TestTags.swift` |

Las previews y el smoke UI no acreditan un recorrido manual con VoiceOver, Voice Control, Switch Control, Full Keyboard Access o Accessibility Inspector. No se realizaron llamadas funcionales a producción. Después de validar estas limitaciones, el propietario autorizó expresamente commit, push, PR, merge, cierre del issue y borrado de las ramas local y remota. La autorización no repara Q1 ni inicia C3 como efecto lateral.

## Catálogo C2 — paginación incremental y lista/cuadrícula

- Tracker: [GitHub Issue #21 — Catálogo C2: añadir paginación incremental y lista/cuadrícula](https://github.com/JFrancoG/MangaLibrary/issues/21), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/21-catalog-pagination-layout`, creada desde `main@d62bc9348ae7da842b41e99e1ef8976e8fbe6a60`, limpio y sincronizado con `origin/main`.
- El OpenAPI vivo descubierto desde `/docs` conserva OpenAPI 3.0.1, 28 paths, 30 operaciones, 19 schemas y 3 mecanismos de seguridad. Su forma canónica saneada coincide byte a byte con el snapshot y mantiene SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no se hicieron llamadas funcionales.
- `CatalogModel` sigue siendo el único propietario `@Observable @MainActor` de consulta, acumulación, cursor, carga adicional, error, retry, cancelación y protección frente a respuestas tardías. Las Views permanecen como structs declarativas sin `@MainActor`.
- Lista y cuadrícula consumen el mismo contenido acumulado y la misma selección por `Manga.ID`. La cuadrícula adapta sus columnas a Dynamic Type y a la anchura disponible; en presentación compacta abre el detalle mediante la columna preferida de `NavigationSplitView`.
- Una página adicional conserva el orden y el primer valor ya visible de cada identidad. El fin por total o página vacía cierra el cursor; un fallo mantiene contenido y selección y reintenta exactamente la misma página.
- `CatalogAPIClient` rechaza como deriva contractual la metadata de página o tamaño que no corresponde a la petición. `HTTPClient` continúa concreto, inmutable, app-scoped e inyectado; no se añaden actor compartido, `@globalActor`, Repository, UseCase o Store.

### RED / GREEN de C2

- RED: el primer build-for-testing falló por la ausencia de `CatalogModel.Content`, `CatalogModel.Pagination` y las intenciones de página adicional después de añadir las caracterizaciones.
- GREEN: página 2 exacta, acumulación, deduplicación, fin, error adicional, retry, cancelación y respuesta invalidada quedaron implementados solo hasta satisfacer esas pruebas.
- La inspección visual posterior detectó que el valor inline de la macro `@State` impedía arrancar la preview en cuadrícula. La asignación directa desde ambos inicializadores corrige el estado moderno de iOS 27 sin manipular un backing wrapper.
- La primera auditoría iPad detectó una única columna y el título de navegación truncado. El ancho adaptativo de tarjeta, la portada escalable y el ancho acotado del selector se ajustaron antes de repetir las previews.

### Validación técnica de C2

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — `ReleaseGate` | 38/38 pruebas aprobadas: 37 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o pruebas no ejecutadas |
| Xcode MCP — smoke UI | 1/1 aprobado tanto en iPhone 17 como en iPad Air 11-inch (M4): alterna lista/cuadrícula, abre el mismo detalle por `Manga.ID` y conserva la ruta tras cambiar de tab |
| Xcode MCP — build y diagnósticos | Build-for-testing aprobado; los 12 archivos Swift afectados muestran cero diagnósticos y el Issue Navigator y el build log contienen cero warnings estructurados |
| Previews Xcode | Lista y cuadrícula inspeccionadas en iPhone e iPad; Large, XXX Large y AX5; inglés y español; modo oscuro y contraste aumentado. La cuadrícula usa dos columnas cuando el ancho y Dynamic Type lo permiten y refluye a una en AX5 |
| Localización | `Localizable.xcstrings` válido; 24 claves traducidas manualmente en inglés y español, sin estados new, needs review o machine translated |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; `docbuild` Release para iOS genérico aprobado y `.doccarchive` regenerado con warnings DocC como errores |
| ADR 0011 | Exactamente una emisión externa autorizada en `27A5252f`; cero warnings de Swift, Clang o DocC. La excepción no acredita Advanced |

`GetTestList` no proyecta actualmente los tags heredados de `@Suite` y deja 0/37 tests habilitados tanto en `Fast` como en `Integration`; `UI` descubre 1/1 y `ReleaseGate`, 38/38. Una prueba diagnóstica reversible confirmó que un tag directo sí aparece en el inventario, pero el filtro continúa deshabilitándolo. La prueba se retiró y `TestPlans/`, el scheme y el proyecto permanecen fuera del diff. C2 no repara Q1 silenciosamente y no puede acreditar todavía esos dos planes.

Después de recibir esta limitación y la recomendación de resolverla antes de entregar, el propietario autorizó expresamente el cierre completo de C2 mediante commit, push, PR, merge, cierre del issue y eliminación de rama. La autorización no convierte `Fast` o `Integration` en gates aprobados, no amplía C2 a una reparación de Q1 y no acredita el Advanced Release Gate.

### Alcance excluido y estado de entrega de C2

- Búsqueda, filtros y ordenación pertenecen a C3. También quedan fuera SwiftData, colección, autenticación, sincronización, Library Red ejecutable, WidgetKit, watchOS, App Group, entitlements y llamadas funcionales al backend.
- No se modifican SDD, ADR, OpenAPI, configuración, scheme, planes ni `project.pbxproj`.
- La implementación, los gates técnicos aplicables y las revisiones especializadas quedan cerrados. La entrega autorizada vincula la rama `codex/21-catalog-pagination-layout` con el issue #21 mediante su PR de cierre y elimina después la rama local y remota. C3 no se inicia como efecto lateral.

## Q1 — planes de test versionados

- Tracker: [GitHub Issue #19 — Q1: materializar los planes de test versionados](https://github.com/JFrancoG/MangaLibrary/issues/19), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/19-test-plans`, creada desde `main@b86d2352e83e6aa26bec51bec38233253fa244db`, limpio y sincronizado con `origin/main`.
- RED de configuración: Xcode MCP encontraba únicamente el plan implícito autocreado `MangaLibrary`; no existían `.xctestplan` versionados.
- Los planes `Fast`, `Integration`, `UI` y `ReleaseGate` viven en `TestPlans/` y el scheme compartido deja `Fast` como predeterminado.
- `Fast` incluye el tag Swift Testing `fast`, aplicado a `AppCompositionTests` y `CatalogModelTests`; `Integration` incluye `integration`, aplicado a `CatalogAPIClientTests` y `HTTPClientTests`; `UI` contiene el target XCUITest; `ReleaseGate`, ambos targets completos sin filtros.
- `ReleaseGate.xctestplan` es el componente completo de tests. Build, DocC y evidencia manual continúan siendo acciones separadas del Release Gate de producto.

### Validación de Q1

| Evidencia | Resultado |
| --- | --- |
| Xcode MCP — preflight | Proyecto `MangaLibrary.xcodeproj`, scheme compartido `MangaLibrary`, tres targets, destino original iPhone 11 físico con iOS 27 y cero warnings del navegador |
| Descubrimiento inicial | 30 tests activos bajo el plan implícito: 29 Swift Testing y 1 XCUITest |
| RED de ejecución | La selección nominal por nombres mostraba 12 tests habilitados en `Fast`, pero `RunAllTests` ejecutaba los 29 unitarios; se descartó por no constituir un gate real para Swift Testing |
| GREEN de descubrimiento | Los filtros nativos Include Tags dejan `Fast` con 12 habilitados y 17 excluidos; `Integration`, 17 y 12; `UI`, 1; `ReleaseGate`, 30 |
| Xcode MCP — ejecución `Fast` | Los 12 identificadores habilitados por el plan, obtenidos con `GetTestList` y ejecutados con `RunSomeTests`, aprobaron 12/12 |
| Xcode MCP — ejecución `Integration` | Los 17 identificadores habilitados por el plan, obtenidos con `GetTestList` y ejecutados con `RunSomeTests`, aprobaron 17/17 |
| Xcode MCP — ejecución `UI` | `RunAllTests` aprobó 1/1 XCUITest |
| Xcode MCP — ejecución `ReleaseGate` | `RunAllTests` aprobó 30/30: 29 Swift Testing y 1 XCUITest |
| Xcode MCP — build y restauración | `BuildProject(buildForTesting: true)` aprobado en 2,097 s sin errores; cero warnings en el navegador; `Fast` y el iPhone 11 físico con iOS 27 restaurados como plan y destino activos |
| Validación estática | Los cuatro JSON y el XML del scheme son válidos; `git diff --check`, 196 enlaces locales y el escaneo de patrones sensibles pasan; `project.pbxproj` conserva SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Revisión iOS independiente | Perfil `greenfield-xcode27`; testing, configuración, concurrencia, alcance y gobernanza revisados sin hallazgos; revisión SwiftUI/accesibilidad no aplicable porque Q1 no modifica UI |

La operación MCP `RunAllTests` ignora los tests deshabilitados por un plan y, por tanto, no sirve como evidencia de cardinalidad para `Fast` o `Integration`; la combinación `GetTestList` + `RunSomeTests` sí conserva y ejecuta exactamente la selección resuelta por cada plan. C2 y cualquier comportamiento nuevo de producto quedan fuera.

### Estado de entrega de Q1

La implementación se versiona en el commit `43424a6` y se entrega mediante la [PR #20](https://github.com/JFrancoG/MangaLibrary/pull/20), cuya fusión cierra el issue #19. La entrega autorizada incluye la eliminación posterior de la rama local y remota. C2 no se inicia como efecto lateral de este cierre.

## D1 — frontera de logout Advanced y bridge Deluxe

- Tracker: [GitHub Issue #17 — D1: delimitar logout Advanced y su extensión Deluxe](https://github.com/JFrancoG/MangaLibrary/issues/17), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/17-advanced-deluxe-session-boundary`, creada desde `main@2488308b290353b469247e16f73d246aadb37a42`, limpio y sincronizado con `origin/main`.
- D1 elimina la dependencia circular entre un Advanced que debe cerrar autenticación y sincronización y unas garantías de `SessionFence`, App Group, WidgetKit y WatchConnectivity que solo pueden materializarse después de su Release Gate.
- Advanced conserva un logout local, durable y recuperable: gate de pendientes, propietario de sesión serializado, invalidación de la generación esperada, revalidación de tareas y limpieza condicionada de Keychain, datos y rutas. Mientras A está en curso no se activa B y un efecto tardío de A no altera una sesión posterior. La cancelación solo es válida antes del commit de invalidación local.
- Cuando exista el bridge Deluxe, su fence cerrado y verificado se compone entre la transición persistida y la invalidación local y adelanta el punto de no retorno; envelope, reload y contexto watchOS continúan siendo eventuales. El bootstrap empieza cerrado y solo abre tras autorización y revalidación explícitas del propietario de sesión. Advanced no crea un bridge no-op.
- [ADR 0013](adr/0013-advanced-logout-and-deluxe-bridge-boundary.md) complementa ADR 0006, 0007 y 0010 sin superseder sus decisiones. SDD 00, 04, 05 y 06 atribuyen cada requisito y prueba a su gate real.

### Validación de D1

| Herramienta y acción | Resultado |
| --- | --- |
| Git y GitHub — preflight | Repositorio privado; `main` limpio y sincronizado en `2488308`; cero issues o PR abiertas antes de D1; issue #17 y rama creados desde esa base |
| Xcode MCP — preflight | `MangaLibrary.xcodeproj`, scheme compartido y plan `MangaLibrary`, app y targets de tests, destino activo iPhone 11 con iOS 27 y cero warnings en Issue Navigator |
| OpenAPI vivo — comparación canónica | OpenAPI 3.0.1, 28 paths, 30 operaciones, 19 schemas y 3 mecanismos de seguridad; SHA-256 saneado `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`, idéntico al snapshot. No declara logout ni revocación; no se hicieron llamadas funcionales |
| Matriz antes/después | Antes, SDD 04 y el gate Advanced exigían incondicionalmente capacidades cuya entrada depende de superar Advanced. Después, PROD-013 y los casos con columna `Gate` cierran la sesión local en Advanced y reservan fence, bootstrap y proyecciones para Deluxe |
| Documentación e integridad | SDD 00/04/05/06 incrementan versión; 13 ADR y 13 entradas de índice conservan estados y fechas coherentes; 36 Markdown y 196 enlaces locales sin roturas; escaneo de privacidad y secretos sin hallazgos; `git diff --check` limpio y `project.pbxproj` intacto en `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Revisiones independientes | La auditoría iOS detectó y cerró carrera A/B, bootstrap y punto de no retorno; los read-backs finales de arquitectura/seguridad, gobierno ADR y alcance/integridad terminaron sin hallazgos |
| Alcance ejecutable | TDD, build, tests, previews y DocC no aplican: D1 cambia únicamente contrato humano y no modifica código, Assets, proyecto, configuración o catálogo DocC |

### Estado de entrega de D1

La decisión se versiona en el commit `93288f3` y se entrega mediante la [PR #18](https://github.com/JFrancoG/MangaLibrary/pull/18), cuya fusión cierra el issue #17. La entrega autorizada incluye la eliminación posterior de la rama local y remota. Código de sesión, Keychain, SwiftData, outbox, App Group, WidgetKit, watchOS, entitlements, OpenAPI, colorsets, Q1 y C2 quedan fuera de D1.

## Contrato cromático Library Red — issue #15

- Tracker: [GitHub Issue #15 — Documentar el contrato cromático Library Red](https://github.com/JFrancoG/MangaLibrary/issues/15), cerrado mediante la [PR #16](https://github.com/JFrancoG/MangaLibrary/pull/16) después de comprobar que no existía un issue duplicado.
- Rama: `codex/15-brand-palette-contract`, creada desde `main@884dd6c3dfdd98a1b37e5ab66329cad7a8c4615c`, limpio y sincronizado con `origin/main`, y eliminada local y remotamente tras la fusión.
- [`docs/design/brand-palette.md`](design/brand-palette.md) define significado, política de uso, accesibilidad y límites. [`docs/design/library-color-tokens.json`](design/library-color-tokens.json) es la autoridad exacta de versión, valores, roles, modos, umbrales y parejas.
- SDD 06 enlaza el contrato y difiere colorsets, código y tests a una unidad RED/GREEN posterior. La procedencia coordinada con ScienceLibrary no se convierte en una invariante entre repositorios.
- La revisión de fuentes corrigió la atribución normativa: WCAG2ICT es una Group Note informativa y WCAG2Mobile una Group Draft Note; ninguna define conformidad para una app nativa. También distingue los `44 × 44 pt` predeterminados de Apple de su mínimo `28 × 28 pt` y limita lo que demuestra la matriz del indicador de foco.
- El Markdown genérico y el HTML visual se archivaron en documentación privada fuera de Git. El archive DocC regenerable de 72 MB y el residuo temporal literal de 52 KB se retiraron del workspace y permanecen recuperables en la Papelera hasta que se vacíe.

### Validación del contrato cromático

| Herramienta y acción | Resultado |
| --- | --- |
| Git, GitHub y Xcode MCP — preflight | Repositorio privado; `main` limpio y sincronizado antes de abrir el issue; sin issues ni PR abiertos; Xcode observa `MangaLibrary.xcodeproj`, scheme y plan `MangaLibrary`, destino físico iPhone 11 con iOS 27 |
| Apple y W3C — fuentes primarias | HIG Color/Accessibility/Dark Mode, Asset Catalog, SwiftUI `ColorSchemeContrast`, WCAG 2.2, WCAG2ICT y WCAG2Mobile contrastados el 25 de agosto de 2026 |
| JSON y recálculo independiente | JSON válido; 4 modos, 22 colores por modo, 29 roles y 56 parejas por modo, 224 en total; todos los ratios superan sus umbrales sin redondeo previo |
| Correspondencia humana/máquina | Los 88 pares OKLCH/HEX del Markdown coinciden exactamente con el JSON; la conversión independiente de cada OKLCH reproduce su HEX cuantizado y confirma que todos quedan dentro de sRGB; los cuatro peores casos recalculados reproducen `4.735`, `5.022`, `7.046` y `7.429` para texto |
| Enlaces y privacidad | 174 enlaces Markdown locales sin roturas; los archivos nuevos no contienen rutas privadas, cuentas, correos, credenciales ni secretos |
| Integridad | `git diff --check` limpio; `project.pbxproj` sin diff y con SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| TDD y gates Xcode | No aplican: la unidad cambia exclusivamente documentación y datos de diseño; no modifica código, Assets, configuración, proyecto ni comportamiento ejecutable |

### Estado de entrega del issue #15

El contrato queda versionado en el commit `1ab880c` y se entrega mediante la PR #16, cuya fusión cierra el issue #15. La entrega autorizada incluye la eliminación posterior de la rama local y remota. Colorsets, `AccentColor`, tests de assets y cualquier adopción visual quedan fuera de esta unidad.

## Catálogo C1 — primera página pública y detalle por identidad

- Tracker: [GitHub Issue #13 — Catálogo C1: cargar la primera página pública y abrir el detalle por identidad](https://github.com/JFrancoG/MangaLibrary/issues/13), cerrado mediante la PR #14, iniciada sobre `main@b6909d645a0e28b15a5b19ce935a3139b4598bb0`.
- Rama: `codex/13-catalog-first-page-detail`, creada directamente desde esa base limpia y sincronizada.
- El OpenAPI vivo descubierto desde `/docs` se revalidó antes de implementar: `/openapi/openapi.json` conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b` y coincide con el snapshot versionado.
- El shell mantiene tabs estables para Catálogo, Colección y Cuenta. Catálogo carga únicamente `GET /list/mangas?page=1&per=20`, representa carga, contenido, vacío y error recuperable, y abre un detalle desde el elemento ya cargado mediante `Manga.ID == Int64`, sin segunda petición.
- La frontera compartida es un `HTTPClient` concreto, inmutable, de ámbito app e inyectado desde composición. No existe estado mutable compartido que justifique un actor de instancia ni una invariante global que justifique `@globalActor`; la carpeta se denomina `Networking`.
- `CatalogModel` posee el estado de presentación como `@Observable @MainActor`. Las Views, que son structs declarativas, no llevan `@MainActor` explícito y construyen su `@State` macro mediante asignación directa.
- `CatalogFixtureScenario` localiza de forma segura el valor posterior a `-catalog-fixture`. Un flag sin valor, inválido o solicitado fuera de Debug falla cerrado y nunca deriva a tráfico live.
- Portadas, localización española e inglesa, previews y composición de UI tests son deterministas. Tests y previews no contactan producción.

### RED / GREEN de C1

- RED inicial: `BuildProject(buildForTesting: true)` falló por la ausencia de `CatalogPageRequest` y `CatalogPage`, antes de añadir producción.
- GREEN: transporte HTTP, request exacta, decodificación y mapeo, vocabulario cerrado, cancelación, retry, respuestas tardías, selección y detalle quedaron implementados solo hasta satisfacer las caracterizaciones.
- RED adicionales reprodujeron y cerraron el rechazo de credenciales embebidas en la URL base, el saneamiento de URL de portada y el comportamiento cerrado de los fixtures de lanzamiento.
- Una última RED de auditoría demostró que el modelo no conservaba la categoría del fallo. GREEN traduce construcción/transporte a `unavailable`, mantiene decodificación y duplicados como `contractDrift`, propaga cancelación y no retiene body, URL ni error subyacente.
- La UI smoke recorre shell, contenido, detalle y tabs con una composición local, y comprueba que la ruta de detalle de Catálogo sobrevive al cambio temporal de tab.

### Validación técnica final de C1

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — proyecto y destino | `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, plan implícito `MangaLibrary`, Xcode 27 build `27A5252f`, Swift 6.4 e iOS 27 |
| Xcode MCP — `BuildProject(buildForTesting: true)` | Snapshot final aprobado en iPhone 17 en 2,274 s, sin errores; Issue Navigator y build log contienen cero warnings estructurados |
| Xcode MCP — suite completa en iPhone 17 | 30/30 pruebas aprobadas: 29 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o tests no ejecutados |
| Xcode MCP — smoke en iPad Air 11-inch (M4) | 1/1 aprobado sobre el snapshot final, incluido detalle y conservación de ruta entre tabs |
| Previews Xcode | Inspeccionadas carga, contenido, vacío, error, detalle, shell iPad y portada ausente/fallida; Large, XXX Large, AX5, inglés, español, modo oscuro y contraste aumentado |
| Localización | `Localizable.xcstrings` válido; 17 claves visibles traducidas en inglés y español, sin estados new, needs review o machine translated |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; `docbuild` Release para iOS genérico aprobado y `.doccarchive` regenerado con warnings DocC como errores |
| ADR 0011 | Exactamente una emisión externa autorizada en `27A5252f`; cero warnings de Swift, Clang o DocC. La excepción no acredita Advanced |
| Integridad y alcance | `git diff --check` limpio; `project.pbxproj` sin diff y SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543`; catálogo JSON válido |
| Enlaces y privacidad | 163 enlaces Markdown locales sin roturas; cero rutas privadas, correos reales o secretos plausibles. Dos credenciales sintéticas bajo `example.test` ejercitan exclusivamente tests negativos |
| Revisión SwiftUI/accesibilidad independiente | Sin hallazgos tras cerrar headings, contraste y preview de fallo; el recorrido manual con tecnologías de asistencia y restauración real de foco queda pendiente |
| Revisión iOS independiente | Sin hallazgos tras cerrar composición, seguridad de URL, fixtures fail-closed, persistencia de navegación y taxonomía segura de errores |

### Alcance excluido de C1

- Página 2, paginación incremental, grid, búsqueda, filtros y ordenación.
- SwiftData, colección, favoritos, outbox, autenticación, Keychain, sesión y sincronización.
- `/search/manga/{id}`, escrituras o pruebas funcionales contra el backend.
- Repositories, use cases, stores, protocolos ceremoniales, actor compartido y `@globalActor`.
- Dependencias externas, cliente OpenAPI generado, `.xctestplan`, WidgetKit, watchOS, App Groups y entitlements.
- Cambios en `project.pbxproj`, scheme, `Shared.xcconfig`, SDD, ADR o snapshot OpenAPI.
- Advanced Release Gate completo, presentación, vídeo y siguiente unidad.

### Estado de entrega de C1

La implementación, los gates técnicos locales y las revisiones independientes están cerrados sin hallazgos. El commit principal `048c7ab` se entregó mediante la PR #14, cuya fusión cerró el issue #13; la rama `codex/13-catalog-first-page-detail` se eliminó local y remotamente como parte del cierre autorizado.

## Reconciliación G0 posterior a la PR #10

- Tracker: [GitHub Issue #11 — Reconciliar Progress tras la PR #10](https://github.com/JFrancoG/MangaLibrary/issues/11).
- Antes de abrir G0, GitHub no tenía issues ni pull requests abiertas; tampoco existía una unidad de producto activa.
- `main`, `origin/main` y su merge-base coincidían en `051a03f895ef55b5fe940574a0fcf5521b9a74bb`, merge de la PR #10, con el worktree limpio.
- La rama de trabajo `codex/11-reconcile-progress-pr-10` se creó directamente desde esa base y el alcance de G0 quedó limitado a este documento.
- El repositorio continúa `PRIVATE` por el cambio de visibilidad realizado antes del primer push del issue #7. Los issues #1, #3, #4, #6 y #7 están cerrados y las PR #2, #5, #8, #9 y #10 fusionadas.
- G0 no ejecuta ni acredita TDD, build, tests, DocC o una nueva validación Xcode porque no cambia código, configuración ni comportamiento de producto.
- G0 se entregó mediante la PR #12, fusionada en `b6909d645a0e28b15a5b19ce935a3139b4598bb0`; el issue #11 está cerrado.

### Validación de G0

- Git y GitHub se releyeron antes de editar: base limpia y sincronizada en `051a03f`, repositorio `PRIVATE`, ningún issue o pull request abierto antes de G0 y ausencia de trabajo de producto activo.
- El diff contiene únicamente `docs/Progress.md`; `git diff --check` termina limpio y `project.pbxproj` conserva SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543`.
- Se comprobaron 163 enlaces Markdown locales sin roturas.
- El escaneo acotado devuelve cero rutas privadas, correos y patrones plausibles de secretos.
- La reauditoría documental independiente termina sin hallazgos después de corregir cronología, estado posterior a G0 y registro de validación.

## Fuente docente y privacidad del issue #7

- Tracker: [GitHub Issue #7 — Versionar el enunciado saneado y definir su límite de publicación](https://github.com/JFrancoG/MangaLibrary/issues/7).
- GitHub confirmó el cambio de visibilidad de `PUBLIC` a `PRIVATE` antes de cualquier push de la rama del enunciado.
- El original exacto se archivó fuera de Git con SHA-256 `7b95ee784ef661eca72b41f49bb2d8b8d2b47f7bfbd6d4d3bf1d30fed490a52c`.
- `docs/sources/Practica_Mis_Mangas_SDP_2026.md` conserva el texto completo, añade únicamente la nota declarada y sustituye el valor demostrativo de 42 caracteres por 42 `X`; SHA-256 saneado `0a4b840a13f87bae482ebf8afa5195a222d4de37b4fdcce43b5be6732011be4a`.
- ADR 0012 mantiene las decisiones DocC selectivas, reemplaza la frontera pública de ADR 0008 y exige autorización separada para visibilidad, redistribución o accesos.
- TDD y Xcode no aplican a esta entrega exclusivamente documental. No se invita todavía a profesores ni se publica DocC o GitHub Pages.

## Icono y recursos del issue #6

- Tracker: [GitHub Issue #6 — Adoptar el icono de Manga Library y organizar los recursos del target](https://github.com/JFrancoG/MangaLibrary/issues/6).
- `Assets.xcassets` e `InfoPlist.xcstrings` se trasladan byte a byte a `MangaLibrary/Resources/`; Git detecta los cuatro movimientos como `R100`.
- `MangaLibrary.icon` conserva el `icon.json` creado por Icon Composer y sus tres capas PNG de 1024 × 1024. El proyecto selecciona `MangaLibrary` como app icon en Debug y Release.
- La captura aportada por el propietario muestra `Assets.xcassets`, `InfoPlist.xcstrings` y `MangaLibrary.icon` bajo `MangaLibrary/Resources` en Copy Bundle Resources. El propietario instaló y lanzó esa configuración en un iPhone 11 físico y observó el icono nuevo; la evidencia no se extrapola a otras capacidades de hardware.
- El enunciado quedó fuera del diff del issue #6 y se incorpora por separado, saneado y auditado, mediante el issue #7.

## Gate técnico del issue #3

- Tracker: [GitHub Issue #3 — Materializar warnings-as-errors y el gate DocC reproducible](https://github.com/JFrancoG/MangaLibrary/issues/3).
- Estado del plan: implementación y validación ejecutadas. Tras confirmar que Xcode 27 beta 6 conserva el warning externo, el propietario aprobó ADR 0011, su contrato ejecutable y el cierre completo mediante PR y merge commit.
- Alcance: adopción consciente del baseline Xcode 27 protegido, configuración compartida, scheme compartido, landing DocC, catálogo de Info.plist, script reproducible, excepción externa acotada y actualización documental proporcional.
- Fuera del alcance: `.xctestplan`, `Localizable.xcstrings`, textos o permisos de producto todavía inexistentes, código o tests de producto, comentarios `///`, artículos, tutoriales, dependencias, publicación, targets y entitlements.

## Base, alineación y preservación

| Evidencia | Estado |
| --- | --- |
| Entregas anteriores | Issue #1 por PR #2, merge `eb340b3`; OpenAPI por PR #5, merge `5ebdcb6`; gate Xcode 27/DocC por PR #8, merge `7522977`; icono y recursos por PR #9, merge `0a30fac`; enunciado saneado y ADR 0012 por PR #10, merge `051a03f`; G0 por PR #12, merge `b6909d6` |
| Base verificada al iniciar G0 | `main`, `origin/main` y merge-base limpios y coincidentes en `051a03f` antes de crear la rama del issue #11 |
| Rama de trabajo de G0 | `codex/11-reconcile-progress-pr-10`, creada directamente desde `051a03f` |
| Base histórica del issue #7 | La rama del issue #7 avanzó de forma fast-forward a `origin/main` en `0a30fac` después de verificar el archive externo, sin pull ni rebase |
| Rama histórica del issue #7 | `codex/7-private-practice-statement` |
| Cambio previo protegido | Verificado antes y después de la alineación: 34 inserciones, 24 eliminaciones, `git diff --check` limpio |
| SHA-256 inicial protegido | `375f108b069732d9076090ec39668e07a7892da484b18ac933c07c18e2b8e582` |
| Extensión aprobada del proyecto | Frente al snapshot protegido, `project.pbxproj` suma 13 líneas y no elimina ninguna: las 12 de configuración compartida y la región `es`; el contenido previo permanece byte a byte |
| SHA-256 del proyecto tras recursos | `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Alcance histórico del issue #7 | Copia saneada, ADR 0012 y actualización de gobierno, fuentes, navegación, SDD y evidencia; sin código, configuración Xcode ni material docente adicional |
| Alcance histórico de G0 | Reconciliación exclusiva de `docs/Progress.md`; sin producto, configuración Xcode, SDD, ADR, DocC o contrato OpenAPI |
| Base y rama históricas de C1 | `main@b6909d6`; `codex/13-catalog-first-page-detail` para el issue #13 y la PR #14 |

No se usó `stash`, `reset`, `clean`, pull, rebase ni sobrescritura. El snapshot temporal de control permaneció fuera del repositorio.

## Configuración materializada

- `Configuration/Shared.xcconfig` se conecta a las configuraciones Debug y Release del proyecto.
- App, unit tests y UI tests heredan `GCC_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` y `OTHER_DOCC_FLAGS = $(inherited) --warnings-as-errors`.
- `MangaLibrary.xcscheme` queda compartido y versionable; el estado personal de gestión de schemes se retira del control de versiones.
- El catálogo DocC contiene únicamente `MangaLibrary.md`; no se añadieron comentarios, extensiones, artículos ni tutoriales sin contratos reales.
- `MangaLibrary/Resources/InfoPlist.xcstrings` registra inglés y español. `CFBundleDisplayName` conserva `Manga Library` en ambos idiomas por decisión de producto; `CFBundleName` conserva el valor técnico `MangaLibrary` en ambos.
- No se creó ningún `.xctestplan`. Xcode muestra su plan implícito autocreado `MangaLibrary`, que no sustituye los futuros planes `Fast`, `Integration`, `UI` y `ReleaseGate`.

## Validación histórica acumulada hasta G0

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — ventanas, scheme, targets, destino y plan | `MangaLibrary.xcodeproj`; scheme compartido `MangaLibrary`; app, unit y UI tests; iPhone 17 Pro / iOS 27.0; plan implícito `MangaLibrary` |
| Xcode MCP — build settings de los tres targets | Swift 6, iOS 27, iPhone/iPad, concurrencia `complete`, aislamiento `nonisolated` y warnings Swift/Clang como errores |
| `Scripts/validate-docc.sh` — matriz 3 targets × 2 configuraciones | Los cinco ajustes compartidos evaluaron al valor exigido en Debug y Release |
| Clasificador de diagnósticos — 8 escenarios sintéticos | Cero y una emisión exacta pasan; dos exactas, warning o error adicional, severidad modificada, dos diagnósticos en una línea y build distinto fallan con la clasificación esperada |
| Xcode MCP — `BuildProject(buildForTesting: true)` | Debug con los catálogos DocC y de recursos completado en 0,592 s; cero errores y cero warnings estructurados por MCP. El full log conserva tres emisiones del diagnóstico externo descrito debajo, una por target |
| Producto compilado — localizaciones Info.plist | Xcode compiló el catálogo y copió `en.lproj/InfoPlist.strings` y `es.lproj/InfoPlist.strings`; ambos resuelven `CFBundleDisplayName` a `Manga Library` |
| Xcode MCP — smoke Swift Testing | `MangaLibraryTests/example()` pasó: 1 ejecutado, 1 aprobado, 0 fallos |
| Xcode 27 CLI — `build-for-testing`, Release, iPhone 17 Pro / iOS 27.0 | Exit 0; el full log contiene el mismo diagnóstico externo tres veces, una por target; DerivedData temporal eliminado después de validar |
| Gate DocC — `docbuild`, Release, `generic/platform=iOS` | Revalidado después de integrar los recursos con Xcode 27.0 beta 6 build `27A5252f` y Apple Swift 6.4; `--warnings-as-errors` activo, exit 0 y una única emisión externa aceptada por ADR 0011 |
| Archive | `.build/docc/MangaLibrary.doccarchive` creado y comprobado; permanece ignorado por Git |
| Recursos del icono | Cuatro movimientos `R100`; tres PNG válidos de 1024 × 1024; `icon.json` válido y con referencias exactas; app icon `MangaLibrary` en Debug y Release |
| Evidencia física del propietario | Copy Bundle Resources contiene los tres recursos en la ruta aprobada; instalación y lanzamiento en iPhone 11 con el icono nuevo observados por el propietario |
| Integridad del enunciado | El original externo conserva su SHA-256; la copia versionada coincide después de aplicar únicamente la nota declarada y la sustitución exacta de 42 caracteres |
| Visibilidad GitHub | Repositorio verificado como `PRIVATE` antes del primer push que pueda contener la fuente saneada |
| Auditoría estática | `plutil`, `jq`, `xmllint`, `bash -n` y `git diff --check` aprobados; 163 enlaces locales comprobados en 34 Markdown, sin roturas; escaneo de rutas privadas y patrones de secretos sin hallazgos |

El primer intento del smoke no obtuvo resultado porque el simulador no devolvió un proceso al lanzar la app. Xcode MCP lanzó después la app correctamente y la repetición idéntica del test pasó; no se modificó código para resolverlo.

## Diagnóstico de herramienta observado

Xcode 27 beta emite `Metadata extraction skipped, no AppIntents.framework dependency found` desde `appintentsmetadataprocessor` al procesar cada target en los builds Debug y Release, y una vez durante `docbuild`. El comportamiento persistió en la beta 6 build `27A5252f`. Las acciones terminan con exit 0 y MCP no lo devuelve como issue estructurado, pero el texto sí está en sus full logs. No es un warning de Swift, Clang ni DocC; se conserva y atribuye a la herramienta de Xcode. No se añadió un App Intents ficticio, no se activó `LM_FILTER_WARNINGS` —que solo pasaría `--quiet-warnings`— ni se adoptó un ajuste interno para ocultarlo.

ADR 0011 sustituye el bloqueo indefinido por un límite ejecutable: cero diagnósticos pasa; una única coincidencia exacta pasa solo en `27A5252f`; cualquier otra firma, severidad, cantidad o build falla. La excepción no filtra la salida ni relaja los warnings-as-errors propios. Tampoco satisface el Advanced Release Gate, que conserva el requisito de build limpio y cero warnings.

## Revisiones independientes

- La revisión iOS/configuración, incluida la reauditoría del catálogo y la región `es`, terminó sin otros hallazgos. La nueva decisión no suprime el warning: lo limita y hace fallar el gate ante cualquier deriva.
- La revisión SwiftUI/accesibilidad detectó la ausencia inicial de `InfoPlist.xcstrings`; tras la ampliación autorizada, la reauditoría cerró el P2 sin hallazgos. La comprobación manual del nombre y su pronunciación real con VoiceOver queda diferida a evidencia de interfaz/dispositivo.
- La revisión DocC independiente terminó sin hallazgos propios del catálogo o del gate y confirmó que el warning de App Intents es externo a DocC.
- La revisión iOS/configuración de los recursos cerró el único P2 al reconciliar el índice y terminó sin hallazgos: cuatro `R100`, proyecto, PNG e `icon.json` forman un snapshot completo y el enunciado queda excluido.
- La revisión documental y de privacidad del issue #7 terminó sin hallazgos: confirmó visibilidad privada previa al push, transformación exacta, ausencia de secretos o rutas privadas y coherencia entre ADR 0012 y las SDD 00, 07 y 08.

## Completado anteriormente

- Constitución, README, SDD 00–08, ADR 0001–0010, fuentes, progreso y material público inicial entregados mediante la PR #2.
- Contrato OpenAPI saneado, reproducible y enlazado entregado mediante la PR #5.
- Configuración compartida, gate DocC y ADR 0011 entregados mediante la PR #8.
- Icono de Icon Composer y organización de recursos entregados mediante la PR #9.
- Enunciado saneado y ADR 0012 entregados mediante la PR #10; la privacidad se activó externamente antes del primer push de esa entrega.
- Reconciliación documental G0 entregada mediante la PR #12; issue #11 cerrado.
- Primera página pública de Catálogo y detalle local entregados mediante la PR #14; issue #13 cerrado.
- Arquitectura feature-first, navegación local, contratos de SwiftData, autenticación/sync, WidgetKit/watchOS y DocC selectivo aprobados y auditados.
- Separación entre `/docs`, catálogo DocC, artefactos generados y memoria privada definida.

## Hoja de ruta Advanced

La lista de capacidades de la SDD 00 es una puerta de aceptación, no un orden de implementación. El orden operativo parte de dos decisiones ya aprobadas: la colección local se identifica por **usuario + manga** y no existe una política de colección anónima. S1, S2, S2.1, S2.2, L1 y L2 están entregados; L2 se incorpora mediante la PR #50. La secuencia completa es:

1. **S1 — identidad y sesión dual, entregado.** Login Basic hacia refresh JWT, intercambio por access JWT, `/users/session/me`, identidad estable, Keychain para ambos tokens, contraseña solo en memoria, renovación única concurrente, restauración, generaciones de sesión y estados básicos de Cuenta. El logout local cubre el escenario sin operaciones pendientes, pero no acredita todavía el gate Advanced que dependerá de la outbox. La PR #34 introdujo originalmente el ledger descrito por [ADR-0016](adr/0016-versioned-session-ledger-and-keychain-boundary.md); la corrección del 2026-09-01 registrada arriba lo sustituye en el código vigente por un único registro Keychain V2 y borrado condicionado por generación.
2. **S2 — alta de usuario, entregado.** `POST /users` con `App-Token` inyectado desde configuración local ignorada y alta enlazada con login, entregado mediante la PR #36. Una escritura live continúa necesitando autorización separada. S2 no añade todavía Colección.
3. **S2.1 — acciones accesibles de Cuenta, entregado.** La PR #38 da jerarquía primaria y secundaria a las acciones sin sesión, incorpora el prompt de alta y conserva objetivos táctiles nativos y contraste adaptativo sin cambiar sesión, red o persistencia.
4. **S2.2 — formularios de credenciales, entregado mediante la PR #40.** SDD 01 v1.4 y SDD 04 v1.13 definen propiedad de pantalla, gramática conservadora compartida y la compatibilidad exacta del alta con `200` publicado y `201` observado; login y alta presentan errores inline, mantienen los fallos no atribuibles a nivel de formulario, permiten mostrar u ocultar la contraseña con controles SwiftUI sin perder contenido o foco y conservan acciones primarias accesibles. El estado autenticado presenta la identidad segura y el logout con la misma jerarquía visual. No inicia persistencia de producto.
5. **L1 — núcleo SwiftData de Colección, entregado mediante la PR #44.** El composition root crea una sola vez el `ModelContainer` live, declara el esquema V1 y persiste Colección y outbox mediante una capacidad `@ModelActor` compartida. La primera mutación valida invariantes y guarda ambos estados atómicamente, sin una ruta local provisional.
6. **L2 — Colección local y offline, entregada mediante la PR #50.** `@Query` queda restringida a la identidad activa y excluye tombstones; Colección posee navegación independiente y alta, edición y eliminación mediante la ruta semántica de L1. El esquema V2 añade presentación offline con migración lightweight, y tomos, lectura, colección completa, tombstones y aislamiento A/B sobreviven a reapertura sin red.
7. **R1 — lectura e importación remota, entregada mediante la [PR #54](https://github.com/JFrancoG/MangaLibrary/pull/54).** Consume la colección de la persona autenticada al iniciar o restaurar sesión y reconcilia el snapshot completo en SwiftData sin pisar intenciones locales posteriores. Aquí empieza la integración con la persistencia remota; la UI continúa observando exclusivamente el estado local.
8. **R2 — envío y reconciliación de outbox.** Procesar la outbox persistida mediante POST/DELETE, coalescencia, retry, `blockedAuth`, `blockedOutcome`, reversión y protección frente a respuestas tardías. Antes de implementar GET/DELETE por `{id}` debe resolverse o caracterizarse de forma autorizada la ambigüedad entre ID de manga `int64` e ID de entrada UUID. Las escrituras remotas de Colección comienzan aquí y no se prueban contra producción.
9. **Advanced Release Gate.** Completar el logout con operaciones pendientes, aislamiento A→B, recuperación después de crash y toda la evidencia de catálogo, Cuenta, Colección, sincronización, iPhone/iPad, accesibilidad, build, tests y DocC.
10. **Deluxe.** Iniciar WidgetKit, watchOS, App Group, `SessionFence` y los puentes de datos únicamente después de que Advanced quede aceptado.

S2 no es una dependencia técnica del esquema L1 cuando ya existe una identidad autenticable, pero permanece antes del gate Advanced y en una unidad separada porque incorpora el `App-Token`. S2.1 y S2.2 cierran superficies de Cuenta sin iniciar persistencia de producto. La outbox sí pertenece a L1: el worker de R2 puede llegar después, pero ninguna mutación expuesta puede escribir Colección sin registrar o coalescer su intención en la misma operación lógica.

### Trabajo transversal pendiente

1. Revalidar ADR 0011 con cada beta, RC o versión estable de Xcode 27 y retirar la excepción cuando desaparezca el warning.
2. Resolver de forma separada la regresión de descubrimiento de tags de `Fast` e `Integration` antes del Advanced Release Gate.
3. Mantener la clasificación de cada suite nueva mediante su target y tag en el mismo cambio que la introduce.
4. Preparar evidencia, presentación y mecanismo final de entrega cuando exista confirmación externa.

## Estado técnico aún no alcanzado

- El gate técnico del issue #3 se completa bajo ADR 0011; la excepción no acredita una candidata Advanced.
- Catálogo C1–C4, D1, Q1, P1 y Library Red están entregados. La limpieza posterior de tests tautológicos de consulta está en `main@1839c29` y no cambia comportamiento de producto.
- S1 entrega identidad, sesión dual y Keychain de producto mediante la PR #34. Su estado y evidencia originales viven en la sección correspondiente; la corrección Keychain V2 del 2026-09-01 queda registrada separadamente arriba.
- La entrega original de S2 no acreditó una escritura live; la observación manual posterior de `201` y su compatibilidad quedan registradas en S2.2 sin exponer datos de cuenta.
- S2.2 entrega mediante la PR #40 la validación y presentación de credenciales, la corrección HTTP y la autoridad Keychain V2 reconciliadas en el issue #39; no incorpora persistencia de producto.
- L1 entrega mediante la PR #44 `ModelContainer`, esquema V1, modelos SwiftData, outbox y primera mutación atómica. L2 entrega mediante la PR #50 el esquema V2, `@Query`, presentación offline y UI de Colección. R1 entrega mediante la PR #54 la lectura e importación remota con reconciliación local-first; el worker y los envíos continúan reservados a R2.
- No existen todavía targets, entitlements, App Group ni integración WidgetKit que materialicen ADR 0010.
- La evidencia física histórica comprende la instalación y visualización del icono observada por el propietario y las comprobaciones sintéticas de la implementación S1 original. La corrección vigente añade 30/30 casos de sesión aprobados en el iPhone 11, incluido el service Keychain V2 aislado, además de build y lanzamiento del producto; no usa credenciales ni red live. No existe todavía evidencia de accesibilidad física, App Group, WatchConnectivity o integración live.
- No se ha autorizado publicación DocC ni GitHub Pages.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

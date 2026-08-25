# Progreso y evidencia

**Última actualización:** 2026-08-25
**Estado general:** G0 fusionado en `main`; Catálogo C1 está implementado en la rama del issue #13 y pendiente de autorización para su entrega

## Catálogo C1 — primera página pública y detalle por identidad

- Tracker: [GitHub Issue #13 — Catálogo C1: cargar la primera página pública y abrir el detalle por identidad](https://github.com/JFrancoG/MangaLibrary/issues/13), abierto sobre `main@b6909d645a0e28b15a5b19ce935a3139b4598bb0`.
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

La implementación, los gates técnicos locales y las revisiones independientes están cerrados sin hallazgos. No se ha realizado commit, push, PR, merge, cierre del issue ni borrado de rama; esas acciones requieren autorización separada del propietario.

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
| Base y rama actuales de C1 | `main@b6909d6`; `codex/13-catalog-first-page-detail` para el issue #13 |

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
- Arquitectura feature-first, navegación local, contratos de SwiftData, autenticación/sync, WidgetKit/watchOS y DocC selectivo aprobados y auditados.
- Separación entre `/docs`, catálogo DocC, artefactos generados y memoria privada definida.

## Siguiente trabajo

1. Revalidar ADR 0011 con cada beta, RC o versión estable de Xcode 27 y retirar la excepción cuando desaparezca el warning.
2. Conservar el snapshot validado de Catálogo C1 y, solo tras autorización separada, realizar las acciones de entrega aprobadas.
3. No iniciar la siguiente unidad de Catálogo hasta cerrar C1 y acordar su alcance.
4. Implementar el producto restante y superar Advanced antes de iniciar WidgetKit/watchOS y el Deluxe Release Gate.
5. Preparar evidencia, presentación y mecanismo final de entrega cuando exista confirmación externa.

## Estado técnico aún no alcanzado

- El gate técnico del issue #3 se completa bajo ADR 0011; la excepción no acredita una candidata Advanced.
- Catálogo C1 es la única unidad de producto activa: issue #13 y rama `codex/13-catalog-first-page-detail`.
- No existen planes `Fast`, `Integration`, `UI` o `ReleaseGate` versionados.
- C1 implementa solo la primera página pública y su detalle local; colección, autenticación, sincronización, widget y watchOS siguen sin implementar.
- No existen todavía targets, entitlements, App Group ni integración WidgetKit que materialicen ADR 0010.
- La única evidencia física actual es la instalación y visualización del icono en el iPhone 11 observada por el propietario. No existe todavía evidencia de accesibilidad física, Keychain, App Group, WatchConnectivity o integración live.
- No se ha autorizado publicación DocC ni GitHub Pages.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

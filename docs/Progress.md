# Progreso y evidencia

**Última actualización:** 2026-08-28
**Estado general:** G0, Catálogo C1–C4, el contrato cromático Library Red, D1, Q1 y P1 entregados; Library Red ejecutable implementado y revalidado técnica y manualmente, con entrega Git completa autorizada

## Library Red ejecutable — issue #29

- Tracker: [GitHub Issue #29 — Implementar Library Red en Asset Catalog y la UI actual](https://github.com/JFrancoG/MangaLibrary/issues/29), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/29-library-red-assets`, creada desde `main@0b398841b64f27071ac22a133b00dd3a72b7c2ce`, limpio y sincronizado con `origin/main` después de entregar C4.
- El JSON canónico materializa 29 color sets universales sRGB opacos. Cada uno contiene Any/Light, Dark, Increased Contrast Light e Increased Contrast Dark; el placeholder `AccentColor` se retira y `BrandPrimary` queda como único origen de identidad cromática.
- `MainShellView` establece el tint global mediante `.tint(Color(.brandPrimary))`. La UI con superficie final controlada adopta `Canvas`, `BackgroundElevated`, `Surface`, `SurfaceStrong`, `ControlBorder`, `TextPrimary`, `TextSecondary` y `TextTertiary`. Las filas de `List` y `Form` conservan `.primary`/`.secondary` porque su selección o material final pertenece a SwiftUI; así sus estados nativos no quedan forzados a una pareja opaca que deja de ser cierta durante la interacción.
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
del issue #29. El propietario autorizó el 2026-08-28 commit, push, PR, merge,
cierre del issue y borrado de las ramas local y remota; esta autorización no
inicia Colección ni otra fase como efecto lateral.

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
Inspector. Tampoco existe evidencia física ni integración live. El propietario
autorizó el 2026-08-28 commit, push, PR, merge, cierre del issue y borrado de las
ramas. El read-back manual de VoiceOver quedó aprobado con el orden geométrico
observado; esta autorización no inicia Colección ni Library Red como efecto
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

## Siguiente trabajo

1. Revalidar ADR 0011 con cada beta, RC o versión estable de Xcode 27 y retirar la excepción cuando desaparezca el warning.
2. Resolver de forma separada la regresión de descubrimiento de tags de `Fast` e `Integration`, sin mezclarla con el comportamiento C2.
3. Completar la entrega ya autorizada de Catálogo C4; no iniciar Colección ni mezclar la reparación de Q1 como efecto lateral.
4. Mantener la clasificación de cada suite nueva mediante su target y tag en el mismo cambio que la introduce.
5. Implementar el producto restante y superar Advanced antes de iniciar WidgetKit/watchOS y el Deluxe Release Gate.
6. Preparar evidencia, presentación y mecanismo final de entrega cuando exista confirmación externa.

## Estado técnico aún no alcanzado

- El gate técnico del issue #3 se completa bajo ADR 0011; la excepción no acredita una candidata Advanced.
- Catálogo C1 y la decisión normativa D1 están entregados.
- Los planes `Fast`, `Integration`, `UI` y `ReleaseGate` están materializados, ejecutados, revisados y entregados mediante Q1.
- C2, C3 y P1 están entregados; C4 está implementado y revalidado técnicamente, con VoiceOver manual aprobado y entrega completa autorizada. Colección, autenticación, sincronización, widget y watchOS siguen sin implementar.
- No existen todavía targets, entitlements, App Group ni integración WidgetKit que materialicen ADR 0010.
- La única evidencia física actual es la instalación y visualización del icono en el iPhone 11 observada por el propietario. No existe todavía evidencia de accesibilidad física, Keychain, App Group, WatchConnectivity o integración live.
- No se ha autorizado publicación DocC ni GitHub Pages.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

# Progreso y evidencia

**Última actualización:** 2026-08-25
**Estado general:** gobernanza, contrato OpenAPI y gate Xcode 27/DocC fusionados; icono y recursos validados en el issue #6

## Icono y recursos del issue #6

- Tracker: [GitHub Issue #6 — Adoptar el icono de Manga Library y organizar los recursos del target](https://github.com/JFrancoG/MangaLibrary/issues/6).
- `Assets.xcassets` e `InfoPlist.xcstrings` se trasladan byte a byte a `MangaLibrary/Resources/`; Git detecta los cuatro movimientos como `R100`.
- `MangaLibrary.icon` conserva el `icon.json` creado por Icon Composer y sus tres capas PNG de 1024 × 1024. El proyecto selecciona `MangaLibrary` como app icon en Debug y Release.
- La captura aportada por el propietario muestra `Assets.xcassets`, `InfoPlist.xcstrings` y `MangaLibrary.icon` bajo `MangaLibrary/Resources` en Copy Bundle Resources. El propietario instaló y lanzó esa configuración en un iPhone 11 físico y observó el icono nuevo; la evidencia no se extrapola a otras capacidades de hardware.
- El enunciado de la práctica permanece fuera de este cambio y del índice de Git.

## Gate técnico del issue #3

- Tracker: [GitHub Issue #3 — Materializar warnings-as-errors y el gate DocC reproducible](https://github.com/JFrancoG/MangaLibrary/issues/3).
- Estado del plan: implementación y validación ejecutadas. Tras confirmar que Xcode 27 beta 6 conserva el warning externo, el propietario aprobó ADR 0011, su contrato ejecutable y el cierre completo mediante PR y merge commit.
- Alcance: adopción consciente del baseline Xcode 27 protegido, configuración compartida, scheme compartido, landing DocC, catálogo de Info.plist, script reproducible, excepción externa acotada y actualización documental proporcional.
- Fuera del alcance: `.xctestplan`, `Localizable.xcstrings`, textos o permisos de producto todavía inexistentes, código o tests de producto, comentarios `///`, artículos, tutoriales, dependencias, publicación, targets y entitlements.

## Base, alineación y preservación

| Evidencia | Estado |
| --- | --- |
| Entregas anteriores | Issue #1 por PR #2, merge `eb340b3`; OpenAPI por PR #5, merge `5ebdcb6`; gate Xcode 27/DocC por PR #8, merge `7522977` |
| Base adoptada | El commit de recursos `0f02b88` conserva el checkout local y la rama fusiona explícitamente `origin/main` en `7522977`, sin pull ni rebase |
| Rama de entrega | `codex/6-app-icon-resources` |
| Cambio previo protegido | Verificado antes y después de la alineación: 34 inserciones, 24 eliminaciones, `git diff --check` limpio |
| SHA-256 inicial protegido | `375f108b069732d9076090ec39668e07a7892da484b18ac933c07c18e2b8e582` |
| Extensión aprobada del proyecto | Frente al snapshot protegido, `project.pbxproj` suma 13 líneas y no elimina ninguna: las 12 de configuración compartida y la región `es`; el contenido previo permanece byte a byte |
| SHA-256 del proyecto tras recursos | `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Alcance de entrega | Proyecto, cuatro movimientos de recursos, `MangaLibrary.icon` y evidencia proporcional del issue #6; el enunciado queda excluido |

No se usó `stash`, `reset`, `clean`, pull, rebase ni sobrescritura. El snapshot temporal de control permaneció fuera del repositorio.

## Configuración materializada

- `Configuration/Shared.xcconfig` se conecta a las configuraciones Debug y Release del proyecto.
- App, unit tests y UI tests heredan `GCC_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` y `OTHER_DOCC_FLAGS = $(inherited) --warnings-as-errors`.
- `MangaLibrary.xcscheme` queda compartido y versionable; el estado personal de gestión de schemes se retira del control de versiones.
- El catálogo DocC contiene únicamente `MangaLibrary.md`; no se añadieron comentarios, extensiones, artículos ni tutoriales sin contratos reales.
- `MangaLibrary/Resources/InfoPlist.xcstrings` registra inglés y español. `CFBundleDisplayName` conserva `Manga Library` en ambos idiomas por decisión de producto; `CFBundleName` conserva el valor técnico `MangaLibrary` en ambos.
- No se creó ningún `.xctestplan`. Xcode muestra su plan implícito autocreado `MangaLibrary`, que no sustituye los futuros planes `Fast`, `Integration`, `UI` y `ReleaseGate`.

## Validación ejecutada

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — ventanas, scheme, targets, destino y plan | `MangaLibrary.xcodeproj`; scheme compartido `MangaLibrary`; app, unit y UI tests; iPhone 17 Pro / iOS 27.0; plan implícito `MangaLibrary` |
| Xcode MCP — build settings de los tres targets | Swift 6, iOS 27, iPhone/iPad, concurrencia `complete`, aislamiento `nonisolated` y warnings Swift/Clang como errores |
| `Scripts/validate-docc.sh` — matriz 3 targets × 2 configuraciones | Los cinco ajustes compartidos evaluaron al valor exigido en Debug y Release |
| Clasificador de diagnósticos — 8 escenarios sintéticos | Cero y una emisión exacta pasan; dos exactas, warning o error adicional, severidad modificada, dos diagnósticos en una línea y build distinto fallan con la clasificación esperada |
| Xcode MCP — `BuildProject(buildForTesting: true)` | Debug con el catálogo final completado en 0,592 s; cero errores y cero warnings estructurados por MCP. El full log conserva tres emisiones del diagnóstico externo descrito debajo, una por target |
| Producto compilado — localizaciones Info.plist | Xcode compiló el catálogo y copió `en.lproj/InfoPlist.strings` y `es.lproj/InfoPlist.strings`; ambos resuelven `CFBundleDisplayName` a `Manga Library` |
| Xcode MCP — smoke Swift Testing | `MangaLibraryTests/example()` pasó: 1 ejecutado, 1 aprobado, 0 fallos |
| Xcode 27 CLI — `build-for-testing`, Release, iPhone 17 Pro / iOS 27.0 | Exit 0; el full log contiene el mismo diagnóstico externo tres veces, una por target; DerivedData temporal eliminado después de validar |
| Gate DocC — `docbuild`, Release, `generic/platform=iOS` | Revalidado después de integrar los recursos con Xcode 27.0 beta 6 build `27A5252f` y Apple Swift 6.4; `--warnings-as-errors` activo, exit 0 y una única emisión externa aceptada por ADR 0011 |
| Archive | `.build/docc/MangaLibrary.doccarchive` creado y comprobado; permanece ignorado por Git |
| Recursos del icono | Cuatro movimientos `R100`; tres PNG válidos de 1024 × 1024; `icon.json` válido y con referencias exactas; app icon `MangaLibrary` en Debug y Release |
| Evidencia física del propietario | Copy Bundle Resources contiene los tres recursos en la ruta aprobada; instalación y lanzamiento en iPhone 11 con el icono nuevo observados por el propietario |
| Auditoría estática | `plutil`, `jq`, `xmllint`, `bash -n` y `git diff --check` aprobados; 152 enlaces locales comprobados en 32 Markdown, sin roturas; escaneo de rutas privadas y patrones de secretos sin hallazgos |

El primer intento del smoke no obtuvo resultado porque el simulador no devolvió un proceso al lanzar la app. Xcode MCP lanzó después la app correctamente y la repetición idéntica del test pasó; no se modificó código para resolverlo.

## Diagnóstico de herramienta observado

Xcode 27 beta emite `Metadata extraction skipped, no AppIntents.framework dependency found` desde `appintentsmetadataprocessor` al procesar cada target en los builds Debug y Release, y una vez durante `docbuild`. El comportamiento persistió en la beta 6 build `27A5252f`. Las acciones terminan con exit 0 y MCP no lo devuelve como issue estructurado, pero el texto sí está en sus full logs. No es un warning de Swift, Clang ni DocC; se conserva y atribuye a la herramienta de Xcode. No se añadió un App Intents ficticio, no se activó `LM_FILTER_WARNINGS` —que solo pasaría `--quiet-warnings`— ni se adoptó un ajuste interno para ocultarlo.

ADR 0011 sustituye el bloqueo indefinido por un límite ejecutable: cero diagnósticos pasa; una única coincidencia exacta pasa solo en `27A5252f`; cualquier otra firma, severidad, cantidad o build falla. La excepción no filtra la salida ni relaja los warnings-as-errors propios. Tampoco satisface el Advanced Release Gate, que conserva el requisito de build limpio y cero warnings.

## Revisiones independientes

- La revisión iOS/configuración, incluida la reauditoría del catálogo y la región `es`, terminó sin otros hallazgos. La nueva decisión no suprime el warning: lo limita y hace fallar el gate ante cualquier deriva.
- La revisión SwiftUI/accesibilidad detectó la ausencia inicial de `InfoPlist.xcstrings`; tras la ampliación autorizada, la reauditoría cerró el P2 sin hallazgos. La comprobación manual del nombre y su pronunciación real con VoiceOver queda diferida a evidencia de interfaz/dispositivo.
- La revisión DocC independiente terminó sin hallazgos propios del catálogo o del gate y confirmó que el warning de App Intents es externo a DocC.
- La revisión iOS/configuración de los recursos cerró el único P2 al reconciliar el índice y terminó sin hallazgos: cuatro `R100`, proyecto, PNG e `icon.json` forman un snapshot completo y el enunciado queda excluido.

## Completado anteriormente

- Constitución, README, SDD 00–08, ADR 0001–0010, fuentes, progreso y material público inicial entregados mediante la PR #2.
- Contrato OpenAPI saneado, reproducible y enlazado entregado mediante la PR #5.
- Configuración compartida, gate DocC y ADR 0011 entregados mediante la PR #8.
- Arquitectura feature-first, navegación local, contratos de SwiftData, autenticación/sync, WidgetKit/watchOS y DocC selectivo aprobados y auditados.
- Separación entre `/docs`, catálogo DocC, artefactos generados y memoria privada definida.

## Siguiente trabajo

1. Convertir el repositorio en privado y versionar el enunciado completo saneado con su nueva frontera de publicación mediante el [issue #7](https://github.com/JFrancoG/MangaLibrary/issues/7).
2. Revalidar ADR 0011 con cada beta, RC o versión estable de Xcode 27 y retirar la excepción cuando desaparezca el warning.
3. Implementar producto y superar Advanced antes de iniciar WidgetKit/watchOS y el Deluxe Release Gate.
4. Preparar evidencia, presentación y mecanismo final de entrega cuando exista confirmación externa.

## Estado técnico aún no alcanzado

- El gate técnico del issue #3 se completa bajo ADR 0011; la excepción no acredita una candidata Advanced.
- No existen planes `Fast`, `Integration`, `UI` o `ReleaseGate` versionados.
- No hay implementación de catálogo, colección, autenticación, sincronización, widget o watchOS.
- No existen todavía targets, entitlements, App Group ni integración WidgetKit que materialicen ADR 0010.
- La única evidencia física actual es la instalación y visualización del icono en el iPhone 11 observada por el propietario. No existe todavía evidencia de accesibilidad física, Keychain, App Group, WatchConnectivity o integración live.
- No se ha autorizado publicación DocC ni GitHub Pages.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

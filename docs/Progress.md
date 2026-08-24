# Progreso y evidencia

**Última actualización:** 2026-08-25
**Estado general:** gobernanza fusionada; gate Xcode 27/DocC implementado y validado técnicamente en el issue #3, todavía abierto por el warning externo de App Intents

## Gate técnico activo

- Tracker: [GitHub Issue #3 — Materializar warnings-as-errors y el gate DocC reproducible](https://github.com/JFrancoG/MangaLibrary/issues/3).
- Estado del plan: implementación y validación local ejecutadas; el propietario decidió mantener abierto el gate mientras el toolchain emita el warning de App Intents. La localización del nombre visible se amplió y materializó. El checkpoint de rama está autorizado para commit y push; PR, merge y cierre siguen sin autorización.
- Alcance: adopción consciente del baseline Xcode 27 protegido, configuración compartida, scheme compartido, landing DocC, catálogo de Info.plist, script reproducible y actualización documental proporcional.
- Fuera del alcance: `.xctestplan`, `Localizable.xcstrings`, textos o permisos de producto todavía inexistentes, código o tests de producto, comentarios `///`, artículos, tutoriales, dependencias, publicación, targets y entitlements.

## Base, alineación y preservación

| Evidencia | Estado |
| --- | --- |
| Entrega anterior | Issue #1 cerrado por la PR #2; commit documental `43d52b5`, merge commit `eb340b3` |
| Base adoptada | `main` y `origin/main` están en `eb340b3`; la rama activa parte de ese merge commit y suma el checkpoint del issue #3, sin pull ni rebase |
| Rama activa | `codex/3-xcode27-warnings-docc-gate` |
| Cambio previo protegido | Verificado antes y después de la alineación: 34 inserciones, 24 eliminaciones, `git diff --check` limpio |
| SHA-256 inicial protegido | `375f108b069732d9076090ec39668e07a7892da484b18ac933c07c18e2b8e582` |
| Extensión aprobada del proyecto | Frente al snapshot protegido, `project.pbxproj` suma 13 líneas y no elimina ninguna: las 12 de configuración compartida y la región `es`; el contenido previo permanece byte a byte |
| SHA-256 actual del proyecto | `73d0aa5bf5eff5421d19ba6fbb67f0cb3ecc7c97669ecf0e93e2d130402dea65` |
| Alcance de entrega | Un único checkpoint con las rutas exactas del issue #3; sin PR, merge ni cierre |

No se usó `stash`, `reset`, `clean`, pull, rebase ni sobrescritura. El snapshot temporal de control permaneció fuera del repositorio.

## Configuración materializada

- `Configuration/Shared.xcconfig` se conecta a las configuraciones Debug y Release del proyecto.
- App, unit tests y UI tests heredan `GCC_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` y `OTHER_DOCC_FLAGS = $(inherited) --warnings-as-errors`.
- `MangaLibrary.xcscheme` queda compartido y versionable; el estado personal de gestión de schemes se retira del control de versiones.
- El catálogo DocC contiene únicamente `MangaLibrary.md`; no se añadieron comentarios, extensiones, artículos ni tutoriales sin contratos reales.
- `MangaLibrary/InfoPlist.xcstrings` registra inglés y español. `CFBundleDisplayName` conserva `Manga Library` en ambos idiomas por decisión de producto; `CFBundleName` conserva el valor técnico `MangaLibrary` en ambos.
- No se creó ningún `.xctestplan`. Xcode muestra su plan implícito autocreado `MangaLibrary`, que no sustituye los futuros planes `Fast`, `Integration`, `UI` y `ReleaseGate`.

## Validación ejecutada

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — ventanas, scheme, targets, destino y plan | `MangaLibrary.xcodeproj`; scheme compartido `MangaLibrary`; app, unit y UI tests; iPhone 17 Pro / iOS 27.0; plan implícito `MangaLibrary` |
| Xcode MCP — build settings de los tres targets | Swift 6, iOS 27, iPhone/iPad, concurrencia `complete`, aislamiento `nonisolated` y warnings Swift/Clang como errores |
| `Scripts/validate-docc.sh` — matriz 3 targets × 2 configuraciones | Los cinco ajustes compartidos evaluaron al valor exigido en Debug y Release |
| Xcode MCP — `BuildProject(buildForTesting: true)` | Debug con el catálogo final completado en 0,592 s; cero errores y cero warnings estructurados por MCP. El full log conserva tres emisiones del diagnóstico externo descrito debajo, una por target |
| Producto compilado — localizaciones Info.plist | Xcode compiló el catálogo y copió `en.lproj/InfoPlist.strings` y `es.lproj/InfoPlist.strings`; ambos resuelven `CFBundleDisplayName` a `Manga Library` |
| Xcode MCP — smoke Swift Testing | `MangaLibraryTests/example()` pasó: 1 ejecutado, 1 aprobado, 0 fallos |
| Xcode 27 CLI — `build-for-testing`, Release, iPhone 17 Pro / iOS 27.0 | Exit 0; el full log contiene el mismo diagnóstico externo tres veces, una por target; DerivedData temporal eliminado después de validar |
| Gate DocC — `docbuild`, Release, `generic/platform=iOS` | Xcode 27.0 build `27A5237l`, Apple Swift 6.4; `--warnings-as-errors` visible en la invocación DocC; exit 0 y el mismo diagnóstico externo conservado una vez |
| Archive | `.build/docc/MangaLibrary.doccarchive` creado y comprobado; permanece ignorado por Git |
| Auditoría estática | `plutil`, `xmllint`, `bash -n` y `git diff --check` aprobados; 136 enlaces locales comprobados en 30 Markdown, sin roturas; escaneo de rutas privadas y patrones de secretos sin hallazgos |

El primer intento del smoke no obtuvo resultado porque el simulador no devolvió un proceso al lanzar la app. Xcode MCP lanzó después la app correctamente y la repetición idéntica del test pasó; no se modificó código para resolverlo.

## Diagnóstico de herramienta observado

Xcode 27 beta emite `Metadata extraction skipped, no AppIntents.framework dependency found` desde `appintentsmetadataprocessor` al procesar cada target en los builds Debug y Release, y una vez durante `docbuild`. Las acciones terminan con exit 0 y MCP no lo devuelve como issue estructurado, pero el texto sí está en sus full logs. No es un warning de Swift, Clang ni DocC; se conserva y atribuye a la herramienta de Xcode. No se añadió un App Intents ficticio, no se activó `LM_FILTER_WARNINGS` —que solo pasaría `--quiet-warnings`— ni se adoptó un ajuste interno para ocultarlo.

Por tanto, la configuración warnings-as-errors y el gate DocC funcionan, pero el criterio literal del issue «Builds Debug y Release finalizan con cero warnings» todavía no está satisfecho con este build de Xcode. El propietario decidió mantener el gate abierto hasta disponer de un toolchain que no emita el diagnóstico; atribuirlo no equivale a declararlo resuelto.

## Revisiones independientes

- La revisión iOS/configuración, incluida la reauditoría del catálogo y la región `es`, terminó sin otros hallazgos, pero considera bloqueante para el criterio de cero warnings el diagnóstico de `appintentsmetadataprocessor`; suprimirlo no sería una corrección válida.
- La revisión SwiftUI/accesibilidad detectó la ausencia inicial de `InfoPlist.xcstrings`; tras la ampliación autorizada, la reauditoría cerró el P2 sin hallazgos. La comprobación manual del nombre y su pronunciación real con VoiceOver queda diferida a evidencia de interfaz/dispositivo.
- La revisión DocC independiente terminó sin hallazgos propios del catálogo o del gate; confirmó que el warning de App Intents es externo a DocC y permanece como bloqueo del issue.

## Completado anteriormente

- Constitución, README, SDD 00–08, ADR 0001–0010, fuentes, progreso y material público inicial entregados mediante la PR #2.
- Arquitectura feature-first, navegación local, contratos de SwiftData, autenticación/sync, WidgetKit/watchOS y DocC selectivo aprobados y auditados.
- Separación entre `/docs`, catálogo DocC, artefactos generados y memoria privada definida.

## Siguiente trabajo

1. Mantener el issue #3 abierto hasta validar con un Xcode 27 que no emita el warning de App Intents.
2. Revalidar el gate con el siguiente Xcode 27 disponible y, solo con cero warnings, solicitar autorización separada para PR, merge y cierre.
3. Caracterizar y versionar el contrato OpenAPI sin secretos.
4. Implementar producto y superar Advanced antes de iniciar WidgetKit/watchOS y el Deluxe Release Gate.
5. Preparar evidencia, presentación y mecanismo final de entrega cuando exista confirmación externa.

## Estado técnico aún no alcanzado

- El gate del issue #3 todavía no cumple todos sus criterios de aceptación y no está integrado en `main`.
- No existen planes `Fast`, `Integration`, `UI` o `ReleaseGate` versionados.
- No hay implementación de catálogo, colección, autenticación, sincronización, widget o watchOS.
- No existen todavía targets, entitlements, App Group ni integración WidgetKit que materialicen ADR 0010.
- No se ha ejecutado evidencia de hardware, accesibilidad física, Keychain, App Group, WatchConnectivity o integración live.
- No se ha autorizado publicación DocC ni GitHub Pages.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

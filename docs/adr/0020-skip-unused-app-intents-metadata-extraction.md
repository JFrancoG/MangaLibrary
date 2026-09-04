# ADR-0020: Omitir la extracción de App Intents no utilizada

**Estado:** Accepted
**Fecha:** 2026-09-04
**Supersede:** [ADR 0011](0011-bounded-xcode-app-intents-warning-exception.md)
**Superseded by:** —

## Contexto

Manga Library no declara App Intents ni enlaza `AppIntents.framework`. A pesar
de ello, Xcode 27 build `27A5252f` construía una tarea
`ExtractAppIntentsMetadata` para cada target. La herramienta terminaba con éxito,
pero emitía el warning externo que ADR 0011 acotó durante el bootstrap.

Esa excepción no puede acreditar el Advanced Release Gate, que exige un build
limpio. El código fuente oficial de Swift Build declara
`LM_SKIP_METADATA_EXTRACTION` como macro booleana y su
`AppIntentsMetadataTaskProducer` retorna antes de construir tareas cuando evalúa
a `true`. El Xcode instalado materializa el mismo macro y el mismo productor.

## Drivers

- Cumplir el gate Advanced con cero warnings reales, sin filtrar la salida.
- No declarar una dependencia ni una capacidad de producto inexistentes.
- Aplicar la política de forma común a app, unit tests y UI tests.
- Fallar si el proyecto empieza a usar App Intents sin revisar esta decisión.

## Opciones consideradas

1. **Omitir la tarea no aplicable:** evita ejecutar una fase sin entradas y
   conserva visibles todos los diagnósticos de las fases que sí se construyen.
2. **Mantener la excepción de ADR 0011:** conserva el warning conocido, pero no
   permite superar el Advanced Release Gate.
3. **Activar `LM_FILTER_WARNINGS` o filtrar el log:** aparenta limpieza y puede
   ocultar diagnósticos nuevos de la herramienta.
4. **Enlazar App Intents o añadir una intención vacía:** cambia capacidades del
   producto únicamente para condicionar el toolchain.

## Decisión

`Configuration/Shared.xcconfig` fija
`LM_SKIP_METADATA_EXTRACTION = YES`. Como todos los targets y configuraciones
heredan ese fichero, Swift Build no construye la tarea de extracción de App
Intents para Manga Library, MangaLibraryTests o MangaLibraryUITests.

Esto no es una supresión: la herramienta no se ejecuta y no existe un warning
que silenciar. Los warnings de Swift, Clang, DocC y del resto de herramientas
continúan siendo bloqueantes. `Scripts/validate-advanced-build.sh` compila los
tres targets en Debug y Release, y `Scripts/validate-docc.sh` exige el ajuste
efectivo en ambas configuraciones antes del archive Release. Los dos rechazan
cualquier warning o error sin allowlist.

La decisión solo es válida mientras el repositorio no declare App Intents,
`AppShortcuts` ni una dependencia real de `AppIntents.framework`. No anticipa
ninguna capacidad Deluxe.

## Consecuencias

### Positivas

- Los builds dejan de crear una fase ajena al producto y quedan realmente
  limpios.
- ADR 0011 y su clasificador temporal dejan de formar parte del gate vigente.
- La configuración cubre targets presentes y futuros que hereden la política
  compartida.

### Negativas

- El macro pertenece a la implementación publicada de Swift Build y no aparece
  en la referencia visible de Build Settings de Xcode; una actualización del
  toolchain exige verificar que conserva su semántica.
- Adoptar App Intents requerirá retirar primero la omisión y añadir validación
  propia de su metadata.

## Validación

- Comprobar el valor efectivo `YES` en app, unit tests y UI tests para Debug y
  Release.
- Ejecutar un `build-for-testing` de `ReleaseGate` y verificar que no existe una
  tarea `ExtractAppIntentsMetadata`, una invocación de
  `appintentsmetadataprocessor` ni warnings o errores.
- Generar el archive DocC Release con warnings como errores y cero allowlists.
- Conservar `SWIFT_TREAT_WARNINGS_AS_ERRORS`,
  `GCC_TREAT_WARNINGS_AS_ERRORS` y `--warnings-as-errors` activos.

## Condiciones de revisión

- El producto adopta App Intents, App Shortcuts o una dependencia de
  `AppIntents.framework`.
- Swift Build retira, renombra o cambia la semántica del macro.
- Una actualización de Xcode vuelve a construir la fase o emite un diagnóstico.

## Fuentes verificadas

- [Declaración de `LM_SKIP_METADATA_EXTRACTION` en Swift Build](https://github.com/swiftlang/swift-build/blob/990525f9dd8a29f17448b92bef69ece0a9579f2d/Sources/SWBCore/Settings/BuiltinMacros.swift)
- [Uso del macro en `AppIntentsMetadataTaskProducer`](https://github.com/swiftlang/swift-build/blob/990525f9dd8a29f17448b92bef69ece0a9579f2d/Sources/SWBApplePlatform/AppIntentsMetadataTaskProducer.swift)

## Especificaciones relacionadas

- [ADR 0001: plataforma, toolchain y warnings como errores](0001-toolchain-platform-and-warning-policy.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
- [Documentación y DocC](../specs/07-documentation-and-docc.md)

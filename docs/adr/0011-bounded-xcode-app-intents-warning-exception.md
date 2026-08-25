# ADR-0011: Excepción acotada para el warning de App Intents de Xcode

**Estado:** Accepted
**Fecha:** 2026-08-25
**Supersede:** —
**Superseded by:** —

## Contexto

La configuración compartida hace que los warnings de Swift y Clang sean errores
en todos los targets y que DocC construya con `--warnings-as-errors`. Aun así,
Xcode 27 beta ejecuta `appintentsmetadataprocessor` aunque Manga Library no
dependa de `AppIntents.framework` y escribe este diagnóstico en el log:

```text
warning: Metadata extraction skipped, no AppIntents.framework dependency found
```

El warning permaneció al actualizar de Xcode build `27A5237l` a la beta 6,
build `27A5252f`. Las acciones terminan con exit code 0 y Xcode no registra un
issue estructurado. La emisión no procede de Swift, Clang ni DocC y no revela
un defecto del código o del catálogo de documentación del proyecto.

La política de cero warnings no permite normalizar ruido indefinido, pero
mantener abierto el bootstrap hasta que una beta deje de emitirlo tampoco añade
evidencia sobre el producto. Hace falta una excepción verificable que falle en
cuanto cambie cualquiera de sus límites.

## Drivers

- Mantener cero warnings de Swift, Clang y DocC sin ocultar diagnósticos.
- Conservar visible y atribuida una emisión externa que el proyecto no puede
  corregir.
- Detectar automáticamente cambios de toolchain, firma, severidad o cantidad.
- No añadir una dependencia o una capacidad de App Intents ficticia.

## Opciones consideradas

1. **Excepción exacta y temporal en el gate:** permite cerrar el bootstrap, pero
   exige revalidar cada build de Xcode y mantener la excepción estrecha.
2. **Mantener el issue abierto hasta que desaparezca:** evita toda excepción,
   pero convierte el calendario de una beta externa en condición de integración
   aunque las superficies propias ya estén limpias.
3. **Suprimir o filtrar warnings de la herramienta:** produciría un log
   artificialmente limpio y podría ocultar diagnósticos futuros.
4. **Añadir `AppIntents.framework` o una App Intent vacía:** evitaría el mensaje
   a costa de declarar una capacidad que el producto no usa.

## Decisión

Se acepta temporalmente una única emisión de
`appintentsmetadataprocessor` con severidad `warning` y mensaje exacto
`Metadata extraction skipped, no AppIntents.framework dependency found`, solo
en Xcode build `27A5252f`.

`Scripts/validate-docc.sh` aplicará el contrato ejecutable siguiente:

- cero warnings y cero errores pasan sin usar la excepción;
- exactamente una emisión con productor, severidad y mensaje autorizados pasa
  únicamente en el build `27A5252f`;
- dos o más emisiones autorizadas, cualquier otro warning o error, o la misma
  emisión en otro build hacen fallar el gate;
- el script sigue comprobando los warnings-as-errors efectivos de Swift, Clang y
  DocC antes de ejecutar `docbuild`.

La evidencia observada por acción es una emisión en un build normal de la app,
tres en `build-for-testing` —una por target— y una en `docbuild`. El script
versionado controla la acción `docbuild`; los demás builds deben conservar el
diagnóstico visible y respetar esos límites cuando se registren como evidencia.

La excepción no activa `LM_FILTER_WARNINGS`, `--quiet-warnings`, ajustes de
supresión ni filtros de salida; tampoco añade `AppIntents.framework`. Un build
con exit code distinto de cero o con un issue estructurado continúa fallando.
Los warnings de Swift, Clang y DocC no tienen ninguna excepción.

Esta decisión permite completar el gate técnico del bootstrap, pero no relaja el
Advanced Release Gate: una candidata Advanced debe llegar con un build limpio y
cero warnings. La excepción se revisará en cada beta, RC o versión estable de
Xcode 27.

## Consecuencias

### Positivas

- El diagnóstico externo permanece visible, atribuido y medido.
- Una deriva pequeña deja de coincidir y bloquea automáticamente el gate.
- El proyecto no incorpora código, frameworks ni ajustes ficticios.

### Negativas

- El gate conoce de forma temporal un build concreto de Xcode.
- Cada actualización del toolchain exige repetir la validación y revisar esta
  decisión si el warning persiste.
- La rama principal puede conservar un warning externo durante el bootstrap,
  aunque no sea admisible en una candidata Advanced.

## Validación

- Ejecutar `Scripts/validate-docc.sh` con Xcode build `27A5252f` y comprobar una
  única emisión autorizada, exit code 0 y un solo
  `.build/docc/MangaLibrary.doccarchive`.
- Verificar que el script falla con una firma, severidad, cantidad o build de
  Xcode distintos y que pasa sin excepción cuando no existe ningún diagnóstico.
- Confirmar mediante Xcode que los builds no presentan issues estructurados y
  conservar el full log para atribuir la emisión externa.
- Mantener `SWIFT_TREAT_WARNINGS_AS_ERRORS`,
  `GCC_TREAT_WARNINGS_AS_ERRORS` y `--warnings-as-errors` activos.

## Condiciones de revisión

- El warning desaparece: retirar la allowlist ejecutable y deprecar esta
  excepción.
- El warning persiste en otro build: el gate debe fallar hasta una nueva decisión
  explícita.
- Cambian productor, mensaje, severidad, cantidad o clasificación estructurada.
- Manga Library adopta una dependencia real de App Intents.
- Se valida una RC o versión estable de Xcode 27; como máximo la excepción expira
  al llegar a la versión estable.

## Especificaciones relacionadas

- [ADR 0001: plataforma, toolchain y warnings como errores](0001-toolchain-platform-and-warning-policy.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
- [Documentación y DocC](../specs/07-documentation-and-docc.md)

# ADR-0004: SwiftData local-first y actores de modelo

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

La colección debe responder sin depender de red y conservar invariantes mientras
la sincronización ocurre en segundo plano. SwiftData ya ofrece modelos,
observación, consultas y contextos, por lo que una capa genérica adicional
ocultaría semántica importante sin aportar otra fuente de datos actual.

## Drivers

- Mantener la experiencia local-first y consultas reactivas en SwiftUI.
- Respetar el aislamiento contextual de `ModelContext` y sus modelos.
- Poder evolucionar el esquema sin perder bibliotecas existentes.

## Opciones consideradas

1. **SwiftData directo con aislamiento contextual:** integra el stack nativo y
   reduce capas, pero acopla el dominio persistido a SwiftData.
2. **Repositorios genéricos sobre SwiftData:** facilitan dobles superficiales,
   aunque duplican consultas y transacciones y ocultan el contexto.
3. **Core Data o almacenamiento manual:** ofrecen mayor control, a costa de más
   infraestructura sin una necesidad demostrada.

## Decisión

Los datos persistidos usarán `@Model`; SwiftUI consultará directamente con
`@Query` cuando sea adecuado. El composition root creará el `ModelContainer` y
cada operación respetará el actor de su `ModelContext`. El trabajo persistente
fuera de la UI se encapsulará en tipos `@ModelActor`; entre actores se pasarán
identificadores o valores `Sendable`, nunca instancias de modelo vivas.

El esquema tendrá versión explícita y un plan de migración antes de cambiar una
versión publicada. No se creará una capa Repository genérica por defecto.

## Consecuencias

### Positivas

- Menos traducciones entre modelos y actualización natural de la UI.
- Las operaciones en segundo plano tienen un propietario de contexto verificable.
- La evolución del almacén queda planificada y probada.

### Negativas

- Parte del dominio persistido queda ligado a SwiftData y sus limitaciones.
- Los tests necesitan contenedores en memoria y fixtures de migración reales.
- No se pueden compartir libremente modelos entre actores.

## Validación

- Probar invariantes y consultas con un `ModelContainer` en memoria.
- Probar cada migración desde un almacén fixture de la versión anterior.
- Compilar los flujos de `@ModelActor` con concurrencia estricta y ejercer errores
  y cancelación.

## Condiciones de revisión

- SwiftData no puede expresar una migración o consulta necesaria con fiabilidad.
- Aparece una segunda implementación de persistencia real que justifica un
  contrato de abstracción.

## Especificaciones relacionadas

- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)

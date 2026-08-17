# ADR-0003: Concurrencia y aislamiento predeterminado

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

La app combinará UI, red, persistencia y sincronización. Aislar todo el módulo al
actor principal ocultaría decisiones de concurrencia; dejar el aislamiento
implícito en cada tipo haría difícil razonar sobre seguridad y rendimiento.

## Drivers

- Mantener la UI segura y predecible sin serializar trabajo independiente en el
  actor principal.
- Hacer visibles los cruces de aislamiento y la propiedad de datos.
- Conservar cancelación, prioridades y vida estructurada de las tareas.

## Opciones consideradas

1. **Aislamiento predeterminado `nonisolated` y anotaciones explícitas:** aporta
   límites claros, con más trabajo de diseño en cada cruce.
2. **Aislamiento predeterminado `MainActor`:** simplifica UI, pero puede arrastrar
   red, transformaciones y persistencia al actor principal.
3. **Escapes no estructurados para trabajo en segundo plano:** parecen simples,
   pero debilitan cancelación, prioridades y verificación de `Sendable`.

## Decisión

El módulo tendrá aislamiento predeterminado `nonisolated`. Los ViewModels y el
estado o los efectos de presentación que dependan del actor principal se aislarán
explícitamente con `@MainActor`. Las Views seguirán el aislamiento que establezca
su contrato real y solo añadirán la anotación cuando corresponda; no se aplicará
como regla global. Los servicios y actores declararán el aislamiento adecuado a
su estado. Se usará concurrencia estructurada y se transferirán valores
`Sendable` entre dominios. No se aceptarán `Task.detached`,
`nonisolated(unsafe)`, `@unchecked Sendable` ni otros escapes inseguros sin una
justificación localizada y una decisión que documente el riesgo.

## Consecuencias

### Positivas

- Los accesos a UI quedan protegidos y el trabajo independiente puede ejecutarse
  fuera del actor principal.
- El compilador puede verificar cruces de aislamiento y transferencias.

### Negativas

- Las dependencias y resultados que cruzan actores requieren diseño `Sendable`.
- El código contiene más anotaciones explícitas y pruebas de cancelación.

## Validación

- Compilar con comprobación estricta de concurrencia y cero warnings.
- Probar cancelación y orden de estados en operaciones asíncronas relevantes.
- Auditar cualquier escape de aislamiento como hallazgo bloqueante.

## Condiciones de revisión

- Swift cambia sustancialmente sus reglas de aislamiento predeterminado.
- La evidencia de rendimiento o seguridad exige otro límite de actor.

## Especificaciones relacionadas

- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)

# Architecture Decision Records

Este directorio conserva las decisiones arquitectónicas de Manga Library y el
razonamiento que permite revisarlas con el tiempo. Las especificaciones explican
qué debe hacer el producto; los ADR registran decisiones técnicas transversales y
sus compromisos.

## Índice

| ADR | Decisión | Estado | Fecha |
| --- | --- | --- | --- |
| [0001](0001-toolchain-platform-and-warning-policy.md) | Plataforma, toolchain y warnings como errores | Accepted | 2026-08-17 |
| [0002](0002-feature-first-and-composition-root.md) | Arquitectura feature-first y composition root | Accepted | 2026-08-17 |
| [0003](0003-concurrency-and-default-isolation.md) | Concurrencia y aislamiento predeterminado | Accepted | 2026-08-17 |
| [0004](0004-swiftdata-local-first-and-model-actors.md) | SwiftData local-first y actores de modelo | Accepted | 2026-08-17 |
| [0005](0005-hybrid-testing-strategy.md) | Estrategia híbrida de pruebas | Accepted | 2026-08-17 |
| [0006](0006-authentication-keychain-and-sync.md) | Autenticación, Keychain y sincronización | Accepted | 2026-08-17 |
| [0007](0007-watchos-widgetkit-and-data-bridges.md) | Puentes de datos para watchOS y WidgetKit | Accepted | 2026-08-17 |
| [0008](0008-selective-docc-and-publishing-boundaries.md) | DocC selectivo y límites de publicación | Accepted | 2026-08-17 |
| [0009](0009-native-source-owned-features-and-local-navigation.md) | Flujos nativos por fuente y navegación local | Accepted | 2026-08-17 |
| [0010](0010-widgetkit-event-driven-freshness.md) | Frescura dirigida por eventos para WidgetKit | Accepted | 2026-08-18 |

## Inmutabilidad y supersesión

Un ADR aceptado es un registro histórico: no se reescribe para cambiar la
decisión o sus compromisos. Las correcciones puramente editoriales y los enlaces
pueden mantenerse, pero un cambio semántico exige un ADR nuevo. El ADR nuevo debe
indicar a cuál supersede; el anterior cambia su estado a `Superseded` y enlaza al
nuevo, sin borrar su contenido.

Estados admitidos:

- `Proposed`: pendiente de decisión.
- `Accepted`: vigente y aprobada.
- `Rejected`: considerada y descartada.
- `Deprecated`: ya no se recomienda, pero no tiene sustitución directa.
- `Superseded`: sustituida por otro ADR identificado expresamente.

Para proponer una decisión, copia [template.md](template.md), asigna el siguiente
número correlativo, documenta opciones y consecuencias honestas, y actualiza este
índice en la misma PR.

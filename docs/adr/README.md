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
| [0006](0006-authentication-keychain-and-sync.md) | Autenticación, Keychain y sincronización | Superseded | 2026-08-17 |
| [0007](0007-watchos-widgetkit-and-data-bridges.md) | Puentes de datos para watchOS y WidgetKit | Accepted | 2026-08-17 |
| [0008](0008-selective-docc-and-publishing-boundaries.md) | DocC selectivo y límites de publicación | Superseded | 2026-08-17 |
| [0009](0009-native-source-owned-features-and-local-navigation.md) | Flujos nativos por fuente y navegación local | Superseded | 2026-08-17 |
| [0010](0010-widgetkit-event-driven-freshness.md) | Frescura dirigida por eventos para WidgetKit | Superseded | 2026-08-18 |
| [0011](0011-bounded-xcode-app-intents-warning-exception.md) | Excepción acotada para el warning de App Intents de Xcode | Superseded | 2026-08-25 |
| [0012](0012-private-repository-and-sanitized-practice-source.md) | Repositorio privado y fuente docente saneada | Superseded | 2026-08-25 |
| [0013](0013-advanced-logout-and-deluxe-bridge-boundary.md) | Frontera de logout Advanced y bridge Deluxe | Superseded | 2026-08-25 |
| [0014](0014-native-flows-live-composition-and-direct-doubles.md) | Flujos nativos, composición live y dobles directos | Superseded | 2026-08-27 |
| [0015](0015-native-flows-live-composition-and-adaptive-navigation.md) | Flujos nativos, composición live y navegación adaptable | Superseded | 2026-08-28 |
| [0016](0016-versioned-session-ledger-and-keychain-boundary.md) | Ledger versionado y frontera Keychain de sesión | Superseded | 2026-08-30 |
| [0017](0017-validated-http-status-response-boundary.md) | Flujos nativos y respuesta HTTP con status validado | Accepted | 2026-08-31 |
| [0018](0018-single-keychain-session-bundle-and-atomic-logout.md) | Bundle único de sesión en Keychain y logout atómico | Superseded | 2026-09-01 |
| [0019](0019-single-jwt-session-and-keychain-v3.md) | JWT único de sesión y envelope Keychain V3 | Accepted | 2026-09-02 |
| [0020](0020-skip-unused-app-intents-metadata-extraction.md) | Omitir la extracción de App Intents no utilizada | Accepted | 2026-09-04 |
| [0021](0021-widget-reading-rotation-and-priority.md) | Rotación de lecturas y prioridad de la última edición | Superseded | 2026-09-07 |
| [0022](0022-widget-collection-projection-and-adaptive-reading.md) | Colección en mediano y lectura adaptable | Accepted | 2026-09-07 |
| [0023](0023-temporary-public-access-for-assessment.md) | Acceso público temporal para la corrección académica | Accepted | 2026-09-18 |

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

# Progreso y evidencia

**Última actualización:** 2026-08-18
**Estado general:** bootstrap documental y refinamientos arquitectónicos completados; entrega trazada mediante GitHub Issue y PR

## Entrega de este bloque

- Tracker: [GitHub Issue #1 — Establecer la gobernanza y definición inicial del proyecto](https://github.com/JFrancoG/MangaLibrary/issues/1).
- Estado del plan: implementado y auditado; la entrega autorizada usa una PR con `Closes #1` y GitHub conserva su estado definitivo.
- Alcance actual: constitución, README, SDD 00–08, ADR 0001–0010, fuentes, progreso y material público inicial.
- Fuera del alcance actual: configuración Xcode, test plans, catálogo DocC y código de producto.

## Baseline verificado

| Evidencia | Estado |
| --- | --- |
| Raíz Git | Checkout de MangaLibrary verificado; la ruta privada local no se versiona |
| Rama base y entrega | `main` en `bcc4281` (`Initial Commit`); gobernanza en `codex/issue-1-governance` |
| Repositorio remoto | `JFrancoG/MangaLibrary`, público; `origin` usa SSH |
| Publicación base | `bcc4281` publicado como `main` antes de crear la rama de gobernanza |
| Cambio previo protegido | `MangaLibrary.xcodeproj/project.pbxproj`, sin stage |
| SHA-256 protegido | `375f108b069732d9076090ec39668e07a7892da484b18ac933c07c18e2b8e582` |
| Diff previo | 34 inserciones, 24 eliminaciones; `git diff --check` limpio antes del bootstrap |
| Xcode verificado en la propuesta | Xcode 27.0, compilador Swift 6.4, SDK iOS 27.0, scheme `MangaLibrary` |

La evidencia de toolchain y proyecto se obtuvo mediante MCP durante la propuesta aprobada. En esta sesión, Xcode MCP respondió pero `XcodeListWindows` no encontró ninguna ventana de proyecto; por tanto no existe una comprobación renovada de scheme, build o tests. `DocumentationSearch` sí confirmó en la documentación del SDK instalado las APIs de tabs tipadas, colapso de `NavigationSplitView`, protocolos personalizados de `URLSessionConfiguration` y `ModelActor`.

## Completado localmente en este bloque

- Repositorio público creado, enlazado como `origin` y con el commit inicial publicado como rama base `main`.
- Issue #1 creado tras comprobar que no existía un issue equivalente.
- Constitución y estructura pública de documentación creadas.
- SDD 00–08 y ADR 0001–0008 redactados conforme a la propuesta aprobada.
- Arquitectura refinada por fuente de verdad: catálogo remoto observable, colección SwiftData directa, sesión/sync aislados y navegación local SwiftUI; ADR 0009 añadido sin reescribir decisiones aceptadas.
- Frescura de WidgetKit definida mediante ADR 0010 y SDD relacionadas: publicación tras commit local completado, publicador serializado, envelope ordinario o fence de sesión seguros antes del reload dirigido, timeline `.never` y ausencia de SLA temporal.
- Auditoría independiente de WidgetKit corregida: `StaticConfiguration + TimelineProvider`, snapshot `Codable & Sendable`, redacción fail-closed, epoch/revisión durable, revalidación de sesión, recuperación de crash y portadas inmutables con retención segura.
- Reauditoría final independiente de WidgetKit cerrada sin hallazgos tras corregir: `SessionFence` compartido con doble lectura, logout ordenado antes de Keychain, apertura final para sesión nueva, rotación de epoch sin bootstrap observado y `WCSession.updateApplicationContext(_:)` como único canal canónico autocontenido para watchOS.
- `Widgets-transcripcion-completa-sin-tiempos.md` registrada únicamente por nombre como fuente histórica no normativa, sin ruta ni contenido crudo.
- Separación entre `/docs`, catálogo DocC y artefactos generados definida.
- Auditoría iOS inicial cerrada sin hallazgos pendientes tras corregir aislamiento condicional, orden de snapshots, resultado remoto ambiguo y límite de XCTest.
- Reauditoría del refinamiento arquitectónico ejecutada sobre AGENTS, SDD 00/01/02/04/06 y ADR 0009; sus hallazgos de identidad, ownership, fixtures, Keychain, trazabilidad y retención de navegación se corrigieron antes del cierre local.
- Auditoría `swift-docc-semantic` cerrada sin hallazgos; catálogo, script y archive quedan correctamente diferidos.
- Los 29 Markdown tienen enlaces locales resolubles y no contienen rutas privadas, secretos detectables ni whitespace final.
- `.gitignore` protege Obsidian, artefactos DocC, DerivedData y cualquier `Local.xcconfig` sin excluir schemes compartidos o test plans.

Este bloque se entrega exclusivamente mediante la PR vinculada al issue #1; el cambio protegido de Xcode queda fuera de su stage y de su diff.

## Siguiente trabajo tras esta entrega

1. Issue separado para warnings-as-errors, configuración compartida, catálogo DocC y gate reproducible.
2. Caracterización/versionado del contrato OpenAPI sin secretos.
3. Implementación y Advanced Release Gate.
4. Widget, watchOS y Deluxe Release Gate.
5. Evidencia, presentación, vídeo opcional y mecanismo final de entrega.

## Estado técnico aún no alcanzado

- Warnings-as-errors todavía no está materializado en todos los targets.
- No existen planes `Fast`, `Integration`, `UI` o `ReleaseGate` versionados.
- No existe catálogo DocC ni archive validado.
- No hay implementación de catálogo, colección, autenticación, sincronización, widget o watchOS.
- No existen todavía targets, entitlements, App Group ni integración WidgetKit que materialicen ADR 0010.
- No se ha ejecutado build ni suite como evidencia de este cambio documental.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

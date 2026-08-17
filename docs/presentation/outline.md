# Outline de presentación

**Estado:** borrador público
**Última revisión:** 2026-08-18
**Objetivo:** explicar decisiones y evidencia de Manga Library sin depender de notas privadas.

## 1. Problema y alcance

- Explorar más de 64.000 mangas sin cargar el catálogo completo.
- Mantener tomos poseídos, tomo de lectura y colección completa.
- Entregar niveles acumulativos: Advanced primero y Deluxe después.

## 2. Experiencia de producto

- Catálogo paginado, búsqueda y filtros.
- Lista, cuadrícula, detalle y portada siempre representada.
- Experiencia adaptada a iPhone e iPad.

## 3. Arquitectura

- Feature-first y composition root.
- SwiftData directo con `@Model`, `@Query` y una ruta semántica de escritura.
- Sin dependencias externas ni capas ceremoniales.

## 4. Concurrencia y estado

- Swift 6.4, aislamiento predeterminado `nonisolated`.
- Estado remoto o transitorio en modelos de feature `@Observable @MainActor`; colección observada directamente con `@Query` y mutada mediante `@ModelActor`.
- Navegación local y tipada por `Manga.ID`, adaptada con componentes SwiftUI nativos sin router global anticipado.
- `@ModelActor`, valores `Sendable`, cancelación y concurrencia estructurada.

## 5. Colección local

- Invariantes de tomos, lectura y colección completa.
- SwiftData como estado observado por la UI.
- Experiencia local-first y evolución mediante esquema/migración.

## 6. Autenticación y sincronización

- Sesión dual JWT en Keychain; nunca contraseña persistida.
- Outbox, coalescencia, reintentos, tombstones y limitación multi-dispositivo.
- Logout sin mezcla de cuentas y sin secretos en logs.

## 7. Deluxe

- Widget `StaticConfiguration + TimelineProvider` pequeño/mediano: misma proyección para todas las instancias, sin App Intent, red ni acceso al store.
- Publicación serializada tras cada commit local completado, recursos inmutables y envelope atómico antes del reload dirigido; timeline `.never`.
- `publicationGeneration`, revisión monotónica y rotación de epoch con un `SessionFence` nuevo cerrado, sin exigir un bootstrap observado.
- Lectura `SessionFence → envelope → SessionFence`; solo dos fences idénticos pueden autorizar el contenido de su epoch y sesión.
- Logout cierra y verifica el fence antes de invalidar sesión o limpiar Keychain; un fallo aborta y ofrece retry, aunque la redacción visual posterior sea eventual.
- Frescura por eventos sin SLA: WidgetKit conserva el control del momento efectivo de presentación.
- Companion watchOS de solo lectura mediante contextos autocontenidos reemplazables de `WCSession.updateApplicationContext(_:)`.
- La app principal conserva la autoridad de edición y sincronización.

## 8. Calidad

- Swift Testing para unidad/integración y XCUITest para UI.
- Gates Advanced y Deluxe, warnings como errores y evidencia reproducible.
- Español/inglés, Dynamic Type, VoiceOver y estados visuales completos.

## 9. DocC y documentación

- DocC avanzado y selectivo para contratos no obvios.
- SDD y ADR como fuente normativa; `/docs` separado de catálogo y archive.
- Publicación diferida y sin plugin externo.

## 10. Demostración y cierre

- Recorrido verificable de Básico → Medio → Avanzado → Deluxe.
- Evidencia real de build/tests/DocC, sin afirmar gates pendientes.
- Limitaciones, riesgos, aprendizaje y siguientes pasos.

Las notas de orador, ensayos y material personal permanecen fuera del repositorio.

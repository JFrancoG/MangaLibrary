# Outline de presentación

**Estado:** relato versionado; presentaciones exportadas, notas y ensayos se gestionan fuera de Git.
**Última revisión:** 2026-09-18
**Objetivo:** explicar decisiones y evidencia de Manga Library sin depender de notas privadas.

## 1. Problema y alcance

- Explorar más de 64.000 mangas sin cargar el catálogo completo.
- Mantener tomos poseídos, tomo de lectura y colección completa.
- Niveles acumulativos: Advanced entregado y DX1–DX5 completadas (5/7).
- DX6/DX7 tienen sus cortes técnicos integrados por PR #89/#91; #90 está cerrado, mientras #88/#77 conservan el gate completo y los pendientes físicos.

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

- Sesión JWT única y envelope Keychain V3; nunca contraseña persistida.
- Outbox, coalescencia, reintentos, tombstones y limitación multi-dispositivo.
- Logout sin mezcla de cuentas y sin secretos en logs.
- La aceptación multidispositivo de R2.2 acredita la ruta decimal y la ausencia reconciliada. No caracteriza el status/body del primer DELETE ni el GET individual presente `200`; conservar esos límites de [la evidencia API](../api/openapi-contract.md#colección).

## 7. Deluxe

- Widget `StaticConfiguration + TimelineProvider`, con un kind y tres familias: pequeño/grande muestran lecturas; mediano, una ficha de colección con propiedad, completitud, total y fecha. La extensión no tiene red, Keychain ni acceso al store SwiftData de la app.
- La app prepara ambas proyecciones desde estado persistido autorizado. Publica recursos y manifest verificados tras el commit local completado y solicita el reload dirigido. Watch recibe exclusivamente lecturas.
- Rotación local acotada: slots de 300 segundos, entry actual más doce futuras y `.atEnd` si hay varios elementos; `.never` para cero/uno o estados sin contenido. El foco de edición de lectura y el de alta local en colección son independientes.
- WidgetKit decide cuándo presenta y renueva la timeline: los 300 segundos no son un plazo garantizado ni implican ejecución continua de la extensión.
- Epoch y revisión monotónica protegen la publicación; la lectura `SessionFence → manifest/recursos → SessionFence` requiere dos fences iguales que autoricen epoch y sesión. Las portadas son recursos preparados e inmutables.
- Logout cierra y verifica el fence antes de invalidar sesión o limpiar Keychain; la redacción visual de caches sigue siendo eventual.
- Companion watchOS de solo lectura mediante contextos autocontenidos reemplazables de `WCSession.updateApplicationContext(_:)`. Conserva caché compatible sin convertirla en autorización vigente ni prometer entrega inmediata.
- La app principal conserva la autoridad de edición, sincronización y publicación. [ADR-0022](../adr/0022-widget-collection-projection-and-adaptive-reading.md) y [SDD 09](../specs/09-deluxe-reading-contract.md) contienen los contratos completos.

## Correcciones integradas después de DX7

- **A01 — PR #93:** la recuperación de contenido Watch vuelve a exigir una capacidad vigente; el reload del widget y el envío al reloj tienen fallos independientes.
- **A02 — PR #95:** se puede reofrecer el candidato exacto tras fallar la persistencia de caché, conservando las barreras y mostrando contenido solo después de verificarlo.
- **A03 — PR #97:** la consulta de outbox filtra por usuario autenticado en SwiftData y devuelve vacío sin sesión; conserva los estados necesarios para sincronizar y la identidad estable del shell.
- **C1–C5 — PR #115/#117/#119/#121/#123:** recuperación del catálogo tras cancelación, tests deterministas, arranque recuperable ante fallos del almacenamiento y simplificación de Colección/formularios. Presentar estos cambios como mantenimiento posterior, sin confundir esta serie C1–C6 con los cortes originales del catálogo.
- **C6 — PR #125:** reutilización de JPEG preparados por digest de sus bytes de origen, con caché de 2 MiB / 128 entradas por pipeline. No evita las cargas de URL ni limita la espera de una fuente lenta. Las mediciones locales y sus límites están en Progress; no equivalen a una mejora garantizada en hardware o red.
- Explicar qué riesgo corrigió cada cambio y enlazar [sus pruebas y límites](../Progress.md); no presentar los tests deterministas como reproducción física.

## 8. Calidad

- Swift Testing para unidad/integración y XCUITest para UI.
- Gates Advanced y Deluxe separados, warnings como errores y evidencia reproducible.
- Español/inglés, Dynamic Type, estados y tecnologías de asistencia con evidencia por superficie y combinación; una preview no acredita VoiceOver, teclado, foco ni scroll.
- **Checkpoint DX7, PR #91:** ReleaseGate 811/811 declaraciones y 1.160 invocaciones; builds Debug/Release y DocC sin warnings. Es el resultado histórico de ese corte.
- **Checkpoint A03, PR #97:** Fast 359/359, Integration 455/455 y UI 11/11, con 567/630/11 invocaciones respectivamente; builds Debug/Release y DocC sin warnings. Son planes ejecutados por separado, no una nueva ejecución de ReleaseGate completo.
- **Último checkpoint de producto — C6, 2026-09-14, PR #125:** commit `0d14d6b`, integrado en `6dfc59d`; ReleaseGate 846 declaraciones / 1.274 invocaciones, incluidos 13 tests UI, iPhone 17 Simulator / iOS 27. Builds Debug/Release de cinco targets y DocC sin warnings/errores. La revisión documental del 18 de septiembre no reejecuta estos gates ni añade evidencia física.
- **Límites vigentes:** H01, protección anterior al primer desbloqueo del iPhone, sigue limitado/no observable y no está aplazado. H02/H03/H04 físicas de Watch se difieren a después de entregar el proyecto por decisión del 2026-09-10; pueden adelantarse con pareja compatible prestada. El gate completo sigue pendiente en #88/#77. Véanse [DX6](../dx6-integration-accessibility.md) y [la excepción acotada de SDD 06](../specs/06-testing-quality-and-accessibility.md#entrega-del-proyecto-con-validación-física-de-watch-diferida).

## 9. DocC y documentación

- DocC avanzado y selectivo para contratos no obvios.
- SDD y ADR como fuente normativa; `/docs` separado de catálogo y archive.
- Publicación diferida y sin plugin externo.

## 10. Demostración y cierre

- Recorrido verificable de Básico → Medio → Avanzado → Deluxe.
- Antes de exportar o actualizar la presentación de entrega, identificar el commit de la candidata y registrar su evidencia aplicable en [Progress](../Progress.md). No renombrar los checkpoints anteriores como validación de esa candidata.
- Mostrar qué se verificó, en qué entorno y qué sigue pendiente; la excepción de Watch no elimina H01 ni permite declarar el Deluxe Release Gate completo aprobado.
- Limitaciones, riesgos, aprendizaje y siguientes pasos.

Las notas de orador, ensayos y material personal permanecen fuera del repositorio.

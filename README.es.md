# Manga Library

[English](README.md) | **Español**

Aplicación nativa SwiftUI para explorar manga y gestionar una colección personal
en iPhone e iPad. Permite registrar tomos en propiedad, progreso de lectura y
colecciones completas, con persistencia local y sincronización por cuenta.
Los widgets de inicio y un companion de Apple Watch de solo lectura amplían
la experiencia.

## Funcionalidades

- **Catálogo:** paginación incremental, búsqueda, filtros, mejores mangas, lista, cuadrícula y detalle. La consulta no requiere cuenta.
- **Colección:** acceso offline a los datos disponibles localmente, tomos en propiedad, progreso de lectura y colección completa, almacenados con SwiftData.
- **Cuenta y sincronización:** alta, sesión JWT única en Keychain, outbox de cambios locales y resolución explícita de escrituras remotas inciertas.
- **Widgets:** pequeño y grande muestran progreso de lectura; el mediano muestra una ficha de colección. Se actualizan tras cambios locales confirmados, con rotación acotada; WidgetKit decide cuándo aparece el contenido.
- **Apple Watch:** snapshots de lectura recibidos mediante WatchConnectivity, con caché offline compatible y sin login independiente.
- **Interfaz:** español e inglés, navegación adaptada a iPhone/iPad, colores Library Red claros/oscuros y evidencia de accesibilidad por superficie.

## Estado del proyecto

Documentación revisada el **18 de septiembre de 2026**, contra `main` en `6dfc59d`.

**Advanced está entregado y la implementación técnica Deluxe DX1–DX7 está
integrada.** El seguimiento formal de Deluxe conserva **5/7 subfases completas**:
DX6 y el Deluxe Release Gate completo mantienen comprobaciones físicas en
[#88](https://github.com/JFrancoG/MangaLibrary/issues/88) y
[#77](https://github.com/JFrancoG/MangaLibrary/issues/77).

- **H01:** la protección del iPhone antes del primer desbloqueo sigue limitada/no observable y pendiente; no se ha aplazado.
- **H02–H04:** pairing, reconexión, entrega en background y tecnologías de asistencia en Watch físico se difieren a después de la entrega por la decisión registrada del propietario. La evidencia de Simulator no los completa.
- **Último cambio integrado:** reutilización de portadas preparadas C6, [PR #125](https://github.com/JFrancoG/MangaLibrary/pull/125). El mantenimiento posterior a DX7 también abarca cancelación/reentrada del catálogo, tests deterministas, arranque recuperable del almacenamiento y simplificación de flujos de Colección y Cuenta.

El último checkpoint automatizado registrado es **C6, 14 de septiembre**:
ReleaseGate aprobó **846 declaraciones de test / 1.274 invocaciones**, incluidos
13 tests UI, en iPhone 17 Simulator con iOS 27. Los builds Debug/Release de cinco
targets y el archive DocC terminaron sin warnings ni errores. Son resultados
fechados, no una ejecución nueva ni la aprobación del gate físico completo.
Consulta [progreso y evidencia](docs/Progress.md).

La fecha objetivo original de entrega era el 15 de septiembre de 2026. El acceso
público para la corrección no acredita por sí solo el cumplimiento de los criterios
de entrega de [SDD 08](docs/specs/08-delivery-presentation-and-video.md). El vídeo es opcional.

## Requisitos y puesta en marcha

- Xcode 27 con compilador Swift 6.4, modo de lenguaje Swift 6 y comprobación estricta de concurrencia.
- iOS/iPadOS 27 para la app principal y los widgets; watchOS 27 para el companion.
- Solo frameworks de Apple; no hay paquetes de terceros que instalar.

1. Abre `MangaLibrary.xcodeproj` en Xcode.
2. Selecciona el scheme compartido `MangaLibrary` y un simulador de iPhone o iPad con iOS 27. Para el companion, usa `MangaLibraryWatch Watch App`.
3. Ejecuta la app para consultar el catálogo público. Las peticiones normales del catálogo necesitan red; el acceso offline a Colección usa datos ya guardados.
4. Para habilitar el alta, copia [`Configuration/Local.xcconfig.example`](Configuration/Local.xcconfig.example) a `Configuration/Local.xcconfig` y configura `MANGA_LIBRARY_APP_TOKEN` localmente mediante el canal privado aprobado. Git ignora la copia. La falta de configuración de registro no impide consultar el catálogo público.

En dispositivos físicos, usa la configuración de firma y App Group aprobada;
los cambios de capacidades o entitlements requieren autorización separada.
Tests y previews usan fixtures sintéticas y no necesitan cuentas, tokens ni
acceso a producción reales.

## Arquitectura y calidad

Cada feature posee su estado y navegación. El composition root crea las
dependencias compartidas; SwiftData y `@Query` proporcionan la fuente local
observada por la interfaz, con mutaciones serializadas mediante `@ModelActor`.
Los modelos `@Observable @MainActor` poseen el estado remoto o transitorio de
presentación. El trabajo entre aislamientos usa identidades y valores `Sendable`
con concurrencia estructurada.

La app principal posee autenticación, edición y sincronización de Colección.
Widgets y Watch consumen proyecciones de solo lectura; no se convierten en
autoridades independientes. Las [SDD](docs/README.md#especificaciones) y los
[ADR aceptados](docs/adr/README.md) definen los contratos.

El scheme compartido ofrece cuatro planes: `Fast` (predeterminado),
`Integration`, `UI` y `ReleaseGate`. Unidad e integración usan Swift Testing;
los tests UI aprobados usan XCUITest. Los warnings de Swift, Clang y DocC son
errores. Ejecución de tests, builds de cinco targets, DocC y evidencia manual
son validaciones separadas.

La [guía de desarrollo y validación](docs/development.md) detalla la configuración
local, el uso del Xcode MCP oficial y los comandos reproducibles de los gates.

## Documentación

La documentación detallada se mantiene principalmente en español. Este README y
su [versión inglesa](README.md) describen el mismo alcance y las mismas limitaciones.

- [Índice documental](docs/README.md)
- [Desarrollo y validación](docs/development.md)
- [Instrucciones del repositorio](AGENTS.md)
- [Progreso y evidencia fechada](docs/Progress.md) · [Changelog](CHANGELOG.md)
- [Decisiones de arquitectura](docs/adr/README.md)
- [Outline de presentación](docs/presentation/outline.md) · [Storyboard del vídeo opcional](docs/video/storyboard.md)
- [Fuentes y autoridad](docs/Sources.md)

La documentación humana vive en `docs/`; el catálogo fuente DocC, en
`MangaLibrary/Documentation/MangaLibrary.docc/`. Archives generados,
presentaciones, vídeo y notas privadas de preparación permanecen fuera de Git.

## Acceso y reutilización

El propietario ha hecho el repositorio **público temporalmente para la corrección
académica**. [ADR 0023](docs/adr/0023-temporary-public-access-for-assessment.md)
registra esa excepción y conserva los límites existentes de fuentes y privacidad.

No se versionan credenciales utilizables, cuentas reales ni rutas privadas.
La única fuente docente completa aprobada es el enunciado saneado: su ejemplo
de `App-Token` contiene 42 `X`. Consulta los [límites de las fuentes](docs/Sources.md).

Este repositorio no incluye una licencia de reutilización. El acceso no concede
permiso para redistribuir el código o el material docente; se reservan todos los derechos.

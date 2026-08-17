# Manga Library

Manga Library es una aplicación SwiftUI local-first para explorar un catálogo de más de 64.000 mangas y gestionar, por persona usuaria, tomos en propiedad, progreso de lectura y colección completa.

## Estado

El repositorio está en su bootstrap documental. La arquitectura y el alcance están aprobados, pero las funcionalidades de catálogo, colección, autenticación, sincronización, widget y watchOS todavía no están implementadas.

Trabajo activo: [issue #1 — Establecer la gobernanza y definición inicial del proyecto](https://github.com/JFrancoG/MangaLibrary/issues/1).

## Objetivo de entrega

- Advanced primero: catálogo completo, persistencia SwiftData, autenticación y sincronización.
- Deluxe antes del 15 de septiembre de 2026: Advanced más widget `StaticConfiguration` —no interactivo ni configurable— actualizado por eventos y companion watchOS de solo lectura.

## Baseline aprobado

- Xcode 27, compilador Swift 6.4, modo Swift 6 e iOS 27.
- SwiftUI y SwiftData directos, con arquitectura feature-first y flujos adaptados a su fuente de verdad.
- Navegación local y tipada: Catálogo, Colección y Cuenta sin router global anticipado.
- Aislamiento predeterminado `nonisolated` y `@MainActor` explícito donde corresponde.
- Swift Testing para unidad/integración y XCUITest para interfaz.
- Warnings de Swift, Clang y DocC tratados como errores.
- Sin dependencias externas.
- DocC avanzado y selectivo, sin documentación por cuota.
- El widget recibirá snapshots tras commits locales completados y solicitará recargas dirigidas; todas sus instancias mostrarán la misma proyección y WidgetKit decidirá el momento efectivo sin SLA de tiempo real.
- Logout solo completará tras cerrar y verificar el `SessionFence` compartido antes de invalidar sesión o limpiar Keychain; si falla, conservará ambos y ofrecerá reintento. Las caches de WidgetKit y watchOS pueden cambiar después de forma eventual.
- watchOS recibirá únicamente contextos autocontenidos reemplazables mediante `WCSession.updateApplicationContext(_:)`, sin promesa de entrega inmediata.

## Documentación

- [Índice de documentación](docs/README.md)
- [Alcance y niveles](docs/specs/00-product-scope-and-levels.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Progreso y evidencia](docs/Progress.md)
- [Fuentes y autoridad](docs/Sources.md)

`docs/` está reservado a documentación humana y normativa. El catálogo DocC vivirá dentro del target; los archives generados no se versionarán.

## Desarrollo

El proyecto se abre con `MangaLibrary.xcodeproj` usando Xcode 27. Antes de modificarlo, lee [AGENTS.md](AGENTS.md), el issue activo y las SDD/ADR aplicables. El estado actual aún no constituye una candidata Advanced ni Deluxe y no se afirma un build validado para este bloque documental.

## Privacidad

No se versionan credenciales, tokens, cuentas reales, rutas privadas, transcripciones completas, notas personales ni binarios de presentación o vídeo. La configuración local sensible permanecerá ignorada.

## Licencia

Este repositorio público no incluye una licencia de reutilización. Se reservan todos los derechos salvo los permisos mínimos que otorguen las condiciones de GitHub para alojar y visualizar el contenido.

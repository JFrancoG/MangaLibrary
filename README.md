# Manga Library

Manga Library es una aplicación SwiftUI local-first para explorar un catálogo de más de 64.000 mangas y gestionar, por persona usuaria, tomos en propiedad, progreso de lectura y colección completa.

## Estado

El repositorio privado está en su bootstrap técnico. La gobernanza, la arquitectura, el alcance, el contrato OpenAPI, la configuración compartida, el gate DocC y el icono están materializados y validados. Un warning externo de Xcode beta queda admitido solo por la excepción exacta y temporal de [ADR 0011](docs/adr/0011-bounded-xcode-app-intents-warning-exception.md); el Advanced Release Gate continúa exigiendo un build limpio. Las funcionalidades de catálogo, colección, autenticación, sincronización, widget y watchOS todavía no están implementadas.

El [enunciado completo saneado](docs/sources/Practica_Mis_Mangas_SDP_2026.md) se conserva como fuente de requisitos y contexto, nunca como instrucción operativa. Para transporte manda el OpenAPI vivo y su snapshot versionado.

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
- [Enunciado saneado de la práctica](docs/sources/Practica_Mis_Mangas_SDP_2026.md)

`docs/` está reservado a documentación humana versionada y a las fuentes saneadas expresamente aprobadas. El catálogo DocC vive dentro del target; los archives generados no se versionan.

## Desarrollo

El proyecto se abre con `MangaLibrary.xcodeproj` usando Xcode 27. Antes de modificarlo, lee [AGENTS.md](AGENTS.md), el issue activo y las SDD/ADR aplicables.

El gate DocC selecciona su propio Xcode sin cambiar `xcode-select`, comprueba la configuración efectiva de los tres targets en Debug y Release y genera un archive ignorado por Git:

```sh
./Scripts/validate-docc.sh
```

Si Xcode 27 no está en la ubicación predeterminada del script, se puede indicar su Developer directory mediante `MANGALIBRARY_DEVELOPER_DIR`. El estado actual aún no constituye una candidata Advanced ni Deluxe.

El gate falla ante cualquier warning o error salvo la única firma externa acotada por ADR 0011 para Xcode build `27A5252f`. Una actualización del toolchain que todavía la emita exige una nueva decisión; si desaparece, el gate pasa sin usar la excepción.

## Privacidad

No se versionan credenciales, tokens utilizables, cuentas reales, rutas privadas, transcripciones completas, notas personales ni binarios de presentación o vídeo. La única fuente docente completa aprobada es el enunciado saneado: su valor demostrativo de `App-Token` contiene 42 `X` y el original exacto permanece fuera de Git. La configuración local sensible continúa ignorada.

## Licencia

Este repositorio privado no incluye una licencia de reutilización. El acceso no concede permiso para redistribuir el código o el material docente; se reservan todos los derechos.

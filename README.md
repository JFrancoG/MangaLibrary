# Manga Library

Manga Library es una aplicación SwiftUI local-first para explorar un catálogo de más de 64.000 mangas y gestionar, por persona usuaria, tomos en propiedad, progreso de lectura y colección completa.

## Estado

El catálogo público está entregado en cuatro cortes: [C1](https://github.com/JFrancoG/MangaLibrary/issues/13) materializa el shell, la primera página y el detalle por `Manga.ID`; [C2](https://github.com/JFrancoG/MangaLibrary/issues/21) añade paginación incremental y lista/cuadrícula; [C3](https://github.com/JFrancoG/MangaLibrary/issues/25) incorpora búsqueda avanzada, filtros y «Mejores»; y [C4](https://github.com/JFrancoG/MangaLibrary/issues/27) enriquece manga y detalle, adopta navegación compacta nativa y anticipa la siguiente página. El contrato cromático y la adopción ejecutable de [Library Red](https://github.com/JFrancoG/MangaLibrary/issues/29) también están entregados.

**S1 — identidad y sesión dual** incorpora el login Basic → refresh → access → identidad estable, restauración, renovación single-flight y logout local recuperable cuando no hay operaciones pendientes. Los JWT permanecen en un bundle Keychain ligado a una generación opaca; un ledger protegido en Application Support conserva versión, UUID, generación opcional, revisión, fase y, durante limpieza, su destino opcional. Cuenta no expone tokens; la contraseña vive solo en el estado transitorio del formulario, se elimina al enviar y no se retiene en el modelo, logs ni persistencia.

**S2 — alta de usuario** añade a Cuenta el contrato `POST /users` con `App-Token` inyectado desde configuración local ignorada. Un alta confirmada enlaza exactamente una vez con el pipeline S1; un resultado remoto incierto no se reintenta automáticamente y un fallo posterior de login conserva el hecho «cuenta creada». Catálogo sigue disponible cuando falta esa configuración y ninguna prueba o preview usa token, cuenta o red live.

El siguiente corte de producto es **L1 — esquema local y outbox atómica**; después llegan la experiencia offline de Colección y la sincronización remota. La identidad estable precede a Colección porque el modelo aprobado se particiona por usuario y manga y no define una colección anónima. La [hoja de ruta Advanced](docs/Progress.md#hoja-de-ruta-advanced) delimita esos cortes; persistencia de producto, Colección, sincronización, WidgetKit y watchOS continúan sin implementar.

La gobernanza, la arquitectura, el contrato OpenAPI, la configuración compartida, el gate DocC y el icono permanecen materializados. [ADR 0013](docs/adr/0013-advanced-logout-and-deluxe-bridge-boundary.md) separa el logout local y recuperable de Advanced de la garantía compartida que se añade al incorporar el bridge Deluxe. Un warning externo de Xcode beta queda admitido solo por la excepción exacta y temporal de [ADR 0011](docs/adr/0011-bounded-xcode-app-intents-warning-exception.md); el Advanced Release Gate continúa exigiendo un build limpio.

El [enunciado completo saneado](docs/sources/Practica_Mis_Mangas_SDP_2026.md) se conserva como fuente de requisitos y contexto, nunca como instrucción operativa. Para transporte manda el OpenAPI vivo y su snapshot versionado.

## Objetivo de entrega

- Advanced primero: catálogo completo, persistencia SwiftData, autenticación y sincronización.
- Deluxe antes del 15 de septiembre de 2026: Advanced más widget `StaticConfiguration` —no interactivo ni configurable— actualizado por eventos y companion watchOS de solo lectura.

## Baseline aprobado

- Xcode 27, compilador Swift 6.4, modo Swift 6 e iOS 27.
- SwiftUI y SwiftData directos, con arquitectura feature-first y flujos adaptados a su fuente de verdad.
- Navegación local y tipada: Catálogo, Colección y Cuenta sin router global anticipado.
- Aislamiento predeterminado `nonisolated`; los propietarios observables de presentación usan `@MainActor`, no las Views declarativas.
- En Xcode 27, las propiedades de estado SwiftUI usan la macro `@State`; la raíz de Catálogo inicializa con su accessor moderno, sin manipular el backing del antiguo property wrapper.
- Swift Testing para unidad/integración y XCUITest para interfaz.
- Warnings de Swift, Clang y DocC tratados como errores.
- Sin dependencias externas.
- DocC avanzado y selectivo, sin documentación por cuota.
- El widget recibirá snapshots tras commits locales completados y solicitará recargas dirigidas; todas sus instancias mostrarán la misma proyección y WidgetKit decidirá el momento efectivo sin SLA de tiempo real.
- Advanced completa logout mediante invalidación local durable, limpieza recuperable de Keychain y aislamiento por usuario, sin depender de capacidades Deluxe. Cuando exista el bridge, el `SessionFence` se cerrará y verificará después de persistir la transición y antes de invalidar la sesión o limpiar Keychain; las caches de WidgetKit y watchOS pueden cambiar después de forma eventual.
- Las peticiones de sesión ignoran la caché HTTP local; la frescura de credenciales e identidad no depende de headers opcionales del servidor.
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

El scheme compartido ofrece cuatro planes versionados en `TestPlans/`:

- `Fast`, predeterminado, incluye el tag Swift Testing `fast` para el ciclo
  determinista habitual;
- `Integration` incluye el tag `integration` para fronteras controladas como
  `URLProtocol`;
- `UI`, para recorridos XCUITest;
- `ReleaseGate`, que ejecuta completos los targets unitario y UI.

Cada plan se selecciona desde **Product > Test Plan** en Xcode. El plan
`ReleaseGate` aporta la ejecución completa de tests, pero una candidata también
requiere por separado el build limpio, el gate DocC y la evidencia manual que
corresponda.

## Privacidad

No se versionan credenciales, tokens utilizables, cuentas reales, rutas privadas, transcripciones completas, notas personales ni binarios de presentación o vídeo. La única fuente docente completa aprobada es el enunciado saneado: su valor demostrativo de `App-Token` contiene 42 `X` y el original exacto permanece fuera de Git. La configuración local sensible continúa ignorada.

## Licencia

Este repositorio privado no incluye una licencia de reutilización. El acceso no concede permiso para redistribuir el código o el material docente; se reservan todos los derechos.

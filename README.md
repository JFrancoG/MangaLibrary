# Manga Library

Manga Library es una aplicación SwiftUI local-first para explorar un catálogo de más de 64.000 mangas y gestionar, por persona usuaria, tomos en propiedad, progreso de lectura y colección completa.

## Estado

El catálogo público está entregado en cuatro cortes: [C1](https://github.com/JFrancoG/MangaLibrary/issues/13) materializa el shell, la primera página y el detalle por `Manga.ID`; [C2](https://github.com/JFrancoG/MangaLibrary/issues/21) añade paginación incremental y lista/cuadrícula; [C3](https://github.com/JFrancoG/MangaLibrary/issues/25) incorpora búsqueda avanzada, filtros y «Mejores»; y [C4](https://github.com/JFrancoG/MangaLibrary/issues/27) enriquece manga y detalle, adopta navegación compacta nativa y anticipa la siguiente página. El contrato cromático y la adopción ejecutable de [Library Red](https://github.com/JFrancoG/MangaLibrary/issues/29) también están entregados.

**S1 — identidad y sesión JWT única** usa `POST /users/jwt/login`, valida la identidad estable mediante `/users/jwt/me` y renueva preventivamente el mismo tipo de JWT mediante `/users/jwt/refresh`. La autoridad vigente, el UUID, la generación opaca, el JWT y su expiración forman un único registro Keychain V3 `WhenUnlockedThisDeviceOnly`, no sincronizable y con un `kSecAttrAccount` fijo no identificador. Los envelopes V1/V2 no se reinterpretan y se retiran para exigir un login nuevo. Logout publica `signedOut` solo después de borrar condicionalmente la generación esperada; un fallo permite reintentar con la sesión activa únicamente mientras su JWT siga vigente, y si vence conserva `authenticationRequired` fail-closed. `authenticationRequired` conserva el UUID únicamente en memoria tras invalidar la credencial e intentar retirar el registro, y no sobrevive a un relanzamiento. Cuenta no expone tokens; la contraseña vive solo en el modelo efímero del formulario, se elimina al enviar o abandonar y no se retiene en `AccountModel`, logs ni persistencia.

**S2 — alta de usuario** añade a Cuenta el contrato `POST /users` con `App-Token` inyectado desde configuración local ignorada. Un alta confirmada enlaza exactamente una vez con el pipeline S1; un resultado remoto incierto no se reintenta automáticamente y un fallo posterior de login conserva el hecho «cuenta creada». Catálogo sigue disponible cuando falta esa configuración y ninguna prueba o preview usa token, cuenta o red live.

**S2.2 — formularios de credenciales** se entrega mediante la [PR #40](https://github.com/JFrancoG/MangaLibrary/pull/40), que reconcilia el alcance final del [issue #39](https://github.com/JFrancoG/MangaLibrary/issues/39). Login y alta comparten una validación tipada; cada presencia de pantalla posee mediante `@State` su modelo `@Observable` para borradores, errores, foco, visibilidad, tarea y limpieza, mientras `AccountModel` conserva sesión y workflow remoto. Los fallos remotos permanecen a nivel de formulario y la contraseña puede mostrarse u ocultarse con controles SwiftUI sin perder contenido o foco.

**L1 — núcleo SwiftData de Colección** se entrega mediante la [PR #44](https://github.com/JFrancoG/MangaLibrary/pull/44), vinculada al [issue #41](https://github.com/JFrancoG/MangaLibrary/issues/41). El composition root crea una sola vez el `ModelContainer` live y conserva la misma capacidad `@ModelActor`; el esquema V1 congela sus modelos de Colección y outbox y declara desde el inicio su plan de migración. La primera mutación cruza aislamiento únicamente con valores `Sendable`, protege la identidad usuario + manga, canonicaliza las invariantes y confirma Colección y outbox en una transacción con rollback explícito.

**L2 — Colección local y offline** está entregada mediante la [PR #50](https://github.com/JFrancoG/MangaLibrary/pull/50), vinculada al [issue #49](https://github.com/JFrancoG/MangaLibrary/issues/49). El esquema V2 añade la presentación offline; la UI filtra por identidad activa con `@Query` y las altas, ediciones y tombstones recorren la capacidad atómica compartida. **R1 — lectura e importación remota** se entrega mediante la [PR #54](https://github.com/JFrancoG/MangaLibrary/pull/54), vinculada al [issue #53](https://github.com/JFrancoG/MangaLibrary/issues/53), con snapshot completo, commit SwiftData único y protección por generación de sesión. **R2.1 — POST y reconciliación conservadora de outbox** está en curso mediante el [issue #57](https://github.com/JFrancoG/MangaLibrary/issues/57): reutiliza el GET completo y procesa únicamente intenciones no tombstone, sin reenvío automático de resultados inciertos. GET/DELETE individual, tombstones y el resto de R2 permanecen pendientes; entitlements, WidgetKit y watchOS también quedan fuera. La [hoja de ruta Advanced](docs/Progress.md#hoja-de-ruta-advanced) delimita esas unidades.

La gobernanza, la arquitectura, el contrato OpenAPI, la configuración compartida, el gate DocC y el icono permanecen materializados. [ADR 0019](docs/adr/0019-single-jwt-session-and-keychain-v3.md) adopta la única familia JWT que el backend live acepta de extremo a extremo, preserva el logout binario de Advanced y mantiene cerrada la garantía compartida que se añadirá al incorporar el bridge Deluxe. Un warning externo de Xcode beta queda admitido solo por la excepción exacta y temporal de [ADR 0011](docs/adr/0011-bounded-xcode-app-intents-warning-exception.md); el Advanced Release Gate continúa exigiendo un build limpio.

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
- Advanced mantiene el logout local sin red mediante el borrado Keychain condicionado a la generación vigente: una eliminación fallida conserva la sesión activa y permite reintentar solo si el JWT sigue vigente; si vence, mantiene `authenticationRequired`, y únicamente una eliminación confirmada publica `signedOut`. Cuando exista el bridge, el `SessionFence` se cerrará y verificará antes de ese borrado condicional; las caches de WidgetKit y watchOS pueden cambiar después de forma eventual.
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

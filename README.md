# Manga Library

Manga Library es una aplicación SwiftUI local-first para explorar un catálogo de más de 64.000 mangas y gestionar, por persona usuaria, tomos en propiedad, progreso de lectura y colección completa.

## Estado

**Advanced está aceptado y entregado** mediante el [issue #75](https://github.com/JFrancoG/MangaLibrary/issues/75) y la [PR #76](https://github.com/JFrancoG/MangaLibrary/pull/76). **Deluxe tiene siete subfases en el [plan #77](https://github.com/JFrancoG/MangaLibrary/issues/77), con DX1–DX3 entregadas** mediante las PR [#80](https://github.com/JFrancoG/MangaLibrary/pull/80), [#81](https://github.com/JFrancoG/MangaLibrary/pull/81) y [#83](https://github.com/JFrancoG/MangaLibrary/pull/83). DX3 completa sus cinco bloques de proyección persistida, prefijo estable, portadas y eventos ordenados; se integra en `fa60f15` y cierra [#82](https://github.com/JFrancoG/MangaLibrary/issues/82).

**DX4 está implementado en el [issue #84](https://github.com/JFrancoG/MangaLibrary/issues/84), rama `codex/84-dx4-reading-widget`, con validación automatizada, Simulator y física completadas en su alcance aprobado; entrega en preparación.** Incluye widget pequeño, mediano y grande EN/ES para iPhone/iPad, App Group, doble fence y publicación ligada al ciclo de vida. La evidencia registra lectura entre procesos, mutación y logout, adaptación iPhone/iPad y continuidad entre ventanas.

La ampliación aprobada el 7 de septiembre añade rotación programada cada cinco minutos, prioridad del manga cuyo tomo cambia y grupos adaptables de hasta seis lecturas. Pasan **716 declaraciones / 1.014 invocaciones** de Swift Testing, incluida la corrección de precisión de fechas detectada al comprobar el reloj real, y builds limpios Debug/Release y DocC sin warnings. Revisión independiente y previews de los tres tamaños completas; Simulator acredita rotación natural y prioridad en iPhone y tamaño grande en portrait/landscape de iPad. [ADR-0021](docs/adr/0021-widget-reading-rotation-and-priority.md) registra el contrato y sus límites: WidgetKit decide el momento efectivo del cambio.

La petición posterior del mismo día está implementada: pequeño con `Tomo N/T`
o `Tomo N`, grande ampliado con 1–4 lecturas reales y mediano «Mi colección»
con una ficha rotatoria, tomos en propiedad, completitud y total de mangas,
incluidos los que no se están leyendo. [ADR-0022](docs/adr/0022-widget-collection-projection-and-adaptive-reading.md)
concreta el recurso local completo y acotado, enlazado al publicador y fence
existentes. Pasan **754 declaraciones / 1.093 invocaciones**, builds limpios y
DocC sin warnings; 29 previews revisadas y revisión independiente de fuente.
La comprobación interactiva de esta ampliación quedó pendiente por Mac bloqueado;
los recorridos anteriores de Simulator conservan su alcance histórico.

El propietario confirma posteriormente que los widgets funcionan como espera.
El ajuste visual siguiente incorpora «¿Qué estás leyendo?» y «Tus mangas, aquí»,
con la ilustración del manga abierto del icono en los estados sin contenido;
se adapta a cada familia y cede espacio al texto con Dynamic Type. Esta
confirmación no identifica hardware ni sustituye pruebas físicas concretas.

La prueba posterior en iPhone11 detectó que WidgetKit rechazaba archivar la
ilustración de1024×1024 y seguía mostrando el estado anterior. Se ha corregido
preparando miniaturas acotadas antes del render. La extensión actual ya no
registra ese rechazo y el propietario confirma que ahora se muestra correctamente
en el iPhone 11.

El ajuste posterior amplía la portada del grande con 1, 5 y 6 lecturas y hace
que un alta local o una reincorporación aparezca primero en «Mi colección».
Después continúa la rotación; los cinco minutos siguen siendo orientativos.
SDD09 v1.10 y ADR-0022 concretan la prioridad local independiente de lectura,
sin guardar un historial de adquisiciones ni cambiar el orden de la colección.
Pasan **763 declaraciones / 1.104 invocaciones**, builds Debug/Release y DocC
sin warnings. La versión está instalada en iPhone11; quedan por confirmar allí
la prioridad al añadir bajo condiciones controladas. Los tamaños se aceptan
posteriormente como parte del cierre visual.

Una segunda petición amplía de nuevo las cinco/seis lecturas: portadas y
texto mayores, menos separación y una alternativa intermedia cuando no caben.
SDD09 v1.11 mantiene el resto de tamaños y la prioridad de nuevas altas.
Quince previews revisadas y builds Debug/Release sin warnings; instalada en
iPhone11 y aceptada visualmente por el propietario.

El propietario confirma el último ajuste del grande y aprueba destacar el
total de «Mi colección» en una pastilla junto al título; abajo queda solo la
fecha. SDD09 v1.12 conserva el conteo y adapta la cabecera al espacio disponible.
Veintiuna previews revisadas y builds Debug/Release sin warnings; instalada en
el iPhone11. El propietario da por terminados todos los ajustes visuales y de
UI y autoriza guardar el avance con commit/push e iniciar VoiceOver.

El [contrato](docs/specs/09-deluxe-reading-contract.md), [Progress](docs/Progress.md) y la [checklist DX4](docs/dx4-widget-validation.md) conservan el alcance de cada ejecución anterior y la validación final. VoiceOver ES/EN, estados, títulos largos, propiedad, rotación, logout y recuperación de los tres widgets están confirmados en iPhone 11 en los casos registrados. SDD09 v1.14 y SDD06 v1.36 recogen el traslado aprobado de la prueba física anterior al primer desbloqueo a DX6: limitada/no observable y pendiente para el gate Deluxe. El binario normal está reinstalado y su contenido confirmado. La entrega de DX4 está autorizada y en preparación; no requiere Apple Watch. **El Deluxe Release Gate no está superado.**

El catálogo público está entregado en cuatro cortes: [C1](https://github.com/JFrancoG/MangaLibrary/issues/13) materializa el shell, la primera página y el detalle por `Manga.ID`; [C2](https://github.com/JFrancoG/MangaLibrary/issues/21) añade paginación incremental y lista/cuadrícula; [C3](https://github.com/JFrancoG/MangaLibrary/issues/25) incorpora búsqueda avanzada, filtros y «Mejores»; y [C4](https://github.com/JFrancoG/MangaLibrary/issues/27) enriquece manga y detalle, adopta navegación compacta nativa y anticipa la siguiente página. El contrato cromático y la adopción ejecutable de [Library Red](https://github.com/JFrancoG/MangaLibrary/issues/29) también están entregados.

**S1 — identidad y sesión JWT única** usa `POST /users/jwt/login`, valida la identidad estable mediante `/users/jwt/me` y renueva preventivamente el mismo tipo de JWT mediante `/users/jwt/refresh`. La autoridad vigente, el UUID, la generación opaca, el JWT y su expiración forman un único registro Keychain V3 `WhenUnlockedThisDeviceOnly`, no sincronizable y con un `kSecAttrAccount` fijo no identificador. Los envelopes V1/V2 no se reinterpretan y se retiran para exigir un login nuevo. Logout publica `signedOut` solo después de borrar condicionalmente la generación esperada; un fallo permite reintentar con la sesión activa únicamente mientras su JWT siga vigente, y si vence conserva `authenticationRequired` fail-closed. `authenticationRequired` conserva el UUID únicamente en memoria tras invalidar la credencial e intentar retirar el registro, y no sobrevive a un relanzamiento. Cuenta no expone tokens; la contraseña vive solo en el modelo efímero del formulario, se elimina al enviar o abandonar y no se retiene en `AccountModel`, logs ni persistencia.

**S2 — alta de usuario** añade a Cuenta el contrato `POST /users` con `App-Token` inyectado desde configuración local ignorada. Un alta confirmada enlaza exactamente una vez con el pipeline S1; un resultado remoto incierto no se reintenta automáticamente y un fallo posterior de login conserva el hecho «cuenta creada». Catálogo sigue disponible cuando falta esa configuración y ninguna prueba o preview usa token, cuenta o red live.

**S2.2 — formularios de credenciales** se entrega mediante la [PR #40](https://github.com/JFrancoG/MangaLibrary/pull/40), que reconcilia el alcance final del [issue #39](https://github.com/JFrancoG/MangaLibrary/issues/39). Login y alta comparten una validación tipada; cada presencia de pantalla posee mediante `@State` su modelo `@Observable` para borradores, errores, foco, visibilidad, tarea y limpieza, mientras `AccountModel` conserva sesión y workflow remoto. Los fallos remotos permanecen a nivel de formulario y la contraseña puede mostrarse u ocultarse con controles SwiftUI sin perder contenido o foco.

**L1 — núcleo SwiftData de Colección** se entrega mediante la [PR #44](https://github.com/JFrancoG/MangaLibrary/pull/44), vinculada al [issue #41](https://github.com/JFrancoG/MangaLibrary/issues/41). El composition root crea una sola vez el `ModelContainer` live y conserva la misma capacidad `@ModelActor`; el esquema V1 congela sus modelos de Colección y outbox y declara desde el inicio su plan de migración. La primera mutación cruza aislamiento únicamente con valores `Sendable`, protege la identidad usuario + manga, canonicaliza las invariantes y confirma Colección y outbox en una transacción con rollback explícito.

**L2 — Colección local y offline** está entregada mediante la [PR #50](https://github.com/JFrancoG/MangaLibrary/pull/50), vinculada al [issue #49](https://github.com/JFrancoG/MangaLibrary/issues/49). El esquema V2 añade la presentación offline; la UI filtra por identidad activa con `@Query` y las altas, ediciones y tombstones recorren la capacidad atómica compartida. **R1 — lectura e importación remota** se entrega mediante la [PR #54](https://github.com/JFrancoG/MangaLibrary/pull/54), vinculada al [issue #53](https://github.com/JFrancoG/MangaLibrary/issues/53), con snapshot completo, commit SwiftData único y protección por generación de sesión. **R2.1/R2.2 — envío y reconciliación de outbox** se entregan mediante la [PR #60](https://github.com/JFrancoG/MangaLibrary/pull/60): R2.1 incorpora POST y reconciliación conservadora; R2.2 añade GET/DELETE individual, envío de tombstones y confirmación destructiva en el editor, con aceptación live multidispositivo de la ruta decimal y la ausencia reconciliada. **R2.3 — recuperación automática de outbox** se entrega mediante la [PR #68](https://github.com/JFrancoG/MangaLibrary/pull/68), vinculada al [issue #67](https://github.com/JFrancoG/MangaLibrary/issues/67): define clasificación conservadora, backoff persistido y cancelable, recuperación de `blockedAuth` y rechazo positivo con rollback atómico. El backoff solo se habilita ante evidencia positiva de que el envío no comenzó; ningún error live actual de `URLSession` se infiere como seguro. **R2.4 — resolución interactiva de resultados inciertos** se entrega mediante la [PR #70](https://github.com/JFrancoG/MangaLibrary/pull/70), vinculada al [issue #69](https://github.com/JFrancoG/MangaLibrary/issues/69): revisa una evidencia remota fresca y permite adoptar la nube o crear conscientemente una intención local nueva, sin reencolar ni repetir la escritura incierta.

La cota transversal del [issue #63](https://github.com/JFrancoG/MangaLibrary/issues/63) se entrega mediante la [PR #64](https://github.com/JFrancoG/MangaLibrary/pull/64): Colección admite números de tomo entre 1 y 300, mientras `nil` sigue significando total editorial desconocido. Entitlements, WidgetKit y watchOS también quedan fuera. La [hoja de ruta Advanced](docs/Progress.md#hoja-de-ruta-advanced) delimita esas unidades.

La gobernanza, la arquitectura, el contrato OpenAPI, la configuración compartida, el gate DocC y el icono permanecen materializados. [ADR 0019](docs/adr/0019-single-jwt-session-and-keychain-v3.md) adopta la única familia JWT que el backend live acepta de extremo a extremo, preserva el logout binario de Advanced y mantiene cerrada la garantía compartida que se añadirá al incorporar el bridge Deluxe. [ADR 0020](docs/adr/0020-skip-unused-app-intents-metadata-extraction.md) supersede la excepción temporal de ADR 0011 y evita construir la fase de metadata de App Intents que el producto no utiliza; los gates vuelven a exigir cero warnings sin allowlists.

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
- El widget recibe snapshots tras commits locales completados y solicita recargas dirigidas; sus tres tamaños muestran ventanas de la misma proyección, con rotación pausada y prioridad de edición, y WidgetKit decidirá el momento efectivo sin SLA de tiempo real.
- Advanced mantiene el logout local sin red mediante el borrado Keychain condicionado a la generación vigente. Si existen cambios de Colección sin resolver, permite mantener la sesión mientras R2 continúa o confirmar su descarte atómico contra la última base remota confirmada localmente; una eliminación Keychain fallida conserva la sesión activa y permite reintentar solo si el JWT sigue vigente, sin resucitar cambios ya descartados. Si vence, mantiene `authenticationRequired`, y únicamente una eliminación confirmada publica `signedOut`. Cuando exista el bridge, el `SessionFence` se cerrará y verificará antes de ese borrado condicional; las caches de WidgetKit y watchOS pueden cambiar después de forma eventual.
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

El gate DocC selecciona su propio Xcode sin cambiar `xcode-select`, comprueba la configuración efectiva de los cuatro targets en Debug y Release y genera un archive ignorado por Git:

```sh
./Scripts/validate-docc.sh
```

El build reproducible de la candidata compila app, unit tests y UI tests en
Debug y Release mediante el plan completo, con DerivedData temporal. El script
habilita testabilidad solo para esta compilación local, de modo que los tests
`@testable` compilen también con el resto de ajustes Release sin cambiar la
configuración distribuida del producto:

```sh
./Scripts/validate-advanced-build.sh
```

Si Xcode 27 no está en la ubicación predeterminada del script, se puede indicar su Developer directory mediante `MANGALIBRARY_DEVELOPER_DIR`. El Advanced Release Gate del issue #75 está aceptado y entregado con la matriz manual y sus límites registrados en [Progreso](docs/Progress.md#advanced-release-gate--issue-75). El [issue #77](https://github.com/JFrancoG/MangaLibrary/issues/77) conserva el plan operativo Deluxe y su siguiente subfase; sus targets y capacidades todavía no están implementados.

El gate falla ante cualquier warning o error. También exige que los tres targets
omitan la extracción de metadata de App Intents mientras el producto no declare
esa capacidad, conforme a ADR 0020; cualquier cambio del toolchain o adopción de
App Intents exige revisar esa decisión.

El scheme compartido ofrece cuatro planes versionados en `TestPlans/`:

- `Fast`, predeterminado, incluye el tag Swift Testing `fast` para el ciclo
  determinista habitual;
- `Integration` incluye el tag `integration` para fronteras controladas como
  `URLProtocol`;
- `UI`, para recorridos XCUITest;
- `ReleaseGate`, que ejecuta completos los targets unitario y UI.

Cada plan se selecciona desde **Product > Test Plan** en Xcode. El plan
`ReleaseGate` aporta la ejecución completa de tests, pero una candidata también
requiere por separado `validate-advanced-build.sh`, el gate DocC y la evidencia
manual que corresponda.

La clasificación versionada se comprueba sin ejecutar tests:

```sh
./Scripts/validate-test-plans.sh
```

El gate exige que cada `@Suite` declare una sola categoría `fast` o
`integration`, valida los targets y filtros de los cuatro planes y conserva
`Fast` como predeterminado. La cardinalidad runtime se obtiene del resumen
nativo del `.xcresult` generado al ejecutar cada plan; el inventario de
`GetTestList` no se usa como oráculo de selección para tags heredados de suite.

## Privacidad

No se versionan credenciales, tokens utilizables, cuentas reales, rutas privadas, transcripciones completas, notas personales ni binarios de presentación o vídeo. La única fuente docente completa aprobada es el enunciado saneado: su valor demostrativo de `App-Token` contiene 42 `X` y el original exacto permanece fuera de Git. La configuración local sensible continúa ignorada.

## Licencia

Este repositorio privado no incluye una licencia de reutilización. El acceso no concede permiso para redistribuir el código o el material docente; se reservan todos los derechos.

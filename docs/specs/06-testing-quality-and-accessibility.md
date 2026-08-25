# SDD 06: Testing, calidad y accesibilidad

**Estado:** Aprobada
**Versión:** 1.8
**Fecha:** 2026-08-25

## Propósito

Definir evidencia proporcional al riesgo para entregar Advanced y Deluxe con cero warnings, sin confundir cantidad de tests con cobertura real.

## Estrategia híbrida

- **Swift Testing** cubrirá tests unitarios y de integración nuevos.
- **XCTest/XCUITest** se reservará para automatización de interfaz.
- No se mezclarán aserciones de ambos frameworks dentro del mismo test.
- El comportamiento nuevo testeable seguirá RED/GREEN. Documentación, configuración y exploración visual registrarán validación proporcional con TDD marcado como no aplicable.
- Ningún test automatizado llamará al servicio de producción.

## Planes previstos

| Plan | Responsabilidad | Ejecución mínima |
| --- | --- | --- |
| `Fast` | Invariantes, transformaciones, estados y lógica determinista | Cada cambio de comportamiento |
| `Integration` | SwiftData, migraciones, URLProtocol, Keychain aislado y composición de fronteras | Cambios en datos, red o sesión |
| `UI` | Flujos críticos, adaptación y accesibilidad automatizable | Gate Advanced y cambios de navegación |
| `ReleaseGate` | Composición aprobada de build, tests, UI y DocC | Candidatas Advanced y Deluxe |

Los ficheros `.xctestplan` se crearán en un issue posterior dedicado a la estrategia de suites. El scheme compartido puede exponer el plan implícito que Xcode autocrea, pero el gate de warnings y DocC no materializa ni afirma que existan todavía `Fast`, `Integration`, `UI` o `ReleaseGate`.

### Aplicabilidad por gate

Los planes seleccionan únicamente suites y targets que pertenecen al gate en
evaluación. Advanced prueba la sesión local, Keychain, outbox, aislamiento,
navegación y recuperación definidos por SDD 04 sin exigir App Group,
`SessionFence`, WidgetKit o WatchConnectivity. Deluxe vuelve a ejecutar Advanced
y añade las suites del bridge compartido, sus targets y sus entitlements.

Un tipo no implementado, un target ausente o un bridge no-op no cuentan como
evidencia. Los casos Deluxe enumerados debajo permanecen como contrato futuro,
pero no bloquean una candidata Advanced anterior a su gate de entrada.

## Cobertura por riesgo

### Unidad

- invariantes de colección y transiciones de edición;
- composición y reinicio de consultas y filtros;
- mapeo de errores de transporte, sesión y dominio;
- máquina de estados de autenticación y sincronización;
- exclusión serializada de activación durante logout y efectos condicionados por
  generación y revisión de transición;
- punto de no retorno y rechazo de cancelación tras invalidación local o fence
  Deluxe cerrado y verificado;
- coalescencia, reintento, cancelación e idempotencia de mutaciones;
- `Codable & Sendable`, compatibilidad y estados del snapshot Deluxe;
- `publicationGeneration`, `sessionGeneration`, revisión `UInt64` estrictamente monotónica y persistida sin wrap y rotación de epoch con fence cerrado;
- `SessionFence` versionado, `fenceRevision`, sesión opcional permitida y decisión del provider mediante doble lectura idéntica alrededor del envelope;
- selección de eventos, serialización del publicador, distinción entre contenido y sanitización y revalidación de la sesión esperada antes del reemplazo;
- diferencia entre fallo ordinario y cierre fail-closed, incluido el aborto de logout si no puede persistirse o verificarse el fence;
- orden write-before-reload, supresión de reload tras fallo inseguro y selección del `kind` de widget afectado;
- `StaticConfiguration`, `TimelineProvider`, timeline `.never`, proyección común y ausencia de configuración por App Intent;
- manifest, portada inmutable local o placeholder, retención y limpieza;
- estados y cancelación de modelos de feature `@Observable @MainActor` cuando sean propietarios reales de ese workflow.

### Integración

- CRUD SwiftData con un `ModelContainer` aislado y verificación desde otro contexto;
- migración mediante un store temporal en disco creado con el esquema anterior;
- requests y respuestas mediante un `URLProtocol` limitado a la `URLSession` de test, incluidos códigos y payloads inválidos;
- ciclo de access/refresh token con un almacén Keychain sustituible y sin credenciales reales;
- crash y recuperación del logout de A, bloqueo de una activación B concurrente y
  efectos tardíos de A convertidos en no-op después de activar B;
- cancelación antes de cada punto de no retorno y recuperación obligatoria cuando
  se solicita después;
- reinicio con outbox pendiente, pérdida de red, bloqueo de autenticación y rechazo permanente;
- escritura y lectura concurrentes del snapshot y portadas en App Group, fallo de disco, manifest anterior, retención y limpieza, en directorios temporales y después en sandbox o dispositivo autorizado;
- recuperación tras crash en la secuencia fence cerrado → invalidación/Keychain → envelope redactado → reload;
- doble lectura con sustitución concurrente del fence; sesión B cuyo envelope precede a la apertura; sanitización tardía de A convertida en no-op tras abrir B;
- bootstrap Deluxe cerrado ante una sesión Advanced activa, autorización explícita de su propietario y revalidación antes de abrir el fence;
- WatchConnectivity no alcanzable y reemplazo del contexto pendiente mediante `WCSession.updateApplicationContext(_:)`, incluidos epoch nuevo y entrega tardía de A sin bootstrap observado;
- composición del widget sin SwiftData, Keychain, red, polling, ActivityKit, WidgetKit push ni `BGTask`.

### Interfaz

XCUITest cubrirá como mínimo los flujos críticos que puedan automatizarse de forma determinista:

- catálogo a detalle y cambio entre lista y grid;
- edición de tomos, tomo de lectura y colección completa;
- alta, login, expiración recuperable y logout;
- restauración de estado local y representación de error;
- layout de iPhone en vertical e iPad en sus orientaciones admitidas;
- cambio entre Catálogo, Colección y Cuenta, conservando durante la misma escena la ruta local de cada tab mediante su propietario de ámbito feature;
- selección por `Manga.ID` desde catálogo y colección hacia el mismo detalle, sin transportar un modelo SwiftData vivo;
- navegación lineal de Cuenta y catálogo accesible sin sesión;
- invalidación de la selección de Colección al completar cambio de usuario, sin inventar todavía un flujo de colección anónima.

Los tests UI no incluirán secretos ni dependerán de datos personales o de producción.

## Determinismo

Reloj, UUID, red, aleatoriedad y almacenamiento se inyectarán cuando afecten al resultado. No se usarán sleeps como sincronización ni se serializará una suite para ocultar estado compartido. Los oráculos procederán de contratos, fixtures controlados o cálculos independientes.

Los tests de frescura de WidgetKit observarán los límites sustituibles de publicación, almacenamiento y recarga. Comprobarán que cada mutación, reconciliación, reversión, restauración, importación o redacción aplicable parte de un commit local completado o transición persistida y solicita una sola vez `reloadTimelines(ofKind:)` con el `kind` esperado únicamente después de dejar el bridge seguro.

En las suites Deluxe, un evento sin cambio visible no publicará ni solicitará reload. Un fallo ordinario conservará el manifest anterior de la misma sesión vigente. Un fallo al cerrar o verificar el `SessionFence` abortará logout y conservará sesión y Keychain; después de un fence seguro, un crash entre invalidación, limpieza de Keychain y envelope redactado se recuperará sin volver a autorizar A. Se probará también que el provider rechaza una lectura si los fences anterior y posterior difieren, que B no es visible antes de abrir su fence y que una sanitización tardía de A no altera B.

Se inyectarán pérdida o corrupción de contador, overflow, disco lleno y carreras A/B para verificar recuperación, rotación de epoch con fence nuevo cerrado y revalidación de sesión. Una revisión reservada que no llegó al envelope quedará consumida; un envelope ya publicado cuyo reload quedó pendiente provocará otra solicitud dirigida sin una publicación nueva. Para watchOS se verificará que una nueva llamada a `updateApplicationContext(_:)` sustituye el contexto pendiente, que un epoch nuevo reemplaza la cache compatible anterior y que un reloj no alcanzable no bloquea logout. Ningún test esperará una actualización real de WidgetKit o WatchConnectivity ni impondrá sleeps o deadlines.

## Previews deterministas

- Una preview estática puede construir directamente un estado representativo sin fingir una petición.
- Una preview interactiva de red usa `URLSessionConfiguration.ephemeral` y un `URLProtocol` local sin registro global ni handler mutable compartido.
- Los fixtures de transporte contienen bytes, cabeceras, status o errores; el decoder y los DTO son los de producción.
- Colección usa un `ModelContainer` en memoria con el esquema real; las interacciones posteriores recorren la capacidad de mutación de producción.
- Cada escenario significativo posee contexto aislado y no llama a API, Keychain ni almacenamiento live.
- Loading estable se modela como estado de presentación; no se simula con sleeps.
- Xcode MCP renderiza las variantes aprobadas como comprobación editorial; una preview no sustituye build, tests UI ni evidencia de accesibilidad.

## Warnings como errores

- Warnings de Swift y Clang bloquearán Debug y Release en todos los targets presentes y futuros.
- La concurrencia estricta no se silenciará con `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` u otros escapes no aprobados.
- DocC se validará con warnings como errores.
- Un warning de una dependencia o herramienta se atribuirá a su origen; no se presentará como un defecto corregido del código propio ni se suprimirá sin decisión explícita.

ADR 0011 acepta durante el bootstrap una única firma externa de
`appintentsmetadataprocessor` en Xcode build `27A5252f`. La excepción fija
productor, severidad, mensaje, cantidad y build; cualquier deriva falla. No
filtra la salida, no añade App Intents y no permite warnings de Swift, Clang o
DocC. Cero diagnósticos pasa sin excepción. Si el warning persiste al cambiar de
beta, RC o versión estable, el gate falla hasta una nueva decisión explícita.

La excepción permite integrar la configuración reproducible, pero no satisface
por sí sola el Advanced Release Gate: una candidata Advanced mantiene el
requisito de build limpio y cero warnings.

La política común se materializa en `Configuration/Shared.xcconfig`, conectada a Debug y Release a nivel de proyecto para que la hereden todos los targets actuales y futuros. `Scripts/validate-docc.sh` comprueba los valores efectivos de app, unit tests y UI tests en ambas configuraciones antes de construir documentación.

## Calidad de producto

- Todo texto visible residirá en String Catalog con español e inglés, incluso cuando una marca mantenga deliberadamente el mismo valor en ambos idiomas.
- `InfoPlist.xcstrings` explicita `Manga Library` como nombre visible invariable en inglés y español, y conserva también el nombre técnico de bundle en ambos locales.
- Las futuras descripciones de permisos se añadirán a `InfoPlist.xcstrings` en los dos idiomas junto a la capacidad real que las necesite. `Localizable.xcstrings` se creará con la primera interfaz de producto y sus textos reales; este gate no anticipa un catálogo vacío ni traducciones ficticias.
- Las vistas soportarán Dynamic Type sin truncar acciones o datos esenciales.
- VoiceOver comunicará nombre, valor, estado y acción sin depender de la portada.
- Se comprobarán contraste, orden de foco, áreas táctiles, estados vacío/carga/error y reducción de movimiento cuando corresponda.
- Las portadas tendrán placeholder estable y la interfaz conservará significado ante fallo de imagen.
- Previews deterministas cubrirán estados representativos, pero no contarán como evidencia de UI automation.

## Contrato cromático

Library Red es el contrato cromático aprobado para Manga Library. La [especificación humana](../design/brand-palette.md) define significado, política de uso, accesibilidad y límites; el [JSON canónico](../design/library-color-tokens.json) es la autoridad exacta de valores, roles, modos, umbrales y parejas autorizadas.

La incorporación documental no materializa colorsets ni acredita la interfaz. Una unidad posterior implementará Asset Catalog mediante RED/GREEN, comprobará las cuatro combinaciones Light/Dark y Standard/Increased Contrast contra el JSON y auditará los estados renderizados. Que una pareja opaca supere su ratio no demuestra por sí solo contraste tras materiales, transparencia, imágenes, estados nativos o composición dinámica, ni conformidad WCAG de la app o soporte de una etiqueta de accesibilidad de App Store.

## Gates

### Advanced Release Gate

- build limpio y cero warnings;
- `Fast`, `Integration` y flujos UI críticos aprobados;
- catálogo, colección local, autenticación y sincronización cumplen sus contratos Advanced; logout demuestra invalidación local durable, punto de no retorno, exclusión de otra activación y efectos tardíos condicionados sin depender de un bridge Deluxe;
- accesibilidad y adaptación verificadas en la matriz acordada;
- documentación y evidencia actualizadas.

### Deluxe Release Gate

- Advanced continúa en verde;
- widget y watchOS satisfacen la [SDD Deluxe](05-deluxe-watch-and-widget.md);
- el `SessionFence` se cierra después de persistir la transición y antes de invalidar la sesión o limpiar Keychain conforme a [ADR 0013](../adr/0013-advanced-logout-and-deluxe-bridge-boundary.md), sin reutilizar la ausencia previa del bridge como evidencia;
- un fence cerrado y verificado hace no cancelable la transición y obliga a completar el cierre local Advanced;
- la primera incorporación del bridge permanece cerrada hasta que el propietario de sesión autoriza y el publicador revalida una generación Advanced activa;
- snapshot, configuración estática, generaciones, `SessionFence`, redacción fail-closed, `updateApplicationContext(_:)`, portadas, `.never` y reload dirigido tienen evidencia proporcional;
- la evidencia valida causalidad y contenido sin sleeps ni afirmaciones de latencia en tiempo real;
- la integración autorizada prueba App Group, manifest/portadas, crash/reintento y cambio de sesión sin introducir red u otra autoridad en la extensión;
- el gate DocC produce el archive esperado sin warnings.

Un simulador no sustituye evidencia física cuando la capacidad dependa de hardware, llavero, App Group, WatchConnectivity o una tecnología de asistencia real.

## Fuera de alcance para 1.0

- objetivos porcentuales de cobertura;
- tests de rendimiento y presupuestos de Instruments;
- llamadas automatizadas al backend de producción;
- afirmar cobertura de accesibilidad solo por compilar, renderizar una preview o ejecutar un flujo diferente.

## Decisiones relacionadas

- [ADR 0001: toolchain, plataforma y warnings](../adr/0001-toolchain-platform-and-warning-policy.md)
- [ADR 0005: estrategia híbrida de testing](../adr/0005-hybrid-testing-strategy.md)
- [ADR 0010: frescura dirigida por eventos para WidgetKit](../adr/0010-widgetkit-event-driven-freshness.md)
- [ADR 0011: excepción acotada para el warning de App Intents](../adr/0011-bounded-xcode-app-intents-warning-exception.md)
- [Documentación y DocC](07-documentation-and-docc.md)
- [ADR 0009: flujos nativos por fuente y navegación local](../adr/0009-native-source-owned-features-and-local-navigation.md)
- [ADR 0013: frontera de logout Advanced y bridge Deluxe](../adr/0013-advanced-logout-and-deluxe-bridge-boundary.md)

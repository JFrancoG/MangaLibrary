# DX5 — validación del companion watchOS

**Última actualización:** 2026-09-10
**Estado:** DX5 implementada y validada localmente en el alcance registrado, con entrega autorizada y en preparación. Fast/Integration conservan 800 declaraciones / 1.149 invocaciones disjuntas aprobadas, con Fast repetido tras recuperar MCP. Builds finales Debug/Release y DocC limpios. UI/cache representativas y entrega nativa de vacío, contenido en nueva sesión y redacción por logout verificadas en Simulator; entorno restaurado. La ampliación combinatoria y física pertenece a DX6/DX7. Deluxe mantiene DX1–DX4 entregadas (4/7); el issue #86 sigue abierto hasta completar la entrega y no se avanza de subfase.
**Tracker:** [issue #86](https://github.com/JFrancoG/MangaLibrary/issues/86), hijo del [plan #77](https://github.com/JFrancoG/MangaLibrary/issues/77); rama `codex/86-dx5-watch-companion`.

El propietario autorizó abrir issue y rama e implementar DX5; posteriormente,
el 10 de septiembre, autoriza su entrega completa mediante commit, push, PR,
merge, cierre del issue y retirada de la rama. La entrega está en preparación,
con #86 todavía abierto y sin merge ni cierre acreditados. No se autoriza
avanzar a DX6/DX7. La autoridad
permanece en [SDD 05](specs/05-deluxe-watch-and-widget.md),
[SDD 09 v1.16](specs/09-deluxe-reading-contract.md),
[SDD 06 v1.37](specs/06-testing-quality-and-accessibility.md) y
[ADR 0007](adr/0007-watchos-widgetkit-and-data-bridges.md).

## Configuración y alcance

- Target `MangaLibraryWatch Watch App`, bundle
  `com.plusprojects.MangaLibrary.watchkitapp`, watchOS 27, creado mediante
  Xcode MCP como companion de `com.plusprojects.MangaLibrary`.
- Swift 6, concurrencia estricta y aislamiento predeterminado `nonisolated`.
  Xcode 27/Swift 6.4 del IDE conectado; las herramientas de validación deben
  confirmar ese Xcode y no usar el seleccionado globalmente por suposición.
- Lista SwiftUI de solo lectura, progreso, antigüedad informativa, restantes en
  iPhone y placeholder local. Sin autenticación, edición, red, SwiftData, App
  Group ni transferencia de JPEG en el reloj.
- Canal único `updateApplicationContext(["readingSnapshot": Data])`;
  presupuesto de 32.768 bytes del binary plist completo. Cache privada de
  65.536 bytes con snapshot y barreras de aceptación, sin TTL de autorización.
- No hay Apple Watch físico disponible. Las obligaciones físicas de DX6/DX7
  y el primer desbloqueo del iPhone limitado/no observable siguen pendientes
  para el Deluxe Release Gate.

## Evidencia inicial — 10 de septiembre

Xcode MCP ejecuta una selección focal en `MangaLibraryTests`, scheme
`MangaLibrary`, plan `ReleaseGate`, iPhone 17 Simulator/iOS 27. Resultado:
**29 invocaciones aprobadas**, receptor 17, almacenamiento 3, framing 5 y
reenvío canónico 4. Bundle:
`Test-MangaLibrary-2026.09.10_14-59-35-+0200.xcresult`.
La selección no equivale a ejecutar el plan ReleaseGate completo.

Las pruebas recorren compatibilidad y orden con fixtures sintéticas, cache
temporal aislada y fronteras controladas de transporte. El reenvío usa el
publicador real y su fence: no reserva otra revisión y puede entregar la
retirada pendiente de una sesión con fence cerrado. No prueban entrega de
WatchConnectivity, el modelo final ni una compilación completa del companion.

Durante esta ejecución inicial el target watchOS tenía exclusiones temporales
de fuentes compartidas y mantenía el entrypoint del template. El Mac bloqueado
impedía completar su pertenencia mediante Xcode UI. Ese build provisional no
acredita la feature watchOS; la integración posterior se registra abajo.

El gate estático `Scripts/validate-test-plans.sh` pasa con **28 suites Fast y
39 Integration** durante la implementación. Clasificar suites no acredita
su ejecución y estos conteos deben contrastarse con el diff final.

### Aislamiento del host y regresiones adicionales

Las cinco invocaciones focales de sesión y no-op pasan en
`Test-MangaLibrary-2026.09.10_15-12-15-+0200.xcresult`: expiración antes del
reenvío, bloqueo del reenvío antes de restaurar sesión, logout pese a fallo de
transporte y reenvío sin otra publicación/reload. Estas pruebas, y las 29
iniciales, inyectan sus dependencias, pero su host todavía arrancaba la
composición de producto: la consola registra `WCErrorCodeDeviceNotPaired`.
No se atribuye a esas ejecuciones ausencia de efectos del host ni recepción WC.

Se corrigen Fast/Integration/ReleaseGate para lanzar el host con `-ui-testing`,
reutilizando fixtures existentes y evitando la composición live. El gate estático
exige ese argumento. La ejecución focal de las dos regresiones de drenaje del
10 de septiembre a las 15:16:19 ya usa esos planes y no contiene logs WC del
host; sus fallos RED son los esperados. La regresión completa posterior acredita
el GREEN de esas fuentes.

### Regresión completa y revisión sobre las fuentes compartidas

Xcode MCP, scheme MangaLibrary, iPhone 17 Simulator/iOS 27.0 build `24A434`,
Xcode 27.0 `27A266a`, Swift 6.4 `swiftlang-6.4.0.34.1`:

| Plan | Declaraciones | Invocaciones | Bundle nativo |
| --- | --- | --- | --- |
| Fast | 353 | 539 | `Test-MangaLibrary-2026.09.10_15-28-10-+0200.xcresult` |
| Integration | 447 | 610 | `Test-MangaLibrary-2026.09.10_15-28-37-+0200.xcresult` |

Son **800 declaraciones / 1.149 invocaciones disjuntas**, con cero fallos,
skips, expected failures y runtime warnings. Los árboles nativos confirman
los dos argumentos del fallo de activación y las cinco invocaciones de la cola;
no se suman las selecciones focales anteriores. `xcresulttool get test-results`
contrasta resumen y árbol; el agregado MCP mezcla resultados fuera del plan.
Resúmenes y árboles se conservan fuera de Git como `dx5-fast-summary.json`,
`dx5-fast-tree.json`, `dx5-integration-summary.json` y `dx5-integration-tree.json`.
Las consolas de estas ejecuciones no muestran emisiones WC del host.

La revisión independiente cierra los defectos reproducidos: relectura adelantada
de otro epoch, terminal previo a su propia petición, contenido encolado mientras
el consumidor estaba suspendido y fallo de activación anterior a contenido nuevo.
La cola conserva el orden y el cierre finito comprueba atómicamente su versión
de entrega; las pruebas no usan sleeps ni transporte real como oráculo.

Revisión iOS de datos/concurrencia/configuración y Audit de 24 Swift sin hallazgos
pendientes. Revisión estática SwiftUI/accesibilidad de tres Views, fixtures y modelo
sin hallazgos; 13 textos propios ES/EN y contraste opaco mínimo de 7,32:1 para
texto secundario y 5,85:1 para marca sobre Surface. Esto no acredita renderizado,
interacción ni tecnologías de asistencia. El entrypoint completo quedó fuera
de aquella revisión inicial; su delta recibió después revisión independiente
iOS/SwiftUI y Audit sin hallazgos. El inventario pasó de 24 a 23 Swift al retirar
`ContentView` del template, antes de ampliar la fixture de caracterización.

### Intento de DocC sobre el target provisional

`MANGALIBRARY_DEVELOPER_DIR` selecciona explícitamente Xcode-RC 27.0 `27A266a`
para `Scripts/validate-docc.sh`; la selección global sigue siendo otro Xcode.
El primer intento comprobó los cinco targets con su SDK correspondiente, pero
`docbuild` falló en `CompileDocumentation` del watch provisional: «No valid
content was found in this file». El log local `dx5-docc.log` conserva ese fallo.
No demuestra por sí solo un grafo vacío; el diagnóstico y su resolución se
registran en el gate posterior.

### De la integración provisional al target completo

`Scripts/validate-advanced-build.sh`, con el mismo Xcode explícito, pasa Debug y
Release limpios: cero warnings, errores y tareas de metadata de App Intents.
Log local `dx5-clean-build.log`. Esa ejecución todavía compilaba el entrypoint
provisional con exclusiones watchOS; acredita app/widget y código compartido,
no el companion completo.

Después se conecta `MangaLibraryWatchApp` al propietario de presentación: tarea
continua, reconciliación separada al volver a activo y
`.backgroundTask(.watchConnectivity)`. Se elimina `ContentView` del template y
se retira `EXCLUDED_SOURCE_FILE_NAMES` mediante Xcode MCP. No quedan esas
exclusiones temporales en el estado actual.

El build MCP del target real a las **15:36:06 falló** porque faltaban los recursos
compartidos (`Color.surface` y `brandPrimaryInk`). Además, `GetFileCompilerFlags`
confirmó como miembros `ReadingSnapshot.swift` y `ReadingSnapshotCodec.swift`,
y confirmó que todavía faltaban `SessionFence.swift`, `WatchReadingConnectivity.swift`,
`WatchReadingModel.swift`, `WatchReadingSnapshotReceiver.swift` y
`WatchReadingSnapshotStorage.swift`. El bloqueo de macOS demoró ese ajuste;
no se atribuye a aquella ejecución compilación del companion completo.

Tras desbloquear el Mac, Xcode UI incorpora las cinco fuentes pendientes,
Assets y el icono compartido. `GetFileCompilerFlags` verifica la pertenencia;
no se añaden flags por archivo y `EXCLUDED_SOURCE_FILE_NAMES` permanece vacío.
Xcode MCP `BuildProject(buildForTesting: true)` a las **15:57:19** compila el
companion completo y el host de pruebas con cero warnings y errores.

El gate limpio final `Scripts/validate-advanced-build.sh` usa Xcode-RC explícito
y el target completo. Finaliza con salida 0: `dx5-final-clean-build.log` acredita
Debug y Release aprobados, cero warnings, errores y tareas de metadata de App
Intents. El destino es genérico iOS Simulator, scheme `MangaLibrary` y plan
`ReleaseGate`; el override de testabilidad se limita a la compilación local
Release. Este gate no ejecuta tests ni acredita hardware o integración live.
El scheme temporal de validación se retira y el scheme canónico `MangaLibrary`
conserva sus bytes. El scheme compartido nuevo del watch conserva el lanzamiento
con LLDB tras la caracterización sin debugger. El build limpio provisional
permanece como evidencia histórica.

El `Info.plist` del producto watch construido y del companion embebido confirma
`WKApplication = true`, el companion `com.plusprojects.MangaLibrary` y
`UIDeviceFamily = 4`, sin configuración de token embebida en el reloj. Esto
verifica la composición del producto; no identifica la causa de los errores
WatchConnectivity observados en Simulator.

### DocC aprobado con el target completo

`Scripts/validate-docc.sh` finaliza con cero warnings y errores en Xcode 27.0
`27A266a`, Swift 6.4 `swiftlang-6.4.0.34.1`, Release y destino genérico iOS.
`dx5-final-docc-naming.log` conserva el resultado y el archive local
`.build/docc/MangaLibrary.doccarchive`; no se publica.

El target watch define `DOCC_CATALOG_DISPLAY_NAME = $(PRODUCT_MODULE_NAME)`
en Debug y Release mediante Xcode UI, después de que MCP rechazara el setting
como desconocido. El nombre visible de la app permanece independiente.
La diferencia previa entre el módulo `MangaLibraryWatch_Watch_App` y el nombre
de presentación DocC coincide con la condición que sintetiza una landing sin
catálogo. El diagnóstico de extensión vacía y las implementaciones primarias
de [generación de la landing](https://github.com/swiftlang/swift-docc/blob/main/Sources/SwiftDocC/Infrastructure/Input%20Discovery/DocumentationInputsProvider.swift)
y [análisis semántico](https://github.com/swiftlang/swift-docc/blob/main/Sources/SwiftDocC/Semantics/SemanticAnalyzer.swift)
respaldan esa causa como inferencia; el gate aprobado verifica la corrección.
No se añade un catálogo artificial, no se retira ningún target y no se relajan
los warnings como errores.

### Arranque watchOS y caracterización nativa

Xcode MCP `RunProject` arranca el companion real en Apple Watch SE 3 de **40 mm**
a las **16:01:13**, PID `47368`, y en Ultra 4 de **49 mm** a las **16:06:39**,
PID `49729`. Se observa la pantalla inicial en español y no se observa crash
de esos procesos. Esto acredita arranque y presentación inicial; no contenido
recibido, relanzamiento con cache, scroll ni Digital Crown.

La preview 0 de Series 12 de **46 mm** falla a las **15:58:30** en `UIKitCore`.
Ese fallo pertenece a Preview y no se atribuye al arranque real del companion.
La preview 6, estado no disponible, también falla a las **16:09:19**, PID
`51801`, en `UIKitCore` dentro del pipeline de Preview. Ninguna de las dos
ejecuciones acredita renderizado correcto. Los controles de la ventana host
observados con CUA no acreditan accesibilidad o interacción watchOS.

La caracterización iPhone usa exclusivamente la fixture DEBUG de Simulator con
`-ui-testing -ui-testing-reading-widget -ui-testing-watch-connectivity`;
`-ui-testing-reading-empty` selecciona el caso vacío. Los cuatro planes carecen
de las flags de caracterización. La fixture usa SwiftData en memoria, cargas
sintéticas y una generación nueva de sesión por lanzamiento WC; conserva el
bridge canónico de esa instalación de prueba, sin Keychain ni HTTP.
Recupera y retira el bridge anterior, si corresponde, antes de sembrar datos y
activar el transporte. Reenvío y logout pasan por el publicador y sus capacidades.
La revisión independiente del seam y sus tareas estructuradas no encuentra
hallazgos funcionales. Su ampliación queda limitada al escenario manual DEBUG;
no cambia la lógica compartida cubierta por las suites anteriores. Los builds
limpios compilan ese delta; la repetición posterior de Fast se registra abajo.

| Intento nativo | Resultado observado | Alcance excluido |
| --- | --- | --- |
| iPhone 17, 16:05:45 | Activación y `WCErrorCodeDeviceNotPaired` | Sin envío aceptado, callback ni aplicación en el reloj. |
| Pareja Ultra 4 de 49 mm/iPhone 17; relanzamiento iPhone a las 16:07:09 | Activación y `WCErrorCodeWatchAppNotInstalled`, pese al companion lanzado | No se acredita disponibilidad del transporte entre los runtimes ni recepción de contenido. |

Estos intentos conservan su resultado histórico; no demuestran una imposibilidad
general de Simulator. La recepción nativa posterior se registra abajo y no
permite inferir retrospectivamente la causa de aquellos errores.

### Interrupción de Xcode MCP — incidencia histórica

El intento final de `RunAllTests` devuelve `BSServiceConnectionErrorDomain`,
código 3, durante la respuesta XPC. A continuación `XcodeListWindows` devuelve
`Transport closed`; Xcode GUI se reinicia con PID `52375`. No se obtiene un
nuevo resultado de tests ni se atribuye al intento un aprobado o un fallo de
producto.

Dos reconexiones directas con el mismo `mcpbridge` oficial de Xcode-RC completan
`initialize` con versión `25317`, pero `tools/list` vuelve a cerrar STDIO.
La repetición quedó entonces pendiente; no se sustituyó MCP por otra herramienta
de ejecución. Fast **353/539** e Integration **447/610** conservaron la evidencia
de las fuentes compartidas mientras se recuperaba la conexión.

La skill oficial Apple `DeviceInteraction`, cuya resolución estaba pendiente
durante los recorridos UI, queda exportada y disponible localmente. No se afirma
que faltara; la desconexión impidió continuar aquellos recorridos.

Antes del error, MCP había confirmado `MangaLibrary`, iPhone 17 y Fast. Tras el
reinicio, Xcode UI recuerda el scheme watch y Ultra 4 vía iPhone 17; el intento
de restaurarlo mediante el selector no confirmó cambio. La reanudación posterior
vuelve a ejecutar Fast desde MCP, sin alterar el scheme iOS versionado.

La revisión independiente final de configuración no encuentra nuevos hallazgos:
scheme watch, tres planes modificados, scripts y catálogo ES/EN válidos. El Audit
de las fuentes y sus deltas cubría entonces 24 Swift; el ajuste de
dos líneas largas de la fixture se limita a formato. `git diff --check` pasa y
no hay archivos staged ni acciones de entrega.

### Reanudación de la validación runtime

MCP recupera la conexión y ejecuta Fast a las **17:48:21**, con el mismo Xcode
27.0 `27A266a`, Swift 6.4 e iPhone 17 Simulator/iOS 27.0 `24A434`. El bundle
`Test-MangaLibrary-2026.09.10_17-48-21-+0200.xcresult` confirma **353 declaraciones /
539 invocaciones aprobadas**, cero fallos, skips y expected failures, y
`runtimeWarnings = []`. La interrupción anterior ya no bloquea este gate.
Esta repetición no se suma al total disjunto de Fast/Integration.

`WatchReadingRuntimeFixture` permite validar la UI y la cache del companion real
solo en **DEBUG y Simulator**. El argumento `-dx5-fixture` acepta `content`,
`longtitles`, `empty`, `redacted`, `unavailable` y `cache`. Opcionalmente,
`-dx5-locale es|en` fija el idioma y
`-dx5-dynamic-type large|xxxLarge|accessibility5` fija el tamaño del texto.
Usa `WatchReadingPreview`, el codec, el receptor, el modelo y el almacenamiento
reales; guarda únicamente en `Application Support/DX5Validation`, separado de la
cache de producto. Los escenarios distintos de `cache` descartan solo ese archivo
sintético una vez por lanzamiento. Para comprobar continuidad, se lanza un
escenario con snapshot, se termina y se relanza `cache` en la misma instalación:
este último no siembra ni recibe otro contexto. La rama no instancia WCSession y
no existe en Release; sus leases finitas no acreditan transporte ni background
nativos. Revisión independiente y Audit de ambos archivos sin hallazgos.

El scheme compartido watch incluye host iOS y watch. Usarlo para un destino watch
sin pareja produjo **dos warnings de `actool`** por assets iOS con dispositivo
`Watch7,13`; ese intento no supera el gate de diagnósticos. La validación UI usa
un scheme temporal que construye solo el target watch, sin modificar los targets
ni aceptar o suprimir warnings. Su build termina con **cero warnings y errores**;
log MCP `31610C2A-8BC7-4E8E-BDF2-ED52CF4FDC85`. Después,
`DeviceInteractionInstallAndRun` con el scheme host+watch y UUID de watch repite
dos avisos de assets iOS para `Watch8,1`, log `AA4F5622`; tampoco se aceptan ni
suprimen. El build posterior del scheme principal sobre iPhone termina limpio,
log `29AC91BB`. La UI con el scheme temporal watch y los gates canónicos
conservan sus resultados sin warnings.

Los scripts canónicos se repiten con Xcode-RC seleccionado explícitamente:
Xcode 27.0 `27A266a`, Swift 6.4 `swiftlang-6.4.0.34.1`. Ambos terminan con salida 0.
`dx5-runtime-final-build.log` acredita `build-for-testing` Debug y Release del
scheme `MangaLibrary`, plan `ReleaseGate`, destino genérico iOS Simulator, con
cero warnings, errores y tareas de metadata de App Intents. No ejecuta tests.
`dx5-runtime-final-docc.log` acredita el `docbuild` Release en destino genérico
iOS y el archive local `.build/docc/MangaLibrary.doccarchive`, también sin
warnings ni errores y sin publicación. El inventario Swift actual contiene
**25 archivos**; la fixture runtime y su delta del entrypoint están revisados.

La consulta de `device_set.plist` y `simctl list -j pairs` confirma la pareja
activa `9C93DF4A-E6E2-4067-BBE3-072C0528E224`: iPhone 17
`C0534329-7329-4763-A3E9-FD3F45F6E368` y Ultra 4 de 49 mm
`F876BD84-D3FD-4513-855B-39775CDC4415`. El reloj tiene un contenedor con identificador
`com.plusprojects.MangaLibrary.watchkitapp`, creado por `com.apple.installd`, y
metadata de bundle compatible. La consulta inicial se hizo con ambos apagados:
`(active, disconnected)` y `listapps` con `SimError 405: Shutdown`. Una vez
arrancados, la consulta confirma **ambos Booted**, pareja **active, connected** y
`listapps` con salida 0 y ambos bundles registrados como aplicaciones `User`.
`SIMULATOR_ROOT` de cada dispositivo y su `SystemVersion.plist` identifican
**iOS 27.0 `24A434` y watchOS 27.0 `24R362`**. Esta comprobación distingue el
runtime activo de los dos builds watchOS 27 instalados. La metadata no explica
el anterior `WatchAppNotInstalled`; la evidencia de entrega es la siguiente.

### WatchConnectivity nativo en Simulator

El companion real arranca **sin flags de fixture watch** a las 18:07, PID
`71313`, y reconcilia un contexto previo de **1.238 bytes de Data** con contenido
sintético del iPhone. Conserva ese proceso durante el recorrido completo.
Los iPhone usan la fixture sintética y el publicador canónico descritos arriba;
las ocho lecturas elegibles proceden de esa fixture, no de las tres filas de
`WatchReadingPreview`.

| Transición | Publicación iPhone | Recepción y presentación watch |
| --- | --- | --- |
| Vacío | PID `71730`; activación 18:08:34.157 y envío aceptado de 372 bytes a las 18:08:34.172. | Callback 18:08:35.533 y contexto de 372 bytes reconciliado; UI vacía capturada a las 18:08:58.689. |
| Contenido en nueva sesión | PID `72025`; nueva sesión sintética, activación 18:09:26.696 y envío aceptado de 1.238 bytes a las 18:09:26.708. | Callback 18:09:27.005 y contenido restaurado. Se recorren las ocho lecturas, incluidas Diario 1/5 y Jardín 5/9 en la captura 18:10:58.166. |
| Logout y redacción | En el mismo PID `72025`, Cuenta → Cerrar sesión → confirmación de descartar solo cambios sintéticos; redacción aceptada de 252 bytes a las 18:11:44.750530. | Mismo PID `71313`: callback 18:11:45.041331 y contexto de 252 bytes a las 18:11:45.041796. Captura 18:11:59.275: «Tus mangas, aquí / Inicia sesión…», sin lecturas, fecha ni contador. |

La captura final del iPhone a las 18:11:59.015 confirma sesión cerrada. Las
capturas transitorias de las 18:11:44 no se usan como resultado. Los artefactos
de `DeviceInteraction` tienen prefijos `DX5 Native iPhone` y `DX5 Native Watch`.
Quedan observados envío aceptado, callback y aplicación en el mismo proceso
watch para vacío → contenido de una nueva sesión → logout/redacción. Las horas
son evidencia del recorrido, no un plazo garantizado. No demuestra coalescencia
de contextos pendientes, suspensión, background ni comportamiento físico.

### Restauración del entorno

Las sesiones oficiales de 40, 46 y 49 mm y las dos sesiones nativas se cierran;
estas últimas devuelven `Session stopped`. Se elimina el scheme temporal
`MangaLibraryDX5Validation` y `XcodeListSchemes` conserva solo los tres finales.
El scheme watch recupera LLDB después de que `DeviceInteraction` lo dejase en
`PosixSpawn`. El scheme canónico `MangaLibrary` permanece byte a byte idéntico,
SHA-256 `2eb06cb4b56e8ac78031322e74e497eec375e4d683c9b9fc09cef4e20adc7907`.
MCP queda en `MangaLibrary` / `Fast` / iPhone 17 y el navegador de diagnósticos
registra cero warnings. No se repiten builds por restaurar esos atributos a su
valor original. No hay staging, commit ni acciones de entrega.

### Checkpoint previo al commit

El Audit final queda cerrado sobre 25 Swift. Tres ajustes de espacios y
disposición en `UITestingReadingWidget.swift` no cambian comportamiento; los
otros 24 archivos conservan sus hashes. Se reutilizan Fast 353/539, Integration
447/610 y los gates canónicos Debug/Release y DocC aprobados. El build incremental
MCP posterior al Audit aprueba a las **18:44:27**: `buildForTesting: true`, Fast,
iPhone 17, 12,45 s y cero warnings/errores en el log completo
`BuildProject-Log-20260910-184427.txt`.

Tras reaparecer por un guardado del IDE, el scheme temporal se retira mediante
Manage Schemes. El intento de las 18:42 conserva un destino watch obsoleto y
emite dos warnings de actool para Watch8,1; queda excluido del gate. Se cierra
únicamente el proyecto MangaLibrary, se retira el residuo y se restaura LLDB
en el scheme compartido watch. Al reabrir, MCP y Xcode UI confirman
`MangaLibrary` / `Fast` / iPhone 17. Después del build limpio se verifican
ausencia del scheme temporal, LLDB y hash intacto del scheme canónico. La entrega
está autorizada y en preparación; este checkpoint no acredita merge ni cierre
del issue o la rama.

## Gates técnicos de DX5

| Gate | Estado actual | Evidencia necesaria para cerrarlo |
| --- | --- | --- |
| Receptor, cache, framing y reenvío canónico | Aprobados en lógica compartida | Focal inicial y Fast/Integration completos; no acreditan transporte real. |
| Modelo, activación/reactivación y background controlado | Aprobado en lógica compartida | Fast completo; no acredita ejecución background de watchOS. |
| Sesión y restauración sin cambios | Aprobado | Integration completo con ambos argumentos de expiración y composición determinista. |
| Integración del target completo | Aprobada | Fuentes/assets/icono y flags verificados; build MCP 15:57:19 sin warnings ni errores, sin exclusiones temporales. |
| Fast e Integration completos | 800 declaraciones / 1.149 invocaciones aprobadas para lógica compartida | Fast repetido y aprobado a las 17:48:21; Integration completo de las 15:28:37. No se suman repeticiones. |
| Builds Debug/Release y diagnósticos | Aprobados sobre el corte runtime final | `dx5-runtime-final-build.log`, salida 0 y cero warnings/errores. Los intentos host+watch con warnings quedan excluidos del gate aprobado. |
| DocC | Aprobado sobre el corte runtime final | `dx5-runtime-final-docc.log`, archive local y cero warnings/errores; sin publicación. |
| Revisión independiente iOS y SwiftUI/accesibilidad | Código compartido, entrypoint, UI estática, fixture y configuración aprobados | Sin hallazgos funcionales pendientes; UI ejecutada con los límites de la matriz. |
| Swift Source Style, modo Audit | Aprobado sobre fuentes y deltas revisados | Inventario actual de 25 Swift, con delta de fixture/entrypoint revisado y sin hallazgos pendientes de estilo. |
| Documentación, catálogos y Git | Evidencia actualizada; entrega autorizada y en preparación | 13 claves ES/EN; sesiones cerradas y scheme canónico intacto. El checkpoint previo al commit revalida el entorno; merge y cierre pendientes. |

## Matriz de Simulator y transporte

`DeviceInteraction` oficial ejecuta esta matriz representativa el 10 de septiembre,
entre **17:56 y 18:06**. Capturas y jerarquías se conservan fuera de Git en
`ActionArtifacts/default/DeviceInteractionSynthesize`, con prefijos
`DX5 Watch 40 Fixtures`, `DX5 Watch 46 Fixtures` y `DX5 Watch 49 Fixtures`.

| Watch / PID | Escenario, idioma y Dynamic Type | Resultado observado |
| --- | --- | --- |
| SE 3, 40 mm / `64246` | `content`, ES, Large | Contenido y progreso presentados. |
| SE 3, 40 mm / `66411` | `cache`, ES | Nuevo proceso restaura el contenido persistido sin sembrar ni recibir contextos. |
| SE 3, 40 mm / `66743` | `longtitles`, EN, AX5 | Digital Crown permite recorrer títulos, progreso y footer completos. |
| Series 12, 46 mm / `68337` | `empty`, ES, Large | Solo mensaje y fecha, sin filas de lectura. |
| Series 12, 46 mm / `69167` | `redacted`, EN, Large | Sin contenido ni fecha. |
| Series 12, 46 mm / `69812` | `unavailable`, EN, XXX Large | Sin contenido ni fecha. |
| Ultra 4, 49 mm / `70555` | `content`, EN, XXX Large | Contenido y recorrido con Digital Crown correctos. |
| Ultra 4, 49 mm / `71010` | `redacted`, ES, AX5 | Estado de redacción presentado. |

No se observa crash ni truncado permanente en estos recorridos. Las jerarquías
aportan evidencia de semántica accesible; no equivalen a VoiceOver físico. La
cache usa receptor y almacenamiento reales en el directorio aislado, sin WC.
Los fallos anteriores de Preview en `UIKitCore` se conservan como tales y no
invalidan estos recorridos de la app ejecutada. No se ha realizado el producto
cartesiano de tamaños, idiomas y estados; su ampliación queda en DX6.

| Alcance | Estado y límite |
| --- | --- |
| UI, Dynamic Type y Digital Crown | Matriz representativa aprobada; no acredita ergonomía física ni todas las combinaciones. |
| Cache tras relanzar | Aprobada en 40 mm con proceso nuevo y sin nuevos contextos; no demuestra desconexión física. |
| Activación y entrega nativa | iPhone 17 / Ultra 4 conectados; envío, callback y aplicación observados para vacío y contenido de nueva sesión. |
| Logout/redacción nativa | Aprobado sin reiniciar watch: desaparecen lecturas, fecha y contador. |
| Contextos tardíos, coalescencia y pending | Orden y barreras aprobados con pruebas controladas; no caracterizados como recorrido nativo. |
| Pairing, reconexión, suspensión, background y VoiceOver físicos | Pendientes para DX6/DX7 por falta de Apple Watch. No los satisfacen tests ni Simulator. |

La entrega nativa se acredita con callback y contenido aplicado, no solo con la
aceptación del envío. No se promete latencia ni se extrapola a hardware o
background. Esta checklist no da por superado el Deluxe Release Gate.

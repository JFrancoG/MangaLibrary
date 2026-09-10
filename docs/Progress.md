# Progreso y evidencia

**Última actualización:** 2026-09-10
**Estado general:** Advanced entregado; Deluxe aprobado y DX1–DX4 entregadas mediante PR #80, #81, #83 y #85 (4/7). DX5 está implementada y validada localmente en el alcance registrado, con issue #86 abierto y rama `codex/86-dx5-watch-companion`, con entrega autorizada y en preparación. Fast/Integration conservan 800 declaraciones / 1.149 invocaciones disjuntas aprobadas, builds finales Debug/Release y DocC limpios. UI/cache representativas y entrega WatchConnectivity de vacío, contenido en nueva sesión y logout/redacción verificadas en Simulator; entorno restaurado. La ampliación combinatoria y física de Apple Watch queda en DX6/DX7, junto a la evidencia física anterior al primer desbloqueo del iPhone, limitada/no observable. No se han iniciado esas subfases ni se declara entregada DX5.

## DX5 — companion watchOS — issue #86 (entrega autorizada, en preparación)

### Checkpoint previo al commit — 10 de septiembre

El propietario autoriza la entrega completa de DX5: commit, push, PR, merge,
cierre del issue y retirada de la rama. La entrega está en preparación; #86
sigue abierto y no se acredita todavía merge ni cierre. DX6/DX7 no se inician.

El Audit final queda cerrado sobre 25 Swift. Los tres ajustes de
`UITestingReadingWidget.swift` afectan solo a espacios y disposición; los hashes
de los otros 24 archivos permanecen idénticos. Se reutilizan Fast 353/539,
Integration 447/610 y los gates canónicos Debug/Release y DocC ya aprobados.
El build incremental MCP posterior al Audit aprueba a las **18:44:27** con
`buildForTesting: true`, plan Fast e iPhone 17: 12,45 s, cero warnings y errores
en el log completo `BuildProject-Log-20260910-184427.txt`.

El IDE volvió a guardar el scheme temporal de validación y conservar un destino
watch obsoleto. El intento de las 18:42 queda excluido: emitió dos warnings de
actool para Watch8,1. Tras retirarlo en Manage Schemes, cerrar únicamente el
proyecto MangaLibrary y restaurar su scheme compartido, se reabre el proyecto.
MCP y Xcode UI confirman `MangaLibrary` / `Fast` / iPhone 17. Después del build
limpio se comprueban la ausencia del scheme temporal, la depuración LLDB del
ejecutable watch y el hash intacto del scheme canónico. Este checkpoint no
anticipa la entrega.

### Validación runtime y restauración del entorno — 10 de septiembre

MCP vuelve a ejecutar Fast a las **17:48:21** en el mismo iPhone 17 Simulator y
toolchain registrado: **353 declaraciones / 539 invocaciones aprobadas**, cero
fallos, skips y expected failures, y `runtimeWarnings = []`. Lo confirma
`Test-MangaLibrary-2026.09.10_17-48-21-+0200.xcresult`. La interrupción anterior
queda como incidencia histórica; no hay un gate Fast pendiente por desconexión
ni se suma la repetición a las **800/1.149** disjuntas de Fast/Integration.

La nueva `WatchReadingRuntimeFixture`, exclusiva de DEBUG/Simulator, valida
contenido, títulos largos, vacío, redacción, no disponible y cache
con los propietarios y almacenamiento reales en `DX5Validation`. Sus flags
explícitas fijan escenario, ES/EN y Dynamic Type; el modo `cache` conserva y
restaura el archivo sintético tras relanzar. No instancia WC ni existe en Release.
Su revisión independiente y Audit no encuentran hallazgos; el inventario Swift
actual contiene 25 archivos. La
[checklist DX5](dx5-watch-validation.md#reanudación-de-la-validación-runtime)
recoge argumentos, secuencia y límites.

Para destinos watch sin pareja se usa un scheme temporal que construye solo
watch. El scheme compartido host+watch había provocado dos warnings `actool`
de assets iOS para `Watch7,13`; no se aceptan ni suprimen. El build UI aislado
pasa con cero warnings y errores, log MCP
`31610C2A-8BC7-4E8E-BDF2-ED52CF4FDC85`. `DeviceInteractionInstallAndRun` repite
dos avisos de assets iOS para `Watch8,1` al usar host+watch con UUID watch,
log `AA4F5622`; también quedan fuera del gate aprobado. El build principal sobre
iPhone posterior, log `29AC91BB`, pasa limpio. No se aceptan ni suprimen avisos.

Los scripts canónicos se repiten tras la fixture con Xcode-RC 27.0 `27A266a`
seleccionado explícitamente y Swift 6.4. Ambos terminan con salida 0:
`dx5-runtime-final-build.log` acredita Debug/Release sin warnings, errores ni
metadata de App Intents, y `dx5-runtime-final-docc.log` acredita archive DocC
limpio. El primero compila para tests pero no los ejecuta; el archive permanece
local y no se publica.

La matriz oficial `DeviceInteraction` de 17:56–18:06 recorre en **40 mm**
contenido ES Large, cache en proceso nuevo y títulos largos EN AX5; en **46 mm**,
vacío ES Large, redacción EN Large y no disponible EN XXX Large; en **49 mm**,
contenido EN XXX Large y redacción ES AX5. Digital Crown permite completar los
recorridos de contenido y títulos largos, sin crash ni truncado permanente
observado. Las jerarquías aportan semántica accesible, no VoiceOver físico.
Cache se restaura con receptor y almacenamiento reales sin nuevos contextos WC.
Es una matriz representativa, no todas las combinaciones; la ampliación queda
en DX6. La checklist conserva los PID, artefactos y límites de cada recorrido.

La pareja iPhone 17/Ultra 4 de 49 mm está **active, connected**, ambos Booted y
ambas apps registradas por `listapps`. Sus runtimes efectivos son iOS 27.0
`24A434` y watchOS 27.0 `24R362`, contrastados con `SIMULATOR_ROOT`. La evidencia
posterior no identifica la causa de los errores WC históricos.

El watch real, sin flags de fixture, mantiene el PID `71313` durante vacío →
contenido en nueva sesión → logout/redacción. El iPhone `71730` envía 372 bytes
a las 18:08:34.172; callback watch 18:08:35.533 y UI vacía confirmada. El iPhone
`72025` publica 1.238 bytes de una nueva sesión a las 18:09:26.708; callback
18:09:27.005 y ocho lecturas recorridas. Tras cerrar sesión y descartar solo los
cambios sintéticos, la redacción de 252 bytes se acepta a las 18:11:44.750530;
el watch recibe callback a las 18:11:45.041331. Las capturas finales de las
18:11:59 confirman iPhone sin sesión y watch sin lecturas, fecha ni contador.
Hay envío, callback y aplicación observados; no se atribuye a este recorrido
coalescencia de pendientes, background, garantías de latencia ni hardware.

Todas las sesiones oficiales se cierran, incluidas las dos nativas con
`Session stopped`. Se retira `MangaLibraryDX5Validation`; quedan tres schemes,
watch recupera LLDB y `MangaLibrary` conserva sus bytes. MCP queda en
`MangaLibrary` / `Fast` / iPhone 17, con cero warnings en el navegador.
No hay staging, commit ni acciones de entrega; no se avanza a DX6/DX7.

### Companion completo y caracterización parcial — 10 de septiembre

Tras desbloquear el Mac, Xcode UI incorpora las cinco fuentes compartidas
pendientes, Assets y el icono al target watchOS. MCP verifica la pertenencia
con `GetFileCompilerFlags`; `EXCLUDED_SOURCE_FILE_NAMES` permanece vacío y no
se añaden flags por archivo. El entrypoint real conserva recepción continua,
reconciliación al volver a activo y trabajo `.backgroundTask(.watchConnectivity)`.
`BuildProject(buildForTesting: true)` de las **15:57:19** compila el companion
completo y el host de pruebas con cero warnings y errores.

`Scripts/validate-docc.sh` finaliza aprobado en Xcode 27.0 `27A266a`, Swift 6.4
`swiftlang-6.4.0.34.1`, Release y destino genérico iOS, con cero warnings y errores.
El target watch define `DOCC_CATALOG_DISPLAY_NAME = $(PRODUCT_MODULE_NAME)`
en Debug/Release mediante Xcode UI después del rechazo del setting por MCP.
El error anterior de extensión vacía encajaba con la landing sintetizada por
DocC al diferir módulo y display name; se conserva como inferencia respaldada
por el diagnóstico y la fuente primaria. No se añade un catálogo artificial ni
se relaja el gate. Log `dx5-final-docc-naming.log` y archive local
`.build/docc/MangaLibrary.doccarchive`, sin publicación.

El script limpio final sobre el target completo finaliza con salida 0 y acredita
Debug y Release sin warnings, errores ni tareas de metadata de App Intents en
`dx5-final-clean-build.log`. Usa el destino genérico iOS Simulator, el scheme
`MangaLibrary` y el plan `ReleaseGate`; no ejecuta tests. El scheme temporal de
validación se retira y el scheme canónico `MangaLibrary` conserva sus bytes.
El nuevo scheme compartido watch conserva su configuración de lanzamiento LLDB.
Los `Info.plist` del
watch construido y embebido confirman `WKApplication`, companion correcto y
familia watch `4`, sin configuración de token embebida en el reloj; esa evidencia
no identifica la causa de los errores WC del runtime.

`RunProject` arranca el companion en SE 3 de **40 mm** a las **16:01:13**, PID
`47368`, y Ultra 4 de **49 mm** a las **16:06:39**, PID `49729`. Se observa su
pantalla inicial en español, sin crash de esos procesos observado. La preview 0
de Series 12 de **46 mm** falla a las **15:58:30** en `UIKitCore`; la preview 6
del estado no disponible también falla a las **16:09:19**, PID `51801`, en el
pipeline de Preview de `UIKitCore`. Esto no acredita scroll, Digital Crown,
Dynamic Type ejecutado, accesibilidad watchOS, otros estados ni continuidad
de cache tras relanzar; los arranques reales se mantienen como evidencia separada.

La fixture nativa requiere DEBUG, Simulator y las flags explícitas
`-ui-testing -ui-testing-reading-widget -ui-testing-watch-connectivity`; el caso
vacío añade `-ui-testing-reading-empty`. Ningún plan suministra estas flags de
caracterización. Usa datos en memoria y una generación nueva de sesión; recupera
y retira el bridge de la instalación de prueba antes de sembrar y activar WC,
sin Keychain ni HTTP. La revisión independiente del seam no encuentra hallazgos
funcionales de aislamiento, orden, sesión o tareas estructuradas. El delta sólo
amplía la fixture manual DEBUG y no cambia la lógica compartida de las suites;
queda compilado en el build final aprobado.

En iPhone 17, el intento de las **16:05:45** activa WCSession y obtiene
`WCErrorCodeDeviceNotPaired`. Tras lanzar el companion en la pareja Ultra 4 de
49 mm/iPhone 17, el relanzamiento del iPhone de las **16:07:09** vuelve a activar
y obtiene `WCErrorCodeWatchAppNotInstalled`. En esos intentos no se acreditan
envío aceptado, callback ni contenido recibido. Es una limitación del entorno observado, no una
afirmación general sobre Simulator. La [checklist DX5](dx5-watch-validation.md)
separa arranque, UI, cache/receptor controlados y transporte entonces pendiente,
caracterizado después en la reanudación registrada arriba.

El intento final de `RunAllTests` no produce resultado: devuelve
`BSServiceConnectionErrorDomain`, código 3, durante la respuesta XPC, y después
`XcodeListWindows` devuelve `Transport closed`. Xcode GUI se reinicia con PID
`52375`. Dos reconexiones con el mismo `mcpbridge` oficial de Xcode-RC completan
`initialize` con versión `25317`, pero `tools/list` cierra STDIO. La repetición
de Fast quedó entonces pendiente; ese error de herramienta no se presentó como
un fallo de tests. La recuperación y el aprobado posterior constan en la
reanudación registrada arriba. La skill oficial Apple `DeviceInteraction` ya
estaba exportada y disponible localmente.

La revisión independiente final de configuración y los deltas de estilo quedan
sin hallazgos pendientes; el inventario de aquel corte contiene 24 Swift. El catálogo
watch tiene 13 claves ES/EN completas y `git diff --check` pasa. Tras el reinicio,
Xcode recuerda el scheme watch/Ultra 4 vía iPhone 17 y no confirma su restauración
por UI; la ejecución Fast posterior confirma la reanudación mediante MCP,
sin cambios al scheme iOS.
En aquel corte DX5 continuaba en curso; la validación posterior se registra arriba.

### Gates de lógica compartida — 10 de septiembre

Xcode MCP ejecuta Fast **353 declaraciones / 539 invocaciones** a las 15:28:10 e
Integration **447/610** a las 15:28:37 en iPhone 17 Simulator, iOS 27.0 `24A434`,
Xcode 27.0 `27A266a` y Swift 6.4. Son **800/1.149 disjuntas**, cero fallos, skips,
expected failures y runtime warnings, confirmados mediante los resúmenes y árboles
nativos de `xcresulttool`. Las consolas no muestran emisiones WC del host aislado.

La revisión independiente cierra los defectos de orden entre epochs y drenaje
prematuro, incluidos contenido posterior durante una suspensión y reactivación
posterior a un fallo. Las regresiones tienen RED/GREEN observado. Revisión iOS,
Audit de 24 Swift y revisión estática de UI/accesibilidad sin hallazgos pendientes.
La [checklist DX5](dx5-watch-validation.md) conserva bundles, alcance y limitaciones.

El primer intento DocC verificó los settings de cinco targets, pero falló en la
compilación documental del watch provisional con «No valid content was found».
El log local `dx5-docc.log` conserva ese resultado; su resolución posterior
figura en el registro actual.

El script de builds limpios pasa Debug/Release sin warnings ni errores en el alcance
app/widget/código compartido, todavía con watch provisional. Después se conecta el
entrypoint real y se retiran las exclusiones temporales mediante MCP. El build de
las 15:36:06 falló por colores compartidos ausentes; MCP confirmó cinco fuentes
compartidas aún sin pertenencia watchOS. El Mac bloqueado demoró aquel ajuste.
Esta evidencia es provisional y no acredita el companion completo; la integración
posterior se recoge arriba. El delta del entrypoint recibe revisión iOS/SwiftUI
y Audit sin hallazgos, con inventario de 23 Swift tras retirar el template y antes
de ampliar la fixture de caracterización.

### Inicio e implementación parcial — 10 de septiembre

El propietario autoriza abrir issue y rama e implementar DX5. Preflight desde
`main` limpio e idéntico a `origin/main@3fa4514`; se crea el
[issue #86](https://github.com/JFrancoG/MangaLibrary/issues/86), hijo real del
[plan #77](https://github.com/JFrancoG/MangaLibrary/issues/77), y la rama
`codex/86-dx5-watch-companion`. No se autoriza commit, push, PR, merge, cierre
ni avance a otra subfase.

Xcode MCP crea `MangaLibraryWatch Watch App` como companion watchOS 27 de la
app iOS existente, bundle `com.plusprojects.MangaLibrary.watchkitapp`.
El diff incorpora recepción ordenada, cache privada acotada y reenvío del
contexto canónico tras activación o restauración sin cambios. La UI prevista
es una lista de lectura con progreso, fecha, estados ES/EN y placeholder local.
La integración final del target y del ciclo de vida estaba entonces en curso.
SDD 09 materializa este alcance; su versión actual es v1.16 y SDD 06 v1.37 delimita los gates.

- MCP, iPhone 17 Simulator/iOS 27, scheme MangaLibrary y selección focal bajo
  ReleaseGate: **29 invocaciones aprobadas**, receptor 17, almacenamiento 3,
  framing 5 y reenvío canónico 4. Bundle
  `Test-MangaLibrary-2026.09.10_14-59-35-+0200.xcresult`.
  No es una ejecución completa de ReleaseGate ni evidencia de entrega WCSession.
- El gate estático de planes pasa con 28 suites Fast y 39 Integration durante
  la implementación; no acredita ejecución de los planes completos.
- Cinco invocaciones adicionales de sesión/no-op pasan a las 15:12:15. Se detecta
  que el host de las selecciones iniciales arrancaba la composición live y emitía
  `WCErrorCodeDeviceNotPaired`; no se afirma aislamiento de ese host retrospectivamente.
  Fast/Integration/ReleaseGate pasan ahora `-ui-testing`, exigido por el gate estático,
  y reutilizan la composición DEBUG de fixtures. La siguiente ejecución RED ya no
  muestra intentos WC del host; la regresión completa posterior acredita el GREEN.
- El Mac bloqueado dejó pendiente la pertenencia de fuentes mediante Xcode UI.
  Las pruebas iniciales usaron exclusiones temporales y el entrypoint del template;
  no se atribuye a esas ejecuciones la integración posterior del companion.
- Modelo, suites completas, builds, DocC y revisiones estaban pendientes en este
  corte inicial. La [checklist DX5](dx5-watch-validation.md) conserva su evolución
  y separa lógica controlada, UI simulada y transporte observado.

La cache no acredita una sesión vigente y una llamada de envío aceptada no
acredita recepción en el reloj. No hay evidencia de Apple Watch físico ni se
rebaja su matriz de DX6/DX7. Deluxe conserva **4/7 entregadas**; DX5 no se
declara completa con estos resultados iniciales. Los relatos siguientes
mantienen el estado y la evidencia de sus fechas.

## DX4 — widgets de iPhone/iPad — issue #84 (entregado mediante PR #85)

### Entrega completada — 8 de septiembre

La [PR #85](https://github.com/JFrancoG/MangaLibrary/pull/85) integra DX4 en `main` mediante
el merge [`1868244`](https://github.com/JFrancoG/MangaLibrary/commit/18682445a6b1de36fffeaf26775880fdc629ce66),
con los commits de implementación `cebf2cf` y corrección final `dd7e1f6`.
El issue #84 está cerrado. Se comprueba la incorporación completa del head y la
ausencia de commits exclusivos antes de retirar la rama
`codex/84-dx4-reading-widget`, local y remota.

La revisión independiente del head publicado confirma los 79 archivos del diff
y los 57 Swift idénticos a las fuentes validadas, sin hallazgos pendientes.
GitHub informó `CLEAN`/`MERGEABLE` y no ofreció checks de CI; la validación descrita
abajo procede de las herramientas y revisiones registradas.

El plan #77 queda abierto con **DX1–DX4 entregadas (4/7)**. El siguiente corte es
DX5, companion watchOS, todavía sin iniciar. La prueba física anterior al primer
desbloqueo sigue **limitada/no observable y pendiente en DX6** para el Deluxe
Release Gate. La entrega no cambia ese límite ni acredita hardware Apple Watch.
Los registros siguientes conservan el estado y la evidencia de cada momento.

### Gate de entrega — 8 de septiembre

Entrega completa autorizada por el propietario: commit/push, PR, revisión,
merge y cierre del issue/rama. La publicación permanece pendiente en este registro.

- Revisión independiente de datos/concurrencia/configuración y SwiftUI/accesibilidad
  cerrada sin hallazgos pendientes. Audit de los 57 Swift contra `fa60f15`, cinco
  candidatos justificados y cero infracciones; delta final del test revisado aparte.
  El cambio protegido de proyecto es intencionado: +218/0, sin deriva posterior.
- Se corrigen dos inspecciones de `generatedAt` en pruebas mediante un Decodable
  privado, conservando los diez argumentos y valores esperados. No cambia producción.
  `RunSomeTests` bajo Fast rechaza la selección por la limitación de tags del bridge;
  bajo ReleaseGate solo ejecuta dos argumentos. No se acredita con ese intento la
  matriz completa ni el Release Gate de producto.
- Se repite **Fast 327 declaraciones / 506 invocaciones**, iPhone 17 Simulator/iOS27,
  02:33:31, sin fallos, skips, expected failures ni runtime warnings. El árbol nativo
  confirma los seis y cuatro argumentos de fechas aprobados. Bundle
  `Test-MangaLibrary-2026.09.08_02-33-31-+0200.xcresult`; resumen y árbol locales
  `dx4-delivery-fast-summary.json` y `dx4-delivery-fast-tree.json`.
  El agregado MCP mezcla resultados ajenos y no es autoridad de conteo.
- Integration 436/598 y DocC se reutilizan con sus fechas del 7 de septiembre;
  fuentes de datos y documentación compilada sin cambios asociados. Total combinado
  disjunto **763 declaraciones / 1.104 invocaciones**, sin sumar las repeticiones.
- Build MCP 02:27:58 correcto, más build-for-testing limpio Debug/Release repetido
  después de la revisión del test con el script aprobado: salida0, cero warnings,
  errores o tareas de metadata de App Intents; log `dx4-delivery-reviewed-build.log`.
  Xcode27 `27A5252f`, Swift6.4, ReleaseGate, destino genérico iOS Simulator.
- Gate estático: 24 suites Fast/37 Integration, planes válidos. Catálogos/JSON,
  enlaces y diff comprobados. MangaLibrary/Fast/iPhone11 restaurado, sin argumentos
  de fixture ni sonda temporal; no se reinstala ni altera la prueba física aceptada.

Se conserva el traslado aprobado del primer desbloqueo a DX6, limitado/no
observable y pendiente para Deluxe. Los relatos anteriores mantienen sus cortes
históricos; no se presenta esta entrega como inicio de DX5 ni gate Deluxe superado.

### Ajuste de cierre aprobado — 8 de septiembre

El propietario aprueba trasladar a DX6 la comprobación física de protección
anterior al primer desbloqueo. SDD 09 v1.14, SDD 06 v1.36 y ADR 0022 conservan
el resultado **limitado/no observable** y la obligación pendiente para el Deluxe
Release Gate; no se declara superada ni se relaja la protección del bridge.
La recuperación posterior y el estado inyectado no acreditan I/O protegido.

Con los casos físicos de DX4 confirmados en el alcance de esta checklist y esa
transferencia expresa, no quedan pruebas físicas pendientes que bloqueen DX4.
La implementación y su evidencia están preparadas para la entrega autorizada;
#84 y su rama siguen abiertos, sin PR/merge/cierre ni nuevos commit/push. Deluxe
continúa en 3/7 subfases entregadas; DX5 y DX6 no se inician con este ajuste.

Revisión independiente de los tres diffs normativos sin hallazgos; versiones,
matrices y obligación pendiente coherentes. Enlaces relativos y diff comprobados.
Esta actualización es documental. Se corrige además, con autorización separada,
la errata local `limport Foundation`; `ReadingWidgetRotation.swift` vuelve a ser
idéntico al archivo de HEAD. No hay cambio de comportamiento ni nuevas suites
por esa restauración; las validaciones anteriores conservan sus fechas y alcances.
Los registros cronológicos anteriores conservan el estado de su propia ejecución;
la cabecera y las checklists actuales recogen la decisión posterior.

### No disponible confirmado y versión normal reinstalada — 8 de septiembre

El propietario confirma «Correctos los tres en español e inglés» sobre el
binario de prueba final: ilustración y locución completa del título/mensaje de
no disponible, sin anuncios decorativos, en las tres familias ES/EN del iPhone 11.
Se completa ese caso de VO-04/05; no se extrapola a otras tecnologías de asistencia,
a I/O protegido ni a primer desbloqueo.

Xcode MCP confirma MangaLibrary/Fast/iPhone 11/iOS 27. Fuente sin sonda temporal
y scheme sin argumentos de fixture. `RunProject` 02:08:08, sin debugger, instala
y abre la versión normal, PID 1462, referencia `ac603eb80`; build correcto y
`GetBuildLog` con cero warnings/errores. El propietario confirma después que los tres widgets vuelven a mostrar sus
lecturas y colección: reinstalación y recuperación visible completadas.
No hay cambios Swift nuevos, suites adicionales ni entrega. Primer desbloqueo
conserva el límite no observable y su traslado a DX6 no está aprobado.

### No disponible: texto directo e ilustración — 8 de septiembre

El propietario confirma la locución del diseño anterior en las tres familias
ES/EN y solicita el tono directo y el libro de los estados de acceso. Se registra
ese resultado como histórico; el cambio posterior exige comprobar su texto final.
SDD 09 v1.13: «¿Actualizamos?» / «Abre Manga Library y actualizamos tus mangas.»;
EN «Let's refresh» / «Open Manga Library and we'll refresh your manga.».
El título español breve está aprobado por el propietario y deja espacio al libro
incluso en el pequeño estándar. Se reutiliza la imagen acotada existente, preparada
por el provider, decorativa y omitida en tamaños de accesibilidad. No cambian
snapshots, política temporal, cuenta, publicación ni entitlements.

- Doce previews nativas iPhone 17 Pro/iOS 27: tres familias × ES/EN × estándar/AX5,
  timeline de no disponible; manifest en
  `.build/dx4-preview/2026-09-08-unavailable/`. Texto completo y libro presente en
  estándar, sin libro en AX5. En pequeño ES AX5 el signo final queda en otra línea;
  detalle cosmético, sin pérdida de mensaje. Revisión visual independiente sin
  hallazgos materiales; previews no acreditan VoiceOver físico.
- Revisión independiente de seis Swift y catálogo, Audit sin candidatos; Audit
  del diff acumulado de siete Swift limpio. No se repiten suites de datos ni DocC
  por este cambio de presentación; los gates anteriores conservan sus fechas.
- `RunProject` 02:04:10, MangaLibrary/Fast/iPhone 11/iOS 27, sin debugger,
  PID 1224 y referencia `adcecfa80`: instalado el nuevo binario de prueba;
  build correcto y `GetBuildLog` con cero warnings/errores.
- Sonda temporal solo DEBUG mediante la inyección existente de `.unavailable`,
  con host normal y sin fixture de datos. Retirada inmediatamente de fuente tras
  instalar; `MangaLibraryWidget.swift` coincide byte a byte con su versión normal
  de este ajuste, SHA-256
  `cd7f12f1f1861262587afe45d289c9aebabaae936b11dde510ba0c44660eb779`.

Pendientes confirmar la ilustración y VoiceOver del nuevo texto en las tres
familias ES/EN, y reinstalar/contrastar el binario normal. El teléfono conserva
la prueba temporal hasta esa reinstalación; restaurar la fuente no basta.
La prueba no acredita I/O protegido ni primer desbloqueo. El traslado de ese
límite a DX6 sigue sin aprobar; no hay commit/push ni entrega DX4.

### Propiedad confirmada y prueba temporal de no disponible — 8 de septiembre

El propietario confirma actualización de tomos poseídos en la ficha visible.
La revisión normativa permite completar la evidencia de colección con esa
observación y los tests/recorridos anteriores; el intento incompleto de Simulator
conserva su resultado histórico.

Se instala en iPhone 11 una sonda solo DEBUG que inyecta `.unavailable` en el
proveedor existente, conservando la vista real y el host normal. Revisión y Audit
sin hallazgos; `RunProject` 01:42:03, sin debugger, PID 741, build correcto y cero
warnings. La sonda de fuente se retira inmediatamente y vuelve al original.
El teléfono conserva el binario temporal hasta comprobar VO ES/EN en las tres
familias y reinstalar la versión normal: ambos pasos siguen pendientes.
No se alteran archivos, cuenta, fence o entitlements para inducir el estado.
Sin nuevas suites ni entrega; primer desbloqueo sigue limitado, aún sin aprobar
su traslado propuesto a DX6.

### Mi colección — retirada visible y propiedad por aclarar, 8 de septiembre

El propietario confirma de nuevo prioridad del manga añadido y retirada inmediata
del eliminado cuando estaba visible, en su observación. Informa que editar tomos
en propiedad no cambia el widget; se aclara si se refiere a datos antiguos en la
ficha visible o a que no salta al manga editado. Aclara después que editaba otro
manga. Solo las altas/reincorporaciones proponen foco de colección según ADR-0022;
esa ausencia de salto no demuestra un fallo. Se propone contrastar el conteo de
la misma ficha tras variar realmente la cantidad poseída, en una entrada sin
lectura. Resultado pendiente; revisión independiente sin defecto concreto de
fuente, sin cambios de código ni entrega.

### VoiceOver en Hoy — confirmado, 8 de septiembre

El propietario confirma locución correcta del pequeño en Hoy, en el mismo
recorrido de iPhone 11/iOS 27. No concreta idioma ni estado de bloqueo durante
esa locución. VoiceOver de no disponible sigue pendiente y el tramo previo al
primer desbloqueo conserva su límite no observable. Sin código, builds/tests
ni entrega; se actualiza evidencia y tracker.

### Colección sintética — intento limitado por herramientas, 7 de septiembre

Xcode MCP instala y ejecuta la fixture con ambos argumentos explícitos en iPhone
17 Simulator/iOS 27, PID 13355; build correcto y sin warnings. Se observan entradas
sintéticas en Colección y el pequeño con Historias del viento, 2/8 y siete
restantes. La pérdida repetida de la sesión de interacción y el fallo de gestos
CUA impiden añadir el mediano y comprobar propiedad/logout. El recorrido de
colección sigue pendiente; no se extrapola la observación del pequeño.

Proceso detenido y sesión ya inexistente según Xcode MCP. Se restaura el destino
iPhone 11; MangaLibrary/Fast y scheme sin argumentos ni diff. No se actúa sobre
la app del iPhone físico ni se modifica Swift. Sin suites nuevas ni entrega.

### Reinicio — observación limitada antes de desbloquear, 7 de septiembre

El propietario no puede acceder a Hoy antes del primer desbloqueo: comunica que
solo dispone de llamada de emergencia y que debe desbloquear para introducir
el PIN de SIM. Tras completar el recorrido, llega a Inicio y Hoy muestra una
lectura en el pequeño. Se confirma la recuperación visible posterior y se
registra el tramo previo como no observable, sin dar por probados I/O protegido,
ejecución del provider ni epoch, ni atribuir esa protección al PIN de la tarjeta.

VoiceOver de no disponible no se ejercitó; colección sintética instrumentada
sigue pendiente en instalación dedicada. No se cambian ajustes, código ni
entitlements; solo documentación y tracker. Sin builds/tests nuevos ni entrega.

### Hoy bloqueado — lectura visible, 7 de septiembre

Tras indicar que los widgets estaban solo en Inicio y preparar un pequeño en Hoy,
el propietario confirma acceso con el iPhone bloqueado y una lectura visible.
Se registra la presentación con los permisos actuales en iPhone 11/iOS 27,
después de haber desbloqueado previamente; no prueba ocultación, ejecución del
provider ni acceso al almacenamiento protegido. El bloqueo de pantalla no
equivale al bloqueo de sesión según SDD 09.

Resta el recorrido tras reiniciar, antes de introducir el código y después de
desbloquear sin abrir la app. Se conservan pendientes VoiceOver de no disponible
y el escenario sintético instrumentado de colección dedicado. Sin código,
builds/tests, cambios de permisos ni entrega; la corrección del pie sigue local.

### Rotación posterior a edición — confirmada, 7 de septiembre

El propietario confirma que pequeño y mediano cambian después de esperar en
segundo plano; comunica cinco minutos exactos en esta observación. Se acredita
continuación tras actualizar sin convertir ese intervalo en garantía de WidgetKit.
Prioridades de alta/edición y rotación posterior quedan registradas.

La preparación siguiente delimita reinicio/primer desbloqueo y privacidad: se
pregunta si hay widgets en Hoy, conservando los permisos actuales. Lo no observable
no se marcará como protección probada. Permanecen esos pendientes, VoiceOver de
no disponible y el recorrido sintético instrumentado de colección dedicado.
Sin código, builds/tests ni entrega nuevos; la corrección del pie sigue local.

### Prioridad al editar y evidencia de retirada — 7 de septiembre

El propietario confirma que editar una lectura existente la coloca primero en
pequeño y grande. Se registra esa prioridad; resta observar la rotación después
de esta edición en segundo plano. La prueba no impone cinco minutos exactos.

La revisión independiente normativa permite reconciliar retirada con evidencia
proporcional: tests deterministas de cierre/verificación/denegación más logout
físico con redacción observada en los tres widgets ES/EN, sin debugger. No se
exige otra inspección de bytes físicos ni se afirma haberla hecho. Primer
desbloqueo y privacidad mantienen su propio alcance pendiente. Sin código,
builds/tests ni entrega nuevos.

### Título largo y prioridad de alta — confirmados, 7 de septiembre

El propietario confirma un título considerablemente largo íntegro con VoiceOver
en las tres familias ES/EN: pequeño truncado en pantalla, mediano en dos líneas
completas y grande entero. Se registra el recorte solo donde se observó.
También confirma expresamente que Mi colección mostró primero ese manga nuevo
tras actualizar, sin comunicar una latencia. Se acredita prioridad de alta en
mediano; edición de lectura existente y condiciones de rotación restantes siguen
pendientes. Sin código, builds/tests ni entrega nuevos.

### Bloqueo/desbloqueo — continuidad confirmada, 7 de septiembre

El propietario confirma widgets con contenido al desbloquear sin abrir la app y
sesión iniciada en Cuenta después. Se marca esa continuidad, manteniendo separados
privacidad durante bloqueo, primer desbloqueo y fence. Aporta un manga como
candidato para título largo; la locución completa y su recorte/idioma siguen
pendientes de confirmación. Sin cambios de código, builds/tests ni entrega.

### VoiceOver inglés — contenido confirmado, 7 de septiembre

El propietario confirma todo el recorrido propuesto de contenido EN en los tres
widgets, sin omisiones ni repeticiones. Contenido, vacíos y sesión cerrada tienen
confirmación física ES/EN en los casos concretos del iPhone 11. Se reconcilia la
checklist; no disponible, título largo identificado y las demás configuraciones
mantienen sus límites o pendientes. No se declara cerrada toda accesibilidad/DX4.

Siguiente paso propuesto: restaurar español y comprobar continuidad visible de
contenido y sesión al bloquear/desbloquear, inicialmente sin abrir la app. No
acredita protección antes del primer desbloqueo ni inspección del fence. Sin
código, builds/tests ni entrega nuevos; la corrección del pie permanece local.

### VoiceOver inglés — sesión cerrada confirmada, 7 de septiembre

El propietario confirma presentación y locución correctas de sesión cerrada en
los tres tamaños EN, sin anuncios de la ilustración. Vacíos y sesión cerrada
quedan comprobados en ES/EN en sus configuraciones registradas; no acredita
latencia ni lectura del fence. Se continúa con contenido EN de la cuenta habitual.
Sin cambios de código, builds/tests ni entrega nuevos.

### VoiceOver inglés — vacíos confirmados, 7 de septiembre

El propietario confirma los mensajes vacíos visibles y hablados completos en
los tres tamaños EN, con la cuenta vacía y el mismo iPhone 11/iOS 27. VO-05 queda
parcial; se continúa por sesión cerrada en inglés antes de volver al contenido.
No se extrapola a otros estados ni se cambia código, ejecutan builds/tests o
realizan acciones de entrega.

### VoiceOver vacíos — cuenta de prueba confirmada, 7 de septiembre

El propietario confirma los mensajes vacíos completos en los tres tamaños ES,
sin datos de la cuenta anterior ni anuncios decorativos, tras iniciar sesión
normalmente con su cuenta vacía. La colección habitual permanece intacta y no se
activa el escenario sintético. VO-04 tiene confirmados sesión cerrada y vacíos;
no disponible conserva su pendiente. Se continúa con VO-05 en inglés desde la
cuenta vacía. Sin código, builds/tests ni entrega nuevos.

### VoiceOver sesión cerrada — tres tamaños confirmados, 7 de septiembre

El propietario confirma presentación y locución correctas del estado de sesión
cerrada en pequeño, mediano y grande ES: mensaje de acceso sin anuncios de la
ilustración. Es evidencia de UI/VoiceOver en iPhone 11 sin debugger; no inspecciona
el fence ni mide latencia. VO-04 conserva pendientes vacío y no disponible.

Se prepara el siguiente caso sin alterar la colección personal. El escenario
sintético existente exige instalación dedicada porque toma bridge y bookkeeping;
no se activa en este iPhone. El propietario confirma que dispone de cuenta vacía;
se continuará con login normal en ella para comprobar los vacíos, aún pendientes.
Sin código, builds/tests ni acciones de entrega nuevos.

### VoiceOver mediano — colección confirmada, 7 de septiembre

El propietario confirma la locución completa y correcta de Mi colección en ES:
encabezado, total, manga, tomos en propiedad, completitud y actualización, sin
anuncios indebidos. VO-03 pasa para el contenido observado en iPhone 11; no se
extiende a ambas variantes de completitud, estados vacíos ni inglés. Los tres
tamaños tienen confirmación de contenido ES en los casos registrados.

Se continúa con VO-04, sesión cerrada en las tres familias. Las pruebas de fence,
privacidad y estados conservan sus evidencias separadas. Sin cambios de código,
builds, tests ni entrega nuevos; la corrección del pie permanece local.

### VoiceOver grande — seis lecturas confirmadas, 7 de septiembre

El propietario confirma el recorrido completo propuesto en el grande ES:
encabezado, los seis mangas con sus progresos y actualización final («7 barra 9,
18:42»), sin anuncios indebidos. VO-02 pasa en esta configuración del iPhone 11;
no acredita inglés ni otras distribuciones. El pie sin restantes se comprueba
en este tamaño. Se continúa con VO-03, colección mediana. Sin código, builds,
tests ni entrega nuevos; la corrección accesible del pie sigue local.

### VoiceOver pequeño — corrección confirmada, 7 de septiembre

El propietario confirma que el pie ya anuncia restantes y actualización completa
(«7 barra 9, 18:42»). Al salir y volver a enfocar tras una rotación, anuncia el
manga visible, incluso recién cambiado. VO-01 pasa en el pequeño ES con restantes;
no se extrapola a EN, al pie sin restantes ni a los otros tamaños. Se conserva
la rotación actual; no se observa contenido antiguo al recuperar el foco.

Se continúa con VO-02 en el grande: títulos/progresos de todas las filas visibles
en orden, actualización al final y ausencia de anuncios decorativos/duplicados.
La corrección del pie permanece local y revisada; no hay nuevo commit/push.

### VoiceOver pequeño — primer resultado físico, 7 de septiembre

Tras el checkpoint `cebf2cf`, el propietario confirma en español encabezado,
título/progreso completos y contador de restantes, pero el pequeño omite la
actualización en su recorrido de VoiceOver. Si rota durante la locución, sigue
anunciando el manga anterior. VO-01 queda parcial con incidencia, sin aprobar.
El propietario confirma después que la fecha está visible y que el foco salta
desde restantes a un icono de la app. El anuncio al salir/reentrar tras una
rotación sigue pendiente. El registro exacto y los límites figuran en la
checklist DX4. Se prepara una etiqueta única para el pie, con restantes y fecha
formateada previamente según el locale, conservando el diseño. Nuevo plural
EN/ES; el mediano y la rotación no cambian. Build MCP y tres previews nativas
correctos en su alcance, sin warnings; revisión independiente sin hallazgos y
Audit sin candidatos. RunProject 20:30:08 instala y abre el cambio en iPhone 11
sin debugger (PID 25037); GetBuildLog sin warnings. La repetición física sigue
pendiente; esta corrección posterior a `cebf2cf` no tiene commit/push.

### Aceptación de UI y comienzo de VoiceOver — 7 de septiembre

El propietario da por terminados los ajustes visuales de los tres widgets y
solicita commit y push del avance en `codex/84-dx4-reading-widget`, seguidos de
pruebas guiadas de VoiceOver. La autorización conserva abiertos #84 y #77;
no incluye PR, merge, cierre de rama ni comienzo de DX5.

La aceptación incluye el total destacado del mediano y los tamaños del grande.
La instalación de desarrollo firmada, la extensión en funcionamiento y el
acceso efectivo al App Group ya están acreditados en iPhone 11/iOS 27; esa
comprobación no acredita distribución ni protección antes del primer desbloqueo.
Se reconcilia la fila correspondiente de DX4.5. Las menciones históricas a
confirmación visual o commit/push pendientes describen el corte de cada ajuste.

Se reutilizan los últimos gates sin cambios posteriores de código: Fast
327 declaraciones / 506 invocaciones e Integration 436 / 598 (total 763 / 1.104),
sin fallos, skips ni runtime warnings; DocC del ajuste de prioridad de altas y
builds limpios Debug/Release de la cabecera final, sin warnings ni errores.
Las revisiones independientes y previews mantienen el alcance documentado en
cada ajuste. La revisión del checkpoint cubre los 57 Swift únicos del diff:
24 en SwiftUI y 36 fuera del widget, con tres archivos comunes. No encuentra
hallazgos bloqueantes; Audit adjudica cinco candidatos no UI sin infracciones
(y ninguno en UI). Se revisan también los +218/0 del proyecto, entitlements,
Info.plist y el cuarto target del script DocC. Las revisiones cruzadas anteriores
se conservan para los componentes que redactó cada revisor. `git diff --cached
--check` queda limpio. Este corte añade reconciliación documental, sin cambios
funcionales.

La validación física comienza por VoiceOver en español, widget pequeño con
contenido, y continuará por grande, colección mediana, estados e inglés.
Todavía no hay resultado hablado confirmado. Permanecen pendientes las pruebas
controladas sin debugger de privacidad, retirada y rotación, y el recorrido
sintético instrumentado de colección; no se deducen otras tecnologías de
asistencia de los resultados de VoiceOver.

### Total destacado en la cabecera de Mi colección — 7 de septiembre

El propietario confirma que el grande ya se ve bien y aprueba subir el total
del mediano a la cabecera. SDD 09 v1.12 y ADR-0022 sitúan «Mi colección» a la
izquierda y una pastilla a la derecha: número mayor semibold y unidad menor,
con `OnBrandContainer` sobre `BrandContainer`. El pie queda solo con la fecha.
No cambian conteo, estado vacío, portada, proyección ni timeline.

La cabecera prueba la pastilla completa y luego solo el número si falta ancho,
con etiqueta accesible completa y sin reducir escala. Un recurso localizado
con énfasis Markdown conserva el plural y el orden de traducción; su locale se
resuelve mediante `LocalizedStringResource` antes de preparar el texto con
atributos. Durante la comprobación se corrige el uso inicial del idioma del
proceso en el formato atribuido; el resultado EN/ES se verifica visualmente.

Build MCP final 19:01:54 correcto. Veintiuna previews nativas iPhone 17 Pro/iOS 27:
1/24/4096 en EN/ES y Large/XXXL/AX5, dos variantes oscuras de 24 y un widget
con ancho de contenido limitado a 220 pt que ejercita la pastilla sin unidad.
Manifest y PNG en `.build/dx4-preview/2026-09-07-collection-header/`. Los
intentos iniciales de descubrimiento de archivos y de preview View directa
no forman parte de esa evidencia; la extensión admite previews de Widget.
La pareja semántica autorizada conserva ratios de contraste calculados desde
los assets: 7,87/8,91/9,56/11,64 en claro/oscuro/alto contraste claro/oscuro.
No se atribuye a estos renders ejecución interactiva de VoiceOver ni hardware.

No se repiten tests de datos ni DocC por este cambio declarativo; los gates
anteriores conservan fecha y alcance. Revisión independiente de seis Swift y
21 renders cerrada sin hallazgos; Audit sin candidatos. RunProject 19:03:32
instala y abre la versión en iPhone 11/iOS 27, PID 24475; GetBuildLog sin warnings.
MangaLibrary/Fast/iPhone11 restaurado. El script aprobado
`Scripts/validate-advanced-build.sh` completa el build-for-testing Debug/Release
final con salida 0, cero warnings/errores y sin metadata de App Intents, usando
Xcode 27 `27A5252f`/Swift 6.4 y destino genérico iOS Simulator, DerivedData temporal.
Registro `dx4-collection-header-final-build.log`.
Confirmación física del nuevo mediano pendiente del propietario; sin commit/push
ni entrega.

### Segundo aumento del grande con cinco y seis lecturas — 7 de septiembre

El propietario solicita aprovechar más espacio en esos dos tamaños. SDD 09
v1.11 y ADR-0022 añaden una primera variante con portadas de 56/47 pt, título
`footnote` semibold y progreso `caption`. La separación entre filas baja a 2 pt
y los espacios flexibles de encabezado/pie pueden ceder hasta 0 pt. Solo se
elige para cinco/seis lecturas reales en un snapshot completo y tamaño no AX.
Si no cabe, se conserva la variante previa de 48/44 pt con sus fuentes originales,
antes de probar 40 pt con las mismas filas o reducir la cantidad. Los intentos
que saltaban directamente al compacto se descartan durante la revisión nativa.

Build MCP 18:36:31 correcto. Quince previews nativas de iPhone 17 Pro/iOS 27 en
`.build/dx4-preview/2026-09-07-five-six-larger/`, incluido manifest: EN/ES con
cinco/seis títulos cortos y largos, ES XXXL/AX5 y controles de una/cuatro lecturas
y snapshot parcial de cuatro. En estándar caben las cinco/seis portadas nuevas;
los títulos largos ejercitan la alternativa anterior sin perder filas. Esta
validación no acredita VoiceOver interactivo ni la apariencia física final.

Revisión independiente de los cinco Swift y quince renders cerrada sin
hallazgos; Audit de estilo sin candidatos y `git diff --check` limpio. Los
controles 1–4, parciales y AX conservan su comportamiento. El script aprobado
`Scripts/validate-advanced-build.sh` finaliza con salida 0: build-for-testing
Debug/Release, cero warnings/errores y sin metadata de App Intents. Xcode 27
`27A5252f`/Swift 6.4, destino genérico iOS Simulator, DerivedData temporal;
registro `dx4-five-six-larger-build.log`.

RunProject 18:39:19 instala y abre la app en iPhone 11/iOS 27, PID 24316;
GetBuildLog sin warnings. MangaLibrary/Fast/iPhone11 restaurado. El propietario confirma después que el grande se ve muy bien; esa aceptación
corresponde al tamaño de cinco/seis lecturas.
No se añaden ni repiten tests de datos o DocC por este ajuste declarativo;
las 763 declaraciones/1.104 invocaciones y archive limpios anteriores conservan
su fecha y alcance. Sin commit/push ni entrega; la matriz restante de DX4.5 no cambia.

### Portadas mayores y prioridad de nuevas incorporaciones — 7 de septiembre

El propietario confirma en el iPhone 11 la corrección de la ilustración y que
la rotación de colección sí se produce; concreta que añadir un manga no cambia
la ficha. El contrato anterior reiniciaba por el primer elemento canónico.
SDD09 v1.10 y ADR-0022 incorporan una preferencia local de presentación para
la última alta o reincorporación confirmada, independiente del tomo de lectura.
No se presenta como último adquirido de la cuenta ni se escribe en la nube.

El evento nace después del commit autorizado de Colección/outbox. El pipeline
lo conserva durante coalescencia, publicación y carga acotada de portadas. El
recurso de colección añade un ID opcional validado, mantiene el array canónico
y conserva bytes anteriores cuando no hay preferencia. La rotación comienza
en ese índice y después recorre todos los mangas. No-op y restauración
conservan ancla y foco; una sesión nueva no hereda la preferencia, y retirar el
manga restaura el inicio canónico. Si un alta pendiente se retira antes de
publicar, permanece el foco anterior válido. No cambian esquema SwiftData,
entitlements, las 13 entradas programadas ni el intervalo nominal de 300 segundos.

En el grande completo noAX, la portada pasa de 160 a 184 pt con 1 lectura; con 5 y 6
usa 48 y 44 pt. Se conservan 2–4, pequeño y snapshots parciales. Si no cabe, prueba
primero igual número de filas compactas y después reduce las filas visibles.

Validación del resultado:

- RED del codec/rotación a las 17:51:45: tres invocaciones fallan por no admitir
  el foco externo o aceptar un ID ajeno; GREEN focal posterior. RED de las
  primeras cinco pruebas de publicación a las 17:54:19: cinco fallos funcionales.
- Suite de publicación final a las 17:57:52: 17 invocaciones pasan. Incluye alta
  sin lectura, coalescencia con edición/importación, restauración/no-op,
  retirada, sesión nueva, reincorporación y alta retirada antes de publicar.
- RED adicional a las 18:04:25, retirando temporalmente solo la prioridad de
  candidatos de portada: falla el caso con foco 260 fuera de las 128 URLs extra,
  pasa el control sin foco. Se restaura el bloque exacto antes del GREEN.
- Planes completos mediante Xcode MCP, MangaLibrary/iPhone17 Simulator/iOS27
  `24A5423a`: Integration 18:04:49 **436 declaraciones/598 invocaciones** y
  Fast 18:05:12 **327/506**. Total disjunto **763/1.104**, cero fallos, skips y
  runtime warnings. Conteos canónicos de xcresult; el agregado MCP mezcla
  resultados anteriores y no se usa como autoridad. Bundles
  `Test-MangaLibrary-2026.09.07_18-04-49-+0200.xcresult` y
  `Test-MangaLibrary-2026.09.07_18-05-12-+0200.xcresult`.
- Once previews nativas iPhone17Pro/iOS27: EN estándar 1/5/6, ES XXXL 1 con título
  largo/5/6, ES AX5 1/5/6 y controles parciales 1/4. Manifest y PNG en
  `.build/dx4-preview/2026-09-07-large-focus/`. La primera override XXXL sobre
  un fixture con tamaño explícito se excluye; los renders válidos usan dos
  nuevas definiciones deterministas. No equivalen a ejecución de VoiceOver.
- Revisión iOS independiente y Audit de 14 Swift sin hallazgos nuevos; un candidato
  previo de llamada compleja queda documentado fuera del delta. Revisión de
  fuente SwiftUI/accesibilidad e inspección visual independiente de los once
  renders cerradas sin hallazgos. `git diff --check` limpio.
- Scripts aprobados `validate-advanced-build.sh` y `validate-docc.sh`, salida 0,
  Debug/Release y archive con cero warnings/errores, Xcode 27 `27A5252f`/Swift 6.4;
  registros `dx4-large-focus-build.log` y `dx4-large-focus-docc.log`.
- RunProject 18:07:35 instala y abre la versión final en iPhone 11/iOS27,
  PID 24107; GetBuildLog sin warnings. Scheme MangaLibrary, plan Fast y destino
  iPhone 11 restaurados, sin cambiar argumentos de lanzamiento.

Pendiente del propietario: añadir un manga y confirmar que es la primera ficha
cuando WidgetKit presenta la actualización; revisar tamaños 1/5/6. No se hacen
altas reales de prueba desde las herramientas. Apple mantiene el control del
momento efectivo de actualización. La matriz restante de DX4.5 sigue abierta.
No hay commit, push, PR ni entrega.

### Corrección del archivado de la ilustración — 7 de septiembre

El propietario informa en iPhone 11 de una representación antigua que pide
iniciar sesión aun estando autenticado, sin aviso de publicación en la app.
La inspección directa con LLDB/Foundation encuentra el App Group disponible,
fence abierto y manifest autorizado de lectura vacía, revisión14. El binario
instalado incluye la vista nueva. No se imprimen identidades ni datos de cuenta.
Ejecutar la extensión con Xcode MCP reproduce cuatro fallos de archivado:
la imagen de1024×1024 excede el área máxima comunicada por esa ejecución.
Las previews anteriores no habían detectado esta frontera de WidgetKit.

Se conserva el PNG original byte a byte como recurso bundled y se prepara con
ImageIO una miniatura de128/288/512px según la familia. El provider la entrega
en la entrada antes del render y conserva la misma CGImage en sus copias;
las Views solo dibujan ese valor. Si falla la carga, permanece el texto. No
cambian autenticación, publicaciones, wire ni política temporal. SDD09 precisa
la cota propia, que no se presenta como límite universal de WidgetKit.

Build MCP final a las17:06:36 correcto, GetBuildLog sin warnings. Seis previews
nativas ES de vacío/redacción, tres familias, iPhone17 Pro/iOS27, conservan
ilustración y mensajes: `.build/dx4-preview/2026-09-07-illustration-fix/`.
Dos revisiones independientes y Audit6Swift sin hallazgos; se corrige durante
revisión la primera decodificación desde body desplazándola al provider.
La extensión final corre en iPhone11 a las17:09:54 (PID23737): no reaparece
el fallo de archivado; queda una incidencia XPC externa de conexión invalidada,
por lo que no se declara una consola completamente limpia ni validación visual
física a partir de su ausencia. El agregado RunProject de extensión acaba
informando fallo de lanzamiento pese al proceso y consola observados; se
conserva esa limitación de herramienta. El RunProject final de la app a las
17:10:46 sí confirma instalación/lanzamiento (PID23750). Xcode queda en
MangaLibrary/Fast/iPhone11. El propietario confirma posteriormente que ahora se
muestra correctamente en el iPhone11; no cierra el resto de la matriz física.

Los scripts aprobados completan build-for-testing Debug/Release y archive DocC,
ambos con salida0, cero warnings/errores y sin tareas de metadata de App Intents
en el gate de build. Toolchain Xcode27 `27A5252f`/Swift6.4, destinos genéricos
iOS Simulator para build e iOS para DocC; DerivedData temporales sin firma.
Registros locales `dx4-illustration-bounded-build.log` y
`dx4-illustration-bounded-docc.log`; archive `.build/docc/MangaLibrary.doccarchive`.

La [checklist DX4](dx4-widget-validation.md#archivado-de-la-ilustración--diagnóstico-físico-del-7-de-septiembre)
recoge la evidencia y los pendientes físicos. No se ejecutan tests de datos
por este cambio de preparación de un recurso visual. Sin commit/push ni entrega.

### Estados sin contenido — 7 de septiembre

El propietario confirma que la ampliación de colección/lectura «ha quedado muy
bien y funcionando como se espera». Es aceptación del propietario; no identifica
el dispositivo ni sustituye la matriz física de DX4.5 o acredita un recorrido
instrumentado. Después aprueba los textos informales y la ilustración del icono
para vacío de lectura y sesión cerrada. Se mantiene la rama/issue84.

La modificación de presentación aplica SDD09 v1.9: «¿Qué estás leyendo?» y «Tus
mangas, aquí», mensajes de acción en Manga Library y composición por familia.
`MangaLibraryFront.png` se copia byte a byte desde el icono existente a un imageset
local del widget; no se cambia el icono de la app. No se modifica proyecto,
snapshot, timeline o publicación.

Build-for-testing por MCP a las 16:18:58: correcto. El script aprobado
`Scripts/validate-advanced-build.sh` completa Debug y Release con cero warnings,
errores o tareas de metadata de App Intents; salida0, registro local
`dx4-status-final-build.log`. Xcode27 `27A5252f`, Swift6.4, cuatro targets,
MangaLibrary/ReleaseGate y destino genérico iOS Simulator, DerivedData temporal
sin firma ni instalación. `GetBuildLog` final sin warnings. El scheme activo
conserva Fast/iPhone17 y no se añaden argumentos de lanzamiento.

Audit independiente de 54 Swift sin hallazgos; cinco candidatos heredados siguen
justificados por closures/llamadas complejas. Las40claves del catálogo tienen
EN/ES; seis corresponden a este ajuste, incluidos los mensajes cortos accesibles.
42 combinaciones de previews nativas iPhone17 Pro/iOS27: tres estados y tres familias en ES con
Large/XXXL/AX5; EN AX5 y variantes ES oscuras de vacío/redacción. Evidencia y
manifest fuera de Git en `.build/dx4-preview/2026-09-07-status/`.
La revisión detecta que el SF Symbol previo `book.closed.badge.questionmark`
no se dibujaba en el estado no disponible. Los metadatos locales de Apple no
incluyen ese nombre; sí `questionmark.circle` desde2019. Se sustituye y se
recompila explícitamente por MCP a las16:25:49; el render16:25:54 muestra el
símbolo correcto. El primer render tras editar aún presentaba la versión
anterior y se excluye. Se conservan56PNG:42iniciales,2diagnósticos y12repeticiones
finales de no disponible, que sustituyen las muestras anteriores en la matriz.
Revisión visual independiente final sin hallazgos:42combinaciones válidas,
30muestras iniciales de vacío/redacción y12finales de indisponibilidad. El símbolo
aparece en tamaños ordinarios y cede espacio cuando es necesario; los mensajes
no se cortan ni solapan. La corrección se valida además con otra ejecución limpia
Debug/Release, salida0 y cero warnings/errores, registro
`dx4-status-symbol-final-build.log`. El registro sin `symbol` conserva el primer
gate aprobado anterior a la corrección. El Audit de los dos Swift del ajuste
se repite sin candidatos ni hallazgos tras cambiar el nombre del símbolo.

No se crean ni ejecutan tests de datos por esta modificación declarativa; el
GREEN anterior de754declaraciones/1.093invocaciones y DocC son evidencia previa
reutilizada, no una ejecución nueva. No se realiza recorrido interactivo ni
VoiceOver físico; DX4.5 mantiene sus pendientes. Sin commit/push ni entrega.

### Colección mediana y lectura adaptable — 7 de septiembre

La petición posterior incorpora «Mi colección» al mediano y ajusta el progreso
pequeño y la amplitud del grande con 1–4 lecturas. Autoridad: SDD 05 v1.9,
SDD 09 v1.8 y ADR-0022. DX4.10–DX4.12 se desarrollan en la misma rama #84;
la evidencia de las ampliaciones anteriores permanece histórica.

El RED inicial ejecutado por Xcode MCP/ReleaseGate, iPhone 17 Simulator, demuestra
que cambiar propiedad de un manga sin lectura no publicaba otra revisión. Una
declaración ejecutada, un fallo conductual esperado en `#require` del resultado;
ningún skip. Bundle `Test-MangaLibrary-2026.09.07_14-30-51-+0200.xcresult`.
El build limpio Debug/Release anterior termina sin warnings ni errores,
`dx4-collection-red-build.log`. Se escriben además pruebas de codec, doble fence,
recursos en dos slots, límites, reparación y rotación de toda la colección.

El RED adicional, tras otro build limpio Debug/Release, ejecuta Fast 325
declaraciones / 503 invocaciones (43 fallos conductuales) e Integration 429/590
(8 fallos), bundles `Test-MangaLibrary-2026.09.07_15-01-00-+0200.xcresult` y
`Test-MangaLibrary-2026.09.07_15-01-18-+0200.xcresult`. La ampliación suma 38
declaraciones / 79 invocaciones: 48 fallan antes de completar codec, lector y
rotación y 31 son controles. Los otros tres fallos pertenecen a dos no-op
históricos afectados por el codec provisional y al oráculo de coalescencia,
actualizado a las solicitudes reales `10 → 10 → 20`: el intento obsoleto prepara
10 y el vigente añade 20, que pertenece a colección pero no tiene lectura.

GREEN final por Xcode MCP, MangaLibrary/iPhone 17 Simulator, iOS 27 `24A5423a`,
Xcode 27 `27A5252f` y Swift 6.4:

| Plan | Declaraciones | Invocaciones | Bundle canónico |
| --- | ---: | ---: | --- |
| Fast | 325 | 503 | `Test-MangaLibrary-2026.09.07_15-08-22-+0200.xcresult` |
| Integration | 429 | 590 | `Test-MangaLibrary-2026.09.07_15-04-19-+0200.xcresult` |
| Total disjunto | **754** | **1.093** | Cero fallos, skips o runtime warnings. |

El resumen y árbol `.xcresult` son la autoridad; el agregado MCP arrastra
resultados ajenos al plan. Fast se repite tras eliminar una aserción redundante
sobre el valor inmutable inyectado; conserva los oráculos conductuales. El Fast
previo de las 15:04:16 ya pasaba 325/503. Las 38/79 nuevas quedan incluidas; no se
suman las repeticiones. `validate-test-plans.sh`: 24 suites Fast/37 Integration,
partición válida y plan predeterminado Fast.

`validate-advanced-build.sh` y `validate-docc.sh` terminan con salida 0, Debug y
Release limpios y archive DocC sin warnings/errores. Logs locales
`dx4-collection-final-build.log` y `dx4-collection-final-docc.log`, destinos
`generic/platform=iOS Simulator` y `generic/platform=iOS`, cuatro targets,
DerivedData temporal y archive `.build/docc/MangaLibrary.doccarchive` fuera de
Git. La única edición posterior es retirar la aserción redundante, recompilada
y validada en Fast final; no cambia producción ni DocC.

Revisión independiente cruzada iOS/SwiftUI/accesibilidad y Audit de 53 Swift
sin hallazgos de fuente pendientes. Cinco candidatos de estilo se justifican
por closures, llamadas anidadas y un guard cuya forma horizontal excede 120
columnas. Se actualizan también los criterios de SDD05 y la matriz de SDD06
para distinguir lectura y colección; ADR0022 limita la garantía de rutas al
lector no-follow y la comprobación previa del escritor.

29 PNG nativos por `RenderPreview`, iPhone 17 Pro/iOS 27, revisados de forma
independiente: pequeño EN/ES conocido/desconocido y AX5; grande 1–6, AX5,
parciales 1/8 y 4/8; mediano propiedad 0/1/300, completitud, total desconocido,
4.096 mangas, estados, título largo ES/XXXL y EN/ES AX5. Sin recortes de progreso
o pie en los archivos finales. Una visualización inicial EN de total desconocido
omitía el contador; repetida sin cambios muestra `1 manga` y ambos archivos
actuales son idénticos por SHA-256. Evidencia y manifest fuera de Git en
`.build/dx4-preview/2026-09-07-collection/`; detalle en la checklist DX4.

La comprobación interactiva de esta ampliación queda pendiente: CUA confirma
que el Mac sigue bloqueado y no puede desbloquearlo automáticamente. No se
atribuyen a este cambio los recorridos anteriores de Simulator. La fixture DEBUG
prepara diez mangas/ocho lecturas sin red ni Keychain, lista para comprobar
colección sin lectura, rotación, propiedad y logout mediante el mismo publicador.
Los nuevos valores y lectores comparten los archivos ya incluidos en ambos
targets; el proyecto conserva su diff previo de 218 líneas. Scheme sin argumentos
temporales ni diff y plan Fast restaurado. DX4.5 física sigue pendiente; no hace
falta Apple Watch. Sin commit/push, PR, merge, cierre ni borrado de rama.

### Rotación y tamaño grande — 7 de septiembre

El propietario aprueba rotación pausada, reinicio por la lectura editada y tamaño
grande con grupos. La unidad continúa en #84 y en la rama DX4 local. ADR-0021
incorpora las garantías de ADR-0010 y cambia su política de presentación; SDD 05
v1.8 y SDD 09 v1.7 fueron la autoridad de esa ampliación.

El plan DX4.6–DX4.9 comprende prioridad opcional compatible con formato 1,
selección prioritaria bajo 32 KiB, eventos/no-op, trece entradas por hora con
pasos de 300 segundos y tres tamaños. Las ventanas avanzan una lectura y se
solapan para no saltar lecturas al reducir filas. Los estados sin contenido no
rotan. El reloj de publicación de la fixture DEBUG ahora es inyectable y usa la
fecha actual; ocho lecturas sintéticas permiten observar grupos con sobrantes.

Tests finales de esta ampliación por Xcode MCP: Fast 298 declaraciones / 440
invocaciones e Integration 418/574, **716/1.014** en total, todos aprobados y sin
skips ni duplicados entre planes. Bundles canónicos del 7 de septiembre:
`Test-MangaLibrary-2026.09.07_12-52-40-+0200.xcresult` (Fast) y
`Test-MangaLibrary-2026.09.07_12-53-36-+0200.xcresult` (Integration), iPhone 17
Simulator iOS 27 `24A5423a`, Xcode 27 `27A5252f` y Swift 6.4. El resumen y árbol
de cada `.xcresult` prevalecen sobre el agregado MCP que arrastra tests ajenos al
plan. `GetBuildLog` sin warnings; test plans válidos, 21 suites Fast/36 Integration.

El RED inicial registra 31 fallos conductuales esperados y 75 controles aprobados
en 106 invocaciones. La revisión encontró además un caso de recuperación de
tombstone mediante propiedad o completitud: sus dos parámetros fallaron antes de
corregir la comparación de `readingVolume` y pasan en Integration completo. La
rotación añade 28 declaraciones / 42 invocaciones. Revisión iOS/SwiftUI y Audit
independientes de 41 archivos Swift sin hallazgos de fuente pendientes.

Un aviso inicial de publicación en Simulator no permitió capturar el error
concreto y no se repitió en dos arranques diagnósticos. La investigación sí
reprodujo un defecto de fechas `.999Z` válidas con reloj real: dos fallos
`invalidDate` en RED Fast 298/438, bundle de las 12:48:22. Normalizar la fracción
dentro del segundo corrige la pérdida de precisión sin cambiar el wire. Diez
casos finales, incluidos antes de 1970 y límites de año, pasan en Fast. El total
de esta ampliación con la corrección de fechas añade **30/52** a la base 686/962;
la relación con el fallo original permanece sin demostración. Revisión y Audit
independientes de los dos archivos de esa corrección, sin hallazgos.

Los scripts aprobados `validate-advanced-build.sh` y `validate-docc.sh` terminan
con salida 0: Debug/Release y archive DocC sin warnings ni errores. Registros
locales finales `dx4-rotation-fractional-build.log` y
`dx4-rotation-fractional-docc.log`, posteriores a la corrección de precisión, sin
publicar artefactos. Los registros sin `fractional` conservan el gate previo.
Previews nativas y revisión visual independientes completadas: tres familias,
grande con seis filas/dos restantes, slots Alba…Faro → Bosque…Girasol, títulos
largos ES/XXX Large y contenido/estados EN/AX5. Catorce PNG inspeccionados, once
válidos; tres capturas iniciales anómalas se excluyen y sus casos se repiten sin
cambiar fuente. Destino real iPhone 17 Pro Simulator/iOS 27, archivos fuera de
Git en `.build/dx4-preview/2026-09-07-rotation/`.

Runtime iPhone 17 final, `RunProject` sin debugger a las 12:54:53: ocho lecturas,
grande con seis filas/dos restantes y mediano con dos/seis. Se observa rotación
natural Historias → Alba entre 12:59 y 13:00, sin abrir la app ni pedir reload.
Guardar Bosque 2 → 3 a las 13:01:22–13:01:24 cambia el foco a Bosque 3/12 y la
fecha a 13:01 en ambas familias; observado a las 13:01:53, sin recortes ni aviso.
Al regresar a Home a las 13:10, sin abrir la app ni forzar reload, la ventana
empieza por Cuaderno en ambos tamaños y mantiene fecha 13:01: se observa también
la rotación posterior a la edición.

Runtime iPad A16/iPadOS 27, `RunProject` sin debugger 13:03:39: grande añadido
tras cerrar la escena sintética; portrait 13:07 → landscape 13:08 → portrait
muestran seis filas/dos restantes, sin recortes y sin relanzar la app. La dificultad inicial de
interacción CUA con una escena lateral se resuelve con App Switcher; no se
atribuye a un defecto del producto.

La [checklist DX4](dx4-widget-validation.md#rotación-y-tamaño-grande--ampliación-del-7-de-septiembre)
registra los detalles y límites. Las secciones siguientes conservan la evidencia
histórica anterior.

Restauración final: proceso detenido, MangaLibrary/Fast/iPhone 17, argumentos
vacíos y diff del scheme limpio. `GetBuildLog` sin warnings; Audit final de los
41 Swift después de la última corrección y `git diff --check`, sin hallazgos.
DX4.6–DX4.9 quedan implementadas y validadas en #84; DX4.5 conserva pruebas
físicas pendientes. No se realizan commit, push ni acciones de entrega.

### Ajuste visual — 7 de septiembre, mañana

- El propietario solicita mejorar la presentación de «Leyendo». El encabezado
  Reading/Leyendo se centra; título/progreso destacados usan headline/footnote,
  portadas escalables de base 60 puntos y 40 en variante compacta. Los títulos
  admiten dos líneas y escala mínima 0,85 en tamaños ordinarios. En accesibilidad
  siguen sin reducir escala, con una línea, encabezado caption y portadas ocultas.
- Los espaciadores anclan el pie abajo. `ReadingWidgetFooterView` pone contador y
  fecha en horizontal si caben y los apila con `ViewThatFits` cuando falta ancho;
  mantiene tipografía semántica y fecha caption2. Snapshot, eventos y capacidades
  del bridge no cambian.
- Los renders de 10:31:28–10:33:25 observan mediano con dos lecturas, total
  desconocido EN/AX5 en ambas familias y títulos largos ES en dos líneas, pequeño
  Light y mediano XXX Large. La [checklist](dx4-widget-validation.md) registra
  cada entorno y hora. La revisión independiente final de los 13 archivos Swift
  del widget y siete renders no encuentra hallazgos; Audit Swift Source Style
  devuelve cero candidatos. El catálogo conserva 15 claves completas EN/ES.
- `Scripts/validate-advanced-build.sh` aprueba Debug y Release después del ajuste
  (`dx4-widget-polish-build.log`, salida 0), con cero warnings, errores o tareas
  de metadata de App Intents. Se reutilizan los resultados Swift Testing 686/962
  anteriores porque el cambio afecta solo a UI, y el archive DocC anterior al no
  cambiar fuente DocC; no se presentan como nuevas ejecuciones.
- Runtime iPhone 17: `RunProject` 10:36:48 y CUA 10:38 confirman las cuatro
  lecturas 3/2/8/1. El pequeño conserva 1/+3 y Alba en dos líneas; un mediano
  nuevo conserva 2/+2 y pie horizontal. No se observan recortes, solapamientos o
  marcas de diagnóstico. La fixture usa placeholders de portada; la portada
  grande observada en galería es sintética.
- Runtime iPad: `RunProject` 10:39:08 y recorrido CUA 10:43–10:44 confirman
  portrait→landscape→portrait sin recortes ni elementos superpuestos. Los tres
  medianos muestran 1/+3, Leyendo centrado, portada placeholder grande y pie
  horizontal; el pequeño conserva 1/+3 con pie vertical. La portada y tipografía
  mayores reducen la densidad mediante la adaptación prevista; no se extrapolan
  a esta UI las dos filas de la versión anterior.
- Los dos `RunProject` terminan sin build errors; `GetBuildLog` devuelve cero
  warnings. Los procesos se detienen y Xcode queda en MangaLibrary/Fast/iPhone 17,
  con argumentos vacíos y diff del scheme vacío. El ajuste visual queda validado
  en el alcance registrado, sin ampliar la evidencia física.
- Las previews pequeño Light y mediano Dark se conservan localmente en
  `.build/dx4-preview/2026-09-07-reading-polish/`, fuera de Git. No se exporta
  la imagen aportada por el propietario.
- El propietario comunica que funcionan correctamente y aporta una captura.
  Sin modelo ni versión de sistema explícitos, esa observación no acredita
  VoiceOver, provisioning ni protección física de archivos.
- El segundo widget «Mi colección» es una propuesta sin implementar. Los datos
  actuales permiten contar títulos activos y colecciones completas; falta una
  fecha real para «último adquirido». Requiere otra unidad con contrato de
  snapshot/eventos y semántica de los contadores, sin reinterpretar el snapshot
  de lectura ni iniciar ese trabajo como parte del ajuste visual.

### Evidencia base — 6 de septiembre y madrugada del 7

Los resultados siguientes corresponden a la versión anterior al ajuste visual
de la mañana. Conservan su alcance original y no sustituyen su repetición visual.

- El propietario autoriza crear issue/rama e implementar DX4. Base limpia y sincronizada:
  merge de PR #83 `fa60f154cfe9e3619cd7d979924f501bc1e2350a`; issue #82 cerrado.
  Se crea #84 como hijo nativo de #77 y rama `codex/84-dx4-reading-widget`.
- Xcode MCP oficial crea `MangaLibraryWidgetExtension` sin Configuration Intent,
  con embedding solicitado en MangaLibrary. Verifica bundle
  `com.plusprojects.MangaLibrary.widget`, plataformas iOS/Simulator, familias 1/2,
  Swift 6, aislamiento nonisolated, concurrencia completa y warnings como errores.
  App y widget reciben el entitlement del App Group aprobado. Las ocho fuentes
  comunes y los Assets ya tienen pertenencia al widget, completada en la UI de Xcode.
- El widget usa `StaticConfiguration`, familias pequeña/mediana y una entrada
  con `.never`. Consume el prefijo publicado sin red, SwiftData ni Keychain;
  distingue contenido, vacío, redacción y no disponible. El lector abre archivos
  sin seguir enlaces, limita bytes y aplica `fence → snapshot → fence` en cada petición.
- La composición live comparte escritor, eventos y publicador con SessionController.
  La resolución del App Group se repite en cada efecto; su ausencia falla sin crear
  almacenamiento privado sustituto. Un propietario observable de ámbito app coordina
  tareas de escenas activas, libera la exclusión después del drenaje y mantiene
  los fallos de retirada para reintento explícito y reconciliación de Cuenta.
- La UI EN/ES conserva Library Red y el orden del snapshot. El mediano reduce el
  prefijo 3→2→1 según espacio; el pequeño muestra uno. El ajuste de AX5 oculta
  portadas decorativas en tamaños de accesibilidad y abrevia contador/fecha visuales,
  manteniendo sus etiquetas accesibles completas. La carga de portadas se limita
  a las tres primeras lecturas. La aceptación visual/runtime se registra por separado.
- El escenario DEBUG `-ui-testing -ui-testing-reading-widget` usa Colección en memoria
  y cuatro lecturas sintéticas, con mutaciones y publicador reales en el App Group
  canónico. Solo debe usarse en una instalación de pruebas: toma ese bridge y su
  bookkeeping privado existente. No ejecuta red ni accede a Keychain.
- Incidencia histórica resuelta: el primer build falló por pertenencia compartida
  e inicializador del provider; ese fallo de compilación no cuenta como RED conductual.
  Después de corregirlo, Clean y BuildProject por MCP pasan sin warnings.
- RED oficial posterior: 24 declaraciones / 52 invocaciones, con 31 fallos conductuales
  y 21 controles aprobados. GREEN focalizado: 24 declaraciones / 35 invocaciones;
  solo ejecutó parte de los argumentos y no acredita por sí solo las 52.
  Fast e Integration posteriores ejecutan las cuatro suites completas, todas verdes.
- La revisión iOS independiente del wiring, lifecycle, lectores y tests no conserva
  hallazgos en esos ámbitos. El P2 del loader se resuelve limitando la preparación
  al prefijo máximo de tres. Audit Swift Source Style de los siete archivos del
  wiring, fixture, lifecycle y lector de disco sin hallazgos en el diff; la disposición
  vertical preexistente de SessionAPIClient conserva su closure de reloj.
  La revisión final posterior al ajuste de espaciado abarca los 28 archivos Swift
  del diff y la fuente SwiftUI/accesibilidad, sin hallazgos.
- Los scripts aprobados ejecutan builds limpios `build-for-testing` Debug y Release
  para iOS Simulator: cero warnings, errores o tareas de extracción de metadata de
  App Intents. La ejecución final posterior al ajuste de espaciado confirma ambas
  configuraciones con los mismos resultados (`dx4-advanced-build-final-layout.log`,
  salida 0). Xcode MCP `GetBuildLog` de las 00:13 conserva cero issues.
  `validate-docc.sh` valida cuatro targets y genera
  `.build/docc/MangaLibrary.doccarchive` con cero warnings y errores.
  `validate-test-plans.sh` verifica 20 suites Fast y 35 Integration.
- Xcode MCP `RunProject` (23:14:58) y CUA DeviceHub acreditan la instalación DEBUG
  de pruebas en iPhone 17/iOS 27, ES y Dark. El pequeño muestra Alba 3/3 y tres más;
  el mediano, Alba 3/3 y Bosque 2/12 y dos más. Cambiar Alba a 2 se observa en ambas
  familias; logout con descarte deja Cuenta sin sesión y ambos widgets redactados.
  Volver a foreground no repuebla el escenario. Es evidencia de lectura efectiva
  entre procesos; no es una inspección del disco ni establece un plazo de recarga.
- Los renders nativos en iPhone 17 Pro verifican los cuatro estados pequeños ES/AX5,
  total desconocido pequeño/mediano ES/Dark y EN/AX5, y redacción visual de privacidad.
  El locale `en` solicitado al MCP no se aplicaba; los renders EN válidos usan el
  wrapper DEBUG con locale explícito de Environment (23:21:10 y 23:21:18).
  En aquella UI, el encabezado breve «Reading»/«En lectura» conservaba su etiqueta
  accesible completa; corresponde a la versión anterior al ajuste de la mañana.
  El cálculo independiente de los Assets da un contraste mínimo de 6,32:1 en las
  cuatro variantes; no acredita VoiceOver ni sustituye la matriz visual completa.
- iPad A16/iPadOS 27, ES/Light: la app muestra cuatro lecturas y rota a landscape;
  los widgets instalados muestran contenido en ambas orientaciones. La galería
  solo mostró Manga Library tras lanzar el scheme de la extensión por MCP
  (23:27:46). Un mediano nuevo añadido sin ese lanzamiento confirma después un
  defecto de densidad: una fila y tres más con ancho libre, pese a que el payload
  sintético contiene las cuatro lecturas. La corrección posterior resuelve el
  presupuesto de altura. Las previews iPad terminaron en timeout y
  `CHSErrorDomain 1051 timelineReloadTimeout`; no cuentan como UI aprobada.
- Tras ese lanzamiento de la extensión, abrir el host desde el Dock lo arrancó
  sin los argumentos DEBUG y mostró el Catálogo normal. El recorrido se detuvo
  antes de Cuenta o mutaciones; esas pantallas no acreditan la fixture aislada.
  Xcode MCP relanzó MangaLibrary con ambos argumentos a las 23:33:13. Después de
  una terminación/rearranque del proceso hay que relanzar así la instalación de
  pruebas; los argumentos no se conservan al abrir desde el sistema.
- Dos ventanas iPad: ambas visibles; tras cerrar una se cambia Alba 3→2 desde la
  restante y los widgets muestran la actualización. El recorrido acredita el
  cableado entre escenas; no demuestra una cancelación exactamente dentro de un
  commit, cuya exclusión y drenaje tienen cobertura aislada en tests.
- La medición temporal del 7 de septiembre aisló el límite de altura: área mediana
  307×120 puntos frente a 120×120 del pequeño. Reducir el espaciado principal de
  6 a 4 recupera seis puntos y permite la candidata de dos filas. Tras restaurar
  `ViewThatFits` 3→2→1 sin GeometryReader ni sondas, `RunProject` de las 00:08:18
  muestra en tres medianos Alba 3/3, Bosque 2/12, dos más y la fecha sintética del snapshot. No se
  atribuye el fallo a WidgetKit. El recorrido CUA de las 00:09–00:10 aprueba
  portrait→landscape→portrait: medianos 2/+2 y pequeño 1/+3, sin recortes,
  solapamientos o marcas de diagnóstico.
- Repetición final iPhone 17: `RunProject` de las 00:10:46 y observación CUA de
  las 00:11 confirman las cuatro lecturas 3/2/8/1, mediano 2/+2 y pequeño 1/+3,
  fecha íntegra y ausencia de marcas de diagnóstico, con espaciado de cuatro puntos.
- Renders finales iPhone 17 Pro/iOS 27: total desconocido EN/AX5/Dark en pequeño
  y mediano (00:12:09 y 00:12:19), y vacío/redacción/no disponible pequeños
  EN/AX5/Light (00:12:32, 00:12:41 y 00:12:51) legibles. El título largo mediano
  ES/XXX Large/Light (00:13:03) reduce a una fila y usa elipsis intencional; conserva
  progreso 1/12, seis lecturas más y fecha íntegra.
- La validación automatizada y Simulator de DX4 queda completada en el alcance
  registrado. La ampliación combinatoria de familias, estados y entornos pertenece a
  DX6; esta evidencia acredita únicamente los casos observados.
  La validación física conserva sus pendientes. La [checklist DX4](dx4-widget-validation.md)
  conserva las acciones, resultados y límites de cada entorno.
- Provisioning, protección antes del primer desbloqueo y VoiceOver del widget
  requieren iPhone físico y mantienen DX4.5 y el issue #84 abiertos. DX4 no necesita Apple Watch; no se acredita todavía el
  Deluxe Release Gate ni se extrapola la evidencia histórica de Advanced o DX3.
- Cierre de la sesión de validación: Xcode UI retira los dos argumentos DEBUG y
  el diff del scheme vuelve a vacío. Xcode MCP queda en MangaLibrary, Fast e
  iPhone 17, con el proceso detenido. #84 y el plan #77 quedan actualizados y
  abiertos; DX1–DX3 siguen siendo las tres fases entregadas de siete.
- No hay commit, push, PR, merge ni cierre DX4 autorizados. DX5 no se inicia.

### Resultados canónicos de tests DX4

Xcode MCP oficial, Xcode 27 `27A5252f`, Swift 6.4, scheme MangaLibrary,
iPhone 17 Simulator/iOS 27 `24A5423a`, arm64. Los árboles y resúmenes nativos
se contrastan con `xcresulttool` beta 25114, esquema 0.4.0, sin ejecutar tests
por CLI ni cambiar `xcode-select`. No se suman nodos padre, reintentos ni historia.

| Plan | Declaraciones | Invocaciones | Resultado |
| --- | ---: | ---: | --- |
| Fast | 278 | 399 | Todas aprobadas; 0 fallos, skips o runtime warnings. |
| Integration | 408 | 563 | Todas aprobadas; 0 fallos, skips o runtime warnings. |
| Total disjunto | 686 | 962 | Sin identificadores duplicados ni compartidos entre planes. |

Bundles: `Test-MangaLibrary-2026.09.06_23-01-52-+0200.xcresult` (Fast) y
`Test-MangaLibrary-2026.09.06_23-02-53-+0200.xcresult` (Integration).
Los agregados MCP 402/797 no corresponden al contenido canónico de estos bundles.

| Suite nueva | Declaraciones / invocaciones aprobadas | Comportamiento |
| --- | ---: | --- |
| ReadingSnapshotReadResultTests | 8 / 23 | Contenido/vacío autorizado, redacción, incompatibilidad, doble fence y errores de I/O. |
| ReadingPublicationLifecycleTests | 6 / 6 | Exclusión, drenaje, cancelación y fallos que esperan reintento explícito. |
| ReadingLiveSnapshotStorageTests | 2 / 4 | Grupo ausente, recuperación del mismo storage y separación público/privado. |
| ReadingSnapshotFileReaderTests | 8 / 19 | Disco real aislado, límites, enlaces/FIFO, ausencia y reemplazo atómico concurrente. |
| Total nuevo | 24 / 52 | Todas las combinaciones ejecutadas dentro de Fast e Integration. |

## Entrega DX3 — issue #82 / PR #83

- El propietario autoriza commit, push, PR, merge y cierre del issue y de su rama
  el 6 de septiembre de 2026. DX3.5 se publica en
  `14d6251d0a42ae5fe247f4963da241848a384569`, con commit/push verificados.
- La [PR #83](https://github.com/JFrancoG/MangaLibrary/pull/83) agrupa DX3.1–DX3.5
  desde la base DX2 `c55a88c` y se fusiona en `fa60f154cfe9e3619cd7d979924f501bc1e2350a`,
  cerrando [#82](https://github.com/JFrancoG/MangaLibrary/issues/82). La rama local/remota
  se elimina después de comprobar ascendencia, cero commits únicos e igualdad del árbol.
- Se reutilizan los gates inmediatamente anteriores de DX3.5: 662 declaraciones /
  910 invocaciones, builds limpios Debug/Release y DocC, sin modificaciones
  funcionales posteriores. La revisión independiente de entrega confirma el diff,
  Audit Swift Source Style y ausencia de deriva; Xcode MCP conserva MangaLibrary,
  Fast e iPhone 17 Simulator, con Navigator limpio y proyecto protegido intacto.
- Al entregar DX3, el siguiente corte era DX4, autorizado posteriormente en #84.
  El plan #77 conserva DX4–DX7 y la matriz física pendiente; la entrega DX3 por sí
  sola no inició consumidores ni declaró el Deluxe Release Gate.

## DX3.5 — gate técnico conjunto de publicación — issue #82

- El propietario autoriza «Commit y push. adelante con DX3.5». DX3.4 se publica
  en `8ca565d54342361cde5c72075fc2bf3825d5fd81`, rama
  `codex/82-dx3-reading-projection`; commit/push y HEAD remoto verificados, worktree
  limpio antes de DX3.5. Se reutilizan sus gates recientes de 660 declaraciones /
  908 invocaciones y DocC sin deriva funcional antes de publicar.
- La auditoría conjunta contrasta la unidad completa desde la base DX2 `c55a88c`:
  selección persistida, recorte/presupuesto, recursos y recuperación, eventos,
  orden y sesión. No detecta defecto funcional nuevo. Identifica dos comprobaciones
  integradas necesarias: commit real hasta JPEG/manifest/fence/reload, y conservación
  física del estado publicado ante una lectura histórica inválida ya persistida.
- La revisión del perfil mueve el inicializador validante de ReadingPublicationPlan
  a una extensión con almacenamiento privado, preservando sus invariantes; tres
  ajustes de disposición completan el Audit Swift Source Style conjunto.
- Dos caracterizaciones integradas nuevas usan Colección SwiftData real en memoria,
  composición aislada, imagen sintética y directorios temporales. La primera deriva
  el evento de un commit real; dentro de la solicitud de reload comprueba lectura
  persistida, manifest aceptado por doble fence y JPEG legible con SHA-256,
  dimensiones y contenido esperado. La segunda persiste un tomo histórico 301,
  recrea el escritor y exige error tipado, conservando byte a byte todo el bridge,
  sin nueva descarga/reload ni corrección silenciosa del dato.
- La segunda prueba suministra el evento autorizado de restauración; los hooks de
  activación de SessionController se verifican en DeluxeSessionTests. El pipeline
  se construye directamente para rechazar cualquier reconciliación inesperada;
  no acredita arranque live ni una recarga efectiva de WidgetKit/WCSession.
- Sensibilidad comprobada mediante dos mutaciones temporales compilables: omitir
  la señal del commit hace fallar la primera prueba; devolver `nil` para lectura
  inválida hace fallar la segunda al publicar vacío. Ambos archivos se restauran
  exactamente antes del GREEN final. Son caracterizaciones de comportamiento ya
  implementado, no un defecto funcional nuevo ni RED retrospectivo. Durante la
  preparación se añade el import de CoreGraphics y se corrige un umbral de color
  excesivo para JPEG; no se cambia producción para satisfacer ese oráculo.
- Xcode MCP oficial, Xcode 27 `27A5252f`, Swift 6.4, scheme MangaLibrary,
  iPhone 17 Simulator/iOS 27 `24A5423a`: **Fast 264/264 declaraciones y 370
  invocaciones; Integration 398/398 y 540. Total 662/910**. Árboles y resúmenes
  nativos `.xcresult` verifican todas las declaraciones y argumentos, incluidas
  las dos pruebas nuevas; cero fallos, skips, expected failures o runtime warnings.
  Ejecuciones finales `Test-MangaLibrary-2026.09.06_21-32-11-+0200.xcresult`
  (Integration) y `Test-MangaLibrary-2026.09.06_21-32-27-+0200.xcresult` (Fast).
  Los agregados MCP incluyen resultados ajenos al filtro y no sustituyen esa evidencia.
- Scripts aprobados por SDD 06/ADR 0020: `validate-advanced-build.sh` termina con
  exit 0, build-for-testing limpio Debug y Release, tres targets actuales, destino
  generic iOS Simulator y DerivedData nuevo por configuración. `validate-docc.sh`
  termina con exit 0, Release generic iOS, DerivedData nuevo y archive en
  `.build/docc/MangaLibrary.doccarchive`. Ambos gates tienen cero warnings/errores.
  El script de build no ejecuta UI ni acredita el Deluxe Release Gate.
- Build-for-testing MCP final, log y Navigator limpios. Plan Fast restaurado;
  `validate-test-plans.sh` confirma 18 suites Fast y 33 Integration. Revisión iOS
  independiente del conjunto y Audit Swift Source Style de los cinco Swift
  modificados/nuevos sin hallazgos pendientes. Hash protegido del proyecto intacto;
  no cambian wire, esquema, targets, entitlements o composición live.
- **Registro histórico anterior a la entrega DX3:** al completar DX3.5, sus cinco
  bloques estaban completos técnicamente y quedaban commit/push y entrega de #82.
  Entonces #82 y #77 seguían abiertos y había 2/7 subfases entregadas. La entrega
  posterior mediante PR #83, descrita arriba, cierra #82 y eleva el total a 3/7.
- Límites: datos sintéticos, disco temporal y simulador. No se ejecuta UI ni se
  añade evidencia de accesibilidad, App Group, WidgetKit, WatchConnectivity o
  hardware físico. El guard de 64 millones de píxeles y la cancelación durante
  transferencia ya iniciada conservan revisión de código sin caracterización
  runtime específica. La matriz física y el gate global siguen en DX6/DX7.

| Criterio conjunto DX3 | Evidencia de comportamiento |
| --- | --- |
| Selección, orden y datos históricos | CollectionReadingProjectionTests; ReadingPublicationIntegrationTests añade conservación física ante tomo 301. |
| Prefijo, presupuesto y no-op | ReadingPublicationPlanTests y ReadingProjectionPublicationTests: framing final, límite inclusivo, reserva y reload sin cambios. |
| JPEG, cuota, retención y recuperación | Suites ReadingCover de preparación, fuente, batch, almacenamiento y publicación; oráculos de bytes, disco y fallos. |
| Eventos y orden | CollectionReadingEventTests y ReadingPublicationPipelineTests: commits reales, rollback, ticket, supersesión y consumidor. |
| Sesión y fence | DeluxeSessionTests y ReadingSnapshotPublisherTests: bootstrap, expiración, cancelación, logout y autoridad exacta. |
| Cadena completa de contenido | ReadingPublicationIntegrationTests: commit → proyección → JPEG → manifest/fence aceptados en la solicitud controlada de reload. |

## DX3.4 — eventos, orden y reconciliación de sesión — issue #82

- El propietario autoriza «commit y push. Adelante con DX3.4» el 6 de septiembre.
  DX3.3 se publica en `99203db1bc7903f5cbf50c036cb2ca2465902c31`, rama
  `codex/82-dx3-reading-projection`, con HEAD remoto verificado y worktree limpio
  antes de DX3.4. Se reutiliza su validación reciente sin deriva funcional.
- El único actor de Colección señala después de commits reales y dentro de la
  misma autorización: mutación local, importación, rechazo permanente, DELETE y
  outcome bloqueado. Rollback/cancelación previa no señalan. Outbox-only conserva
  el ticket. Descartar durante logout invalida sin publicar contenido intermedio.
- Un emisor conserva el último evento y un ticket opaco de vigencia. El consumidor
  estructurado relee SwiftData y prepara portadas; la preparación antigua se rechaza
  aunque termine después. El publicador valida ticket dentro del cerrojo de sesión
  al admitir recursos, sustituir manifest y abrir fence. Las reservas consumidas
  siguen sin reutilizarse. Una publicación fallida no revierte Colección/outbox.
- Buffer del último evento, suscripción exclusiva y reinicio sin perder la última
  intención. Cancelar no libera el consumidor hasta terminar su preparación.
  Restauración, login, refresh y reactivación tras logout fallido emiten capacidad
  nueva. Se prueba restauración local aunque falle la consulta de identidad offline.
- La revisión independiente detecta caducidad durante una portada: rechazar el
  resultado sin avisar al propietario dejaba el fence anterior permitido. RED lo
  confirma. El pipeline reconcilia con SessionController, que retira mediante DX2
  o reintenta su retirada capturada por autoridad exacta. Fallar fence/Keychain
  termina el consumidor con error visible. Cancelación coincidente tampoco omite
  esa reconciliación; conserva su tipo salvo fallo de retirada, que tiene prioridad.
- Factoría aislada en AppComposition: container, directorios, reloj, UUID, portada
  y reload inyectados. La factoría de pipeline exige el propietario de sesión.
  No arranca tareas ni conecta AppComposition.live. SDD 09 v1.5 concreta estas
  garantías sin cambiar wire, esquema SwiftData o arquitectura de consumidores.
- RED compilables por Xcode MCP: 24 fallos y 10 controles en señales/pipeline/sesión;
  2 regresiones de publisher por ticket; 3 de caducidad/reconciliación; 2 de
  cancelación coincidente con 2 controles. Un fixture de publisher reentraba al
  obtener autorización dentro del gate; se corrige antes del RED conductual.
  Otro oráculo esperaba revisión 2 tras logout fallido: DX2 consume esa reserva,
  por lo que el resultado correcto es 3; se corrige el test, no producción.
- GREEN/regresión final por RunAllTests: **Fast 264/264 declaraciones, 370
  invocaciones; Integration 396/396, 538 invocaciones. Total 660/908**. Cero fallos,
  skips, expected failures o runtime warnings en los resultados nativos xcresult.
  Las **31 declaraciones/41 invocaciones nuevas** pasan completas: Colección 12/17,
  pipeline 13/13, sesión 5/9 y publisher 1/2. Los agregados MCP y los focales parciales
  no sustituyen los árboles nativos ni acreditan ReleaseGate completo.
- Xcode MCP oficial: Xcode 27 `27A5252f`, Swift 6.4, scheme MangaLibrary,
  iPhone 17 Simulator/iOS 27 `24A5423a`; build-for-testing y logs sin warnings o
  errores, Navigator limpio. Fast queda activo. Script de planes: 18 suites Fast
  y 32 Integration, filtros/partición válidos. Hash protegido del proyecto intacto.
- Gate DocC final: Scripts/validate-docc.sh termina con exit 0, Release generic
  iOS y DerivedData temporal nuevo; archive generado en
  `.build/docc/MangaLibrary.doccarchive`, cero warnings/errores y sin allowlists.
- Revisión iOS independiente y Audit Swift Source Style sobre los 13 Swift:
  correcciones de inicializador/formato aplicadas y P1 resuelto con regresiones;
  reauditoría de cancelación limpia. No se modifica UI; no hay nueva evidencia
  de accesibilidad, App Group, WidgetKit, WatchConnectivity o hardware físico.
- **Estado al completar DX3.4: completo localmente, 4/5 bloques; DX3.5 y commit/push de DX3.4 pendientes en ese corte.** #82 y #77 continúan
  abiertos, sin PR/merge/cierre; Deluxe conserva 2/7 subfases entregadas por PR.

## DX3.3 — portadas acotadas y recuperación — issue #82

- El propietario autoriza «commit y push y DX3.3» el 6 de septiembre de 2026 y
  pide continuar tras la interrupción. DX3.2 se publica en
  `95213eda4f9cacde31929917c2d7d750f087691a`, rama
  `codex/82-dx3-reading-projection`; HEAD remoto verificado. Se conserva la
  validación reciente de ese bloque sin deriva funcional antes del commit.
  DX3.3 queda local, sin ampliar la entrega a PR, merge, cierre o DX3.4.
- Entrada HTTPS opcional mediante `URLSession.AsyncBytes`, acotada a 8 MiB;
  preparación secuencial fuera del actor del llamador sobre el prefijo potencial,
  con deduplicación de URL y bytes JPEG, sin cache de fuentes. Image I/O produce
  el primer frame orientado, con aspecto preservado y sin copiar metadata,
  hasta 384 px/65.536 bytes. Un valor validado calcula SHA-256 de los bytes exactos.
- Un único publicador decide cuota/prefijo y no-op antes de escribir portadas.
  Journal, staging protegido y receipts permanentes preceden al manifest;
  promoción exclusiva, reutilización íntegra y cuota global de 8 MiB incluyendo
  metadata. Fallo posterior a seleccionar una referencia conserva el manifest
  anterior y consume la reserva, sin sustituirlo por éxito con placeholder.
- Recuperación conservadora: inventario completo antes de borrar, manifiesto
  reconciliado válido y ausencia de receipt para un huérfano propio. Se retienen
  recursos ambiguos o ya referenciados, incluso al restaurar un JPEG cuya receipt
  desapareció. Los receipts anteriores al manifest se conservan aunque falle
  este último; esa retención deliberada puede agotar la cuota antes.
- La revisión detecta y convierte en RED dos casos adicionales: pérdida conjunta
  de JPEG/receipt con referencia vigente, y avance de manifest tras una limpieza
  pendiente. El plan puede leer un journal ya comprometido sin modificarlo;
  después del no-op final, el commit liquida ese intento contra el manifest aún
  válido. El caso parcial por cuota también queda sin escrituras ni reload.
  Un fallo de mantenimiento de portadas no impide cerrar el fence de sesión.
- RED compilables por Xcode MCP: imagen/fuente (35 fallos de 39 invocaciones,
  con 4 controles), almacenamiento/publicación (16 fallos y 10 controles),
  batch (7 fallos), no-op con journal pendiente, las dos regresiones de retención
  y las dos de avance/no-op parcial. El fixture de cuota inicial generaba JPEG
  de 71.320 bytes a calidad 0,4 y era correctamente rechazado; se ajusta el
  ruido sintético a 352×352, conservando los oráculos de ocupación de 8 MiB.
- GREEN y regresión completos por `RunAllTests`: **Fast 264/264 declaraciones,
  370 invocaciones; Integration 365/365, 497 invocaciones**. Total **629/867**,
  cero fallos, skips, expected failures o runtime warnings. Los árboles nativos
  `.xcresult` acreditan las **53 declaraciones/80 invocaciones nuevas**:
  preparación 14/28, fuente 5/11, batch 7/7, almacenamiento 17/24 y publicación
  10/10. Los agregados MCP incluyen resultados ajenos al filtro; no se usan para
  declarar cardinalidad ni se confunden con ejecución de ReleaseGate completo.
- Xcode MCP oficial: Xcode 27 `27A5252f`, Swift 6.4, scheme MangaLibrary,
  iPhone 17 Simulator/iOS 27 `24A5423a`. Build-for-testing final y log completo
  sin warnings/errores; Navigator sin diagnósticos. Fast queda activo. El script
  de planes acredita 18 suites Fast y 30 Integration, partición y filtros válidos.
- Gate DocC final: `Scripts/validate-docc.sh` termina con exit 0 en Release
  generic iOS y DerivedData temporal nuevo. Archive generado en
  `.build/docc/MangaLibrary.doccarchive`, con cero warnings/errores y sin allowlist.
- Revisión iOS independiente y Audit Swift Source Style sobre los 12 Swift:
  correcciones conductuales y léxicas aplicadas. Reauditoría final de código,
  resultados nativos, DocC y documentación cerrada sin hallazgos.
- **DX3.3 completo localmente, pendiente de commit/push; DX3 queda en 3/5 bloques.**
  #82 y #77 siguen abiertos; Deluxe conserva 2/7 subfases entregadas por PR.
  Siguiente: **DX3.4, eventos y orden entre proyecciones de la misma sesión**.
  SDD 09 v1.4 concreta fuentes, recursos y recuperación; wire y esquema no cambian.
- Validación determinista con URLProtocol, imágenes nativas sintéticas y disco
  temporal aislado, sin red real o producción. La cancelación de la transferencia
  ya iniciada y la cota de 64 millones de píxeles conservan revisión de código,
  sin caracterización runtime específica. No cambia UI, composición live,
  targets, App Group o entitlements. No acredita WidgetKit, WatchConnectivity,
  accesibilidad ni hardware. `project.pbxproj` conserva SHA-256
  `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`.

## DX3.2 — prefijo estable y no-op — issue #82

- El propietario autoriza «commit y push y DX3.2» el 6 de septiembre de 2026.
  DX3.1 se publica en `db5d2eb2fda8d29ae7a75be8a27d251af9fa042e`, rama
  `codex/82-dx3-reading-projection`, con HEAD remoto verificado. Se conserva su
  validación reciente sin deriva funcional. El nuevo bloque continúa en #82;
  no amplía la autorización a PR, merge, cierre o DX3.3–DX3.5.
- `ReadingPublicationPlan` prepara un prefijo puro desde todos los candidatos
  DX3.1 y referencias opcionales ya decididas. Valida todos antes de truncar,
  conserva total/autoridad y mide con el codec final, revisión máxima y fecha
  wire fija. La búsqueda crece hasta el primer exceso y acota el intervalo;
  no intenta codificar una colección completa potencialmente grande.
- El publicador verifica autoridad exacta antes de preparar, reutiliza el commit
  DX2 y mantiene el chequeo del contexto final. El no-op conserva la intención
  de reload pendiente sin escribir ni recargar; la recuperación explícita la
  entrega sin otra reserva. SDD 09 v1.3 concreta esta separación.
- RED compilable: 9 declaraciones/13 invocaciones de publicación y 11/24 del
  preparador. El no-op con reload pendiente demuestra antes de la corrección
  una escritura, cambio de bytes y recarga indebidos; el resto falla por los
  stubs de preparación. El oráculo de presupuesto usa wire textual independiente
  y constantes de aceptación, incluyendo contexto de 32.768 y 32.769 bytes,
  JSON que cabe pero contexto que excede, comillas/controles y portada opcional.
- GREEN y regresión por Xcode MCP `RunAllTests`: **Integration 326/326
  declaraciones, 445 invocaciones; Fast 250/250, 342 invocaciones**. Total
  **576 declaraciones/787 invocaciones**, con las **20/37 nuevas** completas
  según los árboles nativos `.xcresult`. Cero fallos, skips, expected failures
  o runtime warnings. El GREEN focal previo contabilizó 21 invocaciones; la
  prueba completa de parámetros procede de los planes y árboles nativos.
- Xcode MCP oficial: Xcode 27 `27A5252f`, Swift 6.4, scheme MangaLibrary,
  iPhone 17 Simulator/iOS 27 `24A5423a`. Build-for-testing final y logs completos
  sin warnings/errores; Navigator sin diagnósticos. Se conserva Fast activo.
  El script de planes acredita 17 suites Fast y 26 Integration, con filtros y
  partición válidos. El script aprobado `Scripts/validate-docc.sh` usa un
  DerivedData temporal nuevo, docbuild Release para generic iOS y termina con
  archive `.build/docc/MangaLibrary.doccarchive`, cero warnings y errores.
- Revisión iOS independiente final y Audit Swift Source Style de los cuatro
  Swift: sin hallazgos. Se reemplaza el oráculo preliminar `JSONSerialization`
  por wire textual con `JSONEncoder` solo para escapar strings, conservando
  expectativas independientes, antes del RED puro. Los ajustes léxicos quedan
  aplicados y recompilados antes de ambos planes completos y DocC.
- **DX3.2 completo localmente; DX3 queda en 2/5 bloques.** Su commit/push
  quedan pendientes, mientras DX3.1 está publicado; #82/#77 siguen abiertos.
  Siguiente bloque: **DX3.3, portadas y recuperación**, todavía sin iniciar.
  Deluxe mantiene 2/7 subfases entregadas mediante PR, sin declarar su gate.
  Pruebas puras y disco temporal aislado, sin producción o red real.
- Las referencias aún no acreditan JPEGs reales; cuota, integridad y admisión
  pertenecen a DX3.3. Eventos, composición y orden entre proyecciones de la misma
  sesión pertenecen a DX3.4. No cambia UI, esquema, wire, entitlements, App Group,
  targets o `AppComposition.live`. `project.pbxproj` conserva SHA-256
  `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`.
  No hay evidencia nueva de WidgetKit, WCSession, accesibilidad o hardware.

## DX3.1 — proyección persistida — issue #82

- El propietario autorizó implementar únicamente DX3.1 el 6 de septiembre de
  2026. Se reutilizan el [issue #82](https://github.com/JFrancoG/MangaLibrary/issues/82)
  y `codex/82-dx3-reading-projection`, desde `main@c55a88c` limpio. DX1/DX2
  permanecen entregados y el padre #77 abierto; no se amplía este corte a
  DX3.2–DX3.5 ni a entrega Git.
- `CollectionMutationActor.readingProjection(authorization:)` consulta el estado
  comprometido, conserva la autoridad exacta y devuelve todos los candidatos por
  valor. No escribe Colección/outbox, recursos o bridge. Valida solo lectura y
  total, rechaza identidad de presentación incompatible y contexto pendiente,
  abrevia títulos por `Character` y ordena bytes de claves normalizadas con locale
  fijo. SDD 09 v1.2 concreta esta frontera privada sin cambiar wire o esquema.
- RED focal: 17 declaraciones/38 invocaciones fallan por el stub compilable de
  preparación, después de un build sin warnings. `RunSomeTests` rechaza la
  selección desde Integration por la proyección errónea de tags ya caracterizada;
  el RED se ejecuta como selección explícita de esas mismas pruebas desde
  ReleaseGate. No representa la ejecución del gate completo.
- GREEN y regresión: `RunAllTests` en Integration acredita **317/317
  declaraciones y 432 invocaciones**, incluidas las **17 declaraciones/38 casos
  nuevos**. Se comprueba el árbol nativo para asegurar los 2 casos de orden, 6
  transiciones de autorización, 9 estados incompatibles y 8 títulos, además de
  los 13 tests sin parámetros. Fast acredita **239/239 y 318 invocaciones**.
  Ambos `.xcresult` terminan sin fallos, skips, expected failures o runtime
  warnings: **556 declaraciones/750 invocaciones** entre los dos planes.
- El GREEN focal anterior solo contabilizó 18 invocaciones; no se considera
  prueba completa de las variantes. La evidencia completa anterior procede de
  `RunAllTests` y del árbol nativo, no de los agregados `No result` del MCP.
- Xcode MCP: Xcode 27 `27A5252f`, Swift 6.4, iPhone 17 Simulator/iOS 27
  `24A5423a`. Build-for-testing final aprobado y logs completos sin warnings ni
  errores. El único cambio después de Integration fue disponer verticalmente
  cuatro argumentos de un test; se reaudita y recompila antes de Fast/DocC.
- `Scripts/validate-test-plans.sh`: 16 suites Fast y 25 Integration, filtros y
  partición válidos. Fast restaurado como plan del IDE. El script aprobado
  `Scripts/validate-docc.sh` verifica Xcode beta, construye DocC Release para
  generic iOS y genera `.build/docc/MangaLibrary.doccarchive` con cero warnings
  y errores. DocC se limita a la consulta y al contrato privado de la proyección.
- Revisión iOS independiente de código, tests y concreción SDD 09: sin
  hallazgos. Audit Swift Source Style sobre los dos Swift, pasada manual y
  script, cerrado sin hallazgos después del ajuste léxico. `project.pbxproj`
  conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`.
- **Estado al completar DX3.1: completo localmente; DX3 queda en 1/5 bloques y Deluxe en 2/7
  subfases entregadas.** El siguiente bloque es DX3.2, prefijo estable y no-op,
  todavía sin iniciar en ese corte. La publicación posterior de DX3.1 figura arriba. La suite usa
  fixtures sintéticos y SwiftData en memoria; no cambia UI, esquema, wire,
  composición live, recursos, App Group o targets. No valida publicación por
  eventos, conservación física de manifests, WidgetKit/WCSession ni hardware.

## DX2 — bridge durable y seguridad de sesión — issue #79

- El propietario autorizó el siguiente paso tras DX1. Su commit y push previos quedan en `28e167d2975c652288e63572598d9ec95e17d89e`, rama `codex/78-dx1-reading-contract`. El [issue #79](https://github.com/JFrancoG/MangaLibrary/issues/79) es hijo nativo de #77; `codex/79-dx2-durable-bridge` parte de ese commit con árbol limpio. El propietario autoriza el 6 de septiembre de 2026 su entrega completa: commit/push DX2, PR y merge de DX1 seguidos de DX2, cierre de ambos issues y retirada de sus ramas; después, preparación de issue/rama DX3 desde `main`. DX1 se fusionó mediante la [PR #80](https://github.com/JFrancoG/MangaLibrary/pull/80) en `270b287` y #78 está cerrado. DX2 se versiona en `d9ba4d6` y se entrega mediante la [PR #81](https://github.com/JFrancoG/MangaLibrary/pull/81), que cierra #79. El cierre remoto y la preparación posterior de DX3 quedan contrastados en el plan operativo #77.
- `ReadingSnapshot`, `SessionFence` y el codec validan los oráculos DX1, tipos enteros exactos, estados, campos nulos obligatorios, UTF-8 y límite previo de bytes. El presupuesto de 32 KiB incluye el diccionario binary plist. El lector exige dos fences íntegros e idénticos alrededor del manifest.
- El almacenamiento aplica reemplazos atómicos y protección `completeUntilFirstUserAuthentication` a archivos reales de directorios aislados. Un actor centraliza reservas, epoch, publicación, doble comprobación y reintento de reload. Distingue corrupción de indisponibilidad temporal; un no-op no reserva ni recarga y una reserva fallida no se reutiliza.
- `SessionController` integra el publicador opcional: recupera antes de aplicar Keychain, conserva la decisión A1 y verifica el fence antes del borrado condicional. Tras el cierre no permite que fallo o cancelación reautorice la cuenta. Logout, expiración e invalidación comparten retiro seguro y redacción eventual; un Keychain ausente/corrupto también sanea cualquier fence residual.
- La recuperación conserva un único descriptor predecesor de la retirada, sin historial recursivo. El fence canónico distingue crash antes/después del commit incluso al rotar por overflow. Cuenta retirada y destinatario de redacción son independientes: B puede entrar/salir sin publicar mientras A queda pendiente de redactar, y nunca sustituye por una redacción B el contexto que todavía necesita retirar A.
- [SDD 09 v1.1](specs/09-deluxe-reading-contract.md) concreta bytes internos y recuperación, sin añadir autoridad de autenticación. DocC explica únicamente codec, efectos, autorización, idempotencia, cancelación y recuperación; omite propiedades mecánicas y fixtures.

### Evidencia local de DX2 — 2026-09-06

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — preflight y build-for-testing | Proyecto/scheme MangaLibrary, Xcode 27 `27A5252f`, Swift 6.4, iPhone 17 Simulator/iOS 27 build `24A5423a`. Compila app y tests con cero warnings/errores; el log completo se comprueba además del resumen estructurado. |
| Xcode MCP — RED/GREEN | RED compilables antes del codec, publisher y sesión. La revisión añade fallos reproducibles de overflow, contador retrocedido, historia con fence perdido, manifest sobredimensionado y retiro A→B antes/después del fence. Dos RED finales prueban destinatario A tras reload aceptado/fallido; GREEN y regresión completos pasan. |
| Xcode MCP + `.xcresult` — Fast | 239/239 declaraciones y 318 invocaciones aprobadas; cero fallos, skips o runtime warnings. |
| Xcode MCP + `.xcresult` — Integration | 300/300 declaraciones y 394 invocaciones aprobadas; cero fallos, skips o runtime warnings. La suma `239 + 300 = 539` cubre todas las declaraciones Swift Testing; DX2 añade 46 declaraciones y 77 invocaciones. |
| `Scripts/validate-test-plans.sh` | 16 suites Fast y 24 Integration, clasificación exclusiva, filtros, targets y plan predeterminado correctos. Se restaura Fast como plan activo del IDE. |
| `Scripts/validate-docc.sh` | Toolchain explícito de Xcode beta verificado contra el proceso vinculado al MCP; docbuild Release para generic iOS y archive en `.build/docc/MangaLibrary.doccarchive`, cero warnings/errores. No usa la selección CLI global para sustituir el proyecto activo. |
| Revisiones independientes | Revisión iOS de codec/almacenamiento/publicación y de sesión; los hallazgos conductuales se convierten en regresiones. Audit Swift Source Style sobre los once archivos Swift afectados; tras corregir los ajustes léxicos y recompilar, la reauditoría final queda sin hallazgos. |
| Integridad | `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`. Diff y enlaces locales verificados; no cambian targets, entitlements, secretos, test plans, scheme o `AppComposition.live`. |

El preflight de entrega confirma el mismo diff funcional: reauditoría iOS y de
estilo sin hallazgos, build-for-testing final sin warnings/errores y gate estático
aprobado. Se conserva la evidencia runtime y DocC reciente porque después solo
cambiaron ajustes léxicos ya recompilados y documentación de seguimiento.

El resumen nativo `.xcresult` es la autoridad de cardinalidad; los campos agregados
`No result` del bridge incluyen tests excluidos por tags y no se interpretan como
omisiones del plan ejecutado. Las pruebas utilizan datos sintéticos, disco temporal
y efectos controlados; no usan producción. UI/accesibilidad nueva no aplica a este
diff sin Views. No se ejecuta un Deluxe Release Gate ni se revalida hardware.

La conexión de eventos, proyección, recorte y portadas queda en DX3; el App Group
efectivo, los consumidores y WatchConnectivity siguen pendientes. No se ha expuesto
un consumidor live ni usado un directorio privado como sustituto de un App Group.
La matriz física del reloj permanece pendiente y no se rebaja por estos resultados.

## DX1 — contrato de lectura y preparación técnica — issue #78

- El propietario aprobó el plan y autorizó comenzar DX1 el 6 de septiembre de 2026. La planificación se versionó en `954ee37` y se publicó en `codex/77-deluxe-watch-widget`. El [issue #78](https://github.com/JFrancoG/MangaLibrary/issues/78) es hijo nativo de #77; `codex/78-dx1-reading-contract` parte de ese commit con árbol limpio. La planificación y el contrato se incorporaron después a `main` mediante la [PR #80](https://github.com/JFrancoG/MangaLibrary/pull/80), merge `270b287`.
- El propietario aprobó expresamente el contrato concreto DX1 el 6 de septiembre de 2026. La [SDD 09 v1.0](specs/09-deluxe-reading-contract.md) pasa a **Aprobada** y complementa SDD 05 v1.7: selección de lectura, título, orden, capacidad por familia, estados wire, presupuesto de bytes, portadas y preparación de targets. La aprobación no materializa capacidades ni inicia DX2.
- Selección aprobada derivada de Colección: usuario autorizado, entrada activa y tomo actual informado, incluido el último; propiedad/completitud no condicionan lectura. Se aceptan orden por título, 1/hasta 3 mangas en widget, prefijo limitado por 32 KiB con contador, imágenes de hasta 384 px/64 KiB y cuota de 8 MiB con retención de publicados y limpieza de huérfanos demostrados. Son presupuestos propios, no límites atribuidos a Apple.
- El propietario confirma que no dispone de Apple Watch físico. La matriz de SDD 09 permite avanzar con Swift Testing determinista y UI/cache en Simulator; DX5 caracterizará el intercambio de `updateApplicationContext` en una pareja simulada antes de atribuir soporte al runtime. Quedan pendientes pairing, reconexión, suspensión/entrega background y VoiceOver en watchOS físico conforme a SDD 06; el gate Deluxe no se rebaja. Apple exige pareja física en su ejemplo de WatchConnectivity y distingue Inspector de tecnologías de asistencia reales.
- [Contracts/Deluxe](../Contracts/Deluxe/README.md) contiene 16 JSON sintéticos, incluidos 7 escenarios fuente y 2 ejemplos de orden. Python 3 de la sesión verifica lectura JSON, tipos/estados/conteos, exactitud de los enteros extremos, los defectos intencionados de fixtures negativos y cobertura del inventario. Los ejemplos compatibles caben holgadamente en el presupuesto en una medida auxiliar; no es evidencia del encoder Foundation ni de WatchConnectivity.
- Xcode MCP confirmó app/scheme/destino, bundle vigente y templates de widget/watchOS. La instalación vinculada a la única instancia Xcode activa acredita Xcode 27 build `27A5252f`, Apple Swift 6.4 y SDK watchOS 27. `XcodeListRunDestinations` enumera cinco simuladores watchOS 27: SE 3 de 40/44 mm, Series 11 de 42/46 mm y Ultra 3 de 49 mm. Aparecen incompatibles con el scheme iOS actual por plataforma; no acredita pairing o ejecución companion. La plantilla de widget incluye App Intent por defecto y la de watch parte de Watch-only: DX4/DX5 deben resolver esos defaults según el contrato. No se modificaron targets, dispositivos, scheme, plan, destino, entitlements o `project.pbxproj`.
- La revisión independiente del contrato detectó y corrigió reservas espurias al crecer el número de revisión, admisión de portadas fuera del prefijo publicable y retención de huérfanos nunca publicados. El dimensionado usa overhead estable, el no-op se decide antes de reservar y la limpieza exige evidencia de que el recurso nunca fue referenciado. Las reauditorías iOS y de transporte terminaron sin hallazgos pendientes, incluidos los fixtures. La investigación independiente de Simulator contrasta la matriz con fuentes primarias Apple; la revisión final de aprobación, matriz y seguimiento termina sin hallazgos. Estas revisiones no acreditan comportamiento ejecutable.
- Validación proporcional: documentación/fixtures y `git diff --check`; sin código Swift, build, tests del producto, previews, archive DocC ni evidencia física nueva. Audit Swift Source Style no aplica al diff, que no contiene Swift. **DX1 tiene sus criterios documentales satisfechos y el contrato aceptado.** Su commit `28e167d` se entregó mediante la PR #80 y #78 está cerrado. DX2 se implementó posteriormente en #79 y conserva su evidencia y estado actuales en la sección superior.

## Preparación de Deluxe — issue #77

- El [issue #77 — planificar e implementar widget y companion watchOS](https://github.com/JFrancoG/MangaLibrary/issues/77) conserva el plan operativo **Approved**, aprobado por el propietario el 6 de septiembre de 2026, con checklist, dependencias y criterios de cierre de DX1–DX7. Los identificadores DX evitan confundir estas subfases con D1, entregado en el issue #17.
- El propietario autorizó planificar primero, abrir issue y crear rama. `codex/77-deluxe-watch-widget` parte de `main@06170b7`, limpio y coincidente con el remoto, después de verificar el cierre de #75 y la fusión de #76. En ese corte inicial el gate de entrada estaba cumplido, con **0/7 subfases completadas**, y la siguiente unidad era **DX1 — contrato de lectura y preparación técnica**. El estado posterior se registra en el apartado DX1 anterior.
- Xcode MCP oficial confirma `MangaLibrary.xcodeproj`, scheme compartido `MangaLibrary`, plan `Fast`, iPhone 17 Simulator/iOS 27 y únicamente los tres targets Advanced. Issue Navigator no muestra warnings ni errores. Esta preparación no ejecuta builds, tests o previews ni acredita capacidades Deluxe.
- La planificación y el mapa de integración recibieron revisión independiente. Se incluyeron expresamente bloqueo, expiración e invalidación como disparadores de redacción, además de logout. Quedaron para DX1 selección/orden/capacidad de mangas en lectura, identificadores y destino watchOS, límites de recursos y retención de portadas; ya concretados y aprobados en SDD 09. No se han aplicado entitlements ni creado targets.
- README y este registro reconcilian el estado posterior al merge Advanced. La descripción del issue mantiene el plan vivo; este archivo registrará evidencia y el siguiente corte sin duplicar las SDD.
- Tras revisar el plan, el propietario autorizó comenzar DX1 y abrir su issue y rama, con commit y push previos de la planificación cuando resultaran necesarios. #77 pasa a ser el seguimiento general y DX1 tendrá su unidad de ejecución vinculada; las subfases posteriores conservan sus propios gates.

## Advanced Release Gate — issue #75

- El [issue #75 — certificar la versión Advanced](https://github.com/JFrancoG/MangaLibrary/issues/75) partió de `main@aa2e475`, limpio y sincronizado con `origin/main`, en la rama `codex/75-advanced-release-gate`. La matriz manual de las cuatro tecnologías de asistencia quedó completa y la [PR #76](https://github.com/JFrancoG/MangaLibrary/pull/76) se fusionó el 6 de septiembre de 2026 en `06170b7`, con el issue cerrado. Advanced queda aceptado con el alcance de evidencia descrito debajo; Deluxe es una unidad posterior independiente.
- La caracterización reproduce tres warnings externos —uno por target— porque Swift Build construía `ExtractAppIntentsMetadata` aunque el producto no declara App Intents. [ADR 0020](adr/0020-skip-unused-app-intents-metadata-extraction.md) supersede ADR 0011 y fija `LM_SKIP_METADATA_EXTRACTION = YES` en la configuración compartida: la tarea deja de construirse, sin filtrar logs, añadir una capacidad ficticia ni relajar warnings.
- El gate DocC elimina el clasificador y la allowlist temporal. Ahora comprueba el ajuste efectivo en app, unit tests y UI tests para Debug y Release, y falla ante cualquier warning o error.

### Evidencia automatizada actual de #75

| Herramienta y acción | Resultado |
| --- | --- |
| `Scripts/validate-advanced-build.sh` | `ReleaseGate` compila app, unit tests y UI tests en Debug y Release con DerivedData temporal; ambas configuraciones terminan con cero warnings, errores o tareas de metadata de App Intents. Release habilita testabilidad solo como override local para sus imports `@testable`, sin cambiar la configuración distribuida. |
| Xcode MCP — build-for-testing y build ordinario | `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, Xcode 27 build `27A5252f`, Apple Swift 6.4. Ambos aprueban con cero warnings y errores; el log completo no contiene la tarea ni `appintentsmetadataprocessor`. |
| `Scripts/validate-test-plans.sh` | 15 suites `Fast` y 22 `Integration`, clasificación exclusiva, filtros, targets, partición y plan predeterminado válidos. |
| Xcode MCP + `.xcresult` — `Fast` | 224/224 declaraciones, 276 invocaciones, cero fallos, skips o runtime warnings. |
| Xcode MCP + `.xcresult` — `Integration` | 269/269 declaraciones, 359 invocaciones, cero fallos, skips o runtime warnings. `224 + 269` cubre las 493 declaraciones Swift Testing. |
| Xcode MCP + `.xcresult` — `UI` | iPhone: 11/11 aprobados. iPad Air 11-inch (M4): 11/11 aprobados en lotes 1 + 4 + 6 para respetar el timeout de la herramienta. Cero fallos, skips o casos no ejecutados. |
| Xcode MCP + `.xcresult` — `ReleaseGate` | 504/504 declaraciones y 646 invocaciones aprobadas en iPhone 17 Simulator/iOS 27; cero fallos, skips, expected failures o runtime warnings. La acción nativa completó después de que expirase la espera monolítica del bridge. |
| `Scripts/validate-docc.sh` | Archive Release generado con warnings-as-errors, cero warnings y errores y ninguna allowlist. Comprueba `LM_SKIP_METADATA_EXTRACTION = YES` en 3 targets × 2 configuraciones. |
| OpenAPI live, lectura GET | `/docs` responde `200`; el snapshot vivo saneado conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`, idéntico al versionado. No se hicieron llamadas funcionales, credenciales ni escrituras live. |
| Integridad y privacidad | `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`; cero dependencias o entitlements versionados nuevos, cero escapes de concurrencia prohibidos y catálogos válidos sin unidades obsoletas. |

### Adaptación, accesibilidad y límite de aceptación

- Los once recorridos UI pasan tanto en iPhone como en iPad. Las previews actuales inspeccionadas cubren Catálogo, Cuenta, editor de Colección y detalle con combinaciones representativas de Light/Dark, contraste aumentado, orientación, controles resaltados y Dynamic Type Large, XXX Large y AX5. No se observaron solapamientos, truncado funcional ni controles desaparecidos; el contenido de tamaños AX continúa mediante scroll.
- La rama de Reduce Motion permanece implementada y se ha inspeccionado estáticamente, pero una captura no acredita el comportamiento temporal de una animación.
- VoiceOver se ha recorrido manualmente en un iPhone 11 físico con iOS 27 y locale español. Tabs, navegación, rotor, Cuenta, Filtros, detalle, editor y alert nativo conservan nombres, roles, lectura y orden comprensibles. La validación descubrió tres pérdidas de contexto: cierre del editor, cancelación del borrado y estado de los botones Filtros/Lista/Cuadrícula. La corrección restaura el foco a las acciones de origen y expone nombres localizados explícitos para los estados activos; el propietario repitió los tres casos y confirmó el resultado. La apariencia y el tamaño de texto no se variaron dentro de este recorrido VoiceOver y conservan únicamente la evidencia visual automatizada anterior.
- XCUITest verifica de forma independiente que Lista y Cuadrícula intercambian el nombre accesible seleccionado y que aplicar un filtro cambia el nombre a «Filtros activos»; el recorrido focal termina 1/1. Esta prueba protege la semántica expuesta, pero no sustituye la locución manual ya ejecutada.
- Control por voz se ha recorrido manualmente en el mismo iPhone 11 físico, iOS 27 y locale español. Tabs, barra de Catálogo, búsqueda, filtros, lista, detalle, Colección, editor, alert, Cuenta y autenticación responden mediante nombres o la cuadrícula numérica sin acciones dobles ni controles inaccesibles. Algunos títulos propios o ingleses necesitaron «Mostrar números»; el fallback nativo permitió abrirlos y no bloquea el recorrido. Desplazamiento, deslizamiento y cambio de pantalla retiraron sus overlays conforme al comportamiento del sistema.
- Switch Control se ha recorrido manualmente en el iPhone 11 físico, iOS 27 y locale español mediante barrido automático y botón de pantalla completa. El barrido por grupos alcanza tabs, barra, búsqueda y teclado, filtros, mangas, detalle, Colección, editor, confirmación de borrado, Cuenta, login y registro; permite entrar, actuar y salir de cada grupo sin trampas ni omisiones.
- Acceso total con teclado se ha recorrido manualmente en un iPad Pro 11-inch (M5) Simulator con iOS 27 y locale español, usando cursores para navegar, Espacio para activar y Return para finalizar la edición de texto. Shell regular, búsqueda, filtros, lista/detalle, editor, alert y autenticación conservan foco visible y navegación reversible. El recorrido RED descubrió que `.textSelection(.enabled)` convertía el correo autenticado en una trampa direccional que impedía alcanzar Cerrar sesión; tras retirar únicamente esa interacción, el propietario repitió el caso y confirmó que el foco alcanza el botón. El correo continúa disponible como contenido agrupado para VoiceOver.
- La matriz manual vigente queda completa sin extrapolaciones: VoiceOver, Control por voz y Switch Control poseen evidencia en iPhone físico; Acceso total con teclado posee evidencia manual en iPad simulado y no se presenta como prueba de teclado o iPad físicos. Las pruebas y previews automatizadas complementan estos recorridos, pero no los sustituyen.

## Q2 — partición ejecutable de planes estrechos — issue #73

- El [issue #73 — reparar la selección por tags de Fast e Integration](https://github.com/JFrancoG/MangaLibrary/issues/73) parte de `main@ef7336f`, limpio y sincronizado con `origin/main`, en la rama `codex/73-q2-test-tag-discovery`. La implementación se versiona en `4c98a7c` y se entrega mediante la [PR #74](https://github.com/JFrancoG/MangaLibrary/pull/74).
- La caracterización corrige el diagnóstico histórico: el editor nativo de Xcode incluye 224 de 493 declaraciones en `Fast`, y `RunAllTests` sí aplica los tags heredados de `@Suite`. El campo `isEnabled` de `GetTestList` continúa proyectando 0 habilitadas y no representa la selección que ejecuta el plan.
- El diagnóstico mínimo con un tag directo y la prueba de escribir `.fast` en el plan no repararon esa proyección y se retiraron por completo. La forma nativa correcta continúa siendo `.tags(.fast)` o `.tags(.integration)` en la suite y `fast` o `integration` en Include Tags.
- SDD 06 v1.33 establece el `.xcresult` del runner nativo como autoridad de cardinalidad runtime. El nuevo `Scripts/validate-test-plans.sh` cerca la configuración estática: clasificación exclusiva en cada una de las 37 suites, ausencia de duplicación en tests, filtros exactos, targets completos de `UI` y `ReleaseGate` y `Fast` predeterminado.

### Caracterización y validación local de #73

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — `GetTestList` | Reproduce 0 habilitadas y 493 deshabilitadas en ambos planes. Se conserva como limitación del bridge para tags heredados, no como resultado del runner. |
| Xcode nativo — editor de plan | `Fast` muestra 493 declaraciones: 224 incluidas y 269 excluidas. Las filas proyectan el tag heredado `fast`. |
| Xcode MCP + `.xcresult` — `Fast` | `RunAllTests` termina sin fallos; el resumen nativo acredita 224/224 declaraciones aprobadas y 276 invocaciones tras expandir parámetros. |
| Xcode MCP + `.xcresult` — `Integration` | `RunAllTests` termina sin fallos; el resumen nativo acredita 269/269 declaraciones aprobadas y 359 invocaciones tras expandir parámetros. La suma `224 + 269` cubre exactamente las 493 declaraciones. |
| RED/GREEN del gate estático | Sin tag en una suite falla con su archivo y línea; derivar el filtro de `Fast` a `integration` falla con la clave y los valores esperado y real. Restaurada la configuración, aprueban 15 suites `Fast`, 22 `Integration`, filtros, targets, partición exclusiva y plan predeterminado. |
| Xcode MCP — build | El build-for-testing de `Fast` aprueba en 6,805 s sin errores estructurados. El log conserva dos emisiones externas exactas de `appintentsmetadataprocessor`, una por cada target construido, acotadas por ADR 0011; no aparecen warnings de Swift o Clang. |

Q2 no modifica tests ni comportamiento de producto, no añade targets o
dependencias y no certifica por sí solo la candidata Advanced. El propietario
autorizó expresamente commit, push, PR, fusión, cierre del issue y retirada de
la rama; esa entrega no inicia Deluxe ni sustituye el Advanced Release Gate.

## A1 — logout con operaciones pendientes — issue #71

- A1 se entrega mediante la [PR #72](https://github.com/JFrancoG/MangaLibrary/pull/72), que cierra el [issue #71 — completar logout con operaciones pendientes](https://github.com/JFrancoG/MangaLibrary/issues/71). La rama `codex/71-a1-pending-outbox-logout` partió de `main@a1f203e`, limpio y sincronizado con `origin/main`.
- SDD 04 v1.27 y SDD 06 v1.32 cierran la semántica antes de implementarla. `queued`, `sending`, `retry`, `blockedAuth`, `blockedOutcome` y `rejected` exigen una decisión; `confirmed` no. Cada intento obtiene una capacidad de logout nueva, ligada a usuario, generación e identidad de credencial, mientras las mutaciones ordinarias permanecen suspendidas.
- El primer intento con trabajo pendiente reactiva la sesión y rota la cerca. Cuenta presenta un alert nativo localizado con las decisiones «mantener la sesión» o «descartar en este dispositivo y cerrar sesión»; esperar conserva sesión, Keychain, navegación, selección, Colección y outbox, permite que R2 continúe el trabajo automatizable y deja accesible la revisión que requiera una decisión.
- El descarte explícito vuelve a consultar bajo una cerca nueva y ejecuta una única transacción SwiftData. Cada entrada retorna a `confirmedState` o se elimina si nunca tuvo base remota; no intenta deshacer un efecto que ya pudiera existir en la nube. Todas las intenciones reproducibles de la pareja desaparecen y la secuencia máxima se conserva como cursor `confirmed`, con retry y deadline limpiados, para que la siguiente mutación continúe en `max + 1`.
- Keychain solo se elimina después de confirmar ausencia de pendientes o completar el descarte. Un fallo o cancelación de la transacción revierte el store completo y no inicia el borrado; la presentación distingue ese fallo de Colección del almacenamiento seguro de credenciales y deriva aparte si la sesión continúa activa o ha expirado. Un fallo Keychain posterior conserva el envelope sin resucitar cambios ya descartados y solo reactiva la sesión mientras el JWT siga vigente. Otra cuenta, una generación obsoleta o un efecto tardío no pueden inspeccionar ni modificar la partición vigente.

### RED/GREEN y validación local de #71

| Herramienta y acción | Resultado |
| --- | --- |
| RED/GREEN focal | El primer build-for-testing falló únicamente por las capacidades A1 todavía ausentes. Tras implementarlas, las suites focales de persistencia, sesión y presentación cubren todos los estados pendientes, ausencia de base, cursor máximo y `max + 1`, aislamiento de otro usuario, capacidades obsoletas, fallo y cancelación con rollback, exclusión A→B, expiración concurrente, fallo Keychain posterior al descarte y cancelación antes de presentar una decisión abandonada. La repetición ampliada termina 121/121. |
| Xcode MCP — `ReleaseGate` Swift | El inventario final habilita 504 declaraciones y ninguna deshabilitada. La selección completa de las 493 declaraciones de `MangaLibraryTests` expande 520/520 ejecuciones aprobadas, sin fallos, skips, expected failures ni casos no ejecutados. Usa stores, reloj, transporte y Keychain sintéticos o aislados; no usa producción. |
| Xcode MCP — `ReleaseGate` UI | Los once recorridos terminan 11/11, divididos en 1 + 4 + 6 para permanecer dentro del límite de 300 s de la herramienta oficial. El nuevo recorrido abre un detalle local pendiente, solicita logout, conserva la selección al mantener la sesión y después confirma el descarte y el estado `signedOut`; tras precisar que el descarte afecta al dispositivo y no revierte la nube, ese recorrido vuelve a aprobar 1/1. La llamada monolítica caducó por timeout y no se contabiliza como evidencia. |
| Xcode MCP — build y diagnósticos | `BuildProject(buildForTesting: true)` y el build ordinario aprueban sin errores estructurados. Sus logs completos conservan únicamente las emisiones externas de `appintentsmetadataprocessor` ya acotadas por ADR-0011; no aparecen warnings de Swift o Clang. Los diez Swift de producto modificados o añadidos devuelven 0 diagnósticos al refrescar explícitamente el Issue Navigator. Proyecto `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, destino iPhone 17 Simulator/iOS 27; la validación usa `ReleaseGate` y Xcode queda restaurado al plan `Fast`. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas aprobados; archive Release generado con warnings DocC como errores y únicamente la emisión externa exacta acotada por ADR-0011 para Xcode 27 build `27A5252f`. El archive permanece local y no se publica. |
| Preview y accesibilidad estática | El copy y las acciones compartidos por el alert se renderizan de forma editorial y determinista con `CollectionPreviewModifier`: Large/en y XXX Large/es muestran el contenido completo; AX5/es lo conserva en una estructura desplazable anclada arriba. El alert nativo y su cableado se ejercen en el recorrido UI. No sustituye tecnologías de asistencia ni hardware. |
| Localización e integridad | `Localizable.xcstrings` conserva 243 claves, 243/243 traducciones españolas y 0 entradas sin estado `translated`; las cuatro claves del alert A1 comparten una única fuente entre alert y preview y el fallo de persistencia de Colección posee copy seguro propio. `git diff --check` queda limpio y el alcance no contiene GCD, `Task.detached` ni escapes de concurrencia prohibidos. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76` y OpenAPI conserva `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no cambian esquema, dependencias, entitlements ni configuración. |
| Revisiones independientes | Las auditorías iOS/datos/concurrencia y SwiftUI/accesibilidad quedan sin hallazgos materiales tras cerrar cancelación, rollback, dependencias obligatorias de composición, navegación, desacoplamiento del copy y preview determinista. El audit `swift-source-style` inspecciona los 17 Swift del alcance; los candidatos restantes son closures/cadenas justificadas o código preexistente fuera del hunk. |

### Límites y estado de A1

No se ejecutaron VoiceOver, Voice Control, Switch Control, Acceso total con
teclado, Accessibility Inspector, RTL, iPad físico ni landscape. Tampoco se
llamó al backend, se usó una cuenta o Keychain live ni se realizó una escritura
de producción. La evidencia demuestra las invariantes locales, el alert y el
recorrido hermético, pero no certifica aún el Advanced Release Gate global. La
regresión independiente de descubrimiento de tags de `Fast` e `Integration`
permanece fuera de #71. La PR #72 entrega A1, cierra el issue y permite retirar
la rama de trabajo; no inicia la certificación global ni el siguiente corte.

## R2.4 — resolución interactiva de resultados inciertos — issue #69

- El [issue #69 — implementar resolución interactiva de `blockedOutcome`](https://github.com/JFrancoG/MangaLibrary/issues/69) se versiona en `a84b9d3` y se entrega mediante la [PR #70](https://github.com/JFrancoG/MangaLibrary/pull/70). La rama `codex/69-r2-4-blocked-outcome-resolution` parte de `main@c782f11`, limpio y sincronizado con `origin/main`.
- SDD 01 v1.9, SDD 03 v1.6, SDD 04 v1.25 y SDD 06 v1.30 cierran la semántica antes de implementarla. Cada revisión parte de un GET individual fresco; un primer `401` recupera la credencial y reintenta una vez, mientras `403`, segundo `401`, red, persistencia o payload incompatible conservan sesión, Keychain, Colección y bloqueo sin ofrecer decisiones engañosas.
- La pantalla compara la versión de este dispositivo con una presencia remota compatible o una ausencia `404`. Antes de decidir repite el GET y exige que coincida la evidencia completa, incluido el snapshot del manga. Aceptar nube realiza cero escrituras; conservar dispositivo confirma N y solo ante divergencia sin N+1 crea una operación `queued` nueva, con UUID y secuencia propios. La operación incierta nunca se reencola ni se repite.
- La resolución SwiftData es atómica y queda cercada por autoridad, usuario, manga, UUID, secuencia, retry, estado, payload y evidencia. Cancelación, operación obsoleta, UUID duplicado, overflow o fallo de guardado revierten Colección y outbox conjuntamente. Si existe N+1, su estado visible y su operación se preservan bit a bit, no se crea N+2 y el cambio durable del subconjunto `blockedOutcome` despierta el pipeline R1→R2 propiedad del shell.
- Cuenta deriva el aviso y la lista directamente de la outbox, incluye tombstones y mantiene separados el aviso durable y cualquier fallo transitorio R1. El flujo ofrece estados localizados de carga, presencia, ausencia, incompatibilidad y fallo, confirmación nativa proporcional y resúmenes de total conocido o desconocido; no muestra UUID, secuencias ni terminología interna.

### RED/GREEN y validación local de #69

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing y stores reales | Las regresiones focales cubren adopción remota presente/ausente, conservación local, efecto ya demostrado, N+1 preservada y procesada exactamente una vez por el worker real, todas las cercas persistidas, segunda lectura cambiante, aislamiento de usuario/manga, UUID duplicado, overflow, relanzamiento, cancelación y rollback. Los coordinadores cubren `401` con una sola recuperación, segundo `401`, `403`, incompatibilidad y reemplazo de sesión. Usan `ModelContainer` aislado, loaders/JWT sintéticos y cero red o datos live. |
| Xcode MCP — `Fast` | La ejecución final sobre la forma actual descubre 527 resultados: 491 aprobados, 0 fallos y 36 no ejecutados por la selección del plan. |
| Xcode MCP — `Integration` | 559 resultados: 538 aprobados, 0 fallos y 21 no ejecutados por la selección del plan. |
| Xcode MCP — `UI` | Los diez recorridos aprobados terminan 10/10. Se ejecutan en dos lotes de cinco para permanecer dentro del límite de 300 s de la herramienta oficial; no dependen de red, Keychain, cuenta ni disco live. |
| Xcode MCP — `ReleaseGate` | La selección Swift completa expande 542/542 resultados aprobados y los dos lotes UI añaden 5/5 + 5/5. El gate acumulado queda en 552/552, sin fallos, skips, expected failures ni casos habilitados sin ejecutar; se registra en tres llamadas acotadas porque la llamada monolítica excedió el timeout de la herramienta, no por un fallo del producto. |
| Xcode MCP — build y diagnósticos | `BuildProject(buildForTesting: true)` final aprobado en 0,120 s. El build log estructurado contiene 0 warnings y 0 errores; los 15 Swift de producto modificados o añadidos devuelven 0 diagnósticos al refrescar explícitamente el Issue Navigator. Proyecto `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, destino iPhone 17 Pro Simulator/iOS 27; el plan activo se restaura a `Fast`. |
| `Scripts/validate-docc.sh` | Los ocho escenarios deterministas del clasificador aprueban y el archive Release se genera con warnings DocC como errores. Solo aparece la emisión externa exacta de `appintentsmetadataprocessor` acotada por ADR-0011 para Xcode 27 build `27A5252f`; el archive permanece local y no se publica. |
| Previews y accesibilidad estática | Se inspeccionan lista, fallo, remoto presente y ausente, N+1 y total desconocido en español, Light/Dark y Dynamic Type Large, XXX Large y AX5 sobre iPhone 17 Pro/iOS 27. El contenido permanece desplazable y las acciones conservan nombre y jerarquía. Es evidencia estática: no sustituye tecnologías de asistencia ni hardware. |
| Localización e integridad | `Localizable.xcstrings` conserva 238 claves base, traducción española para las 238 y 0 stale. `git diff --check` queda limpio; no aparecen GCD, `Task.detached` ni escapes de concurrencia prohibidos. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76` y OpenAPI conserva `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no cambian esquema, dependencias, entitlements ni configuración. |
| Revisiones independientes | Las revisiones iOS/datos/concurrencia y SwiftUI/accesibilidad quedan sin hallazgos abiertos tras cercar el wake durable, comparar el snapshot remoto completo, completar las cercas, hacer alcanzable el fallo en AX5, exponer el total remoto y añadir la preview de total desconocido. El audit final `swift-source-style` inspecciona los 21 Swift reales del diff y queda sin hallazgos tras 55 ajustes exclusivamente léxicos; los once candidatos restantes son construcciones justificadas o código preexistente fuera del hunk. |

### Límites y estado de entrega

No se ejecutaron VoiceOver, Voice Control, Switch Control, Acceso total con
teclado, Accessibility Inspector, iPad físico, landscape, RTL ni contraste
aumentado runtime. Tampoco se llamó al backend, se inició sesión, se usó
Keychain live ni se realizó una escritura de producción: la evidencia demuestra
el flujo hermético y su atomicidad, pero no caracteriza una nueva respuesta del
servicio real. La primera transición a `blockedOutcome` puede provocar un GET R1
redundante e inocuo al cambiar la identidad durable observada por el shell; no
repite POST/DELETE ni forma un ciclo. La fusión de la PR #70 cierra el issue #69;
el cierre autorizado incluye retirar después la rama local y remota una vez
comprobado que sus commits son ancestros de `main`.

## R2.3 — recuperación automática de outbox — issue #67

- El [issue #67 — implementar recuperación automática de outbox](https://github.com/JFrancoG/MangaLibrary/issues/67) se abrió como unidad posterior y separada de #57/#60. La rama `codex/67-r2-3-outbox-recovery` parte de `main@d79994017f80`, limpio y sincronizado con `origin/main`; la implementación se versiona en `b79b5fc` y se entrega mediante la [PR #68](https://github.com/JFrancoG/MangaLibrary/pull/68).
- SDD 04 v1.24 cierra la clasificación conservadora de R2.3. Solo una señal positiva de una frontera caracterizada que pruebe que el transporte no comenzó permite `retry`. La composición live no dispone hoy de esa señal: timeout, pérdida de respuesta, conexión perdida, respuesta no HTTP, payload inválido, divergencia reconciliada y status no caracterizados mantienen la reconciliación R2.2 y terminan en `blockedOutcome` si no confirman el efecto deseado.
- El backoff persistido usa 1, 2, 4, 8, 16 y un máximo de 30 segundos, reloj inyectable y espera estructurada cancelable. Un deadline futuro no bloquea otra pareja accionable; relanzar, despertar o sustituir un vuelo exige volver a cercar usuario, generación, UUID, secuencia y autorización antes de enviar.
- La pérdida confirmada de autoridad puede bloquear `queued` y `retry` del usuario sin degradar una `sending` incierta. Solo R1 seguido de una sesión válida del mismo UUID reactiva `blockedAuth → queued`; por manga conserva la intención bloqueada de mayor secuencia y retira las anteriores, todas inequívocamente no enviadas, para mantener una sola cola coalescible. Otra identidad o una generación obsoleta no modifica ni envía esas operaciones.
- La excepción histórica de R1 permite además que una tombstone N+1 avance cuando toda la cadena es inequívocamente no enviada (`blockedAuth`, `queued` o `retry`): la presencia remota incompatible queda opaca y la recuperación retira el POST N antes de reclamar únicamente el DELETE. Cualquier predecesora incierta sigue rechazando el snapshot completo.
- `rejected` queda reservado a una clasificación positiva inyectada o a un contrato futuro ya caracterizado. La reversión restaura de forma atómica una base presente o ausente, recupera una entrada tras rechazar su tombstone y conserva N+1 visible; ningún status o body no publicado activa esta ruta por conveniencia.
- Una edición o eliminación durante backoff coalesce la operación `retry` conservando UUID y avanzando secuencia, pero elimina contador y deadline obsoletos. Si N aún estaba `sending` cuando apareció N+1 y después se acredita que N no salió, la transacción retira N; el log seguro se emite después y distingue la programación real del backoff de esa supersesión.
- La expiración entre una validación rápida y la reserva del vuelo o cualquier commit SwiftData vuelve a pasar por Sesión. La gate impide el efecto, el envelope se retira y el observer convierte únicamente trabajo inequívocamente no enviado en `blockedAuth`; la cancelación posterior a evidencia pre-envío no puede impedir su commit local.

### RED/GREEN y validación local de #67

| Herramienta y acción | Resultado |
| --- | --- |
| RED/GREEN focal | El primer build-for-testing falló por las capacidades R2.3 todavía ausentes. Las regresiones añadidas hicieron visibles de forma separada la coalescencia durante backoff, N `sending` frente a N+1, expiración en las fronteras de sesión, recuperación histórica segura y persistencia de retry tras recrear actor/coordinador. Cada caso aprobó tras su corrección; la resolución `scheduled`/`superseded` quedó además comprobada tras mover la observabilidad al commit real. |
| Xcode MCP — suites focales | Las diez suites afectadas ejecutaron 247/247 invocaciones aprobadas, sin fallos, skips, expected failures o casos no ejecutados. Focos posteriores aprobaron 5/5 para expiración y `.retry`, 1/1 para sustitución concurrente durante la espera, 13/13 para retry, supersesión y backoff, y 2/2 para el reloj explícito y la cancelación end-to-end después de acreditar pre-envío. Usan reloj y transporte inyectados y SwiftData real aislado; no usan sleeps temporales, cuenta, JWT, Keychain, red ni producción. |
| Xcode MCP — `ReleaseGate` | El primer intento quedó en 554/559 por una fixture inválida que asignaba `nextRetryAt` a estados distintos de `.retry`; no reveló un defecto de producto. Corregida la fixture y cerrados los hallazgos, el gate monolítico final aprobó 574/574 sobre iPhone 17 Simulator con iOS 27, sin fallos, skips, expected failures o casos no ejecutados. |
| Xcode MCP — builds y diagnósticos | `BuildProject(buildForTesting: true)` final aprobado en 5,817 s y build ordinario aprobado en 1,596 s, ambos sin errores estructurados. Los ocho archivos Swift de producto afectados devuelven 0 diagnósticos en la actualización explícita del Issue Navigator. Proyecto `MangaLibrary.xcodeproj`, scheme `MangaLibrary`. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas aprobados; archive Release generado con warnings DocC como errores y únicamente la emisión externa exacta acotada por ADR-0011 para Xcode 27 build `27A5252f`. El archive permanece local y no se publica. |
| Integridad y alcance | `git diff --check` queda limpio. Los escaneos no encuentran `Task.detached`, GCD, `@preconcurrency`, `@unchecked Sendable` ni `nonisolated(unsafe)` en el alcance. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76` y OpenAPI versionado conserva `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no cambian esquema, dependencias, entitlements ni configuración. |
| Revisiones independientes | Las auditorías iOS/datos/concurrencia y de carreras no dejan hallazgos P0–P2. Sus P1 intermedios de coalescencia, cancelación y expiración se cerraron con regresiones; los P3 de sustitución durante espera y log previo al commit también se corrigieron. La auditoría final `swift-source-style` inspecciona los 18 Swift reales del cambio —17 modificados rastreados y un test nuevo sin seguimiento— y queda limpia tras aplicar ajustes exclusivamente léxicos. |

La fusión de la PR #68 cierra el issue #67 y el cierre autorizado incluye retirar después la rama local y remota una vez comprobado que sus dos commits son ancestros de `main`.

### Fuera de alcance de #67

Permanecen fuera la acción manual y resolución interactiva de `blockedOutcome` de R2.4, el logout con operaciones pendientes, un scheduler de background o `BGTask`, conflictos generales multi-dispositivo, dependencias, cambios de esquema, entitlements, App Group, WidgetKit, watchOS, pruebas live y el cierre global de Advanced. La composición live sigue clasificando todo error real de `URLSession` como potencialmente aplicado porque el backend no publica una señal positiva de fase pre-envío o rechazo permanente; por tanto, esas rutas solo se caracterizan mediante fronteras deterministas inyectadas y no se activan por conveniencia en producción.

## Diferenciación de pestañas y controles de tomos — issue #65

- El [issue #65 — diferenciar Catálogo y mejorar los controles de tomos](https://github.com/JFrancoG/MangaLibrary/issues/65) se abrió sin issue, PR o rama duplicados. La rama `codex/65-distinct-tabs-volume-controls` parte de `main@15458ed3ace4bc3f3e826ed6aa3e5a351c2cc27a`, limpio y sincronizado con `origin/main`; la implementación se versiona en `6f9f90f` y se entrega mediante la [PR #66](https://github.com/JFrancoG/MangaLibrary/pull/66).
- SDD 01 v1.8 diferencia Catálogo mediante `magnifyingglass` y conserva `books.vertical.fill` para la biblioteca personal. No cambia el orden, la selección ni la navegación de las tres pestañas.
- SDD 03 v1.5 y SDD 06 v1.27 concretan para el editor sin total conocido controles SwiftUI nativos, bordeados y circulares: `plus` para añadir y `trash` con rol y color destructivos para retirar. Ambos declaran un mínimo de `44 × 44 pt` y nombres localizados equivalentes a «Añadir tomo» y «Eliminar tomo N».
- `CollectionEditorView` reutiliza la única ruta semántica de borrador existente. El cambio es exclusivamente presentacional: no modifica validación, persistencia, SwiftData, outbox, R1/R2, sesión, red, navegación, dependencias, proyecto ni entitlements.
- El String Catalog reutiliza `Add volume` y `Remove volume %lld` y retira la clave ya huérfana `Add`; Xcode reordenó mecánicamente varias entradas al actualizar su estado, pero la comparación JSON canónica confirma que no cambió ningún otro texto o traducción.

### Validación local de #65

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | `BuildProject(buildForTesting: true)` final aprobado en 6,566 s sobre iPhone 17 Pro/iOS 27. El build log estructurado contiene 0 warnings o errores y el full log conserva las tres emisiones exactas de `appintentsmetadataprocessor` esperadas por target y acotadas por ADR-0011; no hay warnings de Swift, Clang o DocC. `MainShellView.swift` y `CollectionEditorView.swift` devuelven 0 diagnósticos. Proyecto `MangaLibrary.xcodeproj`, scheme `MangaLibrary`. |
| Xcode MCP — previews | El shell se renderizó e inspeccionó en español, Light, Dynamic Type Large y Control Borders visible sobre iPhone 17 Pro/iOS 27: Catálogo muestra la lupa y Colección los libros. El editor sin total conocido se inspeccionó en iPhone en Large, XXX Large oscuro y AX5 con contraste aumentado; los controles se mantienen íntegros en Large y XXX Large, mientras AX5 conserva la cabecera y deja los controles fuera del primer viewport de la estructura desplazable. También se renderizaron el shell y el editor en iPad Pro 13-inch (M5). Es evidencia visual estática, no demuestra un gesto, una medición runtime ni tecnologías de asistencia. |
| Xcode MCP — UI | La regresión que había fallado en el gate aprobó 1/1 de forma focal. El plan `UI` completo aprobó 8/8, sin fallos, skips, expected failures o casos no ejecutados. |
| Xcode MCP — `ReleaseGate` | El último gate monolítico sobre la forma final concisa de `Tab` quedó en 522/523: falló únicamente el primer `waitForExistence` de `tab.account` en `testCatalogDetailSavesAndDeletesMangaFromCollection`; la misma prueba aprobó focalmente y dentro de `UI` 8/8. Otro intento de proyectar el identificador desde una etiqueta personalizada produjo el mismo 522/523 y no se conservó. El artefacto final demuestra que la app, Catálogo y las tres pestañas ya estaban completamente renderizados, pero SwiftUI no expuso ningún `tab.*` al árbol accesible de ese lanzamiento. Por tanto, el `ReleaseGate` no se declara limpio y no se repite hasta ocultar la señal. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas aprobados; archive Release generado con warnings DocC como errores y únicamente la emisión externa exacta acotada por ADR-0011 para Xcode 27 build `27A5252f`. El archive permanece local y no se publica. |
| Localización e integridad | `Localizable.xcstrings` conserva 184 claves activas, 184/184 traducidas en inglés y español y 0 stale. `git diff --check` queda limpio; `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76` y OpenAPI conserva `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`. |
| Revisiones independientes | Las auditorías finales iOS/SwiftUI/accesibilidad, `swift-source-style` y gobernanza no encuentran hallazgos P0–P3 atribuibles al diff. El audit de estilo inspecciona los dos Swift modificados y obtiene 0 candidatos multilinea. Las revisiones conservan como límite explícito el `ReleaseGate` 522/523 y no lo reinterpretan como aprobado. |

### Límites y estado de entrega

No se ejecutaron VoiceOver, Voice Control, Switch Control, Acceso total con
teclado o Accessibility Inspector. El Xcode MCP exigió una skill de interacción
con dispositivo que no está instalada, por lo que el mínimo `44 × 44 pt` queda
acreditado por el código y la inspección de previews, no por una medición directa
del árbol runtime; los nombres EN/ES se verificaron en código y String Catalog,
pero tampoco se escucharon ni inspeccionaron en runtime. Tampoco se llamó al
backend ni se usaron cuenta, Keychain, datos o hardware reales. La fragilidad
intermitente de los identificadores
`tab.*` afecta a la automatización inicial del `TabView`; el artefacto descarta
un crash, una pantalla sin montar o la ausencia visual de Cuenta, pero no permite
declarar limpio el gate global. La fusión de la PR #66 cierra el issue #65 y el
cierre autorizado incluye retirar después la rama local y remota.

## Cota global de 300 números de tomo — issue #63

- El [issue #63 — fijar en 300 el máximo global de tomos](https://github.com/JFrancoG/MangaLibrary/issues/63) parte de la deuda transversal identificada al entregar R1. La rama `codex/63-max-300-collection-volumes` parte de `main@53e6b0c5afba`, limpio y sincronizado con `origin/main`; la implementación se versiona en `71f8682` y se entrega mediante la [PR #64](https://github.com/JFrancoG/MangaLibrary/pull/64).
- La decisión de producto del 3 de septiembre de 2026 fija `300` como máximo inclusivo para total conocido, tomos en propiedad y volumen de lectura. `nil` conserva exclusivamente la semántica de total editorial desconocido y no relaja la cota de los números individuales.
- SDD 03 v1.4 y SDD 04 v1.23 exigen validar antes de materializar rangos, rechazar R1 atómicamente sin afectar sesión y detener R2 antes del claim o transporte. Un estado histórico incompatible se conserva sin truncado ni edición o POST; una eliminación explícita puede crear y enviar una tombstone porque DELETE solo transporta `Manga.ID`.
- `CollectionVolumePolicy` es la única representación de `1...300`, la comprobación de pertenencia, el total conocido compatible y la construcción acotada de una colección completa. Catálogo rechaza un total explícito fuera de rango antes de proyectarlo; `nil` continúa siendo desconocido. Editor, mutación atómica, R1 y R2 reutilizan la misma política y errores tipados, sin dependencias, cambios de esquema, proyecto, entitlements u OpenAPI.
- El editor no construye rangos a partir de un total incompatible. Conserva los valores históricos, bloquea la edición y Guardar, mantiene disponible la eliminación explícita y presenta un mensaje localizado. Cuenta conserva la sesión ante datos de volumen incompatibles de R1 o R2 y muestra un aviso neutral que no pide autenticarse de nuevo.
- R1 valida el lote completo antes de mutar. La única excepción es la presencia opaca de una fila incompatible que coincide con la primera tombstone exacta procesable: no importa sus valores ni confirma ausencia y conserva la entrada bruta para R2. Una tombstone `queued` puede enviar DELETE; una `sending` usa esa presencia para persistir `blockedOutcome` sin adoptar la base inválida ni repetir el borrado. Una operación anterior bloqueada impide la excepción y mantiene el rechazo atómico.

### RED/GREEN y validación local de #63

| Herramienta y acción | Resultado |
| --- | --- |
| RED/GREEN del caso histórico incierto | Las dos regresiones finales fallaron inicialmente 0/2: R1 devolvía `knownTotalExceedsMaximum(301, 300)` antes de la tombstone N+1 y una tombstone `sending` convertía la presencia 301 en `persistenceConflict`. Tras la excepción contextual aprobaron 2/2; el foco ampliado aprueba 3/3 e incluye una operación anterior bloqueada que no permite la excepción. |
| Xcode MCP — suites focales | 148 declaraciones seleccionadas de los nueve archivos de test afectados produjeron 157 invocaciones aprobadas, 0 fallos, skips, expected failures o casos no ejecutados. Cubren Catálogo, editor, cliente POST, mutación, persistencia/reapertura, transiciones R2, importación y coordinación R1. |
| Xcode MCP — `ReleaseGate` | Repetición monolítica final posterior al ajuste presentacional del aviso: 523/523 aprobados en iPhone 17 Simulator con iOS 27, 0 fallos, skips, expected failures o casos no ejecutados. El inventario previo confirmó 403 declaraciones habilitadas y ninguna deshabilitada; los casos parametrizados elevan el recuento de resultados. |
| Xcode MCP — build y diagnósticos finales | `BuildProject(buildForTesting: true)` repetido tras reubicar el aviso y aprobado en 7,694 s; 0 errores o warnings estructurados. El Issue Navigator devuelve 0 issues con severidad warning o superior. Proyecto `MangaLibrary.xcodeproj`, scheme `MangaLibrary`. |
| Planes estrechos | La regresión conocida de descubrimiento de tags permanece: `Fast` e `Integration` enumeran 395 declaraciones pero habilitan 0. No se presentan como gates aprobados; las suites se ejecutaron por identificador y dentro de `ReleaseGate`. Xcode queda restaurado al plan predeterminado `Fast`. |
| Xcode MCP — previews y recorrido UI | El aviso de Cuenta y el editor histórico realmente persistido se renderizaron sin errores en español, tamaños normal, XXX Large y AX5 sobre iPhone 17 Pro/iOS 27. El editor con total desconocido se repitió en español, modo oscuro, Large, XXX Large y AX5. Un recorrido hermético introdujo `301` y verificó en runtime el orden campo → aviso → `Tomo 1`: el valor no se añadió y el mensaje quedó dentro de la misma celda, inmediatamente bajo el campo y antes del listado. El contenido seguía siendo desplazable y no mostró truncados o solapamientos. Es evidencia visual de preview y simulador, no de tecnologías de asistencia. |
| `Scripts/validate-docc.sh` | Repetido sobre el snapshot final: ocho escenarios deterministas aprobados; archive Release generado con warnings DocC como errores y únicamente la emisión externa exacta acotada por ADR-0011 para Xcode 27 build `27A5252f`. El archive permanece local y no se publica. |
| Localización e integridad | `Localizable.xcstrings` conserva 185 claves activas, 185/185 traducidas en inglés y español y 0 stale. `git diff --check` queda limpio; los escaneos no encuentran escapes de concurrencia ni logs de secretos. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76` y OpenAPI conserva `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`. |
| Revisiones independientes | Las reauditorías finales iOS/datos/concurrencia, SwiftUI/accesibilidad y `swift-source-style` cierran sin hallazgos P0–P3. El P1 intermedio de la fila 301 remota se cerró con presencia opaca exacta y tres regresiones; dos comentarios DocC demasiado absolutos se matizaron y el audit final de estilo quedó limpio. |

### Límites y estado de entrega

No se llamó al backend, no se realizó ninguna escritura live y no se usaron
cuentas, JWT o Keychain reales. Tampoco se ejecutaron VoiceOver, Voice Control,
Switch Control, Acceso total con teclado o Accessibility Inspector ni se extrapola
su cobertura desde previews. Retry/backoff y la resolución interactiva de
`blockedOutcome` permanecen fuera de #63. La fusión de la PR #64 cierra el issue
#63 y el cierre autorizado incluye retirar después la rama local y remota.

## Detalle de Colección coherente en iPad — issue #61

- El [issue #61 — actualizar el detalle seleccionado de Colección en iPad](https://github.com/JFrancoG/MangaLibrary/issues/61) parte de la captura live donde la fila seleccionada mostraba 23 tomos y lectura 3, mientras el panel estable del mismo manga conservaba los tomos 1, 2, 3, 4 y 8 y lectura 2. La rama `codex/61-ipad-collection-detail-sync` partió de `main@6a650a4`; la implementación se versiona en `d786ba8` y se entrega mediante la [PR #62](https://github.com/JFrancoG/MangaLibrary/pull/62). Su fusión cierra #61 y el cierre autorizado incluye retirar la rama local y remota.
- La causa estructural queda demostrada: `CollectionUserRootView` ya poseía el `@Query` que alimenta fila y selección, pero `CollectionEntryDetailView` descartaba ese `state` en la rama con snapshot y montaba `CollectionControlsView`, que ejecutaba otro `@Query` para la misma pareja usuario + manga. El iPad podía presentar dos proyecciones observables dentro del mismo `NavigationSplitView`. La fila actualizada y el único `ModelContainer` descartaban una falta global de persistencia.
- La raíz proyecta ahora `mangaID`, `CollectionMangaSnapshot` y `CollectionSnapshot` por valor hacia el detalle. `CollectionControlsContentView` presenta ese valor y genera desde él el seed de una apertura posterior del editor, sin SwiftData ni estado persistente duplicado. `CollectionControlsView` queda como adaptador con `@Query` solo para el detalle de Catálogo, donde no existe una entrada resuelta por la raíz. Una sheet ya abierta conserva deliberadamente su borrador.
- El cambio restaura ARCH-013/ARCH-016 y las políticas ya vigentes de SDD 01, 03 y 04; no cambia la semántica de producto y no requiere ADR, esquema, migración, API, R1/R2, sesión, Keychain u outbox. SDD 06 v1.25 registra los dos niveles de regresión y eleva a ocho los recorridos UI.

### RED / GREEN y validación local de #61

| Herramienta y acción | Resultado |
| --- | --- |
| RED/GREEN discriminante | `testCollectionDetailUsesRootProjection` inyecta B por la frontera raíz mientras el almacén contextual no contiene esa entrada. Restaurar temporalmente el segundo `@Query` antiguo produjo 0/1 y la implementación final aprueba; comprueba además que una apertura posterior del editor usa `[1, 12]` y lectura 8. |
| Recorrido montado A→B | `testMountedCollectionDetailUpdatesWithoutReselection` monta `CollectionUserRootView`, selecciona una entrada A persistida, importa B mediante el `CollectionMutationActor` real y comprueba fila, resumen y seed del editor sin reseleccionar. Aprueba en iPad y, para detalle/editor, en iPhone compacto. Es cobertura complementaria de wiring: también pasa con la consulta antigua en el fixture hermético y no se presenta como RED discriminante. |
| Xcode MCP — `UI` y `ReleaseGate` | `UI` aprueba 8/8. El `ReleaseGate` monolítico final aprueba 472/472 en iPad Air 11-inch (M4), iOS 27: 0 fallos, skips, expected failures o casos no ejecutados. La selección completa también se verificó en sus particiones de 464 Swift Testing y 8 UI. |
| Xcode MCP — compacta | Los dos recorridos nuevos aprueban 2/2 en iPhone 17 Simulator/iOS 27. La lista desaparece legítimamente al navegar; el detalle montado y el editor actualizan a B sin volver atrás ni seleccionar de nuevo. |
| Xcode MCP — build y diagnósticos | El build-for-testing final aprueba en 0,205 s con 0 errores o warnings estructurados. El log incremental conserva dos emisiones exactas de `appintentsmetadataprocessor` acotadas por ADR-0011 y ningún warning de Swift, Clang o DocC. Los siete archivos Swift afectados devuelven 0 diagnósticos focales. |
| Xcode MCP — previews | La nueva preview directa de `CollectionControlsContentView` usa B y un container en memoria; se renderiza e inspecciona sin errores en español, Large, XXX Large y AX5 sobre iPad Pro 13-inch (M5)/iOS 27. Detalle, raíz y adaptador también se revisan en esas variantes; no se observan truncados, solapamientos ni pérdida de la acción. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador aprobados; archive Release generado con warnings DocC como errores y únicamente la emisión externa exacta acotada por ADR-0011. El archive permanece local y no se publica. |
| Integridad, estilo y revisiones | `git diff --check`, el Audit de `swift-source-style` y los escaneos de secretos y escapes de concurrencia quedan limpios. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`. Las reauditorías iOS/datos y SwiftUI/accesibilidad cierran sin hallazgos P0–P3 tras añadir el recorrido montado, el registro durable y la preview directa. |

### Límite de la evidencia

La captura del propietario demuestra la divergencia real, pero el actor y ambos
queries se actualizan correctamente en el fixture A→B de simulador incluso al
restaurar el segundo query. Por tanto, la causa inmediata exacta de invalidación
del runtime físico no se atribuye más allá de lo demostrado. La corrección elimina
la fuente competidora que hacía posible representar dos estados y el RED
determinista impide reintroducirla. El propietario repitió el recorrido live y
comunicó que el fallo quedó arreglado; esa ejecución no fue observada por el
agente. No se ha usado backend, cuenta, Keychain o disco live desde los gates del
agente, ni se han ejecutado VoiceOver, Voice Control, Switch Control, Acceso total
con teclado o Accessibility Inspector.

## R2.2 — GET/DELETE individual y envío de tombstones — issue #57

- El propietario autorizó ampliar el [issue #57 — R2: implementar envío y reconciliación de outbox](https://github.com/JFrancoG/MangaLibrary/issues/57) con ambos endpoints individuales y la interacción de borrado. R2.1 se preserva en `d4b86b5`, R2.2 se versiona en `1629595` y el audit final de estilo en `c2a26a0`; el conjunto se entrega mediante la [PR #60](https://github.com/JFrancoG/MangaLibrary/pull/60). Su fusión cierra #57 y el cierre autorizado incluye retirar `codex/57-r2-outbox-sync` local y remota.
- `/docs` volvió a descubrir `/openapi/openapi.json` y su forma saneada conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`. `GET /collection/manga/{id}` y `DELETE /collection/manga/{id}` reciben `Manga.ID` (`Int64`) como dígitos decimales en el path `string`, usan el mismo Bearer JWT y no envían body, query ni `App-Token`. El GET acepta exclusivamente `200` con una entrada cuyo manga coincide o `404` como ausencia; el DELETE solo confirma con `200` y conserva su `Int64` de respuesta como opaco.
- El GET individual no sustituye al snapshot total de R1 ni se ejecuta como preflight. Su frontera útil es idempotente y estrecha: después de un DELETE cuyo resultado de transporte es incierto, o cuando un trigger autónomo recupera una tombstone `sending` sin proceder de R1 ni disponer de snapshot, permite comprobar una sola vez si ese manga sigue presente sin repetir el borrado. Si R1 acaba de fallar o no puede importar, la operación recuperada se bloquea sin otra request. Una entrada individual nunca pasa por la importación de snapshot completo.
- El worker serializado procesa POST y DELETE. Un DELETE `200` confirma el transporte sin GET; un fallo posterior de resolución local conserva su error, no ejecuta GET y no crea `blockedOutcome`. Un resultado de DELETE incierto ejecuta como máximo un GET individual: `404` confirma, `200` actualiza la base remota y bloquea N como resultado no confirmado y otro fallo ordinario bloquea sin repetir DELETE. Una tombstone recuperada reutiliza primero el snapshot R1 ya importado y hace cero requests adicionales cuando este contiene evidencia suficiente.
- La resolución SwiftData es atómica y vuelve a cercar usuario, manga, UUID y secuencia. Confirmar ausencia retira la entrada tombstone de N solo si no existe una intención posterior y conserva la operación confirmada como cursor monotónico; una N+1 visible permanece intacta. Encontrar presencia remota actualiza base y presentación sin resucitar una tombstone vigente ni pisar N+1. Cancelación, cambio de sesión y fallos seguros de Keychain conservan su clasificación y nunca se degradan a incertidumbre de red.
- En el editor, “Eliminar de la colección” es ahora una acción destructiva prominente, centrada y solo textual, sin icono. Antes de mutar presenta un `alert` nativo localizado cuyo título identifica el manga —con fallback seguro si falta— y cuyo texto explica que se perderán los tomos marcados y el progreso de lectura, incluso si se vuelve a añadir. Conserva Cancelar y una confirmación destructiva “Eliminar”, sin terminología interna de sincronización. El smoke usa identificadores contextuales únicos, valida título, consecuencia, botones y cancelación sin efecto, y comprueba además que la acción queda completamente por encima de la barra flotante antes de tocarla.

### RED / GREEN y validación local de R2.2

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing focal | Las suites nuevas cubren request exacta y adaptación `200/404`, `Int64.max`, ausencia, respuesta malformada, status inesperado y cancelación; DELETE directo, reconciliación ausente/presente/fallida/cancelada, tombstone recuperada y todos los fallos seguros de sesión; y un pipeline real coordinador + `CollectionMutationActor` con N/N+1 y aislamiento de otro manga. La regresión añadida al cierre aprueba 2/2 y demuestra que `staleOperation` y `persistenceConflict` posteriores a DELETE `200` producen 0 GET y 0 bloqueos ambiguos. Todos usan JWT, rutas, respuestas y containers sintéticos. |
| Xcode MCP — `Integration` | El inventario final descubre 366 declaraciones, pero conserva 0 habilitadas y 366 deshabilitadas; por tanto no existe un gate `Integration` independiente válido. La ejecución 390 aprobados/21 excluidos/0 fallos pertenecía al snapshot anterior a la última corrección y no se presenta como evidencia final. Todos los casos del snapshot final quedan cubiertos por `ReleaseGate`. |
| Xcode MCP — `ReleaseGate` | La ejecución final posterior al ajuste de la alerta aprueba 470/470 resultados en iPhone 17 Simulator con iOS 27: 0 fallos, skips, expected failures o casos no ejecutados. Incluye los seis smokes UI, las dos variantes de fallo local posteriores al DELETE y el oráculo nuevo de título contextual, consecuencia, Cancelar/Eliminar y cancelación sin efecto. |
| Xcode MCP — build y diagnósticos | Build-for-testing posterior al ajuste funcional aprobado en 2,037 s con 0 warnings y 0 errores estructurados. Tras el audit final de estilo, otro build-for-testing aprueba en 6,308 s sobre iPhone 17 Simulator/iOS 27 con 0 issues estructurados; el full log conserva dos emisiones incrementales exactas de `appintentsmetadataprocessor` ya atribuidas por ADR-0011 y ningún warning de Swift, Clang o DocC. `CollectionEditorView.swift` y `MangaLibraryUITests.swift` devuelven 0 diagnósticos, igual que la revisión focal anterior del resto del corte. |
| Xcode MCP — preview | “Known total editor” se renderizó sin errores en español sobre iPhone 17 Pro/iOS 27 antes del ajuste final de copy. La captura acredita el editor y su jerarquía inicial, no el contenido del alert; título, mensaje, botones e interacción final se acreditan mediante el smoke UI. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador aprobados; archive Release generado en `.build/docc/MangaLibrary.doccarchive` con warnings DocC como errores y exactamente la emisión externa acotada por ADR-0011 para Xcode 27 build `27A5252f`. No se publica el archive. |
| Localización, integridad y estilo | El String Catalog conserva 182 claves activas completas en inglés y español, 0 stale. `git diff --check`, los escaneos de logs/secretos/escapes de concurrencia y el Audit de `swift-source-style` quedan limpios; las candidatas verticales restantes son closures, tipos función, una cadena SwiftUI o una secuencia cronológica intencionada. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`. |
| Revisiones independientes | Las reauditorías finales iOS/testing y SwiftUI/accesibilidad cierran sin hallazgos P0–P2; el único P3 fue el recuento documental de 180 claves, corregido a 182. No se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado ni Accessibility Inspector; el fallback sin título queda cubierto estáticamente y el copy final no se inspeccionó mediante preview. |

### Evidencia y límite live de R2.2

El propietario ejecutó la ruta de producto sobre tres dispositivos autenticados.
El primer borrado entró en reconciliación tras un resultado DELETE incierto; el
segundo dispositivo recibió `404` al intentar borrar la misma `Manga.ID` y también
reconcilió; una sesión fresca en el tercer dispositivo observó el manga ausente
en el snapshot remoto. No se conservaron tokens, cuentas, URLs completas ni
payloads. Esta prueba acepta la semántica decimal del path, el DELETE concurrente,
el GET individual de reconciliación y la ausencia remota final conforme a SDD 04
v1.22. No permite afirmar el status ni el body exactos del primer DELETE, ni
caracteriza por separado el GET individual presente `200`; esos detalles y que
OpenAPI declare el `404` solo en prosa mientras tipa `{id}` como `string`
continúan como deuda de contrato. Retry/backoff, `blockedAuth`, rechazo/reversión,
resolución manual de `blockedOutcome` y el cierre global del Advanced Release
Gate permanecen fuera de este corte.

## R2.1 — POST y reconciliación conservadora de outbox — issue #57

- El [issue #57 — R2: implementar envío y reconciliación de outbox](https://github.com/JFrancoG/MangaLibrary/issues/57) se abrió después de comprobar que no existía otro issue, PR o rama equivalente. La rama `codex/57-r2-outbox-sync` partió de `main@80ac1bb665c4a4cfc380b3d8617aa276ced83cc0`, limpio y sincronizado con `origin/main` en el preflight aprobado. El corte R2.1 quedó preservado en `d4b86b5` antes de integrar la entrega #58 y forma parte de la [PR #60](https://github.com/JFrancoG/MangaLibrary/pull/60) junto a R2.2.
- La decisión del propietario elimina la ambigüedad semántica de los paths individuales: `{id}` es `Manga.ID` (`Int64`) y el transporte escribe sus dígitos decimales en el parámetro `string`. El UUID de la entrada remota no forma el path. R2.1 lo registró en SDD 04 v1.18; la integración con la autoridad JWT de #58 elevó la especificación combinada a v1.19 y R2.2 materializa ahora esa decisión. La prueba live multidispositivo acepta la ruta decimal y la ausencia reconciliada; la discrepancia machine-readable y la respuesta exacta del primer DELETE permanecen como deuda de contrato.
- `/docs` volvió a descubrir `/openapi/openapi.json`; la forma saneada conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`. R2.1 reutiliza el `GET /collection/manga` completo de R1 e implementa únicamente `POST /collection/manga` para intenciones no tombstone con Bearer y las claves exactas `manga`, `completeCollection`, `volumesOwned` y `readingVolume`. Un progreso ausente se codifica como `null`; solo `200` con `Int64` válido confirma el transporte y ese entero permanece opaco.
- En ese corte, el actor de outbox reautoriza la sesión y reclama la menor secuencia procesable mediante la instancia compartida de `CollectionMutationActor`. La gate exacta se consume en la misma transacción `queued → sending`; confirmación y bloqueo exigen otra vez usuario, manga, UUID y secuencia. Confirmar N solo avanza la base remota y conserva visible N+1. R2.1 dejó entonces diferidos tombstones, retry/backoff, `blockedAuth`, rechazo/reversión y resolución manual; R2.2 implementa ahora los tombstones y mantiene diferido el resto.
- R1 devuelve por valor únicamente autoridad + entradas después de importar. R2 exige la misma generación y reutiliza ese snapshot para cualquier `sending` recuperada: existe un GET total y cero POST repetidos. Si R1 no obtiene o no puede importar evidencia utilizable por un fallo ordinario, bloquea solo `sending` sin reclamar `queued` ni tocar la red; cancelación o `sessionChanged` preservan la operación. Un POST incierto usa exactamente un GET fresco posterior, porque el snapshot R1 es anterior a la escritura.
- La integración con #58 conserva además la precedencia de ADR-0019: si la validación de autoridad ya ha confirmado `temporarilyUnavailable` o `persistenceUnavailable` al limpiar o reemplazar Keychain, R1 no ejecuta la clasificación secundaria de `sending` y R2 no lo reinterpreta como POST incierto o `blockedOutcome`. El error de sesión original prevalece incluso si el caller ya fue cancelado.
- Ambos entrypoints R2 obtienen o revalidan la autoridad vigente y consumen su gate antes de tocar el vuelo activo. Un ticket de reemplazo conserva solo el último caller válido mientras espera a un POST no cooperativo y nunca recorre vuelos instalados durante esa espera. Las regresiones cubren ambos sentidos: snapshot o callback A tardío no cancelan B, mientras snapshot o callback B vigentes sí sustituyen A y reconcilian o bloquean sin repetir la escritura.
- Cuenta conserva la sesión activa y deriva el aviso de resultado no confirmado directamente de `blockedOutcome` persistido; no duplica la outbox en `@State`. El aviso es seguro, localizado y no pide volver a introducir credenciales válidas. Los logs incluyen solo origen constante, status cuando existe y acción; nunca URL completa, cabeceras, token, cuenta, UUID o payload.

### RED / GREEN y validación local de R2.1

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing focal | La selección R2.1 aprueba 40/40 funciones sobre request POST, transiciones, worker y pipeline real. La selección final de siete regresiones de concurrencia también aprueba 7/7: reemplazo single-flight, fallo cancelado, snapshots y callbacks A↔B y cancelación post-importación no cooperativa. Los oráculos usan loaders, tokens y UUID sintéticos y `ModelContainer` aislado. |
| Pipeline GET → outbox | `queued` ejecuta GET → POST → `confirmed`. Una `sending` recuperada usa el único GET R1 y cero POST tanto para match → `confirmed` como para ausencia → `blockedOutcome`. Fallo de lectura o importación ordinario bloquea sin otra request; cancelación, `sessionChanged`, snapshot A/autorización B y callback A tardío conservan la generación vigente. UUID o secuencia obsoletos producen `staleOperation` y dejan store/base intactos. |
| Xcode MCP — `ReleaseGate` | 359/359 resultados aprobados en iPhone 17 Simulator con iOS 27, sin fallos, skips, expected failures o casos no ejecutados. En ese corte el plan `Integration` descubrió cero tests habilitados y no se presentó como gate independiente; la regresión continúa visible en el inventario final de R2.2. |
| Integración #58 → R2.1 | Ocho casos RED reproducen que la recuperación secundaria sustituía los dos fallos seguros de Keychain por cancelación, `sessionChanged` u outcome incierto. Tras cercar los tres catches afectados, el `ReleaseGate` combinado aprueba 438/438 resultados, sin fallos, skips, expected failures ni casos no ejecutados; ninguna regresión marca `blockedOutcome` o repite red ante esos fallos de sesión. |
| Xcode MCP — build y diagnósticos | Build-for-testing incremental posterior aprobado en 0,223 s y log estructurado con cero warnings o errores. La revisión focal de los 13 archivos Swift modificados tampoco encuentra diagnósticos. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador aprobados; archive Release generado en `.build/docc/MangaLibrary.doccarchive` con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011 para Xcode 27 build `27A5252f`. No se publica el archive. |
| SwiftUI y accesibilidad | La preview del aviso R2 se inspecciona en español sobre iPhone 17 Pro/iOS 27 en Large, XXX Large y AX5; no hay truncado ni solapamiento y AX5 conserva el contenido mediante scroll. No se ejecutan Accessibility Inspector, VoiceOver, Voice Control, Switch Control ni Acceso total con teclado. |
| Integridad, localización y estilo | El String Catalog conserva 180 claves activas completas en inglés y español y cero entradas stale. `git diff --check` y el Audit de `swift-source-style` sobre los 13 Swift cambiados quedan limpios; las tres candidatas restantes son closures o componentes de cadena preexistentes e intencionados. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`; no cambian targets, test plans, dependencias ni entitlements. |
| Revisiones independientes | Las revisiones SwiftUI/accesibilidad, iOS/arquitectura/concurrencia y diff/gobernanza cierran sin hallazgos P0–P3. Durante ellas se corrigieron el doble GET de `sending`, el fallo R1 sin clasificación, las cercas de autoridad y operación, el mapping de importación y las carreras de reemplazo A↔B antes del gate final. |

### Límite live y siguiente corte

Durante esta validación local de R2.1, Codex no realizó login, petición
funcional autenticada ni escritura live. Por
tanto, esta evidencia demuestra el pipeline hermético y que sus fallos no borran
la sesión, pero no acredita todavía la respuesta real del POST ni la aceptación
de `Manga.ID` decimal por GET/DELETE individual. El siguiente paso controlado es
que el propietario inicie sesión y suba su colección con esta build; después se
caracterizarán GET y DELETE con id sobre datos deliberadamente creados para esa
prueba. Un backend write o delete ejecutado por Codex necesitará autorización
separada.

## Compatibilidad JWT única con Colección — issue #58

- El [issue #58 — Auth: migrar a JWT único compatible con Colección](https://github.com/JFrancoG/MangaLibrary/issues/58) se abrió sin duplicados. La rama `codex/58-jwt-collection-auth` partió de `main@80ac1bb665c4a4cfc380b3d8617aa276ced83cc0`, se implementó en un worktree aislado para preservar R2 y se entregó mediante la [PR #59](https://github.com/JFrancoG/MangaLibrary/pull/59). Tras la autorización expresa del propietario, el issue se cerró y el worktree y las ramas local/remota se retiraron el 2026-09-03, una vez verificado que no conservaban commits fuera de `main`.
- La evidencia live manual atribuye por fin el status inmediato: el access del flujo dual obtiene `200` en `GET /users/session/me`, pero `GET /collection/manga` devuelve `401`, también después de renovarlo. Los JWT de `POST /users/jwt/login` y `POST /users/jwt/refresh` obtienen `200` tanto en `GET /users/jwt/me` como en Colección; ambos declararon 86.400 segundos. No se conservan tokens, credenciales, cuenta, UUID, cabeceras completas ni cuerpos.
- El OpenAPI vivo y el snapshot versionado continúan coincidiendo con SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b` y siguen publicando ambas familias como válidas. La causa más probable es una configuración o middleware de autenticación de Colección que solo reconoce la familia JWT única; no se dispone de configuración interna del backend para demostrar qué componente exacto produce la deriva.
- ADR-0019 adopta el JWT único y supersede ADR-0006 y ADR-0018. En su entrega, SDD 00 v1.9, SDD 04 v1.17, SDD 05 v1.6 y SDD 06 v1.20 sustituyeron la autoridad dual, conservaron el límite Advanced/Deluxe y definieron la validación proporcional. La integración posterior con R2.1 eleva las especificaciones combinadas SDD 04 y SDD 06 a v1.19 y v1.22, respectivamente. El contrato se documenta como deriva runtime, sin alterar ni reinterpretar su snapshot.
- Sesión ejecuta `jwt/login` → `jwt/me`, persiste solo UUID, generación, JWT y expiración en un envelope Keychain V3, y renueva con `jwt/refresh` → `jwt/me` cinco minutos antes de vencer. V1/V2 se retiran de forma fail-closed y requieren un login nuevo; nunca se reinterpretan como JWT clásico. La contraseña sigue siendo efímera y no se decodifican claims.
- Cada autorización y commit queda cercado por UUID, generación, revisión opaca de credencial, JWT exacto y expiración. Activar o renovar rota la revisión aunque el servidor repita el mismo texto. Los refresh concurrentes son single-flight; los resultados A→B tardíos no alcanzan otra sesión y una recuperación A→B se une a un refresh B→C ya iniciado antes de devolver, por lo que nunca publica B como credencial intermedia.
- R1 conserva la política de #55: el primer `401` de Colección fuerza una renovación validada y un único retry del GET; un segundo `401` conserva sesión y muestra incompatibilidad. `403` conserva sesión sin refresh ni retry. Un rechazo permanente de `jwt/refresh`, un JWT vencido o una identidad distinta sí producen `authenticationRequired`. Los fallos Keychain seguros sobreviven a cancelación y se presentan en Cuenta para la autoridad exacta, incluso como aviso no bloqueante cuando el JWT anterior mantiene el snapshot activo.
- La autoridad completa llega también a los editores y comandos locales. Una sheet de la generación A no puede escribir Colección u outbox después de activar B con el mismo UUID; una rotación de credencial dentro de la misma generación puede resolver una capacidad nueva antes del commit. El alcance entregado por #58 no implementa R2, no llama a POST/DELETE de Colección y no introduce una escritura live.

### RED / GREEN y validación local de #58

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial no compiló porque la sesión aún carecía de `refresh(token:)`. Las regresiones nuevas cubren requests JWT exactos, V3 y retirada V2, ventana preventiva, expiración, identidad, single-flight, texto JWT repetido, carreras A→B/ABA/B→C, cancelación y fallos de carga, reemplazo o limpieza Keychain. Los cuatro últimos bordes pasan 4/4; `SessionController` + `AccountModel`, 120/120; selección afectada de Cuenta, Colección y Sesión, 278/278. |
| Xcode MCP — `ReleaseGate` | 379/379 resultados aprobados en iPhone 17 Simulator con iOS 27: cero fallos, skips, expected failures o casos no ejecutados. Incluye los smokes UI sintéticos; ningún test usa una cuenta, credencial o red de producción. |
| Xcode MCP — build y diagnósticos | Build-for-testing y build normal aprobados con warnings como errores; el log estructurado final no contiene warnings ni errores propios. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador y archive Release aprobados, con warnings DocC como errores y solo la emisión externa exacta acotada por ADR-0011. El archive permanece local y no se publica. |
| UI y revisiones independientes | Cuenta conserva el estado autenticado y presenta por separado incompatibilidad de Colección, permiso insuficiente o fallo de persistencia. Las previews afectadas se revisan en Large, XXX Large y AX5, incluido detalle read-only. Las auditorías iOS, concurrencia, seguridad, testing, SwiftUI/accesibilidad y `swift-source-style` cierran sin hallazgos P0–P3. No se atribuye cobertura de VoiceOver, Voice Control, Switch Control, Acceso total con teclado, dispositivo físico o Accessibility Inspector. |
| Privacidad e integridad | `git diff --check`, el detector de estilo y los escaneos de logs, secretos y escapes de concurrencia quedan limpios. No cambian `project.pbxproj`, targets, test plans, dependencias ni entitlements. El corte R2 original permanece preservado en su commit local. |

La evidencia automatizada demuestra que la composición de producción entrega el
mismo JWT sintético a identidad y al GET R1, que un retry correcto mantiene la
sesión y que un segundo rechazo ya no forma un bucle de credenciales. La evidencia
manual demuestra por separado que la familia JWT única es aceptada live por
Colección. Todavía falta reinstalar o ejecutar esta versión concreta, iniciar
sesión de nuevo tras retirar V2 y confirmar el recorrido completo en el iPhone;
sin acceso al backend no puede atribuirse el middleware interno ni garantizarse
que su configuración no vuelva a cambiar.

La implementación se versiona inicialmente en `4c5c5bb` y se entrega mediante la
[PR #59](https://github.com/JFrancoG/MangaLibrary/pull/59). El issue #58 está
cerrado y su rama local, rama remota y worktree aislado ya se retiraron.

## Corrección crítica del bucle de reautenticación R1 — issue #55

- El [issue #55 — R1: corregir el bucle de reautenticación tras un rechazo de Colección](https://github.com/JFrancoG/MangaLibrary/issues/55) se abrió después de comprobar que no existía otro issue o PR equivalente. La rama `codex/55-r1-collection-auth-loop` parte de `main@6695f106e9de90a44d98bf2d127ddabf1a8948c9`, limpio y sincronizado con `origin/main` en el preflight aprobado.
- La causa inmediata queda demostrada por el flujo de producto: login llegaba a sesión activa y el trigger R1 posterior convertía cualquier `401` o `403` de `GET /collection/manga` en invalidación destructiva del mismo envelope Keychain. La instrumentación LLDB temporal no consiguió atribuir de forma inequívoca un único status a una reproducción nueva, por lo que el código live exacto continúa sin confirmar y no se inventa. El contrato vivo y el snapshot siguen coincidiendo con SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; solo publican `200` para la operación y no documentan la política de error.
- SDD 01 v1.5 asigna al shell un aviso efímero ligado a identidad. SDD 04 v1.16 separa autenticación de autorización, obliga a validar `/me` antes de publicar cualquier access renovado, cerca generaciones y vuelos residuales y limita R1 a un retry seguro. SDD 06 v1.19 define las pruebas separadas. No cambia el contrato OpenAPI y no hace falta otro ADR porque se corrige una política normativa, no se introduce una excepción arquitectónica.
- Un `403` de Colección conserva sesión, Keychain, colección y outbox, no renueva ni repite y presenta permiso insuficiente. Un primer `401` vigente fuerza refresh single-flight ligado a generación y access, valida la misma identidad en `/me` y repite el GET una vez. Solo un rechazo permanente del refresh conduce a `authenticationRequired`; un rechazo del access nuevo en `/me`, un segundo `401` o un `403` en el retry conserva la sesión y expone incompatibilidad o autorización de Colección.
- `MainShellView` ya no oculta el origen: reconcilia primero el snapshot, publica el aviso solo para la misma identidad autenticada y lo limpia al cambiar de usuario o tras una sincronización correcta. Cuenta muestra un aviso no bloqueante localizado que explica que la sesión sigue activa y que no hay que volver a introducir credenciales. Los logs conservan únicamente origen constante, status, intento y acción; no registran URL, cabeceras, tokens, correo ni payload.
- La restauración con access expirado reutiliza la identidad que el propio refresh acaba de validar y no ejecuta un segundo `/me`. Un refresh A residual no intercepta la autorización ni la recuperación de un `401` de B; se comparte un vuelo solo si todavía reemplaza generación y access vigentes. Un `401` que llega durante logout queda marcado y, si el borrado falla, obliga a renovar antes de reutilizar la sesión.

### RED / GREEN y validación local de la corrección #55

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial no compila por las nuevas superficies de recuperación y presentación ausentes. La regresión de restore reproduce el segundo `/me` con 0/1 y queda en 4/4. La carrera determinista flight A suspendido → logout A → login B reproduce por separado el `sessionChanged` espurio en la autorización y en la recuperación de B (0/1 en cada condición anterior) y queda en 1/1. La selección final de sesión y R1 aprueba 13/13. |
| Semántica `401` / `403` | Las pruebas separadas cubren `403` sin refresh ni borrado, `401` con un refresh y un retry, importación correcta, rechazo permanente del refresh, segundo `401`, `403` del retry, rechazo de `/me`, logout fallido y remote `[]` con estados confirmado, pendiente y huérfano sin alterar autenticación. Las composiciones llamadas `live` usan tipos de producción con loaders, tokens y respuestas sintéticos; no alcanzan el backend real. |
| Flujo UI y previews | El test UI sintético confirma login → cierre del formulario → R1 `403` → Cuenta continúa autenticada con aviso específico y Colección no pasa a solo lectura. La preview final en español se inspecciona en Large, XXX Large y AX5 sin truncamiento ni solapamiento; AX5 conserva el contenido mediante scroll. No se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado ni Accessibility Inspector. |
| Xcode MCP — `ReleaseGate` | 308/308 resultados aprobados en iPhone 17 Simulator con iOS 27, sin fallos, skips, expected failures o casos no ejecutados. |
| Xcode MCP — build y diagnósticos | Build-for-testing aprobado en 0,217 s y cero issues estructurados. El log conserva dos emisiones incrementales exactas de `appintentsmetadataprocessor` ya atribuidas por ADR-0011; no hay warnings de Swift o Clang. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente una emisión externa acotada por ADR-0011 para Xcode build `27A5252f`. |
| Localización, integridad y estilo | Catálogo válido con 179 claves, cero traducciones EN/ES ausentes o no traducidas y cero entradas stale. `git diff --check` y el Audit del diff Swift quedan limpios. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`; no cambian targets, dependencias, test plans ni entitlements. |
| Revisiones independientes | Las revisiones finales iOS/arquitectura/concurrencia, contrato/tests y SwiftUI/accesibilidad cierran sin hallazgos P0–P3 sobre el snapshot validado. |

### Límite de evidencia live

La corrección elimina el bucle para ambos status posibles y deja instrumentación segura para distinguirlos en la próxima reproducción, pero esta sesión no dispuso de nuevas credenciales ni de una reproducción física. Sigue pendiente capturar el status real y confirmar la política backend: un `403` apuntaría principalmente a permisos, `isActive` o política específica de Colección; un `401` aceptado antes por `/me` apuntaría a una configuración Bearer o validación incoherente entre endpoints. No se hicieron escrituras live ni se imprimió material sensible.

La implementación se versiona inicialmente en `506153a` y se entrega mediante la
[PR #56](https://github.com/JFrancoG/MangaLibrary/pull/56), cuya fusión cierra el
issue #55. El cierre autorizado incluye retirar después la rama local y remota.

## Lectura e importación remota R1 — issue #53

- El [issue #53 — R1: implementar lectura e importación remota de Colección](https://github.com/JFrancoG/MangaLibrary/issues/53) se abrió después de comprobar que no existían issues, PR o ramas equivalentes. La rama `codex/53-r1-remote-collection-import` parte de `main@a68a3ecc40387dad519ea35ef115f13f0e5b988f`, limpio y sincronizado con `origin/main` en el preflight aprobado.
- `/docs` volvió a descubrir `/openapi/openapi.json`. Su forma canónica saneada coincide con el snapshot versionado y conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no se realizó una petición funcional autenticada ni se usaron cuentas, tokens o datos live.
- R1 consume únicamente `GET /collection/manga` con Bearer vigente y status exacto `200`, reutiliza el DTO real de Manga e interpreta el array como snapshot remoto completo. La raíz estable lo inicia al restaurar o confirmar sesión, sin esperar a que se visite Colección, y la UI continúa observando exclusivamente SwiftData mediante `@Query`.
- El coordinador mantiene la red fuera de `CollectionMutationActor`, propaga cancelación y exige que la misma generación siga autorizada antes de aplicar. La importación valida el lote entero y usa la instancia compartida del actor y un único commit; error, deriva, duplicado, cancelación o fallo de persistencia conservan store y outbox previos.
- Sin intención pendiente, una presencia remota sustituye estado, base confirmada y presentación; con intención pendiente solo actualiza base y presentación. Una ausencia retira únicamente estado confirmado sin pendiente, conserva y registra la base ausente cuando hay pendiente y falla cerrado ante un huérfano sin confirmación ni outbox.
- R1 valida el UUID remoto pero reconcilia por usuario + manga y no persiste ni interpreta todavía ese UUID como `{id}`. `POST`, `DELETE`, GET individual, worker, envío, retry, transiciones `blockedAuth`/`blockedOutcome`, reversión, UI de conflictos, escrituras live y todo Deluxe permanecen fuera y corresponden a R2 o fases posteriores.

### RED / GREEN y validación local de R1

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial falla al compilar por la ausencia deliberada de las superficies R1. El GREEN focal cubre request, DTO, importación, rollback, sesión y carreras; las regresiones finales de logout/401, payload, `401`/`403`, cancelación postmutación y trigger UI aprueban sus selecciones sin fallos. Todos los tokens, UUID, respuestas y containers son sintéticos. |
| Contrato e invariantes | `/docs` descubre el OpenAPI vivo y el snapshot saneado conserva el mismo hash. La ruta rechaza UUID o manga duplicados, UUID wire o enums malformados, identidad y volúmenes no positivos, valores superiores al total, complete sin total, huérfanos y fallo o cancelación parcial; el store y la outbox se comparan desde otro contexto después del rollback. |
| Sesión y concurrencia | La gate de commit linealiza invalidación y transacción sin cruzar procesos. Los tests cubren A→B y ABA, refresh concurrente, rechazo ligado a generación + access exactos, logout fallido concurrente con `401`, sustitución de vuelo, trigger precancelado y mutación local suspendida. |
| Xcode MCP — build y diagnósticos | Build-for-testing final aprobado en 3,625 s sobre iPhone 17 Simulator con iOS 27. El log estructurado y el Issue Navigator devuelven cero warnings y cero errores. |
| Xcode MCP — `ReleaseGate` | 293/293 resultados aprobados, sin fallos, skips, expected failures o casos no ejecutados. Incluye el flujo UI Debug que confirma login sintético → trigger R1 → fila remota observada por `@Query` y después una mutación local por la capacidad de producción; no usa red, Keychain ni disco live. |
| `Scripts/validate-docc.sh` | Ocho escenarios deterministas del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente una emisión externa acotada por ADR 0011 para Xcode build `27A5252f`. El archive permanece local y no se publica. |
| Integridad y estilo | `git diff --check` y el Audit del diff Swift quedan limpios. `project.pbxproj` conserva SHA-256 `ee6cd588ee1ba5666a71b8b42cbc19338af70025072d35a4efe1acb14732ab76`; no cambian test plans, targets, dependencias ni entitlements. Xcode queda restaurado al scheme `MangaLibrary`, plan `Fast` y destino iPhone 17 Simulator. |
| Revisiones independientes | Las revisiones finales iOS/arquitectura/concurrencia y especificación/tests cierran sin hallazgos P0–P3 sobre el snapshot validado. La revisión SwiftUI/accesibilidad no encuentra cambios visuales o semánticos que justifiquen render; no se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado ni Accessibility Inspector. |

### Riesgo transversal y estado de entrega de R1

SDD 03 exige que una colección completa materialice `1...total`, pero el contrato
no publica un máximo para `totalVolumes`. Un total positivo extremo puede agotar
recursos en R1 y en las rutas L1/L2 preexistentes que aplican la misma invariante.
Fijar una cota solo en R1 inventaría una política incoherente; su resolución
requiere una decisión normativa transversal, error tipado y cobertura local,
remota y de UI. No se oculta como gate superado ni se amplía este diff con una
cota arbitraria. El issue #63 recoge la decisión posterior del propietario de
usar 300 como máximo inclusivo e implementa esa resolución transversal con sus
gates locales completos; el riesgo no se considera entregado hasta versionar y
fusionar el cambio mediante autorización posterior.

La implementación se versiona inicialmente en `6298255` y se entrega mediante la
[PR #54](https://github.com/JFrancoG/MangaLibrary/pull/54), cuya fusión cierra el
issue #53. El cierre autorizado incluye retirar después la rama local y remota.

## Limpieza de conformidades `Sendable` redundantes — issue #51

- El [issue #51 — retirar conformidades Sendable explícitas redundantes](https://github.com/JFrancoG/MangaLibrary/issues/51) no tenía un issue, PR o rama equivalente. La rama `codex/51-remove-redundant-sendable-conformances` partió de `main@202d2f73489bfbae415bf88a651348d93357f22c`, limpio y sincronizado con `origin/main`. La implementación se entrega mediante la [PR #52](https://github.com/JFrancoG/MangaLibrary/pull/52).
- El inventario completo de 78 archivos Swift identificó 42 conformidades explícitas redundantes en tipos de valor internos: 32 en 10 archivos de producto y 10 en 5 archivos de tests. Swift 6.4 infiere esas conformidades porque todos sus miembros o valores asociados son enviables, por lo que retirarlas no cambia comportamiento, API interna, aislamiento ni persistencia.
- Permanecen exactamente las tres clases sincronizadas de tests que necesitan declarar `Sendable`: `ControlledSessionPersistenceStorage`, `SynchronousPersistenceGate` y `TestSessionClock`. También se conservan todos los atributos `@Sendable` de closures y typealiases que expresan fronteras concurrentes reales.
- La regla ya está recogida por `ios-development-standards`, `swift-concurrency` y el gate independiente de `review-ios-standards`: los `struct` y `enum` internos confían en la inferencia y una conformidad explícita requiere una frontera pública o genérica demostrada. No se modifica ninguna skill, SDD o ADR.

### Validación local de la limpieza `Sendable`

| Herramienta y acción | Resultado |
| --- | --- |
| Inventario estructural | Cero conformidades explícitas restantes en `struct` o `enum`; exactamente tres clases justificadas. Los atributos `@Sendable` coinciden con `main` y no existen `@unchecked Sendable`, `@preconcurrency` o `nonisolated(unsafe)`. |
| Xcode MCP — build y diagnósticos | Build aprobado sobre iPhone 17 Simulator con iOS 27; log estructurado e Issue Navigator con cero warnings y cero errores. El proyecto conserva Swift 6, concurrencia estricta completa, aislamiento predeterminado `nonisolated` y warnings como errores. |
| Xcode MCP — `ReleaseGate` | 241/241 casos aprobados, sin fallos, skips, expected failures o casos no ejecutados. No se añaden tests que solo comprueben una conformidad inferida por el compilador, de acuerdo con SDD 06. |
| Revisiones independientes | Las auditorías iOS/concurrencia, gobernanza e inventario y `swift-source-style` cierran sin hallazgos. La revisión SwiftUI/accesibilidad no aplica porque no cambia ninguna View, recurso ni semántica de presentación. |
| Integridad y restauración | El diff funcional queda limitado a 15 archivos Swift y la entrada obligatoria de changelog; `git diff --check` está limpio y no cambian `project.pbxproj`, test plans, targets, dependencias o entitlements. Xcode queda restaurado al scheme `MangaLibrary`, plan `Fast` y destino iPhone 17 Simulator. |

La implementación se versiona inicialmente en `0d39c67` y se entrega mediante la [PR #52](https://github.com/JFrancoG/MangaLibrary/pull/52), cuya fusión cierra el issue #51. El cierre autorizado incluye retirar después la rama local y remota. R1, R2 y las capacidades Deluxe permanecen como unidades separadas.

## Colección local y offline L2 — issue #49

- El [issue #49 — L2: implementar Colección local y offline](https://github.com/JFrancoG/MangaLibrary/issues/49) no tenía issues, PR o ramas equivalentes. La rama `codex/49-l2-offline-collection` partió de `main@3fe8b236f68d08b2174cb907f2c332061e49a812`, limpio y sincronizado con `origin/main`. El propietario aprobó las seis decisiones, el plan y después el cierre completo el 2026-09-01. La implementación se entrega mediante la [PR #50](https://github.com/JFrancoG/MangaLibrary/pull/50).
- `MangaLibrarySchema.V2` añade a Colección un snapshot `Codable` de presentación offline y conserva V1 congelado dentro de un plan explícito de migración lightweight `1.0.0 → 2.0.0`. Una entrada migrada sin snapshot muestra ausencia explícita y su `mangaID`; no inventa datos de Catálogo. El composition root continúa creando una sola vez el `ModelContainer` live y el mismo `CollectionMutationActor`.
- La capacidad `@ModelActor` acepta el comando completo del editor por valores `Sendable`, valida el snapshot de la primera alta y extiende la única transacción semántica a reemplazo integral, reactivación y eliminación. Colección y outbox se guardan o coalescen juntas; eliminar persiste una tombstone y su intención, sin `insert`, `delete` o `save` desde una View.
- La raíz de Colección usa `@Query` con predicate de store por usuario y `isTombstone == false`. Posee `NavigationStack` compacto y `NavigationSplitView` regular, selección propia por `Manga.ID` y limpieza al cambiar de identidad. El alta reutiliza el detalle de Catálogo ya cargado; no añade búsqueda, segunda autoridad, router global, Repository o UseCase.
- `authenticationRequired`, reautenticación con identidad conocida y `signingOut` conservan lectura con mutaciones bloqueadas. Restauración, fallo de restauración, autenticación sin identidad y `signedOut` muestran indisponibilidad explícita. `CollectionMutation` relee `AccountModel` justo antes de enviar al actor, por lo que solo la cuenta autenticada coincidente puede crear trabajo `queued`.
- El DTO caracteriza `volumes` nullable: solo un entero positivo se convierte en total conocido. El editor conserva tomos exactos y huecos; usa selección con total conocido y entrada numérica validada cuando es desconocido, mantiene lectura independiente y solo permite completar cuando existe un total válido.
- En el editor con total conocido, `isComplete` deja de duplicar estado y se deriva del conjunto de tomos. Marcar el último tomo activa “Colección completa”, retirar cualquiera la desactiva y el control actúa como selección total: al apagarlo vacía los tomos del borrador sin alterar la lectura. El guardado continúa usando la única mutación atómica de Colección y outbox.
- Cada preview con SwiftData crea mediante `PreviewModifier` un único container V2 real y aislado para su escenario; `@Query` y la capacidad de producción comparten ese container. Los subcomponentes sin persistencia no crean infraestructura ceremonial. Los fixtures son locales y nunca alcanzan red, Keychain, cuentas o disco live.
- En el detalle, `Mi colección` usa un `DisclosureGroup` nativo, expandido por defecto y con un objetivo vertical mínimo de 44 pt. Los mensajes vacío, sin sesión y de solo lectura quedan centrados; las acciones son botones prominentes grandes, centrados y solo con texto. Cada fila prueba primero etiqueta y valor en horizontal y, cuando el valor no cabe —como una propiedad extensa—, `ViewThatFits` conserva la lista completa bajo su etiqueta; en tamaños de accesibilidad todas se apilan. El editor sustituye Cancelar y Guardar por `xmark` y `checkmark` en la toolbar nativa, sin material manual, y mantiene sus nombres localizados, identificadores y progreso accesibles.
- L2 no incorpora R1/R2, endpoints, importación, worker, retry, reconciliación, estados remotos nuevos, entitlements, App Group, CloudKit, WidgetKit, watchOS ni targets adicionales.

### RED / GREEN y validación local de L2

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial falla al compilar por la ausencia deliberada de las superficies L2. El GREEN original selecciona 39 declaraciones focales de Colección y obtiene 44/44 resultados. La regresión posterior del control “Colección completa” reproduce ambos defectos con 0/2 y queda en 2/2; las nueve declaraciones del modelo aprueban 9/9. Usa containers V2 reales en memoria y stores temporales en disco, sin sleeps, serialización artificial, red, Keychain o datos live. |
| Invariantes, autorización y atomicidad | Los oráculos cubren canonicalización también por `replaceState`, valores inválidos y rollback, unicidad, A/B, todos los estados no autenticados, guard/éxito/fallo del borrado del editor, coalescencia, tombstone y reactivación con `desiredState` vigente. |
| Migración y reapertura | Un store V1 temporal migra campo a campo a V2 conservando Colección y outbox y dejando el snapshot ausente. Otro store real demuestra alta A/B, edición no tombstone, aislamiento, eliminación y consultas activas después de tres reaperturas. |
| Xcode MCP — build y diagnósticos | Build-for-testing final aprobado en 3,449 s sobre iPhone 17 Simulator con iOS 27. Los diagnósticos focales de `CollectionStateSummary.swift`, `CollectionEditorView.swift` y `MangaLibraryUITests.swift`, además del resultado estructurado del build, devuelven cero incidencias. |
| Xcode MCP — `ReleaseGate` | El snapshot final ejecuta y aprueba 241/241 casos: cero fallos, skips, expected failures o casos no ejecutados. Incluye los cinco smokes UI; el detalle sin sesión verifica expandir y contraer `Mi colección`, y el flujo autenticado cubre Catálogo → detalle → mutación de producción → fila observada por `@Query`. Ese flujo aprueba también 1/1 de forma focal después de exigir los nombres accesibles Cancelar/Guardar de los botones icon-only. |
| Xcode MCP — previews | Tras hacer al trait autoridad del único container, se rerenderizan e inspeccionan sin errores shell EN, contenido y vacío aislados, editor con total EN y entrada V1 migrada ES en AX 3 sobre iPhone 17 Pro. Las cuatro variantes de la tarjeta —contenido, vacío, sin sesión y solo lectura— se inspeccionan además en Large, XXX Large y AX 5; EN/AX 5 y Dark + Increased Contrast/Large permanecen sin truncado, solapamiento o pérdida de acciones. La regresión visual añade una propiedad de 15 tomos e inspecciona su resumen en español Dark con Large, XXX Large y AX 5: conserva la lista completa y alinea el resto de filas. El editor se inspecciona en las mismas tres escalas y también en Dark + Increased Contrast; AX 5 detecta que una `Image` desnuda podía perder Guardar, y la repetición final con un `Label` icon-only mantiene `xmark`, título y `checkmark` visibles. La matriz editorial anterior cubrió también total desconocido, título largo e iPad landscape. No se ejecutaron VoiceOver, Voice Control, Switch Control, Acceso total con teclado ni Accessibility Inspector. |
| String Catalog | `Localizable.xcstrings` contiene 176 claves, cero valores ausentes en inglés o español, cero comentarios vacíos y cero entradas stale. La única traducción idéntica es `No`, correcta en ambos idiomas. La herramienta de traducción especializada no estaba expuesta; el JSON se editó de forma conservadora y se validó con `jq`. |
| `Scripts/validate-docc.sh` | Ocho escenarios del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente una emisión externa acotada por ADR 0011 para Xcode build `27A5252f`. El archive permanece local y no se publica. |
| Revisiones independientes | Las revisiones iOS/arquitectura, datos/concurrencia, tests, SwiftUI/accesibilidad y el Audit final de `swift-source-style` cierran sin hallazgos. Los revisores hicieron cerrar oráculos de reapertura, autorización y editor, detectaron antes del cierre el segundo container ceremonial de previews y reauditaron el layout adaptativo, la toolbar icon-only y sus labels sobre el snapshot final. |
| Integridad y restauración | `git diff --check` queda limpio, no hay cambios en `project.pbxproj`, test plans, dependencias, targets o entitlements, y no existe contenido staged. Tras el último ajuste visual, Xcode queda restaurado al scheme `MangaLibrary`, plan `Fast` y destino iPhone 17 Simulator vigentes al iniciarlo. |

### Estado de entrega de L2

La implementación se entrega mediante la [PR #50](https://github.com/JFrancoG/MangaLibrary/pull/50), cuya fusión cierra el issue #49. El cierre autorizado incluye retirar después la rama local y remota. R1, R2 y las capacidades Deluxe siguen siendo unidades separadas.

## Simplificación contextual de recursos Color — issue #47

- El [issue #47 — eliminar wrappers Color innecesarios en SwiftUI](https://github.com/JFrancoG/MangaLibrary/issues/47) no tenía issues ni PR equivalentes. La rama `codex/47-remove-redundant-color-wrappers` partió de `main@4df94b8bc480d56bf7d1cf76d4b6021c00672432`, limpio y sincronizado con `origin/main` después de entregar #45. La implementación se entrega mediante la [PR #48](https://github.com/JFrancoG/MangaLibrary/pull/48).
- El inventario completo de 61 archivos Swift localiza 55 wrappers `Color(.token)` en 11 archivos de producción y ninguno en tests. Xcode 27 confirma 40 miembros contextuales seguros para `foregroundStyle`, `background` y `strokeBorder`; los nueve `tint` necesitan `Color.token` para conservar el overload genérico `ShapeStyle`, y los seis `listRowBackground(Color(.canvas))` necesitan `Color.canvas` porque `.canvas` no permite inferir su `View` genérica. Los cuatro `listRowBackground(Color.clear)` existentes expresan esa misma necesidad de tipo y se conservan.
- La implementación sustituye exactamente los 55 wrappers sin cambiar el asset semántico, el modificador, los argumentos, el orden del árbol SwiftUI, los traits o el comportamiento visual intencionado. No modifica tests, assets, String Catalogs, SDD, ADR, arquitectura, configuración Xcode ni `project.pbxproj`, y no introduce una regla textual global.

### Validación local de la simplificación Color

| Herramienta y acción | Resultado |
| --- | --- |
| Inventario y equivalencia estática | Transformación exacta en 11/11 archivos: 55 eliminaciones se corresponden con 40 miembros contextuales, nueve `Color.token` en `tint` y seis `Color.canvas` en `listRowBackground`; quedan cero `Color(.token)` y se conservan cuatro `Color.clear`. `git diff --check` termina limpio. |
| Xcode MCP — diagnósticos focalizados | Los 11 archivos Swift modificados actualizan sus diagnósticos con éxito y devuelven cero incidencias. |
| Xcode MCP — build | Tras corregir los nueve `tint`, build-for-testing de `ReleaseGate` aprobado en 0,711 s sobre iPhone 17 Pro Simulator con iOS 27; cero warnings o errores en el log estructurado. |
| Xcode MCP — `ReleaseGate` | En el snapshot corregido, los 198 casos Swift Testing aprueban en las dos ejecuciones completas. La primera queda en 201/202 porque el smoke histórico de registro no encuentra `tab.account` tras lanzar la app y aprueba 1/1 al repetirlo; la segunda queda en 200/202 por el mismo fallo de arranque en los dos smokes de Cuenta, que aprueban juntos 2/2 al repetirlos sin cambios. No se realizan más repeticiones UI ni se presenta el gate como 202/202 limpio. |
| Xcode MCP — previews | Antes de la corrección de overload, 16/16 snapshots representativas se renderizan e inspeccionan sin errores para shell, Cuenta autenticada, Catálogo y detalle: iPhone en Light/Large, Dark/XXX Large y Dark + Increased Contrast/AX 5, además de iPad en Light + Increased Contrast/Large. La corrección final conserva los mismos recursos y el overload original, compila limpia y no vuelve a renderizarse para evitar validación UI desproporcionada. No se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado o Accessibility Inspector y no se atribuye esa cobertura. |
| Revisiones independientes | Las reauditorías iOS, SwiftUI/accesibilidad y `swift-source-style` cierran sin hallazgos sobre el diff Swift final `75ad23e…`. La revisión SwiftUI detecta antes del cierre que nueve miembros desnudos en `tint` seleccionaban `tint(Color?)`; la corrección a `Color.token` restaura el overload genérico `tint<S: ShapeStyle>` del código original. El `ReleaseGate` UI no limpio permanece documentado como limitación ajena al diff, no como gate completo superado. |
| Restauración Xcode | Scheme `MangaLibrary`, destino físico iPhone 11 y plan `Fast` restaurados y verificados después de la validación. |

La implementación se versiona inicialmente en `4dbfeed` y se entrega mediante la [PR #48](https://github.com/JFrancoG/MangaLibrary/pull/48), cuya fusión cierra el issue #47. El cierre autorizado incluye retirar después la rama local y remota.

## Normalización histórica de layout Swift — issue #45

- El [issue #45 — normalizar el layout Swift histórico](https://github.com/JFrancoG/MangaLibrary/issues/45) no tenía duplicados. La rama `codex/45-normalize-swift-source-style` partió de `main@5a78084c6c2a`, limpio y sincronizado con `origin/main` después de entregar L1. La implementación se entrega mediante la [PR #46](https://github.com/JFrancoG/MangaLibrary/pull/46).
- El normalize repositorio-wide de `$ios-development-kit:swift-source-style` inventaría 61/61 archivos Swift y modifica 44: 30 de aplicación, 13 de tests y uno de UI tests. Una segunda auditoría exhaustiva corrige omisiones sistemáticas de la primera pasada en previews, result builders, llamadas anidadas, tests y fixtures; ningún archivo o categoría queda exento y cada construcción se juzga de forma independiente. Se conservan verticales closures, function types, construcciones de cuatro o más argumentos, condiciones complejas y excepciones donde el formato horizontal superaría 120 columnas o reduciría claridad.
- El cambio es exclusivamente lexical: no modifica tokens, strings, comentarios, interpolaciones, operadores, overloads, orden de evaluación o comportamiento. Tampoco cambia `project.pbxproj`, assets, String Catalogs, contratos, arquitectura, persistencia o tests. La simplificación contextual de wrappers como `Color(.brandPrimary)` quedó expresamente fuera de esta entrega y se aborda como unidad semántica separada mediante el [issue #47 — eliminar wrappers Color innecesarios en SwiftUI](https://github.com/JFrancoG/MangaLibrary/issues/47).

### Validación local de la normalización

| Herramienta y acción | Resultado |
| --- | --- |
| Integridad Swift | Los 44 archivos coinciden con `HEAD` al eliminar whitespace. Ambos snapshots parsean y producen la misma salida canónica de `swift-format` con 120 columnas y sin conservar saltos existentes; no cambian literales, comentarios, identificadores, firmas, operadores ni puntuación. El diff Swift es `+487/-1632`, con SHA-256 `06bb784f0c252f09d3cbde848690ca7d97e28a3968b9503f64465daab7905251`. |
| Xcode MCP — build | Build-for-testing final de `ReleaseGate` aprobado en 3,711 s sobre iPhone 17 Pro Simulator con iOS 27. El log estructurado contiene cero warnings y cero errores. |
| Xcode MCP — `ReleaseGate` | El snapshot final ejecuta y aprueba 202/202 casos: cero fallos, skips, expected failures o casos no ejecutados. |
| Revisiones independientes | La reauditoría final de estilo cierra sin hallazgos después de adjudicar los 41 candidatos del detector de recall; permanecen solo excepciones justificadas por closures, function types, construcciones de cuatro o más argumentos, cadenas semánticas, predicates y tuplas complejas. La auditoría semántica confirma equivalencia canónica 44/44. La revisión SwiftUI/accesibilidad comprueba estáticamente 39/39 previews afectadas y no encuentra cambios en árboles declarativos, textos, colores, identificadores o semántica. No se renderizan previews ni se ejecutan VoiceOver, Voice Control, Switch Control, Acceso total con teclado o Accessibility Inspector; no se atribuye cobertura runtime. |
| Integridad del repositorio | `git diff --check` queda limpio y no hay archivos staged. Solo permanecen tres líneas visuales superiores a 120: la regex de email y dos fixtures JSON atómicas; las tres son excepciones deliberadas. Xcode queda restaurado al destino físico iPhone 11 y al plan `Fast` encontrados en el preflight. |

La implementación se versiona inicialmente en `b4a54e0` y se entrega mediante la [PR #46](https://github.com/JFrancoG/MangaLibrary/pull/46), cuya fusión cierra el issue #45. El cierre autorizado incluye retirar después la rama local y remota. La limpieza semántica de wrappers `Color(...)` se ejecuta como unidad posterior y separada mediante el [issue #47](https://github.com/JFrancoG/MangaLibrary/issues/47).

## Núcleo SwiftData de Colección L1 — issue #41

- El [issue #41 — L1: núcleo SwiftData de Colección y outbox atómica](https://github.com/JFrancoG/MangaLibrary/issues/41) no tenía duplicados. La rama `codex/41-l1-swiftdata-collection-core` partió de `main@2d5cb06bd879eb2876ea30e93438fe89a33e7df7`; el merge previo solo añadió gobernanza de estilo y no alteró Swift, proyecto o contratos de L1. La implementación se entrega mediante la [PR #44](https://github.com/JFrancoG/MangaLibrary/pull/44).
- `AppComposition.live()` crea un único `ModelContainer` persistente y un único `CollectionMutationActor` sobre ese container. `MangaLibraryApp` conserva ambos durante la vida de la app y adjunta el container al `Scene`; la ruta sintética de UI crea una sola composición equivalente en memoria. No se añade un singleton global ni un service locator.
- `MangaLibrarySchema.V1` declara versión `1.0.0`, modelos anidados y un `SchemaMigrationPlan` explícito sin etapas porque no existe un esquema de producto anterior. La configuración desactiva explícitamente App Group y CloudKit. Los aliases vigentes permiten usar los tipos actuales sin hacer mutable retrospectivamente el esquema V1.
- Colección refuerza la identidad compuesta usuario + manga y persiste volúmenes propios canónicos, progreso independiente, total conocido, estado completo, último snapshot confirmado y tombstone. Outbox conserva UUID, identidad compuesta, secuencia monotónica, estado deseado, los siete estados normativos, reintento y tombstone, con constraints de unicidad propios.
- `CollectionMutationActor.apply` recibe comando y UUID por valor `Sendable`, valida identidad, total, propiedad, lectura y colección completa, y devuelve solo un snapshot por valor. Una única transacción actualiza o crea Colección y crea o coalesce exclusivamente la operación `queued` de la misma pareja. Una operación `sending` permanece intacta y la siguiente intención conserva orden independiente. Cualquier validación, cancelación observada, agotamiento de secuencia, colisión de UUID o fallo de persistencia ejecuta rollback explícito.
- La implementación no introduce Repository, UseCase, protocolos, mappers o stores ceremoniales. Tampoco incorpora `@Query`, UI de Colección, worker, reconciliación remota, requests, entitlements, App Group, WidgetKit o watchOS.

### RED / GREEN y validación local de L1

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | El RED inicial falló al compilar por la ausencia deliberada de esquema, modelos, comando y actor. GREEN ejecuta 21 invocaciones focales con un `ModelContainer` V1 real y aislado en memoria por caso, y verifica el resultado desde otro `ModelContext`: 21/21 aprobadas en el iPhone 11 físico con iOS 27. |
| Invariantes y aislamiento | Se cubren identidad de manga, total y volúmenes positivos, límites del total, orden y deduplicación, lectura independiente, semántica completa, cambios de total incompatibles, unicidad del constraint, dos usuarios con el mismo manga y un usuario con mangas distintos. |
| Outbox y atomicidad | Se prueban coalescencia con UUID estable y secuencia creciente, preservación de `sending`, nueva `queued`, colisión de UUID entre identidades, concurrencia serializada, rollback postmutación por agotamiento de secuencia y un guardado posterior limpio. La cancelación se caracteriza antes del commit; no se introduce un hook de producción ni un test dependiente de timing para forzar exactamente el checkpoint posterior a la mutación. |
| Xcode MCP — build y `ReleaseGate` | Build-for-testing final aprobado en 2,259 s con warnings como errores. `ReleaseGate` aprueba 202/202 en iPhone 17 Pro Simulator con iOS 27: cero fallos, skips, expected failures o casos no ejecutados. Una repetición final obtiene 201/202 por el smoke histórico de alta de Cuenta, que aprueba 1/1 al repetirlo sin cambios; los 21 casos L1 pasan en ambas ejecuciones completas. En el destino físico, L1 aprueba 21/21 focales; el gate completo obtiene 191/195 porque tres tests históricos de color intentan leer desde el dispositivo un JSON del checkout y otro smoke de Cuenta falla su aserción. Ninguno de esos fallos pertenece a L1. |
| `Scripts/validate-docc.sh` | Ocho escenarios del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011. El archive permanece local y no se publica. |
| Planes y clasificación | La suite usa el tag `integration`. El plan `Integration` descubre las declaraciones nuevas pero las mantiene deshabilitadas por la regresión transversal ya registrada; no se presenta como una ejecución independiente. `ReleaseGate` sí las habilita y ejecuta. |
| Revisiones independientes | Arquitectura, SwiftData, concurrencia y composición cierran sin hallazgos. La revisión de tests detectó y cerró cobertura de mangas distintos, `sending` y bordes de total/lectura; conserva como límite honesto el checkpoint exacto de cancelación postmutación. El Audit final de `swift-source-style` cierra sin hallazgos en los seis Swift de L1. |

### Estado de entrega de L1

La implementación se versiona inicialmente en `f2b0b10` y se entrega mediante la [PR #44](https://github.com/JFrancoG/MangaLibrary/pull/44), cuya fusión cierra el issue #41. El cierre autorizado incluye retirar después la rama local y remota. L2 y cualquier integración remota o Deluxe requieren unidades y autorizaciones posteriores.

## Corrección de persistencia de sesión — 2026-09-01

- Durante el login manual posterior al alta, el diagnóstico local saneado alcanzó la activación de sesión y registró `stage=write-ledger` con `code=file-system-failure`. Esa evidencia sitúa el fallo histórico en la escritura del ledger de Application Support, después del pipeline remoto refresh → access → `/me`; no registra status HTTP, email, credenciales, tokens, payloads ni rutas privadas.
- La corrección posterior no reescribe la entrega original de S1 mediante la PR #34, documentada más abajo. Sustituyó entonces el ledger y los bundles Keychain V1 por un único ítem Keychain V2 `WhenUnlockedThisDeviceOnly`, no sincronizable y con `kSecAttrAccount = current-session`, fijo y no identificador. Su valor versionado reunía UUID, generación, access y refresh con sus expiraciones; no persistía email, contraseña o roles. La limpieza también retiraba el namespace Keychain V1 conocido. ADR-0019 y la corrección #58 sustituyen después esta autoridad dual por el JWT único y V3 sin reescribir la evidencia histórica de esa entrega.
- Login activa una generación únicamente después de guardar el registro completo. Refresh reemplaza el mismo ítem solo si continúa perteneciendo a la generación esperada y conserva el refresh vigente; un fallo de escritura deja intacta la sesión anterior.
- Logout relee y compara UUID y generación antes de borrar. Solo publica `signedOut` cuando la eliminación condicionada termina; un fallo conserva la sesión activa y permite repetir logout. Una eliminación o refresh tardíos de A se convierten en no-op cuando B ya es la autoridad.
- Un refresh expirado o rechazado permanentemente deja de autorizar inmediatamente la generación en memoria y proyecta `authenticationRequired(userID)`. Después intenta retirar su registro; si Keychain falla, la incidencia permanece visible y el proceso no vuelve a entregar el access rechazado, aunque el envelope residual solo podrá distinguirse tras relanzar mediante otra revalidación remota. Sin registro, la restauración termina en `signedOut`.
- Las pruebas actualizadas separan capacidades deterministas y Keychain sintético: cubren escritura completa, reemplazo V2 con un solo ítem, atributos no identificadores, corrupción fail-closed, indisponibilidad sin falsa salida, refresh condicionado, borrado reintentable, limpieza del namespace legacy y protección frente a efectos tardíos. No usan cuentas, tokens o red live.

### Validación de la corrección de sesión

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing — RED / GREEN | Las regresiones reprodujeron que persistían varias generaciones, que un rechazo permanente podía seguir entregando la sesión si fallaba su limpieza y que el envelope residual impedía una nueva autenticación. GREEN conserva un solo registro V2, invalida inmediatamente la generación rechazada y permite sustituir únicamente ese residual exacto. Las caracterizaciones finales añaden relanzamiento con registro presente y ausente, cancelación posterior al commit de borrado y exclusión determinista de un login B mientras logout elimina A. |
| Xcode MCP — build y `ReleaseGate` | El snapshot final compila con warnings como errores y ejecuta 181/181 casos en iPhone 17 Simulator con iOS 27: cero fallos, skips, expected failures o casos no ejecutados. |
| Xcode MCP — iPhone 11 físico | 30/30 casos de sesión aprobados en iOS 27. Incluyen el propietario de sesión, serialización, fallos inyectados y el service Keychain V2 sintético con atributos protegidos; no usan credenciales, cuenta o red live. El build normal y el lanzamiento del producto se repiten después del gate para dejar instalada la versión comprobada. |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y exactamente la emisión externa autorizada por ADR 0011. El archive permanece local y no se publica. |
| Revisiones independientes | La revisión SwiftUI/accesibilidad no encuentra regresiones en Cuenta. La revisión iOS cierra la reutilización del token rechazado, la reautenticación sobre un residual exacto, los inicializadores redundantes y la exclusión A/B; conserva como límites explícitos el relanzamiento offline tras un borrado fallido y los artefactos inertes de instalaciones anteriores. |

La instalación física demuestra build, lanzamiento y las integraciones sintéticas
anteriores; no demuestra por sí sola login, logout, AutoFill, dispositivo bloqueado,
VoiceOver, Voice Control, Switch Control, Acceso total con teclado, landscape o
multitarea. El propietario confirmó por separado un login live correcto; no se ha
comprobado manualmente el logout ni se registran datos de esa cuenta.

## Formularios de credenciales S2.2 — issue #39

- La implementación se versiona inicialmente en `190dea2` y se entrega mediante la [PR #40](https://github.com/JFrancoG/MangaLibrary/pull/40), cuya fusión cierra el [issue #39 — S2.2: completar Cuenta, alta HTTP y sesión segura](https://github.com/JFrancoG/MangaLibrary/issues/39); el cierre autorizado incluye retirar después la rama local y remota.
- La rama `codex/39-s22-credential-forms` nació desde `main@289fff7ad54c50b5459a9d834bcdec97875694b5`. Antes del primer commit, el issue se reconcilió con HTTP, Keychain, logout, estado autenticado y el criterio final `.fitted` aprobados durante la validación.
- SDD 01 v1.4 y SDD 04 v1.13 mantienen una gramática conservadora de email compartida y definen una instancia observable por presencia de cada formulario. ADR 0017 versiona la frontera de respuesta HTTP con status y conserva el resto de decisiones adaptativas de ADR 0015. Login exige contraseña no vacía y alta conserva el mínimo de ocho caracteres; ninguna entrada inválida inicia trabajo remoto.
- `AccountModel` conserva la política tipada y la autoridad compartida de sesión/workflow. `SignInViewModel` y `RegisterViewModel` poseen borradores, presentación de errores, visibilidad, intención de foco, tarea y limpieza; las Views conservan bindings y el adaptador `@FocusState`. Cada modelo es una instancia por presencia de pantalla creada y retenida con `@State`; `AccountRoute` continúa siendo solo un valor de navegación.
- `SecureField` y `TextField`, ambos de SwiftUI, comparten el mismo `Binding` y `textContentType`; casos de foco diferenciados trasladan el foco modelado al alternar presentación oculta y visible sin introducir UIKit. La credencial desactiva capitalización y autocorrección y continúa limpiándose al enviar o abandonar.
- Iniciar sesión y Crear cuenta usan acciones primarias nativas, grandes, centradas y ajustadas al contenido mediante `.buttonSizing(.fitted)`, sin fijarlas al borde inferior ni conservar el fondo automático de la fila. Crecen con Dynamic Type y mantienen los márgenes de iOS sin imponer un ancho o una altura rígidos. Email y contraseña comparten una superficie de al menos 48 pt, radio continuo de 12 pt y `ControlBorder`; el control de visibilidad conserva un objetivo mínimo de 44 pt. Inglés y español, previews y los dos smokes sintéticos existentes cubren la superficie sin añadir un quinto recorrido UI.
- El propietario realizó manualmente un alta live en el iPhone 11 y observó `201 Created`, coherente con el enunciado pero no con el OpenAPI vivo, que continúa declarando solo `200` con `integer/int64`. No se registra email, `App-Token`, body ni otro dato de la cuenta. `HTTPClient` conserva su API de status único y añade una respuesta validada para que Registro acepte exactamente `200` y `201`: el primero exige el `Int64` publicado y el segundo confirma sin depender de un body no caracterizado; `202` y cualquier otro status siguen sin confirmar.
- La incertidumbre real se presenta una sola vez dentro de Crear cuenta, sin código HTTP ni detalle técnico redundante. Sus dos acciones forman el único par contiguo del flujo: `ViewThatFits` las presenta con igual reparto horizontal cuando caben y las refluye centradas y ajustadas al contenido cuando la localización o Dynamic Type necesitan una columna. Volver muestra el landing inicial de Cuenta sin borrar la protección del workflow; al entrar otra vez en Crear cuenta reaparece el resultado y solo la acción explícita de reintento permite preparar otro `POST`.
- El estado autenticado deja de presentar datos y logout como filas automáticas de `Form`: muestra el estado de sesión, el email seguro en una tarjeta vertical y cualquier aviso en una tarjeta independiente. `Cerrar sesión` continúa siendo un `Button(role: .destructive)` nativo y prominente mediante `DangerFill`/`OnDanger`, pero queda solo con texto, centrado y `.fitted`, igual que las acciones aisladas de login y alta. El contenido conserva scroll en Dynamic Type y un ancho legible centrado en iPad. Las previews sintéticas añaden los casos sin email y con aviso sin exponer una cuenta real.
- Codex y las pruebas herméticas no repiten la escritura live ni ejecutan login o Keychain de producción. No se modifica SwiftData, Colección u outbox y L1 no se ha iniciado.

### RED / GREEN y validación local de S2.2

| Herramienta y acción | Resultado |
| --- | --- |
| Swift Testing focal y `ReleaseGate` | El RED inicial falla porque aún no existen los dos ViewModels. Un segundo RED demuestra que `submit → disappear` inmediato podía iniciar login remoto; el guard de cancelación previo a `operations.login` lo cierra. La regresión adicional reproduce el `201` como `.statusCode(201)` mientras el control `202` ya permanece sin confirmar; después de separar status y bytes, las 16 declaraciones focales de transporte/alta aprueban. La ejecución final posterior al rediseño autenticado aprueba 181/181 en iPhone 17 Simulator, iOS 27, sin fallos, omisiones o casos no ejecutados. `Fast` e `Integration` siguen descubriendo 0 habilitados y no se presentan como ejecuciones independientes. |
| Xcode MCP — UI | El plan `UI` final aprueba 4/4 en el iPhone 11 físico con iOS 27; incluye los dos recorridos sintéticos de Cuenta y la comprobación del nuevo botón de logout como control pulsable de al menos 44 pt. Tras retirar su icono y adoptar el ancho ajustado común, ambos recorridos de Cuenta se repiten de forma focal y aprueban 2/2. Cubren además errores inline vacíos, permanencia del teclado al volver a ocultar, conservación del contenido en alternancias enfocadas y sin foco y edición antes y después de un recorrido oculto-visible. No usan cuentas, red, Keychain o almacenamiento live. |
| Xcode MCP — build y diagnósticos | El build normal definitivo tras el ajuste de botones aprueba en 2,435 s sobre el iPhone 11 físico con iOS 27, sin warnings ni errores; el build físico anterior posterior al rediseño aprobó en 2,626 s y el control previo en iPhone 17 Simulator en 1,405 s. Los diagnósticos focales de `AccountRootView`, `SignInView` y `RegisterView` quedan en cero después del cambio. El gate DocC contiene únicamente la emisión externa exacta de App Intents admitida por ADR 0011, nunca un warning de Swift, Clang o DocC. |
| Xcode MCP — previews | Login, alta y el estado autenticado se repiten tras adoptar botones `.fitted`: en iPhone 17 Pro, español Large, XXX Large y AX5 confirma acciones aisladas centradas, de ancho moderado y sin truncado; AX5 se inspecciona además en Dark y contraste aumentado. El par de recuperación usa columna ajustada en portrait y reparto horizontal equivalente en landscape. Las tres acciones aisladas se vuelven a inspeccionar también en iPad Pro 13-inch tras el último ajuste y conservan ancho moderado y centrado. Se mantiene la matriz anterior del estado autenticado en inglés/español, Large/XXX Large/AX5, portrait/landscape, Light/Dark y contraste aumentado. Las snapshots no prueban interacción ni tecnologías de asistencia. |
| Localización e integridad | String Catalog JSON válido: 106/106 claves activas completas en inglés y español, sin valores incompletos ni entradas stale; se retiran diez claves obsoletas de la antigua máquina de logout. `git diff --check` y los enlaces Markdown locales quedan limpios; el diff no incorpora secretos, credenciales o datos personales. `project.pbxproj` no cambia. |
| `Scripts/validate-docc.sh` | La repetición final aprueba 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011. No se publica el archive. |
| Revisiones independientes | La revisión documental corrige el alcance de ARCH-013/021 y el propietario de Cuenta. Arquitectura/iOS detecta y cierra la carrera de cancelación previa, dos oráculos de limpieza insuficientes, el test ausente del pipeline `200`, la conformance `Sendable` redundante y la cadena normativa de ADR. La revisión final iOS no encuentra desviaciones P0–P2 y su P3 documental queda resuelto al sincronizar SDD, localización y gates; SwiftUI/accesibilidad cierra sin hallazgos tras inspeccionar iPhone e iPad. El issue #39 queda reconciliado antes del primer commit con HTTP, Keychain, logout, estado autenticado y el criterio final `.fitted`. No se extrapolan previews o UI tests a VoiceOver, Voice Control, Switch Control o Acceso total con teclado. |

El plan físico acredita cuatro recorridos UI sintéticos, incluidos los dos de Cuenta. La observación manual adicional del propietario acredita el status `201` de un alta real y un login live posterior correcto; no caracteriza el body, el almacenamiento interno ni el logout. La implementación no valida AutoFill o gestor de contraseñas real, tecnologías de asistencia, interacción runtime en landscape o multitarea. `SecureField` no expone a SwiftUI la posición de cursor o selección, por lo que el gate acredita contenido y foco modelado al alternar, no una posición concreta del cursor. Esas exclusiones no se presentan como evidencia superada. La PR #40 entrega el corte con el cierre completo autorizado por el propietario.

## Acciones accesibles de Cuenta S2.1 — issue #37

- Tracker: [GitHub Issue #37 — S2.1: mejorar jerarquía y áreas táctiles de acceso en Cuenta](https://github.com/JFrancoG/MangaLibrary/issues/37), cerrado por la entrega.
- Rama de entrega: `codex/37-account-actions-accessibility`, creada desde `main@45ce7a0c7db74c726049cdeb9ec0909e764b720f` limpio y sincronizado.
- La implementación se versiona inicialmente en `e19c7f1` y se entrega mediante la [PR #38](https://github.com/JFrancoG/MangaLibrary/pull/38), cuya fusión cierra el issue #37; el cierre autorizado incluye retirar después la rama local y remota.
- `AccountRootView` conserva dos `Button` semánticos y sus rutas existentes. Iniciar sesión mantiene jerarquía primaria y Crear cuenta pasa a secundaria bordeada; ambas usan texto `.headline` y control grande y flexible. El frame runtime estándar queda acotado entre 44 y 56 pt de alto, sin sumar otro mínimo a la etiqueta. La acción primaria aplica la pareja semántica `OnBrandPrimary` sobre `BrandPrimary` para adaptar el contraste a cada apariencia. El prompt `Don't have an account?` / `¿No tienes cuenta?` usa `.body`, aparece solo cuando el alta está disponible y el ajuste visual final conserva 16 pt extra tras la acción primaria y 16 pt entre el prompt y Crear cuenta.
- El smoke de login existente incorpora el oráculo independiente de pulsabilidad, tamaño y orden vertical; no se añade un quinto recorrido UI. El String Catalog queda completo en 113/113 claves inglesas y españolas.
- SDD 06 y ADR 0015 continúan siendo la autoridad aplicable y no cambian. No se modifica modelo, sesión, red, configuración, persistencia ni navegación; no se realiza login, alta o escritura live y L1 no se ha iniciado.

### RED / GREEN y validación local de S2.1

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — RED / GREEN focalizado | El primer RED midió `28,0 pt`, menos de los `44 pt` exigidos. La primera GREEN sumó el mínimo de la etiqueta al control grande y el nuevo RED de calibración midió `74,0 pt`, por encima del máximo estándar de `56 pt`. Tras retirar ese doble escalado y aplicar el espaciado final, login y alta sintéticos aprueban 2/2: ambas acciones permanecen pulsables y entre 44 y 56 pt, y Crear cuenta conserva al menos 12 pt respecto al prompt. |
| Xcode MCP — build y diagnósticos | Build normal final aprobado en 1,748 s sobre iPhone 17 Simulator, iOS 27; log de build, Issue Navigator y diagnósticos focales de View y UI test quedan en cero warnings y cero errores. |
| Xcode MCP — `ReleaseGate` | 166 aprobadas, 0 fallos y 1 omisión de 167, limitada al test preexistente que requiere un dispositivo físico. No se atribuye a S2.1 una ejecución independiente de `Fast` o `Integration`. |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador aprobados; archive Release generado con warnings DocC como errores y exactamente la emisión externa acotada por ADR 0011. No se publica el archive. |
| Xcode MCP — previews | Estado sin sesión final inspeccionado en iPhone 17 Pro con inglés y español Large, español XXX Large y AX5; la corrección cromática final se volvió a renderizar en español Large bajo Light/Dark × contraste estándar/aumentado y conserva la pareja adaptativa clara u oscura. En iPad Pro 13-inch (M5) se inspeccionó español Large y AX5. Las acciones quedan completas en iPad AX5 y continúan bajo el primer viewport dentro del `ScrollView` en iPhone AX5; la preview no acredita desplazamiento runtime, estados pulsado/deshabilitado/foco ni tecnologías de asistencia. |
| Localización e integridad | String Catalog JSON válido y completo en 113/113 claves inglesas y españolas, sin textos vacíos ni comentarios ausentes; `git diff --check` limpio. El diff no incluye proyecto, configuración, sesión, red, persistencia, secretos ni datos personales. |
| Revisiones independientes | Arquitectura, alcance/privacidad y SwiftUI/accesibilidad cierran sin hallazgos P0–P3. La primera revisión visual detectó contraste insuficiente del texto blanco sobre `BrandPrimary` claro; se corrigió aplicando `OnBrandPrimary` y la reauditoría de las cuatro apariencias resolvió el P2 sin regresiones. La inspección estática y las previews no se presentan como evidencia runtime de VoiceOver, Voice Control, Switch Control o Acceso total con teclado. |

La evidencia anterior se entrega mediante la PR #38. Al entregarse S2.1, S2.2 quedó como una unidad posterior y separada antes de L1; su implementación local actual se registra arriba y nunca formó parte de S2.1.

## Alta de usuario S2 — issue #35

- Tracker: [GitHub Issue #35 — S2: implementar alta de usuario con App-Token y enlazar login](https://github.com/JFrancoG/MangaLibrary/issues/35), cerrado por la entrega.
- Rama de entrega: `codex/35-s2-user-registration`, creada desde `main@422ffbb6abd723f41899d0d047417d9777ad4158`, limpio y sincronizado con `origin/main` al comenzar.
- La implementación se versiona inicialmente en `dd0f139` y se entrega mediante la [PR #36](https://github.com/JFrancoG/MangaLibrary/pull/36), cuya fusión cierra el issue #35; el cierre autorizado incluye retirar después la rama local y remota.
- El propietario aprobó la implementación hermética. `/docs` volvió a descubrir `/openapi/openapi.json`; el contrato vivo y el snapshot coinciden con SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`: `POST /users`, JSON requerido `email/password`, seguridad exclusiva `App-Token` y única respuesta declarada `200` con `integer/int64` opaco.
- `UserRegistrationClient` limita esa cabecera al alta, valida el status mediante el transporte común y descarta el entero después de confirmar el contrato. Configuración ausente, vacía o sin expandir falla antes del loader sin impedir Catálogo o login. `Shared.xcconfig` carga primero el `Local.xcconfig` ignorado y el repositorio conserva solo un ejemplo vacío; Xcode MCP añadió la clave propia al Info.plist del target app.
- En el corte S2, `AccountModel` mantenía separado el estado de sesión S1 del workflow de alta y validaba entonces únicamente email normalizado no vacío y contraseña de ocho caracteres; la política vigente queda ampliada por S2.2 arriba. S2 distingue no enviado, incierto y confirmado, enlaza una sola vez con el login existente y conserva «cuenta creada» si esa segunda fase falla o se cancela. Abandonar un alta no confirmada invalida efectos tardíos; si el login ya empezó, la cancelación reconcilia primero cualquier commit durable de S1. Nunca repite automáticamente el `POST` y una respuesta A tardía no puede iniciar login ni sustituir una sesión B posterior.
- Cuenta ofrece alta solo desde `signedOut`, nunca desde `authenticationRequired`. El formulario nativo usa `.newPassword`, limpia la contraseña antes de suspender y al abandonar, y representa progreso, fallo local, incertidumbre y cuenta creada sin depender solo del color. Inglés y español quedan completos en las 112 claves del String Catalog.
- Previews y UI tests usan composición sintética directa: no leen Info.plist, `App-Token`, Keychain o almacenamiento live y no alcanzan producción.

### RED / GREEN de S2

- RED del cliente: 10 instancias fallaron contra el stub por request ausente, configuración mal clasificada y resultados no tipados. GREEN cubre request exacto, cuatro configuraciones inválidas, status, timeout, payload, cancelación antes y después del transporte y fallo desconocido.
- RED de `AccountModel`: las nuevas caracterizaciones detectaron los stubs en validación, secuencia `register → login`, estados no enviado/incierto/creado y protección de respuesta tardía. GREEN cubre además la cancelación antes de entrar en el modelo y la carrera en la que S1 ya confirmó durablemente la sesión, incluida la traza exacta `register(A), login(B)` cuando A termina después de autenticar B. La suite focal completa de `AccountModel` termina 19/19.
- El primer XCUITest de alta llegó al formulario, pero iOS 27 abrió el panel del generador de contraseña segura y dejó el botón deshabilitado. La automatización final conserva `.newPassword`, cierra condicionalmente esa sugerencia del sistema y aprueba 1/1 el recorrido Cuenta → alta sintética → login S1 → identidad fija.

### Validación local de S2

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build normal final aprobado en 1,237 s sobre iPad Air 11-inch (M4), iOS 27; Issue Navigator y log de build quedan en cero warnings y cero errores. El target efectivo conserva Swift 6, concurrencia estricta completa, aislamiento predeterminado `nonisolated`, warnings como errores y ningún entitlement. |
| Xcode MCP — pruebas focalizadas | `AccountModelTests` finaliza 19/19. `ReleaseGate` ejecuta además 11/11 invocaciones de `UserRegistrationClientTests`, incluidas cuatro configuraciones inválidas y cancelación pretransporte con cero requests. |
| Xcode MCP — UI | El único smoke nuevo aprueba 1/1 con bootstrap Debug sintético y sin red o persistencia live, y vuelve a pasar dentro del gate final. |
| Xcode MCP — previews | Formulario inspeccionado en iPad y en iPhone con Dynamic Type XXX Large; incertidumbre en español e iPad con AX5 conserva texto y ambas acciones visibles. La preview base se vuelve a renderizar con locale inglés explícito. Ninguna preview acredita VoiceOver físico. |
| Localización y privacidad | JSON válido, 112/112 claves con inglés y español; no se incorpora un token utilizable, cuenta real, payload sensible o log de credenciales. |
| Gate completo | `ReleaseGate`: 166 aprobadas, 0 fallos y 1 omisión de 167, limitada al test preexistente «Requires a physical iOS device». DocC genera el archive con warnings como errores y solo la emisión externa exacta de ADR-0011. Integridad documental limpia y las revisiones finales de arquitectura/concurrencia, SwiftUI/accesibilidad y contrato/privacidad cierran sin hallazgos P0–P3 después de corregir los detectados. |

No se atribuye a S2 una ejecución independiente de `Fast` o `Integration`: esos
planes conservan la regresión transversal de descubrimiento ya registrada. Los
comportamientos afectados sí quedan incluidos en `ReleaseGate`.

Durante la implementación y entrega original de S2 no se realizó ningún alta,
login o escritura live; la observación manual posterior de `201` se registra en
S2.2 sin reescribir aquella evidencia histórica. S2 no incorpora SwiftData,
`ModelContainer`, outbox, Colección, sincronización, entitlements, recuperación o
eliminación de cuenta, App Group, WidgetKit ni watchOS. La eliminación de cuenta
deberá resolverse antes de distribuir una app que permita crearla; no amplía este
issue. La evidencia visual no demuestra VoiceOver, Voice Control, Switch Control
o Acceso total con teclado en runtime.

## Identidad y sesión dual S1 — issue #33

- Tracker: [GitHub Issue #33 — S1: implementar identidad estable y sesión dual recuperable](https://github.com/JFrancoG/MangaLibrary/issues/33), cerrado por la entrega.
- Rama de entrega: `codex/33-s1-dual-session`, creada desde `main@0c250d423244cadaf15280758e06c452d2790f41`, limpio y sincronizado con `origin/main`.
- La implementación se versiona en `f1c8629` y se entrega mediante la [PR #34](https://github.com/JFrancoG/MangaLibrary/pull/34), cuya fusión cierra el issue #33; el cierre autorizado incluye retirar después la rama local y remota.
- El propietario aprobó continuar el 2026-08-30. Xcode MCP confirmó `MangaLibrary.xcodeproj` en Xcode Beta, scheme `MangaLibrary`, iOS 27, los tres targets, los cuatro planes y cero issues de navegador antes del primer cambio.
- `/docs` volvió a descubrir `/openapi/openapi.json`; la forma canónica viva conserva el SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`.
- [ADR-0016](adr/0016-versioned-session-ledger-and-keychain-boundary.md) acepta Keychain por generación y un ledger protegido en Application Support como autoridad durable. Persiste solo versión, UUID, generación opcional, revisión, fase y destino de limpieza opcional; no adelanta SwiftData, Colección, App Group, entitlements ni capacidades Deluxe.
- La implementación materializa el cliente de sesión vivo, Keychain y ledger versionados, actor de persistencia, controller de sesión, modelo de Cuenta, estados recuperables, localización, previews y bootstrap UI sintético. No incorpora SwiftData, Colección, sincronización, entitlements ni escrituras live.
- Xcode Beta 27A5252f construye app y tests para iPad Air 11-inch (M4) e iPhone 11, iOS 27, con Swift 6.4. No aparecen warnings de Swift o Clang ni issues estructurados; el full log conserva las tres emisiones externas —una por target— acotadas por ADR 0011, por lo que esta evidencia no acredita aún el Advanced Release Gate limpio. `ReleaseGate` en el simulador produjo 146 invocaciones: 145 pasaron, ninguna falló y se omitió únicamente la comprobación declarada como exclusiva de dispositivo físico. `Fast` continúa mostrando la regresión transversal conocida de 0 habilitados y 117 deshabilitados; no existe una ejecución independiente acreditada de `Integration`, aunque sus comportamientos sí quedaron cubiertos por `ReleaseGate`.
- `Scripts/validate-docc.sh` genera `.build/docc/MangaLibrary.doccarchive` con warnings DocC como errores y admite exactamente la única emisión externa acotada por ADR 0011. No publica el archive.
- En el iPhone 11 físico, una ejecución dirigida con `RunSomeTests` bajo el plan `ReleaseGate` seleccionó sin omisiones el ciclo Keychain sintético por generación y la restauración de `completeFileProtection` del ledger: 2/2 pasaron. La evidencia no incluye credenciales o red reales, lectura con el dispositivo bloqueado ni validación física de accesibilidad.

## Reconciliación de documentación y hoja de ruta — issue #31

- Tracker: [GitHub Issue #31 — Reconciliar documentación y hoja de ruta tras Catálogo C4 y Library Red](https://github.com/JFrancoG/MangaLibrary/issues/31), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/31-reconcile-roadmap-docs`, creada desde `main@1839c296c78cff47f4fd40b7ef51db42a65db64c`, limpio y sincronizado con `origin/main`.
- Esta unidad cierra el estado histórico de C4 y Library Red y sustituye el siguiente paso ya ejecutado por una secuencia operativa explícita para identidad, Keychain, SwiftData, outbox, Colección local y sincronización remota.
- El enunciado permite una colección básica solo local, pero el producto Advanced aprobado identifica cada entrada mediante usuario + manga y no define una colección anónima ni su migración posterior. Por eso S1 precede a la Colección expuesta al usuario.
- No cambia SDD, ADR, OpenAPI ni arquitectura: la hoja de ruta aplica las decisiones vigentes. Tampoco crea el issue de S1, inicia código de producto, ejecuta credenciales o realiza escrituras live.

### Validación documental local

- El diff queda limitado a `README.md`, `CHANGELOG.md` y este registro de progreso; `git diff --check` no encuentra errores y permanecen intactos código, proyecto, SDD, ADR y OpenAPI.
- Los enlaces y anchors locales de los 39 archivos Markdown resuelven sin roturas. El enlace del README alcanza esta hoja de ruta.
- El escaneo acotado de líneas añadidas no encuentra rutas privadas, correos, credenciales, secretos ni tokens.
- Dos revisiones independientes contrastaron Git/GitHub, SDD 00/01/03/04, el enunciado y el OpenAPI vivo. La revisión de alcance detectó el cierre histórico incompleto de C4 y se corrigió con sus commits y PR reales; el read-back final no mantiene hallazgos abiertos.
- No se ejecutan build, tests, previews ni archive DocC porque esta unidad solo modifica Markdown y no cambia comportamiento, configuración o catálogo DocC.

## Library Red ejecutable — issue #29

- Tracker: [GitHub Issue #29 — Implementar Library Red en Asset Catalog y la UI actual](https://github.com/JFrancoG/MangaLibrary/issues/29), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/29-library-red-assets`, creada desde `main@0b398841b64f27071ac22a133b00dd3a72b7c2ce`, limpio y sincronizado con `origin/main` después de entregar C4.
- El JSON canónico materializa 29 color sets universales sRGB opacos. Cada uno contiene Any/Light, Dark, Increased Contrast Light e Increased Contrast Dark; el placeholder `AccentColor` se retira y `BrandPrimary` queda como único origen de identidad cromática.
- `MainShellView` establece el tint global mediante `.tint(Color.brandPrimary)`. La UI con superficie final controlada adopta `Canvas`, `BackgroundElevated`, `Surface`, `SurfaceStrong`, `ControlBorder`, `TextPrimary`, `TextSecondary` y `TextTertiary`. Las filas de `List` y `Form` conservan `.primary`/`.secondary` porque su selección o material final pertenece a SwiftUI; así sus estados nativos no quedan forzados a una pareja opaca que deja de ser cierta durante la interacción.
- Los nombres tipados se generan únicamente para `ColorResource` y SwiftUI mediante `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI`. Así se conserva el nombre normativo `Link` sin colisionar con `UIColor.link` ni renombrar el contrato.
- Por autorización expresa del propietario, Debug y Release sustituyen en el target `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` por `BrandPrimary`. El diff de `project.pbxproj` se limita a esas dos líneas y `actool` recibe ahora `--accent-color BrandPrimary`.
- La validación manual descubrió que el `inspector` adaptado a sheet en compacto no permitía una segunda apertura después de descartarlo con el gesto. `EnvironmentValues.isPresented`, el ciclo de vida del formulario y un nuevo flanco manual tampoco resolvieron de forma válida el cierre real; el ciclo de vida además se dispara al navegar dentro de los pickers. La solución usa la API nativa adecuada en cada tamaño: sheet en compacto e inspector en regular, ambos con el mismo `CatalogFiltersView` y la misma consulta vigente. El `Binding` de la sheet recibe su cierre interactivo sin estado interno adaptado. Un cambio entre clase horizontal compacta y regular cierra explícitamente Filtros y descarta la copia no aplicada, evitando trasladar parcialmente borrador, picker o foco entre hosts con identidades distintas. El botón usa el símbolo sin círculo cuando no hay filtros y conserva el círculo relleno con filtros activos.
- No se añade wrapper cromático, dependencia, endpoint, target, entitlement, persistencia, autenticación, sincronización, gradiente, alpha o material personalizado. No cambian la consulta ni las rutas de navegación y Colección no se inicia como efecto lateral.

### RED / GREEN de Library Red

- RED: las tres caracterizaciones nuevas se escribieron contra `library-color-tokens.json` como oráculo independiente y fallaron 3/3 bajo `ReleaseGate` porque solo existía el placeholder `AccentColor` y faltaban los 29 recursos contractuales. `Fast` no pudo acreditar el RED por la regresión ya registrada de tags heredados en Q1: descubre cero tests habilitados y este issue no modifica los planes.
- La primera compilación GREEN reveló una colisión generada entre el asset normativo `Link` y `UIColor.link`. Limitar la generación al framework SwiftUI conserva `ColorResource`, `SwiftUI.Color` y los 29 nombres exactos sin desactivar los símbolos tipados.
- Retirar `AccentColor` reveló en el gate DocC que el target aún pasaba ese nombre a `actool`. La configuración autorizada lo sustituye por `BrandPrimary` en Debug y Release; el siguiente build confirmó `--accent-color BrandPrimary` y cero warnings.
- GREEN final: las tres pruebas aprueban inventario fuente, ausencia de `AccentColor`, resolución runtime en los cuatro traits, componentes sRGB, opacidad y las 56 parejas por apariencia —224 en total— comparadas con sus umbrales sin redondeo previo.
- RED de presentación: el propietario reprodujo dos veces que, después del arrastre real sobre la sheet, el botón no volvía a presentarla. El primer XCUITest arrastraba sobre el botón Cancelar y produjo un falso GREEN; se corrige para arrastrar desde la propia presentación.
- GREEN de presentación: la sheet compacta posee directamente el estado de su presentación y el inspector regular conserva su columna nativa; ambos reutilizan el mismo formulario. El propietario confirmó manualmente en iPhone que, tras descartarla con el gesto, una única pulsación vuelve a abrir Filtros.

### Validación local de Library Red

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing final aprobado en 5,618 s sobre iPhone 17 Pro; la misma separación sheet/inspector aprobó antes en 5,039 s sobre iPad Air 11-inch (M4), ambos con iOS 27. `CatalogRootView.swift`, `CatalogFiltersView.swift` y `MangaLibraryUITests.swift` muestran cero diagnósticos y el Issue Navigator conserva cero warnings o errores. El helper cromático moderno crea un entorno UIKit con `traitOverrides` y fuerza su actualización mediante `updateTraitsIfNeeded()`, sin inicializadores deprecados ni escapes de aislamiento |
| Xcode MCP — pruebas focalizadas | 3/3 pruebas de `LibraryColorTests` aprobadas: inventario/catálogo fuente, resolución compilada exacta y umbrales de todas las parejas autorizadas |
| Xcode MCP — UI y `ReleaseGate` | El test corregido arrastra la propia sheet y demuestra RED 0/1 tanto con `EnvironmentValues.isPresented` como con el flanco manual; con sheet compacta nativa aprueba 1/1 y el plan UI completo aprueba 2/2 en iPhone 17 Pro. La repetición regular de iPad no devolvió resultado por bloqueo de Xcode MCP, aunque su build-for-testing sí aprobó. El `ReleaseGate` final, posterior a la corrección y a la matriz manual, aprueba 81/81 en iPhone 17 Pro: cero fallos, omisiones o tests no ejecutados |
| Xcode MCP — previews | El shell se inspeccionó en español y tamaño Large en iPad y en iPhone 17 Pro para Light, Dark, Increased Contrast Light e Increased Contrast Dark. En iPhone se inspeccionaron además cuadrícula y detalle en Dark + Increased Contrast. La comprobación final muestra el símbolo sin círculo sin filtros, el círculo relleno con filtros activos y la cabecera regular de iPad intacta. El tint rojo coral, fondos cálidos, superficies, texto y bordes se resuelven de forma coherente en las cuatro apariencias |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011. Ya no existe el warning de `AccentColor` |
| Localización | No se añaden textos visibles; `Localizable.xcstrings` conserva 68/68 claves con valor manual en inglés y español y cero entradas stale |
| Integridad | 29 color sets y ausencia de `AccentColor`; JSON válido; cero colores RGB/HEX hardcodeados en Swift de producción; `git diff --check` limpio y 215 enlaces Markdown locales sin roturas. OpenAPI conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; `project.pbxproj` queda en `c52c7a23ebc51f075ec1f5e83291288e78d28a679f3c019b4b05f4d166c9b735` tras sus dos sustituciones autorizadas |
| Revisiones independientes | Los read-backs de Library Red y la reauditoría final quedan sin hallazgos pendientes. El primer read-back del cierre interactivo rechazó correctamente `onDisappear` porque también responde a la navegación interna de los pickers; el siguiente detectó la pérdida implícita del borrador entre hosts, cerrada mediante cancelación explícita al cambiar de size class. Los revisores no sustituyen la evidencia runtime del propietario |
| Restauración Xcode | Tras el `ReleaseGate` final se restauraron el scheme `MangaLibrary`, el plan `Fast` y el simulador iPad Air 11-inch (M4) con iOS 27 al estado encontrado al comenzar esa comprobación. `Fast` mantiene la limitación conocida de Q1 —0 habilitados y 60 deshabilitados por los tags heredados—; la actualización explícita de diagnósticos de `LibraryColorTests.swift` y el Issue Navigator quedan en cero |

Las pruebas demuestran los recursos opacos y las parejas contractuales; el
propietario confirmó manualmente la reapertura de la sheet corregida. Las previews demuestran composición estática
representativa. El propietario confirmó en modo claro y oscuro que la interfaz permanece
legible y operable al combinar Increased Contrast, Reduce Transparency y Bold
Text, además de los recorridos ya aprobados de VoiceOver, Voice Control y Switch
Control. También confirmó en escala de grises que el contenido y los estados de
Lista, Cuadrícula y Filtros permanecen legibles y distinguibles sin depender solo
del color. Asimismo, aprobó en iPad el recorrido completo con Acceso total con
teclado: el foco permanece visible, Espacio o Retorno activan los controles y no
existen trampas al abrir, recorrer y cerrar Filtros. Esta evidencia no constituye
una medición píxel a píxel de todos los estados nativos ni acredita hardware
físico, que no es una condición de este cambio al no incorporar capacidades que
dependan de él. La matriz manual de Library Red queda completa para el alcance
del issue #29. La implementación `ef770f0` se entregó mediante la PR #30,
fusionada en `f2aaf2b`; el issue quedó cerrado y las ramas local y remota se
eliminaron. Esta entrega no inicia Colección ni otra fase como efecto lateral.

## Catálogo C4 — detalle enriquecido y precarga fluida

- Tracker: [GitHub Issue #27 — Catálogo C4: enriquecer el detalle y anticipar la paginación](https://github.com/JFrancoG/MangaLibrary/issues/27), abierto después de comprobar que no existía un issue o una PR equivalente.
- El cuerpo del issue se reconcilió el 2026-08-28 con la petición actual del propietario, SDD 02 v1.11 y ADR 0015: animación local de escala de la portada, reset de scroll regular, cabecera compactada de iPad y tres botones nativos de toolbar. La descripción anterior del `zoom` de navegación completo ya no figura como plan vigente.
- Rama local: `codex/27-catalog-detail-prefetch`, creada desde `main@76ab2707241ac13b21e3e70b3edaca0383a2b23d`, limpio y sincronizado con `origin/main`.
- El OpenAPI vivo se descubrió desde `/docs` y su forma canónica volvió a coincidir con el snapshot saneado, SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`. Las páginas ya contienen el manga completo necesario y no se añadió una segunda petición de detalle ni se hicieron llamadas funcionales al servicio.
- `Manga` conserva ahora estado editorial, autoría con UUID y rol cerrado, y demografías, géneros y temas con identidad UUID. El cliente tipado trata relaciones requeridas ausentes, UUID inválidos y vocabulario cerrado desconocido como deriva contractual.
- El detalle presenta la portada con una variante propia claramente mayor, estado, autoría, clasificaciones y sinopsis disponibles. La raíz de Catálogo usa un `NavigationStack` tipado por `Manga.ID` en compacto y conserva el `NavigationSplitView` regular; ambas presentaciones derivan de la misma selección. Al abrir en compacto, solo la portada del destino aplica `scaleEffect`: `0,1 → 1,25` con `easeIn` en `0,3 s` y `1,25 → 1` con `easeOut` en `0,08 s`. Ya no existen copia visual, geometría global ni coordinación manual; el regreso conserva el pop nativo y Reduce Motion usa `crossFade` sin escala. En regular no se repite la animación y un nuevo `Manga.ID` restablece inmediatamente el scroll arriba sin recrear el detalle ni forzar el foco.
- C3 conserva su inspector adaptativo, presentado como sheet en compacto. En iOS 27 compacto, Filtros ocupa un `ToolbarItem` propio; un `ToolbarSpacer(.fixed)` lo separa del `ToolbarItemGroup` de Lista y Cuadrícula. En regular, Filtros permanece arriba y la pareja de layout pasa a una franja propia para que el título de la columna no se trunque; el título usa modo inline para no apilar además la reserva expandida del título grande sobre la búsqueda. Se retiran el menú de desbordamiento de un único elemento y el `Picker` segmentado. El formulario expone conjuntamente título, modo «Contiene/Empieza por», nombre y apellidos de autoría y selección múltiple de demografía, género y tema. El servidor combina las dimensiones mediante AND; no existe una búsqueda genérica por palabra fuera de los campos declarados.
- La lista muestra título y todos los nombres de autoría disponibles con formato sensible al locale; el bloque textual se centra verticalmente junto a la portada y conserva reflow en tamaños de accesibilidad. La cuadrícula muestra solo portada y título, reserva dos líneas tipográficas centradas y trunca el exceso, por lo que todas las tarjetas mantienen la misma altura sin reducir la fuente.
- Por decisión del propietario durante la implementación, la siguiente página se agenda al aparecer cualquiera de los dos últimos resultados, no cinco. La petición sigue siendo idempotente y el footer existente conserva progreso, error recuperable y fin.
- No se añadieron Repository, UseCase, Store, router global, dependencia externa, endpoint, target, entitlement ni cambio de configuración.

### RED / GREEN de C4

- RED de contrato: el primer build-for-testing falló al exigir en los tests el mapping de estado, autoría y las tres taxonomías, además de deriva por relación ausente, UUID inválido y enum desconocido.
- GREEN de contrato: el DTO mínimo se amplió solo con los campos ahora presentados y todos los valores se traducen a tipos de producto antes de llegar a SwiftUI. La caracterización parametrizada cubre los cuatro roles y los cinco estados válidos, además de mantener separados los casos desconocidos que representan deriva.
- La caracterización de paginación se escribió antes del cambio, pero su RED no se aisló en ejecución porque el build conjunto ya estaba detenido por los nuevos tipos de `Manga`. Tras la aclaración del propietario, el umbral se fijó en los dos últimos elementos y el caso focalizado se volvió a ejecutar 1/1.
- GREEN de paginación: el elemento anterior al umbral no agenda; cualquiera de los dos últimos agenda exactamente la página preparada y las apariciones repetidas no duplican trabajo.
- RED de navegación: el propietario confirmó primero que el `zoom` no se producía en el split compacto y después que la alternativa geométrica no daba un resultado runtime convincente. La prueba visual también mostró el `Picker` segmentado anidado con la acción de Filtros en una cápsula poco clara.
- GREEN de navegación y presentación: lista y cuadrícula compactas vuelven a `NavigationLink(value:)` dentro de un `NavigationStack` cuyo path `[Manga.ID]` se deriva de `selectedMangaID`; la portada del destino posee el único estado de animación. La toolbar declara un corte fijo entre Filtros y el grupo de layout. Lista conserva título y autoría centrados respecto a la portada; cuadrícula reserva dos líneas de título y elimina metadata secundaria para igualar tarjetas. La cabecera regular mantiene búsqueda y controles en franjas propias, pero cambia únicamente el título de `.large` a `.inline` para retirar la reserva vertical expandida. El detalle regular usa una `ScrollPosition` local y vuelve sin animación al borde superior solo cuando cambia `Manga.ID`, sin reiniciar el árbol completo. Estos ajustes editoriales no poseen una aserción unitaria significativa; se validan mediante compilador, previews y recorrido UI, mientras que la secuencia temporal de escala permanece excluida de la evidencia runtime. ADR 0015 supersede la cláusula incompatible de ADR 0014 sin cambiar sus decisiones de composición, transporte o dobles.

### Validación local de C4

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing del snapshot final aprobado en 2,981 s sobre el simulador iPad Air 11-inch (M4); `CatalogRootView.swift` muestra cero diagnósticos y el Issue Navigator contiene cero warnings |
| Xcode MCP — `ReleaseGate` | 77/77 casos aprobados sobre el simulador iPad Air 11-inch (M4): cero fallos, skips, expected failures o casos no ejecutados |
| Xcode MCP — previews | Lista y cuadrícula compactas inspeccionadas en español con Large, XXX Large y AX5; la cuadrícula también en modo oscuro con contraste aumentado, y ambas presentaciones en split regular de iPad. La lista muestra título y uno o varios autores centrados junto a la portada y refluye en AX; la cuadrícula conserva alturas uniformes, centra títulos cortos y trunca los largos dentro de dos líneas reservadas. El detalle regular final se volvió a renderizar en iPad con Large y con español AX5 desde el borde superior. La cabecera regular final se inspeccionó de nuevo en español con Large, XXX Large y AX5: título inline, acciones, búsqueda y selector permanecen visibles y desaparece la reserva expandida anterior |
| Recorrido de detalle | El smoke determinista `testMockCatalogOpensMangaDetail()` aprobó 1/1 en el simulador iPad Air 11-inch (M4) y vuelve a aprobar dentro de `ReleaseGate`. Abre el mismo detalle por `Manga.ID`, pero no desplaza el detalle y selecciona otro manga; por tanto, no acredita por sí solo el reset de scroll ni la secuencia temporal de los dos tramos de escala |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011 |
| Localización | `Localizable.xcstrings` válido; 68/68 claves traducidas manualmente en inglés y español, sin entradas stale o incompletas |
| Integridad | `git diff --check` limpio; 216 enlaces Markdown locales sin roturas; cero patrones sensibles en líneas añadidas; snapshot OpenAPI y `project.pbxproj` conservan sus SHA-256 esperados; sin configuración, scheme o planes en el diff |
| Revisiones independientes | El read-back de SDD 02 y ADR 0015 y las reauditorías finales de composición y SwiftUI/accesibilidad no encuentran defectos en `ToolbarItem` + spacer + `ToolbarItemGroup`, lista, cuadrícula, stack compacto, escala local, Reduce Motion, semántica estática, contraste o Dynamic Type. La evidencia runtime de tecnologías de asistencia permanece excluida |
| Accesibilidad interactiva | **Pasa con observación.** El árbol accesible del Simulator iPad expone Lista y Cuadrícula como botones con identificadores estables, marca Lista como seleccionada y conserva tabs y contenido. El propietario confirmó manualmente que VoiceOver entra por Filtros, Lista y Cuadrícula y alcanza después el encabezamiento Catálogo según su posición visual; al volver arriba tras desplazar la lista, anuncia también el encabezamiento colapsado. En el inspector anuncia Cancelar antes de Filtros por su posición de cierre. El recorrido no queda atrapado y los controles conservan nombres comprensibles. Device Interaction no sustituyó esta comprobación: su skill obligatorio no estaba disponible para el revisor |
| Restauración Xcode | Plan activo `Fast` y destino simulador iPad Air 11-inch (M4) con iOS 27 restaurados y verificados mediante Xcode MCP |

La observación runtime anterior acreditaba una transición ya retirada y no la
nueva escala local. La preview estática y el smoke existente tampoco reproducen
el desplazamiento seguido de un cambio de selección regular; la interacción
dinámica no pudo añadirse a esta evidencia porque el skill requerido por Xcode
no estaba disponible. Build, previews y revisión estructural no constituyen
por sí solos una medición de fluidez frame a frame ni un recorrido manual con
VoiceOver, Voice Control, Switch Control, Full Keyboard Access o Accessibility
Inspector. Tampoco existe evidencia física ni integración live. La implementación
`8b2bb3` y la evidencia manual `98b0bae` se entregaron mediante la PR #28,
fusionada en `0b39884`; el issue #27 quedó cerrado y las ramas local y remota se
eliminaron. El read-back manual de VoiceOver quedó aprobado con el orden
geométrico observado; esta entrega no inició Colección ni Library Red como efecto
lateral.

## Catálogo C3 — búsqueda avanzada y filtros

- Tracker: [GitHub Issue #25 — Catálogo C3: añadir búsqueda avanzada paginada y filtros](https://github.com/JFrancoG/MangaLibrary/issues/25), abierto después de comprobar que no existía un issue o una PR equivalente.
- Rama local: `codex/25-catalog-search-filters`, creada desde `main@1d91d1026bedea25367b4f78eb8917cfb89395ca`, limpio y sincronizado con `origin/main`.
- El OpenAPI vivo se descubrió de nuevo desde `/docs` hacia `/openapi/openapi.json`. Su forma canónica coincide byte a byte con el snapshot saneado y conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no se hicieron llamadas funcionales.
- La consulta distingue catálogo, «Mejores» y búsqueda avanzada. Texto, modo contiene/empieza por, nombre y apellidos de autoría y selecciones de demografía, género y tema forman una identidad canónica; cambiarla reinicia la página, limpia la selección e invalida respuestas tardías.
- `POST /search/manga` conserva la paginación y omite dimensiones vacías del body. `GET /list/bestMangas` es un conjunto paginado exclusivo ordenado por puntuación por el servidor: no es una ordenación configurable ni se combina con texto o filtros. El contrato no expone «Destacados».
- Demografías, géneros y temas cargan perezosamente desde sus tres operaciones públicas mediante un estado independiente con carga, vacío, error recuperable y contenido. La UI representa la combinación AND que recibe el servidor sin atribuir una semántica local no declarada a varios valores de una lista.
- Lista y cuadrícula continúan consumiendo el mismo `CatalogModel`, resultados, consulta, selección y cursor. El inspector edita una copia y solo cambia la consulta al aplicar o restablecer; la barra de búsqueda envía la misma identidad avanzada.
- `AppComposition` sigue siendo exclusivamente live. `HTTPClient` continúa validando transporte y devolviendo `Data`; `CatalogAPIClient` construye y decodifica las operaciones verificadas. Previews y tests inyectan loaders de dominio directos y deterministas. No se añade Repository, UseCase, Store, protocolo de transporte, catálogo global de endpoints ni ordenación anticipada.

### RED / GREEN de C3

- RED: después de añadir primero las caracterizaciones de request, identidad y propietario de estado, `BuildProject(buildForTesting: true)` falló por la ausencia de `CatalogSearch` y `CatalogQuery`.
- GREEN: los requests exactos de búsqueda, «Mejores» y vocabularios, la canonicalización, el reset de página y selección, la preservación en retry/página adicional, las carreras entre consultas y el estado independiente de filtros quedaron implementados solo hasta satisfacer esas pruebas.
- RED de revisión: una carrera determinista reprodujo que reentrar en filtros mientras la carga anterior se cancelaba podía dejar el vocabulario en reposo sin iniciar una petición nueva; el caso falló 0/1 antes de corregir la identidad de la carga activa.
- RED de presentación: la prueba que conserva selecciones ausentes de un vocabulario refrescado no compiló hasta mover esa unión canónica desde la View a `CatalogFilterOptions`.
- RED de reauditoría: dos caracterizaciones nuevas demostraron 0/2 que mover el algoritmo no bastaba mientras el builder siguiera ejecutándolo; cubren tanto recibir vocabularios como cambiar la consulta.
- GREEN de revisión: las selecciones se incorporan ahora en `CatalogModel` solo al recibir vocabularios o cambiar la consulta, sin acumular valores exclusivos de identidades anteriores; las dos últimas pruebas pasan 2/2 y la carga preparada de previews permanece estable sin confundirse con una petición cancelable en curso.
- La inspección iPad en XXX Large detectó que el nuevo botón de filtros volvía a truncar el título de Catálogo. En anchura regular, el selector lista/cuadrícula pasa a una franja propia; la repetición en iPhone e iPad conserva título y controles completos.

### Validación local de C3

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing tras el último cambio de producción aprobado en 2,153 s y comprobación incremental final en 0,193 s; Issue Navigator y build log con cero warnings estructurados |
| Xcode MCP — `ReleaseGate` | 63/63 casos aprobados: 62 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o casos no ejecutados |
| Xcode MCP — previews | Resultados, vacío, carga, error, filtros activos y «Mejores» inspeccionados en iPhone e iPad; Large, XXX Large y AX5; inglés y español; modo oscuro con contraste aumentado |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011 |
| Localización | `Localizable.xcstrings` válido; 56/56 claves traducidas manualmente en inglés y español, sin entradas stale o incompletas |
| Integridad | `git diff --check` limpio; snapshot OpenAPI y `project.pbxproj` conservan sus SHA-256 esperados; sin configuración, scheme, planes o fixture contractual en el diff |
| Revisiones independientes | Reauditorías iOS, SwiftUI/accesibilidad y contrato/gobernanza cerradas sin hallazgos después de las correcciones; la evidencia manual de tecnologías de asistencia permanece excluida |
| Restauración Xcode | Plan activo `Fast` y destino físico `iPhone 11` con iOS 27 restaurados y verificados mediante Xcode MCP |

Las previews y el smoke UI no acreditan un recorrido manual con VoiceOver, Voice Control, Switch Control, Full Keyboard Access o Accessibility Inspector. Después de validar esta limitación y la regresión Q1 separada, el propietario autorizó expresamente commit, push, PR, merge, cierre del issue y borrado de las ramas local y remota. La autorización no repara Q1 ni inicia SwiftData, colección, autenticación, sincronización, Library Red ejecutable, WidgetKit, watchOS, App Group, entitlements o el Advanced Release Gate.

## P1 — composición live, red y pruebas directas

- Tracker: [GitHub Issue #23 — P1: simplificar composición, red y pruebas del catálogo](https://github.com/JFrancoG/MangaLibrary/issues/23), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/23-simplify-catalog-flow`, creada desde `main@e6dbfdae6655c48aac73834812c6fa594882b919`, limpio y sincronizado con `origin/main`.
- Xcode MCP oficial se conectó a Xcode-beta y confirmó `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, los cuatro planes, iOS 27, concurrencia estricta y cero diagnósticos antes de editar.
- [ADR 0014](adr/0014-native-flows-live-composition-and-direct-doubles.md) supersede ADR 0009 sin cambiar su navegación local: `AppComposition` crea únicamente dependencias live; previews y el único bootstrap Debug de UI tests inyectan un loader de dominio directo y fail-closed.
- `HTTPClient` conserva `URLSession` inyectada, valida respuesta HTTP y status y devuelve bytes. `NetworkError` retiene categorías seguras y descripciones localizables; cancelar sigue siendo `CancellationError`.
- `CatalogAPIClient` recibe `@Sendable (URLRequest) async throws -> Data`, decodifica solo los campos consumidos y valida metadata e identidades. Sus tests inyectan JSON crudo y registran la request; `FixtureURLProtocol` queda exclusivamente en `HTTPClientTests`.
- No se introduce `ResultRequest<T>`, decoding genérico en transporte, catálogo global de endpoints, Repository, UseCase, Store, protocolo o builder anticipado. La construcción tipada permanece en `CatalogPageRequest` hasta que una segunda operación real demuestre duplicación.

### RED / GREEN de P1

- RED: `BuildProject(buildForTesting: true)` falló por la ausencia de `NetworkError` y de la costura directa del cliente tipado después de añadir las nuevas caracterizaciones.
- GREEN: el transporte mapea respuesta no HTTP, status, fallo de URL loading y cancelación; el cliente de Catálogo construye página 1/2, decodifica un payload mínimo con campos remotos desconocidos, preserva categorías de red y detecta metadata, identidad y campos consumidos inválidos.
- `AppCompositionTests`, el test de vocabulario remoto no consumido y el getter aislado de selección se eliminan. La garantía de no recargar se integra en la transición inicial; los tests restantes conservan estado, retry, paginación, cancelación y carreras de C2.
- El XCUITest se reduce al recorrido determinista `-ui-testing` → primera fila → detalle de la misma `Manga.ID`; no prueba tabs placeholder, alternancia visual ni wiring garantizado por compilación.

### Validación local de P1

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — build y diagnósticos | Build-for-testing aprobado; build log e Issue Navigator con cero warnings estructurados |
| Xcode MCP — `ReleaseGate` | 42/42 casos aprobados: 41 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o casos no ejecutados |
| Xcode MCP — previews | Shell y contenido renderizados; error inicial y fallo de página adicional inspeccionados en Large, XXX Large y AX 5. El truncado español detectado en AX 5 se corrigió y ambos estados conservan título, descripción y acción completas |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; archive Release generado con warnings DocC como errores y una única emisión externa acotada por ADR 0011 |
| Localización | `Localizable.xcstrings` válido; 29/29 claves traducidas manualmente en inglés y español, sin entradas stale o incompletas |
| Revisiones independientes | Arquitectura/concurrencia/testing y SwiftUI/accesibilidad terminaron sin hallazgos abiertos tras corregir request, fixture OpenAPI, conformidades redundantes, reflow AX 5 e iconografía semántica |
| Límite Q1 | `Fast` continúa descubriendo 0 tests habilitados por la regresión conocida de tags; P1 no modifica planes, scheme ni `TestTags.swift` |

Las previews y el smoke UI no acreditan un recorrido manual con VoiceOver, Voice Control, Switch Control, Full Keyboard Access o Accessibility Inspector. No se realizaron llamadas funcionales a producción. Después de validar estas limitaciones, el propietario autorizó expresamente commit, push, PR, merge, cierre del issue y borrado de las ramas local y remota. La autorización no repara Q1 ni inicia C3 como efecto lateral.

## Catálogo C2 — paginación incremental y lista/cuadrícula

- Tracker: [GitHub Issue #21 — Catálogo C2: añadir paginación incremental y lista/cuadrícula](https://github.com/JFrancoG/MangaLibrary/issues/21), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/21-catalog-pagination-layout`, creada desde `main@d62bc9348ae7da842b41e99e1ef8976e8fbe6a60`, limpio y sincronizado con `origin/main`.
- El OpenAPI vivo descubierto desde `/docs` conserva OpenAPI 3.0.1, 28 paths, 30 operaciones, 19 schemas y 3 mecanismos de seguridad. Su forma canónica saneada coincide byte a byte con el snapshot y mantiene SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`; no se hicieron llamadas funcionales.
- `CatalogModel` sigue siendo el único propietario `@Observable @MainActor` de consulta, acumulación, cursor, carga adicional, error, retry, cancelación y protección frente a respuestas tardías. Las Views permanecen como structs declarativas sin `@MainActor`.
- Lista y cuadrícula consumen el mismo contenido acumulado y la misma selección por `Manga.ID`. La cuadrícula adapta sus columnas a Dynamic Type y a la anchura disponible; en presentación compacta abre el detalle mediante la columna preferida de `NavigationSplitView`.
- Una página adicional conserva el orden y el primer valor ya visible de cada identidad. El fin por total o página vacía cierra el cursor; un fallo mantiene contenido y selección y reintenta exactamente la misma página.
- `CatalogAPIClient` rechaza como deriva contractual la metadata de página o tamaño que no corresponde a la petición. `HTTPClient` continúa concreto, inmutable, app-scoped e inyectado; no se añaden actor compartido, `@globalActor`, Repository, UseCase o Store.

### RED / GREEN de C2

- RED: el primer build-for-testing falló por la ausencia de `CatalogModel.Content`, `CatalogModel.Pagination` y las intenciones de página adicional después de añadir las caracterizaciones.
- GREEN: página 2 exacta, acumulación, deduplicación, fin, error adicional, retry, cancelación y respuesta invalidada quedaron implementados solo hasta satisfacer esas pruebas.
- La inspección visual posterior detectó que el valor inline de la macro `@State` impedía arrancar la preview en cuadrícula. La asignación directa desde ambos inicializadores corrige el estado moderno de iOS 27 sin manipular un backing wrapper.
- La primera auditoría iPad detectó una única columna y el título de navegación truncado. El ancho adaptativo de tarjeta, la portada escalable y el ancho acotado del selector se ajustaron antes de repetir las previews.

### Validación técnica de C2

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — `ReleaseGate` | 38/38 pruebas aprobadas: 37 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o pruebas no ejecutadas |
| Xcode MCP — smoke UI | 1/1 aprobado tanto en iPhone 17 como en iPad Air 11-inch (M4): alterna lista/cuadrícula, abre el mismo detalle por `Manga.ID` y conserva la ruta tras cambiar de tab |
| Xcode MCP — build y diagnósticos | Build-for-testing aprobado; los 12 archivos Swift afectados muestran cero diagnósticos y el Issue Navigator y el build log contienen cero warnings estructurados |
| Previews Xcode | Lista y cuadrícula inspeccionadas en iPhone e iPad; Large, XXX Large y AX5; inglés y español; modo oscuro y contraste aumentado. La cuadrícula usa dos columnas cuando el ancho y Dynamic Type lo permiten y refluye a una en AX5 |
| Localización | `Localizable.xcstrings` válido; 24 claves traducidas manualmente en inglés y español, sin estados new, needs review o machine translated |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; `docbuild` Release para iOS genérico aprobado y `.doccarchive` regenerado con warnings DocC como errores |
| ADR 0011 | Exactamente una emisión externa autorizada en `27A5252f`; cero warnings de Swift, Clang o DocC. La excepción no acredita Advanced |

`GetTestList` no proyecta actualmente los tags heredados de `@Suite` y deja 0/37 tests habilitados tanto en `Fast` como en `Integration`; `UI` descubre 1/1 y `ReleaseGate`, 38/38. Una prueba diagnóstica reversible confirmó que un tag directo sí aparece en el inventario, pero el filtro continúa deshabilitándolo. La prueba se retiró y `TestPlans/`, el scheme y el proyecto permanecen fuera del diff. C2 no repara Q1 silenciosamente y no puede acreditar todavía esos dos planes.

Después de recibir esta limitación y la recomendación de resolverla antes de entregar, el propietario autorizó expresamente el cierre completo de C2 mediante commit, push, PR, merge, cierre del issue y eliminación de rama. La autorización no convierte `Fast` o `Integration` en gates aprobados, no amplía C2 a una reparación de Q1 y no acredita el Advanced Release Gate.

### Alcance excluido y estado de entrega de C2

- Búsqueda, filtros y ordenación pertenecen a C3. También quedan fuera SwiftData, colección, autenticación, sincronización, Library Red ejecutable, WidgetKit, watchOS, App Group, entitlements y llamadas funcionales al backend.
- No se modifican SDD, ADR, OpenAPI, configuración, scheme, planes ni `project.pbxproj`.
- La implementación, los gates técnicos aplicables y las revisiones especializadas quedan cerrados. La entrega autorizada vincula la rama `codex/21-catalog-pagination-layout` con el issue #21 mediante su PR de cierre y elimina después la rama local y remota. C3 no se inicia como efecto lateral.

## Q1 — planes de test versionados

- Tracker: [GitHub Issue #19 — Q1: materializar los planes de test versionados](https://github.com/JFrancoG/MangaLibrary/issues/19), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/19-test-plans`, creada desde `main@b86d2352e83e6aa26bec51bec38233253fa244db`, limpio y sincronizado con `origin/main`.
- RED de configuración: Xcode MCP encontraba únicamente el plan implícito autocreado `MangaLibrary`; no existían `.xctestplan` versionados.
- Los planes `Fast`, `Integration`, `UI` y `ReleaseGate` viven en `TestPlans/` y el scheme compartido deja `Fast` como predeterminado.
- `Fast` incluye el tag Swift Testing `fast`, aplicado a `AppCompositionTests` y `CatalogModelTests`; `Integration` incluye `integration`, aplicado a `CatalogAPIClientTests` y `HTTPClientTests`; `UI` contiene el target XCUITest; `ReleaseGate`, ambos targets completos sin filtros.
- `ReleaseGate.xctestplan` es el componente completo de tests. Build, DocC y evidencia manual continúan siendo acciones separadas del Release Gate de producto.

### Validación de Q1

| Evidencia | Resultado |
| --- | --- |
| Xcode MCP — preflight | Proyecto `MangaLibrary.xcodeproj`, scheme compartido `MangaLibrary`, tres targets, destino original iPhone 11 físico con iOS 27 y cero warnings del navegador |
| Descubrimiento inicial | 30 tests activos bajo el plan implícito: 29 Swift Testing y 1 XCUITest |
| RED de ejecución | La selección nominal por nombres mostraba 12 tests habilitados en `Fast`, pero `RunAllTests` ejecutaba los 29 unitarios; se descartó por no constituir un gate real para Swift Testing |
| GREEN de descubrimiento | Los filtros nativos Include Tags dejan `Fast` con 12 habilitados y 17 excluidos; `Integration`, 17 y 12; `UI`, 1; `ReleaseGate`, 30 |
| Xcode MCP — ejecución `Fast` | Los 12 identificadores habilitados por el plan, obtenidos con `GetTestList` y ejecutados con `RunSomeTests`, aprobaron 12/12 |
| Xcode MCP — ejecución `Integration` | Los 17 identificadores habilitados por el plan, obtenidos con `GetTestList` y ejecutados con `RunSomeTests`, aprobaron 17/17 |
| Xcode MCP — ejecución `UI` | `RunAllTests` aprobó 1/1 XCUITest |
| Xcode MCP — ejecución `ReleaseGate` | `RunAllTests` aprobó 30/30: 29 Swift Testing y 1 XCUITest |
| Xcode MCP — build y restauración | `BuildProject(buildForTesting: true)` aprobado en 2,097 s sin errores; cero warnings en el navegador; `Fast` y el iPhone 11 físico con iOS 27 restaurados como plan y destino activos |
| Validación estática | Los cuatro JSON y el XML del scheme son válidos; `git diff --check`, 196 enlaces locales y el escaneo de patrones sensibles pasan; `project.pbxproj` conserva SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Revisión iOS independiente | Perfil `greenfield-xcode27`; testing, configuración, concurrencia, alcance y gobernanza revisados sin hallazgos; revisión SwiftUI/accesibilidad no aplicable porque Q1 no modifica UI |

La operación MCP `RunAllTests` ignora los tests deshabilitados por un plan y, por tanto, no sirve como evidencia de cardinalidad para `Fast` o `Integration`; la combinación `GetTestList` + `RunSomeTests` sí conserva y ejecuta exactamente la selección resuelta por cada plan. C2 y cualquier comportamiento nuevo de producto quedan fuera.

### Estado de entrega de Q1

La implementación se versiona en el commit `43424a6` y se entrega mediante la [PR #20](https://github.com/JFrancoG/MangaLibrary/pull/20), cuya fusión cierra el issue #19. La entrega autorizada incluye la eliminación posterior de la rama local y remota. C2 no se inicia como efecto lateral de este cierre.

## D1 — frontera de logout Advanced y bridge Deluxe

- Tracker: [GitHub Issue #17 — D1: delimitar logout Advanced y su extensión Deluxe](https://github.com/JFrancoG/MangaLibrary/issues/17), abierto después de comprobar que no existía un issue equivalente.
- Rama: `codex/17-advanced-deluxe-session-boundary`, creada desde `main@2488308b290353b469247e16f73d246aadb37a42`, limpio y sincronizado con `origin/main`.
- D1 elimina la dependencia circular entre un Advanced que debe cerrar autenticación y sincronización y unas garantías de `SessionFence`, App Group, WidgetKit y WatchConnectivity que solo pueden materializarse después de su Release Gate.
- Advanced conserva un logout local, durable y recuperable: gate de pendientes, propietario de sesión serializado, invalidación de la generación esperada, revalidación de tareas y limpieza condicionada de Keychain, datos y rutas. Mientras A está en curso no se activa B y un efecto tardío de A no altera una sesión posterior. La cancelación solo es válida antes del commit de invalidación local.
- Cuando exista el bridge Deluxe, su fence cerrado y verificado se compone entre la transición persistida y la invalidación local y adelanta el punto de no retorno; envelope, reload y contexto watchOS continúan siendo eventuales. El bootstrap empieza cerrado y solo abre tras autorización y revalidación explícitas del propietario de sesión. Advanced no crea un bridge no-op.
- [ADR 0013](adr/0013-advanced-logout-and-deluxe-bridge-boundary.md) complementa ADR 0006, 0007 y 0010 sin superseder sus decisiones. SDD 00, 04, 05 y 06 atribuyen cada requisito y prueba a su gate real.

### Validación de D1

| Herramienta y acción | Resultado |
| --- | --- |
| Git y GitHub — preflight | Repositorio privado; `main` limpio y sincronizado en `2488308`; cero issues o PR abiertas antes de D1; issue #17 y rama creados desde esa base |
| Xcode MCP — preflight | `MangaLibrary.xcodeproj`, scheme compartido y plan `MangaLibrary`, app y targets de tests, destino activo iPhone 11 con iOS 27 y cero warnings en Issue Navigator |
| OpenAPI vivo — comparación canónica | OpenAPI 3.0.1, 28 paths, 30 operaciones, 19 schemas y 3 mecanismos de seguridad; SHA-256 saneado `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`, idéntico al snapshot. No declara logout ni revocación; no se hicieron llamadas funcionales |
| Matriz antes/después | Antes, SDD 04 y el gate Advanced exigían incondicionalmente capacidades cuya entrada depende de superar Advanced. Después, PROD-013 y los casos con columna `Gate` cierran la sesión local en Advanced y reservan fence, bootstrap y proyecciones para Deluxe |
| Documentación e integridad | SDD 00/04/05/06 incrementan versión; 13 ADR y 13 entradas de índice conservan estados y fechas coherentes; 36 Markdown y 196 enlaces locales sin roturas; escaneo de privacidad y secretos sin hallazgos; `git diff --check` limpio y `project.pbxproj` intacto en `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Revisiones independientes | La auditoría iOS detectó y cerró carrera A/B, bootstrap y punto de no retorno; los read-backs finales de arquitectura/seguridad, gobierno ADR y alcance/integridad terminaron sin hallazgos |
| Alcance ejecutable | TDD, build, tests, previews y DocC no aplican: D1 cambia únicamente contrato humano y no modifica código, Assets, proyecto, configuración o catálogo DocC |

### Estado de entrega de D1

La decisión se versiona en el commit `93288f3` y se entrega mediante la [PR #18](https://github.com/JFrancoG/MangaLibrary/pull/18), cuya fusión cierra el issue #17. La entrega autorizada incluye la eliminación posterior de la rama local y remota. Código de sesión, Keychain, SwiftData, outbox, App Group, WidgetKit, watchOS, entitlements, OpenAPI, colorsets, Q1 y C2 quedan fuera de D1.

## Contrato cromático Library Red — issue #15

- Tracker: [GitHub Issue #15 — Documentar el contrato cromático Library Red](https://github.com/JFrancoG/MangaLibrary/issues/15), cerrado mediante la [PR #16](https://github.com/JFrancoG/MangaLibrary/pull/16) después de comprobar que no existía un issue duplicado.
- Rama: `codex/15-brand-palette-contract`, creada desde `main@884dd6c3dfdd98a1b37e5ab66329cad7a8c4615c`, limpio y sincronizado con `origin/main`, y eliminada local y remotamente tras la fusión.
- [`docs/design/brand-palette.md`](design/brand-palette.md) define significado, política de uso, accesibilidad y límites. [`docs/design/library-color-tokens.json`](design/library-color-tokens.json) es la autoridad exacta de versión, valores, roles, modos, umbrales y parejas.
- SDD 06 enlaza el contrato y difiere colorsets, código y tests a una unidad RED/GREEN posterior. La procedencia coordinada con ScienceLibrary no se convierte en una invariante entre repositorios.
- La revisión de fuentes corrigió la atribución normativa: WCAG2ICT es una Group Note informativa y WCAG2Mobile una Group Draft Note; ninguna define conformidad para una app nativa. También distingue los `44 × 44 pt` predeterminados de Apple de su mínimo `28 × 28 pt` y limita lo que demuestra la matriz del indicador de foco.
- El Markdown genérico y el HTML visual se archivaron en documentación privada fuera de Git. El archive DocC regenerable de 72 MB y el residuo temporal literal de 52 KB se retiraron del workspace y permanecen recuperables en la Papelera hasta que se vacíe.

### Validación del contrato cromático

| Herramienta y acción | Resultado |
| --- | --- |
| Git, GitHub y Xcode MCP — preflight | Repositorio privado; `main` limpio y sincronizado antes de abrir el issue; sin issues ni PR abiertos; Xcode observa `MangaLibrary.xcodeproj`, scheme y plan `MangaLibrary`, destino físico iPhone 11 con iOS 27 |
| Apple y W3C — fuentes primarias | HIG Color/Accessibility/Dark Mode, Asset Catalog, SwiftUI `ColorSchemeContrast`, WCAG 2.2, WCAG2ICT y WCAG2Mobile contrastados el 25 de agosto de 2026 |
| JSON y recálculo independiente | JSON válido; 4 modos, 22 colores por modo, 29 roles y 56 parejas por modo, 224 en total; todos los ratios superan sus umbrales sin redondeo previo |
| Correspondencia humana/máquina | Los 88 pares OKLCH/HEX del Markdown coinciden exactamente con el JSON; la conversión independiente de cada OKLCH reproduce su HEX cuantizado y confirma que todos quedan dentro de sRGB; los cuatro peores casos recalculados reproducen `4.735`, `5.022`, `7.046` y `7.429` para texto |
| Enlaces y privacidad | 174 enlaces Markdown locales sin roturas; los archivos nuevos no contienen rutas privadas, cuentas, correos, credenciales ni secretos |
| Integridad | `git diff --check` limpio; `project.pbxproj` sin diff y con SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| TDD y gates Xcode | No aplican: la unidad cambia exclusivamente documentación y datos de diseño; no modifica código, Assets, configuración, proyecto ni comportamiento ejecutable |

### Estado de entrega del issue #15

El contrato queda versionado en el commit `1ab880c` y se entrega mediante la PR #16, cuya fusión cierra el issue #15. La entrega autorizada incluye la eliminación posterior de la rama local y remota. Colorsets, `AccentColor`, tests de assets y cualquier adopción visual quedan fuera de esta unidad.

## Catálogo C1 — primera página pública y detalle por identidad

- Tracker: [GitHub Issue #13 — Catálogo C1: cargar la primera página pública y abrir el detalle por identidad](https://github.com/JFrancoG/MangaLibrary/issues/13), cerrado mediante la PR #14, iniciada sobre `main@b6909d645a0e28b15a5b19ce935a3139b4598bb0`.
- Rama: `codex/13-catalog-first-page-detail`, creada directamente desde esa base limpia y sincronizada.
- El OpenAPI vivo descubierto desde `/docs` se revalidó antes de implementar: `/openapi/openapi.json` conserva SHA-256 `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b` y coincide con el snapshot versionado.
- El shell mantiene tabs estables para Catálogo, Colección y Cuenta. Catálogo carga únicamente `GET /list/mangas?page=1&per=20`, representa carga, contenido, vacío y error recuperable, y abre un detalle desde el elemento ya cargado mediante `Manga.ID == Int64`, sin segunda petición.
- La frontera compartida es un `HTTPClient` concreto, inmutable, de ámbito app e inyectado desde composición. No existe estado mutable compartido que justifique un actor de instancia ni una invariante global que justifique `@globalActor`; la carpeta se denomina `Networking`.
- `CatalogModel` posee el estado de presentación como `@Observable @MainActor`. Las Views, que son structs declarativas, no llevan `@MainActor` explícito y construyen su `@State` macro mediante asignación directa.
- `CatalogFixtureScenario` localiza de forma segura el valor posterior a `-catalog-fixture`. Un flag sin valor, inválido o solicitado fuera de Debug falla cerrado y nunca deriva a tráfico live.
- Portadas, localización española e inglesa, previews y composición de UI tests son deterministas. Tests y previews no contactan producción.

### RED / GREEN de C1

- RED inicial: `BuildProject(buildForTesting: true)` falló por la ausencia de `CatalogPageRequest` y `CatalogPage`, antes de añadir producción.
- GREEN: transporte HTTP, request exacta, decodificación y mapeo, vocabulario cerrado, cancelación, retry, respuestas tardías, selección y detalle quedaron implementados solo hasta satisfacer las caracterizaciones.
- RED adicionales reprodujeron y cerraron el rechazo de credenciales embebidas en la URL base, el saneamiento de URL de portada y el comportamiento cerrado de los fixtures de lanzamiento.
- Una última RED de auditoría demostró que el modelo no conservaba la categoría del fallo. GREEN traduce construcción/transporte a `unavailable`, mantiene decodificación y duplicados como `contractDrift`, propaga cancelación y no retiene body, URL ni error subyacente.
- La UI smoke recorre shell, contenido, detalle y tabs con una composición local, y comprueba que la ruta de detalle de Catálogo sobrevive al cambio temporal de tab.

### Validación técnica final de C1

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — proyecto y destino | `MangaLibrary.xcodeproj`, scheme `MangaLibrary`, plan implícito `MangaLibrary`, Xcode 27 build `27A5252f`, Swift 6.4 e iOS 27 |
| Xcode MCP — `BuildProject(buildForTesting: true)` | Snapshot final aprobado en iPhone 17 en 2,274 s, sin errores; Issue Navigator y build log contienen cero warnings estructurados |
| Xcode MCP — suite completa en iPhone 17 | 30/30 pruebas aprobadas: 29 Swift Testing y 1 XCUITest; cero fallos, skips, expected failures o tests no ejecutados |
| Xcode MCP — smoke en iPad Air 11-inch (M4) | 1/1 aprobado sobre el snapshot final, incluido detalle y conservación de ruta entre tabs |
| Previews Xcode | Inspeccionadas carga, contenido, vacío, error, detalle, shell iPad y portada ausente/fallida; Large, XXX Large, AX5, inglés, español, modo oscuro y contraste aumentado |
| Localización | `Localizable.xcstrings` válido; 17 claves visibles traducidas en inglés y español, sin estados new, needs review o machine translated |
| `Scripts/validate-docc.sh` | 8/8 escenarios del clasificador; `docbuild` Release para iOS genérico aprobado y `.doccarchive` regenerado con warnings DocC como errores |
| ADR 0011 | Exactamente una emisión externa autorizada en `27A5252f`; cero warnings de Swift, Clang o DocC. La excepción no acredita Advanced |
| Integridad y alcance | `git diff --check` limpio; `project.pbxproj` sin diff y SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543`; catálogo JSON válido |
| Enlaces y privacidad | 163 enlaces Markdown locales sin roturas; cero rutas privadas, correos reales o secretos plausibles. Dos credenciales sintéticas bajo `example.test` ejercitan exclusivamente tests negativos |
| Revisión SwiftUI/accesibilidad independiente | Sin hallazgos tras cerrar headings, contraste y preview de fallo; el recorrido manual con tecnologías de asistencia y restauración real de foco queda pendiente |
| Revisión iOS independiente | Sin hallazgos tras cerrar composición, seguridad de URL, fixtures fail-closed, persistencia de navegación y taxonomía segura de errores |

### Alcance excluido de C1

- Página 2, paginación incremental, grid, búsqueda, filtros y ordenación.
- SwiftData, colección, favoritos, outbox, autenticación, Keychain, sesión y sincronización.
- `/search/manga/{id}`, escrituras o pruebas funcionales contra el backend.
- Repositories, use cases, stores, protocolos ceremoniales, actor compartido y `@globalActor`.
- Dependencias externas, cliente OpenAPI generado, `.xctestplan`, WidgetKit, watchOS, App Groups y entitlements.
- Cambios en `project.pbxproj`, scheme, `Shared.xcconfig`, SDD, ADR o snapshot OpenAPI.
- Advanced Release Gate completo, presentación, vídeo y siguiente unidad.

### Estado de entrega de C1

La implementación, los gates técnicos locales y las revisiones independientes están cerrados sin hallazgos. El commit principal `048c7ab` se entregó mediante la PR #14, cuya fusión cerró el issue #13; la rama `codex/13-catalog-first-page-detail` se eliminó local y remotamente como parte del cierre autorizado.

## Reconciliación G0 posterior a la PR #10

- Tracker: [GitHub Issue #11 — Reconciliar Progress tras la PR #10](https://github.com/JFrancoG/MangaLibrary/issues/11).
- Antes de abrir G0, GitHub no tenía issues ni pull requests abiertas; tampoco existía una unidad de producto activa.
- `main`, `origin/main` y su merge-base coincidían en `051a03f895ef55b5fe940574a0fcf5521b9a74bb`, merge de la PR #10, con el worktree limpio.
- La rama de trabajo `codex/11-reconcile-progress-pr-10` se creó directamente desde esa base y el alcance de G0 quedó limitado a este documento.
- El repositorio continúa `PRIVATE` por el cambio de visibilidad realizado antes del primer push del issue #7. Los issues #1, #3, #4, #6 y #7 están cerrados y las PR #2, #5, #8, #9 y #10 fusionadas.
- G0 no ejecuta ni acredita TDD, build, tests, DocC o una nueva validación Xcode porque no cambia código, configuración ni comportamiento de producto.
- G0 se entregó mediante la PR #12, fusionada en `b6909d645a0e28b15a5b19ce935a3139b4598bb0`; el issue #11 está cerrado.

### Validación de G0

- Git y GitHub se releyeron antes de editar: base limpia y sincronizada en `051a03f`, repositorio `PRIVATE`, ningún issue o pull request abierto antes de G0 y ausencia de trabajo de producto activo.
- El diff contiene únicamente `docs/Progress.md`; `git diff --check` termina limpio y `project.pbxproj` conserva SHA-256 `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543`.
- Se comprobaron 163 enlaces Markdown locales sin roturas.
- El escaneo acotado devuelve cero rutas privadas, correos y patrones plausibles de secretos.
- La reauditoría documental independiente termina sin hallazgos después de corregir cronología, estado posterior a G0 y registro de validación.

## Fuente docente y privacidad del issue #7

- Tracker: [GitHub Issue #7 — Versionar el enunciado saneado y definir su límite de publicación](https://github.com/JFrancoG/MangaLibrary/issues/7).
- GitHub confirmó el cambio de visibilidad de `PUBLIC` a `PRIVATE` antes de cualquier push de la rama del enunciado.
- El original exacto se archivó fuera de Git con SHA-256 `7b95ee784ef661eca72b41f49bb2d8b8d2b47f7bfbd6d4d3bf1d30fed490a52c`.
- `docs/sources/Practica_Mis_Mangas_SDP_2026.md` conserva el texto completo, añade únicamente la nota declarada y sustituye el valor demostrativo de 42 caracteres por 42 `X`; SHA-256 saneado `0a4b840a13f87bae482ebf8afa5195a222d4de37b4fdcce43b5be6732011be4a`.
- ADR 0012 mantiene las decisiones DocC selectivas, reemplaza la frontera pública de ADR 0008 y exige autorización separada para visibilidad, redistribución o accesos.
- TDD y Xcode no aplican a esta entrega exclusivamente documental. No se invita todavía a profesores ni se publica DocC o GitHub Pages.

## Icono y recursos del issue #6

- Tracker: [GitHub Issue #6 — Adoptar el icono de Manga Library y organizar los recursos del target](https://github.com/JFrancoG/MangaLibrary/issues/6).
- `Assets.xcassets` e `InfoPlist.xcstrings` se trasladan byte a byte a `MangaLibrary/Resources/`; Git detecta los cuatro movimientos como `R100`.
- `MangaLibrary.icon` conserva el `icon.json` creado por Icon Composer y sus tres capas PNG de 1024 × 1024. El proyecto selecciona `MangaLibrary` como app icon en Debug y Release.
- La captura aportada por el propietario muestra `Assets.xcassets`, `InfoPlist.xcstrings` y `MangaLibrary.icon` bajo `MangaLibrary/Resources` en Copy Bundle Resources. El propietario instaló y lanzó esa configuración en un iPhone 11 físico y observó el icono nuevo; la evidencia no se extrapola a otras capacidades de hardware.
- El enunciado quedó fuera del diff del issue #6 y se incorpora por separado, saneado y auditado, mediante el issue #7.

## Gate técnico del issue #3

- Tracker: [GitHub Issue #3 — Materializar warnings-as-errors y el gate DocC reproducible](https://github.com/JFrancoG/MangaLibrary/issues/3).
- Estado del plan: implementación y validación ejecutadas. Tras confirmar que Xcode 27 beta 6 conserva el warning externo, el propietario aprobó ADR 0011, su contrato ejecutable y el cierre completo mediante PR y merge commit.
- Alcance: adopción consciente del baseline Xcode 27 protegido, configuración compartida, scheme compartido, landing DocC, catálogo de Info.plist, script reproducible, excepción externa acotada y actualización documental proporcional.
- Fuera del alcance: `.xctestplan`, `Localizable.xcstrings`, textos o permisos de producto todavía inexistentes, código o tests de producto, comentarios `///`, artículos, tutoriales, dependencias, publicación, targets y entitlements.

## Base, alineación y preservación

| Evidencia | Estado |
| --- | --- |
| Entregas anteriores | Issue #1 por PR #2, merge `eb340b3`; OpenAPI por PR #5, merge `5ebdcb6`; gate Xcode 27/DocC por PR #8, merge `7522977`; icono y recursos por PR #9, merge `0a30fac`; enunciado saneado y ADR 0012 por PR #10, merge `051a03f`; G0 por PR #12, merge `b6909d6` |
| Base verificada al iniciar G0 | `main`, `origin/main` y merge-base limpios y coincidentes en `051a03f` antes de crear la rama del issue #11 |
| Rama de trabajo de G0 | `codex/11-reconcile-progress-pr-10`, creada directamente desde `051a03f` |
| Base histórica del issue #7 | La rama del issue #7 avanzó de forma fast-forward a `origin/main` en `0a30fac` después de verificar el archive externo, sin pull ni rebase |
| Rama histórica del issue #7 | `codex/7-private-practice-statement` |
| Cambio previo protegido | Verificado antes y después de la alineación: 34 inserciones, 24 eliminaciones, `git diff --check` limpio |
| SHA-256 inicial protegido | `375f108b069732d9076090ec39668e07a7892da484b18ac933c07c18e2b8e582` |
| Extensión aprobada del proyecto | Frente al snapshot protegido, `project.pbxproj` suma 13 líneas y no elimina ninguna: las 12 de configuración compartida y la región `es`; el contenido previo permanece byte a byte |
| SHA-256 del proyecto tras recursos | `b6f3b006f5693f1580c7dae1cd114beaf4fb6d23ec3769850f21836c84e35543` |
| Alcance histórico del issue #7 | Copia saneada, ADR 0012 y actualización de gobierno, fuentes, navegación, SDD y evidencia; sin código, configuración Xcode ni material docente adicional |
| Alcance histórico de G0 | Reconciliación exclusiva de `docs/Progress.md`; sin producto, configuración Xcode, SDD, ADR, DocC o contrato OpenAPI |
| Base y rama históricas de C1 | `main@b6909d6`; `codex/13-catalog-first-page-detail` para el issue #13 y la PR #14 |

No se usó `stash`, `reset`, `clean`, pull, rebase ni sobrescritura. El snapshot temporal de control permaneció fuera del repositorio.

## Configuración materializada

- `Configuration/Shared.xcconfig` se conecta a las configuraciones Debug y Release del proyecto.
- App, unit tests y UI tests heredan `GCC_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` y `OTHER_DOCC_FLAGS = $(inherited) --warnings-as-errors`.
- `MangaLibrary.xcscheme` queda compartido y versionable; el estado personal de gestión de schemes se retira del control de versiones.
- El catálogo DocC contiene únicamente `MangaLibrary.md`; no se añadieron comentarios, extensiones, artículos ni tutoriales sin contratos reales.
- `MangaLibrary/Resources/InfoPlist.xcstrings` registra inglés y español. `CFBundleDisplayName` conserva `Manga Library` en ambos idiomas por decisión de producto; `CFBundleName` conserva el valor técnico `MangaLibrary` en ambos.
- No se creó ningún `.xctestplan`. Xcode muestra su plan implícito autocreado `MangaLibrary`, que no sustituye los futuros planes `Fast`, `Integration`, `UI` y `ReleaseGate`.

## Validación histórica acumulada hasta G0

| Herramienta y acción | Resultado |
| --- | --- |
| Xcode MCP — ventanas, scheme, targets, destino y plan | `MangaLibrary.xcodeproj`; scheme compartido `MangaLibrary`; app, unit y UI tests; iPhone 17 Pro / iOS 27.0; plan implícito `MangaLibrary` |
| Xcode MCP — build settings de los tres targets | Swift 6, iOS 27, iPhone/iPad, concurrencia `complete`, aislamiento `nonisolated` y warnings Swift/Clang como errores |
| `Scripts/validate-docc.sh` — matriz 3 targets × 2 configuraciones | Los cinco ajustes compartidos evaluaron al valor exigido en Debug y Release |
| Clasificador de diagnósticos — 8 escenarios sintéticos | Cero y una emisión exacta pasan; dos exactas, warning o error adicional, severidad modificada, dos diagnósticos en una línea y build distinto fallan con la clasificación esperada |
| Xcode MCP — `BuildProject(buildForTesting: true)` | Debug con los catálogos DocC y de recursos completado en 0,592 s; cero errores y cero warnings estructurados por MCP. El full log conserva tres emisiones del diagnóstico externo descrito debajo, una por target |
| Producto compilado — localizaciones Info.plist | Xcode compiló el catálogo y copió `en.lproj/InfoPlist.strings` y `es.lproj/InfoPlist.strings`; ambos resuelven `CFBundleDisplayName` a `Manga Library` |
| Xcode MCP — smoke Swift Testing | `MangaLibraryTests/example()` pasó: 1 ejecutado, 1 aprobado, 0 fallos |
| Xcode 27 CLI — `build-for-testing`, Release, iPhone 17 Pro / iOS 27.0 | Exit 0; el full log contiene el mismo diagnóstico externo tres veces, una por target; DerivedData temporal eliminado después de validar |
| Gate DocC — `docbuild`, Release, `generic/platform=iOS` | Revalidado después de integrar los recursos con Xcode 27.0 beta 6 build `27A5252f` y Apple Swift 6.4; `--warnings-as-errors` activo, exit 0 y una única emisión externa aceptada por ADR 0011 |
| Archive | `.build/docc/MangaLibrary.doccarchive` creado y comprobado; permanece ignorado por Git |
| Recursos del icono | Cuatro movimientos `R100`; tres PNG válidos de 1024 × 1024; `icon.json` válido y con referencias exactas; app icon `MangaLibrary` en Debug y Release |
| Evidencia física del propietario | Copy Bundle Resources contiene los tres recursos en la ruta aprobada; instalación y lanzamiento en iPhone 11 con el icono nuevo observados por el propietario |
| Integridad del enunciado | El original externo conserva su SHA-256; la copia versionada coincide después de aplicar únicamente la nota declarada y la sustitución exacta de 42 caracteres |
| Visibilidad GitHub | Repositorio verificado como `PRIVATE` antes del primer push que pueda contener la fuente saneada |
| Auditoría estática | `plutil`, `jq`, `xmllint`, `bash -n` y `git diff --check` aprobados; 163 enlaces locales comprobados en 34 Markdown, sin roturas; escaneo de rutas privadas y patrones de secretos sin hallazgos |

El primer intento del smoke no obtuvo resultado porque el simulador no devolvió un proceso al lanzar la app. Xcode MCP lanzó después la app correctamente y la repetición idéntica del test pasó; no se modificó código para resolverlo.

## Diagnóstico de herramienta observado

Xcode 27 beta emite `Metadata extraction skipped, no AppIntents.framework dependency found` desde `appintentsmetadataprocessor` al procesar cada target en los builds Debug y Release, y una vez durante `docbuild`. El comportamiento persistió en la beta 6 build `27A5252f`. Las acciones terminan con exit 0 y MCP no lo devuelve como issue estructurado, pero el texto sí está en sus full logs. No es un warning de Swift, Clang ni DocC; se conserva y atribuye a la herramienta de Xcode. No se añadió un App Intents ficticio, no se activó `LM_FILTER_WARNINGS` —que solo pasaría `--quiet-warnings`— ni se adoptó un ajuste interno para ocultarlo.

ADR 0011 sustituye el bloqueo indefinido por un límite ejecutable: cero diagnósticos pasa; una única coincidencia exacta pasa solo en `27A5252f`; cualquier otra firma, severidad, cantidad o build falla. La excepción no filtra la salida ni relaja los warnings-as-errors propios. Tampoco satisface el Advanced Release Gate, que conserva el requisito de build limpio y cero warnings.

## Revisiones independientes

- La revisión iOS/configuración, incluida la reauditoría del catálogo y la región `es`, terminó sin otros hallazgos. La nueva decisión no suprime el warning: lo limita y hace fallar el gate ante cualquier deriva.
- La revisión SwiftUI/accesibilidad detectó la ausencia inicial de `InfoPlist.xcstrings`; tras la ampliación autorizada, la reauditoría cerró el P2 sin hallazgos. La comprobación manual del nombre y su pronunciación real con VoiceOver queda diferida a evidencia de interfaz/dispositivo.
- La revisión DocC independiente terminó sin hallazgos propios del catálogo o del gate y confirmó que el warning de App Intents es externo a DocC.
- La revisión iOS/configuración de los recursos cerró el único P2 al reconciliar el índice y terminó sin hallazgos: cuatro `R100`, proyecto, PNG e `icon.json` forman un snapshot completo y el enunciado queda excluido.
- La revisión documental y de privacidad del issue #7 terminó sin hallazgos: confirmó visibilidad privada previa al push, transformación exacta, ausencia de secretos o rutas privadas y coherencia entre ADR 0012 y las SDD 00, 07 y 08.

## Completado anteriormente

- Constitución, README, SDD 00–08, ADR 0001–0010, fuentes, progreso y material público inicial entregados mediante la PR #2.
- Contrato OpenAPI saneado, reproducible y enlazado entregado mediante la PR #5.
- Configuración compartida, gate DocC y ADR 0011 entregados mediante la PR #8.
- Icono de Icon Composer y organización de recursos entregados mediante la PR #9.
- Enunciado saneado y ADR 0012 entregados mediante la PR #10; la privacidad se activó externamente antes del primer push de esa entrega.
- Reconciliación documental G0 entregada mediante la PR #12; issue #11 cerrado.
- Primera página pública de Catálogo y detalle local entregados mediante la PR #14; issue #13 cerrado.
- Arquitectura feature-first, navegación local, contratos de SwiftData, autenticación/sync, WidgetKit/watchOS y DocC selectivo aprobados y auditados.
- Separación entre `/docs`, catálogo DocC, artefactos generados y memoria privada definida.

## Hoja de ruta Advanced

La lista de capacidades de la SDD 00 es una puerta de aceptación, no un orden de implementación. El orden operativo parte de dos decisiones ya aprobadas: la colección local se identifica por **usuario + manga** y no existe una política de colección anónima. S1, S2, S2.1, S2.2, L1 y L2 están entregados; L2 se incorpora mediante la PR #50. La secuencia completa es:

1. **S1 — identidad y sesión JWT única, entregado mediante la PR #59.** La PR #34 introdujo originalmente el flujo dual y el ledger descrito por [ADR-0016](adr/0016-versioned-session-ledger-and-keychain-boundary.md); la corrección del 2026-09-01 lo sustituyó por Keychain V2. ADR-0019 adopta ahora `jwt/login` → `jwt/me`, un único envelope Keychain V3, renovación preventiva mediante `jwt/refresh`, contraseña solo en memoria, single-flight, generaciones de sesión y estados básicos de Cuenta. El logout local cubre el escenario sin operaciones pendientes, pero no acredita todavía el gate Advanced que dependerá de la outbox.
2. **S2 — alta de usuario, entregado.** `POST /users` con `App-Token` inyectado desde configuración local ignorada y alta enlazada con login, entregado mediante la PR #36. Una escritura live continúa necesitando autorización separada. S2 no añade todavía Colección.
3. **S2.1 — acciones accesibles de Cuenta, entregado.** La PR #38 da jerarquía primaria y secundaria a las acciones sin sesión, incorpora el prompt de alta y conserva objetivos táctiles nativos y contraste adaptativo sin cambiar sesión, red o persistencia.
4. **S2.2 — formularios de credenciales, entregado mediante la PR #40.** SDD 01 v1.4 y SDD 04 v1.13 definen propiedad de pantalla, gramática conservadora compartida y la compatibilidad exacta del alta con `200` publicado y `201` observado; login y alta presentan errores inline, mantienen los fallos no atribuibles a nivel de formulario, permiten mostrar u ocultar la contraseña con controles SwiftUI sin perder contenido o foco y conservan acciones primarias accesibles. El estado autenticado presenta la identidad segura y el logout con la misma jerarquía visual. No inicia persistencia de producto.
5. **L1 — núcleo SwiftData de Colección, entregado mediante la PR #44.** El composition root crea una sola vez el `ModelContainer` live, declara el esquema V1 y persiste Colección y outbox mediante una capacidad `@ModelActor` compartida. La primera mutación valida invariantes y guarda ambos estados atómicamente, sin una ruta local provisional.
6. **L2 — Colección local y offline, entregada mediante la PR #50.** `@Query` queda restringida a la identidad activa y excluye tombstones; Colección posee navegación independiente y alta, edición y eliminación mediante la ruta semántica de L1. El esquema V2 añade presentación offline con migración lightweight, y tomos, lectura, colección completa, tombstones y aislamiento A/B sobreviven a reapertura sin red.
7. **R1 — lectura e importación remota, entregada mediante la [PR #54](https://github.com/JFrancoG/MangaLibrary/pull/54).** Consume la colección de la persona autenticada al iniciar o restaurar sesión y reconcilia el snapshot completo en SwiftData sin pisar intenciones locales posteriores. Aquí empieza la integración con la persistencia remota; la UI continúa observando exclusivamente el estado local.
8. **R2 — envío y reconciliación de outbox.** R2.1 y R2.2 están entregados mediante la PR #60. La decisión del propietario del 2 de septiembre fija `{id}` como `Manga.ID` `int64` serializado en decimal; el UUID de entrada no forma el path y la discrepancia `string` queda como deuda contractual. R2.1 reutiliza el GET completo R1 e implementa POST y procesamiento conservador de intenciones no tombstone; R2.2 añade GET/DELETE individual, tombstones y la confirmación destructiva de UI. Ambos cortes están validados localmente y R2.2 cuenta con aceptación live multidispositivo de la ruta decimal y la ausencia reconciliada; el status/body exacto del primer DELETE y el GET presente `200` siguen sin caracterización directa. R2.3 se entrega mediante la PR #68 con retry/backoff seguro, `blockedAuth` recuperable y rechazo positivo con reversión atómica. R2.4 se entrega mediante la PR #70 con revisión fresca, adopción remota o nueva intención consciente y resolución atómica del `blockedOutcome`.
9. **Cota transversal de números de tomo, entregada mediante la PR #64.** Fija 300 como máximo inclusivo compartido, preserva `nil` como total desconocido y protege editor, mutación, R1 y R2 frente a valores históricos o remotos fuera de rango sin truncado ni transporte accidental.
10. **Advanced Release Gate — aceptado y entregado mediante el issue #75 / PR #76.** A1 se entrega mediante la PR #72 y Q2 mediante la PR #74. La automatización global acredita build, planes, Swift Testing, UI en iPhone/iPad, ReleaseGate, DocC, contrato e integridad sin warnings ni allowlists. La matriz manual está completa con VoiceOver, Control por voz y Switch Control en iPhone físico y Acceso total con teclado en iPad simulado, sin extrapolar este último a hardware. La fusión `06170b7` del 6 de septiembre de 2026 habilita la entrada a Deluxe.
11. **Deluxe — plan aprobado en el issue #77.** DX1–DX4 entregadas mediante PR #80, #81, #83 y #85 (4/7). DX4 se integra en `1868244`, con #84 cerrado y rama retirada: target WidgetKit, App Group, UI y composición live, con tests completos, builds limpios y DocC, lectura entre procesos observada en iPhone Simulator y adaptación y continuidad entre ventanas iPad verificadas. La validación automatizada, Simulator y física DX4 están completadas en su alcance; la comprobación física anterior al primer desbloqueo se traslada a DX6 por aprobación del propietario del 2026-09-08, como limitada/no observable y pendiente para el gate Deluxe, junto a la ampliación combinatoria. DX5 está implementada y validada localmente en el issue #86, con UI/cache representativas y entrega WatchConnectivity observadas en Simulator, con entrega autorizada y en preparación. La ampliación combinatoria y la evidencia física de Apple Watch permanecen en DX6/DX7.

S2 no es una dependencia técnica del esquema L1 cuando ya existe una identidad autenticable, pero permanece antes del gate Advanced y en una unidad separada porque incorpora el `App-Token`. S2.1 y S2.2 cierran superficies de Cuenta sin iniciar persistencia de producto. La outbox sí pertenece a L1: el worker de R2 puede llegar después, pero ninguna mutación expuesta puede escribir Colección sin registrar o coalescer su intención en la misma operación lógica.

### Trabajo transversal pendiente

1. Ampliar la matriz visual y de tecnologías de asistencia a las superficies Deluxe conforme se implementen, conservando el alcance y los límites de la evidencia Advanced ya aceptada.
2. Revisar ADR 0020 ante cualquier cambio de toolchain o antes de adoptar App Intents; retirar la omisión cuando exista esa capacidad real.
3. Mantener la clasificación de cada suite nueva mediante su target y tag en el mismo cambio que la introduce.
4. Preparar evidencia, presentación y mecanismo final de entrega cuando exista confirmación externa.

## Estado técnico aún no alcanzado

- ADR 0020 supersede la excepción de ADR 0011 y el gate técnico vuelve a quedar limpio: la fase de metadata de App Intents no aplicable no se construye y cualquier warning o error continúa siendo bloqueante.
- Catálogo C1–C4, D1, Q1, P1 y Library Red están entregados. La limpieza posterior de tests tautológicos de consulta está en `main@1839c29` y no cambia comportamiento de producto.
- S1 conserva como historia la sesión dual de la PR #34 y la corrección Keychain V2 del 2026-09-01. La PR #59 entrega el JWT único y Keychain V3 conforme a ADR-0019.
- La entrega original de S2 no acreditó una escritura live; la observación manual posterior de `201` y su compatibilidad quedan registradas en S2.2 sin exponer datos de cuenta.
- S2.2 entregó mediante la PR #40 la validación y presentación de credenciales y la autoridad Keychain V2 vigente en ese momento; #58 cambia solo la infraestructura de sesión a JWT único/V3 y no altera el workflow visual ni incorpora persistencia de producto.
- L1 entrega mediante la PR #44 `ModelContainer`, esquema V1, modelos SwiftData, outbox y primera mutación atómica. L2 entrega mediante la PR #50 el esquema V2, `@Query`, presentación offline y UI de Colección. R1 entrega mediante la PR #54 la lectura e importación remota con reconciliación local-first. R2.1/R2.2 entregan mediante la PR #60 el POST, GET/DELETE individual, vaciado seguro de intenciones no tombstone y tombstones, con aceptación live multidispositivo y la deuda contractual descrita en su evidencia. R2.3 se entrega mediante la PR #68 con retry/backoff seguro, recuperación de `blockedAuth` y rechazo/reversión atómicos. R2.4 se entrega mediante la PR #70 con resolución manual durable de `blockedOutcome`.
- A1 se entrega mediante la PR #72 y Q2 mediante la PR #74. El issue #75 / PR #76 entrega Advanced con los gates automáticos y la matriz manual aceptados. Deluxe conserva el plan aprobado #77; DX1–DX4 están entregadas mediante PR #80/#81/#83/#85 (4/7). DX4 está integrado en `1868244`, con #84 cerrado y rama retirada, y con validación automatizada, Simulator y física completadas en el alcance DX4 aprobado; primer desbloqueo físico limitado/no observable transferido a DX6 y pendiente para el gate Deluxe; DX5 está implementada y validada localmente en #86, con entrega autorizada y en preparación; DX6/DX7 no se inician y conservan ampliación combinatoria, hardware, accesibilidad y gate global.
- DX4 materializa target, entitlements App Group, consumidor WidgetKit y composición live de ADR 0010. Los gates técnicos y los recorridos iPhone/iPad Simulator están completados en su alcance. DX4.5 completa su evidencia física en el alcance aprobado. DX6 conserva la prueba física anterior al primer desbloqueo, limitada/no observable y pendiente para el gate Deluxe, además de la ampliación combinatoria. watchOS y WatchConnectivity quedan implementados y validados localmente en DX5, con evidencia representativa de Simulator y límites registrados en su checklist; su entrega está autorizada y en preparación.
- La evidencia histórica de icono, sesión y accesibilidad se complementa con la matriz vigente de #75: VoiceOver, Control por voz y Switch Control en iPhone 11 físico, y Acceso total con teclado en iPad simulado. Sus límites se conservan en el apartado Advanced; no acredita App Group o WatchConnectivity, capacidades que pertenecen a Deluxe.
- No se ha autorizado publicación DocC ni GitHub Pages.

## Pendiente externo

El mecanismo académico final de entrega no estaba confirmado en las fuentes. Se añadirá aquí cuando exista una indicación verificable.

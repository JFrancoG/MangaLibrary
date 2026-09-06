# SDD 06: Testing, calidad y accesibilidad

**Estado:** Aprobada
**Versión:** 1.34
**Fecha:** 2026-09-04

## Propósito

Definir evidencia proporcional al riesgo para entregar Advanced y Deluxe con cero warnings, sin confundir cantidad de tests con cobertura real.

## Estrategia híbrida

- **Swift Testing** cubrirá tests unitarios y de integración nuevos.
- **XCTest/XCUITest** se reservará para automatización de interfaz.
- No se mezclarán aserciones de ambos frameworks dentro del mismo test.
- El comportamiento nuevo testeable seguirá RED/GREEN. Documentación, configuración y exploración visual registrarán validación proporcional con TDD marcado como no aplicable.
- Ningún test automatizado llamará al servicio de producción.
- No se probarán conformidades exigidas por el compilador, inicializadores triviales ni wiring sin ramas solo para aumentar la cantidad de tests.

## Planes previstos

| Plan | Responsabilidad | Ejecución mínima |
| --- | --- | --- |
| `Fast` | Invariantes, transformaciones, estados y lógica determinista | Cada cambio de comportamiento |
| `Integration` | SwiftData, migraciones, URLProtocol, Keychain aislado y composición de fronteras | Cambios en datos, red o sesión |
| `UI` | Flujos críticos, adaptación y accesibilidad automatizable | Gate Advanced y cambios de navegación |
| `ReleaseGate` | Todos los targets de test pertenecientes al producto en el gate actual | Candidatas Advanced y Deluxe |

Los cuatro ficheros versionados viven en `TestPlans/` y el scheme compartido
`MangaLibrary` deja `Fast` como plan predeterminado. Los planes unitarios usan
filtros Include Tags de Swift Testing. Cada suite de `MangaLibraryTests` declara
exactamente una clasificación heredable: `fast` para valores, bytes, recursos
locales y capacidades directas deterministas; `integration` cuando cruza una
frontera real controlada de `URLSession`, Keychain, SwiftData, migración,
persistencia o composición. Los tags no se duplican en cada `@Test` ni se
sustituyen por listas de nombres. `UI` contiene únicamente
`MangaLibraryUITests`.

`Scripts/validate-test-plans.sh` es el gate estático de esta clasificación. La
categoría permanece legible en la misma línea que `@Suite` para que el gate no
dependa de un parser o paquete externo. Debe fallar si una suite carece de
categoría, declara ambas, repite esos tags en un test, deriva los filtros o
targets de cualquier plan, o deja de mantener `Fast` como predeterminado. Toda
suite nueva actualiza y supera este gate en el mismo cambio que la introduce.

La selección runtime de `Fast` e `Integration` se acredita ejecutando cada plan
con el runner nativo y leyendo `totalTestCount`, aprobados, fallos y omisiones
del resumen de su `.xcresult`. La suma de ambos inventarios debe cubrir todas las
declaraciones Swift Testing y el gate estático garantiza su partición exclusiva
por suite. `GetTestList` puede servir como inventario y localizador, pero su
campo `isEnabled` no es autoridad de selección mientras el bridge de Xcode 27 no
proyecte los tags heredados de `@Suite`.

`ReleaseGate.xctestplan` incluye completos los targets `MangaLibraryTests` y
`MangaLibraryUITests`. Por ello también detecta un test nuevo todavía no
clasificado en un plan más estrecho. El fichero compone solo la ejecución de
tests: el Release Gate de producto combina por separado build limpio, este plan,
DocC y la evidencia no automatizable aplicable. No se atribuyen a un
`.xctestplan` capacidades de build o documentación que Xcode no ejecuta desde él.

### Aplicabilidad por gate

Los planes seleccionan únicamente suites y targets que pertenecen al gate en
evaluación. Advanced prueba el envelope Keychain V3, refresh JWT, logout binario,
outbox, aislamiento y navegación definidos por SDD 04 sin exigir App Group,
`SessionFence`, WidgetKit o WatchConnectivity. Deluxe vuelve a ejecutar Advanced
y añade las suites del bridge compartido, sus targets y sus entitlements.

Un tipo no implementado, un target ausente o un bridge no-op no cuentan como
evidencia. Los casos Deluxe enumerados debajo permanecen como contrato futuro,
pero no bloquean una candidata Advanced anterior a su gate de entrada.

## Cobertura por riesgo

### Unidad

- invariantes de colección y transiciones de edición;
- política única de números de tomo: `nil` conserva total desconocido, 299 y 300
  son válidos, y 301 e `Int64.max` se rechazan antes de construir rangos tanto
  con total conocido como desconocido;
- Catálogo distingue `nil` real de un total wire explícito fuera de `1...300`: el
  primero permanece desconocido y el segundo rechaza la página sin proyectarlo;
- un seed histórico incompatible no materializa `1...total`, no permite una
  edición ordinaria y conserva sus valores mientras expone una categoría segura;
- composición y reinicio de consultas y filtros;
- mapeo de errores de transporte, sesión y dominio;
- máquina de estados de autenticación y sincronización;
- exclusión serializada de activación durante logout y efectos condicionados por
  la generación del bundle Keychain vigente;
- logout Advanced binario: un fallo de borrado conserva la sesión y un éxito
  publica `signedOut`, sin fase durable intermedia;
- logout con outbox: todos los estados no `confirmed` exigen una decisión,
  esperar reactiva la sesión con una revisión nueva y descartar restaura cada
  base o ausencia en una transacción, conserva el cursor máximo como
  `confirmed` y no reinicia la secuencia;
- un fallo SwiftData al comprobar o descartar pendientes conserva Keychain y se
  presenta como indisponibilidad de Colección, distinta de un fallo de
  persistencia segura de la sesión; mantiene la sesión activa si el JWT sigue
  vigente y converge a `authenticationRequired` si vence durante el intento;
- punto de no retorno y rechazo de cancelación tras un fence Deluxe cerrado y verificado;
- coalescencia, reintento, cancelación e idempotencia de mutaciones;
- clasificador R2.3 cerrado: solo una señal positiva de una frontera
  caracterizada que demuestre que el envío no comenzó permite `retry`; timeout,
  conexión perdida, status no publicado, divergencia reconciliada y resultado
  todavía ambiguo conservan `blockedOutcome`;
- política de backoff `1, 2, 4, 8, 16, 30` segundos, tope posterior de 30
  segundos, contador sin wrap y selección del deadline accionable más temprano;
- `Codable & Sendable`, compatibilidad y estados del snapshot Deluxe;
- `publicationGeneration`, `sessionGeneration`, revisión `UInt64` estrictamente monotónica y persistida sin wrap y rotación de epoch con fence cerrado;
- `SessionFence` versionado, `fenceRevision`, sesión opcional permitida y decisión del provider mediante doble lectura idéntica alrededor del envelope;
- selección de eventos, serialización del publicador, distinción entre contenido y sanitización y revalidación de la sesión esperada antes del reemplazo;
- diferencia entre fallo ordinario y cierre fail-closed, incluido el aborto de logout si no puede persistirse o verificarse el fence;
- orden write-before-reload, supresión de reload tras fallo inseguro y selección del `kind` de widget afectado;
- `StaticConfiguration`, `TimelineProvider`, timeline `.never`, proyección común y ausencia de configuración por App Intent;
- manifest, portada inmutable local o placeholder, retención y limpieza;
- estados y cancelación de modelos de feature `@Observable @MainActor` cuando sean propietarios reales de ese workflow.
- modelo R2.4 con estados de carga, presencia, ausencia, incompatibilidad, fallo,
  cambio remoto y resolución; una cancelación o ruta abandonada no ejecuta la
  capacidad ni conserva una decisión obsoleta.

### Integración

- CRUD SwiftData con un `ModelContainer` aislado y verificación desde otro contexto;
- migración mediante un store temporal en disco creado con el esquema anterior;
- transporte HTTP mediante un `URLProtocol` limitado a la `URLSession` de test: bytes exactos, respuesta no HTTP, status inesperado, fallo de transporte y cancelación;
- ciclo JWT único con `/users/jwt/login`, `/users/jwt/refresh` y
  `/users/jwt/me`, un único envelope Keychain V3 sustituible y sin credenciales
  reales; cada refresh validado rota una revisión opaca no persistida, incluso si
  el texto JWT se repite, y las capacidades anteriores dejan de autorizar;
- restauración dentro de la ventana preventiva que comparte el refresh, valida
  `/users/jwt/me` una sola vez y reutiliza la identidad comprobada sin un
  segundo rechazo destructivo; el borde exterior, interior y un JWT ya expirado
  se prueban con reloj inyectado; login y refresh tampoco persisten un JWT que
  expire mientras `/users/jwt/me` está suspendido, y un fallo transitorio no
  conserva autoridad si el JWT anterior expira durante el vuelo; las suspensiones
  y fallos de escritura Keychain prueban además que una credencial expirada nunca
  se publica, que el envelope anterior solo se conserva mientras siga vigente y
  que un registro residual tras una limpieza fallida puede sustituirse mediante
  un login posterior; la expiración después de restaurar con `/jwt/me` `200` o
  fallo transitorio, después de resolver una autorización y durante transporte
  impide emitir o aplicar efectos con el JWT vencido; login y refresh que reciben
  un JWT ya vencido en el siguiente preflight no lo envían a `/jwt/me`;
- atributos no sincronizables y no migrables, account fijo sin PII, formato cerrado
  y rechazo seguro de V1/V2, una versión desconocida o un envelope corrupto;
- crash antes y después del borrado binario de A, bloqueo de una activación B
  concurrente y efectos tardíos de A convertidos en no-op después de activar B;
- fallo de borrado que conserva A activa y permite reintentar, y cancelación
  reconciliada después de que el commit Keychain haya terminado;
- fallo de inspección o descarte que no inicia el borrado Keychain y revierte
  todo SwiftData; fallo Keychain posterior al descarte que conserva A activa
  sin resucitar las intenciones ya descartadas;
- fallo de borrado de logout que cruza la expiración: conserva el envelope
  residual y el error de limpieza, pero proyecta `authenticationRequired` y no
  reactiva la gate;
- logout e invalidación rechazados con `transitionInProgress` mientras un refresh
  espera el reemplazo Keychain; al reanudarse no divergen el JWT activo en
  memoria y el envelope durable;
- vuelos single-flight con handshakes deterministas que demuestran que el segundo
  waiter se ha unido antes de liberar el transporte; un vuelo completado de A no
  entrega su JWT después de activar B; una recuperación A→B suspendida se une a
  un reemplazo B→C ya iniciado y ambos consumidores reciben únicamente C;
- cancelación anterior a un fallo compartido de carga, guardado, reemplazo o
  limpieza Keychain: la operación conserva `temporarilyUnavailable` o
  `persistenceUnavailable`, y Cuenta lo aplica o enriquece únicamente para UUID
  y generación exactos aunque se cancele el reconciliador activo; si el snapshot
  exacto sigue activo tras fallar un reemplazo, la sesión permanece autenticada
  y Cuenta muestra el aviso de persistencia;
- rechazo permanente que borra el bundle, publica `authenticationRequired` solo en
  el proceso vigente y restaura `signedOut` tras un relanzamiento;
- reinicio con outbox pendiente, pérdida de red, bloqueo de autenticación y rechazo permanente;
- cliente R1 con request `GET /collection/manga` exacto, Bearer sintético,
  status `200`, DTO compartido, `readingVolume` ausente o nulo y rechazo de
  identidad, enum, payload o duplicados incompatibles con el snapshot completo;
- coordinador R1 con autoridad inyectada, cancelación y reemplazo de ejecución,
  trigger tardío ya cancelado, revalidación rápida y gate linealizable durante
  el commit; `403` vigente conserva sesión y Keychain sin refresh ni retry; el
  primer `401` fuerza una renovación single-flight ligada a generación y JWT,
  revalida `/users/jwt/me` antes de publicar el JWT y ejecuta un único segundo GET; la
  composición real cliente + sesión + coordinador + SwiftData cubre tanto ese
  éxito como el `401` observado durante un logout cuyo borrado falla; el refresh rechazado
  permanentemente produce `authenticationRequired`; un segundo `401` o un `403`
  del retry conserva la sesión y expone una categoría de Colección; las carreras
  A→B, ABA y logout fallido no reactivan el JWT rechazado ni afectan a una
  sesión o credencial posterior; un refresh A suspendido, seguido de logout A y
  login B, no bloquea la autorización ni la recuperación de B y termina cercado
  al reanudarse;
- refresh preventivo rechazado por `/users/jwt/me` durante la autorización
  inicial R1: expone incompatibilidad de identidad renovada y no ejecuta fetch ni
  importación;
- JWT que vence entre la revalidación R1 y el commit SwiftData: la gate rechaza
  el lote, el coordinador vuelve a Sesión, invalida la credencial y no modifica
  colección ni outbox;
- mutación local iniciada desde Cuenta autenticada cuando el JWT acaba de
  expirar, incluso después de emitir la capacidad y antes de la segunda cerca:
  no crea estado ni outbox, fuerza invalidación de sesión y reconcilia Cuenta
  como `authenticationRequired` sin dejar una presentación falsamente
  autenticada; los fallos de limpieza `temporarilyUnavailable` y
  `persistenceUnavailable` conservan su categoría segura;
- editor/comando de generación A enviado tras activar B con el mismo UUID: el
  wrapper no solicita capacidad y el model actor también rechaza directamente
  una capacidad válida de B, sin crear entrada ni outbox; una revisión nueva de
  la misma generación permite solo el retry previo al commit ya definido;
- composición `jwt/login` → `jwt/me` → envelope V3 → autorización R1 que
  demuestra que el mismo JWT sintético llega como Bearer al primer snapshot de
  Colección;
- importación R1 sobre un `ModelContainer` V2 aislado, observada desde otro
  contexto: snapshot presente, intención pendiente, ausencia remota, aislamiento
  por usuario, canonicalización, error tipado del lote inválido y rollback real
  después de la primera mutación de un único commit;
- importación R1 con total, propiedad o lectura 301 e `Int64.max`: validación
  anterior a cualquier rango, rollback del lote completo y conservación de
  sesión, Keychain, Colección y outbox; la única excepción cubierta es la presencia
  opaca del manga cuya primera intención es una tombstone procesable, sin importar
  sus valores ni confirmar ausencia;
- cliente POST R2.1 con request y JSON exactos, `readingVolume` nulo explícito,
  Bearer sintético, ausencia de `App-Token`, status exacto `200` e `Int64` opaco;
- cliente R2.2 con GET y DELETE individuales exactos, `Manga.ID` decimal,
  Bearer sintético y sin UUID remoto, body ni `App-Token`; `200` valida la entrada
  solicitada o el `Int64` opaco y el `404` descrito se representa únicamente como
  ausencia del GET;
- worker R2 y transiciones persistidas observadas desde otro contexto: claim
  ordenado por pareja, inclusión de tombstones, cerca de usuario/generación/
  operación/secuencia, UUID o secuencia obsoletos que no pueden confirmar,
  autorización de petición rechazada antes del claim que conserva `queued` y
  realiza cero POST, confirmación que no pisa una intención posterior, mapping de
  cancelación y cambio de sesión en cada frontera del store y recuperación de
  `sending` sin repetir el POST;
- intención R2 no tombstone con estado histórico fuera de `1...300`: error local
  anterior al claim, cero requests, cero transición parcial y ninguna alteración
  de otra secuencia; su eliminación explícita sí crea y envía una tombstone cuyo
  DELETE no contiene números de tomo;
- cursor N ya `confirmed` con estado histórico incompatible y tombstone N+1: R1
  conserva ambas operaciones y R2 puede reclamar N+1 sin volver a validar o enviar
  el payload confirmado;
- POST N histórico incompatible recuperado en `sending` seguido de eliminación:
  la mutación lo deja sin efecto atómicamente sin marcarlo confirmado, conserva
  N+1, R1 no adopta la fila incompatible ni la trata como ausencia y R2 reclama
  la tombstone como DELETE; una tombstone ya `sending` conserva la presencia
  incompatible como evidencia opaca, pasa a `blockedOutcome` y no repite DELETE;
- operación bloqueada anterior seguida de tombstone y fila remota incompatible:
  R1 no concede la excepción contextual, revierte el lote y conserva ambas
  operaciones;
- pipeline R1 → R2 sobre SwiftData real: una `sending` recuperada reutiliza el
  único snapshot R1 con exactamente un GET total y cero POST; match confirma y
  ausencia bloquea. Fallo de lectura o de importación ordinario bloquea sin otra
  request; cancelación, cambio de sesión, snapshot A frente a autorización B y
  fallo A tardío conservan la operación de la generación vigente; una importación
  no cooperativa que termina tras cancelarse no expone un snapshot reutilizable;
- reemplazo single-flight con POST suspendido: el vuelo anterior se cancela sin
  confirmación tardía, el sustituto reconcilia `sending` y existe un solo POST;
  un fallo R1 tardío cuyo vuelo ya está cancelado no interrumpe el POST vigente;
  un snapshot o callback R1 tardío de A no cancela el vuelo B suspendido, que
  conserva un único POST y confirma solo para B; en sentido inverso, un trigger
  B vigente sí cancela el POST A suspendido y reconcilia la intención sin una
  segunda escritura, y su callback de fallo R1 bloquea solo la recuperación B;
- fallo incierto de POST con exactamente un GET completo de reconciliación:
  coincidencia confirma; ausencia, diferencia o lectura fallida dejan
  `blockedOutcome`, conservan sesión y estado local y realizan cero reintentos de
  escritura; un bloqueo persistido continúa presentando su aviso cuando el GET
  R1 de un trigger posterior falla antes de alcanzar el worker;
- DELETE confirmado que retira una tombstone sin N+1 y conserva el cursor de
  secuencia; con una intención posterior solo registra ausencia como nueva base.
  Un fallo local de resolución después del `200` conserva su error, ejecuta cero
  GET y no crea un bloqueo ambiguo.
  Un DELETE incierto realiza un único GET individual: `404` confirma, una entrada
  `200` o un fallo ordinario bloquean y ningún caso repite DELETE; una tombstone
  `sending` recuperada reutiliza el snapshot R1 sin otra request;
- resolución R2.4 con store SwiftData real: presencia y ausencia frescas al
  aceptar nube o conservar dispositivo; coincidencia que confirma sin nueva
  escritura; nueva UUID y secuencia solo ante divergencia sin N+1; usuario,
  manga, UUID, secuencia, estado, payload y autoridad obsoletos; UUID duplicado,
  overflow, cancelación y fallo de persistencia con rollback conjunto;
- operación N bloqueada con N+1 posterior: actualiza base, confirma solo N,
  conserva estado y N+1 intactos, no crea N+2 y provoca una única reanudación del
  worker; otra pareja y otro usuario no cambian;
- coordinador R2.4 con GET individual, primer `401` seguido de recuperación y un
  único retry, segundo `401`, `403`, red, contrato incompatible y sesión
  reemplazada; compara de nuevo antes del commit y una nube cambiada conserva el
  bloqueo con cero escrituras;
- R2.3 con reloj controlado y store SwiftData real: `sending → retry` persiste
  contador y deadline; antes de vencer realiza cero requests, al vencer reutiliza
  UUID y secuencia una sola vez, y una pareja accionable no queda bloqueada por
  el deadline futuro de otra;
- edición y eliminación durante backoff: una `retry` inequívocamente no enviada
  se coalesce con el mismo UUID, secuencia nueva y backoff limpio. Si N recibe la
  clasificación pre-envío después de crear N+1, N se retira y solo N+1 puede
  progresar;
- cancelación posterior a la clasificación pre-envío: persiste N como `retry` o
  la retira ante N+1 antes de propagar cancelación, y ejecuta cero requests
  posteriores;
- cancelación, relanzamiento y sustitución A→B durante el backoff: el deadline
  permanece durable, una respuesta o wakeup tardíos no envían y cada reanudación
  vuelve a validar usuario, generación, operación y autorización de commit;
- pérdida de autoridad que convierte únicamente `queued` y `retry` seguros del
  usuario en `blockedAuth`; una `sending` incierta conserva reconciliación. R1 y
  una sesión válida posterior del mismo UUID reactivan la operación, mientras
  otro usuario, una generación sustituida o una gate vencida realizan cero
  transiciones y cero requests;
- rechazo permanente proporcionado por una clasificación positiva inyectada:
  restaura atómicamente una base presente o ausente, recupera una entrada tras
  rechazar su tombstone, conserva N+1 visible y revierte ambas mitades ante fallo
  de persistencia. Ningún status o body no publicado activa por sí solo esta ruta;
- escritura y lectura concurrentes del snapshot y portadas en App Group, fallo de disco, manifest anterior, retención y limpieza, en directorios temporales y después en sandbox o dispositivo autorizado;
- recuperación tras crash en la secuencia fence cerrado → invalidación/Keychain → envelope redactado → reload;
- doble lectura con sustitución concurrente del fence; sesión B cuyo envelope precede a la apertura; sanitización tardía de A convertida en no-op tras abrir B;
- bootstrap Deluxe cerrado ante una sesión Advanced activa, autorización explícita de su propietario y revalidación antes de abrir el fence;
- WatchConnectivity no alcanzable y reemplazo del contexto pendiente mediante `WCSession.updateApplicationContext(_:)`, incluidos epoch nuevo y entrega tardía de A sin bootstrap observado;
- composición del widget sin SwiftData, Keychain, red, polling, ActivityKit, WidgetKit push ni `BGTask`.

#### Matriz focal R2.3

| Caso | Estímulo controlado | Oráculo independiente |
| --- | --- | --- |
| Fallo inequívocamente pre-envío | El transporte inyectado acredita que no inició la request | `sending → retry`, `retryCount` incrementado y primer deadline a +1 s; cero reconciliaciones y cero escrituras remotas observadas. |
| Resultado potencialmente aplicado | Timeout, conexión perdida tras iniciar transporte, respuesta no HTTP, body inválido o status no caracterizado | Ejecuta solo la reconciliación aplicable; si no concluye conserva `blockedOutcome`, sesión y estado local, sin segundo POST/DELETE ni status inventado. |
| Reconciliación demuestra que la intención no se aplicó | Snapshot o GET individual caracterizado diverge del efecto deseado | Conserva `blockedOutcome`, no repite la escritura y difiere a R2.4 cualquier nueva intención consciente. |
| Secuencia y tope del backoff | Se clasifican seis fallos retryables y después más fallos sobre la misma operación | Deadlines relativos 1, 2, 4, 8, 16 y 30 s; los posteriores continúan en 30 s y el contador no hace wrap. |
| Espera y vencimiento | El reloj permanece antes del deadline y luego avanza exactamente hasta él | Antes: cero requests. Al vencer: una transición `retry → sending` y una única request con el mismo UUID y secuencia. |
| Parejas independientes | A tiene deadline futuro y B está `queued` o `retry` vencida | B progresa sin esperar a A; el worker solo suspende cuando no existe otra pareja accionable. |
| Cancelación, relanzamiento y reemplazo | Se cancela la espera, se recrea el coordinador o el mismo coordinador sustituye un vuelo suspendido | Persisten `retryCount` y `nextRetryAt`; el sustituto respeta el mismo deadline, no hay request tardía y cada reanudación vuelve a validar usuario, generación, UUID y secuencia. |
| Cancelación tras evidencia pre-envío | El vuelo se cancela después de que la frontera acredita que N no se envió | El commit local de esa evidencia termina: N queda `retry` o se retira ante N+1; después no se reclama ni envía más trabajo. |
| Pérdida de autoridad | La sesión confirma pérdida mientras existen `queued`, `retry` y `sending` incierta | Solo `queued` y `retry` del mismo usuario pasan a `blockedAuth`; `sending` conserva la ruta de reconciliación y Keychain no se muta desde R2. |
| Expiración en frontera R2 | El JWT vence después de la revalidación rápida y antes de reservar el vuelo o de cualquier commit del store | La gate impide reservar o mutar, R2 vuelve a Sesión, retira el envelope y pasa el trabajo seguro a `blockedAuth`; cero requests. |
| Recuperación de autorización | R1 termina bajo una sesión válida del mismo UUID | Conserva una única intención segura no enviada vigente por manga; una N+1 `queued` o `retry` más reciente prevalece sobre N `blockedAuth`. Otro UUID, una generación obsoleta o una gate vencida producen cero cambios y cero requests. |
| Edición durante backoff | La persona edita o elimina mientras N está `retry`, o crea N+1 antes de clasificar N como no enviada | La intención vigente queda en una única operación procesable; no se envía primero el payload obsoleto ni se conserva su deadline. |
| Recuperación de DELETE histórica segura | N es un POST seguro no enviado, N+1 una tombstone y ambos están en `blockedAuth`, `queued` o `retry`; R1 recibe presencia remota incompatible | R1 conserva la presencia opaca, la recuperación retira N y solo N+1 progresa como DELETE; cualquier predecesora incierta mantiene el rechazo fail-closed. |
| Rechazo positivo con base presente o ausente | El clasificador inyectado devuelve rechazo permanente | La misma transacción restaura la base confirmada o la ausencia y resuelve `sending → rejected → confirmed`; ningún error live no caracterizado activa la ruta. |
| Rechazo de tombstone y N+1 | Se rechaza DELETE con base presente o existe una intención posterior N+1 | Restaura la entrada confirmada cuando corresponde y conserva N+1 como estado visible y pendiente. |
| Fallo de reversión | El store inyecta un fallo al persistir la restauración | Rollback conjunto: Colección y outbox retienen el estado previo, sin restauración parcial ni cursor `confirmed` falso. |

#### Matriz focal R2.4

| Caso | Estímulo controlado | Oráculo independiente |
| --- | --- | --- |
| Revisión presente o ausente | GET individual devuelve `200` compatible o `404` | La pantalla compara dispositivo con presencia o ausencia; todavía no cambia SwiftData ni ejecuta una escritura. |
| Lectura no utilizable | Red, `403`, segundo `401` o payload incompatible | Las decisiones permanecen ocultas, sesión y Keychain siguen activos y Colección/outbox no cambian. |
| Aceptar nube | Evidencia fresca estable, sin N+1 | La presencia se aplica o la ausencia retira la entrada, N pasa a `confirmed` y se observan cero POST/DELETE. |
| Mantener dispositivo divergente | Evidencia fresca estable, sin N+1 | N pasa a `confirmed`; existe una sola operación nueva `queued`, con UUID distinta y secuencia mayor, para el mismo estado local. |
| Efecto ya demostrado | La evidencia fresca coincide con el estado deseado de N | N se confirma y no existe nueva operación ni escritura. |
| Intención posterior | N está bloqueada y N+1 continúa pendiente | N se confirma contra la base; entrada y N+1 quedan bit a bit iguales, no existe N+2 y el worker recibe un único wake explícito. |
| Cambio durante la decisión | El segundo GET difiere de la evidencia mostrada | Cero mutaciones y cero escrituras; la UI exige revisar la nueva versión. |
| Cerca o commit inválidos | Cambian autoridad/UUID/secuencia/estado o falla persistencia | Rollback de entrada y outbox; el aviso durable continúa visible. |

### Interfaz

XCUITest se limita a los menores recorridos deterministas que demuestren wiring
crítico no cubierto con Swift Testing. En el alcance actual ejecuta once; el
recorrido de Colección cubre tanto alta como eliminación confirmada:

- bootstrap mock Debug → primera fila de Catálogo → detalle de la misma
  `Manga.ID`;
- bootstrap mock Debug → abrir Filtros → descartar la sheet compacta con el
  gesto → volver a abrirla;
- bootstrap mock Debug → Cuenta → login con credenciales sintéticas → identidad
  sintética fija distinta del email introducido, sin red, Keychain ni
  almacenamiento live;
- bootstrap mock Debug → Cuenta → alta con credenciales sintéticas → login S1
  inyectado → identidad sintética fija distinta del email introducido, sin leer
  `App-Token`, usar Keychain, persistir ni alcanzar red live.
- bootstrap mock Debug → login sintético → trigger R1 con fila remota
  observada por `@Query` → detalle de Catálogo → alta por la capacidad de
  producción → segunda fila local observada por `@Query` en Colección → editor
  con botón destructivo textual → alerta nativa cancelada sin efecto y después
  confirmada → fila retirada por la capacidad de producción, con un único
  `ModelContainer` real en memoria y sin red, Keychain o disco live.
- bootstrap mock Debug → login sintético → fallo R1 de autorización → formulario
  cerrado, Cuenta todavía autenticada y aviso seguro de Colección visible, sin
  red, Keychain, disco live ni transición a `authenticationRequired`.
- bootstrap mock Debug → detalle de Colección con una proyección raíz más nueva
  que cualquier entrada disponible para una consulta contextual → resumen y
  apertura posterior del editor derivados de esa proyección, sin una segunda
  fuente SwiftData, red, Keychain o almacenamiento live.
- bootstrap mock Debug → `NavigationSplitView` regular con A persistido y el
  detalle ya seleccionado → importación B por el actor real → fila, resumen y
  apertura posterior del editor en B sin reseleccionar, red, Keychain o disco.
- bootstrap mock Debug → Cuenta autenticada con alta y tombstone
  `blockedOutcome` → aviso durable → lista → revisión determinista → cancelación
  sin efecto y resolución posterior → fila y aviso desaparecen, usando un
  container real en memoria y sin red, Keychain ni disco live.
- bootstrap mock Debug → Cuenta autenticada con `blockedOutcome` y fallo R1 de
  autorización → aviso transitorio y aviso durable visibles simultáneamente, con
  la acción de revisión accesible y sin red, Keychain ni disco live.
- bootstrap mock Debug → Cuenta autenticada con una intención `queued` → logout
  presenta un alert nativo localizado → mantener sesión conserva la identidad y
  una segunda confirmación destructiva descarta mediante el actor real y publica
  `signedOut`, sin red, Keychain ni disco live.

Un flujo UI adicional solo se incorpora cuando exista un riesgo observable que
no pueda caracterizarse con estado, modelo, integración o preview, y se elimina
cuando otra evidencia más rápida y estable lo cubra. Los tests UI no prueban
tabs placeholder, getters, persistencia local de un `@State` ya cubierta ni
variantes visuales editoriales. Nunca incluyen secretos ni dependen de datos
personales o de producción.

## Determinismo

Reloj, UUID, red, aleatoriedad y almacenamiento se inyectarán cuando afecten al resultado. No se usarán sleeps como sincronización ni se serializará una suite para ocultar estado compartido. Los oráculos procederán de contratos, fixtures controlados o cálculos independientes.

Las suites R1 usan tokens, generaciones y respuestas exclusivamente sintéticos,
un loader controlado y un container real aislado por caso. Verifican el efecto
persistido desde un `ModelContext` independiente y no acceden a Keychain, cuentas,
red o almacenamiento de producción. La clasificación documenta cobertura
prevista y no acredita por sí misma ninguna ejecución.

Las suites R2.3 sustituyen fecha y espera mediante un reloj controlado que solo
avanza por una acción explícita del test. Los oráculos leen `state`, `retryCount`,
`nextRetryAt`, Colección y base confirmada desde otro `ModelContext`; no esperan
segundos reales ni dependen del scheduler. La clasificación de rechazo permanente
se inyecta como evidencia positiva y no simula que el OpenAPI publique un status
que todavía no declara.

Los tests de frescura de WidgetKit observarán los límites sustituibles de publicación, almacenamiento y recarga. Comprobarán que cada mutación, reconciliación, reversión, restauración, importación o redacción aplicable parte de un commit local completado o fence seguro verificado y solicita una sola vez `reloadTimelines(ofKind:)` con el `kind` esperado únicamente después de dejar el bridge seguro.

En las suites Deluxe, un evento sin cambio visible no publicará ni solicitará reload. Un fallo ordinario conservará el manifest anterior de la misma sesión vigente. Un fallo al cerrar o verificar el `SessionFence` abortará logout y conservará sesión y Keychain; después de un fence seguro, un crash entre invalidación, limpieza de Keychain y envelope redactado se recuperará sin volver a autorizar A. Se probará también que el provider rechaza una lectura si los fences anterior y posterior difieren, que B no es visible antes de abrir su fence y que una sanitización tardía de A no altera B.

Se inyectarán pérdida o corrupción de contador, overflow, disco lleno y carreras A/B para verificar recuperación, rotación de epoch con fence nuevo cerrado y revalidación de sesión. Una revisión reservada que no llegó al envelope quedará consumida; un envelope ya publicado cuyo reload quedó pendiente provocará otra solicitud dirigida sin una publicación nueva. Para watchOS se verificará que una nueva llamada a `updateApplicationContext(_:)` sustituye el contexto pendiente, que un epoch nuevo reemplaza la cache compatible anterior y que un reloj no alcanzable no bloquea logout. Ningún test esperará una actualización real de WidgetKit o WatchConnectivity ni impondrá sleeps o deadlines.

## Previews deterministas

- Una preview estática puede construir directamente un estado representativo sin fingir una petición.
- Una preview interactiva de Catálogo usa un loader de dominio directo; no construye `URLSession`, `HTTPClient`, DTO, `URLProtocol` o JSON.
- Los fixtures JSON se reservan a tests del cliente tipado y `URLProtocol` a tests de `HTTPClient`; ninguna preview pretende demostrar por sí sola el pipeline completo.
- Colección usa un `ModelContainer` en memoria con el esquema real; las interacciones posteriores recorren la capacidad de mutación de producción.
- La variante histórica incompatible del editor conserva sus valores, evita
  construir un rango no acotado y presenta un mensaje localizado seguro; su
  inspección visual no sustituye los oráculos de atomicidad y cero transporte.
- Cada escenario significativo posee contexto aislado y no llama a API, Keychain ni almacenamiento live.
- R2.4 incluye previews deterministas de lista con alta y tombstone, remoto
  presente, remoto ausente, carga, fallo, incompatibilidad y N+1; ninguna preview
  presenta una base histórica como si fuese una lectura actual.
- Loading estable se modela como estado de presentación; no se simula con sleeps.
- Cuenta construye directamente estados de alta inactiva, enviando, incierta y
  creada, y usa operaciones sintéticas para el encadenado con login; ninguna
  preview lee Info.plist, `App-Token`, Keychain o red.
- Xcode MCP renderiza las variantes aprobadas como comprobación editorial; una preview no sustituye build, tests UI ni evidencia de accesibilidad.

## Warnings como errores

- Warnings de Swift y Clang bloquearán Debug y Release en todos los targets presentes y futuros.
- La concurrencia estricta no se silenciará con `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` u otros escapes no aprobados.
- DocC se validará con warnings como errores.
- Un warning de una dependencia o herramienta se atribuirá a su origen; no se presentará como un defecto corregido del código propio ni se suprimirá sin decisión explícita.

ADR 0020 supersede la excepción temporal de ADR 0011. Mientras Manga Library no
declare App Intents, la configuración compartida fija
`LM_SKIP_METADATA_EXTRACTION = YES` para que Swift Build no construya una fase
sin entradas. No se filtran warnings ni se añade una capacidad ficticia. El
gate exige el valor efectivo en todos los targets y configuraciones, la ausencia
de la tarea y cero warnings o errores; adoptar App Intents obliga a revisar y
retirar primero esta omisión.

La política común se materializa en `Configuration/Shared.xcconfig`, conectada a
Debug y Release a nivel de proyecto para que la hereden todos los targets
actuales y futuros. `Scripts/validate-advanced-build.sh` ejecuta
`build-for-testing` con el plan `ReleaseGate` en ambas configuraciones, DerivedData
temporal y destino genérico de simulador; falla ante cualquier warning, error o
tarea de metadata de App Intents. Para compilar los imports `@testable` del
target unitario bajo Release, habilita testabilidad exclusivamente como override
de esa acción local; no cambia el valor distribuido del producto ni el resto de
ajustes Release. `Scripts/validate-docc.sh` comprueba los valores efectivos de
app, unit tests y UI tests en ambas configuraciones antes de construir
documentación Release. Ambos seleccionan y verifican su Xcode sin modificar
`xcode-select`.

## Calidad de producto

- Todo texto visible residirá en String Catalog con español e inglés, incluso cuando una marca mantenga deliberadamente el mismo valor en ambos idiomas.
- Los errores visibles conservan categorías tipadas y recursos localizables; los tests validan la categoría y el String Catalog valida idiomas y formato, no se acoplan a frases traducidas exactas.
- `InfoPlist.xcstrings` explicita `Manga Library` como nombre visible invariable en inglés y español, y conserva también el nombre técnico de bundle en ambos locales.
- Las futuras descripciones de permisos se añadirán a `InfoPlist.xcstrings` en los dos idiomas junto a la capacidad real que las necesite. `Localizable.xcstrings` se creará con la primera interfaz de producto y sus textos reales; este gate no anticipa un catálogo vacío ni traducciones ficticias.
- Las vistas soportarán Dynamic Type sin truncar acciones o datos esenciales.
- VoiceOver comunicará nombre, valor, estado y acción sin depender de la portada.
- Los controles de icono del editor sin total conocido conservarán un nombre
  accesible localizado que describa la acción y un objetivo táctil mínimo de
  `44 × 44 pt`; un contorno o símbolo no sustituye ninguno de esos requisitos.
- Se comprobarán contraste, orden de foco, áreas táctiles, estados vacío/carga/error y reducción de movimiento cuando corresponda.
- Las portadas tendrán placeholder estable y la interfaz conservará significado ante fallo de imagen.
- Previews deterministas cubrirán estados representativos, pero no contarán como evidencia de UI automation.

## Contrato cromático

Library Red es el contrato cromático aprobado para Manga Library. La [especificación humana](../design/brand-palette.md) define significado, política de uso, accesibilidad y límites; el [JSON canónico](../design/library-color-tokens.json) es la autoridad exacta de valores, roles, modos, umbrales y parejas autorizadas.

La implementación ejecutable materializa los 29 roles como colorsets sRGB opacos, cada uno con Light, Dark, Increased Contrast Light e Increased Contrast Dark. No existe `AccentColor`: Debug y Release declaran `BrandPrimary` como color global del catálogo y `MainShellView` lo aplica directamente mediante `tint`. Swift Testing usa el JSON como oráculo independiente para comprobar inventario fuente, resolución runtime, componentes y las 224 parejas autorizadas sin redondeo previo. La generación de símbolos se limita a SwiftUI para conservar el rol contractual `Link` sin colisionar con `UIColor.link`.

La prueba de assets no acredita por sí sola la interfaz. Que una pareja opaca supere su ratio no demuestra contraste tras materiales, transparencia, imágenes, estados nativos o composición dinámica, ni conformidad WCAG de la app o soporte de una etiqueta de accesibilidad de App Store. Los estados renderizados continúan requiriendo auditoría proporcional.

## Gates

### Advanced Release Gate

- build limpio y cero warnings;
- `Fast`, `Integration` y flujos UI críticos aprobados;
- catálogo, colección local, autenticación y sincronización cumplen sus contratos Advanced; logout demuestra decisión ante outbox pendiente, descarte transaccional, secuencia monotónica, borrado condicional del bundle Keychain, conservación de la sesión ante fallo, exclusión de otra activación y efectos tardíos condicionados sin depender de un bridge Deluxe;
- accesibilidad y adaptación verificadas en la matriz acordada;
- documentación y evidencia actualizadas.

### Deluxe Release Gate

- Advanced continúa en verde;
- widget y watchOS satisfacen la [SDD Deluxe](05-deluxe-watch-and-widget.md);
- el `SessionFence` se cierra y verifica antes de borrar condicionalmente el envelope Keychain conforme a [ADR 0019](../adr/0019-single-jwt-session-and-keychain-v3.md), sin reutilizar la ausencia previa del bridge como evidencia;
- un fence cerrado y verificado hace no cancelable la transición Deluxe y obliga a completar el borrado Keychain y la redacción compartida;
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
- [ADR 0020: omitir la extracción de App Intents no utilizada](../adr/0020-skip-unused-app-intents-metadata-extraction.md)
- [ADR 0011: excepción acotada para el warning de App Intents, superseded](../adr/0011-bounded-xcode-app-intents-warning-exception.md)
- [Documentación y DocC](07-documentation-and-docc.md)
- [ADR 0017: flujos nativos y respuesta HTTP con status validado](../adr/0017-validated-http-status-response-boundary.md)
- [ADR 0018: bundle único de sesión en Keychain y logout atómico](../adr/0018-single-keychain-session-bundle-and-atomic-logout.md)
- [ADR 0019: JWT único de sesión y envelope Keychain V3](../adr/0019-single-jwt-session-and-keychain-v3.md)

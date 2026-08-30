# Autenticación y sincronización

- Estado: aprobado
- Versión: 1.8
- Última revisión: 2026-08-31

## Propósito y alcance

Definir la sesión de usuario y una sincronización local-first de la colección. La UI observa SwiftData; la API es autoridad remota solo cuando confirma una operación. Esta especificación no inventa endpoints, cabeceras, payloads ni campos: cada intercambio debe implementarse desde `/openapi/openapi.json`.

## Autenticación

### Alta de cuenta S2

El alta usa exclusivamente el contrato vivo `POST /users`: body JSON con
`email` y `password`, cabecera `App-Token`, status `200` e `Int64` de respuesta
interpretado solo como confirmación opaca. El `App-Token` procede de una
configuración local ignorada y queda encerrado en este request; no entra en la
configuración común de API, Catálogo, sesión, Keychain, ledger, logs o errores.
Si falta, está vacío o conserva un placeholder sin expandir, la capacidad falla
antes de transporte y el resto de la app, incluido Catálogo público, continúa
disponible.

| ID | Requisito |
| --- | --- |
| AUTH-006 | El alta se ofrece solo desde el estado sin sesión; `authenticationRequired` conserva su identidad estable y no permite crear otra cuenta. |
| AUTH-007 | La validación local normaliza un email no vacío y exige una contraseña de al menos ocho caracteres, sin inventar una gramática que OpenAPI no declara. |
| AUTH-008 | La contraseña permanece únicamente en el formulario y en la operación suspendida; se limpia al enviar o abandonar y nunca se persiste. |
| AUTH-009 | Una confirmación válida inicia exactamente una vez el login S1 existente; no crea otra autoridad de sesión ni otra ruta de persistencia. |
| AUTH-010 | Un fallo o cancelación después de confirmar el alta conserva «cuenta creada» y ofrece login manual sin repetir `POST /users`. |
| AUTH-011 | Timeout, cancelación o fallo después de invocar el transporte sin confirmación válida dejan un resultado incierto visible y nunca provocan reintento automático. |
| AUTH-012 | Cada workflow posee identidad propia. Abandonar un alta aún no confirmada invalida sus efectos de presentación; si ya comenzó el login S1, su cancelación reconcilia primero la autoridad de sesión para no ocultar un commit durable. Una respuesta tardía no sustituye una sesión posterior. |

La persona puede preparar conscientemente un alta nueva después de un resultado
incierto, pero la preparación no envía nada. La interfaz prioriza probar el
login porque el servidor no declara idempotency key, `409` ni un DTO de error.
Un status no declarado o un payload distinto del `Int64` esperado no expone el
body y conserva el resultado remoto como no confirmado.

### Sesión dual JWT

La sesión usa dos tokens con responsabilidades distintas:

| Token | Vigencia aceptada | Uso |
| --- | --- | --- |
| Access token | 1 hora | Autorizar operaciones de API. |
| Refresh token | 30 días | Obtener una nueva sesión de acceso según el contrato. |

Las duraciones se modelan con un reloj inyectable para que expiración y renovación sean verificables sin esperas reales.

### Almacenamiento seguro

| ID | Requisito |
| --- | --- |
| AUTH-001 | Access y refresh token se almacenan en Keychain. |
| AUTH-002 | La contraseña nunca se persiste, ni en SwiftData, preferencias, archivos, logs o Keychain. |
| AUTH-003 | Los tokens no aparecen en logs, errores presentados, fixtures versionados ni documentación pública. |
| AUTH-004 | El estado de sesión visible para UI no expone el valor bruto de ningún token. |
| AUTH-005 | Los datos locales y operaciones pendientes permanecen particionados por identidad de usuario. |

S1 materializa esta autoridad mediante el [ledger versionado de sesión y la
frontera Keychain](../adr/0016-versioned-session-ledger-and-keychain-boundary.md).
El ledger protegido persiste solo versión, UUID, generación opcional, revisión,
fase y destino de limpieza opcional; email y roles permanecen en memoria. Un
bundle Keychain sin un ledger activo de la misma generación nunca reactiva
sesión. La fase `authenticationRequired` conserva el scope UUID sin autorizar
tokens, mientras `invalidatedCleanupPending` obliga a completar la limpieza
después del punto de no retorno.

### Renovación

- Una petición que necesita autorización obtiene credenciales válidas desde el límite de sesión, no directamente desde una View.
- Las solicitudes concurrentes que detectan la misma expiración comparten una única renovación en curso.
- El resultado de refresh se acepta solo si todavía pertenece a la sesión que lo inició.
- Un fallo recuperable conserva una sesión bloqueada para red sin borrar ni mezclar la colección local.
- Una imposibilidad permanente de renovar requiere autenticación del usuario y coloca las operaciones afectadas en `blockedAuth`.

### Logout seguro en Advanced

Advanced cierra la sesión dentro de la app principal y no depende de capacidades
Deluxe que todavía no existen. El propietario serializado de sesión es la única
autoridad para activar generaciones y avanzar transiciones de logout. Logout
debe:

1. bloquear nuevas mutaciones y comprobar si existen operaciones pendientes;
2. permitir esperar su resolución o confirmar expresamente su descarte antes de continuar;
3. persistir una transición de logout en curso ligada a la generación de sesión esperada y a una revisión de transición;
4. impedir que otra generación se active hasta cancelar válidamente o completar esa transición;
5. invalidar durablemente la generación esperada solo si continúa siendo la propietaria de esa revisión;
6. impedir que nuevas peticiones usen sus tokens y hacer que refresh y envíos en curso revaliden la generación antes de aplicar efectos;
7. mantener cualquier colección y outbox conservadas bajo la identidad que las creó e impedir que una ruta privada resuelva datos de la generación invalidada;
8. eliminar access y refresh token de Keychain únicamente si todavía pertenecen a la generación esperada y completar cualquier limpieza local pendiente;
9. al completar el gate, invalidar la selección y rutas de Colección ligadas a esa identidad y generación.

Descartar operaciones pendientes elimina esas intenciones de forma atómica y restaura la colección al último estado confirmado antes de retirar la sesión. La confirmación debe explicar que los cambios locales no sincronizados se perderán.

Un fallo anterior a persistir la invalidación conserva la sesión y Keychain y
permite reintentar. Una vez persistida, la generación saliente nunca vuelve a
habilitarse. Si falla la limpieza de Keychain o el proceso termina, la app
permanece en un estado local bloqueado, completa la limpieza al recuperarse y no
usa esas credenciales. El estado privado de esa generación deja de resolverse
desde su invalidación; logout solo se presenta como completado y limpia sus rutas
cuando termina la limpieza local requerida.

En Advanced, cancelar solo es válido antes de persistir la invalidación local y
retira la transición revisionada sin alterar sesión, datos o navegación. La
invalidación es el punto de no retorno: después de ese commit, cualquier solicitud
de cancelación se rechaza y la recuperación completa Keychain, aislamiento y
rutas.

Cada reanudación y efecto destructivo transporta la generación y revisión
esperadas. Si el propietario ya no coincide, actúa como no-op y no borra
credenciales, rutas, datos u operaciones de una sesión posterior. La presencia de
tokens en Keychain no reconstruye por sí sola una sesión activa sin el estado
durable de la misma generación.

Una operación remota de revocación solo se usa si el OpenAPI vivo la define. La indisponibilidad de red no debe impedir el cierre local de sesión. Advanced no crea App Group, `SessionFence`, envelope, reload de WidgetKit, contexto de WatchConnectivity ni un sustituto no-op para ellos.

### Extensión Deluxe del logout

Cuando una unidad posterior incorpore el bridge Deluxe, el protocolo de
[ADR-0010](../adr/0010-widgetkit-event-driven-freshness.md) se intercala entre la
transición persistida y la invalidación local de Advanced:

1. persistir la transición de logout en curso;
2. cerrar y verificar atómicamente el `SessionFence` para la generación esperada —`allowedSessionGeneration == nil`—, sin alterar un fence que ya pertenezca a una sesión posterior;
3. abortar el logout y conservar sesión y Keychain si el fence no puede cerrarse o verificarse;
4. después del fence seguro, ejecutar la invalidación local, la limpieza de Keychain y el aislamiento definidos para Advanced;
5. publicar eventualmente un envelope redactado y solicitar el reload dirigido solo desde un estado compartido seguro;
6. reemplazar el contexto pendiente de watchOS por una redacción autocontenida mediante `WCSession.updateApplicationContext(_:)`, sin esperar su entrega.

En Deluxe, cerrar y verificar el fence adelanta el punto de no retorno. Antes de
ese commit puede cancelarse si la sesión local sigue activa; después, la
transición no es cancelable y la recuperación debe completar la invalidación local
y Keychain.

Logout no espera a que WidgetKit renderice otra timeline ni a que
WatchConnectivity entregue el contexto. El fence protege nuevas lecturas del
bridge canónico, mientras WidgetKit y watchOS pueden conservar una representación
ya cacheada; no se promete una retirada visual instantánea.

La app persiste intención suficiente para recuperar un crash entre fence,
invalidación local, Keychain y envelope. Un fence ya cerrado nunca vuelve a
permitir la sesión saliente: la recuperación completa el gate Advanced y
reintenta la redacción eventual. Una sesión nueva publica su envelope con el
fence cerrado y solo lo abre y verifica al final.

La [frontera Advanced/Deluxe](../adr/0013-advanced-logout-and-deluxe-bridge-boundary.md)
hace que esta extensión sea obligatoria cuando el bridge existe, pero no una
precondición para implementar o aceptar Advanced.

## Modelo local-first

| ID | Requisito |
| --- | --- |
| SYNC-001 | La intención válida se persiste primero en SwiftData y se refleja al observar el almacén local. |
| SYNC-002 | Toda intención sincronizable crea o actualiza de forma atómica su operación de outbox. |
| SYNC-003 | La UI no espera una respuesta de red para representar la intención local aceptada. |
| SYNC-004 | El servidor se convierte en autoridad para esa operación al emitir una confirmación válida. |
| SYNC-005 | La reconciliación de respuesta usa la misma ruta de mutación que protege las invariantes locales. |
| SYNC-006 | Un error permanente revierte la entrada a su último estado confirmado por el servidor. |
| SYNC-007 | Cuando exista el bridge Deluxe, una mutación, reconciliación, reversión, restauración, importación o redacción que cambie su proyección se publica únicamente después del commit local completado o de la transición de sesión persistida correspondiente. |

La última versión confirmada debe distinguirse del estado local optimista para hacer posible SYNC-006 sin fabricar valores.

## Publicación de proyecciones Deluxe

Esta sección entra en vigor al materializar el bridge Deluxe. Conserva el
contrato que la app principal deberá componer entonces, pero sus tipos,
entitlements y pruebas de integración no forman parte del Advanced Release Gate.

La publicación no constituye una segunda ruta de mutación ni una autoridad paralela. Después de que la ruta semántica de escritura haya completado el commit que observa la UI, la app deriva del estado local persistido un snapshot por valor y aplica este orden ordinario:

1. completar el commit local o persistir la transición de sesión;
2. construir la proyección de contenido desde ese resultado persistido;
3. delegar al publicador serializado la revisión, recursos, revalidación de la sesión esperada y reemplazo atómico del envelope;
4. solicitar `reloadTimelines(ofKind:)` con el `kind` concreto afectado, nunca una recarga global.

Este flujo ordinario se activa cuando el estado persistido por una mutación, reconciliación, reversión, restauración o importación cambia lo que el widget muestra. Un evento sin cambio visible o una operación que no alcanza su commit no publica. En una publicación ordinaria fallida, el estado local persistido mantiene su autoridad, el último snapshot de una sesión todavía válida queda intacto y no se solicita una recarga que anunciaría datos no escritos. La redacción de sesión sigue el protocolo fail-closed siguiente.

La invalidación de sesión es distinta: cierra y verifica primero el `SessionFence`, de modo que el provider ya no pueda aceptar el contenido anterior aunque el envelope siga intacto. Una sesión B prepara y publica su envelope mientras el fence permanece cerrado; solo después abre y verifica el fence para B y solicita el reload. La rotación de `publicationGeneration` sigue el mismo patrón con un fence nuevo cerrado y no requiere que el provider haya observado un bootstrap intermedio.

El publicador distingue comandos de contenido y de sanitización. Un comando de contenido conserva la generación de sesión esperada y la revalida antes de reemplazar el envelope o abrir el fence. Una sanitización dirigida a A procede si el bridge todavía permite A, es idempotente si ya está cerrado y se convierte en no-op si B ya posee el fence, para que una tarea tardía nunca cierre ni sustituya B. El término `confirmed` queda reservado al estado remoto de outbox; no describe este commit local. El contrato completo de fence, publicación, generaciones y recuperación se define en [Deluxe, watchOS y widget](05-deluxe-watch-and-widget.md).

## Identidad y orden de outbox

Cada operación de outbox pertenece a una pareja **usuario + manga** y dispone de:

- un UUID de operación estable durante sus reintentos;
- una secuencia monotónica dentro de esa pareja;
- la intención o estado deseado mínimo necesario para sincronizar;
- el estado de procesamiento;
- la información de reintento que no exponga secretos;
- una tombstone cuando la intención sea eliminar.

Estos son requisitos semánticos del modelo local. No presuponen que el servidor acepte esos valores como campos del payload.

Para una misma pareja usuario + manga:

- solo se envía una operación a la vez;
- una secuencia posterior no puede ser sobrescrita por la respuesta tardía de una anterior;
- los reintentos conservan el UUID;
- dos identidades de usuario nunca comparten operación ni secuencia.

## Coalescencia

Las mutaciones aún no confirmadas de una misma pareja se coalescen hacia la intención vigente siempre que ninguna confirmación intermedia sea necesaria para interpretar el resultado.

- La coalescencia conserva una secuencia superior a todas las intenciones reemplazadas.
- No cambia el UUID de una operación que ya está `sending`; crea o mantiene la siguiente intención ordenada.
- Una edición posterior a una tombstone puede cancelar la eliminación pendiente solo si todavía no fue confirmada y el resultado queda expresado como una intención válida.
- Nunca se coalescen operaciones de usuarios o mangas diferentes.

## Tombstones

Eliminar es una mutación local-first:

1. la entrada deja de aparecer en consultas activas;
2. persiste una tombstone en lugar de borrar toda evidencia necesaria;
3. la outbox envía la intención cuando haya sesión y red;
4. una confirmación permite retirar el estado local ya innecesario;
5. un rechazo permanente restaura el último estado confirmado.

Una tombstone debe sobrevivir al cierre de la app y a reinicios de proceso.

## Estados de una operación

Los únicos estados normativos de outbox son:

| Estado | Significado |
| --- | --- |
| `queued` | Persistida y preparada para un primer envío. |
| `sending` | Existe un intento activo para su UUID y secuencia. |
| `retry` | Un fallo transitorio permite un intento posterior. |
| `blockedAuth` | No puede enviarse hasta recuperar una sesión válida del mismo usuario. |
| `blockedOutcome` | El request pudo aplicarse, pero no existe evidencia concluyente; no se reintenta ni revierte automáticamente. |
| `rejected` | El servidor rechazó permanentemente la intención; debe ejecutarse la reversión. |
| `confirmed` | No queda divergencia local pendiente: el servidor aceptó la intención o la app restauró la última versión que el servidor ya había confirmado. |

### Transiciones permitidas

- `queued → sending`
- `sending → confirmed`
- `sending → retry → sending`
- `queued | sending | retry → blockedAuth`
- `blockedAuth → queued` al restaurar una sesión válida para el mismo usuario
- `sending → blockedOutcome` cuando se pierde una respuesta y repetir no está demostrado como seguro
- `blockedOutcome → confirmed` cuando una lectura concluyente demuestra el efecto deseado o la persona acepta el estado remoto reconciliado
- `blockedOutcome → queued` únicamente cuando la reconciliación demuestra que el efecto no se aplicó y el reintento es seguro
- `sending → rejected`
- `rejected → confirmed` únicamente después de restaurar localmente la última versión confirmada y registrar el rechazo como resuelto; no significa que el servidor aceptara la intención rechazada

Una cancelación por finalización de proceso no equivale a rechazo: tras recuperar consistencia, la operación vuelve a un estado procesable sin duplicar su identidad.

`blockedOutcome` es un bloqueo visible, no una cola oculta que reintenta indefinidamente. Si la lectura remota no permite concluir qué ocurrió, la interfaz ofrece conservar el estado remoto como nueva base o volver a emitir conscientemente la intención local. La segunda opción resuelve primero la operación ambigua contra la base remota y crea una intención nueva con su propia secuencia; nunca convierte la incertidumbre en `rejected`.

## Fallos y reintentos

- Solo los fallos clasificados como transitorios pasan a `retry`.
- El reintento aplica una espera acotada y cancelable; su política exacta se prueba con reloj controlado.
- Un fallo de autenticación pasa a `blockedAuth`, no consume indefinidamente reintentos de red.
- Un rechazo permanente pasa a `rejected` y revierte colección o tombstone al último estado confirmado.
- Perder la respuesta después de enviar pasa a `blockedOutcome` salvo que el contrato caracterizado garantice un reintento seguro.
- La reconciliación consulta primero el estado remoto: coincidencia con el estado deseado confirma sin repetir; ausencia concluyente del efecto permite reencolar; un resultado todavía ambiguo permanece bloqueado y visible.
- Si una respuesta no puede vincularse inequívocamente con usuario, manga, UUID y secuencia local, no modifica el estado confirmado.
- Ningún mensaje de error conserva tokens o contraseña.

## Arranque y reconciliación

Al iniciar una sesión válida:

1. la UI puede mostrar de inmediato la colección local del usuario;
2. el sistema recupera el estado remoto mediante operaciones verificadas en OpenAPI;
3. aplica confirmaciones remotas sin pisar ciegamente una secuencia local posterior;
4. reactiva operaciones `blockedAuth` del mismo usuario;
5. procesa la outbox ordenadamente.

El servidor es autoridad después de confirmar, pero una lectura remota no debe borrar sin análisis intenciones locales posteriores pendientes.

## Criterios de aceptación

| Gate | Caso | Resultado requerido |
| --- | --- | --- |
| Advanced | Alta confirmada | Ejecuta una sola vez el login S1 y termina en la sesión durable que este confirme. |
| Advanced | Configuración de alta ausente | Falla antes de transporte; Catálogo y el login existente continúan disponibles. |
| Advanced | Alta confirmada y login fallido o cancelado | Conserva «cuenta creada», no repite el alta y ofrece iniciar sesión. |
| Advanced | Respuesta de alta perdida o cancelada después del envío | Presenta resultado incierto y no reintenta automáticamente. |
| Advanced | Alta A tardía después de autenticar B | No inicia el login de A ni reemplaza el estado o la sesión de B. |
| Advanced | Login correcto | Los dos tokens quedan en Keychain; la contraseña no queda persistida. |
| Advanced | Access expirado y refresh vigente | Una sola renovación abastece peticiones concurrentes y actualiza la sesión aplicable. |
| Advanced | Refresh no válido | La sesión requiere autenticación y sus operaciones pasan a `blockedAuth`. |
| Advanced | Logout sin red | La invalidación local queda persistida, Keychain queda limpio y los datos siguen aislados por usuario, sin exigir un bridge Deluxe. |
| Advanced | Fallo antes de persistir la invalidación | Logout no completa, conserva sesión y Keychain y ofrece reintento. |
| Advanced | Fallo o crash después de persistir la invalidación | La sesión queda localmente bloqueada, sus rutas no resuelven datos privados, nunca reutiliza sus tokens y la recuperación completa Keychain y la limpieza pendiente. |
| Advanced | Activación de B durante el logout de A | El propietario no activa B hasta cancelar válidamente o completar la transición revisionada de A. |
| Advanced | Efecto tardío de A tras activar B | La comprobación de generación y revisión lo convierte en no-op; credenciales, rutas, datos y operaciones de B permanecen intactos. |
| Advanced | Logout con cambios pendientes | Exige esperar o confirmar el descarte; el descarte restaura el último estado confirmado y no deja outbox reproducible bajo otra sesión. |
| Advanced | Edición sin red | La UI cambia vía SwiftData y queda una operación persistida `queued` o `retry`. |
| Advanced | Reinicio de app | La intención pendiente conserva UUID, secuencia y posibilidad de envío. |
| Advanced | Varias ediciones del mismo manga | Se coalescen sin perder la intención más reciente ni permitir respuestas fuera de orden. |
| Advanced | Ediciones de mangas distintos | Mantienen identidades y secuencias independientes. |
| Advanced | Borrado sin red | La entrada se oculta y la tombstone persiste hasta resolverla. |
| Advanced | Error transitorio | La operación pasa por `retry` y no duplica efectos visibles. |
| Advanced | Efecto remoto aplicado y respuesta perdida | La reconciliación reconoce el estado deseado, pasa a `confirmed` y no repite el request. |
| Advanced | Resultado remoto inconcluso | Pasa a `blockedOutcome`, conserva ambos estados para resolver y no revierte ni reintenta automáticamente. |
| Advanced | Rechazo permanente | Se restaura la última versión confirmada y el rechazo queda resuelto de forma observable. |
| Advanced | Respuesta antigua | No sobrescribe una secuencia local posterior. |
| Advanced | Cambio de usuario | No muestra ni envía datos u operaciones del usuario anterior. |
| Advanced | Logout completado | La selección anterior de Colección ya no resuelve un detalle bajo la generación invalidada; sesión y Keychain respetan el gate local. |
| Advanced | Cancelación antes de la invalidación local | Retira la transición revisionada y conserva sesión, datos y navegación vigentes. |
| Advanced | Cancelación después de la invalidación local | Se rechaza; la transición no vuelve a activar la sesión y la recuperación completa limpieza y rutas. |
| Deluxe | Mutación local de lectura persistida | La UI observa el commit local completado y después se publica la nueva proyección; la recarga dirigida solo se solicita tras escribirla. |
| Deluxe | Reconciliación, reversión, restauración o importación visible | Publica el estado local resultante después de persistirlo, sin exponer una versión intermedia. |
| Deluxe | Evento sin cambio de proyección | No incrementa la revisión, no reemplaza el snapshot y no solicita reload. |
| Deluxe | Fallo de publicación ordinaria | Conserva el último snapshot válido de la misma sesión todavía vigente y no solicita la recarga del widget. |
| Deluxe | Fallo al cerrar o verificar el fence | Logout no completa, conserva sesión y Keychain y ofrece reintento sin publicar una falsa redacción. |
| Deluxe | Cancelación después de verificar el fence cerrado | Se rechaza; la recuperación completa la invalidación local Advanced y Keychain. |
| Deluxe | Crash entre fence, invalidación local, Keychain y envelope | La recuperación nunca vuelve a permitir A: completa el gate Advanced desde el fence cerrado y puede diferir el envelope redactado. |
| Deluxe | Primera incorporación con una sesión Advanced activa | El bridge empieza cerrado y solo abre tras autorización y revalidación explícitas de esa generación por su propietario. |
| Deluxe | Watch no alcanzable durante logout | `updateApplicationContext(_:)` reemplaza el contexto pendiente por la redacción; el reloj puede mostrar cache antigua de forma eventual sin alterar el cierre local. |
| Deluxe | Inicio de una sesión B | Su envelope se publica con el fence cerrado; el fence se abre para B al final y el reload se solicita después. |
| Deluxe | Sanitización tardía de A | Actúa si el bridge aún permite A y se convierte en no-op si el fence ya pertenece a B. |

Las transiciones, coalescencia, orden y expiración se prueban con Swift Testing. Keychain, SwiftData y recuperación determinista de ciclo de vida usan también Swift Testing con almacenes, adaptadores y procesos controlados. XCTest/XCUITest queda reservado a recorridos conducidos mediante automatización de interfaz; una excepción no UI requeriría una decisión separada.

## Limitación multi-dispositivo

La versión inicial no ofrece un algoritmo general de resolución de conflictos entre dispositivos. Dos dispositivos pueden editar la misma pareja usuario + manga sin conocer aún la intención pendiente del otro.

La política explícita es:

- cada dispositivo conserva orden solo para su propia outbox;
- una confirmación válida del servidor es la base remota autoritativa;
- una intención local posterior puede volver a sincronizarse sobre esa base;
- no se promete mezcla campo a campo, CRDT ni conservación automática de dos ediciones incompatibles;
- un conflicto no resoluble sin perder intención debe hacerse visible o conservarse bloqueado, no resolverse con datos inventados.

WatchOS y WidgetKit consumen proyecciones y no abren nuevos escritores autoritativos. El orden de snapshot y recarga de WidgetKit sigue [ADR-0010](../adr/0010-widgetkit-event-driven-freshness.md); cualquier mutación futura desde una superficie Deluxe requeriría otra decisión explícita.

## Fuera de alcance y riesgos

- No se persisten credenciales básicas ni se implementa un almacén de secretos propio.
- No se presupone un endpoint de revocación, idempotency key o resolución de conflictos que OpenAPI no declare.
- Una operación con UUID estable mejora la idempotencia local, pero no garantiza idempotencia del servidor si su contrato no la soporta.
- La recuperación después de un cierre durante `sending` debe reconciliar antes de repetir; si no puede demostrar el resultado, conserva `blockedOutcome` para resolución visible.

## Especificaciones y decisiones relacionadas

- [Alcance de producto](00-product-scope-and-levels.md)
- [Arquitectura y composición](01-architecture-and-composition.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [ADR-0003: concurrencia y aislamiento](../adr/0003-concurrency-and-default-isolation.md)
- [ADR-0004: SwiftData local-first y model actors](../adr/0004-swiftdata-local-first-and-model-actors.md)
- [ADR-0006: autenticación, Keychain y sincronización](../adr/0006-authentication-keychain-and-sync.md)
- [ADR-0015: flujos nativos, composición live y navegación adaptable](../adr/0015-native-flows-live-composition-and-adaptive-navigation.md)
- [ADR-0010: frescura dirigida por eventos para WidgetKit](../adr/0010-widgetkit-event-driven-freshness.md)
- [ADR-0013: frontera de logout Advanced y bridge Deluxe](../adr/0013-advanced-logout-and-deluxe-bridge-boundary.md)
- [ADR-0016: ledger versionado y frontera Keychain de sesión](../adr/0016-versioned-session-ledger-and-keychain-boundary.md)

# Autenticación y sincronización

- Estado: aprobado
- Versión: 1.18
- Última revisión: 2026-09-02

## Propósito y alcance

Definir la sesión de usuario y una sincronización local-first de la colección. La UI observa SwiftData; la API es autoridad remota solo cuando confirma una operación. Esta especificación no inventa endpoints, cabeceras, payloads ni campos: cada intercambio debe implementarse desde `/openapi/openapi.json`.

## Autenticación

### Alta de cuenta S2

El alta usa `POST /users` con body JSON `email/password` y cabecera `App-Token`.
El OpenAPI vivo declara únicamente status `200` con un `Int64` opaco, mientras
el enunciado aprobado y la ejecución real observada el 31 de agosto de 2026
devuelven `201 Created`. La app acepta exclusivamente ambas confirmaciones:
`200` exige decodificar el `Int64`; `201` confirma por el status y no depende de
un body cuya forma no está caracterizada. Ningún otro `2xx` se generaliza como
éxito.

El `App-Token` procede de una configuración local ignorada y queda encerrado en
este request; no entra en la configuración común de API, Catálogo, sesión,
Keychain, logs o errores. Si falta, está vacío o conserva un placeholder
sin expandir, la capacidad falla antes de transporte y el resto de la app,
incluido Catálogo público, continúa disponible.

| ID | Requisito |
| --- | --- |
| AUTH-006 | El alta se ofrece solo desde `signedOut`. `authenticationRequired` conserva la identidad estable únicamente en memoria durante el proceso actual y no permite crear otra cuenta; tras relanzar sin registro Keychain, la app parte de `signedOut`. |
| AUTH-007 | La validación local normaliza y comprueba el email con la gramática conservadora S2.2. El alta exige además una contraseña de al menos ocho caracteres; el login solo exige que la contraseña no esté vacía para no excluir cuentas existentes con una política local no declarada por el servidor. |
| AUTH-008 | La contraseña permanece únicamente en el formulario y en la operación suspendida. El estado oculto usa `SecureField` y el visible `TextField`, ambos de SwiftUI, con el mismo `Binding` y `textContentType`; el cambio conserva el contenido y el foco modelado sin introducir un puente UIKit. Se limpia al enviar o abandonar y nunca se persiste. La continuidad de una sesión AutoFill real requiere validación manual y no se infiere de previews o tests sintéticos. |
| AUTH-009 | Una confirmación válida inicia exactamente una vez el login S1 existente; no crea otra autoridad de sesión ni otra ruta de persistencia. |
| AUTH-010 | Un fallo o cancelación después de confirmar el alta conserva «cuenta creada» y ofrece login manual sin repetir `POST /users`. |
| AUTH-011 | Timeout, cancelación o fallo después de invocar el transporte sin confirmación válida dejan un resultado incierto visible y nunca provocan reintento automático. |
| AUTH-012 | Cada workflow posee identidad propia. Abandonar un alta aún no confirmada invalida sus efectos de presentación; si ya comenzó el login S1, su cancelación reconcilia primero la autoridad de sesión para no ocultar un commit durable. Una respuesta tardía no sustituye una sesión posterior. |
| AUTH-013 | Cada presencia en pantalla de login o alta crea su modelo de formulario `@Observable @MainActor`, retenido por la View con `@State`; `AccountRoute` continúa siendo solo un valor de navegación. Cada modelo conserva borradores, campos visitados, visibilidad de contraseña, intención semántica de foco, tarea y limpieza de credenciales. La View conserva únicamente el adaptador `@FocusState` y bindings SwiftUI; `AccountModel` permanece como única autoridad compartida del estado de sesión y del workflow remoto. |
| AUTH-014 | La incertidumbre remota se explica una sola vez dentro del formulario de alta, sin mostrar status ni detalles técnicos. Volver muestra el landing inicial de Cuenta sin borrar el resultado; al entrar de nuevo en Crear cuenta reaparece la protección y solo una acción explícita prepara otro intento. |

#### Gramática local de credenciales S2.2

Antes de iniciar login o alta, el email se recorta en sus extremos y debe
coincidir por completo con una gramática local deliberadamente conservadora:

- una parte local ASCII formada por uno o más segmentos separados por un único
  punto; cada segmento admite letras, dígitos y los caracteres
  `!#$%&'*+/=?^_{|}~-`;
- una única `@`;
- un dominio con al menos dos etiquetas ASCII separadas por puntos; cada
  etiqueta contiene entre 1 y 63 letras, dígitos o guiones, empieza y termina
  con una letra o un dígito y nunca queda vacía;
- ningún espacio, salto de línea, punto inicial o final ni dos puntos
  consecutivos.

La implementación materializa esta forma mediante Swift Regex y exige una
coincidencia completa. Es una comprobación de entrada, no una implementación
exhaustiva de todos los formatos admitidos por los estándares ni evidencia de
que la dirección exista, pueda recibir correo o pertenezca a una cuenta. El
servidor conserva la autoridad sobre aceptación, unicidad y credenciales. Un
fallo local se presenta debajo del campo correspondiente después de abandonarlo
o intentar enviar; credenciales incorrectas, red, configuración y contrato no se
atribuyen a un campo y permanecen como error general del formulario.

La persona puede preparar conscientemente un alta nueva después de un resultado
incierto, pero la preparación no envía nada. La interfaz prioriza probar el
login porque el servidor no declara idempotency key, `409` ni un DTO de error.
Un status distinto de `200` o `201`, o un payload `200` distinto del `Int64`
esperado, no expone el body y conserva el resultado remoto como no confirmado.

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

S1 materializa esta autoridad mediante el [bundle único de sesión en Keychain](../adr/0018-single-keychain-session-bundle-and-atomic-logout.md).
Un único registro V2 conserva `sessionGeneration`, UUID de usuario,
access y refresh token con sus expiraciones. El email, roles y demás datos
descriptivos permanecen en memoria y vuelven a obtenerse mediante `/me` cuando
la red lo permite. El registro es la única autoridad durable: no existe ledger,
fase ni revisión paralela en Application Support.

Login completa refresh → access → `/me`, reemplaza el registro Keychain y solo
después publica la sesión. Al relanzar, un registro íntegro restaura generación e
identidad mínima; su ausencia significa `signedOut`. Una versión desconocida o
un payload corrupto fallan cerrados y se intentan retirar sin interpretar campos
parciales. Si el dispositivo bloqueado hace que el registro
`WhenUnlockedThisDeviceOnly` esté temporalmente inaccesible, la restauración se
difiere sin escribir ni borrar.

Si la restauración necesita renovar un access expirado, esa renovación valida
`/me` antes de reemplazar el envelope y publica directamente la identidad ya
comprobada. La restauración no repite un segundo `/me` sobre la misma credencial.

`authenticationRequired` no se persiste. Un refresh rechazado permanentemente
deja de autorizar esos tokens, bloquea las operaciones del usuario mediante
`blockedAuth` e intenta borrar el registro. Mientras el proceso continúa, Cuenta
conserva el UUID en memoria aunque el borrado falle y nunca vuelve a entregar el
access rechazado; el fallo de Keychain permanece visible para poder reintentar la
limpieza. Un relanzamiento sin registro comienza en `signedOut` y el mismo scope
se recupera cuando un login posterior confirme de nuevo ese UUID. Si el proceso
termina con el envelope residual todavía presente, un arranque offline no puede
distinguirlo durablemente sin reintroducir un tombstone; la revalidación remota
vuelve a exigir autenticación.

### Renovación

- Una petición que necesita autorización obtiene credenciales válidas desde el límite de sesión, no directamente desde una View.
- Las solicitudes concurrentes que detectan la misma expiración comparten una única renovación en curso.
- El resultado de refresh se acepta solo si todavía pertenece a la sesión que lo inició y `/me` confirma la misma identidad antes de persistirlo o publicarlo.
- Un fallo recuperable conserva una sesión bloqueada para red sin borrar ni mezclar la colección local.
- Una imposibilidad permanente de renovar requiere autenticación del usuario y coloca las operaciones afectadas en `blockedAuth`.

### Logout seguro en Advanced

Advanced cierra la sesión dentro de la app principal y no depende de capacidades
Deluxe que todavía no existen. El propietario serializado de sesión es la única
autoridad para activar una generación, renovar sus credenciales y eliminar su
registro. Logout debe:

1. bloquear nuevas mutaciones y comprobar si existen operaciones pendientes;
2. permitir esperar su resolución o confirmar expresamente su descarte antes de continuar;
3. bloquear temporalmente nuevas autorizaciones e impedir que otra generación se active mientras el borrado de la actual esté en curso;
4. revalidar que el único registro continúe perteneciendo a la generación esperada;
5. eliminar ese registro Keychain como único commit durable del logout;
6. solo tras confirmar la eliminación, publicar `signedOut` e invalidar selección y rutas privadas de esa identidad;
7. hacer que refresh, requests y envíos suspendidos revaliden la generación antes de aplicar efectos;
8. mantener colección y outbox conservadas bajo la identidad que las creó y no enviarlas bajo otra sesión.

Descartar operaciones pendientes elimina esas intenciones de forma atómica y restaura la colección al último estado confirmado antes de retirar la sesión. La confirmación debe explicar que los cambios locales no sincronizados se perderán.

La eliminación del registro es a la vez invalidación y limpieza; Advanced no
persiste `logoutPrepared`, `invalidatedCleanupPending`, revisión ni otra fase. Si
el borrado falla o el proceso termina antes de confirmarlo, logout no completa y
el envelope todavía presente puede restaurar la sesión; un fallo devuelve además
la sesión en memoria a su estado activo para poder reintentar. Si el registro ya
no existe, la restauración permanece en `signedOut`. Una cancelación solo puede
aceptarse antes de iniciar el borrado; después no existe una transición durable
que cancelar o recuperar.

Cada efecto transporta la generación esperada. Si el propietario o el envelope
ya no coinciden, actúa como no-op y no borra credenciales, rutas, datos u
operaciones de una sesión posterior. La presencia de un envelope íntegro sí es
la autoridad durable para reconstruir la sesión Advanced de esa generación.

Una operación remota de revocación solo se usa si el OpenAPI vivo la define. La indisponibilidad de red no debe impedir el cierre local de sesión. Advanced no crea App Group, `SessionFence`, envelope compartido Deluxe, reload de WidgetKit, contexto de WatchConnectivity ni un sustituto no-op para ellos.

### Extensión Deluxe del logout

Cuando una unidad posterior incorpore el bridge Deluxe, el protocolo de
[ADR-0010](../adr/0010-widgetkit-event-driven-freshness.md) se intercala antes
del borrado Keychain de Advanced:

1. cierra y verifica atómicamente el `SessionFence` para la generación esperada —`allowedSessionGeneration == nil`—, sin alterar un fence que ya pertenezca a una sesión posterior;
2. aborta el logout y conserva sesión y Keychain si el fence no puede cerrarse o verificarse;
3. después del fence seguro, elimina el registro Keychain esperado y completa el aislamiento Advanced;
4. publica eventualmente un envelope redactado y solicita el reload dirigido solo desde un estado compartido seguro;
5. reemplaza el contexto pendiente de watchOS por una redacción autocontenida mediante `WCSession.updateApplicationContext(_:)`, sin esperar su entrega.

En Deluxe, cerrar y verificar el fence adelanta el punto de no retorno. Antes de
ese commit puede cancelarse si la sesión local sigue activa; después, el fence
cerrado es el único punto durable de no retorno y la recuperación completa el
borrado Keychain aunque el proceso termine. No se reintroduce un ledger privado
de sesión en Advanced.

Logout no espera a que WidgetKit renderice otra timeline ni a que
WatchConnectivity entregue el contexto. El fence protege nuevas lecturas del
bridge canónico, mientras WidgetKit y watchOS pueden conservar una representación
ya cacheada; no se promete una retirada visual instantánea.

Un fence ya cerrado nunca vuelve a permitir la sesión saliente. Si el bundle de
esa generación todavía existe, la recuperación lo elimina condicionalmente y
reintenta la redacción eventual; si ya no existe, permanece en `signedOut`. Una
sesión nueva publica su envelope con el fence cerrado y solo lo abre y verifica
al final.

La [frontera vigente](../adr/0018-single-keychain-session-bundle-and-atomic-logout.md)
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

## Lectura e importación remota R1

R1 incorpora únicamente la lectura autenticada `GET /collection/manga` y la
importación de su resultado en el `ModelContainer` V2 existente. La petición usa
el access vigente como Bearer, no lleva body, query ni `App-Token` y solo acepta
el status exacto `200`. El array recibido representa un snapshot remoto completo,
no una página, delta o confirmación de envíos locales.

El DTO de entrada reutiliza el wire contract compartido de `MangaDTO`, acepta
`readingVolume` ausente o `null` y valida antes de persistir la identidad UUID de
la entrada, la identidad del manga, los enums cerrados y el resto del payload.
Dos entradas con el mismo UUID remoto o con el mismo manga invalidan el lote. R1
no persiste ni interpreta el UUID de la entrada como el parámetro `{id}` de las
operaciones individuales: la identidad local de reconciliación continúa siendo
**usuario + manga**.

## Identidad de las operaciones individuales de Colección

La decisión del propietario del 2 de septiembre de 2026 resuelve la discrepancia
descriptiva de OpenAPI: `{id}` en `GET /collection/manga/{id}` y
`DELETE /collection/manga/{id}` representa `Manga.ID`, el mismo `Int64` que
publican `MangaDTO.id` y `UserMangaCollectionRequest.manga`. La frontera de
dominio permanece numérica y el transporte la serializa como sus dígitos
decimales en el path porque el parámetro publicado tiene schema `string`.

El UUID `id` incluido en una entrada remota identifica esa representación, pero
no sustituye la identidad del manga, no se persiste para construir el path y no
se envía en `POST` o `DELETE`. La decisión elimina la ambigüedad de producto; la
aceptación efectiva de los dos paths por el backend real sigue pendiente de una
prueba funcional controlada y no se infiere del OpenAPI.

## Envío POST de outbox R2.1

El primer corte de R2 reutiliza el GET completo de R1 e incorpora únicamente
`POST /collection/manga` para intenciones no tombstone. Cada request usa el
Bearer ligado a su generación y envía exactamente `manga`, `volumesOwned`,
`readingVolume` y `completeCollection`; un progreso ausente se expresa como
`null`. Solo `200` con un `Int64` válido confirma el transporte. Ese entero es
opaco: no sustituye el UUID de operación local ni se interpreta como identidad
de manga o de entrada.

El arranque autenticado importa primero el snapshot R1 y entrega a la composición
solo su `SessionAuthority` y sus entradas por valor, nunca el access. El worker
R2 solicita una autorización vigente y exige que usuario y generación coincidan
antes de usar esa evidencia; una cancelación observada después del commit de
importación impide que R1 exponga el snapshot al siguiente efecto. Después
reclama por valor la menor secuencia
procesable de cada pareja. Antes del claim comprueba la generación y la gate
exacta se consume dentro de la misma transacción `queued → sending`; esa
transacción es la última validación antes de invocar el POST. Si la autorización
ya no es válida, no reclama ni cambia el estado. Después de exponer `sending`,
cualquier interrupción se considera potencialmente posterior al envío y exige
reconciliación. La confirmación consume de nuevo la gate de commit y una respuesta
de N actualiza solo la base confirmada; si ya existe N+1, su estado optimista
continúa visible. Las mutaciones posteriores vuelven a activar la misma capacidad
a partir de la outbox observada en SwiftData.

Una operación `sending` recuperada después de cancelar o relanzar nunca repite el
POST. En el arranque compuesto, el único GET completo de R1 constituye también
la evidencia de reconciliación R2 y no se realiza una segunda lectura. La
coincidencia de manga, volúmenes, progreso y estado completo confirma el efecto;
una ausencia o diferencia conserva la intención como `blockedOutcome`. Si R1 no
puede obtener o importar un snapshot utilizable por un fallo ordinario, una ruta
cercada a la autoridad exacta bloquea únicamente operaciones ya `sending`, sin
reclamar `queued` ni realizar GET o POST. Cancelación y `sessionChanged` conservan
`sending` y propagan su categoría sin mutar otra generación; una clasificación
R1 tardía que ya fue cancelada tampoco cancela el vuelo R2 vigente. La decisión
de reemplazo usa la autoridad de sesión vigente, no la antigüedad del vuelo: un
snapshot o fallo A tardío se rechaza antes de tocar B, mientras un trigger B
validado cancela y reconcilia cualquier vuelo A anterior. Un fallo
observado después de invocar un POST sí exige un GET completo nuevo porque la
evidencia R1 es anterior a esa escritura. Transporte, status no publicado o body
inválido no provocan un segundo POST automático; tampoco se borra la sesión ni
se piden de nuevo credenciales válidas.

Este corte no procesa tombstones ni materializa todavía GET individual, DELETE,
retry/backoff, `blockedAuth`, rechazo/reversión o resolución manual del conflicto.
Un `blockedOutcome` se muestra como aviso seguro de Colección mientras la sesión
permanece activa. El aviso se deriva de la outbox persistida para esa identidad y
no desaparece porque el GET R1 anterior falle o porque se relance el proceso; los
avisos efímeros de autorización pueden prevalecer mientras estén activos. Su
resolución interactiva sigue siendo trabajo posterior de R2.

La raíz estable inicia la capacidad al restaurar o confirmar una sesión
autenticada, sin depender de visitar la tab Colección. La UI puede seguir
mostrando inmediatamente SwiftData mediante `@Query`. Una autorización interna
de sesión obtiene access y generación sin exponerlos a SwiftUI; el coordinador
actor mantiene la red fuera del model actor, propaga cancelación, reemplaza una
ejecución anterior y revalida la misma generación inmediatamente antes de
importar. Abandonar la identidad cancela su ejecución. Una respuesta tardía,
reemplazada o perteneciente a A después de activar B no aplica efectos.

La revalidación previa es solo un rechazo rápido. La garantía de commit usa una
gate de proceso ligada a la autoridad exacta: invalidación de sesión y
transacción SwiftData adquieren el mismo `Mutex`, y la autorización se mantiene
durante toda la sección síncrona sin `await`. Si la invalidación gana, la
transacción no comienza; si el commit gana, logout o invalidación esperan y se
linealizan después. Esta gate no persiste estado, no cruza procesos y no es el
`SessionFence` durable reservado a Deluxe.

La respuesta de autenticación o autorización se clasifica contra la generación y
el access exactos de la request. Un rechazo tardío de un token sustituido o de la
generación A se convierte en `sessionChanged` y no afecta al access renovado ni a
la sesión B.

Un primer `401` vigente fuerza una renovación single-flight aunque el access aún
no haya vencido. La renovación queda ligada a la generación y al access rechazado,
revalida con `/users/session/me` que el access nuevo representa la misma identidad
y permite un único segundo `GET /collection/manga`. Solo un rechazo permanente del
refresh conduce a `authenticationRequired` y retira el envelope conforme a
ADR-0018. Si `/me` no acepta el access recién emitido, o Colección devuelve otro
`401` después de que `/me` lo acepte, se clasifica una incompatibilidad del backend:
la sesión, Keychain, colección y outbox permanecen intactos y no existe un tercer
intento. Toda renovación, incluida la iniciada por expiración ordinaria, valida esa
identidad antes de persistir o publicar el access nuevo; por ello una recuperación
R1 que comparte un refresh ya en curso nunca puede observar una credencial todavía
no validada. Un vuelo residual solo se comparte si todavía sustituye la generación
y el access vigentes; al activar una sesión posterior se ignora, y su resultado
tardío queda cercado como `sessionChanged` sin bloquear la autorización nueva.

Un `403` vigente, incluido el segundo intento, representa autorización insuficiente
para Colección; no demuestra que access o refresh sean inválidos. Conserva sesión,
Keychain, colección y outbox, y no inicia refresh ni otro retry. Cuenta mantiene su
estado autenticado y muestra un aviso seguro distinto para permiso denegado o
incompatibilidad de autenticación del endpoint. El diagnóstico de Colección conserva
únicamente el origen constante, el status y el intento; el rechazo permanente del
refresh registra `origin=refreshExchange`, status y acción. Ninguno conserva URL
completa, cabeceras, tokens, body, email o UUID. Esta recuperación es protocolaria y
acotada al GET seguro: R1 no incorpora backoff, repetición general ni una acción
manual de retry.

La importación usa la misma instancia de `CollectionMutationActor` y una única
transacción SwiftData para el snapshot completo. Primero valida y canonicaliza
todo el lote; solo después modifica el contexto y ejecuta un único commit. Un
UUID o manga duplicado, un payload inválido, cancelación observada o fallo de
persistencia aborta el lote entero y conserva colección y outbox previas. R1 no
crea, coalesce, reactiva, envía ni cambia el estado de ninguna operación de
outbox.

Para cada pareja usuario + manga, una outbox en cualquier estado distinto de
`confirmed` representa una intención local pendiente. La reconciliación aplica
estas reglas:

- si la entrada remota está presente y no existe intención pendiente, el estado
  local, la base confirmada y el snapshot de presentación adoptan la versión
  remota;
- si está presente y existe intención pendiente, solo se actualizan la base
  confirmada y los datos remotos de presentación; el estado local optimista, su
  tombstone y la outbox permanecen intactos;
- si está ausente y no existe intención pendiente, se retira la entrada local
  cuya existencia remota anterior estaba confirmada;
- si está ausente y existe intención pendiente, se conserva el estado local y
  la outbox y se registra la ausencia como nueva base confirmada;
- una entrada local huérfana, sin base confirmada ni outbox, no se borra por
  inferencia: invalida la importación y hace fallar cerrado el lote.

Los volúmenes en propiedad se deduplican y ordenan de forma canónica. Cualquier
volumen propio o de lectura no positivo, un valor superior al total conocido o
`completeCollection == true` sin un total válido invalida el lote; la ruta aplica
además las invariantes completas de la SDD 03 y nunca descarta valores para
fabricar un estado aceptable. Red, autenticación, deriva de contrato, cancelación
o persistencia fallida no borran el estado local ni convierten la red en fuente
de UI. Salvo la recuperación protocolaria única de un `401` y el aviso mínimo que
evita pedir credenciales válidas, R1 no añade retry automático, presentación de
progreso ni resolución visible de conflictos.

## Arranque y reconciliación Advanced

Al iniciar una sesión válida:

1. la UI puede mostrar de inmediato la colección local del usuario;
2. R1 recupera el snapshot remoto completo mediante la operación verificada en OpenAPI;
3. R1 lo importa atómicamente sin pisar una intención local posterior;
4. solo R2 reactiva operaciones `blockedAuth` del mismo usuario;
5. solo R2 procesa la outbox ordenadamente y materializa sus transiciones.

El servidor es autoridad después de confirmar, pero una lectura remota no debe borrar sin análisis intenciones locales posteriores pendientes.

## Criterios de aceptación

| Gate | Caso | Resultado requerido |
| --- | --- | --- |
| Advanced | Alta confirmada | Ejecuta una sola vez el login S1 y termina en la sesión durable que este confirme. |
| Advanced | Configuración de alta ausente | Falla antes de transporte; Catálogo y el login existente continúan disponibles. |
| Advanced | Alta confirmada y login fallido o cancelado | Conserva «cuenta creada», no repite el alta y ofrece iniciar sesión. |
| Advanced | Respuesta de alta perdida o cancelada después del envío | Presenta resultado incierto y no reintenta automáticamente. |
| Advanced | Alta A tardía después de autenticar B | No inicia el login de A ni reemplaza el estado o la sesión de B. |
| Advanced | Login correcto | Un único envelope Keychain V2 conserva generación, UUID, ambos tokens y expiraciones; la contraseña no queda persistida. |
| Advanced | Access expirado y refresh vigente | Una sola renovación abastece peticiones concurrentes y actualiza la sesión aplicable. |
| Advanced | Refresh no válido | El registro deja de autorizar, se intenta eliminar, la sesión requiere autenticación solo en memoria y sus operaciones pasan a `blockedAuth`; tras relanzar sin registro parte de `signedOut`. |
| Advanced | Logout sin red | El envelope Keychain esperado queda eliminado y los datos siguen aislados por usuario, sin exigir un bridge Deluxe. |
| Advanced | Fallo al borrar Keychain | Logout no completa, conserva la sesión autorizable y ofrece reintento. |
| Advanced | Crash durante logout | Si el registro permanece, restaura la sesión; si ya fue eliminado, restaura `signedOut`. No existe limpieza intermedia. |
| Advanced | Activación de B durante el logout de A | El propietario no activa B hasta que el borrado de A termina con éxito o error. |
| Advanced | Efecto tardío de A tras activar B | La comprobación de generación lo convierte en no-op; credenciales, rutas, datos y operaciones de B permanecen intactos. |
| Advanced | Logout con cambios pendientes | Exige esperar o confirmar el descarte; el descarte restaura el último estado confirmado y no deja outbox reproducible bajo otra sesión. |
| Advanced | Edición sin red | La UI cambia vía SwiftData y queda una operación persistida `queued` o `retry`. |
| Advanced | Reinicio de app | La intención pendiente conserva UUID, secuencia y posibilidad de envío. |
| Advanced | Varias ediciones del mismo manga | Se coalescen sin perder la intención más reciente ni permitir respuestas fuera de orden. |
| Advanced | Ediciones de mangas distintos | Mantienen identidades y secuencias independientes. |
| Advanced | Borrado sin red | La entrada se oculta y la tombstone persiste hasta resolverla. |
| Advanced | Snapshot R1 presente sin intención pendiente | Estado local, base confirmada y presentación adoptan la versión remota mediante un único commit. |
| Advanced | Snapshot R1 presente con intención pendiente | Conserva estado local, tombstone y outbox; actualiza únicamente la base confirmada y la presentación remota. |
| Advanced | Snapshot R1 ausente | Retira solo una entrada confirmada sin intención pendiente; conserva una intención pendiente con ausencia confirmada y falla cerrado ante un huérfano sin base ni outbox. |
| Advanced | Lote R1 inválido, cancelado o no persistible | No aplica ninguna parte y conserva colección y outbox previas. |
| Advanced | Respuesta R1 de una generación anterior | No modifica la colección ni la outbox de la sesión vigente. |
| Advanced | Primer `401` R1 de la request vigente | Fuerza una única renovación single-flight, revalida la identidad y repite una sola vez el GET seguro. |
| Advanced | Refresh rechazado permanentemente durante la recuperación R1 | Retira el envelope exacto y proyecta `authenticationRequired`; no ejecuta el segundo GET. |
| Advanced | Segundo `401` R1 con access renovado aceptado por `/me` | Conserva sesión, Keychain, colección y outbox, no realiza un tercer intento y presenta incompatibilidad del endpoint. |
| Advanced | `403` R1 de una request vigente | Conserva sesión, Keychain, colección y outbox, no renueva ni repite y presenta autorización insuficiente de Colección. |
| Advanced | Rechazo R1 tardío tras refresh o sesión B | Se convierte en `sessionChanged`, no invalida el access renovado ni la sesión posterior y no modifica SwiftData. |
| Advanced | Vuelo de refresh A residual después de activar B | La autorización y una recuperación `401` de B ignoran el vuelo no coincidente; A termina como `sessionChanged` y no modifica ni bloquea B. |
| Advanced | Error transitorio | La operación pasa por `retry` y no duplica efectos visibles. |
| Advanced | Efecto remoto aplicado y respuesta perdida | La reconciliación reconoce el estado deseado, pasa a `confirmed` y no repite el request. |
| Advanced | Resultado remoto inconcluso | Pasa a `blockedOutcome`, conserva ambos estados para resolver y no revierte ni reintenta automáticamente. |
| Advanced | Rechazo permanente | Se restaura la última versión confirmada y el rechazo queda resuelto de forma observable. |
| Advanced | Respuesta antigua | No sobrescribe una secuencia local posterior. |
| Advanced | Cambio de usuario | No muestra ni envía datos u operaciones del usuario anterior. |
| Advanced | Logout completado | El registro ya no existe y la selección anterior de Colección no resuelve un detalle bajo la generación eliminada. |
| Advanced | Cancelación antes del borrado | Conserva envelope, sesión, datos y navegación vigentes. |
| Advanced | Cancelación después del borrado | No existe transición que cancelar: logout ya completó y la app permanece en `signedOut`. |
| Deluxe | Mutación local de lectura persistida | La UI observa el commit local completado y después se publica la nueva proyección; la recarga dirigida solo se solicita tras escribirla. |
| Deluxe | Reconciliación, reversión, restauración o importación visible | Publica el estado local resultante después de persistirlo, sin exponer una versión intermedia. |
| Deluxe | Evento sin cambio de proyección | No incrementa la revisión, no reemplaza el snapshot y no solicita reload. |
| Deluxe | Fallo de publicación ordinaria | Conserva el último snapshot válido de la misma sesión todavía vigente y no solicita la recarga del widget. |
| Deluxe | Fallo al cerrar o verificar el fence | Logout no completa, conserva sesión y Keychain y ofrece reintento sin publicar una falsa redacción. |
| Deluxe | Cancelación después de verificar el fence cerrado | Se rechaza; el fence como punto durable de no retorno obliga a completar el borrado Keychain. |
| Deluxe | Crash entre fence, Keychain y envelope | La recuperación nunca vuelve a permitir A: elimina su registro desde el fence cerrado y puede diferir el envelope redactado. |
| Deluxe | Primera incorporación con una sesión Advanced activa | El bridge empieza cerrado y solo abre tras autorización y revalidación explícitas de esa generación por su propietario. |
| Deluxe | Watch no alcanzable durante logout | `updateApplicationContext(_:)` reemplaza el contexto pendiente por la redacción; el reloj puede mostrar cache antigua de forma eventual sin alterar el cierre local. |
| Deluxe | Inicio de una sesión B | Su envelope se publica con el fence cerrado; el fence se abre para B al final y el reload se solicita después. |
| Deluxe | Sanitización tardía de A | Actúa si el bridge aún permite A y se convierte en no-op si el fence ya pertenece a B. |

Las transiciones, coalescencia, orden y expiración se prueban con Swift Testing. Keychain, SwiftData y los límites binarios de restauración usan también Swift Testing con almacenes, adaptadores y procesos controlados. XCTest/XCUITest queda reservado a recorridos conducidos mediante automatización de interfaz; una excepción no UI requeriría una decisión separada.

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
- R2.1 no implementa `DELETE`, `GET /collection/manga/{id}`, retry/backoff
  general, reactivación `blockedAuth`, rechazo/reversión, acción manual de retry
  ni resolución interactiva de conflictos; esas capacidades permanecen en R2 y
  en el cierre posterior de Advanced.

## Especificaciones y decisiones relacionadas

- [Alcance de producto](00-product-scope-and-levels.md)
- [Arquitectura y composición](01-architecture-and-composition.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [ADR-0003: concurrencia y aislamiento](../adr/0003-concurrency-and-default-isolation.md)
- [ADR-0004: SwiftData local-first y model actors](../adr/0004-swiftdata-local-first-and-model-actors.md)
- [ADR-0006: autenticación, Keychain y sincronización](../adr/0006-authentication-keychain-and-sync.md)
- [ADR-0017: flujos nativos y respuesta HTTP con status validado](../adr/0017-validated-http-status-response-boundary.md)
- [ADR-0010: frescura dirigida por eventos para WidgetKit](../adr/0010-widgetkit-event-driven-freshness.md)
- [ADR-0018: bundle único de sesión en Keychain y logout atómico](../adr/0018-single-keychain-session-bundle-and-atomic-logout.md)

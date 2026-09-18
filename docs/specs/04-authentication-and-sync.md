# Autenticación y sincronización

- Estado: aprobado
- Versión: 1.28
- Última revisión: 2026-09-18

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

### Sesión JWT única

La sesión usa un único JWT Bearer para identidad, renovación y operaciones
protegidas. `POST /users/jwt/login` y `POST /users/jwt/refresh` devuelven el
mismo DTO `token/tokenType/expiresIn`; la ejecución live observada entrega una
vigencia de 24 horas, pero el cliente deriva cada expiración del `expiresIn`
validado y no fija esa duración como contrato.

El JWT actual solo puede renovarse mientras continúa válido. La app inicia la
renovación cuando le quedan cinco minutos o menos y nunca envía un JWT ya
expirado. Duración, ventana y bordes se modelan con un reloj inyectable para que
sean verificables sin esperas reales.

### Almacenamiento seguro

| ID | Requisito |
| --- | --- |
| AUTH-001 | El JWT único de sesión se almacena en Keychain. |
| AUTH-002 | La contraseña nunca se persiste, ni en SwiftData, preferencias, archivos, logs o Keychain. |
| AUTH-003 | Los tokens no aparecen en logs, errores presentados, fixtures versionados ni documentación pública. |
| AUTH-004 | El estado de sesión visible para UI no expone el valor bruto de ningún token. |
| AUTH-005 | Los datos locales y operaciones pendientes permanecen particionados por identidad de usuario. |

S1 materializa esta autoridad mediante el [JWT único y envelope Keychain V3](../adr/0019-single-jwt-session-and-keychain-v3.md).
Un único registro V3 conserva `sessionGeneration`, UUID de usuario, JWT y su
expiración. El email, roles y demás datos
descriptivos permanecen en memoria y vuelven a obtenerse mediante `/me` cuando
la red lo permite. El registro es la única autoridad durable: no existe ledger,
fase ni revisión paralela en Application Support. El actor sí mantiene una
revisión opaca de credencial exclusivamente en memoria; rota tras cada
activación o refresh validado, incluso cuando el texto del JWT se repite, y no se
deriva de claims ni se serializa.

Login completa `/users/jwt/login` → `/users/jwt/me` con el mismo JWT, reemplaza
el registro Keychain y solo después publica la sesión. Si el JWT expira mientras
se valida la identidad, no se persiste ni se publica; si ya expiró justo después
de recibirlo, ni siquiera se envía a `/jwt/me`. Si expira durante la
escritura Keychain, se retira condicionalmente el envelope exacto antes de
publicar; un fallo de esa limpieza deja `authenticationRequired` en memoria para
que el login siguiente pueda sustituir el registro residual, sin autorizarlo. Al
relanzar, un registro
V3 íntegro restaura generación e identidad mínima; su ausencia significa
`signedOut`. Un envelope V1/V2, una versión desconocida o un payload corrupto
fallan cerrados y se intentan retirar sin interpretar o reutilizar tokens
parciales. Si el dispositivo bloqueado hace que el registro
`WhenUnlockedThisDeviceOnly` esté temporalmente inaccesible, la restauración se
difiere sin escribir ni borrar.

Si la restauración encuentra un JWT todavía válido dentro de la ventana
preventiva, lo renueva y valida `/users/jwt/me` antes de reemplazar el envelope;
publica directamente la identidad ya comprobada y no repite un segundo `/me`
sobre la misma credencial. Un JWT ya expirado no se envía a refresh.

`authenticationRequired` no se persiste. Un JWT expirado o un refresh rechazado
permanentemente deja de autorizar esa credencial, bloquea las operaciones del usuario mediante
`blockedAuth` e intenta borrar el registro. Mientras el proceso continúa, Cuenta
conserva el UUID en memoria aunque el borrado falle y nunca vuelve a entregar el
JWT rechazado; el fallo de Keychain permanece visible para poder reintentar la
limpieza. Un relanzamiento sin registro comienza en `signedOut` y el mismo scope
se recupera cuando un login posterior confirme de nuevo ese UUID. Si el proceso
termina con el envelope residual todavía presente, un arranque offline no puede
distinguirlo durablemente sin reintroducir un tombstone; la revalidación remota
vuelve a exigir autenticación.

### Renovación

- Una petición obtiene el JWT válido desde el límite de sesión, no directamente desde una View.
- Cinco minutos antes de expirar, las solicitudes concurrentes comparten una única renovación en curso mediante `POST /users/jwt/refresh`.
- El vuelo queda ligado a UUID, generación y JWT exacto. Su resultado solo se acepta si todavía pertenece a esa autoridad y `/users/jwt/me` confirma la misma identidad antes de persistirlo o publicarlo.
- Cada reemplazo validado rota una revisión opaca en memoria. Las capacidades de request y commit transportan autoridad y revisión; una capacidad anterior queda inválida aunque el refresh repita exactamente el mismo JWT y expiración.
- Un fallo recuperable conserva el envelope y la colección local solo si el JWT continúa válido al terminar el vuelo; si expira durante la renovación, exige autenticación. La operación no continúa con una credencial que decidió renovar.
- Un JWT expirado nunca se envía. Un rechazo permanente de refresh requiere autenticación del usuario y coloca las operaciones afectadas en `blockedAuth`.
- Un JWT recién emitido que `/users/jwt/me` no acepta o vincula a otro UUID nunca sustituye el envelope anterior.
- Un JWT que expire mientras `/users/jwt/me` valida su identidad tampoco sustituye el envelope anterior ni se publica.
- Un JWT que expire durante el reemplazo Keychain se retira y no se publica. Un fallo de escritura conserva el envelope anterior solo mientras su JWT continúe válido; si ya expiró, pasa a `authenticationRequired`.
- Después de cualquier suspensión usada para obtener o renovar la credencial, el actor revalida autoridad, envelope completo, revisión opaca, rechazo, gate y expiración y emite la autorización Bearer en ese mismo turno, sin otro `await` entre comprobación y construcción.
- Si una recuperación A→B se reanuda cuando ya existe un refresh B→C, debe unirse al vuelo B→C antes de devolver; B nunca se emite como credencial intermedia ni se autoriza mientras está siendo reemplazada.
- Tras esperar una respuesta protegida, la sesión vuelve a validar la expiración antes de admitir efectos. Un JWT que haya vencido durante el transporte pasa a `authenticationRequired` y no permite importar ni confirmar el resultado.
- Una mutación local obtiene su capacidad de commit desde la misma sesión. La gate conserva también la expiración vigente y la comprueba dentro del mutex de la transacción: tanto si el JWT ya venció como si vence después de emitir la capacidad y antes del commit, no modifica SwiftData ni outbox, vuelve a Sesión para converger y la presentación de Cuenta reconcilia inmediatamente `authenticationRequired`.
- El editor local captura UUID y generación al abrirse y los incluye en cada comando. La presentación, Sesión y `CollectionMutationActor` comparan esa autoridad completa; una generación B del mismo UUID no puede aceptar una sheet o comando de A. Una rotación de revisión dentro de la misma generación permite resolver una capacidad actual y repetir una sola vez antes de iniciar el commit.
- Mientras el refresh espera el reemplazo durable del envelope, logout e invalidación se rechazan con `transitionInProgress`; se reintentan cuando ese commit confirma éxito o error. No pueden publicar otro estado en memoria que diverja del JWT que Keychain termina adoptando.
- Logout e invalidación suspenden la gate durante el borrado sin descartar todavía la revisión necesaria para clasificar respuestas en vuelo. Si el borrado falla y el JWT sigue vigente, la reactivación rota la revisión; un rechazo recibido durante la transición fuerza refresh antes de reutilizarlo.
- Un fallo al retirar de Keychain un JWT vencido conserva `authenticationRequired` fail-closed y su categoría segura en Cuenta. Un logout cuyo borrado cruza la expiración tampoco reactiva la sesión aunque el envelope residual siga presente.
- Cancelar un waiter no transforma un fallo normal en reautenticación, pero tampoco puede ocultar un fallo seguro de carga, guardado, reemplazo o limpieza Keychain ya confirmado por el vuelo compartido. Cuenta conserva `temporarilyUnavailable` o `persistenceUnavailable` solo para la autoridad exacta y descarta cualquier causa tardía tras una generación distinta del mismo UUID. Si el snapshot exacto sigue activo porque el JWT anterior aún es válido, presenta la causa como aviso no bloqueante sin pedir credenciales ni degradar la autenticación.

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

Cualquier operación en `queued`, `sending`, `retry`, `blockedAuth`,
`blockedOutcome` o `rejected` cuenta como pendiente; un cursor `confirmed` no.
El primer intento suspende los commits ordinarios y consulta la outbox mediante
una capacidad `SessionLogoutAuthorization` ligada a usuario, generación y
revisión exactos. Si encuentra trabajo pendiente, aborta la transición, rota la
revisión al reactivar la sesión y presenta la decisión; no conserva esa
capacidad mientras el aviso está abierto. Esperar equivale a permanecer con la
sesión iniciada, conserva navegación, Keychain, Colección y outbox y permite que
el worker R2 continúe con el trabajo automatizable; cualquier estado que exija
una decisión permanece disponible para revisión.

Confirmar el descarte inicia otro intento, vuelve a suspender y consultar bajo
una capacidad nueva y restaura todas las parejas afectadas en una única
transacción SwiftData. Una entrada vuelve a `confirmedState` o se elimina si la
base confirmada es ausencia. Por pareja se retiene únicamente la operación de
secuencia máxima como cursor `confirmed`, con retry y deadline eliminados, y se
retiran las demás; así no queda trabajo reproducible y una mutación posterior
continúa en `max + 1`. Esta transición directa de cualquier estado no
`confirmed` a `confirmed` es exclusiva del descarte explícito de logout y no
afirma que el servidor aceptara la intención. La confirmación explica que los
cambios pendientes de este dispositivo volverán a su última base confirmada y
que esto no revierte un efecto que ya pudiera existir en la nube; una lectura R1
posterior puede volver a importarlo.

Un fallo o cancelación antes del commit de descarte revierte la transacción
completa y no inicia el borrado Keychain. Si el JWT continúa vigente, reactiva
la sesión; si vence durante el intento, conserva el envelope sin volver a
autorizarlo y publica `authenticationRequired`. Una vez confirmado el descarte
local, esos cambios no se resucitan: si el borrado Keychain falla, la sesión
vuelve a estar activa para poder reintentar solo mientras el JWT siga vigente,
pero Colección conserva las bases restauradas y los cursores resueltos.

Un fallo de SwiftData al comprobar o descartar pendientes se clasifica de forma
separada de un fallo de Keychain. Cuenta informa de que no ha podido comprobarse
o completarse la decisión de Colección y de que no se retiró ningún cambio
local; el estado de autenticación se deriva por separado del snapshot vigente.
No atribuye el problema al almacenamiento seguro de credenciales.

La eliminación del registro es a la vez invalidación y limpieza; Advanced no
persiste `logoutPrepared`, `invalidatedCleanupPending`, revisión ni otra fase. Si
el borrado falla o el proceso termina antes de confirmarlo, logout no completa y
el envelope todavía presente puede restaurar la sesión; un fallo devuelve además
la sesión en memoria a su estado activo para poder reintentar. Si el registro ya
no existe, la restauración permanece en `signedOut`. Una cancelación solo puede
aceptarse antes del primer commit irreversible: el descarte SwiftData cuando se
ha confirmado esa decisión o el borrado Keychain cuando no había pendientes.
Después no existe una fase durable de logout que cancelar o recuperar.

Cada efecto transporta la generación esperada. Si el propietario o el envelope
ya no coinciden, actúa como no-op y no borra credenciales, rutas, datos u
operaciones de una sesión posterior. La presencia de un envelope íntegro sí es
la autoridad durable para reconstruir la sesión Advanced de esa generación.

Una operación remota de revocación solo se usa si el OpenAPI vivo la define. La indisponibilidad de red no debe impedir el cierre local de sesión. Advanced no crea App Group, `SessionFence`, envelope compartido Deluxe, reload de WidgetKit, contexto de WatchConnectivity ni un sustituto no-op para ellos.

### Extensión Deluxe del logout

Con el bridge Deluxe implementado, el protocolo de
[SDD 09](09-deluxe-reading-contract.md), ADR 0019 y
[ADR-0022](../adr/0022-widget-collection-projection-and-adaptive-reading.md)
se intercala antes del borrado Keychain de Advanced:

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

La [frontera vigente](../adr/0019-single-jwt-session-and-keychain-v3.md)
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
- Una operación `retry` acredita que el intento anterior no se envió. Una edición
  o eliminación posterior puede coalescerla con el mismo UUID, una secuencia
  superior y estado `queued`, retirando contador y deadline ya obsoletos.
- No cambia el UUID de una operación que ya está `sending`; crea o mantiene la siguiente intención ordenada.
- Si el fallo positivamente pre-envío de N se conoce cuando N+1 ya está
  `queued`, N se retira en vez de programar un payload que ya no representa la
  intención vigente.
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
- `sending → retry → sending` únicamente cuando una frontera caracterizada
  demuestra positivamente que el transporte no inició el envío
- `queued | retry → blockedAuth` cuando la autoridad se pierde antes de que exista
  una escritura de resultado incierto
- `blockedAuth → queued` al restaurar una sesión válida para el mismo usuario
- `sending → blockedOutcome` cuando se pierde una respuesta y repetir no está demostrado como seguro
- `blockedOutcome → confirmed` cuando una lectura individual fresca demuestra el efecto deseado, la persona acepta el estado remoto observado o confirma conscientemente una nueva intención local
- `sending → rejected`
- `rejected → confirmed` únicamente después de restaurar localmente la última versión confirmada y registrar el rechazo como resuelto; no significa que el servidor aceptara la intención rechazada
- `queued | sending | retry | blockedAuth | blockedOutcome | rejected → confirmed`
  únicamente durante el descarte explícito de logout, después de restaurar o
  retirar la entrada en la misma transacción y reteniendo solo el cursor de
  secuencia máxima; tampoco significa que el servidor aceptara la intención

Una cancelación por finalización de proceso no equivale a rechazo: tras recuperar consistencia, la operación vuelve a un estado procesable sin duplicar su identidad.

`blockedOutcome` es un bloqueo visible, no una cola oculta que reintenta
indefinidamente. R2.4 permite revisar la última versión remota observada y
escoger conscientemente entre conservarla o volver a emitir la intención local.
La segunda opción resuelve primero la operación ambigua como `confirmed` contra
la base remota y, cuando aún existe divergencia y no hay una intención posterior,
crea una intención `queued` nueva con UUID y secuencia propios; nunca reencola la
operación incierta ni la convierte en `rejected`.

## Fallos y reintentos

- Solo los fallos clasificados como transitorios pasan a `retry`.
- El reintento aplica una espera acotada y cancelable; su política exacta se prueba con reloj controlado.
- Una pérdida de autenticación confirmada bloquea `queued` y `retry`; una
  `sending` potencialmente aplicada reconcilia y no consume indefinidamente
  reintentos de red.
- Un rechazo permanente pasa a `rejected` y revierte colección o tombstone al último estado confirmado.
- Perder la respuesta después de enviar pasa a `blockedOutcome` salvo que el contrato caracterizado garantice un reintento seguro.
- La reconciliación consulta primero el estado remoto: coincidencia con el estado deseado confirma sin repetir; cualquier divergencia conserva `blockedOutcome` hasta la decisión consciente de R2.4 y nunca reencola automáticamente la operación incierta.
- Si una respuesta no puede vincularse inequívocamente con usuario, manga, UUID y secuencia local, no modifica el estado confirmado.
- Ningún mensaje de error conserva tokens o contraseña.

## Lectura e importación remota R1

R1 incorpora únicamente la lectura autenticada `GET /collection/manga` y la
importación de su resultado en el `ModelContainer` V2 existente. La petición usa
el JWT de sesión vigente como Bearer, no lleva body, query ni `App-Token` y solo acepta
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

Antes de la transición `queued → sending`, R2 valida que el estado deseado de
una intención no tombstone cumpla la cota inclusiva `1...300` de SDD 03. Un total,
tomo propio o volumen de lectura histórico fuera de esa cota produce un error
local tipado: la operación no se reclama, no se construye ni envía un POST, no se
modifica otra secuencia y sesión y Keychain permanecen intactos.

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
una cancelación o una interrupción sin evidencia del transporte se considera
potencialmente posterior al envío y exige reconciliación; solo una prueba
inequívoca de que el transporte no inició el envío permite el retry R2.3. La
confirmación consume de nuevo la gate de commit y una respuesta
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
evidencia R1 es anterior a esa escritura. Un status no publicado, un body
inválido o un fallo de transporte que no demuestre que el envío nunca comenzó no
provocan un segundo POST automático; tampoco se borra la sesión ni se piden de
nuevo credenciales válidas.

R2.1 no procesa tombstones ni materializa todavía GET individual, DELETE,
retry/backoff, `blockedAuth`, rechazo/reversión o resolución manual del conflicto.
Un `blockedOutcome` se muestra como aviso seguro de Colección mientras la sesión
permanece activa. El aviso se deriva de la outbox persistida para esa identidad y
no desaparece porque el GET R1 anterior falle o porque se relance el proceso; los
avisos efímeros de autorización se presentan de forma independiente y no pueden
ocultar la acción de revisión. Su resolución interactiva se define en R2.4.

## GET/DELETE individual y tombstones R2.2

R2.2 amplía el mismo worker y la misma ruta persistente, sin crear otra cola ni
otra autoridad. La menor secuencia procesable puede representar un upsert o una
tombstone: ambas se reclaman mediante la misma transición atómica
`queued → sending` y conservan las cercas de usuario, manga, UUID, secuencia,
generación y autorización de commit ya definidas por R2.1.

Una tombstone nueva ejecuta exactamente un
`DELETE /collection/manga/{mangaID}` con el `Manga.ID` decimal como segmento,
Bearer JWT y sin body, query, `App-Token` ni UUID remoto. Solo `200` con un
`Int64` válido confirma directamente el transporte; el entero continúa siendo
opaco. Una respuesta directa distinta, un body inválido o un fallo de transporte
sin prueba inequívoca de que el envío nunca comenzó se consideran resultado
potencialmente posterior al envío y no provocan un segundo DELETE automático.

Como excepción estrecha, una tombstone creada mediante eliminación explícita
puede reclamarse y enviarse aunque conserve como base un estado histórico
incompatible con la cota. El DELETE solo transporta la identidad del manga: nunca
serializa su total, propiedad o lectura. Esta excepción no hace válido ese estado,
no permite editarlo ni convertirlo en POST. Una presencia incompatible obtenida
por GET nunca se adopta como base; para una tombstone exacta basta, no obstante,
para demostrar que el borrado sigue sin confirmarse.

Una operación `confirmed` es únicamente un cursor monotónico y no vuelve a ser
payload. Sus valores históricos se conservan, pero quedan fuera de la validación
volumétrica previa al claim y a R1; sus identidades, secuencia, tipo de operación y
relación usuario + manga continúan validándose. Un cursor confirmado incompatible
no puede bloquear la importación ni una tombstone posterior, y nunca se convierte
de nuevo en POST.

Un POST histórico incompatible recuperado en `sending` sigue siendo una escritura
de resultado remoto incierto. Si la persona elimina explícitamente ese manga, la
mutación retira N de forma atómica después de calcular la siguiente secuencia y
crea la tombstone N+1; no lo marca `confirmed` ni intenta reconciliar o repetir su
payload inválido. R1 puede actualizar una base remota compatible y R2 reclama el
DELETE, que domina si el POST antiguo llegó a aplicarse y si no lo hizo. Cuando
el snapshot conserva la fila incompatible, R1 permite exclusivamente que
progrese la primera tombstone `queued` o `sending` de esa misma pareja: retiene
la entrada remota bruta como presencia opaca para R2, no importa sus valores y no
confirma ausencia. Una tombstone `queued` envía DELETE; una `sending` no lo repite
y queda en `blockedOutcome` al observar la presencia.

R2.3 amplía esa excepción a una cadena formada íntegramente por operaciones
acreditadas como no enviadas (`blockedAuth`, `queued` o `retry`): R1 puede usar
como presencia opaca la última cuando sea la tombstone que coincide con la
entrada. Sus predecesoras son seguras para superseder y la recuperación las
retira atómicamente antes del claim. Una operación anterior `sending`,
`blockedOutcome` o `rejected` continúa cercando la tombstone y no habilita la
excepción.

Cuando el DELETE ya ha retornado ese `200` válido, cualquier fallo posterior de
revalidación o persistencia es local: conserva su categoría, no se reclasifica
como resultado remoto incierto, no ejecuta GET individual y no bloquea la
operación como `blockedOutcome` por esa causa. La resolución exacta puede
reanudarse desde su cursor persistido sin volver a borrar en red.

La reconciliación posterior a un DELETE incierto usa como máximo una vez
`GET /collection/manga/{mangaID}`. Un `200` debe decodificar una única entrada
cuyo `manga.id` coincida exactamente con el segmento solicitado: demuestra que
el efecto deseado no está confirmado. Si sus valores son válidos, la misma
transacción los adopta como base remota y datos de presentación; si son
incompatibles con la cota, los conserva opacos y no modifica esa base. En ambos
casos mantiene intacta la intención local visible y deja la operación en
`blockedOutcome`, sin reintento automático.
El `404` descrito por OpenAPI como «manga no presente en la colección» es la única
ausencia concluyente y confirma la tombstone. Esta interpretación queda limitada
al GET individual exacto: no se generaliza al DELETE ni a otros endpoints. Un
payload o identidad inválidos no avanzan la base confirmada. Cualquier otro
status, fallo o cancelación conserva la clasificación segura correspondiente; un
resultado ordinario no borra sesión, Keychain ni estado local.

Una tombstone `sending` recuperada después de un relanzamiento reutiliza primero
el snapshot completo R1 ya importado, igual que un upsert recuperado: ausencia
del manga confirma y presencia bloquea, con cero DELETE repetidos y cero GET
adicionales. Cuando un trigger autónomo no procede de R1 y carece de snapshot,
su reconciliación dirigida usa el GET individual. Si R1 acaba de fallar o no ha
podido importar su snapshot, se conserva la ruta específica vigente: bloquear
la operación recuperada sin realizar otra petición. El endpoint individual no
alimenta una segunda fuente de UI, no sustituye el snapshot completo R1 y no se
llama como preflight de un DELETE confirmado.

La aceptación live debe demostrar sin registrar secretos que el path decimal
identifica el manga y que eliminar termina en ausencia remota observable. Puede
hacerlo mediante la secuencia directa GET presente `200` → DELETE `200` → GET
ausente `404`, o mediante una prueba multidispositivo equivalente: un dispositivo
elimina una entrada conocida, otro reconcilia el borrado concurrente mediante el
`404` del endpoint individual y una sesión fresca observa la ausencia en el
snapshot remoto. Esta segunda ruta acredita la semántica de producto y del path,
pero no permite afirmar el status ni el body exactos de la primera respuesta
DELETE si se perdieron en transporte; esa caracterización continúa como deuda
de contrato y no bloquea por sí sola R2.2.

Al confirmar la eliminación, la transacción marca la operación exacta como
`confirmed` y registra ausencia remota. Si no existe una intención posterior,
retira la entrada tombstone ya innecesaria; conserva la operación confirmada como
cursor monotónico para que una futura reactivación continúe la secuencia. Si N+1
ya posee el estado visible, no lo borra: solo avanza la base confirmada de N a
ausencia y mantiene N+1 pendiente.

La raíz estable inicia la capacidad al restaurar o confirmar una sesión
autenticada, sin depender de visitar la tab Colección. La UI puede seguir
mostrando inmediatamente SwiftData mediante `@Query`. Una autorización interna
de sesión obtiene JWT y generación sin exponerlos a SwiftUI; el coordinador
actor mantiene la red fuera del model actor, propaga cancelación, reemplaza una
ejecución anterior y revalida la misma generación inmediatamente antes de
importar. Abandonar la identidad cancela su ejecución. Una respuesta tardía,
reemplazada o perteneciente a A después de activar B no aplica efectos.
El trigger del shell y la reconciliación de Cuenta se identifican por la
`SessionAuthority` completa, no solo por UUID; una causa segura de limpieza solo
puede enriquecer el estado correspondiente a esa misma autoridad.

La revalidación previa es solo un rechazo rápido. La garantía de commit usa una
gate de proceso ligada a la autoridad exacta: invalidación de sesión y
transacción SwiftData adquieren el mismo `Mutex`, y la autorización se mantiene
durante toda la sección síncrona sin `await`. Si la invalidación gana, la
transacción no comienza; si el commit gana, logout o invalidación esperan y se
linealizan después. Esta gate no persiste estado, no cruza procesos y no es el
`SessionFence` durable reservado a Deluxe.

La respuesta de autenticación o autorización se clasifica contra la generación y
el JWT exactos de la request. Un rechazo tardío de un token sustituido o de la
generación A se convierte en `sessionChanged` y no afecta al JWT renovado ni a
la sesión B. Una respuesta `200` tampoco autoriza por sí sola la importación: al
volver del transporte se revalida que el JWT exacto continúe vigente y que su
gate siga autorizando la generación. Si vence entre esa comprobación y el commit
SwiftData, la propia gate aborta la importación y el coordinador vuelve a Sesión
para converger antes de presentar el resultado. R2 aplica la misma regla a cada
frontera de store: un `sessionChanged` de la gate obliga a revalidar la request
exacta. Si la causa es expiración, Sesión invalida el envelope y transforma el
trabajo `queued` o `retry` en `blockedAuth`; si fue sustitución de JWT o
generación, la revalidación es un no-op sobre la autoridad nueva.

Un primer `401` vigente fuerza una renovación single-flight aunque el JWT todavía
esté fuera de la ventana preventiva. La renovación queda ligada a la generación y
al JWT rechazado, revalida con `/users/jwt/me` que el JWT nuevo representa la misma
identidad y permite un único segundo `GET /collection/manga`. Solo un rechazo
permanente de `/users/jwt/refresh` conduce a `authenticationRequired` y retira el
envelope conforme a ADR-0019. Si `/users/jwt/me` no acepta el JWT recién emitido,
o Colección devuelve otro
`401` después de que `/me` lo acepte, se clasifica una incompatibilidad del backend:
la sesión, Keychain, colección y outbox permanecen intactos y no existe un tercer
intento. Toda renovación, incluida la iniciada por expiración ordinaria, valida esa
identidad antes de persistir o publicar el JWT nuevo; por ello una recuperación
R1 que comparte un refresh ya en curso nunca puede observar una credencial todavía
no validada. Un vuelo residual solo se comparte si todavía sustituye la generación
y el JWT vigentes; al activar una sesión posterior se ignora, y su resultado
tardío queda cercado como `sessionChanged` sin bloquear la autorización nueva.
Si la renovación preventiva necesaria para obtener la autorización inicial
produce un JWT rechazado por `/users/jwt/me`, el coordinador lo clasifica como
incompatibilidad de identidad renovada sin ejecutar el GET ni ocultar la causa.

Un `403` vigente, incluido el segundo intento, representa autorización insuficiente
para Colección; no demuestra que el JWT de sesión sea inválido. Conserva sesión,
Keychain, colección y outbox, y no inicia refresh ni otro retry. Cuenta mantiene su
estado autenticado y muestra un aviso seguro distinto para permiso denegado o
incompatibilidad de autenticación del endpoint. El diagnóstico de Colección conserva
únicamente el origen constante, el status y el intento; el rechazo permanente del
refresh registra `origin=jwtRefresh`, status y acción. Ninguno conserva URL
completa, cabeceras, tokens, body, email o UUID. Esta recuperación es protocolaria y
acotada al GET seguro: R1 no incorpora backoff, repetición general ni una acción
manual de retry.

La importación usa la misma instancia de `CollectionMutationActor` y una única
transacción SwiftData para el snapshot completo. Primero clasifica y valida todo
el lote, incluida cualquier presencia opaca contextual; solo después modifica el
contexto y ejecuta un único commit. Un UUID o manga duplicado, un payload inválido
fuera de esa excepción, cancelación observada o fallo de persistencia aborta el
lote entero y conserva colección y outbox previas. R1 no crea, coalesce, reactiva,
envía ni cambia el estado de ninguna operación de outbox.

La validación incluye la cota global de SDD 03 y ocurre antes de materializar
cualquier rango: un total conocido, tomo poseído o lectura fuera de `1...300`,
incluidos `301` e `Int64.max`, invalida el snapshot completo. La única excepción
es una fila que coincide con la primera tombstone local procesable de esa pareja
o, durante la recuperación R2.3, con la última de una secuencia formada
exclusivamente por operaciones `blockedAuth`, `queued` o `retry`: R1 conserva su
presencia opaca para R2, pero no la materializa, no la interpreta como ausencia
y continúa validando identidad y duplicados del lote. El rechazo
ordinario conserva Colección, outbox, sesión y Keychain y se presenta como
incompatibilidad segura de datos de Colección, nunca como fallo de autenticación
ni como motivo para retry. El GET individual de reconciliación exige identidad
exacta y solo adopta como base una presencia que supere la validación volumétrica.

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
volumen propio o de lectura fuera de `1...300`, un valor superior al total
conocido, un total conocido fuera de `1...300` o `completeCollection == true` sin
un total válido invalida el lote; `nil` continúa significando total desconocido y
no elimina la cota de los números individuales. La ruta aplica además las
invariantes completas de la SDD 03 y nunca descarta valores para fabricar un
estado aceptable. Red, autenticación, deriva de contrato, cancelación o
persistencia fallida no borran el estado local ni convierten la red en fuente de
UI. Salvo la recuperación protocolaria única de un `401` y el aviso mínimo que
evita pedir credenciales válidas, R1 no añade retry automático, presentación de
progreso ni resolución visible de conflictos.

## Recuperación automática de outbox R2.3

R2.3 materializa las transiciones automáticas `retry`, `blockedAuth` y
`rejected` sin alterar la política conservadora de resultados inciertos de
R2.1/R2.2. La clasificación se decide antes de mutar SwiftData y es cerrada:

- `retry` solo se admite si una frontera caracterizada clasifica positivamente
  el fallo como anterior al inicio del envío;
- perder una respuesta, recibir un timeout, perder una conexión después de
  invocar el transporte, obtener una respuesta no HTTP, un payload inválido o
  cualquier status no caracterizado no demuestra ausencia del efecto. Esos
  resultados conservan la reconciliación de R2.2 y terminan en
  `blockedOutcome` si la lectura tampoco permite concluir;
- ningún status HTTP se convierte por conveniencia en retry o rechazo
  permanente. El OpenAPI vigente solo publica `200` para las escrituras de
  Colección y no tipa sus errores;
- la composición live vigente no posee una señal fiable de fase pre-envío y,
  por tanto, clasifica todos los errores reales de `URLSession` como resultado
  potencialmente aplicado. El backoff queda materializado para una frontera
  futura caracterizada, pero no se activa por status, body o error de transporte
  inferidos;
- `rejected` exige una clasificación positiva inyectada en la frontera del
  coordinador o incorporada posteriormente por un contrato remoto ya
  caracterizado. La implementación live vigente no inventa esa clasificación a
  partir de un status o body desconocidos.

### Espera persistida y cancelable

Al programar `sending → retry`, la misma transacción incrementa de forma segura
`retryCount` y persiste `nextRetryAt` usando un reloj inyectable. El primer retry
espera un segundo; los siguientes esperan 2, 4, 8 y 16 segundos, y el sexto y
todos los posteriores esperan como máximo 30 segundos. El contador nunca hace
wrap y la confirmación o resolución definitiva retira el deadline.

El backoff pertenece a la intención exacta, no a la pareja para siempre. Una
edición o eliminación local durante la espera reemplaza ese payload seguro no
enviado, conserva su UUID, avanza la secuencia y vuelve a `queued` con contador
y deadline limpios. Si N todavía figuraba `sending` cuando se creó N+1, pero la
frontera acredita después que N no llegó a enviarse, la misma transacción retira
N y deja progresar N+1; nunca espera para repetir primero el estado obsoleto.
Una vez que la frontera ha acreditado positivamente que el intento no comenzó,
persistir N como `retry` o retirarla ante N+1 es un punto de no retorno local:
la cancelación del vuelo no puede borrar esa evidencia. Al terminar ese commit,
la cancelación vuelve a propagarse antes de reclamar o emitir otra request.
La observabilidad registra `backoff` o `superseded` únicamente después de ese
commit y refleja cuál de las dos resoluciones ocurrió realmente.

El worker procesa primero cualquier pareja accionable sin quedar bloqueado por
el deadline futuro de otra. Si solo queda trabajo `retry`, espera hasta el
deadline más temprano mediante una suspensión estructurada y cancelable. Una
operación ya vencida se procesa inmediatamente al relanzar o reactivar el
coordinador. Tras despertar vuelve a comprobar usuario, generación, UUID,
secuencia, estado y autorización de commit antes de ejecutar
`retry → sending`; una intención posterior u otra sesión convierten el efecto
tardío en no-op. Cancelar o sustituir el vuelo conserva el retry y su fecha
durables y no emite otra request.

### Bloqueo y recuperación de autenticación

Cuando el propietario de sesión confirma que una autoridad dejó de ser válida,
R2 puede convertir atómicamente las operaciones `queued` y `retry` de ese
usuario en `blockedAuth`. Una operación `sending` cuyo resultado pueda haberse
aplicado no pierde esa identidad ni se reencola: permanece preparada para la
reconciliación conservadora ya definida. Ningún fallo ordinario de red o de
Colección se presenta como pérdida de autenticación.

Después de que R1 importe una sesión válida, R2 reactiva `blockedAuth → queued`
solo para el mismo UUID de usuario y bajo una autorización de commit vigente.
Para cada pareja compara toda intención segura no enviada (`blockedAuth`,
`queued` o `retry`) y conserva únicamente la de mayor secuencia, con su UUID e
intención vigente; las anteriores quedan supersedidas dentro de la misma
transacción. La retenida pasa de `blockedAuth` a `queued`; si una edición más
reciente ya estaba `queued`, o ya existía un `retry` más reciente, conserva su
semántica propia. Así nunca reaparece una cola bloqueada obsoleta por delante de
la intención actual. Una sesión de otro usuario, una generación sustituida o
una autorización ya vencida no modifica ni envía esas operaciones.

### Rechazo y reversión

Una clasificación positiva de rechazo permanente ejecuta semánticamente
`sending → rejected → confirmed` dentro de una única transacción SwiftData. No
existe un intervalo persistido donde Colección y outbox discrepen:

- si la operación rechazada todavía posee el estado visible, se restaura su
  última base confirmada;
- si esa base es ausencia, se retira la entrada local activa o la tombstone;
- rechazar una tombstone restaura la entrada confirmada cuando existía;
- si ya existe N+1, su intención optimista mantiene precedencia visual y N solo
  conserva la base confirmada anterior;
- la operación rechazada termina como cursor `confirmed`, con el retry resuelto,
  sin afirmar que el servidor aceptara su payload.

Un fallo de persistencia, cancelación o cerca inválida revierte juntas la
restauración y la transición de outbox. `blockedOutcome` nunca entra en esta
ruta, y sesión y Keychain permanecen intactos salvo que el propietario de sesión
haya confirmado de forma independiente una pérdida real de autoridad.

## Resolución interactiva de resultados inciertos R2.4

R2.4 convierte el aviso durable de `blockedOutcome` en un flujo accesible desde
Cuenta para la identidad autenticada. La lista se deriva directamente de la
outbox SwiftData e incluye altas, ediciones y tombstones, incluso cuando la
entrada ya no aparece en Colección. Seleccionar una operación ejecuta un GET
individual fresco antes de mostrar o habilitar decisiones; `confirmedState` no
es evidencia suficiente porque `nil` también puede significar que nunca existió
una base utilizable y una presencia incompatible puede haber dejado una base
anterior.

La evidencia de revisión solo puede ser:

- `200` con identidad y volúmenes compatibles: presencia remota utilizable;
- `404` exacto: ausencia remota utilizable;
- presencia incompatible o deriva de contrato: estado opaco, sin decisiones;
- fallo de red, autorización o persistencia: no disponible, sin decisiones y con
  posibilidad de volver a comprobar.

Un primer `401` del GET individual fuerza la recuperación single-flight de la
credencial para la misma generación y un único retry. Un segundo `401` conserva
sesión, Keychain, Colección y bloqueo y se presenta como incompatibilidad del
servicio. Un `403` conserva igualmente la sesión y se presenta como permiso
insuficiente, sin refresh ni retry. Ningún log contiene JWT, correo o payload.

Antes de confirmar una decisión, el coordinador repite una única lectura fresca.
Si la evidencia completa —estado de colección y snapshot de manga— difiere de la mostrada, no muta y exige revisar de nuevo; el
backend no publica ETag ni revisión con la que cerrar esa carrera. Una evidencia
compatible e idéntica habilita estas acciones:

- **usar la versión de la nube**: avanza la base, aplica la presencia o elimina
  la entrada ante ausencia y confirma la operación exacta, sin POST ni DELETE;
- **enviar la versión de este dispositivo**: avanza la base y confirma la
  operación exacta; si la lectura ya demuestra el efecto deseado termina sin
  escritura, y si persiste divergencia crea una nueva `queued` con UUID y
  secuencia nuevos para que el worker normal emita exactamente un POST o DELETE.

Si existe una intención N+1 posterior para la misma pareja, su estado local tiene
precedencia. La UI lo explica y ofrece únicamente continuar con ese cambio más
reciente: confirma N, actualiza la base, conserva N+1 sin modificarla y despierta
explícitamente el worker. No crea N+2 ni permite adoptar la nube descartando de
forma implícita N+1. Una secuencia posterior corrupta, incierta o no validable
mantiene N bloqueada.

La transacción de resolución queda cercada por autoridad, usuario, manga, UUID,
secuencia, estado `blockedOutcome`, estado deseado completo y evidencia remota.
Una operación resuelta o reemplazada, un cambio de sesión, cancelación, UUID
duplicado, overflow o fallo de guardado deja todo en el último commit. Tras el
commit, una nueva intención cambia la identidad observada por el shell. La identidad
de sincronización incluye además el subconjunto durable `blockedOutcome`; cuando
se conserva N+1 sin cambiarla, confirmar N modifica ese subconjunto y el shell
inicia de forma explícita un nuevo ciclo R1→R2, independiente de la tarea de la
pantalla, para evitar que N+1 quede dormida tras retirar la cerca.

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
| Advanced | Login correcto | Un único envelope Keychain V3 conserva generación, UUID, JWT y expiración después de validar `/users/jwt/me`; la contraseña no queda persistida. |
| Advanced | JWT dentro de la ventana preventiva | Una sola renovación abastece peticiones concurrentes, valida la misma identidad y actualiza la sesión aplicable. |
| Advanced | Refresh devuelve el mismo texto JWT | Rota la revisión opaca; las capacidades anteriores no autorizan requests ni commits y los waiters reciben solo la credencial de su autoridad vigente. |
| Advanced | JWT ya expirado | No se envía a refresh ni a recursos protegidos; el registro deja de autorizar, se intenta eliminar y la sesión requiere autenticación. |
| Advanced | JWT vence tras resolver una autorización o durante transporte | No se emite una credencial ya vencida ni se aplica la respuesta remota; la sesión pasa a `authenticationRequired`. |
| Advanced | JWT vence antes de una mutación local | No cambia SwiftData ni outbox; Cuenta reconcilia `authenticationRequired` y Colección queda sin capacidad de escritura. |
| Advanced | Refresh JWT no válido | El registro deja de autorizar, se intenta eliminar, la sesión requiere autenticación solo en memoria y sus operaciones pasan a `blockedAuth`; tras relanzar sin registro parte de `signedOut`. |
| Advanced | Logout o invalidación durante el commit Keychain de refresh | Devuelve `transitionInProgress`; al terminar el commit puede reintentarse contra el único envelope V3 vigente, sin divergencia entre memoria y Keychain. |
| Advanced | Logout sin red | El envelope Keychain esperado queda eliminado y los datos siguen aislados por usuario, sin exigir un bridge Deluxe. |
| Advanced | Fallo al borrar Keychain | Logout no completa y ofrece reintento. Conserva la sesión solo si su JWT sigue vigente; si vence durante el borrado, publica `authenticationRequired`, conserva visible el fallo y no reactiva el envelope residual. |
| Advanced | Crash durante logout | Si el registro permanece, restaura la sesión; si ya fue eliminado, restaura `signedOut`. No existe limpieza intermedia. |
| Advanced | Activación de B durante el logout de A | El propietario no activa B hasta que el borrado de A termina con éxito o error. |
| Advanced | Efecto tardío de A tras activar B | La comprobación de generación lo convierte en no-op; credenciales, rutas, datos y operaciones de B permanecen intactos. |
| Advanced | Editor o comando A tras activar otra generación del mismo UUID | No solicita una capacidad para B, y la cerca del model actor rechaza también una capacidad B directa; colección y outbox quedan intactas. |
| Advanced | Logout con cambios pendientes | Exige mantener la sesión o confirmar el descarte mediante dos intentos cercados distintos; esperar conserva todo y reanuda R2, mientras el descarte restaura o elimina cada entrada, retiene `max` como cursor `confirmed` y no deja outbox reproducible bajo otra sesión. |
| Advanced | Edición sin red | La UI cambia vía SwiftData y queda una operación persistida `queued` o `retry`. |
| Advanced | Reinicio de app | La intención pendiente conserva UUID, secuencia y posibilidad de envío. |
| Advanced | Varias ediciones del mismo manga | Se coalescen sin perder la intención más reciente ni permitir respuestas fuera de orden. |
| Advanced | Ediciones de mangas distintos | Mantienen identidades y secuencias independientes. |
| Advanced | Borrado sin red | La entrada se oculta y la tombstone persiste hasta resolverla. |
| Advanced | Snapshot R1 presente sin intención pendiente | Estado local, base confirmada y presentación adoptan la versión remota mediante un único commit. |
| Advanced | Snapshot R1 presente con intención pendiente | Conserva estado local, tombstone y outbox; actualiza únicamente la base confirmada y la presentación remota. |
| Advanced | Snapshot R1 ausente | Retira solo una entrada confirmada sin intención pendiente; conserva una intención pendiente con ausencia confirmada y falla cerrado ante un huérfano sin base ni outbox. |
| Advanced | Lote R1 inválido, cancelado o no persistible | No aplica ninguna parte y conserva colección y outbox previas. |
| Advanced | R1 recibe total, propiedad o lectura `301` o `Int64.max` sin una tombstone exacta procesable | Falla antes de materializar rangos, revierte el lote completo y conserva sesión, Keychain, colección y outbox. |
| Advanced | Respuesta R1 de una generación anterior | No modifica la colección ni la outbox de la sesión vigente. |
| Advanced | Refresh preventivo previo a R1 rechazado por `/users/jwt/me` | No llama a Colección, conserva la sesión todavía válida y presenta incompatibilidad de identidad renovada. |
| Advanced | Primer `401` R1 de la request vigente | Fuerza una única renovación single-flight, revalida la identidad y repite una sola vez el GET seguro. |
| Advanced | Refresh rechazado permanentemente durante la recuperación R1 | Retira el envelope exacto y proyecta `authenticationRequired`; no ejecuta el segundo GET. |
| Advanced | Segundo `401` R1 con JWT renovado aceptado por `/users/jwt/me` | Conserva sesión, Keychain, colección y outbox, no realiza un tercer intento y presenta incompatibilidad del endpoint. |
| Advanced | `403` R1 de una request vigente | Conserva sesión, Keychain, colección y outbox, no renueva ni repite y presenta autorización insuficiente de Colección. |
| Advanced | Rechazo R1 tardío tras refresh o sesión B | Se convierte en `sessionChanged`, no invalida el JWT renovado ni la sesión posterior y no modifica SwiftData. |
| Advanced | Vuelo de refresh A residual después de activar B | La autorización y una recuperación `401` de B ignoran el vuelo no coincidente; A termina como `sessionChanged` y no modifica ni bloquea B. |
| Advanced | Waiter cancelado mientras falla la persistencia Keychain | El fallo seguro de carga, guardado, reemplazo o limpieza prevalece sobre la cancelación y Cuenta lo presenta solo si aún coincide UUID y generación. |
| Advanced | Error transitorio | La operación pasa por `retry` y no duplica efectos visibles. |
| Advanced | Retry 1–6 y posteriores | Persiste esperas de 1, 2, 4, 8, 16 y 30 segundos; después conserva el tope de 30 segundos sin overflow. |
| Advanced | Retry futuro en una pareja y trabajo accionable en otra | Procesa primero la pareja accionable; el deadline no bloquea globalmente la outbox. |
| Advanced | Cancelación o sustitución durante el backoff | Conserva `retry`, contador y deadline sin emitir otra request; el sustituto espera el mismo deadline y al reactivarse vuelve a cercar sesión y operación. |
| Advanced | Resultado potencialmente aplicado o status no caracterizado | Reconcilia y, si no obtiene evidencia concluyente, conserva `blockedOutcome`; nunca lo convierte por conveniencia en retry o rechazo. |
| Advanced | Pérdida de autoridad antes de una escritura incierta | `queued` y `retry` del usuario pasan a `blockedAuth`; una `sending` incierta permanece para reconciliación. |
| Advanced | Sesión válida posterior del mismo usuario | Después de R1, conserva la última intención segura no enviada por manga; una `blockedAuth` retenida pasa a `queued` y una N+1 `queued` o `retry` más reciente prevalece sobre la bloqueada. |
| Advanced | Sesión posterior de otro usuario | No reactiva, muestra ni envía las operaciones bloqueadas de la identidad anterior. |
| Advanced | R2 encuentra una intención no tombstone histórica fuera de `1...300` | No la reclama ni emite POST, conserva su estado y no altera otra intención, sesión o Keychain. |
| Advanced | Eliminación explícita de un estado histórico incompatible | Crea y puede enviar una tombstone mediante DELETE sin transportar total, propiedad o lectura; no habilita su edición o POST. |
| Advanced | POST histórico incompatible N recuperado en `sending` y eliminación explícita | La transacción retira N sin confirmarlo, conserva la secuencia y crea N+1; R1 no queda bloqueado y R2 reclama el DELETE. |
| Advanced | R1 observa la fila incompatible de una tombstone exacta `queued` | No importa ni confirma ausencia para esa fila; conserva la presencia bruta y R2 envía DELETE. |
| Advanced | R1 observa la fila incompatible de una tombstone exacta `sending` | No adopta sus valores; R2 usa la presencia bruta, persiste `blockedOutcome` y no repite DELETE. |
| Advanced | Todas las operaciones N…N+1 son `blockedAuth`, `queued` o `retry` y N+1 es tombstone | R1 conserva la presencia incompatible opaca; la recuperación supersede N y reclama únicamente el DELETE N+1. |
| Advanced | Una operación `sending`, `blockedOutcome` o `rejected` anterior cerca la tombstone | La excepción contextual no se aplica y el snapshot incompatible se rechaza completo. |
| Advanced | Efecto remoto aplicado y respuesta perdida | La reconciliación reconoce el estado deseado, pasa a `confirmed` y no repite el request. |
| Advanced | Resultado remoto inconcluso | Pasa a `blockedOutcome`, conserva ambos estados para resolver y no revierte ni reintenta automáticamente. |
| Advanced | DELETE de tombstone confirmado con `200` e `Int64` | Confirma la operación exacta, retira la entrada si no existe N+1 y no ejecuta GET individual. |
| Advanced | DELETE incierto y GET individual `404` | Confirma ausencia y nunca repite DELETE. |
| Advanced | DELETE incierto y GET individual `200` coincidente | Conserva la tombstone en `blockedOutcome`, mantiene la sesión y no repite DELETE. |
| Advanced | Tombstone `sending` recuperada con snapshot R1 | Ausencia confirma y presencia bloquea con cero requests adicionales. |
| Advanced | Rechazo permanente | Se restaura la última versión confirmada y el rechazo queda resuelto de forma observable. |
| Advanced | Rechazo positivo con base ausente | La transacción restaura ausencia, resuelve la operación como cursor `confirmed` y no deja una entrada optimista huérfana. |
| Advanced | Rechazo positivo con intención N+1 | Resuelve N contra su base confirmada sin sobrescribir el estado visible ni la secuencia posterior. |
| Advanced | Fallo al persistir una reversión | Colección y outbox conservan juntas el estado anterior; no queda una mitad restaurada ni un falso `confirmed`. |
| Advanced | R2.4 abre una operación bloqueada | Ejecuta un GET individual fresco; `200` compatible y `404` habilitan decisiones, mientras lectura fallida o presencia incompatible conservan el bloqueo sin mutaciones. |
| Advanced | R2.4 acepta nube presente o ausente sin N+1 | Aplica o elimina localmente, confirma la operación exacta y realiza cero escrituras remotas. |
| Advanced | R2.4 conserva dispositivo con divergencia sin N+1 | Confirma la ambigua contra la base fresca y crea una nueva `queued` con UUID y secuencia propios; el worker normal realiza como máximo una escritura. |
| Advanced | R2.4 conserva dispositivo y la lectura ya coincide | Confirma sin crear otra intención ni escribir de nuevo. |
| Advanced | R2.4 encuentra N+1 | Conserva estado visible y N+1 intactos, confirma N contra la base fresca, no ofrece adoptar nube ni crea N+2 y despierta el worker. |
| Advanced | La nube cambia entre revisión y confirmación | No muta Colección ni outbox; muestra la nueva evidencia y exige una decisión actualizada. |
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

WatchOS y WidgetKit consumen proyecciones y no abren nuevos escritores autoritativos. El orden de snapshot y recarga de WidgetKit sigue [ADR-0022](../adr/0022-widget-collection-projection-and-adaptive-reading.md); cualquier mutación futura desde una superficie Deluxe requeriría otra decisión explícita.

## Fuera de alcance y riesgos

- No se persisten credenciales básicas ni se implementa un almacén de secretos propio.
- No se presupone un endpoint de revocación, idempotency key o resolución de conflictos que OpenAPI no declare.
- Una operación con UUID estable mejora la idempotencia local, pero no garantiza idempotencia del servidor si su contrato no la soporta.
- La recuperación después de un cierre durante `sending` debe reconciliar antes de repetir; si no puede demostrar el resultado, conserva `blockedOutcome` para resolución visible.
- R2.3 no incorpora una acción manual de retry ni resolución interactiva de
  `blockedOutcome`; esas capacidades permanecen en R2.4 y en el cierre posterior
  de Advanced.
- No existe scheduler de background, `BGTask`, polling perpetuo ni ejecución
  garantizada fuera del ciclo de vida del coordinador. La fecha persistida permite
  continuar con seguridad al siguiente trigger aplicable.
- Ningún error de escritura no publicado se adopta como rechazo permanente hasta
  que una revisión normativa caracterice de forma positiva esa respuesta.

## Especificaciones y decisiones relacionadas

- [Alcance de producto](00-product-scope-and-levels.md)
- [Arquitectura y composición](01-architecture-and-composition.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [ADR-0003: concurrencia y aislamiento](../adr/0003-concurrency-and-default-isolation.md)
- [ADR-0004: SwiftData local-first y model actors](../adr/0004-swiftdata-local-first-and-model-actors.md)
- [ADR-0006: autenticación, Keychain y sincronización, superseded](../adr/0006-authentication-keychain-and-sync.md)
- [ADR-0017: flujos nativos y respuesta HTTP con status validado](../adr/0017-validated-http-status-response-boundary.md)
- [ADR-0022: proyecciones y frescura del widget](../adr/0022-widget-collection-projection-and-adaptive-reading.md)
- [ADR-0018: bundle único de sesión en Keychain y logout atómico, superseded](../adr/0018-single-keychain-session-bundle-and-atomic-logout.md)
- [ADR-0019: JWT único de sesión y envelope Keychain V3](../adr/0019-single-jwt-session-and-keychain-v3.md)

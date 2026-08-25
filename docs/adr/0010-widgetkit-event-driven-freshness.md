# ADR-0010: Frescura dirigida por eventos para WidgetKit

**Estado:** Accepted
**Fecha:** 2026-08-18
**Supersede:** —
**Superseded by:** —
**Complementa:** [ADR-0007: Puentes de datos para watchOS y WidgetKit](0007-watchos-widgetkit-and-data-bridges.md)
**Complementado por:** [ADR-0013: Frontera de logout Advanced y bridge Deluxe](0013-advanced-logout-and-deluxe-bridge-boundary.md)

## Contexto

El ADR-0007 establece que la app iOS publica un snapshot versionado en un App
Group y que el widget es un consumidor de solo lectura. Falta decidir cuándo se
publica ese snapshot y cómo se solicita su presentación sin convertir la
frecuencia de actualización en una promesa temporal.

La proyección del widget cambia por transiciones conocidas de la colección o de
la sesión. No representa una actividad continua y WidgetKit conserva la decisión
final sobre cuándo renderizar una timeline solicitada. Una marca privada de
limpieza no permite que la extensión compruebe si aún está autorizada a leer
un envelope anterior. La autorización debe formar parte del estado compartido y
ser verificable durante cada lectura.

## Drivers

- Publicar únicamente estado persistido o comprometido localmente y ya visible
  para la lectura canónica de la app; reservar `confirmed` para confirmaciones
  remotas.
- Preservar el último snapshot válido ante fallos ordinarios, pero revocar su
  legibilidad compartida antes de completar un logout.
- Ordenar publicaciones, cambios de sesión y recuperación de crashes sin usar el
  reloj de pared ni permitir que una tarea tardía publique datos de otra sesión.
- Hacer que la extensión detecte una carrera entre autorización y lectura sin
  depender de coordinación entre procesos.
- Publicar portadas locales inmutables sin dejar manifests con referencias
  parciales o rotas.
- Respetar el presupuesto de WidgetKit y mantener red, sincronización y
  credenciales fuera de la extensión.
- Poder verificar disparadores, orden y fallos con tests deterministas, sin
  esperas ni dependencias del reloj real.
- No ofrecer un SLA de frescura que la plataforma no puede garantizar.

## Opciones consideradas

1. **Publicación serializada, `SessionFence` compartido y timeline `.never`:** la
   app publica por eventos y la extensión solo acepta contenido autorizado por
   un fence estable; añade una lectura y un pequeño protocolo de commit.
2. **Marca privada de limpieza pendiente:** puede bloquear al escritor, pero
   la extensión no puede verla ni usarla para revocar semánticamente un envelope
   anterior.
3. **Polling mediante timelines o un `BGTask`:** añade una oportunidad periódica
   de actualización, aunque consume presupuesto, introduce latencia artificial y
   sigue sin garantizar una hora de ejecución.
4. **Red directa o WidgetKit push:** permitiría obtener cambios sin abrir la app,
   pero duplicaría autoridad, transporte, autenticación o infraestructura para
   una superficie local y de solo lectura.
5. **ActivityKit:** está diseñado para actividades vivas con evolución temporal;
   no corresponde a una proyección estática de mangas en lectura.

## Decisión

### Disparadores, publicador y comandos

Un único publicador serializado será propietario del bridge, del `SessionFence`,
de la asignación de revisiones, del staging de recursos y de la solicitud de
reload. La app iOS le enviará una publicación después de una transición
completada que cambie la proyección visible:

- un commit local persistido satisfactoriamente y ya visible para la lectura
  canónica;
- una reconciliación remota que cambie el estado confirmado por el servidor y
  persistido localmente;
- una reversión o descarte que cambie el estado visible;
- una restauración o importación que cambie el estado visible;
- una redacción por logout, bloqueo o invalidación de la sesión.

No se publicará estado especulativo anterior al commit local. Un comando de
contenido exige que su generación de sesión esperada continúe activa; el
publicador la revalidará inmediatamente antes de reemplazar el envelope y, cuando
deba abrir el fence, otra vez justo antes de abrirlo. Si la sesión A dejó de ser
la vigente, descartará el comando.

Un comando de redacción de A no exige que A siga activa. Se ejecutará si el fence
todavía permite A, o será idempotente si ya está cerrado. Si el fence pertenece a
B, la redacción tardía de A será un no-op y no podrá reemplazar ni cerrar el
estado de B.

### `SessionFence` y lectura verificable

El App Group contendrá un `SessionFence` mínimo, inmutable al leerlo y versionado,
con estos campos semánticos:

- versión de formato;
- `publicationGeneration`;
- `fenceRevision`, un `UInt64` monotónico dentro del epoch;
- `allowedSessionGeneration`, opcional y sin identidad personal.

El fence se escribirá atómicamente. El escritor no considerará aplicado un cambio
hasta volver a leerlo, decodificarlo y comprobar que coincide con el valor
esperado. `allowedSessionGeneration == nil` cierra el bridge: ningún envelope de
contenido es semánticamente legible, aunque sus bytes sigan presentes.

El provider leerá y validará en este orden: fence inicial, envelope completo y
fence final. Solo renderizará contenido o vacío si los dos fences son idénticos,
su versión es conocida, `allowedSessionGeneration` no es `nil`, y el envelope
pertenece a la misma `publicationGeneration` y generación de sesión autorizada.
Un fence ausente, corrupto, cerrado o cambiado entre ambas lecturas, o cualquier
discordancia de epoch o sesión, produce un estado redactado o no disponible; no
se recupera contenido directamente del envelope como fallback.

### Generaciones, revisiones y recuperación

La generación opaca de sesión del ADR-0007 delimita la sesión de contenido. La
`publicationGeneration` es un epoch opaco separado, sin identidad personal, que
delimita los contadores del envelope y del fence.

La revisión del envelope será un `UInt64` estrictamente monotónico dentro de una
`publicationGeneration`. El publicador persistirá el contador fuera de la sesión
y reservará durablemente cada revisión antes del reemplazo. `fenceRevision`
también crecerá monotónicamente dentro del epoch para detectar cada apertura o
cierre. Una revisión reservada puede quedar sin usar tras un fallo o crash, pero
nunca se reutiliza ni hace wrap. Las revisiones de epochs distintos no se
comparan numéricamente.

Si el epoch o sus contadores se pierden o corrompen, la app se reinstala, o el
siguiente incremento produciría overflow, el publicador rotará
`publicationGeneration`. Primero escribirá y verificará un fence del epoch nuevo
con `allowedSessionGeneration == nil`; después podrá publicar contenido del epoch
nuevo y abrir ese fence para la sesión vigente. El provider no necesita observar
un envelope de bootstrap intermedio: el fence cerrado es el reset verificable.

Antes de un reemplazo, el publicador persistirá intención suficiente para
recuperar la operación. Al arrancar reconciliará esa intención con fence y
envelope: una revisión reservada pero no publicada queda consumida; un envelope
y fence ya comprometidos cuyo reload no llegó a solicitarse provocan una nueva
solicitud dirigida. Repetir la solicitud es aceptable porque no confirma que la
presentación haya ocurrido.

En una publicación ordinaria de una sesión todavía permitida, un fallo al
reservar, codificar, reemplazar el envelope o preparar un asset que aún fuese a
referenciarse conserva el último manifest válido y el fence vigente, consume
cualquier revisión ya reservada y no solicita reload. El fallo de una portada
opcional se normaliza antes del commit omitiendo su referencia y usando
placeholder. Esta degradación no se usa para completar una invalidación de
sesión, que debe cerrar primero el fence.

### Logout, redacción y apertura de sesión

Logout persistirá primero su transición en curso. Antes de invalidar la sesión o
borrar Keychain, el publicador cerrará atómicamente el fence de A con
`allowedSessionGeneration == nil` y verificará su lectura. Si no puede cerrar y
verificar el fence, logout no se considera completado: conserva la sesión y sus
credenciales, presenta el fallo y ofrece retry.

Una vez verificado el fence cerrado, la app puede invalidar la sesión y limpiar
Keychain sin esperar a WidgetKit. Después intentará reemplazar el envelope por un
estado `redacted` y solicitará el reload dirigido. Si ese reemplazo falla, el
fence ya impide que futuras lecturas acepten el contenido anterior; la limpieza
del envelope puede reintentarse, pero ya no es la garantía de privacidad.

La recuperación del logout distingue sus límites de crash: antes de verificar el
fence reintenta el cierre y no completa la limpieza de sesión; después del fence
cerrado completa la invalidación y Keychain; después de la limpieza puede repetir
el envelope redactado y el reload. Una timeline ya cacheada puede seguir visible
hasta que WidgetKit procese una nueva: la redacción visual continúa siendo
eventual y no tiene SLA.

Para publicar la primera proyección de una sesión B, el fence debe estar cerrado
o permitir ya B. La app prepara recursos y envelope, revalida B, reemplaza
atómicamente el envelope y, si el fence estaba cerrado, vuelve a validar B, abre
y verifica el fence para B. Solo entonces solicita reload. Un crash o fallo antes
de abrirlo puede dejar el envelope de B en disco, pero el provider no lo considera
legible.

### Portadas y commit de publicación

Una portada será una referencia local opcional. Cada archivo publicado será
inmutable y tendrá un nombre content-addressed o ligado a
`publicationGeneration` y revisión; nunca se sobrescribirá en el mismo nombre.
La app escribirá atómicamente los assets necesarios antes del envelope, que actúa
como manifest y punto de commit. Si una portada opcional no puede prepararse o
validarse, el envelope omitirá su referencia y el widget mostrará un placeholder
accesible; la extensión nunca la descargará.

La limpieza se ejecutará después de publicar el manifest y conservará todos los
assets todavía referenciados por el envelope canónico o por una revisión retenida
para lectores en curso. Un crash anterior al commit puede dejar un asset huérfano,
pero no una referencia parcial; la recuperación lo podrá limpiar más tarde sin
alterar la publicación válida.

### WidgetKit y reload

El widget 1.0 seguirá siendo estático: usará `StaticConfiguration` con un
`TimelineProvider`, y todas las instancias del mismo `kind` consumirán la misma
proyección.

En una actualización ordinaria de la sesión ya permitida, la app solicitará
`WidgetCenter.shared.reloadTimelines(ofKind:)` solo después del reemplazo atómico
del envelope. En apertura, rotación de epoch o redacción, lo hará únicamente
después de escribir y verificar el fence seguro correspondiente. No usará
`reloadAllTimelines()` para este flujo.

El provider entregará el estado actual mediante una timeline con política
`.never`. La solicitud dirigida comunica que existen datos nuevos, pero no
establece un plazo de renderizado: el sistema puede diferirla o combinarla con
otras actualizaciones. Manga Library no ofrecerá un SLA temporal de frescura.

Para 1.0 quedan excluidos como mecanismos de frescura del widget el polling, la
red o sincronización directa desde la extensión, WidgetKit push, `BGTask` y
ActivityKit. Un `BGTask` de la app puede servir a otros fines aprobados, pero la
corrección ni la frescura del widget dependerán de él.

### WatchConnectivity

El estado canónico de solo lectura para watchOS viajará exclusivamente mediante
`WCSession.updateApplicationContext(_:)` como un diccionario versionado y
autocontenido. No dependerá de mensajes o archivos anteriores para interpretar
contenido, vacío, redacción o cambio de epoch. Apple reemplaza con cada llamada el
diccionario anterior pendiente en este canal; el receptor reemplazará su cache
canónica con el nuevo contexto y un epoch nuevo sustituirá el anterior sin exigir
que el reloj observe un bootstrap intermedio.

`transferUserInfo`, `transferFile` y `sendMessage` no serán el canal canónico ni
una precondición para aceptar ese estado. Una portada que no esté contenida o
disponible localmente degrada a placeholder. El envío puede hacerse sin que el
reloj esté alcanzable, pero la entrega ocurre cuando el sistema encuentra una
oportunidad; sigue siendo eventual y no bloquea logout.

## Consecuencias

### Positivas

- El widget refleja transiciones semánticas sin consultar periódicamente el
  store, Keychain o la red.
- La doble lectura del fence impide aceptar contenido durante una apertura,
  cierre o rotación concurrente.
- Cerrar y verificar el fence antes de borrar credenciales hace que el estado
  compartido, no una marca privada, revoque la lectura de la sesión.
- El epoch, las revisiones durables y los comandos condicionados impiden
  reutilizar orden o publicar contenido o redacciones tardías sobre otra cuenta.
- `updateApplicationContext(_:)` modela el reloj como consumidor del último
  estado autocontenido, sin una cola canónica adicional.
- La política `.never` evita usar una cadencia ficticia como mecanismo de
  consistencia.
- Los fallos y el orden de efectos se pueden probar sin latencia real.

### Negativas

- Un evento omitido por la app puede dejar visible el último snapshot hasta una
  publicación posterior.
- Incluso una publicación correcta puede tardar en aparecer por decisión del
  sistema.
- Cada lectura del provider accede dos veces al fence y una vez al envelope.
- El publicador necesita metadata durable para revisiones, fence, recuperación y
  reset, además del ciclo de vida de portadas locales obsoletas.
- Un fallo al cerrar o verificar el fence impide completar logout y obliga a
  presentar retry, aunque la sesión todavía sea válida.
- Tras cerrar el fence, WidgetKit puede seguir mostrando una timeline cacheada y
  el reloj puede conservar su contexto anterior hasta recibir el reemplazo.
- `updateApplicationContext(_:)` conserva último estado, no historial, entrega
  inmediata ni un canal adecuado para recursos separados obligatorios.
- Las revisiones pueden contener huecos y una recuperación puede repetir una
  solicitud de reload.
- La actualización originada exclusivamente en servidor mientras la app no se
  ejecuta queda fuera del alcance de 1.0.

## Validación

- Probar cada disparador con cambios visibles y comprobar que los eventos sin
  cambio de proyección no publican revisiones innecesarias.
- Probar la secuencia fence-envelope-fence: dos lecturas iguales y compatibles
  permiten contenido; cambio de `fenceRevision`, cierre, ausencia, corrupción o
  discordancia de epoch o sesión producen redacción o no disponible.
- Registrar en un doble que el envelope precede a la apertura del fence y que
  `reloadTimelines(ofKind:)` ocurre solo después del envelope ordinario o del
  fence abierto/cerrado y verificado que corresponda.
- Inyectar fallos de codificación y escritura y verificar que los bytes del
  snapshot anterior de la misma sesión no cambian y que no se solicita reload.
- Probar que un fallo al cerrar o verificar el fence aborta la finalización de
  logout, conserva sesión y Keychain y ofrece retry.
- Simular crashes antes y después de cerrar el fence, entre fence y limpieza de
  Keychain, y entre Keychain, envelope redactado y reload; la recuperación
  completa exactamente la fase segura pendiente.
- Simular contenido tardío de A tras activar B; el comando de contenido se
  descarta, la redacción de A procede si el fence aún permite A y se vuelve no-op
  si ya permite B.
- Simular pérdida, corrupción, reinstalación y overflow del contador; verificar
  cierre del fence con el epoch nuevo, publicación y apertura posterior, sin
  exigir observar bootstrap y sin wrap, reutilización o comparación numérica
  entre epochs.
- Simular crashes tras reservar revisión, escribir assets, reemplazar el envelope
  y antes o después de abrir el fence o solicitar reload; nunca se acepta un
  manifest parcial y la recuperación vuelve a solicitar únicamente cuando
  procede.
- Probar portada content-addressed o ligada a revisión válida, ausente y corrupta;
  orden asset-before-manifest, placeholder accesible, retención de assets
  referenciados y limpieza posterior de huérfanos.
- Probar reemplazos sucesivos de `updateApplicationContext(_:)` con contextos
  autocontenidos, incluido un epoch nuevo y una redacción; el último sustituye la
  cache sin depender de `transferUserInfo`, `transferFile`, `sendMessage` ni de
  observar un bootstrap intermedio.
- Verificar que el provider usa `.never` y que la extensión no enlaza rutas de
  red, WidgetKit push, `BGTask` o ActivityKit.
- Ejecutar estas pruebas con dobles, directorios temporales y entradas
  controladas, sin `sleep`, polling ni aserciones de tiempo transcurrido.

## Condiciones de revisión

- El producto exige reflejar cambios de servidor sin que la app se ejecute.
- Aparece un caso realmente vivo que requiera ActivityKit o una cadencia propia.
- Se solicita un SLA de frescura o interactividad desde el widget.
- El bridge necesita varios escritores o el ciclo de epoch ya no puede mantenerse
  con un publicador serializado.
- La política de producto permite completar logout sin haber cerrado un fence
  compartido verificable, lo que exigiría otra garantía de revocación.
- Una API futura de Apple ofrece entrega transaccional o garantías temporales
  adecuadas para sustituir este contrato.

## Especificaciones relacionadas

- [Deluxe, watchOS y widget](../specs/05-deluxe-watch-and-widget.md)
- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)

## Referencias

- Apple: [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- Apple: [`TimelineReloadPolicy.never`](https://developer.apple.com/documentation/widgetkit/timelinereloadpolicy/never)
- Apple: [`WidgetCenter.reloadTimelines(ofKind:)`](https://developer.apple.com/documentation/widgetkit/widgetcenter/reloadtimelines(ofkind:))
- Apple: [Making network requests in a widget extension](https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension)
- Apple: [Updating widgets with WidgetKit push notifications](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications)
- Apple: [ActivityKit](https://developer.apple.com/documentation/activitykit)
- Apple: [`WCSession.updateApplicationContext(_:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:))

# ADR-0018: Bundle único de sesión en Keychain y logout atómico

**Estado:** Accepted
**Fecha:** 2026-09-01
**Supersede:** [ADR-0013](0013-advanced-logout-and-deluxe-bridge-boundary.md) y [ADR-0016](0016-versioned-session-ledger-and-keychain-boundary.md)
**Superseded by:** —
**Complementa:** [ADR-0006](0006-authentication-keychain-and-sync.md) y [ADR-0010](0010-widgetkit-event-driven-freshness.md)

## Contexto

ADR-0016 coordinaba dos almacenes: un bundle secreto por generación en Keychain
y un ledger no secreto en Application Support. ADR-0013 utilizaba ese ledger
para persistir fases y revisiones de logout recuperables. La solución ofrece una
máquina resistente a fallos entre ambos almacenes, pero su coste no corresponde
al límite actual de Manga Library: durante Advanced solo el proceso principal
lee o escribe la sesión y no existe todavía App Group, extensión o bridge
Deluxe.

La primera autenticación live completó login, intercambio de access, `/me` y la
escritura Keychain, pero no pudo activar la sesión porque falló la escritura del
ledger. El diagnóstico confirma una frontera real entre los dos almacenes; no
demuestra que el producto necesite conservarla. El propietario decide que, para
esta práctica, un único registro Keychain debe contener los datos mínimos de la
sesión, restaurarse desde ese registro y eliminarse al cerrar sesión.

La colección continúa particionada por usuario incluso sin red. Por ello una
restauración necesita conocer el UUID estable sin decodificar ni atribuir
semántica no declarada al JWT y sin exigir que `/me` esté disponible.

## Drivers

- Guardar access y refresh token únicamente en Keychain y no persistir nunca la
  contraseña.
- Mantener una sola autoridad durable de sesión y eliminar la coordinación
  falible entre Keychain y filesystem.
- Recuperar offline la identidad mínima necesaria para particionar Colección y
  outbox.
- Impedir que un refresh, logout o respuesta tardía de A alteren la sesión B.
- Completar logout sin red y considerarlo terminado solo después de borrar el
  registro Keychain esperado.
- No adelantar SwiftData, entitlements, App Group ni capacidades Deluxe.

## Opciones consideradas

1. **Mantener bundle por generación y ledger en Application Support:** conserva
   fases revisionadas y recuperación después del punto de no retorno, pero exige
   ordenar, recuperar y probar dos almacenes sin transacción común.
2. **Un único registro Keychain V2:** convierte la presencia o ausencia
   de un solo ítem en la autoridad durable. Un borrado fallido conserva la sesión
   y puede reintentarse; no existe una limpieza durable intermedia.
3. **Guardar solo los JWT y recuperar siempre la identidad mediante `/me`:** es
   todavía más pequeño, pero impide identificar offline el scope local después
   de relanzar y obligaría a interpretar el token fuera del contrato publicado.
4. **Mover metadata a preferencias o SwiftData:** vuelve a introducir dos
   autoridades y, en el segundo caso, adelanta L1 sin resolver la frontera con
   Keychain.

## Decisión

Se adopta la segunda opción. El propietario serializado de sesión coordina un
único registro `kSecClassGenericPassword` que representa la sesión vigente del
proceso principal. El registro usa un `service` propio de Manga Library y un
`account` fijo; la generación deja de seleccionar otro ítem y pasa a formar
parte del valor protegido.

### Envelope Keychain V2

El envelope V2 contiene exclusivamente:

- versión de formato;
- `sessionGeneration` opaca;
- `userID` UUID estable;
- access token y su expiración absoluta;
- refresh token y su expiración absoluta.

No contiene email, contraseña, roles, permisos ni estado de presentación. Usa
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, no es sincronizable y no declara
`kSecAttrAccessGroup`. Una versión desconocida, un payload corrupto o
credenciales incoherentes nunca se interpretan parcialmente: la restauración
falla cerrada, intenta retirar el registro y presenta una sesión sin autenticar.

Los artefactos legacy de ADR-0016 no poseen autoridad bajo este formato. La
primera restauración que no encuentre un envelope vigente limpia de forma
acotada los ítems de sesión legacy y comienza sin sesión; no intenta combinar
bytes de Keychain con un ledger anterior.

### Activación, restauración y renovación

Login completa refresh → access → `/me` antes de persistir. Después genera una
identidad opaca nueva, reemplaza el único envelope Keychain y solo tras confirmar
esa escritura publica la sesión en memoria. Si el guardado falla, no publica una
sesión autenticada.

Al relanzar, la ausencia del registro significa `signedOut`. Un envelope íntegro
restaura el UUID y la generación; los datos descriptivos de cuenta vuelven a
obtenerse mediante `/me` cuando la red lo permita. Un access expirado no cierra
por sí solo la sesión si el refresh continúa vigente. Las peticiones concurrentes
comparten una sola renovación y el access nuevo reemplaza el envelope únicamente
si su generación sigue siendo la vigente.

`authenticationRequired` es un estado transitorio de memoria. Un refresh
rechazado permanentemente deja de autorizar credenciales, coloca la outbox de ese
usuario en `blockedAuth` e intenta eliminar el registro. No se persiste un
tombstone ni un scope sin tokens: después de relanzar sin envelope, la app parte
de `signedOut` y recuperará ese mismo scope cuando un login posterior confirme el
mismo `userID`.

Si ese borrado falla, el proceso vigente descarta inmediatamente las credenciales
de memoria, permanece en `authenticationRequired` y expone la incidencia de
persistencia para reintentar la limpieza; nunca vuelve a entregar el access ya
rechazado. El envelope residual no recupera autoridad dentro de ese proceso. Sin
un tombstone durable, un relanzamiento posterior solo puede volver a detectar el
rechazo al revalidar la sesión con el servidor.

### Logout Advanced

Después de resolver el gate de operaciones pendientes, el propietario bloquea
temporalmente nuevas autorizaciones y otra activación, revalida la generación
esperada y elimina el único registro. Solo una eliminación satisfactoria publica
`signedOut` y retira selecciones y rutas privadas de esa sesión. Un fallo de
borrado devuelve la sesión anterior a su estado activo y permite reintentar.

La eliminación Keychain es a la vez invalidación durable y limpieza. No existen
`logoutPrepared`, `invalidatedCleanupPending`, revisión de transición, ledger o
cancelación durable. Si el borrado falla o el proceso termina antes de
confirmarlo, el envelope permanece como autoridad y el siguiente arranque puede
restaurar la sesión; logout no se presentó como completado. Si el ítem ya no
existe, la restauración permanece cerrada. Una cancelación solo puede aceptarse
antes de iniciar el borrado.

Refresh, requests y efectos suspendidos capturan `sessionGeneration` y la
revalidan antes de aplicar su resultado. El mismo propietario serializado impide
intercalar la activación de B con el borrado de A; una discordancia convierte el
efecto tardío en no-op.

### Frontera Deluxe

Advanced continúa sin App Group, `SessionFence`, WidgetKit o WatchConnectivity.
Cuando exista un consumidor Deluxe, ADR-0010 mantiene su frontera compartida:
el publicador cierra y verifica el fence antes de solicitar el borrado Keychain.
El fence cerrado es el único punto durable de no retorno de Deluxe y permite
recuperar el tramo posterior sin reintroducir un ledger privado de sesión en
Advanced.

El bridge conserva sesión y Keychain si no puede cerrar o verificar el fence.
Después del fence seguro, la recuperación elimina condicionalmente el envelope
de la generación saliente si todavía existe y completa la redacción eventual
conforme a ADR-0010. La separación entre el gate Advanced y las garantías
compartidas Deluxe de ADR-0013 se conserva, pero su máquina local de fases y
revisiones queda sustituida por esta decisión.

## Consecuencias

### Positivas

- Un solo ítem decide la autoridad durable y elimina la causa de fallo entre
  Keychain y Application Support.
- Login, restauración, refresh y logout tienen menos estados y recuperaciones.
- El UUID necesario para Colección permanece disponible offline sin persistir
  email ni interpretar el JWT.
- Un fallo de logout tiene una semántica binaria: el ítem sigue presente y la
  sesión no terminó, o fue eliminado y la sesión quedó cerrada.
- Deluxe solo añade metadata compartida cuando exista un lector externo real.

### Negativas

- Un logout iniciado pero interrumpido antes del borrado no se reanuda; al
  relanzar puede restaurarse la sesión todavía vigente.
- `authenticationRequired` no sobrevive por sí mismo al relanzamiento.
- Si Keychain conserva por error un envelope rechazado y el proceso termina antes
  de limpiarlo, un arranque offline no puede distinguirlo de una sesión todavía
  vigente; la siguiente revalidación remota vuelve a exigir autenticación.
- El UUID estable pasa a compartir el envelope protegido con los tokens.
- La migración desde ADR-0016 falla cerrada y puede exigir volver a iniciar
  sesión.
- Si el producto exige en el futuro un punto de no retorno anterior al borrado,
  necesitará una nueva autoridad durable demostrada por ese consumidor.

## Validación

- Probar envelope íntegro, ausente, desconocido, corrupto y temporalmente
  inaccesible sin exponer tokens ni payloads.
- Probar que login solo se publica después de reemplazar el registro y que un
  fallo conserva la autoridad anterior aplicable.
- Probar restauración offline del UUID, access vigente, access expirado con
  refresh vigente y refresh definitivamente inválido.
- Probar renovación single-flight y rechazo de una respuesta cuya generación ya
  no sea la vigente.
- Probar logout correcto, fallo de borrado y los dos límites de crash: registro
  todavía presente o registro ausente.
- Probar que B no se activa durante el borrado de A y que efectos tardíos de A no
  modifican el envelope, rutas, datos u operaciones de B.
- Ejecutar integración con un service Keychain sintético y datos sintéticos, sin
  credenciales ni red reales; comprobar el ciclo en dispositivo físico antes de
  cerrar la nueva frontera.

## Condiciones de revisión

- Advanced incorpora otro proceso autorizado para leer estado privado.
- El producto exige reanudar logout o conservar `authenticationRequired` después
  de relanzar.
- Keychain deja de ofrecer la atomicidad o protección necesaria para el único
  registro.
- El backend añade revocación remota transaccional o cambia el contrato dual.
- Deluxe demuestra que su intención compartida no basta para recuperar el tramo
  fence → Keychain sin una autoridad adicional.

## Especificaciones relacionadas

- [Alcance de producto y niveles](../specs/00-product-scope-and-levels.md)
- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Deluxe, watchOS y widget](../specs/05-deluxe-watch-and-widget.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)

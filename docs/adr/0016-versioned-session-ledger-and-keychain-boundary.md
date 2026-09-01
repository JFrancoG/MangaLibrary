# ADR-0016: Ledger versionado y frontera Keychain de sesión

**Estado:** Superseded
**Fecha:** 2026-08-30
**Supersede:** —
**Superseded by:** [ADR-0018](0018-single-keychain-session-bundle-and-atomic-logout.md)
**Complementa:** [ADR-0006](0006-authentication-keychain-and-sync.md) y [ADR-0013](0013-advanced-logout-and-deluxe-bridge-boundary.md)

## Contexto

ADR-0006 exige guardar access y refresh token en Keychain. ADR-0013 añade una
condición distinta: la presencia aislada de esos secretos no basta para
reconstruir una sesión activa. La app debe recordar durablemente qué generación
es la autoridad, impedir que un efecto tardío de A altere B y recuperar un crash
en cualquier punto del logout Advanced.

Keychain y el sandbox de la app no ofrecen una transacción conjunta. Un login
puede terminar después de escribir secretos y antes de activar la sesión; un
logout puede persistir su punto de no retorno y fallar antes de borrar Keychain.
Además, S1 debe resolver esta frontera antes de que L1 incorpore SwiftData, sin
adelantar su esquema, un entitlement, App Group o una capacidad Deluxe.

## Drivers

- Mantener los JWT exclusivamente en Keychain y la contraseña solo en memoria.
- Disponer de una autoridad durable no secreta que no reactive tokens huérfanos.
- Aplicar cada reemplazo o borrado a la generación y revisión esperadas.
- Conservar sesión y secretos si logout falla antes de la invalidación.
- Permanecer fail-closed y completar limpieza si falla después de invalidar.
- Preservar el UUID estable del scope cuando una sesión requiera autenticación,
  sin persistir email, roles ni otra PII innecesaria.
- Ejecutar I/O fuera de `MainActor`, serializado por un único propietario y sin
  GCD, escapes de concurrencia ni dependencias externas.

## Opciones consideradas

1. **Bundle completo y autoridad en un único ítem de Keychain:** reduce el
   número de almacenes, pero un secreto residual puede aparentar autoridad
   después de desaparecer el estado del sandbox y expresa mal las fases de
   recuperación y el punto de no retorno.
2. **Secretos en Keychain y ledger versionado en Application Support:** separa
   secreto y autoridad, permite detectar generaciones incoherentes y materializa
   recuperación fail-closed. Exige ordenar y probar dos almacenes sin una
   transacción común.
3. **Metadatos en `UserDefaults`:** ofrece persistencia sencilla, pero no expresa
   una escritura protegida y atómica con la misma claridad, y mezcla estado de
   seguridad recuperable con preferencias.
4. **Ledger en SwiftData:** permitiría transacciones futuras con datos de
   producto, pero adelanta L1, acopla la sesión al `ModelContainer` y no evita la
   frontera independiente con Keychain.

## Decisión

Se adopta la segunda opción. `SessionPersistenceActor` será el único propietario
de la coordinación durable y serializará un almacén Keychain de secretos con un
ledger JSON no secreto en Application Support.

### Bundle secreto

Cada generación usa un único ítem `kSecClassGenericPassword` cuyo `service` es
propio de Manga Library y cuyo `account` es la representación opaca de
`sessionGeneration`. El valor codificado contiene únicamente:

- versión de formato;
- generación de sesión;
- access token y su expiración absoluta;
- refresh token y su expiración absoluta.

El ítem usa `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, no es sincronizable
y no declara `kSecAttrAccessGroup`. No se añade entitlement. El UUID de usuario,
email, contraseña y roles no forman parte de atributos buscables ni del valor
secreto.

El envelope Keychain V1 usa una lista cerrada de campos y no serializa los tipos
de dominio directamente: contiene versión, generación, access y refresh con sus
expiraciones absolutas, sin el campo derivado `use` ni metadatos de usuario. La
ausencia de `kSecAttrSynchronizable` al crear el ítem establece almacenamiento
no sincronizable; las consultas usan `false` para no recuperar otro tipo de ítem.

Una renovación reemplaza solo el access token de la generación esperada y
conserva su refresh token vigente, porque el contrato remoto de intercambio no
declara rotación de refresh. Un borrado consulta y elimina únicamente el account
de la generación esperada. La limpieza sin ledger puede retirar todos los ítems
del service, porque ninguno posee entonces autoridad para reactivar sesión.

### Ledger no secreto

El ledger se guarda en un directorio `Session` dedicado dentro del Application
Support privado de la app. El directorio se protege y excluye de backup antes de
escribir bytes. Cada versión se prepara en un staging V1 único y recuperable del
mismo directorio con `completeFileProtection`, se marca y verifica también como
excluida de backup, y solo entonces reemplaza atómicamente la autoridad anterior.
El reemplazo es la última operación falible del commit: un fallo al preparar
protección o metadata deja intacto el ledger anterior. Un staging huérfano nunca
tiene autoridad y se retira en la siguiente lectura, escritura o limpieza. Los
secretos `ThisDeviceOnly` no migran con él. Su formato versionado contiene solo:

- versión de formato;
- `userID` UUID estable;
- `sessionGeneration` opaca y opcional;
- revisión `UInt64` estrictamente creciente y sin wrap;
- una fase durable;
- un destino de limpieza opcional, limitado a `signedOut` o
  `authenticationRequired` durante `invalidatedCleanupPending`.

Las fases iniciales son:

- `active`: la generación puede autorizar trabajo si existe un bundle coherente;
- `logoutPrepared`: el logout es todavía cancelable, conserva sesión y bloquea
  la activación de otra generación;
- `invalidatedCleanupPending`: se cruzó el punto de no retorno, los tokens ya no
  autorizan y la recuperación debe completar su borrado; conserva como destino
  `signedOut` o `authenticationRequired`;
- `authenticationRequired`: el scope conserva su UUID, pero ningún token puede
  autorizar trabajo hasta completar un nuevo login.

El email y los datos completos de `/users/session/me` viven solo en memoria. Una
restauración offline puede recuperar el UUID estable; los detalles de cuenta se
actualizan al obtener una respuesta válida de `/me` sin convertirlos en
precondición para reconocer el scope local.

### Orden y recuperación

Un login remoto completa refresh → access → `/me` antes de tocar persistencia.
Después:

1. reserva una generación nueva;
2. escribe su bundle Keychain;
3. activa el ledger con el UUID confirmado y esa generación;
4. publica el estado autenticado en memoria.

Un crash entre 2 y 3 deja un token huérfano que no se restaura. La siguiente
restauración o activación lo limpia. Si falla el ledger, la sesión no se publica
y se intenta retirar condicionalmente el bundle recién escrito.

La restauración lee primero el ledger. Solo `active` con un bundle decodificable
de la misma generación vuelve a autorizar credenciales. Ledger ausente o
corrupto, bundle ausente o corrupto y generaciones incoherentes fallan cerrados;
se intenta limpiar el estado residual sin exponer secretos. `logoutPrepared`
restaura su transición cancelable y el bundle coherente para permitir reintentar
o cancelar, pero no admite nuevas credenciales. `invalidatedCleanupPending`
nunca reactiva la sesión y reanuda la limpieza. `authenticationRequired`
conserva únicamente el UUID del scope.

La ausencia o corrupción no se confunde con protección temporalmente
indisponible. Si el dispositivo bloqueado impide abrir el ítem
`WhenUnlockedThisDeviceOnly` o el archivo `completeFileProtection`, la
restauración se difiere y no escribe ni borra ninguno de los dos almacenes.

Logout sin operaciones pendientes sigue este orden:

1. `active → logoutPrepared`, incrementando revisión;
2. `logoutPrepared → invalidatedCleanupPending(.signedOut)`, incrementando
   revisión y estableciendo el punto de no retorno;
3. borrar el bundle de la generación esperada;
4. retirar el ledger únicamente si siguen coincidiendo generación, revisión,
   fase y destino `signedOut`.

Cancelar solo puede transformar la misma revisión `logoutPrepared` en `active`
con una revisión posterior. Un fallo anterior al paso 2 conserva sesión y
Keychain. Después del paso 2, la sesión permanece cerrada aunque falle el borrado
o termine el proceso. Todo efecto tardío transporta generación y revisión; una
discordancia es un no-op y nunca borra ni activa otra sesión.

Un refresh rechazado permanentemente cambia primero el ledger de la generación
esperada a `invalidatedCleanupPending(.authenticationRequired)`. Solo después de
borrar condicionalmente su bundle termina en `authenticationRequired` con el
UUID del scope y sin generación autorizable. Un fallo de limpieza conserva la
fase pendiente para reintentar; un fallo de red recuperable no altera la
autoridad durable ni elimina una sesión válida.

### Aislamiento y composición

Keychain y filesystem son APIs síncronas que pueden bloquear al llamante. Sus
operaciones se ejecutan dentro del actor de persistencia, nunca desde
`MainActor`. La secuencia no suspende entre pasos síncronos de una transición,
por lo que otra operación de sesión no puede intercalarse en mitad del commit
local.

`SessionController` conserva la propiedad de login, restauración, single-flight
de access, generación y logout; consume la capacidad del actor de persistencia y
revalida identidad antes de publicar efectos remotos. `AppComposition` crea solo
la implementación live. Previews y el bootstrap Debug de UI tests usan
capacidades directas, nunca Keychain o red live. Swift Testing mantiene red y
credenciales reales fuera del proceso; la integración de stores usa un service
Keychain sintético único y filesystem temporal aislado.

## Consecuencias

### Positivas

- Un token huérfano nunca se interpreta como sesión activa.
- La frontera distingue con precisión fallo antes y después del punto de no
  retorno.
- La identidad persistida se minimiza al UUID necesario para particionar datos.
- Generación y revisión convierten efectos tardíos de A en no-op frente a B.
- S1 queda independiente de SwiftData, App Group y los targets Deluxe.

### Negativas

- Dos almacenes obligan a mantener una matriz explícita de orden y recuperación.
- Una limpieza fallida después de invalidar deja un estado bloqueado visible
  hasta que el actor pueda completarla.
- Los datos descriptivos de cuenta no están disponibles offline después de un
  relanzamiento hasta revalidar `/me`; el UUID estable sí permanece disponible.
- Los ítems huérfanos pueden existir temporalmente, aunque carecen de autoridad y
  se eliminan al restaurar o activar otra sesión.

## Validación

- Probar activación, restauración y refresh con generaciones coherentes.
- Probar ledger o bundle ausente, corrupto y con generación incoherente.
- Probar crash después de cada escritura de login y logout.
- Probar cancelación antes de invalidar y rechazo después del punto de no
  retorno.
- Probar transición a `authenticationRequired` y conservar solo el UUID.
- Probar que una respuesta tardía de A no reemplaza ni borra el estado de B.
- Ejecutar integración con service Keychain sintético único y directorio
  temporal por test, sin credenciales ni red reales.
- Verificar en dispositivo físico el ciclo Keychain con datos sintéticos antes de
  cerrar S1; el simulador no sustituye esa evidencia.

## Condiciones de revisión

- El backend cambia la sesión dual, rota refresh en el intercambio o añade
  revocación remota transaccional.
- L1 demuestra que el ledger debe compartir una transacción con otro estado
  local sin degradar la separación de secretos.
- Una extensión real necesita compartir autoridad de sesión; entonces se aplica
  la frontera Deluxe de ADR-0013 en una decisión separada.
- La política de producto exige persistir más identidad que el UUID estable.

## Especificaciones relacionadas

- [Alcance de producto y niveles](../specs/00-product-scope-and-levels.md)
- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)

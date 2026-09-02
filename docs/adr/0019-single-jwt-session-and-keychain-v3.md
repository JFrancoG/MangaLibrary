# ADR-0019: JWT único de sesión y envelope Keychain V3

**Estado:** Accepted
**Fecha:** 2026-09-02
**Supersede:** [ADR-0006](0006-authentication-keychain-and-sync.md) y [ADR-0018](0018-single-keychain-session-bundle-and-atomic-logout.md)
**Superseded by:** —
**Complementa:** [ADR-0010](0010-widgetkit-event-driven-freshness.md) y [ADR-0017](0017-validated-http-status-response-boundary.md)

## Contexto

ADR-0006 adoptó un par access/refresh y ADR-0018 lo consolidó, junto con el
UUID y la generación de sesión, en un único registro Keychain V2. Esa decisión
se apoyaba en el contrato OpenAPI, que publica el flujo dual
`/users/session/*` y declara que sus credenciales Bearer autorizan los recursos
protegidos.

La primera integración live de R1 demostró una incompatibilidad no expresada en
ese contrato. El access emitido por `GET /users/session/access` obtiene `200` en
`GET /users/session/me`, pero `GET /collection/manga` rechaza exactamente esa
credencial con `401`, incluso después de renovarla y volver a validar la misma
identidad. En cambio, el JWT emitido por `POST /users/jwt/login` obtiene `200`
tanto en `GET /users/jwt/me` como en Colección. `POST /users/jwt/refresh`
devuelve otro JWT de la misma familia y ese JWT renovado también autoriza
Colección. La evidencia se registró solo como endpoint constante, status y
duración; no conserva tokens, credenciales, cuenta, UUID ni payloads.

El OpenAPI vivo continúa coincidiendo con el snapshot versionado y sigue
publicando ambos flujos como válidos. Por ello el problema es una deriva de
comportamiento del backend, no una razón para modificar el snapshot o inventar
un contrato local. El cliente sí necesita escoger el único flujo que funciona
de extremo a extremo.

## Drivers

- Autorizar Colección con una credencial que el backend live acepte realmente.
- Mantener un único secreto durable, sin contraseña, PII descriptiva ni
  interpretación del contenido del JWT.
- Renovar antes de que el JWT deje de ser aceptable para `/users/jwt/refresh`.
- Conservar las cercas por UUID, generación, revisión opaca de credencial y token
  exacto ante concurrencia, logout, rechazo tardío y cambio A→B.
- Preservar el logout binario, la partición usuario + manga, la outbox y el
  comportamiento local-first ya aceptados.
- No introducir fallback dual, dependencias, entitlements ni pruebas
  automatizadas contra producción.

## Opciones consideradas

1. **Mantener la sesión dual:** conserva el código existente, pero deja
   Colección permanentemente inaccesible y provoca una renovación inútil ante
   cada `401`.
2. **Adoptar el JWT único para toda la sesión:** usa un solo tipo de credencial
   para login, identidad, refresh y recursos protegidos. Exige renovación
   preventiva y una migración cerrada del envelope V2.
3. **Usar JWT único solo en Colección y conservar la sesión dual:** duplicaría
   autoridad, renovación y Keychain, y permitiría que dos identidades remotas
   divergiesen dentro del mismo proceso.
4. **Usar el login legacy:** carece de una semántica de refresh caracterizada y
   no resuelve mejor la autoridad única de sesión.

## Decisión

Se adopta la segunda opción. El JWT único es la única credencial de sesión y el
único Bearer autorizado para identidad, Colección y el resto de recursos
protegidos.

### Flujo remoto

Login ejecuta `POST /users/jwt/login` con Basic Auth, valida el DTO
`token/tokenType/expiresIn`, exige token no vacío, `tokenType == "Bearer"` y
duración positiva, y después consulta `GET /users/jwt/me` con ese mismo JWT.
Antes de llamar a `/jwt/me` vuelve a comprobar que el JWT recién emitido sigue
vigente. Solo una identidad válida y un JWT que continúe vigente al terminar
esa validación permiten persistir la sesión. La credencial debe continuar vigente
después del commit Keychain antes de publicarse; si expira durante esa escritura,
se retira condicionalmente el envelope exacto. Si esa limpieza falla, la memoria
publica `authenticationRequired` para que el siguiente login pueda sustituir de
forma explícita el registro residual, sin volver a autorizarlo.

Refresh ejecuta `POST /users/jwt/refresh` con el JWT actual como Bearer. El JWT
resultante atraviesa la misma validación de DTO, se vuelve a comprobar antes de
enviarlo y `GET /users/jwt/me` debe confirmar el mismo UUID antes de reemplazar
Keychain o autorizar otra petición.
Si el JWT expira durante esa validación suspendida, el envelope anterior no se
reemplaza. Si expira durante el reemplazo durable, el envelope nuevo se retira y
no se publica; un fallo de escritura conserva el anterior solo mientras todavía
sea válido.
El cliente no decodifica el JWT ni atribuye identidad, rol o expiración a sus
claims; la expiración absoluta se deriva exclusivamente de `expiresIn` y del
reloj inyectado al aceptar la respuesta.

### Renovación y cercas

Una credencial se renueva cuando le quedan cinco minutos o menos de vigencia.
La ventana permite completar refresh e identidad antes del vencimiento sin
depender de un instante exacto ni de sleeps. Un JWT ya expirado nunca se envía a
refresh ni a otro recurso: la sesión pasa a `authenticationRequired` y se
retira condicionalmente su envelope.

Las peticiones concurrentes comparten un único vuelo de refresh ligado a la
tupla exacta `(userID, sessionGeneration, JWT actual)`. El resultado se acepta
solo si esa autoridad y ese JWT siguen vigentes. Un vuelo residual de A no
abastece ni bloquea B; una respuesta tardía se convierte en `sessionChanged`.

Cada activación o reemplazo validado del JWT rota además una revisión opaca solo
en memoria, aunque el servidor devuelva exactamente el mismo texto y la misma
expiración. La revisión no se persiste, no se obtiene de claims y nunca sale del
proceso. Las autorizaciones de request y de commit quedan ligadas a autoridad y
revisión; comparar solo el texto del JWT no puede rehabilitar una capacidad
anterior.

Después de cualquier suspensión necesaria para resolver la credencial, el actor
revalida en el mismo turno autoridad, envelope completo, revisión opaca, JWT
rechazado, gate y expiración. Solo entonces construye la autorización Bearer,
sin otro punto de suspensión entre esa comprobación y la emisión. Tras esperar
una respuesta remota vuelve a comprobar la expiración antes de autorizar un
efecto local; si el JWT ya venció, invalida la sesión y no importa ni confirma el
resultado.
Si una recuperación A→B se reanuda cuando otro consumidor ya ha iniciado un
refresh B→C, se une al vuelo B→C antes de devolver y nunca publica B como
credencial intermedia. La construcción final rechaza igualmente una credencial
que haya empezado a ser reemplazada en ese mismo intervalo.
Las mutaciones locales obtienen igualmente su capacidad de commit desde el
actor de sesión: una expiración detectada en ese límite impide modificar
SwiftData u outbox y Cuenta reconcilia inmediatamente el snapshot
`authenticationRequired`. La capacidad conserva además la expiración vigente en
la misma gate protegida por mutex: si el JWT vence después de emitirla pero antes
de entrar en la transacción síncrona, el commit falla, vuelve al actor de sesión
para converger y tampoco aplica efectos. R1 realiza la misma revalidación cuando
su segunda cerca rechaza una importación.

Una edición local captura la `SessionAuthority` exacta al abrir el editor y la
transporta en su comando. Cuenta, la resolución de capacidad y el model actor
comparan UUID y generación completos; una sheet de A no puede escribir para una
generación B del mismo UUID. Si solo rota la revisión de credencial dentro de la
misma autoridad, la mutación todavía no iniciada puede obtener una capacidad
actual y repetir una vez su entrada al actor.

Un fallo transitorio de renovación conserva el envelope solo mientras su JWT
continúe válido al terminar el intento; si expira durante el vuelo, pasa a
`authenticationRequired`. La operación que necesitaba renovar falla y podrá
reintentarse por su política propia. Un `401` o `403` permanente de `/users/jwt/refresh`
invalida la autoridad en memoria, conduce a `authenticationRequired` e intenta
borrar el envelope exacto. Si el JWT recién emitido es rechazado por
`/users/jwt/me` o representa otro UUID, nunca sustituye el envelope anterior.

El intervalo suspendido del reemplazo Keychain del refresh es una transición
exclusiva de proceso. Mientras ese único commit durable está en curso, logout e
invalidación devuelven `transitionInProgress`; pueden reintentarse después de
que la persistencia confirme éxito o error. Así la memoria no puede publicar
`signedOut` o `authenticationRequired` mientras Keychain acaba de adoptar un JWT
renovado que esa transición todavía no conoce. La cerca se retira al reanudarse
el actor y no añade estado durable paralelo.

Logout e invalidación suspenden provisionalmente la gate, pero conservan su
revisión exacta únicamente para clasificar un rechazo ya en vuelo. El éxito la
invalida. Si el borrado falla y el JWT sigue vigente, reactivar la sesión rota la
revisión; un rechazo registrado durante la transición obliga a refresh antes de
reutilizar la credencial.

Si una limpieza Keychain falla al invalidar un JWT vencido, la sesión permanece
fail-closed como `authenticationRequired`, el envelope residual no se vuelve a
autorizar y Cuenta conserva la categoría segura del fallo para permitir un
reintento consciente. Esto también se aplica cuando un logout comenzó con una
credencial válida pero su borrado falla después de que expire: nunca se reactiva
como `.active`.

La cancelación de un consumidor no se convierte en pérdida de autenticación ni
autoriza efectos. La excepción de precedencia es cualquier fallo seguro de
persistencia Keychain ya producido por el vuelo compartido: un fallo de carga,
guardado, reemplazo o limpieza clasificado como `temporarilyUnavailable` o
`persistenceUnavailable` no se reemplaza por `CancellationError`. Ocultarlo
haría pasar por una cancelación ordinaria una autoridad durable no restaurada o
no confirmada. Cuenta puede mejorar un aviso genérico con esa causa solo mientras
coincida la autoridad exacta, incluso si la task de presentación que la entrega
ya fue cancelada. Si el envelope anterior aún es válido y el snapshot continúa
activo después de un fallo de reemplazo, Cuenta conserva la sesión y presenta el
fallo de persistencia como aviso no bloqueante.

Ante un primer `401` vigente de `GET /collection/manga`, R1 fuerza un único
refresh, revalida identidad y repite el GET una vez. Un segundo `401` después de
identidad válida conserva sesión, Keychain, colección y outbox y se clasifica
como incompatibilidad del endpoint. Un `403` de Colección representa
autorización insuficiente, no inicia refresh y tampoco borra la sesión.
Un rechazo `401/403` de `/users/jwt/me` durante el refresh preventivo que precede
al primer GET se presenta con la misma incompatibilidad segura, sin ocultarlo ni
llegar a Colección.

### Envelope Keychain V3

La única autoridad durable es un registro `kSecClassGenericPassword` V3 con:

- versión de formato;
- `sessionGeneration` opaca;
- `userID` UUID estable;
- JWT único;
- expiración absoluta.

Conserva `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, no es sincronizable,
usa un `account` fijo no identificador y no declara access group. No contiene
email, contraseña, roles, permisos, presentación ni outbox.

V1, V2, versiones desconocidas y payloads corruptos fallan cerrados, se retiran
de los namespaces conocidos y exigen un login nuevo. Ningún access o refresh V2
se reinterpreta como JWT único y no existe fallback al flujo dual.

### Garantías readoptadas

Esta decisión readopta expresamente de ADR-0006 y ADR-0018:

- contraseña efímera y ausencia de secretos en logs, UI y documentación;
- UUID y generación protegidos para restauración offline y partición local;
- una sola autoridad Keychain sin ledger paralelo;
- activación posterior al commit completo y reemplazo condicionado;
- logout local binario, reintentable y condicionado a la generación;
- invalidación linealizable frente a commits, efectos tardíos y cambio A→B;
- colección y outbox local-first, coalescencia, tombstones, resultados ambiguos
  y conflictos conforme a las SDD 03 y 04;
- frontera Deluxe cerrada mediante `SessionFence` cuando exista un consumidor
  externo real.

## Consecuencias

### Positivas

- La misma credencial validada por identidad autoriza Colección en el backend
  live.
- Keychain y la máquina de sesión se simplifican a un secreto y una expiración.
- La renovación conserva single-flight, identidad estable y protección contra
  respuestas antiguas.
- Un fallo específico de Colección ya no induce un bucle de credenciales
  válidas.

### Negativas

- El JWT debe renovarse mientras todavía es válido; una app que despierte tras
  su expiración requiere login de nuevo.
- La ventana de cinco minutos puede iniciar una petición adicional antes del
  vencimiento y debe revisarse si cambia la vigencia publicada.
- Usuarios con un envelope V2 deben iniciar sesión de nuevo una vez.
- El cliente se adapta a una deriva live que el OpenAPI todavía no reconoce;
  una corrección futura del backend requerirá reevaluar, no mezclar flujos.

## Validación

- Probar requests exactos de `/users/jwt/login`, `/users/jwt/refresh` y
  `/users/jwt/me` con loaders, tokens y respuestas sintéticos.
- Probar el borde de cinco minutos, JWT ya expirado, refresh single-flight,
  identidad distinta, rechazo permanente, JWT renovado con texto idéntico y
  fallos transitorios sin sleeps. Una recuperación A→B suspendida debe unirse a
  un reemplazo B→C ya iniciado y devolver únicamente C.
- Probar expiración después de `/jwt/me`, después de resolver una autorización,
  durante transporte y antes de una mutación local; probar también el vencimiento
  inmediato del JWT recién emitido antes de `/jwt/me`. Ningún caso emite o aplica
  efectos con el JWT vencido y Cuenta reconcilia la pérdida de autorización.
- Probar envelope V3 íntegro, V2 residual, versión desconocida, corrupción,
  indisponibilidad, reemplazo y borrado condicionado en un service aislado.
- Probar login → autorización R1 y `401` → refresh → `/jwt/me` → único retry,
  además de `403`, segundo `401` y rechazo de identidad durante autorización
  preventiva sin invalidación de una sesión todavía válida.
- Reejecutar las carreras de logout, A→B, ABA y commit linealizable, incluida la
  exclusión de logout e invalidación mientras el refresh espera su commit
  Keychain; probar además comando A frente a una generación B del mismo UUID y
  la conservación de un fallo de persistencia Keychain aunque el waiter se cancele.
- Ejecutar builds, suites y DocC con Xcode MCP y cero warnings propios. Ningún
  test automatizado alcanza producción.

## Condiciones de revisión

- El backend y el OpenAPI reconcilian de forma verificable la autorización de
  todos los recursos protegidos.
- `/users/jwt/refresh` admite tokens expirados, rota otro secreto o cambia su
  ventana de validez.
- La vigencia o la latencia operativa hacen inadecuada la ventana preventiva.
- Advanced incorpora otro proceso autorizado o una revocación remota
  transaccional.

## Especificaciones relacionadas

- [Alcance de producto y niveles](../specs/00-product-scope-and-levels.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Deluxe, watchOS y widget](../specs/05-deluxe-watch-and-widget.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)

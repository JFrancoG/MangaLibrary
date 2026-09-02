# ADR-0006: Autenticación, Keychain y sincronización

**Estado:** Superseded
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** [ADR-0019](0019-single-jwt-session-and-keychain-v3.md)
**Complementado por:** [ADR-0013: Frontera de logout Advanced y bridge Deluxe](0013-advanced-logout-and-deluxe-bridge-boundary.md)

## Contexto

El nivel Advanced incorpora una sesión remota y sincronización sin degradar la
experiencia local-first. Las credenciales y los fallos transitorios de red exigen
separar el estado de autenticación del estado persistido de la biblioteca.

## Drivers

- No persistir contraseñas ni tokens en almacenamiento no seguro.
- Mantener lectura y mutaciones locales durante desconexiones.
- Reintentar sincronización sin duplicar efectos remotos.

## Opciones consideradas

1. **JWT de acceso y refresco en Keychain con outbox local:** protege la sesión y
   tolera desconexiones, pero requiere rotación, reintentos y conflictos.
2. **Persistir sesión en `UserDefaults`:** es simple, pero no ofrece la protección
   adecuada para secretos.
3. **Bloquear mutaciones sin red:** reduce sincronización, pero contradice el
   comportamiento local-first.

## Decisión

La app persistirá exclusivamente el JWT de acceso y el JWT de refresco en
Keychain. La contraseña solo existirá durante la petición de autenticación y nunca
se guardará, registrará ni incluirá en diagnósticos. La renovación de sesión
rotará los tokens de forma coherente; cerrar sesión eliminará ambos.

Si existen operaciones pendientes, logout bloqueará nuevas mutaciones y exigirá
esperar su resolución o confirmar un descarte que restaure el último estado
confirmado. Después cancelará el coordinador de esa sesión y redactará las
proyecciones de widget y watchOS para impedir mezcla entre cuentas.

Las mutaciones se aplicarán primero al almacén local y registrarán una operación
en una outbox persistente en el mismo guardado. Un worker aislado enviará
operaciones con un UUID estable como identidad local del intento, conservará las
pendientes ante fallos recuperables y reconciliará la respuesta del servidor. El
UUID no se enviará ni se presentará como garantía de idempotencia remota salvo que
el contrato vivo lo soporte expresamente. La UI no dependerá de que ese envío
termine para reflejar el cambio local.

Tras un resultado remoto ambiguo, la recuperación no repetirá a ciegas el envío:
primero consultará y reconciliará el estado remoto mediante una operación
verificada. Solo reintentará automáticamente si el método y la semántica
caracterizados demuestran que es seguro. Si la evidencia sigue siendo
inconclusa, conservará la operación como `blockedOutcome`, sin reintentar ni
revertir, y exigirá una resolución visible conforme a la SDD. `rejected` queda
reservado a un rechazo permanente demostrado por el servidor.

## Consecuencias

### Positivas

- Los secretos persistidos quedan dentro del mecanismo de seguridad del sistema.
- La biblioteca permanece utilizable con conectividad intermitente.
- El UUID permite correlacionar reintentos y respuestas dentro de la outbox.

### Negativas

- Rotación, expiración, logout, reintentos y conflictos amplían la máquina de
  estados.
- La outbox requiere observabilidad y políticas explícitas para fallos definitivos.
- Sin soporte remoto de idempotencia, una respuesta perdida obliga a reconciliar
  antes de reintentar y puede dejar un resultado bloqueado que requiere
  resolución visible.

## Validación

- Probar login, refresco, rotación y logout sin exponer secretos en logs o
  fixtures.
- Probar la outbox sin red, tras relanzar la app y ante respuestas duplicadas,
  recuperables y definitivas.
- Probar una respuesta perdida después del envío y demostrar que no se repite la
  mutación antes de reconciliar el estado remoto.
- Probar efecto aplicado con respuesta perdida, efecto no aplicado y resultado
  todavía inconcluso, sin convertir incertidumbre en rechazo.
- Verificar que el cambio local y su operación pendiente se guardan juntos.

## Condiciones de revisión

- El contrato del servidor abandona el par de JWT o incorpora un mecanismo más
  fuerte incompatible con esta estrategia.
- Los requisitos de conflicto o colaboración superan una outbox secuencial.

## Especificaciones relacionadas

- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)

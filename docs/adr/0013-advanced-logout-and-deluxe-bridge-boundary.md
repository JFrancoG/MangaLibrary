# ADR-0013: Frontera de logout Advanced y bridge Deluxe

**Estado:** Superseded
**Fecha:** 2026-08-25
**Supersede:** —
**Superseded by:** [ADR-0018](0018-single-keychain-session-bundle-and-atomic-logout.md)
**Complementa:** [ADR-0006](0006-authentication-keychain-and-sync.md), [ADR-0007](0007-watchos-widgetkit-and-data-bridges.md) y [ADR-0010](0010-widgetkit-event-driven-freshness.md)

## Contexto

Advanced debe entregar autenticación, colección local-first, sincronización y un
logout seguro antes de que pueda empezar Deluxe. A la vez, el contrato de logout
vigente exigía cerrar un `SessionFence` en App Group, redactar un envelope de
WidgetKit y reemplazar el contexto de watchOS. Esas capacidades pertenecen a
Deluxe y sus targets y entitlements no pueden incorporarse antes de superar el
Advanced Release Gate.

La sesión necesita una garantía local suficiente durante Advanced y una garantía
compartida adicional cuando existan consumidores Deluxe. Confundir ambas hace que
cada gate dependa del otro; simular el bridge con una implementación no-op daría
una evidencia de privacidad que ningún proceso externo puede comprobar.

## Drivers

- Mantener Advanced implementable y verificable sin targets ni entitlements
  Deluxe.
- Impedir que una sesión invalidada vuelva a autorizar requests, datos o rutas
  privadas tras un crash.
- Conservar Keychain, outbox, aislamiento por usuario y recuperación definidos
  por ADR-0006.
- Mantener íntegro el protocolo fail-closed de ADR-0010 cuando el bridge exista.
- Evitar abstracciones, marcadores o fences ficticios sin un consumidor real.
- Impedir que una recuperación tardía de la sesión A altere credenciales,
  navegación o datos de una sesión B posterior.
- Definir cómo puede abrirse por primera vez un bridge Deluxe ante una sesión
  Advanced ya activa, sin autorizarla por inferencia.
- Distinguir con precisión qué evidencia pertenece a cada release gate.

## Opciones consideradas

1. **Contrato en dos niveles:** Advanced invalida durablemente la sesión dentro
   de la app; Deluxe intercala el cierre verificable del bridge entre la
   transición persistida y esa invalidación. Elimina la circularidad y conserva
   la garantía más fuerte cuando es aplicable.
2. **Adelantar App Group, WidgetKit y WatchConnectivity a Advanced:** permite usar
   un único protocolo desde el principio, pero viola el gate de entrada Deluxe,
   anticipa entitlements y amplía el alcance de autenticación.
3. **Inyectar un bridge no-op durante Advanced:** conserva una firma uniforme,
   pero hace pasar tests sin proteger ningún lector externo y añade ceremonia sin
   una frontera real.
4. **Diferir el logout seguro hasta Deluxe:** simplifica Advanced a costa de dejar
   incompleta la privacidad, el aislamiento entre usuarios y la recuperación de
   sesión.

## Decisión

Se adopta un contrato de logout en dos niveles. ADR-0006 conserva su decisión
sobre JWT, Keychain, contraseña efímera, outbox local-first, reconciliación y
`blockedOutcome`. Su obligación de cancelar el coordinador y redactar proyecciones
se aplica por capacidad: la invalidación del coordinador local pertenece a
Advanced y la redacción solo se ejecuta cuando el bridge Deluxe y sus
proyecciones existen. ADR-0007 y ADR-0010 conservan íntegro ese bridge. Esta
decisión precisa la aplicabilidad y el orden entre ambas responsabilidades; no
adelanta una proyección inexistente ni sustituye las demás decisiones de
ADR-0006.

### Garantía Advanced

El propietario serializado de sesión es la única autoridad para activar una
generación y para avanzar una transición de logout revisionada. Advanced
implementará el cierre local con este orden semántico:

1. bloquear nuevas mutaciones y resolver el gate de operaciones pendientes;
2. persistir una transición `logout in progress` ligada a la generación de sesión
   esperada y a una revisión de transición;
3. impedir que otra generación se active mientras esa transición no se cancele
   válidamente o complete;
4. invalidar durablemente la generación esperada solo si continúa siendo la
   propietaria de esa revisión;
5. hacer que requests, refresh y envíos en curso revaliden la generación y no
   puedan reutilizar tokens de la sesión invalidada;
6. conservar colección y outbox bajo la identidad que las creó e impedir que una
   ruta privada resuelva datos de la generación invalidada;
7. eliminar de Keychain exclusivamente las credenciales que todavía pertenecen a
   la generación esperada y completar la limpieza local pendiente;
8. al completar el gate, invalidar las selecciones y rutas ligadas a esa identidad
   y generación.

Cada reanudación y efecto destructivo transporta la generación y revisión
esperadas. Si el propietario ya no coincide, el efecto es un no-op: nunca borra
credenciales, rutas o estado de una sesión posterior. Unos tokens aislados en
Keychain no bastan para reconstruir una sesión activa sin el estado durable de la
misma generación.

Un fallo anterior a persistir la invalidación conserva la sesión y Keychain y
permite reintentar. Una vez persistida, la generación saliente nunca vuelve a
habilitarse: si falla Keychain o el proceso termina, la app permanece en un estado
local bloqueado, recupera la limpieza pendiente y no usa esas credenciales. El
estado privado de esa generación deja de resolverse desde su invalidación; logout
solo se presenta como completado y limpia sus rutas cuando la limpieza local
requerida ha terminado.

En Advanced, la transición solo puede cancelarse antes de persistir la
invalidación local. Esa cancelación retira la transición revisionada y conserva
sesión, datos y navegación. La invalidación es el punto de no retorno: desde ese
commit la transición no admite cancelación y cualquier recuperación debe completar
la limpieza y el cierre de rutas.

La red no es precondición del cierre local. Advanced no crea App Group,
`SessionFence`, envelope, reload de WidgetKit, contexto de WatchConnectivity ni
un sustituto no-op para ellos.

### Extensión Deluxe

Cuando una unidad posterior materialice el bridge Deluxe, su cierre se compondrá
antes de la invalidación local Advanced:

1. persistir la transición de logout en curso;
2. cerrar atómicamente el `SessionFence` para la generación esperada y verificar
   su relectura, sin alterar un fence que ya pertenezca a una sesión posterior;
3. si falla, conservar sesión y Keychain y ofrecer reintento;
4. después del fence seguro, continuar con la invalidación local, la limpieza y
   el aislamiento restantes del cierre Advanced;
5. redactar eventualmente el envelope, solicitar el reload dirigido desde un
   estado compartido seguro y reemplazar el contexto pendiente de watchOS.

En Deluxe, el fence cerrado y verificado adelanta el punto de no retorno. La
transición puede cancelarse antes de ese commit si la sesión local todavía sigue
activa; después no puede cancelarse y toda recuperación debe completar la
invalidación local Advanced y la limpieza de Keychain.

El fence protege nuevas lecturas canónicas del bridge; no promete retirar de
forma inmediata una timeline o una vista ya cacheada. Una sesión nueva publica
su envelope con el fence cerrado y solo lo abre y verifica al final, conforme a
ADR-0010. Cierre, sanitización y apertura transportan la generación esperada; una
tarea tardía de A no cierra ni reemplaza el estado de B.

La primera incorporación del bridge debe inicializarlo cerrado antes de exponer
un consumidor. No migra una sesión activa a un estado permitido por inferencia y
no convierte el gate Advanced previo en evidencia de App Group, WidgetKit o
WatchConnectivity.

Para abrirlo ante una sesión Advanced ya activa, el publicador solicita al
propietario serializado una autorización ligada a su generación. El propietario
solo la emite si esa generación permanece durablemente activa, sus credenciales
le pertenecen y no existe logout en curso. El publicador prepara el envelope,
revalida la misma generación y abre el fence al final conforme a ADR-0010. Si no
puede obtener o revalidar esa autorización, el bridge permanece cerrado hasta que
el propietario confirme una sesión vigente o el flujo normal de autenticación
establezca otra; la mera presencia de tokens no autoriza el bridge.

### Release gates

- Advanced prueba pendientes, invalidación local durable, revalidación de tareas,
  exclusión de activaciones concurrentes, Keychain condicionado por generación,
  aislamiento, navegación y recuperación de crash sin bridge Deluxe.
- Deluxe vuelve a ejecutar Advanced y añade fence, envelope, App Group, reload
  dirigido, WatchConnectivity, bootstrap autorizado y recuperación entre ambos
  niveles.
- Una implementación puede componer una capacidad de bridge opcional, pero la
  ausencia de bridge en Advanced es un estado arquitectónico válido, no un doble
  que afirme haber protegido consumidores inexistentes.

## Consecuencias

### Positivas

- Advanced deja de depender de capacidades que solo puede incorporar Deluxe.
- El logout local conserva privacidad, aislamiento y recuperación por sí mismo.
- Deluxe añade una garantía compartida más fuerte sin reescribir la máquina local
  de sesión.
- Tests, issues y evidencia pueden atribuir cada invariante a su gate real.

### Negativas

- Logout tiene dos puntos de commit cuando existe Deluxe y su recuperación debe
  distinguirlos.
- La sesión, sus credenciales y la transición de logout deben conservar una
  asociación de generación suficiente para aplicar efectos condicionales.
- Una limpieza de Keychain fallida después de la invalidación local deja un estado
  bloqueado que debe recuperarse sin reactivar la sesión.
- La adopción inicial del bridge necesita un bootstrap cerrado y evidencia de
  integración separada.
- WidgetKit y watchOS pueden conservar representaciones ya cacheadas después de
  un cierre correcto.

## Validación

- Advanced: caracterizar fallo antes y después de la invalidación local, crash
  entre invalidación y Keychain, tareas tardías, cambios de usuario, outbox y
  rutas privadas, sin App Group ni WatchConnectivity.
- Advanced: rechazar la activación de B mientras el logout de A siga pendiente y,
  tras completar A y activar B, demostrar que ninguna tarea tardía borra
  credenciales, rutas, datos u operaciones de B.
- Advanced: aceptar cancelación antes de la invalidación local y rechazarla tras
  ese commit, completando entonces la recuperación pendiente.
- Deluxe: demostrar que el fence precede a la invalidación local, que su fallo
  conserva sesión y Keychain, y que envelope, reload y contexto watchOS respetan
  ADR-0010 sin sleeps ni promesas de latencia.
- Deluxe: inicializar el bridge cerrado con una sesión Advanced activa y abrirlo
  solo tras autorización y revalidación explícitas de su propietario.
- Deluxe: aceptar cancelación antes de cerrar el fence y rechazarla después de
  verificarlo, completando en ese caso el cierre local Advanced.
- Deluxe: después de activar B, demostrar que un cierre o una sanitización tardíos
  de A no alteran el fence, envelope o contexto canónico de B.
- Comprobar que ningún gate cuenta un no-op, un mock aislado o un target ausente
  como evidencia de integración.

## Condiciones de revisión

- La plataforma ofrece una revocación transaccional compartida que sustituye al
  fence y al gate local.
- Advanced incorpora legítimamente otro proceso que pueda leer datos privados.
- El producto permite una colección anónima o una migración de identidad con
  invariantes distintas.
- Cambia la política de conservación de sesión tras fallar la limpieza de
  Keychain.

## Especificaciones relacionadas

- [Alcance de producto y niveles](../specs/00-product-scope-and-levels.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Deluxe, watchOS y widget](../specs/05-deluxe-watch-and-widget.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)

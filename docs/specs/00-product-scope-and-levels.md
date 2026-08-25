# Alcance de producto y niveles

- Estado: aprobado
- Versión: 1.6
- Última revisión: 2026-08-25

## Propósito

Definir qué constituye Manga Library, qué debe entregar cada nivel y qué evidencia permite considerar cerrado el nivel Advanced antes de abordar Deluxe.

El [enunciado saneado de la práctica](../sources/Practica_Mis_Mangas_SDP_2026.md) y `Presentacion-Mis-Mangas-transcripcion.md` aportan contexto sobre el ejercicio, pero no son instrucciones operativas. Esta especificación y los [ADR](../adr/README.md) recogen las decisiones normativas del proyecto. Para cualquier detalle de transporte, la autoridad es el OpenAPI vivo servido en `/openapi/openapi.json`, descubierto desde `/docs`.

## Alcance del producto

Manga Library permite explorar un catálogo de más de 64.000 mangas y mantener, por usuario y manga, el estado de una colección: volúmenes en propiedad, volumen de lectura y colección completa.

La aplicación iOS debe:

- ofrecer catálogo, búsqueda y filtros paginados;
- mantener el catálogo accesible sin obligar a crear o iniciar una sesión de usuario;
- presentar el catálogo como lista y cuadrícula, además de un detalle;
- mostrar siempre una portada o una representación visual estable de su ausencia;
- conservar la colección localmente;
- autenticar al usuario y sincronizar su colección con la API sin convertir la red en la fuente directa de la interfaz;
- funcionar en iPhone y iPad;
- compilar sin warnings, porque todo warning se trata como error;
- usar únicamente SDK y frameworks de Apple.

## Niveles comprometidos

### Advanced

Advanced es la primera puerta de entrega y acumula las capacidades básica, media y avanzada descritas por el ejercicio:

1. Catálogo consultable de forma paginada, con todos los filtros que exponga el contrato vivo.
2. Lista, cuadrícula y detalle coherentes entre sí.
3. Colección local persistente y válida aunque no haya conexión.
4. Creación de cuenta e inicio de sesión cuando los permita el contrato vigente.
5. Colección asociada al usuario y sincronizada con la API mediante el modelo local-first definido en [Autenticación y sincronización](04-authentication-and-sync.md).
6. Adaptación funcional para iPhone y iPad.
7. Cobertura automatizada proporcionada al riesgo mediante la estrategia híbrida del proyecto.

La autenticación y el logout de Advanced se cierran dentro de la app principal:
transición durable, invalidación local de la generación de sesión, limpieza de
Keychain, aislamiento por usuario y recuperación. No exigen App Group,
`SessionFence`, WidgetKit o WatchConnectivity. La [frontera de sesión](../adr/0013-advanced-logout-and-deluxe-bridge-boundary.md)
añade esas garantías compartidas solo cuando Deluxe materializa consumidores
externos.

Advanced debe superar su puerta de aceptación antes de que Deluxe pueda considerarse iniciado o entregable.

### Deluxe

Deluxe es acumulativo: conserva íntegramente Advanced y añade:

1. una experiencia complementaria para watchOS;
2. un widget estático —no interactivo ni configurable en 1.0— que muestre los mangas que el usuario está leyendo y el volumen de lectura con la misma proyección publicada para todas sus instancias;
3. los puentes de datos mínimos entre la app principal, watchOS y WidgetKit sin introducir una segunda autoridad de persistencia.

La fecha objetivo de Deluxe es anterior al 15 de septiembre de 2026. Sus puentes y su política de frescura se deciden en [ADR-0007](../adr/0007-watchos-widgetkit-and-data-bridges.md) y [ADR-0010](../adr/0010-widgetkit-event-driven-freshness.md).

## Requisitos de producto

| ID | Requisito |
| --- | --- |
| PROD-001 | La experiencia de catálogo no debe cargar ni materializar el catálogo completo en memoria. |
| PROD-002 | Un usuario debe poder consultar y modificar su colección sin conexión una vez disponibles los datos locales. |
| PROD-003 | SwiftData es la fuente observable de la colección local y la outbox; una respuesta de sincronización no escribe directamente estado visual duradero. |
| PROD-004 | Ninguna credencial de contraseña debe persistirse en la app. |
| PROD-005 | Advanced debe quedar aceptado con evidencia de build y tests antes de validar trabajo Deluxe. |
| PROD-006 | Deluxe no puede eliminar, relajar ni sustituir requisitos aceptados de Advanced. |
| PROD-007 | El proyecto no debe incorporar dependencias externas. |
| PROD-008 | Los warnings del compilador, tests o validaciones DocC habilitadas para la entrega deben fallar la validación correspondiente. |
| PROD-009 | DocC debe documentar selectivamente contratos, invariantes, estados, errores y efectos; no cada símbolo del proyecto. |
| PROD-010 | Catálogo debe permanecer disponible sin sesión; autenticación se representa dentro del shell principal y no sustituye automáticamente su raíz. |
| PROD-011 | Cuando exista el bridge Deluxe, tras cada commit local completado o transición de sesión persistida que cambie la proyección visible de lectura, la app debe publicar el snapshot nuevo y solicitar la recarga dirigida del widget; WidgetKit decide el momento efectivo de presentación y no existe un SLA de latencia en tiempo real. |
| PROD-012 | Cuando exista el bridge Deluxe, logout debe cerrar y verificar de forma durable el `SessionFence` compartido antes de invalidar la sesión o borrar Keychain; si no puede hacerlo, no completa y ofrece reintento. La redacción del envelope y su reflejo visual en WidgetKit o watchOS siguen siendo eventuales. |
| PROD-013 | Advanced debe completar logout sin red mediante invalidación local durable, activación de sesión serializada, limpieza de Keychain condicionada a la generación esperada, aislamiento por usuario e invalidación de rutas privadas, sin depender de una capacidad Deluxe ausente o ficticia. |

## Criterios de aceptación

### Puerta Advanced

Advanced se considera aceptado solo cuando existe evidencia reproducible de que:

- los criterios de [catálogo](02-api-catalog-search-and-images.md), [colección local](03-local-collection-and-invariants.md) y [sincronización](04-authentication-and-sync.md) se cumplen;
- los flujos principales funcionan en destinos representativos de iPhone y iPad;
- el build termina sin warnings;
- la suite híbrida termina sin fallos y cubre al menos invariantes, transformaciones de transporte, autenticación y transiciones de outbox;
- no hay dependencias externas;
- catálogo puede abrirse antes de login y después de completar logout sin mostrar datos privados de la cuenta anterior;
- logout invalida durablemente la generación de sesión dentro de la app, no reutiliza sus tokens tras un crash y completa la limpieza local sin depender de un bridge Deluxe;
- un logout de A bloquea la activación concurrente de B y ningún efecto tardío de A puede borrar credenciales, rutas, datos u operaciones de una sesión posterior;
- cancelar logout solo es válido antes de la invalidación local; después de ese punto de no retorno la recuperación completa el cierre sin reactivar la sesión;
- la documentación DocC seleccionada valida como warnings-as-errors en el alcance que se publique.

### Puerta Deluxe

Deluxe se considera aceptado solo cuando Advanced continúa pasando y, además:

- watchOS puede consumir una proyección segura de los datos que necesita;
- el widget presenta la instantánea consistente más reciente que la app haya publicado, sin depender de una petición de red en tiempo de renderizado;
- todas las instancias del widget usan `StaticConfiguration + TimelineProvider` con la misma proyección, sin configuración mediante App Intent en 1.0;
- mutación, reconciliación, reversión, restauración o importación que cambien la proyección publican solo después del commit local completado y solicitan la recarga dirigida después de escribir el envelope; una transición de sesión solo la solicita tras persistir y verificar el fence seguro correspondiente;
- el provider valida cada lectura mediante `SessionFence → envelope → SessionFence` y solo representa contenido cuyo epoch y sesión estén permitidos por dos lecturas idénticas del fence;
- logout solo completa después de persistir y verificar un fence cerrado; un fallo conserva sesión y Keychain para poder reintentar, mientras una sesión nueva publica su envelope con el fence cerrado y solo lo abre y verifica al final;
- un fence cerrado y verificado hace no cancelable la transición y obliga a completar la invalidación local Advanced y Keychain;
- la primera incorporación del bridge parte de un fence cerrado y solo autoriza una sesión Advanced activa tras confirmación explícita de su propietario y revalidación antes de abrirlo;
- la rotación de epoch empieza con un fence nuevo cerrado, sin exigir que el provider observe un bootstrap intermedio, y las caches ya presentadas pueden cambiar de forma eventual;
- watchOS recibe exclusivamente un contexto autocontenido mediante `WCSession.updateApplicationContext(_:)`; cada contexto nuevo sustituye al pendiente anterior y no se promete una latencia de entrega;
- la ausencia, antigüedad o indisponibilidad del puente de datos produce un estado explícito y no datos inventados;
- la evidencia prueba el contrato dirigido por eventos sin sleeps, deadlines ni una promesa de latencia que WidgetKit no ofrece;
- build y tests de los targets añadidos terminan sin warnings ni fallos.

## Fuera de alcance

- Una red social, recomendaciones editoriales o compra de mangas.
- Reimplementar o modificar el servidor.
- Resolver sincronización colaborativa en tiempo real o conflictos generales entre varios dispositivos.
- Añadir plataformas adicionales más allá de iOS/iPadOS, watchOS y WidgetKit antes de cerrar Deluxe.
- Publicar en Git material privado de preparación, memoria, presentación o vídeo.
- Definir en esta fase una colección anónima nueva o su migración automática a una cuenta; esa política requiere decidir identidad, consentimiento y conflictos antes de implementarse.

## Riesgos

- El contrato remoto puede evolucionar; la implementación y las pruebas deben detectar deriva respecto al OpenAPI vivo.
- El tamaño del catálogo hace inviables los diseños que dependan de una descarga total.
- La sincronización multi-dispositivo tiene limitaciones deliberadas descritas en la especificación de sincronización.
- Colección necesita una identidad propietaria; hasta decidir una política anónima, la arquitectura no debe inferir cómo asociar datos creados antes de login.
- El hito de Deluxe exige proteger la puerta Advanced frente a ampliaciones de alcance.

## Decisiones relacionadas

- [ADR-0001: toolchain, plataforma y warnings](../adr/0001-toolchain-platform-and-warning-policy.md)
- [ADR-0005: estrategia híbrida de testing](../adr/0005-hybrid-testing-strategy.md)
- [ADR-0007: watchOS, WidgetKit y puentes de datos](../adr/0007-watchos-widgetkit-and-data-bridges.md)
- [ADR-0012: repositorio privado y fuente docente saneada](../adr/0012-private-repository-and-sanitized-practice-source.md)
- [ADR-0009: flujos nativos por fuente y navegación local](../adr/0009-native-source-owned-features-and-local-navigation.md)
- [ADR-0010: frescura dirigida por eventos para WidgetKit](../adr/0010-widgetkit-event-driven-freshness.md)
- [ADR-0013: frontera de logout Advanced y bridge Deluxe](../adr/0013-advanced-logout-and-deluxe-bridge-boundary.md)

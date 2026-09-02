# SDD 05: Deluxe, watchOS y widget

**Estado:** Aprobada
**Versión:** 1.6
**Fecha:** 2026-09-02
**Gate de entrada:** Advanced Release Gate superado

## Propósito

Definir el incremento Deluxe sin convertirlo en una segunda aplicación completa. Deluxe acumula los niveles Básico, Medio y Avanzado: no puede compensar una carencia de los niveles anteriores.

## Alcance

Deluxe añade dos superficies de solo lectura:

- un widget estático —no interactivo— de WidgetKit para iPhone y iPad, en familias pequeña y mediana;
- una aplicación companion para watchOS que muestra mangas en lectura y su progreso.

La aplicación principal continúa siendo la única superficie con autenticación, catálogo, edición de colección y sincronización.

El widget 1.0 usará `StaticConfiguration` con un `TimelineProvider`. Todas sus instancias consumirán la misma proyección del mismo `kind`; no habrá `AppIntentConfiguration`, `AppIntentTimelineProvider`, selección por manga ni personalización por instancia.

## Entrada desde Advanced

Advanced entrega una sesión cuya única autoridad durable es un envelope V3 en
Keychain y un logout binario por borrado, sin ledger, revisiones durables, fases
de sesión, App Group, `SessionFence`, WidgetKit o WatchConnectivity. La revisión
opaca de credencial de Advanced vive solo en memoria y no constituye una segunda
autoridad. Esa evidencia no
acredita el bridge Deluxe. La primera unidad que lo materialice debe inicializar
el fence cerrado antes de exponer cualquier consumidor y no puede inferir que una
sesión ya activa esté autorizada para el nuevo bridge.

Ante una sesión Advanced ya activa, el publicador solo puede abrir el bridge tras
obtener del propietario serializado una autorización ligada a la generación del
envelope Keychain V3 vigente y sin logout en curso. Después publica el envelope,
revalida esa misma generación y abre el fence al final. Si la autorización falta o
deja de ser válida, el bridge sigue cerrado hasta que el propietario confirme una
sesión vigente o el flujo normal de autenticación establezca otra. Un token suelto,
un formato desconocido o el estado efímero `authenticationRequired` no autorizan
el bridge.

Desde que el bridge existe, logout cierra y verifica el `SessionFence` y solo
después elimina condicionalmente el bundle Keychain de la generación esperada. El
fence cerrado es el punto de no retorno durable de Deluxe; no se reintroduce un
ledger privado de sesión. El envelope redactado, el reload y la entrega a watchOS
quedan como efectos eventuales. No se introduce un bridge no-op en Advanced. La
frontera completa se define en
[ADR-0019](../adr/0019-single-jwt-session-and-keychain-v3.md).

## Snapshot de lectura

La aplicación principal publicará un valor inmutable `Codable & Sendable` y versionado con la información mínima necesaria para representar mangas en lectura:

- identificador estable del manga;
- título de presentación;
- referencia opaca a una portada local opcional;
- tomo de lectura;
- total de tomos conocido, cuando exista;
- `sessionGeneration` opaca y aleatoria, sin identidad de usuario;
- `publicationGeneration` opaca y aleatoria que identifica el epoch del publicador, separada de la sesión;
- `revision` `UInt64`, estrictamente monotónica dentro de ese epoch y persistida entre sesiones;
- estado explícito de contenido, vacío, redacción o no disponible;
- instante de generación con semántica exclusivamente informativa;
- versión del formato.

El snapshot no contendrá tokens, credenciales, correo, identificadores de cuenta ni estado de la outbox. Una versión desconocida se rechazará de forma segura y producirá un estado no disponible, nunca una colección aparentemente vacía ni una interpretación parcial.

La app tendrá un único publicador serializado, propietario del envelope y del fence, para asignar orden, preparar recursos y efectuar sus reemplazos. `publicationGeneration` se persiste como epoch del publicador y `revision` se incrementa de forma estrictamente monotónica entre sesiones dentro de ese epoch. Cada revisión se reserva y persiste antes del reemplazo; no hace wrap, no se reutiliza y puede contener huecos si una publicación reservada falla.

### SessionFence compartido

El App Group contendrá, separado del envelope, un `SessionFence` mínimo, versionado y reemplazado atómicamente con:

- versión de formato;
- `publicationGeneration` vigente;
- `fenceRevision: UInt64`, monotónica dentro del epoch y distinta en cada sustitución del fence para detectar una lectura concurrente;
- `allowedSessionGeneration`, opcional: `nil` cierra el bridge y otro valor permite únicamente esa sesión.

El provider leerá `fence inicial → envelope → fence final`. Solo aceptará contenido o vacío si ambos fences son íntegros e idénticos y el envelope pertenece a la `publicationGeneration` y `sessionGeneration` permitidas. Un fence ausente, corrupto, cambiado durante la lectura o cerrado produce redacción o no disponible; nunca reutiliza el envelope como fallback.

Los consumidores aplicarán estas reglas:

- dentro de la misma `publicationGeneration`, una revisión igual o anterior se ignora; las revisiones de epochs distintos no se comparan numéricamente;
- una redacción solo retira contenido de la `sessionGeneration` a la que pertenece;
- contenido de una sesión nueva solo se vuelve elegible cuando su envelope ya está publicado y el fence se abre expresamente para ella;
- una redacción antigua de la sesión A no puede borrar contenido posterior de la sesión B;
- contenido tardío de A no puede reaparecer después de activar B;
- una entrega repetida o fuera de orden no vuelve a mostrar una proyección retirada.

El publicador distinguirá dos comandos. Un comando de contenido captura la `sessionGeneration` que espera activa y la revalida justo antes de reemplazar el envelope y antes de abrir el fence. Una sanitización de A no depende de que A siga activa: actúa si el bridge todavía permite A, es idempotente si el fence ya está cerrado y es no-op si el fence permite B. Así, una tarea tardía de A nunca publica contenido vencido ni cierra o sustituye la sesión posterior.

La pérdida o corrupción del epoch o de sus contadores persistidos, una reinstalación detectada o el intento de incrementar `UInt64.max` rotan a una `publicationGeneration` nueva; las revisiones nunca vuelven a cero dentro del mismo epoch ni desbordan. La rotación publica y verifica primero un fence cerrado del epoch nuevo, después prepara su contenido y finalmente abre y verifica el fence para la sesión autorizada. El provider consulta el estado canónico actual y no necesita haber observado un bootstrap intermedio. Los consumidores no comparan numéricamente revisiones de epochs distintos.

Antes del reemplazo, el publicador persistirá intención suficiente para recuperar un crash. Al arrancar, una revisión reservada pero no publicada seguirá consumida; si el envelope ya quedó publicado pero faltó solicitar reload, la app repetirá la solicitud dirigida sin crear una publicación nueva.

El instante de generación será informativo y no se usará para ordenar ni resolver conflictos.

### Portadas locales

La referencia de portada no será una ruta absoluta ni una URL remota. Cada recurso será inmutable y tendrá un nombre content-addressed o ligado a `publicationGeneration` y `revision`; nunca se sobrescribirá un nombre ya referenciado. La app validará y escribirá atómicamente el recurso local antes de publicar el envelope, que actúa como manifest y último punto de publicación.

Los recursos de todo manifest todavía retenido o legible se conservarán. La limpieza de versiones anteriores ocurrirá después de publicar, solo sobre recursos que ya no estén referenciados según la política de retención, y su fallo no invalidará el manifest vigente. Una referencia ausente, inválida, corrupta o cuyo recurso no pueda leerse produce el placeholder accesible sin invalidar el resto del snapshot. Cualquier otro consumidor usará la portada únicamente si dispone de su propia copia local.

## Frescura dirigida por eventos

En este producto, «tiempo real» significa que la app publica por evento el último estado local persistido y solicita después su presentación; no significa ejecución continua del widget ni un plazo máximo de actualización.

La publicación se activa cuando cualquiera de estos eventos cambia la proyección visible:

- una mutación local de lectura completa su commit;
- una reconciliación remota persiste un estado local distinto;
- un rechazo o resolución persiste una reversión local;
- el arranque, la restauración o una importación persiste una proyección mostrable;
- logout, bloqueo o invalidación cambia la sesión permitida por el fence y exige redacción.

Para cada evento ordinario de contenido, la app debe respetar este orden:

1. completar el commit local visible;
2. serializar la publicación, reservar y persistir epoch/revisión y derivar el envelope;
3. preparar atómicamente cualquier portada inmutable necesaria;
4. revalidar la `sessionGeneration` esperada inmediatamente antes de publicar;
5. reemplazar atómicamente el envelope del App Group;
6. solo tras una escritura satisfactoria y segura, llamar a `reloadTimelines(ofKind:)` con el `kind` concreto afectado.

Un fallo anterior al commit no publica. En una publicación ordinaria, un fallo de serialización, portada o envelope conserva el último snapshot válido de la misma sesión todavía vigente, retiene sus recursos y suprime la solicitud de recarga.

### Transiciones de sesión fail-closed

Logout debe escribir y releer satisfactoriamente un fence cerrado —`allowedSessionGeneration == nil`— antes de borrar el bundle Keychain. Si esa escritura o verificación falla, logout no completa: conserva sesión y credenciales y ofrece reintento. La app no sustituye esta garantía por un ledger o marcador privado que la extensión no pueda consultar.

La transición Deluxe puede cancelarse antes de cerrar y verificar el fence si la
sesión local continúa activa. El fence seguro es su punto de no retorno: después,
una cancelación se rechaza y la recuperación debe completar el borrado condicional
del bundle Keychain y la redacción compartida.

Después de verificar el fence cerrado, la app elimina de Keychain únicamente el bundle de la generación esperada. El envelope redactado y la solicitud de reload pueden completarse de forma eventual; cualquier reload se solicita únicamente desde un estado compartido seguro. El propio fence cerrado y el bundle todavía presente antes de borrarlo aportan información suficiente para que un crash entre fence, Keychain y envelope se recupere sin volver a permitir la sesión saliente.

Una sesión B se activa para el bridge en orden inverso al cierre: con el fence cerrado, la app prepara recursos y publica el envelope de B; revalida que B siga activa; abre y verifica el fence para B al final; y solo entonces solicita el reload. Un crash antes de abrirlo mantiene el bridge cerrado. La misma secuencia se usa tras rotar `publicationGeneration`, sin exigir que el provider observe el estado intermedio.

Esta garantía protege las lecturas nuevas del bridge canónico, no invalida una vista que WidgetKit o watchOS ya hayan cacheado. Ambas superficies son eventuales y no se promete retirada visual instantánea.

## WidgetKit

- La app y la extensión compartirán mediante App Group solo el envelope, su `SessionFence` y las portadas locales inmutables que aquel referencie.
- El widget no abrirá el store SwiftData, no accederá a Keychain y no ejecutará red, sincronización ni polling.
- `TimelineProvider` aplicará la doble lectura `SessionFence → envelope → SessionFence`, construirá la timeline solo desde un snapshot permitido y usará la política `.never`; la app solicitará la recarga con `reloadTimelines(ofKind:)` para el `kind` concreto afectado y no usará `reloadAllTimelines()` para este flujo.
- Todas las instancias representan la misma proyección; no se consultan App Intents ni preferencias por instancia.
- La timeline representará datos disponibles, estado vacío y sesión no disponible. La solicitud de recarga no es una garantía de latencia: WidgetKit decide cuándo pide y presenta la timeline nueva.
- La extensión no usará ActivityKit, WidgetKit push ni `BGTask` para intentar forzar frescura en la versión 1.0.
- Al invalidar una sesión, un fence cerrado obliga al provider a degradar a redacción o no disponible aunque el envelope anterior siga legible; una timeline cacheada puede seguir visible hasta que WidgetKit procese el reload.
- La portada tendrá placeholder y texto accesible; la lectura seguirá siendo comprensible sin imagen.

## Companion watchOS

- El canal canónico será exclusivamente `WCSession.updateApplicationContext(_:)`; cada contexto será un diccionario versionado y autocontenido que sustituirá el contexto pendiente anterior. App Group no se usará como transporte entre dispositivos.
- El reloj conservará localmente el último snapshot compatible para lectura sin conexión y usará placeholder si no dispone localmente de la portada referenciada.
- La interfaz será de solo lectura: no habrá login, búsqueda, filtros, alta, edición ni borrado de colección.
- El receptor aplicará `publicationGeneration`, `revision` y `sessionGeneration` para ser idempotente; un contexto de epoch nuevo sustituirá la cache anterior sin exigir que el reloj haya observado un bootstrap separado.
- `transferUserInfo`, `transferFile` y `sendMessage` no serán canales canónicos de esta proyección en 1.0.
- Al invalidar una sesión, el iPhone reemplazará el contexto pendiente por una redacción autocontenida. El reloj eliminará los datos mostrables cuando la reciba, sin que esa entrega eventual bloquee logout.

## Estados visibles

Widget y reloj distinguirán al menos:

1. sin snapshot, fence no permitido o formato no disponible;
2. sesión redactada;
3. colección sin mangas en lectura;
4. contenido disponible;
5. datos temporalmente no actualizables, conservando únicamente un snapshot de la misma sesión todavía válida.

La fecha informativa puede comunicar la antigüedad del snapshot, pero no se usará para ordenarlo ni para afirmar que el dato se presentó dentro de un plazo. No se mostrará un error técnico sin una acción útil para la persona usuaria.

## Criterios de aceptación

- Advanced ha superado su Release Gate antes de incorporar targets Deluxe.
- Las familias pequeña y mediana muestran manga, tomo actual y progreso comprensible sin ofrecer edición desde el widget.
- El widget usa `StaticConfiguration + TimelineProvider`; todas sus instancias muestran la misma proyección y 1.0 no contiene `AppIntentConfiguration` ni configuración por instancia.
- El snapshot es `Codable & Sendable` y separa `sessionGeneration`, `publicationGeneration` y `revision`.
- El `SessionFence` versionado separa `publicationGeneration`, `fenceRevision: UInt64` y `allowedSessionGeneration`; el provider solo acepta contenido o vacío tras dos lecturas idénticas que permitan el epoch y sesión del envelope.
- Una mutación, reconciliación, reversión, restauración, importación o redacción relevante publica únicamente después de su commit local completado o fence seguro verificado.
- El publicador serializado revalida la sesión antes del reemplazo; un evento sin cambio visible no incrementa la revisión ni solicita reload.
- `revision` es `UInt64`, estrictamente monotónica y persistida dentro de su epoch, no hace wrap; pérdida, corrupción, reinstalación u overflow rotan `publicationGeneration` y empiezan con un fence nuevo cerrado, sin depender de observar un bootstrap.
- En una publicación ordinaria, recursos y envelope terminan antes del reload; un fallo conserva el manifest anterior de la misma sesión válida y no solicita reload.
- Logout cierra y verifica el fence antes de borrar condicionalmente el bundle Keychain; un fallo aborta el logout y conserva ambos para reintentar, mientras un crash posterior se recupera sin reabrir A.
- Cancelar solo es válido antes del fence cerrado y verificado; después de ese punto de no retorno la recuperación completa el borrado Keychain y la redacción compartida.
- Una sesión B publica su envelope con el fence cerrado y solo lo abre al final; una sanitización tardía de A es no-op si B ya posee el fence.
- La primera incorporación del bridge empieza cerrada; una sesión Advanced activa solo lo abre tras autorización y revalidación explícitas de su generación por el propietario de sesión.
- El provider usa `.never` y la app invoca `reloadTimelines(ofKind:)` con el `kind` concreto afectado, sin `reloadAllTimelines()`.
- El widget funciona sin abrir SwiftData o Keychain y sin ejecutar red, polling, ActivityKit, WidgetKit push ni `BGTask`.
- Las portadas son inmutables, content-addressed o ligadas a revisión, se escriben atómicamente antes del envelope y se retienen mientras un manifest válido pueda referenciarlas; una ausencia produce placeholder sin red.
- El reloj recibe un contexto autocontenido solo mediante `WCSession.updateApplicationContext(_:)`, cuyo reemplazo de contexto pendiente y cache local permiten seguir siendo útil sin conexión.
- El cierre o bloqueo de sesión protege el bridge canónico y reemplaza el contexto pendiente del reloj por la redacción, pero WidgetKit o watchOS pueden conservar cache anterior hasta una entrega eventual.
- Serialización, compatibilidad, epoch/revisión, doble lectura del fence, fallo del fence, crash entre fence/Keychain/envelope, escritura atómica, portadas, reloj no alcanzable, contexto reemplazado y contenido A tardío tras B tienen tests deterministas sin sleeps ni deadlines.
- Las superficies soportan Dynamic Type, VoiceOver y placeholders de portada.
- El Deluxe Release Gate reúne aplicación, widget, watchOS y documentación sin warnings.

## Fuera de alcance para 1.0

- autenticación o edición independiente en watchOS;
- widgets interactivos o intentos de escritura;
- `AppIntentConfiguration`, selección de manga o configuración distinta por instancia;
- complicaciones de reloj;
- CloudKit como transporte;
- compartir directamente un store SwiftData con el widget;
- una garantía de actualización en tiempo real con latencia máxima;
- polling, recargas periódicas, WidgetKit push, ActivityKit o Live Activities para esta proyección;
- usar `BGTask` para forzar la actualización del widget.

## Riesgos y revisión

App Group y WatchConnectivity requieren entitlements y pruebas de integración en entornos autorizados; una prueba en memoria no demuestra su configuración real. WidgetKit conserva autoridad sobre el momento efectivo de recarga y WatchConnectivity sobre la oportunidad de entrega, por lo que la evidencia prueba el orden causal y el estado canónico, no una latencia de presentación o redacción visual. Epoch, fence y retención de portadas elevan el coste de recuperación y deben permanecer centralizados. La decisión se revisará si el SDK cambia el modelo de transferencia, si el producto exige configuración o edición desde superficies Deluxe o si el snapshot deja de ser suficiente.

## Decisiones relacionadas

- [ADR 0007: watchOS, WidgetKit y puentes de datos](../adr/0007-watchos-widgetkit-and-data-bridges.md)
- [ADR 0010: frescura dirigida por eventos para WidgetKit](../adr/0010-widgetkit-event-driven-freshness.md)
- [ADR 0018: bundle único de sesión en Keychain y logout atómico](../adr/0018-single-keychain-session-bundle-and-atomic-logout.md)
- [ADR 0019: JWT único de sesión y envelope Keychain V3](../adr/0019-single-jwt-session-and-keychain-v3.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [Autenticación y sincronización](04-authentication-and-sync.md)
- [Testing, calidad y accesibilidad](06-testing-quality-and-accessibility.md)

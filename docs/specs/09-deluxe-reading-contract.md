# SDD 09: Contrato de lectura Deluxe — DX1–DX5

**Estado:** Aprobada por el propietario el 2026-09-06; ampliaciones de rotación, tamaño grande, colección mediana y prioridad de altas locales autorizadas el 2026-09-07; texto e ilustración de no disponible y traslado de la prueba física anterior al primer desbloqueo a DX6 aprobados el 2026-09-08; implementación y posterior entrega de DX5 autorizadas el 2026-09-10; DX5 entregada mediante PR #87 ese mismo día. DX6 en curso; entrega del proyecto con validación física de Watch diferida aprobada el 2026-09-10, con los límites de SDD 06 v1.38
**Versión:** 1.19
**Fecha:** 2026-09-11
**Tracker:** [DX1 — issue #78](https://github.com/JFrancoG/MangaLibrary/issues/78), [DX2 — issue #79](https://github.com/JFrancoG/MangaLibrary/issues/79), [DX3 — issue #82](https://github.com/JFrancoG/MangaLibrary/issues/82), [DX4 — issue #84](https://github.com/JFrancoG/MangaLibrary/issues/84), [DX5 — issue #86](https://github.com/JFrancoG/MangaLibrary/issues/86) y [DX6 — issue #88](https://github.com/JFrancoG/MangaLibrary/issues/88), hijos del [plan aprobado #77](https://github.com/JFrancoG/MangaLibrary/issues/77)

## Alcance y aprobación

El propietario aprobó el plan DX1–DX7 y después el contrato concreto DX1 el
6 de septiembre de 2026. Este documento complementa la SDD 05 v1.9 con las
decisiones que deberán cumplir las siguientes subfases. La autorización posterior
del propietario para implementar DX4 materializa el target WidgetKit, su App Group
y la conexión al ciclo de vida. El 10 de septiembre autoriza abrir issue y rama
e implementar DX5, incluido el companion watchOS existente en el plan.
Conserva la arquitectura de
snapshots de ADR 0007/0022 (este último incorpora y supersede ADR-0021, sucesor de ADR-0010) y la autoridad Keychain V3 de ADR 0019; no necesita una
nueva capa de persistencia de Colección ni otro ledger de sesión.

El 2026-09-10 autoriza también iniciar DX6 y, posteriormente, permite entregar
el proyecto con la validación física de Watch pendiente para después de esa
entrega, según [SDD 06 v1.38](06-testing-quality-and-accessibility.md#entrega-del-proyecto-con-validación-física-de-watch-diferida).
La decisión cambia cuándo debe obtenerse esa evidencia, sin aprobarla ni alterar
el contrato del companion. No aplaza H01 del iPhone ni otros criterios y no
autoriza por sí sola acciones de entrega Git/GitHub, publicación o inicio de DX7.

La autorización posterior para avanzar a DX2 concreta el almacenamiento y la
recuperación ya exigidos. Esta revisión materializa codec, publicador y conexión
opcional al propietario de sesión con directorios aislados. La composición live,
App Group y consumidores conservan sus subfases. La autorización de DX3.4 añade
eventos de commits reales y activación de sesión a una composición aislada, sin
conectar todavía el bridge al lanzamiento de producto.

| Decisión | Contrato aprobado | Motivo |
| --- | --- | --- |
| En lectura | Entrada activa del usuario autorizado con tomo actual informado, incluido el último | Deriva de COL-020–023; propiedad y lectura son distintas. |
| Orden | Título de presentación normalizado, desempate por `mangaID`; títulos ausentes al final | Reconocible sin inventar fecha de última lectura; la selección conserva ese orden; WidgetKit puede empezar la ventana por la prioridad de presentación. |
| Capacidad visible | Pequeño: 1 lectura; mediano: 1 manga de Colección; grande: hasta 6 lecturas; reloj: lista desplazable del snapshot de lectura recibido | La familia elige la proyección dentro del mismo kind. |
| Contexto | JSON UTF-8 dentro de un único `Data`; máximo 32 KiB del diccionario completo codificado como binary plist | Presupuesto propio de trabajo/memoria, no límite oficial de Apple. |
| Más lecturas | Selección que quepa y cantidad total elegible; prefijo canónico con prioridad de inclusión para la lectura editada; indicar cuántas quedan en iPhone | Evitar una colección aparentemente completa cuando hay recorte. |
| Portadas | JPEG de hasta 384 px de lado mayor y 64 KiB; admisión total de 8 MiB | Recurso opcional; el progreso sigue legible sin imagen. |
| Retención inicial | No eliminar automáticamente portadas publicadas; limpiar solo huérfanos demostrados; agotada la cuota, las nuevas usan placeholder | Conserva cualquier referencia aún legible sin inventar TTL o acuses de WidgetKit. |
| Reloj | Texto/progreso y placeholder; sin transferir binarios de portada en 1.0 | App Group no cruza dispositivos y no se añade otro canal. |
| Plataforma | Widget iOS 27; companion watchOS 27 | Coincide con los SDK presentes; configuración e integración se verifican en su subfase. |

El orden aprobado es por título. La alternativa por `mangaID`, como en Colección,
no se adopta para Deluxe. Ordenar por «última lectura»
requeriría un dato que hoy no existe: ni la secuencia por pareja de outbox ni los
cambios de propiedad miden esa actividad. El orden Deluxe no modifica el orden
actual de la pantalla Colección.

## Selección, título y progreso

La consulta se ejecuta dentro del propietario de persistencia para la identidad
autorizada. Primero excluye otras identidades y tombstones; después selecciona
`readingVolume != nil`. `ownedVolumes` e `isComplete` no seleccionan ni ordenan
la proyección. Vaciar el tomo de lectura lo retira de la proyección de lecturas; permanece en «Mi colección» mientras la entrada siga activa.

La proyección valida `readingVolume` y `knownTotalVolumes` contra `1...300` y
COL-022. No recorta un dato histórico inválido ni lo elimina silenciosamente:
falla la preparación ordinaria y conserva únicamente el último manifest válido
de la misma sesión todavía autorizada. Sin manifest permitido se muestra no
disponible. Una entrada inválida no se transforma en colección vacía.

- Total conocido: texto «Tomo N de T» / «Volume N of T»; el pequeño usa «Tomo N/T» / «Volume N/T».
- Total desconocido: «Tomo N · Total desconocido» / «Volume N · Total unknown»;
  el pequeño usa «Tomo N» / «Volume N». Conserva una etiqueta accesible completa, sin denominador, porcentaje o barra determinada inventados.
- `N == T` permanece visible. El dato indica tomo actual, no tomos terminados;
  no se presenta «Completado» ni «100 % leído». El texto satisface el progreso
  de 1.0; cualquier gráfico posterior deberá expresar posición, no finalización.
- Título: principal persistido en `mangaSnapshot`, sin sustituirlo por otra
  traducción editorial. Sin snapshot o sin título útil, `title == null`; cada
  consumidor localiza «Manga #ID». No se congela el idioma del iPhone en el wire.
- La portada ausente, incompatible o inaccesible solo produce placeholder; no
  invalida la lectura o el título.

La representación de título recorta whitespace/newlines exteriores. Si supera
512 bytes UTF-8, conserva el mayor prefijo de `Character` completos que, seguido
de `…`, quepa en 512 bytes. Es una abreviación de presentación; el título
persistido no cambia. Un título vacío tras normalizar se representa como `null`.

Para ordenar, la app obtiene del título de presentación una clave mediante
normalización canónica y `folding` de mayúsculas, diacríticos y anchura con locale
fijo `en_US_POSIX`; compara lexicográficamente sus bytes UTF-8 y desempata por
`mangaID` ascendente. Las claves ausentes van después de las presentes. No se
transporta la clave ni se vuelve a ordenar en el reloj; cambiar idioma no altera
la selección publicada. El contrato se caracteriza con ejemplos al implementar el proyector.

El widget grande puede reducir de 6 hasta 1 elementos si el espacio disponible o Dynamic Type impiden representar el siguiente completo. El mediano representa una ficha de la proyección de colección definida abajo. Se conserva la ventana circular contigua de cada slot; nunca se omite un elemento intermedio. El contador localizado usa `totalEligibleCount - visibleItems.count`,
tanto por tamaño como por límite de transporte. El reloj usa el mismo cálculo
con todos los elementos recibidos. No se introduce navegación o deep link nuevo
en DX1.

DX4 mantiene el texto de lectura como contenido esencial. En tamaños Dynamic Type
de accesibilidad oculta las portadas decorativas, sin limitar el tamaño del texto.
El contador y la fecha pueden usar una forma visual breve conservando etiquetas
accesibles completas. La extensión prepara únicamente la unión de portadas necesarias para las trece entradas del horizonte, con hasta seis posiciones visibles por entrada (máximo 18 posiciones distintas). Las decodifica como miniaturas de hasta 160 píxeles; cuando el grande recibe exactamente 1–4 lecturas completas usa hasta 384 píxeles para sus portadas mayores. Una portada ausente no altera la selección.

El ajuste visual solicitado el 7 de septiembre por la mañana centra el encabezado
«Reading»/«Leyendo» y da prioridad al título y progreso. La variante destacada usa
tipografía semántica headline/footnote y portadas escalables con base de 60 puntos;
la compacta conserva 40. El título admite dos líneas y escala mínima de 0,85 solo
en tamaños ordinarios; en accesibilidad conserva una línea y no reduce su escala.
El encabezado usa caption en accesibilidad y las portadas permanecen ocultas.
El pie se ancla abajo: contador y fecha comparten fila cuando caben y se apilan
cuando falta ancho; la fecha usa caption2 y conserva menor jerarquía visual.
Ese ajuste visual inicial conservó selección, orden, wire, eventos y publicación. La ampliación aprobada posteriormente se detalla a continuación.

## Estados sin contenido: presentación aprobada el 7 y 8 de septiembre

El propietario aprueba un tono informal y directo para vacío de lectura y sesión
redactada. Lectura vacía usa «¿Qué estás leyendo?» y «Marca tu tomo actual en
Manga Library.»; sesión redactada usa «Tus mangas, aquí» e «Inicia sesión en
Manga Library.». Los equivalentes ingleses conservan el significado. Colección
vacía y recurso no disponible mantienen mensajes distintos. El 8 de septiembre
el propietario extiende el tono informal y directo a no disponible: «¿Actualizamos?»
y «Abre Manga Library y actualizamos tus mangas.», con los equivalentes
«Let's refresh» y «Open Manga Library and we'll refresh your manga.». El mensaje
remite a Manga Library sin identificar un dispositivo que pueda ser incorrecto
en iPad.

La ilustración del manga abierto ya incluida en el icono de la app se reutiliza
como recurso decorativo local de la extensión para vacío, redacción y no
disponible. El grande centra el conjunto ilustración/título/explicación;
el mediano ofrece composición
horizontal y el pequeño una imagen discreta solo si cabe. La imagen cede antes
que los mensajes al adaptar espacio, y se omite en tamaños de accesibilidad.
Las fuentes siguen siendo semánticas, los mensajes accesibles se conservan
completos y no se añaden botones o gestos de autenticación en el widget. La
ilustración común no comunica el estado: los mensajes distintos conservan la
diferencia semántica entre no disponible, sesión cerrada y ausencia real de datos.

El recurso visual no altera snapshot, autoría, sesión, timeline ni publicación.
El PNG original se conserva como recurso bundled fuera del imageset. Antes de
entregar la entrada desde el provider, ImageIO prepara y conserva un thumbnail
por familia, con lado mayor máximo de 128 px en pequeño, 288 px en mediano y 512 px
en grande. Son cotas propias del recurso, independientes del tamaño de layout
y de Dynamic Type, no límites universales de WidgetKit. El archivo original no
se entrega al archivador del widget: reducir solo su `frame` no limita los píxeles
de la imagen. Si la carga o reducción falla, se omite la ilustración y se
conservan los mensajes, sin volver a utilizar la imagen original. Las Views
reciben la imagen preparada, sin lectura ni decodificación durante body.
Esta modificación de composición/copy se valida con builds, previews EN/ES,
Dynamic Type y revisión independiente, sin tests que reproduzcan el layout.

## Rotación de presentación aprobada el 7 de septiembre

El contrato de [ADR-0021](../adr/0021-widget-reading-rotation-and-priority.md) añade
rotación pausada a la misma superficie no interactiva. La ventana avanza una
posición circular cada 300 segundos desde `generatedAt`. Las ventanas del grande
se solapan para que una reducción de filas no provoque saltos. Una
petición prepara el slot actual y doce futuros; `.atEnd` permite renovar la hora
siguiente manteniendo fase. Cero/una lectura y estados vacío, redactado o no
disponible producen una entrada `.never`.
Si el reloj retrocede antes del ancla, la primera fecha es `now` y conserva el
foco; las siguientes son `generatedAt + 300`, `+600` hasta `+3600`. Esa excepción
puede ampliar el primer intervalo y el horizonte de reloj, pero no la cantidad
de entradas ni portadas retenidas. El orden causal continúa basado en revisiones.

El manga cuya lectura cambia en una edición individual puede iniciar el ciclo
siguiente. La preferencia opcional `preferredStartMangaID` viaja con el evento y
el snapshot, conservando compatibilidad con formato 1. Ausencia significa inicio
por el orden canónico.
El orden de los items sigue siendo por título: rotar no reordena el wire. El
ancla temporal solo gobierna presentación; revisiones y generaciones conservan
la autoridad causal. Un no-op no consume revisión ni reinicia el ciclo.
La igualdad se decide sobre el contenido publicable, incluso si una ida y vuelta
coalescida de progreso deja los mismos valores. Título, total o portada nuevos
reinician el ancla al publicar y conservan el foco válido; solo cambiar
`readingVolume` en una edición individual a un valor no nulo propone otro foco.
Editar propiedad o completitud, o guardar la misma lectura, no propone un foco
nuevo. Esto incluye reactivar un tombstone sin cambiar su tomo conservado.
Quitar la lectura no puede dar prioridad a un manga que ya no es elegible.

Si esa lectura quedaría fuera del prefijo admitido por los 32 KiB, se incluye
retirando los elementos finales necesarios, sin perder el orden canónico de los
retenidos. La reserva incluye los bytes de la preferencia. El contador no confunde
las lecturas omitidas por transporte con una colección completamente recibida.
Si el manga editado estaba excluido, incluirlo cambia el manifest publicable
aunque su progreso vuelva al valor original; no se conserva un historial privado
de toda la colección para decidir el no-op.
El transporte de lectura no promete recorrer todas las lecturas de una colección arbitrariamente grande. Una retirada
elimina la preferencia inválida; logout elimina tanto contenido como preferencia.

Las importaciones y reconciliaciones por lotes no deducen una última edición del
orden de la respuesta. Conservan la preferencia anterior si sigue siendo válida
y usan el orden canónico en caso contrario. Las recargas del sistema sin nueva
publicación no reinician la fase. La petición de reload después de una publicación
es best effort y no garantiza la visualización inmediata del manga prioritario.

## Colección mediana y adaptación por cantidad — ampliación DX4

La petición posterior del propietario sustituye el contenido mediano por
«My collection» / «Mi colección». [ADR-0022](../adr/0022-widget-collection-projection-and-adaptive-reading.md)
registra el transporte local, sus límites y la continuidad de las garantías de
ADR-0021. Una sola lectura confirmada y autorizada de SwiftData prepara ambas
proyecciones. Colección incluye **todas** las entradas activas de esa identidad,
con o sin lectura o tomos poseídos, en orden de título e ID. No existe fecha de
adquisición y no se inventa a partir de outbox, ID, mayor tomo o `generatedAt`.

Cada ficha de colección contiene `mangaID`, `title`, `ownedVolumeCount`,
`totalVolumes`, `isComplete` y `coverResourceID` opcional. Cuenta títulos activos,
no suma tomos. Propiedad y completitud se validan contra el estado persistido;
`isComplete == false` no se sustituye por una inferencia del contador.
Los textos muestran propiedad, completitud, total de mangas y fecha en EN/ES.
La nueva composición autorizada el 7 de septiembre sitúa, cuando hay contenido,
«My collection» / «Mi colección» a la izquierda de la cabecera y el total a la
derecha, dentro de una pastilla de fondo rojo tenue. El número usa un tamaño
mayor y peso semibold; la palabra localizada «mangas» usa un tamaño menor. Si
la cabecera y la pastilla completa no caben juntas, la variante compacta conserva
solo el número en la pastilla. Ambas variantes mantienen una etiqueta accesible
completa con el total y su unidad. El pie contiene únicamente la fecha, sin
repetir el contador. El total sigue contando los títulos activos de la misma
proyección; la composición no cambia datos, selección ni estados sin contenido.
Estos estados conservan su presentación sin esta cabecera de colección.

El mediano puede mostrar colección cuando `ReadingSnapshot.state == empty`.
Sin entradas muestra «Sin mangas en tu colección»; un descriptor ausente o inválido es no
disponible, nunca vacío. El pequeño/grande usa «¿Qué estás leyendo?» como estado vacío, conforme al ajuste de presentación siguiente.

`collectionReference` es opcional y compatible con formato 1: `{slot, digest,
byteCount}`. `slot` es 0 o 1, `digest` tiene 64 dígitos hex minúsculos y el tamaño
es de 1 a 1.048.576 bytes. Enlaza `collection-0.json` o `collection-1.json`, JSON
formato 1 con `items` completos, hasta 4.096 entradas. No contiene identidad de
cuenta, credenciales, URL remota ni datos de outbox. La protección usa el
manifest/fence que lo referencia. La app publica el conjunto completo o deja
referencia nula/no disponible si excede la cota; nunca un prefijo. Quita referencias
opcionales de portada antes de rechazar texto que por sí solo cabe.

Tras confirmar el 7 de septiembre que la rotación sí avanza, el propietario
solicita que una alta local muestre primero el manga recién añadido. El recurso
`CollectionWidgetSnapshot` incorpora `preferredStartMangaID` opcional, separado
de la preferencia de lectura del envelope. Es un `Int64` que debe identificar
un elemento de sus `items`; un valor incompatible invalida el recurso. Se omite
si es nulo; ausencia o `null` conservan compatibilidad con formato 1 y el inicio
canónico. Colección vacía no admite preferencia. Sus bytes participan en el
límite de 1 MiB; no se recortan mangas para incluirla.

La preferencia expresa una intención local confirmada, no una fecha de
adquisición ni un historial. No se infiere del orden de importación, de la
diferencia entre dos colecciones ni de una confirmación remota. La última alta
local confirmada de la misma autoridad propone el inicio; los eventos posteriores
sin otra alta conservan esa intención hasta resolver la publicación. Una alta
eliminada antes de publicar no puede mantener el foco. El publicador solo hereda
una preferencia anterior desde una lectura autorizada de la misma sesión y si
el manga sigue presente en la proyección actual. Logout o cambio de autoridad
no heredan el foco retirado.

El único publicador escribe y verifica el slot opuesto al manifest actual antes
de publicar este. Las reservas, tickets, cierre de sesión y ledger siguen siendo
los actuales. El mediano lee `fence → manifest → recurso validado → fence`, sin
fallback. Una carrera que reutilice el slot dos publicaciones después falla por
digest. Un fallo ordinario conserva el slot referido; dos slots retienen hasta
2 MiB y el temporal atómico puede elevar el pico a 3 MiB. No se añade GC.

La igualdad incluye ambas proyecciones y la integridad del recurso, conserva el
slot ante no-op y repara corrupción mediante el alterno y una revisión nueva.
Propiedad, completitud, altas y bajas ahora son cambios visibles aunque las
lecturas no varíen. Una publicación reinicia el ancla común; el mediano parte del
índice de su manga preferido, o del primero canónico si no lo hay, y continúa
circularmente por el mismo orden de `items`, sin modificar el wire. Solo una
edición real de lectura puede proponer la prioridad de lectura del envelope.
Un no-op conserva ambos focos, revisión y ancla: una preferencia por sí sola no
fuerza otra publicación del mismo contenido. La política de 300 segundos y
trece entradas continúa bajo control efectivo de WidgetKit; la entrega es
asíncrona y esos intervalos no garantizan un cambio visible puntual. La colección
se comparte por valor sin materializar trece arrays rotados, y cada entry
selecciona una ficha.

El lote de imágenes conserva candidatos de lectura y admite hasta 128 URLs
nuevas de colección. Prioriza la portada de la alta preferida dentro de esa
misma cota, sustituyendo una candidata final si es necesario; las demás siguen
el orden canónico. Una URL ya seleccionada no ocupa otra plaza. Se mantienen
deduplicación y cuota de 8 MiB. El resto usa placeholder y sigue entrando en la rotación textual.
El mediano solo decodifica las hasta trece portadas de su horizonte a 256 px.
No se leen imágenes de ambas familias en cada petición.

El grande ajusta portada y tipografía a la cantidad si el snapshot es completo
y tiene 1–6 lecturas reales. Las variantes de 1–4 mantienen alturas base de
184/104/76/56 puntos. La nueva petición del 7 de septiembre amplía la primera
variante de 5/6 a 56/47 puntos, con título `footnote` semibold, progreso `caption`
y 2 puntos entre filas. Los espaciadores entre encabezado, contenido y pie pueden
ceder todo su espacio, con mínimo de 0 puntos.

Para 5/6, si esa variante no cabe, se prueba la anterior de 48/44 puntos con
título `caption` y progreso `caption2`; después, las mismas filas compactas con
portada de 40 puntos y, finalmente, menos filas. La ampliación solo se aplica
a snapshots completos de 5/6 lecturas fuera de los tamaños de accesibilidad;
conserva las variantes de 1–4, snapshots parciales y accesibilidad. No se fija
la altura del texto ni se recortan cifras para forzar una variante. Las portadas
continúan omitidas en tamaños de accesibilidad. Datos, selección y timeline
mantienen su contrato.

### Consulta persistida — DX3.1

La autorización del propietario para DX3.1 materializa la consulta como
`CollectionMutationActor.readingProjection(authorization:)`. Reutiliza el
predicado de entradas activas del usuario y la capacidad
`SessionCommitAuthorization`, que comprueba identidad, generación, credencial,
suspensión y expiración. La autoridad se valida alrededor de la lectura y de
nuevo después del orden; la futura publicación todavía debe revalidarla.

La consulta no guarda ni revierte cambios: exige un contexto sin modificaciones
pendientes y desactiva `includePendingChanges`. Excluye filas ajenas y tombstones.
De ese mismo fetch prepara la colección completa y, para lectura, selecciona
`readingVolume != nil` y valida lectura/total.
Propiedad y completitud históricas incompatibles no invalidan una lectura válida.
Un snapshot de presentación perteneciente a otro `mangaID` rechaza la preparación;
no atribuye a una lectura el título o la portada de otro manga.

`CollectionReadingProjection` es un valor exclusivo de la app con autoridad y
todos los candidatos ordenados, título preparado, progreso y URL opcional de
portada como insumo privado. Desde la ampliación de colección incluye también
su lista opcional de candidatos con contador de propiedad y completitud. No es
`Codable`, no contiene modelos SwiftData ni outbox y no se comparte con consumidores. No asigna epoch/revisión,
recorta por 32 KiB, prepara recursos ni publica. Cancelación, contexto pendiente,
lectura incompatible o fallo de persistencia devuelven error sin resultado parcial
ni vacío sintético. La conexión de ese error con la conservación del manifest
pertenece al pipeline posterior de DX3.

## Formato compartido

Los tipos por valor se compartirán por pertenencia explícita de fuentes a los
targets, sin un paquete externo: `ReadingSnapshot`, su `Item` y `State`, y
`SessionFence`. Deben satisfacer `Codable` y `Sendable`; se conserva la inferencia
de Swift para valores internos cuando baste. La síntesis de decoding no puede
eludir la validación de esta frontera.

### Envelope `ReadingSnapshot`, formato 1

| Campo | Wire | Regla |
| --- | --- | --- |
| `formatVersion` | entero | Exactamente `1`; otro valor rechaza el documento completo. |
| `publicationGeneration` | UUID string | Epoch opaco del publicador, distinto de la sesión. |
| `revision` | entero JSON | `UInt64`, `1...UInt64.max`; nunca pasar por `Double`, incrementar con wrap o reutilizar una reserva. |
| `sessionGeneration` | UUID string o `null` | Obligatorio para contenido, vacío y redacción dirigida; opcional en no disponible. |
| `state` | string | `content`, `empty`, `redacted`, `unavailable`. |
| `generatedAt` | string | UTC RFC 3339 con milisegundos; fecha informativa y ancla de rotación de presentación, nunca autoridad causal de orden. |
| `totalEligibleCount` | entero o `null` | `Int64` no negativo en contenido/vacío; `null` en redacción/no disponible. |
| `items` | array | Selección en orden canónico sin IDs duplicados, con prioridad de inclusión dentro del presupuesto; reglas por estado debajo. |
| `preferredStartMangaID` | entero opcional | `Int64` que identifica un item de `content`; se omite al no existir preferencia. Ausencia o `null` se leen como inicio canónico. |
| `collectionReference` | objeto opcional | Slot, digest y byteCount del recurso completo local; solo en `content`/`empty`; ausencia o `null` indica colección no disponible. |

`generatedAt` conserva 24 caracteres UTC y tres dígitos de milisegundos. La
fracción del reloj se aproxima al milisegundo más cercano dentro del segundo,
con techo 999; no adelanta al segundo siguiente. Esa normalización evita que la
representación binaria de `Date` rechace milisegundos válidos al releerlos, también
antes de 1970. La validación mantiene igualdad canónica y rechaza fechas
imposibles, fracciones ausentes y offsets distintos de `Z`.

Cada `Item` contiene `mangaID` (`Int64`), `title` (string de presentación o
`null`), `readingVolume` (entero `1...300`), `totalVolumes` (`null` o entero
`1...300` no menor que lectura) y `coverResourceID` (referencia opaca opcional).
`mangaID` conserva el dominio de identidad `Int64` existente, sin derivarlo de
posición o imponer una nueva identidad.

- `content`: sesión no nula, al menos un item y `totalEligibleCount >= items.count`.
- `empty`: sesión no nula, `items == []` y `totalEligibleCount == 0`.
- `redacted`: generación de la sesión retirada, sin títulos ni items y cantidad
  `null`; no vacía por accidente una sesión B posterior.
- `unavailable`: sin items y cantidad `null`; no interpreta corrupción como vacío.

Una preferencia no nula debe pertenecer a `items`; de lo contrario se rechaza
el snapshot completo. Por ello `empty`, `redacted` y `unavailable` no admiten
una preferencia no nula. No se sustituye silenciosamente un ID incompatible.

El escritor emite todas las claves obligatorias y `null` explícito para ausencia;
la nueva clave opcional `preferredStartMangaID` se omite cuando es nula. El lector
acepta su ausencia o `null`, conservando compatibilidad con envelopes de formato 1
anteriores a DX4; si está informada, exige un entero exacto y pertenencia a `items`.
El lector exige campos obligatorios, tipos y estados coherentes. Puede ignorar
claves adicionales de un formato conocido, pero nunca una versión o estado
desconocidos. Rechaza documento truncado, UTF-8 inválido y números que no puedan
representarse exactamente en el tipo entero requerido o estén fuera de rango.
El escritor no genera claves duplicadas. Se usarán los codecs nativos, sin
introducir un parser JSON propio para imponer otra gramática léxica. Este
contrato se implementa en el codec compartido de DX2.

No viajan UUID de usuario, credenciales, correo, URL remota, rutas absolutas,
estado de outbox, secuencias de sincronización ni modelos SwiftData. El envelope de lectura no lleva propiedad; esa información mínima solo vive en el recurso local de colección.
Las generaciones de los fixtures son constantes sintéticas; producción genera
valores opacos aleatorios conforme a SDD 05.

### `SessionFence`, formato 1

Objeto JSON con `formatVersion: 1`, `publicationGeneration`, `fenceRevision`
(`UInt64` positivo) y `allowedSessionGeneration` (UUID o `null`). El lector acepta
contenido/vacío solo con las dos lecturas de fence íntegros e idénticos que
permitan el epoch y la sesión del envelope. La revisión de fence es independiente
de la de publicación. La lectura del envelope sin fence no autoriza contenido.

Bootstrap, apertura B, reservas, rotación de epoch, crash y punto de no retorno
siguen exactamente SDD 05. El estado durable del publicador existe para ordenar
y recuperar publicaciones; no autoriza sesiones ni sustituye Keychain. El wire
no expone tal estado a los consumidores.

### Almacenamiento y recuperación del publicador — DX2

`ReadingSnapshotStorage` recibe dos raíces por composición. La raíz compartida
contiene `session-fence.json`, `reading-snapshot.json` y, desde la ampliación de colección DX4, sus dos slots de JSON; la raíz privada de la app
contiene `publisher-state.json`. En DX2 ambas son directorios temporales aislados
en tests. No se simula un App Group efectivo mediante una ruta privada live.
Cada sustitución usa escritura atómica y la protección de archivos aprobada;
la atomicidad de un archivo no se presenta como transacción de los tres.

El estado privado es JSON `Codable`, formato 1, limitado a 16 KiB. Persiste
`publicationGeneration`, `lastReservedRevision`, `lastReservedFenceRevision`,
`requiresRetirement` e intención opcional. No guarda JWT, usuario, correo,
colección, títulos ni un estado autenticado. El fence se limita a 1 KiB y el
envelope a 32 KiB antes de decodificar. Un archivo no regular o sobredimensionado
es incompatible; un fallo temporal de lectura se propaga sin inicializar epoch.

- Bootstrap: intención con el fence cerrado de destino. La recuperación puede
  completar ese cierre, nunca una apertura de sesión.
- Publicación: reserva, generación, SHA-256 de los bytes exactos del envelope,
  fence de apertura esperado y marca de redacción. La reserva se guarda antes del
  manifest. Si el archivo canónico y el fence permiten esos mismos bytes, un
  reload pendiente se reintenta sin revisión nueva; si no, se abandona el intento
  incompleto conservando el contador consumido. No se abre el fence al recuperar.
- Retirada: generación cuyo Keychain debe eliminarse, generación a la que se
  dirige la redacción, revisión reservada y fence cerrado de destino. Las dos
  generaciones pueden diferir: si la redacción de A falla, B puede entrar y salir
  antes de publicar; su cierre retira B y la redacción pendiente sigue dirigida a A.

Una retirada conserva como máximo un estado/fence canónicos predecesores, sin
su propio predecesor. La validación rechaza una cadena adicional. Si el proceso
se interrumpe antes del nuevo fence, se recupera ese estado anterior; las reservas
del mismo epoch permanecen consumidas. Si el fence de destino es canónico, la
retirada está comprometida. No se elige un epoch por comparación numérica.
El descriptor se escribe antes del fence también ante overflow; después de
verificar el cierre no hay escritura de bookkeeping ni comprobación de
cancelación que pueda impedir devolver el commit al propietario de sesión.

Un primer bootstrap inocuo exige ausencia coherente de todos los artefactos.
Historia previa con autorización irrecuperable, un fence cerrado sin metadata
fiable o una contradicción entre estado y fence requieren retirar cualquier
Keychain residual antes de aceptar autenticación. Un manifest del mismo epoch
cuya revisión supera el contador reservado demuestra corrupción y fuerza una
rotación, incluso si la proyección solicitada sería idéntica. Un manifest
incompatible puede reemplazarse bajo capacidad vigente; no representa vacío.

`SessionController` recibe el publicador opcional por inicializador; Advanced
mantiene su composición vigente. La recuperación se completa antes de aplicar
Keychain. Logout conserva la decisión A1, suspende la capacidad ordinaria y
consume su capacidad de cierre; invalidación/expiración conservan una continuación
de saneamiento de la generación capturada. Esa continuación pertenece solo al
propietario de sesión y bloquea un login sustituto hasta terminar; no acepta
eventos tardíos de consumidores ni autoriza contenido. El borrado sigue siendo
condicional a la autoridad exacta de Keychain. Fallos después del fence verificado
mantienen la cuenta retirada y reintentable; redacción/reload son eventuales y
no bloquean una cuenta posterior. Sin Keychain también se cierra cualquier fence
residual antes de exponer el estado desconectado.

## Presupuesto y WatchConnectivity

El contexto tiene una sola clave estable `readingSnapshot`, cuyo valor es
`Data` con el JSON del envelope. Antes de llamar a WatchConnectivity, la app mide
el diccionario completo con `PropertyListSerialization` en formato binario:
el resultado debe ocupar **como máximo 32.768 bytes**. La app limita también los
bytes JSON de envelope leídos del disco y de `Data` a ese máximo antes de
decodificar. Es una política propia; la documentación Apple consultada no publica
un máximo numérico que permita prometer aceptación.

No se fija otro máximo arbitrario de mangas. La app calcula el total de
elegibles válidos y toma el mayor prefijo que quepa. Si el manga preferido queda
fuera, retira los elementos finales necesarios para incluirlo y conserva el
orden canónico de la selección resultante. El presupuesto es estable e incluye
`preferredStartMangaID`: la medición usa el encoder final con
`revision == UInt64.max`, UUID canónicos de 36 caracteres y una fecha de la
longitud fija del wire. Así pasar de la revisión 99 a 100 no cambia la selección
por sí mismo. El JSON se escribe compacto, con claves ordenadas y sin escapar
barras; todos los tamaños se calculan con el
codec que se utilizará para publicarlo, no con estimaciones de caracteres.

La comparación de proyección visible incluye la lista de lectura resultante,
`totalEligibleCount`, el contenido de colección y la integridad del recurso referido;
excluye fecha, revisiones y las preferencias de lectura o colección por sí solas.
Una propuesta de foco sin cambio de contenido publicable conserva el foco y el
ancla del manifest anterior, incluso tras una ida y vuelta coalescida de lectura.
Se decide **antes** de reservar revisión o escribir portadas: un no-op no consume ninguna reserva,
admisión durable ni reload. Solo si cambia la proyección se reserva revisión,
prepara el commit y se verifica también el tamaño exacto del contexto final.
Si ni el primer item, o el preferido que debe incluirse, con portada omitida
cabe, la publicación falla de forma ordinaria; nunca publica `empty` por agotar
el presupuesto ni descarta silenciosamente esa prioridad.

La proyección y envelope de lectura sirven a pequeño/grande y reloj. El recurso
local de colección solo sirve al mediano y no se transfiere al reloj. Apple exige una
`WCSession` activada para enviar; la falta de reachability no impide solicitar
`updateApplicationContext(_:)`. Una llamada posterior reemplaza el contexto
pendiente anterior. DX5 conserva/reintenta el último contexto deseado tras
activación/reactivación y tratará `payloadTooLarge` aun bajo el presupuesto;
un fallo del transporte no revierte el commit local o bloquea logout.

Las revisiones y generaciones siguen SDD 05: duplicados y valores anteriores del
mismo epoch se ignoran, un epoch nuevo no se compara numéricamente con el viejo,
y una redacción tardía de A no retira B. La cache local del reloj no usa un TTL
para deducir autorización: conserva el último contexto aceptado hasta que otro
lo sustituya o redacte. Esa cache puede permanecer visible sin conectividad y
no demuestra que la sesión siga vigente en iPhone.

### Materialización del companion — DX5

El manifiesto durable y el fence del publicador iOS siguen siendo la autoridad
del contexto deseado; no se añade otra cola persistida ni otro contador.
Activación/reactivación y restauración sin cambio visible pueden ofrecer el
contexto existente sin reservar revisión, cambiar fecha ni solicitar un reload
de WidgetKit. El propietario de sesión revalida la capacidad y su expiración
antes de ofrecer contenido; una sesión todavía no restaurada no autoriza el
reenvío de la ejecución anterior. Un fence cerrado permite ofrecer únicamente
la redacción compatible, incluida una intención de retirada durable cuyo
envelope aún esté pendiente. En ese último caso se utiliza la revisión ya
reservada y una fecha informativa del intento, sin escribir el manifest.
El fallo de WatchConnectivity conserva el estado
reintentable y no revierte la mutación local ni un logout ya seguro.

La recuperación de reloads WidgetKit y la entrega Watch son efectos separados.
Recuperar una intención de publicación no autoriza contenido ni `empty` en Watch;
sin capacidad solo puede ofrecer la redacción verificada. Cada envío de contenido,
también inmediatamente después del commit, revalida la capacidad. Un fallo Watch
no conserva artificialmente un reload ya completado; un fallo de manifest redactado
o reload no impide intentar la redacción reservada bajo el fence cerrado vigente.
El manifest, fence e intención existentes conservan la autoridad para reintentar.

El receptor del reloj serializa validación, aceptación y escritura. Conserva
el orden de recepción al reconciliar callbacks y el último contexto disponible
del sistema, también en activación y trabajo background. Esa reconciliación
precede a mostrar una cache restaurada; no debe aparecer transitoriamente
contenido que el último contexto recibido ya haya retirado. El reloj no abre
Keychain, SwiftData, App Group ni conexiones HTTP y no autentica la sesión.

La cache privada versionada guarda el snapshot y las barreras de epochs y
sesiones retirados en un único archivo de **hasta 65.536 bytes**, reemplazado
atómicamente. El reemplazo puede ocupar transitoriamente otro tanto. No contiene
JPEG, credenciales ni un historial de lecturas. Su protección es
`completeUntilFirstUserAuthentication`; la ruta no se comparte con iOS.
Ausencia permite esperar el primer contexto; un archivo inaccesible, corrupto,
sobredimensionado, enlace o tipo no regular produce no disponible. Un fallo de
escritura oculta el contenido e intenta retirar y verificar el archivo anterior.
Si escritura y retirada son imposibles, no se acredita retirada durable: la
reactivación reconcilia el contexto del sistema cuando está disponible antes
de mostrar cache. Tras un fallo simultáneo de escritura y retirada, una cache
residual y un sistema todavía inaccesible no permiten acreditar retirada durable
entre procesos; el aviso offline no cambia ese límite.

El receptor puede conservar en su instancia un único candidato cuya escritura o
lectura de verificación falló: los bytes de entrada válidos y acotados junto con
la transición completa de cache propuesta. La proyección permanece oculta hasta
reofrecer exactamente esos bytes y completar escritura y lectura verificadas.
No se acepta otro contenido con igual revisión. Un duplicado ya durable no
reescribe. Una transición nueva aceptada sustituye el candidato, incluso si su
persistencia falla; una entrada incompatible o saturación lo descarta. Las
entradas rechazadas por orden o barreras no modifican el candidato pendiente.
Si la transición era una redacción de A ajena a B, completar su persistencia
conserva la proyección B y la barrera de A. El reintento no reinicia metadata,
expira barreras ni añade tareas o archivos: depende de una nueva oferta del
contexto y no sobrevive por sí mismo al proceso.

Las barreras impiden revivir A después de B y no expiran por tiempo. Si una nueva
transición excede el presupuesto de cache, se conserva el historial aceptado,
se elimina el contenido mostrable y se persiste saturación. Una cache saturada
permanece no disponible; no se descartan barreras para volver a aceptar datos.
Esta política acota la cache sin inventar una vigencia de sesión.

La pantalla usa una lista SwiftUI desplazable con el orden recibido, título,
tomo actual, total conocido o desconocido y placeholder decorativo local.
Muestra el número de lecturas que quedan en iPhone y la fecha informativa del
snapshot. Diferencia vacío, redacción, no disponible y un fallo transitorio de
actualización; este último puede conservar el último snapshot compatible sin
afirmar que su sesión continúe vigente. Los textos ES/EN remiten a la app del
iPhone para cualquier acción. Las previews construyen snapshots sintéticos sin
activar WatchConnectivity ni leer almacenamiento.

La implementación y la validación técnica de DX5 están acreditadas. Su entrega
autorizada se completa el 10 de septiembre mediante la
[PR #87](https://github.com/JFrancoG/MangaLibrary/pull/87), integrada en `main`
con [`4ab15f5`](https://github.com/JFrancoG/MangaLibrary/commit/4ab15f58be84d749d8287eb5b8390fa622e1dd1e);
el issue #86 queda cerrado y la rama local/remota retirada. El plan #77 permanece
abierto con DX1–DX5 entregadas (5/7); DX6 es la siguiente subfase, sin iniciar. La
[checklist DX5](../dx5-watch-validation.md) separa las pruebas lógicas, los builds
completos y DocC, la matriz UI representativa y el transporte observado en
Simulator. Ninguna sustituye la matriz ampliada y física pendiente de DX6–DX7.

### Preparación y publicación acotadas — DX3.2

`ReadingPublicationPlan` recibe la proyección privada completa, un mapa de
referencias de portada ya resueltas por identidad de manga y la preferencia
opcional de inicio. Valida todos los candidatos, incluidos los que quedarán
fuera de la selección, y rechaza duplicados; así un error no reduce silenciosamente
el total. Referencias incompatibles o
no suministradas equivalen a placeholder mediante el contrato de `Item`. La URL
privada nunca se convierte en una referencia wire ni participa en el no-op.

El preparador usa el codec final y solo interpreta exceso de JSON o contexto
como falta de capacidad. Los demás errores se propagan. Las selecciones de prueba
crecen de forma acotada e incluyen los bytes de la preferencia admitida y del descriptor de colección; no se codifica toda la proyección de lectura para descubrir que no cabe. El recurso local de colección tiene su propia cota independiente. La autoridad, el total
original y la preferencia válida acompañan a la selección, sin fecha ni
revisión asignadas y sin I/O o admisión de recursos. Con los límites actuales de
cada item, incluso el primero con título de máximo escaping cabe en 32 KiB; se
mantiene la defensa de fallo ordinario sin un límite artificial para testearla.

La nueva entrada `ReadingSnapshotPublisher.publish(projection:coverResourceIDs:authorization:)`
comprueba la coincidencia exacta de autoridad antes de preparar y delega al único
commit DX2. Este revalida la capacidad y el tamaño exacto final. Una proyección
idéntica deja intacta una intención de reload pendiente; `recover()` explícito,
incluida restauración de sesión, la reintenta sin reservar otra publicación. La
reconciliación inicial sin entregar reloads sigue detectando contadores corruptos
antes del no-op.

Este bloque no acredita que un digest suministrado tenga un JPEG íntegro en disco.
Preparación, cuota, integridad y escritura de esos recursos pertenecen a DX3.3;
el orden entre dos proyecciones de la misma sesión y los eventos reales pertenecen
a DX3.4. Se conserva un único publicador y no se conecta composición live.

## Portadas, protección y retención

La app prepara thumbnails con Image I/O, conservando aspecto/orientación,
primer fotograma y sin copiar metadatos de origen al JPEG de salida. Presupuestos
propios: lado mayor de hasta **384 px** y archivo de hasta **65.536 bytes**. Si
una imagen no puede admitirse bajo ellos se decide usar placeholder antes de
reservar la publicación que no la referenciará.

`coverResourceID` válido es el SHA-256 del JPEG admitido, como 64 dígitos hex
minúsculos. Solo el lector construye `covers/<id>.jpg` bajo la raíz aprobada.
Rechaza referencias con componentes de ruta, nombres alternativos, symlinks o
bytes que no correspondan al digest; el item usa placeholder. Antes de leer
limita tamaño y antes de decodificar valida dimensiones, sin red. El recurso
se escribe atómicamente antes del manifest y su nombre nunca se sobrescribe.

La admisión global inicial de portadas es **8.388.608 bytes**. Cuenta archivos y
staging propios; una portada ya existente e íntegra puede reutilizarse. Si no hay
espacio en la cuota, la nueva proyección se prepara sin nuevas portadas. Un
fallo de escritura después de comprometer una referencia no se transforma a
posteriori en éxito: conserva el manifest anterior como exige SDD 05.

Los candidatos se preparan de forma acotada en memoria y la planificación de
cuota y selección se resuelve antes de escribir. Solo las portadas de los IDs
seleccionados para el manifest publicable pueden consumir admisión durable;
no se llena la cuota con imágenes de mangas excluidos por el presupuesto. Antes de cada escritura se
verifica la cuota, incluido staging. Fallar esa escritura conserva el manifest
anterior y no vuelve a calcular otra selección para aparentar éxito.

En 1.0 no se recolectan automáticamente portadas ya publicadas, tampoco por edad,
número de revisiones, cambio de sesión o llamada a reload. Así ningún manifest
aún legible pierde sus recursos y el almacenamiento queda acotado por admisión.
El coste aceptado es que, al agotarse la cuota, mangas nuevos
pueden mostrar placeholder indefinidamente. Una política posterior de limpieza
de recursos admitidos necesita demostrar qué manifests/lectores conservan
referencias; no se introduce `NSFileCoordinator` para adivinar esa condición.
Los recursos propios completos o incompletos de un intento fallido se pueden
recuperar/retirar por el escritor serializado solo tras demostrar, mediante su
intención durable y el manifest reconciliado, que nunca quedaron publicados ni
los necesita una recuperación pendiente. En caso ambiguo se retienen. Así la
limpieza posterior de huérfanos no borra recursos que un manifest pueda seguir
referenciando. El cierre del fence sigue siendo la protección de las
nuevas lecturas aunque los bytes de antiguas sesiones permanezcan presentes.

### Materialización de portadas — DX3.3

`ReadingCoverSource` recibe una `URLSession` sin credenciales desde composición;
no usa el cliente autenticado de la API. Acepta HTTPS sin usuario/contraseña,
respuesta HTTP 200 y hasta 8.388.608 bytes inclusivos de entrada. Comprueba el
Content-Length si está disponible y limita también los bytes recibidos mediante
`AsyncBytes`; cancela la tarea de transporte al terminar o abandonar la lectura.
Un error opcional produce placeholder y la cancelación de la tarea se propaga.

`ReadingCoverBatch` valida la proyección completa con el plan sin portadas y la
misma preferencia de inicio como techo de la selección posible. Fuera del actor
del llamador, prepara secuencialmente los candidatos de lectura cuyos IDs
selecciona ese plan y hasta 128 URLs distintas adicionales de colección, dando
prioridad a la alta preferida dentro de ese límite. Usar
únicamente la cantidad del prefijo perdería un preferido incluido fuera de su
cola original y los mangas de colección que no se leen. Omite URLs ausentes y memoiza cada URL, incluidos fallos.
No conserva los buffers de origen. Deduplica JPEG por digest y retiene hasta
8.388.608 bytes únicos de JPEG en memoria; la fuente y la operación nativa en curso
son transitorias. Este presupuesto no representa un límite del proceso Image I/O.

Image I/O valida tamaño de entrada, dimensiones positivas y hasta 64 millones
de píxeles antes de crear el thumbnail del primer frame completo. Aplica la
orientación, conserva aspecto y evita ampliar imágenes pequeñas. Genera un JPEG
nuevo sin copiar metadatos de origen, probando calidades 0,8, 0,6 y 0,4; si ninguna
cumple 384 px/65.536 bytes usa placeholder. El valor `ReadingCoverResource` solo
se construye con JPEG completo, acotado y decodificable, y calcula su digest sobre
los bytes exactos. El lector abre directorios y archivo sin seguir symlinks,
rechaza archivos no regulares sin bloquear y limita bytes antes de decodificar.

El único actor `ReadingSnapshotPublisher` recibe los recursos preparados y
resuelve cuota y selección final sin escribir, conservando la prioridad válida.
Admite recursos por los IDs de esa selección, no por posiciones del prefijo original.
Compara tanto la propuesta íntegra como el resultado limitado antes de admitir
recursos. Un journal de una
publicación ya comprometida puede usarse para planificar solo si coincide con
el manifest, es compatible, conserva receipts íntegros y no tiene staging;
la cuota cuenta también ese journal. Así un no-op parcial por cuota tampoco
limpia ni reescribe el intento anterior. Si cambia el resultado, recupera ese
intento mientras el manifest aún lo acredita, antes de preparar el nuevo commit.
La autoridad se comprueba antes del trabajo durable y alrededor de las escrituras.

`ReadingCoverStorage` conserva los JPEG en `covers/` y su metadata privada en
`cover-admission/`: un `journal.json` de hasta 16.384 bytes, `staging/` y
`receipts/<digest>.json`. El journal versionado registra intento UUID, digest del
manifest predecesor (o ausencia comprobada), digest esperado e IDs de archivos
que no existían al iniciar el intento. Se guarda y verifica antes de escribir
staging protegido; la promoción exclusiva nunca sobrescribe un JPEG existente.
Cada receipt es JSON no vacío versionado y se guarda antes del manifest. JPEG,
receipts, journal y staging cuentan juntos en la cuota durable de 8 MiB. Reutilizar
un JPEG íntegro con receipt no crea otro journal ni consume bytes adicionales.

El journal se reconcilia contra los bytes canónicos: si son los esperados, se
retienen recursos; si son el predecesor válido o su ausencia comprobada, solo se
retiran archivos del intento sin receipt y sin referencia en ese manifest.
Antes de borrar se completa el inventario y se comprueban todas las pruebas de
retención. Un manifest incompatible, metadata inaccesible o evidencia ambigua
conservan los bytes. La pérdida conjunta de JPEG y receipt no permite borrar una
imagen restaurada que el manifest siga referenciando. No se inventa reparación de
metadata perdida ni se amplía el estado DX2 de 16 KiB para esta contabilidad.

Los receipts son permanentes incluso si el manifest falla después: esa retención
conservadora puede agotar antes la cuota, pero nunca autoriza borrar una portada
publicada. La recuperación opcional de portadas no impide cerrar el fence ni
revierte un manifest comprometido. Los eventos y el orden entre dos proyecciones
de una misma sesión se concretan en DX3.4; DX3.3 no conecta composición live.

Se establece protección de archivos `completeUntilFirstUserAuthentication` para
envelope, fence, portadas y estado del publicador, aplicada a cada archivo nuevo
antes de su reemplazo. Antes del primer desbloqueo, una lectura inaccesible
degrada a no disponible y no inicializa por error un epoch nuevo. Corrupción y
archivo temporalmente inaccesible son causas distintas. Bloqueo de la **sesión**
dispara redacción; bloquear la pantalla no equivale a invalidar la sesión.

La protección de archivos no elimina timelines cacheadas. DX4 señala el
contenido sensible en SwiftUI; no se añade en DX1 el entitlement de Data
Protection de la extensión. Ocultar todo el widget al bloquear el dispositivo
mediante ese entitlement es una decisión separada, con consecuencias también
para la disponibilidad del widget de iPhone en Mac.

El reloj no recibe JPEG ni rutas de App Group. En 1.0 usa placeholder aunque el
envelope conserve la referencia opaca del iPhone; no intenta resolverla en su
sandbox ni activar `transferFile`, `transferUserInfo` o `sendMessage`.

## Eventos y orden de preparación — DX3.4

`ReadingPublicationEvents` se comparte entre el único `CollectionMutationActor`,
el propietario de sesión y `ReadingPublicationPipeline`. Conserva la última
intención, con autorización de sesión, ticket opaco y dos preferencias opcionales
independientes en memoria: `preferredStartMangaID` para lectura y
`preferredCollectionStartMangaID` para colección. Son identidades de presentación,
sin título, progreso ni copia de la colección; no persiste otro contador. Cada commit posterior invalida
el ticket anterior; el orden procede del commit, nunca de terminar una descarga.

La señal se registra sin suspensión después de la transacción exitosa y antes de
salir de `SessionCommitAuthorization.perform`, sin reentrar al cerrojo de sesión.
Se cubren mutación local autorizada, importación remota, rechazo permanente,
reconciliación de DELETE y resolución de outcome bloqueado. Un rollback, rechazo
o cancelación anterior al commit no emite ni invalida. Claim, confirmación, retry
y bloqueos que solo cambian outbox no emiten. Una importación sin cambios puede
emitir y queda suprimida por el no-op final existente.

Una mutación individual solo propone `preferredStartMangaID` cuando cambia
realmente la lectura comprometida a un valor no nulo. Los eventos posteriores
sin ID preferido, incluidos propiedad, completitud, activación o lotes, conservan
la última preferencia de la misma autoridad; no deducen foco del orden de una
respuesta remota. El publicador puede conservar la preferencia del manifest
anterior de esa misma sesión cuando el evento no aporta otra. La descarta si
ya no identifica una lectura elegible; una autoridad distinta y la redacción
no heredan la preferencia de la sesión retirada.

Para colección, la mutación local captura antes de aplicar el comando si la
entrada ya estaba activa. Solo una transición confirmada de ausente o tombstone
a activa propone `preferredCollectionStartMangaID`; editar propiedad,
completitud o lectura de una entrada ya activa no propone una alta. La señal se
registra dentro de la misma frontera autorizada del commit. Importaciones,
restauración y confirmaciones remotas no eligen un manga reciente, pero conservan
la preferencia pendiente de la misma autoridad. La coalescencia retiene la última
alta local; el publicador descarta su ID si fue eliminado de la proyección final.
La publicación correcta o el no-op consumen las preferencias pendientes solo
si el ticket sigue siendo el actual, sin borrar las de un commit posterior.

El descarte de logout restablece la base confirmada bajo la capacidad suspendida
e invalida el ticket anterior, sin autorizar contenido. Si después falla el cierre
del fence y la sesión se reactiva, se registra una capacidad nueva para releer
esa base ya comprometida. Restauración, login y refresh válidos usan el mismo
punto de activación. Restaurar lectura local no depende de que `/me` o R1 completen
con red disponible; una capacidad expirada o revocada no atraviesa el publicador.

Un rechazo de autorización durante la lectura, preparación o commit se reconcilia
con `SessionController.reconcileReadingAuthorization(for:)`. Si se detectó
caducidad, el propietario cierra el fence y retira Keychain mediante la ruta DX2;
no basta con rechazar el snapshot nuevo dejando el anterior permitido. Un fallo
de fence/Keychain se propaga fuera del consumidor y conserva la retirada capturada
para reintentarla con la misma autoridad completa. Un intento de A nunca retira B.
Los fallos ordinarios de publicación sí permiten consumir el siguiente evento.
La cancelación también comprueba si la capacidad ya fue rechazada y reconcilia
esa retirada antes de propagarse; no exige que siga vigente el ticket del contenido.
Un fallo de retirada mantiene prioridad sobre la cancelación para poder reintentarlo.

El consumidor de `AsyncStream` tiene una suscripción exclusiva y buffer del último
evento (`bufferingNewest(1)`). Conserva la última intención entre ejecuciones;
cancelar no libera la suscripción hasta que finaliza la preparación en curso.
Terminar el stream ocurre fuera del cerrojo del emisor. Un ciclo nuevo puede
reintentar el último estado; una suscripción antigua no libera a su sucesora.
El llamador ejecuta `run()` como tarea hija estructurada. No hay tareas autónomas,
polling, sleeps, timers o red dentro de la transacción de Colección.

Cada evento relee SwiftData comprometido y utiliza el recorte, preparación de
portadas y publicador existentes. Comprueba sesión/ticket alrededor de las
suspensiones. La validación final del ticket comparte la sección crítica de sesión
con admisión de recursos, reemplazo de manifest y apertura del fence: un commit
más reciente no se intercala entre la comprobación y ese efecto. Un intento
superado puede consumir una reserva, que no se reutiliza, pero no atraviesa la
siguiente frontera de publicación. Fallar no revierte Colección ni outbox; el
consumidor continúa en el siguiente evento. Cancelación se propaga. No se promete
latencia de entrega ni reintento periódico de publicación. La renovación temporal
de WidgetKit solo relee el bridge autorizado y no vuelve a publicar Colección.

`AppComposition.makeReadingPublication` recibe el container, las dos raíces,
reloj, generador de identidades, carga de portada y reload. Devuelve el escritor,
eventos y publicador que comparten esas dependencias. El llamador inyecta esos
eventos/publicador en `SessionController` y después crea el consumidor mediante
`makePipeline(sessionController:)`, que enlaza su reconciliación con ese propietario.
Las factorías no arrancan trabajo. DX4 conecta el mismo escritor, publicador y emisor
con `SessionController` y un consumidor estructurado de ámbito app. La app y el widget
resuelven `group.com.plusprojects.MangaLibrary.deluxe/Reading`; el estado de recuperación
permanece en `Application Support/ReadingPublisher`, privado de la app. Los efectos
resuelven el grupo de nuevo en cada acceso: ausencia o inaccesibilidad producen error,
nunca un directorio privado sustituto ni lectura `nil` que simule una sesión nueva.
El fallo mantiene el retiro obligatorio y permite reintentar desde Cuenta.

Las tareas de escenas activas comparten un propietario `@Observable @MainActor`.
Solo una consume; al cancelarse, libera la propiedad después de drenar el pipeline
antes de despertar a las otras escenas. Un fallo de reconciliación conserva la autoridad
exacta, se comunica a Cuenta y muestra reintento; no crea un bucle automático.
Una retirada concluida también reconcilia la presentación de Cuenta. El reload usa
únicamente el kind aprobado y no promete una actualización inmediata de WidgetKit.
Las portadas son opcionales: una preparación de storage fallida al lanzar puede dejar
placeholders hasta el siguiente lanzamiento sin deshabilitar el fence ni el publicador.

El lector distingue snapshot autorizado (contenido o vacío), redacción por fence cerrado
estable y no disponible por ausencia, corrupción o frontera cambiante. Sus lecturas
siguen `fence → snapshot → fence`; los errores de I/O se propagan y el consumidor los
presenta como no disponible. Cada petición genera una observación nueva, sin fallback
a una entrada anterior. Para contenido con más de una lectura publicada, el
provider entrega el slot actual y doce futuros separados 300 segundos, con
renovación `.atEnd` y fase derivada de `generatedAt`. Cero/una lectura y estados
vacío, redactado o no disponible usan una sola entrada y `.never`. Galería y
previews usan datos sintéticos sin resolver App Group ni ejecutar transporte.

La validación entre procesos dispone de un escenario exclusivo de DEBUG que
requiere `-ui-testing -ui-testing-reading-widget`. Usa Colección en memoria,
autorización sintética y la ruta real de mutación/publicación; toma el App Group
canónico y el mismo bookkeeping privado del publicador, sin un segundo ledger.
Solo se ejecuta en una instalación de pruebas. No accede a Keychain ni a red;
no representa autenticación live ni garantiza cuándo WidgetKit procesa un reload.
La [checklist DX4](../dx4-widget-validation.md) separa ese escenario de galería,
previews, tests con directorios aislados y pruebas físicas.

## Preparación de targets y fuentes

| Elemento | Valor previsto | Estado |
| --- | --- | --- |
| App existente | `MangaLibrary`, `com.plusprojects.MangaLibrary`, iOS 27 | Verificado por Xcode MCP. |
| Widget | Product name `MangaLibraryWidget`; target `MangaLibraryWidgetExtension`; bundle `com.plusprojects.MangaLibrary.widget` | Creado mediante Xcode MCP en DX4; Swift 6, iOS 27 y plataformas iPhone/iPad verificados. Fuentes comunes y Assets asignados mediante Xcode UI; builds MCP y gates limpios Debug/Release y DocC sin warnings. Validación automatizada, Simulator y física completadas en el alcance DX4 registrado en su checklist. La comprobación física anterior al primer desbloqueo sigue limitada/no observable y pendiente en DX6. |
| Companion | Target y carpeta `MangaLibraryWatch Watch App`; bundle `com.plusprojects.MangaLibrary.watchkitapp`; watchOS 27 | Creado mediante Xcode MCP para la app iOS existente en DX5. Fuentes y ciclo de vida integrados; builds Debug/Release, DocC y recorridos representativos de Simulator acreditados. Entregada mediante [PR #87](https://github.com/JFrancoG/MangaLibrary/pull/87). |
| App Group | `group.com.plusprojects.MangaLibrary.deluxe` para app iOS y widget | Entitlements añadidos mediante Xcode MCP a app y widget por autorización DX4. Acceso efectivo entre procesos acreditado en iPhone Simulator e instalación de desarrollo en iPhone 11; no acredita distribución ni I/O anterior al primer desbloqueo. No se añade al reloj. |
| Widget kind | `com.plusprojects.MangaLibrary.reading` | Único kind de 1.0, compartido por provider y reload. |
| Fuentes comunes | `MangaLibrary/Shared/Deluxe/` | Snapshot, fence, codec, lectores y configuración mínima compartida, incluidos en app y widget. Sin importar el módulo app o SwiftData. |
| Publicación app | `MangaLibrary/Deluxe/` | Único escritor compuesto en `AppComposition`; efectos DX2–DX3 conectados a sesión y escenas en DX4. |
| Consumidores | `MangaLibraryWidget/` y `MangaLibraryWatch Watch App/` | Widget entregado en DX4; companion y recepción WCSession entregados en DX5 mediante [PR #87](https://github.com/JFrancoG/MangaLibrary/pull/87), con callback y aplicación observados en Simulator. |

La preparación histórica de DX1 y los primeros gates DX4 verificaron Xcode 27
build `27A5252f`, Swift 6.4 y los SDK watchOS/watchOS Simulator 27. DX1 no compiló
ni modificó el destino del IDE. DX4 ejecutó sus tests mediante MCP con el scheme
`MangaLibrary`, iPhone 17 Simulator/iOS 27 `24A5423a`: Fast 278 declaraciones /
399 invocaciones e Integration 408/563, todas aprobadas. DX5 utiliza Xcode 27.0
`27A266a`, Swift 6.4 y iPhone 17 Simulator/iOS 27.0 `24A434`. La evidencia actual y
los gates aún pendientes viven en [Progress](../Progress.md), la
[checklist DX4](../dx4-widget-validation.md), la
[checklist DX5](../dx5-watch-validation.md) y la
[matriz DX6](../dx6-integration-accessibility.md).

Templates consultados por Xcode MCP:

- Widget: `com.apple.dt.unit.multiPlatform.widget`. DX4 se crea con
  `includeConfigurationIntent: false`; usa `StaticConfiguration` y no incorpora
  App Intents ni configuración por instancia.
- Watch: `com.apple.dt.unit.application.watchOS`, lifecycle SwiftUI. DX5 usa
  `companionAppStyle: Watch App for Existing iOS App`, valor comprobado en el
  template instalado, y `embedInAppNamed: MangaLibrary`. Las pruebas de lógica
  compartida se ejecutan con Swift Testing en el target unitario iOS; no se crea
  otro target de XCTest unitario.

La pertenencia de fuentes comunes no incluye `AppComposition`, secretos,
SwiftData ni configuración local en los consumidores. Nuevas configuraciones
mantienen warnings como errores y concurrencia estricta; no heredan ciegamente
ajustes exclusivos de iOS al target watchOS. En DX4, el gate DocC validó los cuatro
targets entonces presentes y generó el archive fuera de Git; sus builds limpios
Debug/Release y DocC pasaron con cero warnings y errores. DX5 acredita esos mismos
gates con el nuevo target completo mediante los scripts canónicos y Xcode-RC
seleccionado explícitamente. El escenario DEBUG de DX4 en iPhone Simulator acredita
contenido, actualización y redacción observados por la extensión; no promete una
latencia de WidgetKit. El contenido instalado también se observa en iPad Simulator;
la continuidad entre dos ventanas está observada. El ajuste visual posterior de
la mañana del 7 de septiembre mantiene el prefijo y contador: en el recorrido
iPhone el mediano muestra dos lecturas; en iPad muestra una con portada y texto
mayores, sin recortes al rotar. La checklist separa esta evidencia de la versión
anterior y registra los límites de cada entorno.
La instalación de desarrollo firmada y el App Group efectivo se acreditan
posteriormente en iPhone 11/iOS 27, junto con la aceptación visual del propietario.
El propietario confirma después los recorridos físicos de DX4 registrados en la
[checklist](../dx4-widget-validation.md), incluido VoiceOver de los tres tamaños
ES/EN y la recuperación tras reinstalar la versión normal. No se acredita
provisioning de distribución.

El 2026-09-08 el propietario aprueba trasladar a DX6 la comprobación física de
protección anterior al primer desbloqueo. El recorrido en iPhone 11 queda
**limitado/no observable**: no permitió acceder al widget antes de desbloquear.
Esta comprobación deja de bloquear el cierre de DX4, pero no se da por superada
ni se elimina: permanece pendiente en DX6 y para el Deluxe Release Gate.
Se conserva el contrato de lectura inaccesible como no disponible, sin inicializar
otro epoch, y no se atribuye esa evidencia a la recuperación posterior, un estado
inyectado, Simulator o tests deterministas.

## Ejemplos y matriz de validación

[Contracts/Deluxe](../../Contracts/Deluxe/README.md) conserva ejemplos sintéticos
independientes para selección, progreso, wire válido, wire rechazado y fallback
de portada. No son snapshots de cuentas reales, tests ejecutados ni modelos
funcionales por sí mismos. DX2 reutiliza esos oráculos en el decoder/publicador;
DX3.1 enlaza selección y orden con SwiftData aislado sin usar producción;
el recorte y los recursos se materializan en DX3.2–DX3.3; DX3.4 conecta los eventos
reales en composición aislada y DX3.5 conserva el gate técnico conjunto.

| Fase | Casos de cierre |
| --- | --- |
| DX1 | JSON legible, conteos/estados coherentes, selección esperada independiente, límites y referencias documentados, ausencia de datos sensibles, revisión iOS. |
| DX2 | Decoder real, exactitud Int64/UInt64, incompatibilidad, fence estable/cambiante/cerrado, reserva y crash, archivo inaccesible frente a corrupto, apertura A/B y logout/invalidación. |
| DX3 | Todos los commits que cambian proyección, recorte por bytes y contador, abreviación Unicode, orden, cuota sin borrar recursos retenidos, JPEG completo seguido de fallo/crash antes del manifest y limpieza del huérfano demostrado, no-op antes de reservar y revisión 99→100 sin cambiar el prefijo. |
| DX4 | Familias pequeña/mediana/grande en iPhone/iPad, EN/ES, Light/Dark, contraste, Dynamic Type/VoiceOver, sin red y lectura de App Group real. Rotación, fronteras de 300 s, renovación de fase, prioridad fuera del prefijo, no-op/coalescencia y retirada con fechas y colecciones sintéticas. La comprobación física anterior al primer desbloqueo pertenece a DX6 por el ajuste aprobado el 2026-09-08. |
| DX5 | Reloj enlazado, activación/reactivación, contextos reemplazados, duplicados/desorden/A→B, offline, cache y placeholder. |
| DX6–DX7 | Matriz física y de tecnologías de asistencia por superficie. La validación física Watch H02/H03/H04 queda pendiente para después de entregar el proyecto por decisión del 2026-09-10; puede adelantarse con pareja compatible prestada. No se marca aprobada ni se declara verde el gate completo. DX6 conserva H01, protección anterior al primer desbloqueo del iPhone, limitada/no observable en DX4 y no incluida en ese aplazamiento. Advanced y los demás criterios conservan sus gates; nuevos targets/planes/DocC sin warnings. |

### Pruebas sin Apple Watch físico

El propietario confirma el 6 de septiembre de 2026 que **no dispone de Apple
Watch físico**. Esto permite implementar y validar parcialmente Deluxe con
pruebas deterministas y Simulator; deja pendiente la evidencia física de reloj
exigida por la SDD 06 para el Deluxe Release Gate.

El **2026-09-10** confirma que no prevé disponer de ese hardware antes de entregar el
proyecto. Aprueba entregar el proyecto con las comprobaciones físicas Watch
pendientes y documentadas para después de la entrega. H02/H03/H04 conservan sus
criterios y se podrán adelantar con una pareja compatible prestada, por ejemplo
de un amigo. Esta excepción de planificación no incluye H01 del iPhone ni las
demás comprobaciones, no equivale a validación física y no declara superado el
Deluxe Release Gate completo.

El inventario histórico de DX1 mediante Xcode MCP (`XcodeListRunDestinations`,
incluidos incompatibles) identificó iPhone 17 Simulator/iOS 27, iPhone 11
físico/iOS 27 y cinco simuladores watchOS
27: SE 3 de 40/44 mm, Series 11 de 42/46 mm y Ultra 3 de 49 mm. Los relojes
figuraban como plataforma incompatible con el scheme iOS de aquel momento: no
implicaba un fallo del runtime ni acreditaba un companion o una pareja enlazada.
DX1 no creó dispositivos, cambió destinos ni ejecutó pruebas watchOS. La
checklist DX5 identifica los dispositivos y runtimes utilizados posteriormente.

| Evidencia planificada | Entorno y subfase | Alcance y límite |
| --- | --- | --- |
| Codec, tamaños, generaciones, duplicados/desorden, A→B y redacción | Swift Testing, fixtures y transporte controlado; DX2–DX5 | Prueba lógica propia con oráculo independiente; no demuestra entrega de WCSession. |
| Cache, relanzamiento, corrupción/ausencia y placeholder | Directorio temporal aislado y watchOS Simulator; DX5 | Prueba persistencia local. «Sin nuevos contextos» simula offline; no demuestra desconexión física. |
| Estados, ES/EN, títulos largos, scroll y Digital Crown | Watch Simulator de 40, 46 y 49 mm; DX5–DX6 | Cubre los extremos y un tamaño intermedio; la interacción es simulada, no ergonomía física. |
| Dynamic Type, contraste, etiquetas y orden semántico | Simulator y Accessibility Inspector según capacidades disponibles; DX5–DX6 | Evidencia visual y semántica parcial. No equivale a VoiceOver watchOS real. |
| Activación y `updateApplicationContext` | Caracterización de pareja iPhone/Watch Simulator compatible; DX5 | Registrar runtime/build, pareja, activación, envío, recepción y aplicación observados. Una llamada aceptada no demuestra recepción. |
| App Group/widget y protección de archivos en iPhone | iPhone 11 físico/iOS 27 y simuladores iPhone/iPad; DX4–DX6 | DX4 acredita instalación de desarrollo y App Group en el alcance registrado. La comprobación física anterior al primer desbloqueo queda limitada/no observable y pendiente en DX6 para el gate Deluxe. No acredita WatchConnectivity. |
| Pairing, desconexión/reconexión, suspensión, entrega background y VoiceOver watchOS | Pareja física compatible; H02/H03/H04, seguimiento después de entregar el proyecto | Pendiente, no aprobado. Puede adelantarse con pareja compatible prestada. Por decisión del 2026-09-10, esta falta de evidencia no impide entregar el proyecto con el pendiente documentado; ni fixtures ni Simulator satisfacen la fila y el gate completo sigue pendiente. |

Apple documenta interacción de watchOS Simulator y comprobaciones de
accesibilidad con Inspector. Su ejemplo de WatchConnectivity exige iPhone y
Apple Watch físicos; no se ha localizado una garantía vigente expresa de
`updateApplicationContext` en Simulator. La caracterización DX5 sí observa
envío, callback y aplicación de vacío, contenido de una nueva sesión sintética
y logout en iPhone 17/iOS 27.0 `24A434` y Ultra 4/watchOS 27.0 `24R362`, sin
reiniciar el Watch. Esa evidencia se limita a la pareja y recorrido registrados;
no garantiza otros runtimes ni ejecución background. No se cambia el canal
canónico para superar una limitación del entorno. Las pruebas controladas
comprueban conservación/reintento del último contexto y logout cuando el reloj
no está disponible, junto a los casos de orden y drenaje del contrato.

Las pruebas de entrega observarán callbacks y contenido, sin usar sleeps como
sincronización ni un plazo de entrega como oráculo. Incluso con hardware, el
ejemplo Apple advierte que el debugger impide la suspensión normal: la evidencia
futura de background deberá incluir apertura desde el reloj sin debugger.

No hace falta adquirir un reloj para avanzar las subfases de implementación.
La decisión del 2026-09-10 permite además entregar el proyecto conservando esta
validación física Watch pendiente para después, con la opción de adelantarla
mediante una pareja compatible prestada o colaboración autorizada. Mientras
falte, no se declara superado el Deluxe Release Gate completo; la entrega debe
identificar el pendiente y la decisión de [SDD 06](06-testing-quality-and-accessibility.md#entrega-del-proyecto-con-validación-física-de-watch-diferida).
No se fija una fecha. H01 del iPhone y los demás criterios mantienen su obligación
vigente; tampoco se autoriza publicación en App Store, entrega Git/GitHub o
inicio de DX7. Cualquier ampliación del aplazamiento necesita otra decisión
explícita en la fuente normativa.

## Fuentes y riesgos

- DX3.4 contrasta el SDK activo con [ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor),
  [AsyncStream, SE-0314](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md)
  y [Mutex, SE-0433](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0433-mutex.md).
  Los cerrojos no reentrantes contienen solo trabajo síncrono; la suscripción tiene
  un consumidor y conserva explícitamente la última intención.

- DX3.3 contrasta el SDK activo con Apple:
  [AsyncBytes](https://developer.apple.com/documentation/foundation/urlsession/asyncbytes),
  [transformación de thumbnail](https://developer.apple.com/documentation/imageio/kcgimagesourcecreatethumbnailwithtransform),
  [JPEG desde imagen decodificada](https://developer.apple.com/documentation/imageio/cgimagedestinationaddimage(_:_:_:)),
  [calidad de compresión](https://developer.apple.com/documentation/imageio/kcgimagedestinationlossycompressionquality)
  y [escritura sin sobrescritura](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/withoutoverwriting).
  Esta última no se combina con `.atomic`: se usa staging y promoción exclusiva.

- Apple Foundation: [normalización canónica](https://developer.apple.com/documentation/swift/stringprotocol/precomposedstringwithcanonicalmapping)
  y [folding con locale explícito](https://developer.apple.com/documentation/foundation/nsstring/folding(options:locale:))
  sustentan la clave interna de orden; SwiftData documenta
  [includePendingChanges](https://developer.apple.com/documentation/swiftdata/fetchdescriptor/includependingchanges)
  para excluir cambios sin guardar de la consulta. DX3.1 caracteriza estas
  operaciones en el SDK activo con oráculos independientes.

- [SDD 03](03-local-collection-and-invariants.md), COL-020–023 y COL-030–035;
  `CollectionModelsV2.swift`, `CollectionQuery.swift` y orden actual de
  `CollectionUserRootView.swift` sustentan selección, título y separación de propiedad.
- [SDD 05](05-deluxe-watch-and-widget.md), [SDD 06](06-testing-quality-and-accessibility.md)
  y [ADR 0019](../adr/0019-single-jwt-session-and-keychain-v3.md) conservan la autoridad.
- Apple: [application context](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)),
  [payloadTooLarge](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/payloadtoolarge),
  [frescura de widgets](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date),
  [creación y privacidad del widget](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension).
- Apple: [thumbnails](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)),
  [protección tras primer desbloqueo](https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication),
  [normalización de strings](https://developer.apple.com/documentation/foundation/nsstring/folding(options:locale:)).
- Apple: [interacción con watchOS Simulator](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-the-watchos-simulator),
  [ejemplo de WatchConnectivity y requisitos físicos](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity),
  [comprobaciones de accesibilidad](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app)
  y [ajustes de accesibilidad](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app).

32 KiB, 384 px, 64 KiB y 8 MiB son elecciones del producto aprobadas, no límites
atribuidos al SDK. El recorte visible, la retención sin recolección y el
comportamiento bloqueado forman parte del contrato aceptado; su comportamiento
ejecutable se valida en las subfases correspondientes. Ningún resultado DX1
certifica App Group, WatchConnectivity, accesibilidad o latencia de presentación.

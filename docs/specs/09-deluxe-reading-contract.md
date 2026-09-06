# SDD 09: Contrato de lectura Deluxe — DX1

**Estado:** Aprobada por el propietario el 2026-09-06
**Versión:** 1.0
**Fecha:** 2026-09-06
**Tracker:** [DX1 — issue #78](https://github.com/JFrancoG/MangaLibrary/issues/78), hijo del [plan aprobado #77](https://github.com/JFrancoG/MangaLibrary/issues/77)

## Alcance y aprobación

El propietario aprobó el plan DX1–DX7 y después el contrato concreto DX1 el
6 de septiembre de 2026. Este documento complementa la SDD 05 v1.7 con las
decisiones que deberán cumplir las siguientes subfases. No activa targets,
entitlements o dispositivos. Conserva la arquitectura de
snapshots de ADR 0007/0010 y la autoridad Keychain V3 de ADR 0019; no necesita una
nueva capa de persistencia de Colección ni otro ledger de sesión.

| Decisión | Contrato aprobado | Motivo |
| --- | --- | --- |
| En lectura | Entrada activa del usuario autorizado con tomo actual informado, incluido el último | Deriva de COL-020–023; propiedad y lectura son distintas. |
| Orden | Título de presentación normalizado, desempate por `mangaID`; títulos ausentes al final | Reconocible sin inventar fecha de última lectura; los consumidores conservan el orden publicado. |
| Capacidad visible | Pequeño: 1; mediano: hasta 3; reloj: lista desplazable del snapshot recibido | Ambas familias consumen prefijos del mismo contenido. |
| Contexto | JSON UTF-8 dentro de un único `Data`; máximo 32 KiB del diccionario completo codificado como binary plist | Presupuesto propio de trabajo/memoria, no límite oficial de Apple. |
| Más lecturas | Prefijo que quepa y cantidad total elegible; indicar cuántas quedan en iPhone | Evitar una colección aparentemente completa cuando hay recorte. |
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
la proyección. Vaciar el tomo de lectura retira el manga de Deluxe.

La proyección valida `readingVolume` y `knownTotalVolumes` contra `1...300` y
COL-022. No recorta un dato histórico inválido ni lo elimina silenciosamente:
falla la preparación ordinaria y conserva únicamente el último manifest válido
de la misma sesión todavía autorizada. Sin manifest permitido se muestra no
disponible. Una entrada inválida no se transforma en colección vacía.

- Total conocido: texto «Tomo N de T» / «Volume N of T».
- Total desconocido: «Tomo N · Total desconocido» / «Volume N · Total unknown»;
  no denominador, porcentaje o barra determinada inventados.
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
el prefijo. El contrato se caracteriza con ejemplos al implementar el proyector.

El widget mediano puede reducir de 3 a 2 o 1 elementos si Dynamic Type impide
representar el siguiente completo. Se conserva el prefijo, nunca se omite uno
intermedio. El contador localizado usa `totalEligibleCount - visibleItems.count`,
tanto por tamaño como por límite de transporte. El reloj usa el mismo cálculo
con todos los elementos recibidos. No se introduce navegación o deep link nuevo
en DX1.

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
| `generatedAt` | string | UTC RFC 3339 con milisegundos; informativo, no autoridad de orden. |
| `totalEligibleCount` | entero o `null` | `Int64` no negativo en contenido/vacío; `null` en redacción/no disponible. |
| `items` | array | Prefijo ordenado sin IDs duplicados; reglas por estado debajo. |

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

El escritor emite todas las claves descritas y `null` explícito para ausencia.
El lector exige campos obligatorios, tipos y estados coherentes. Puede ignorar
claves adicionales de un formato conocido, pero nunca una versión o estado
desconocidos. Rechaza documento truncado, UTF-8 inválido y números que no puedan
representarse exactamente en el tipo entero requerido o estén fuera de rango.
El escritor no genera claves duplicadas. Se usarán los codecs nativos, sin
introducir un parser JSON propio para imponer otra gramática léxica. Este
contrato no implica que ya exista un decoder implementado.

No viajan UUID de usuario, credenciales, correo, URL remota, rutas absolutas,
estado de outbox, propiedad, secuencias de sincronización ni modelos SwiftData.
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
y recuperar publicaciones; no autoriza sesiones ni sustituye Keychain. DX2
concretará sus bytes internos junto al algoritmo de recuperación; este wire no
expone tal estado a los consumidores.

## Presupuesto y WatchConnectivity

El contexto tiene una sola clave estable `readingSnapshot`, cuyo valor es
`Data` con el JSON del envelope. Antes de llamar a WatchConnectivity, la app mide
el diccionario completo con `PropertyListSerialization` en formato binario:
el resultado debe ocupar **como máximo 32.768 bytes**. La app limita también los
bytes JSON de envelope leídos del disco y de `Data` a ese máximo antes de
decodificar. Es una política propia; la documentación Apple consultada no publica
un máximo numérico que permita prometer aceptación.

No se fija otro máximo arbitrario de mangas. La app calcula el total de
elegibles válidos y toma el mayor prefijo que quepa bajo un presupuesto estable:
la medición usa el encoder final con `revision == UInt64.max`, UUID canónicos
de 36 caracteres y una fecha de la longitud fija del wire. Así pasar de la
revisión 99 a 100 no cambia el prefijo por sí mismo. El JSON se escribe compacto,
con claves ordenadas y sin escapar barras; todos los tamaños se calculan con el
codec que se utilizará para publicarlo, no con estimaciones de caracteres.

La comparación de proyección visible incluye la lista resultante y
`totalEligibleCount`, pero excluye fecha y revisiones. Se decide **antes** de
reservar revisión o escribir portadas: un no-op no consume ninguna reserva,
admisión durable ni reload. Solo si cambia la proyección se reserva revisión,
prepara el commit y se verifica también el tamaño exacto del contexto final.
Si ni el primer item con portada omitida cabe, la publicación falla de forma
ordinaria; nunca publica `empty` por agotar el presupuesto.

La misma proyección y envelope sirven a widget y reloj. Apple exige una
`WCSession` activada para enviar; la falta de reachability no impide solicitar
`updateApplicationContext(_:)`. Una llamada posterior reemplaza el contexto
pendiente anterior. DX5 guardará/reintentará el último contexto deseado tras
activación/reactivación y tratará `payloadTooLarge` aun bajo el presupuesto;
un fallo del transporte no revierte el commit local o bloquea logout.

Las revisiones y generaciones siguen SDD 05: duplicados y valores anteriores del
mismo epoch se ignoran, un epoch nuevo no se compara numéricamente con el viejo,
y una redacción tardía de A no retira B. La cache local del reloj no usa un TTL
para deducir autorización: conserva el último contexto aceptado hasta que otro
lo sustituya o redacte. Esa cache puede permanecer visible sin conectividad y
no demuestra que la sesión siga vigente en iPhone.

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
cuota/prefijo se resuelve antes de escribir. Solo las portadas seleccionadas del
prefijo publicable pueden consumir admisión durable; no se llena la cuota con
imágenes de mangas excluidos por el presupuesto. Antes de cada escritura se
verifica la cuota, incluido staging. Fallar esa escritura conserva el manifest
anterior y no vuelve a calcular otro prefijo para aparentar éxito.

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

Se establece protección de archivos `completeUntilFirstUserAuthentication` para
envelope, fence, portadas y estado del publicador, aplicada a cada archivo nuevo
antes de su reemplazo. Antes del primer desbloqueo, una lectura inaccesible
degrada a no disponible y no inicializa por error un epoch nuevo. Corrupción y
archivo temporalmente inaccesible son causas distintas. Bloqueo de la **sesión**
dispara redacción; bloquear la pantalla no equivale a invalidar la sesión.

La protección de archivos no elimina timelines cacheadas. DX4 señalará el
contenido sensible en SwiftUI; no se añade en DX1 el entitlement de Data
Protection de la extensión. Ocultar todo el widget al bloquear el dispositivo
mediante ese entitlement es una decisión separada, con consecuencias también
para la disponibilidad del widget de iPhone en Mac.

El reloj no recibe JPEG ni rutas de App Group. En 1.0 usa placeholder aunque el
envelope conserve la referencia opaca del iPhone; no intenta resolverla en su
sandbox ni activar `transferFile`, `transferUserInfo` o `sendMessage`.

## Preparación de targets y fuentes

| Elemento | Valor previsto | Estado |
| --- | --- | --- |
| App existente | `MangaLibrary`, `com.plusprojects.MangaLibrary`, iOS 27 | Verificado por Xcode MCP. |
| Widget | Product name `MangaLibraryWidget`; target esperado `MangaLibraryWidgetExtension`; bundle `com.plusprojects.MangaLibrary.widget` | Nombre previsto aprobado; comprobar nombre devuelto por Xcode al crearlo en DX4. |
| Companion | `MangaLibraryWatch`; bundle `com.plusprojects.MangaLibrary.watchkitapp`; watchOS 27 | Preparación aprobada; vincular con la app existente en DX5, no crear otra app iOS. |
| App Group | `group.com.plusprojects.MangaLibrary.deluxe` para app iOS y widget | Identificador previsto aprobado; no registrado ni concedido. La activación conserva su alcance y autorización propios. No se añade al reloj. |
| Widget kind | `com.plusprojects.MangaLibrary.reading` | Único kind de 1.0, compartido por provider y reload. |
| Fuentes comunes | `Shared/Deluxe/ReadingSnapshot.swift` y `Shared/Deluxe/SessionFence.swift` | Valores/codec de plataforma mínima; sin importar el módulo app o SwiftData. |
| Publicación app | `MangaLibrary/Deluxe/` | Único escritor compuesto en `AppComposition`; efectos DX2–DX3. |
| Consumidores | `MangaLibraryWidget/` y `MangaLibraryWatch/` | Views, adaptación de plataforma y recepción; DX4–DX5. |

Xcode 27 build `27A5252f`, su compilador Swift 6.4 y los SDK watchOS/watchOS
Simulator 27 se verificaron en esta sesión. El scheme activo sigue siendo
`MangaLibrary`, plan `Fast`, iPhone 17 Simulator/iOS 27. No se ha cambiado la
selección del IDE ni se ha compilado.

Templates consultados por Xcode MCP:

- Widget: `com.apple.dt.unit.multiPlatform.widget`. Su opción
  `includeConfigurationIntent` está activada por defecto; DX4 debe pasar `false`
  y comprobar que no aparecen App Intents/configuración por instancia.
- Watch: `com.apple.dt.unit.application.watchOS`, lifecycle SwiftUI. El default
  `companionAppStyle` es `Watch-only App`; DX5 deberá resolver la vinculación a
  MangaLibrary existente con el contrato que acepte Xcode, sin inventar el valor
  del chooser. El template admite Swift Testing; no se selecciona XCTest unitario.

La pertenencia de fuentes comunes no incluye `AppComposition`, secretos,
SwiftData ni configuración local en los consumidores. Nuevas configuraciones
mantienen warnings como errores y concurrencia estricta; no heredan ciegamente
ajustes exclusivos de iOS al target watchOS. Los scripts/planes que hoy enumeran
tres targets se amplían explícitamente cuando se añadan los nuevos. Signing,
provisioning, App Group efectivo, embedding y frameworks siguen sin verificar.

## Ejemplos y matriz de validación

[Contracts/Deluxe](../../Contracts/Deluxe/README.md) conserva ejemplos sintéticos
independientes para selección, progreso, wire válido, wire rechazado y fallback
de portada. No son snapshots de cuentas reales, tests ejecutados ni modelos
funcionales. DX2 reutilizará esos oráculos al implementar el decoder/publicador;
DX3 los enlazará a persistencia aislada sin usar producción.

| Fase | Casos de cierre |
| --- | --- |
| DX1 | JSON legible, conteos/estados coherentes, selección esperada independiente, límites y referencias documentados, ausencia de datos sensibles, revisión iOS. |
| DX2 | Decoder real, exactitud Int64/UInt64, incompatibilidad, fence estable/cambiante/cerrado, reserva y crash, archivo inaccesible frente a corrupto, apertura A/B y logout/invalidación. |
| DX3 | Todos los commits que cambian proyección, recorte por bytes y contador, abreviación Unicode, orden, cuota sin borrar recursos retenidos, JPEG completo seguido de fallo/crash antes del manifest y limpieza del huérfano demostrado, no-op antes de reservar y revisión 99→100 sin cambiar el prefijo. |
| DX4 | Familias pequeña/mediana en iPhone/iPad, EN/ES, Light/Dark, contraste, Dynamic Type/VoiceOver, sin red, antes de desbloqueo, lectura de App Group real. |
| DX5 | Reloj enlazado, activación/reactivación, contextos reemplazados, duplicados/desorden/A→B, offline, cache y placeholder. |
| DX6–DX7 | Matriz física y de tecnologías de asistencia por superficie; Advanced permanece verde; nuevos targets/planes/DocC sin warnings. |

### Pruebas sin Apple Watch físico

El propietario confirma el 6 de septiembre de 2026 que **no dispone de Apple
Watch físico**. Esto permite implementar y validar parcialmente Deluxe con
pruebas deterministas y Simulator; deja pendiente la evidencia física de reloj
exigida por la SDD 06 para el Deluxe Release Gate.

Xcode MCP (`XcodeListRunDestinations`, incluidos incompatibles) identifica
iPhone 17 Simulator/iOS 27, iPhone 11 físico/iOS 27 y cinco simuladores watchOS
27: SE 3 de 40/44 mm, Series 11 de 42/46 mm y Ultra 3 de 49 mm. Los relojes
figuran como plataforma incompatible con el scheme iOS actual: no implica un
fallo del runtime ni acredita un target companion o una pareja enlazada. iPad
se elegirá entre los simuladores existentes. No se han creado dispositivos,
cambiado destinos ni ejecutado pruebas watchOS en DX1.

| Evidencia planificada | Entorno y subfase | Alcance y límite |
| --- | --- | --- |
| Codec, tamaños, generaciones, duplicados/desorden, A→B y redacción | Swift Testing, fixtures y transporte controlado; DX2–DX5 | Prueba lógica propia con oráculo independiente; no demuestra entrega de WCSession. |
| Cache, relanzamiento, corrupción/ausencia y placeholder | Directorio temporal aislado y watchOS Simulator; DX5 | Prueba persistencia local. «Sin nuevos contextos» simula offline; no demuestra desconexión física. |
| Estados, ES/EN, títulos largos, scroll y Digital Crown | Watch Simulator de 40, 46 y 49 mm; DX5–DX6 | Cubre los extremos y un tamaño intermedio; la interacción es simulada, no ergonomía física. |
| Dynamic Type, contraste, etiquetas y orden semántico | Simulator y Accessibility Inspector según capacidades disponibles; DX5–DX6 | Evidencia visual y semántica parcial. No equivale a VoiceOver watchOS real. |
| Activación y `updateApplicationContext` | Caracterización de pareja iPhone/Watch Simulator compatible; DX5 | Registrar runtime/build, pareja, activación, envío, recepción y aplicación observados. Una llamada aceptada no demuestra recepción. |
| App Group/widget y protección de archivos en iPhone | iPhone 11 físico/iOS 27 y simuladores iPhone/iPad; DX4–DX6 | El iPhone disponible permite esa evidencia en su alcance; no acredita WatchConnectivity. |
| Pairing, desconexión/reconexión, suspensión, entrega background y VoiceOver watchOS | Pareja física compatible; DX6–DX7 | Pendiente por falta de Apple Watch. Ni fixtures ni Simulator satisfacen esta fila. |

Apple documenta interacción de watchOS Simulator y comprobaciones de
accesibilidad con Inspector. Su ejemplo de WatchConnectivity exige iPhone y
Apple Watch físicos; no se ha localizado una garantía vigente expresa de
`updateApplicationContext` en Simulator. DX5 caracterizará el runtime real
antes de atribuirle soporte. Si no permite el intercambio, UI/cache/receptor se
validan con fixtures y queda pendiente el transporte; no se cambia el canal
canónico para hacer pasar la prueba. El doble sí comprobará que se conserva y
reintenta el último contexto y que un reloj no alcanzable no bloquea logout.

Las pruebas de entrega observarán callbacks y contenido, sin usar sleeps como
sincronización ni un plazo de entrega como oráculo. Incluso con hardware, el
ejemplo Apple advierte que el debugger impide la suspensión normal: la evidencia
futura de background deberá incluir apertura desde el reloj sin debugger.

No hace falta adquirir un reloj para avanzar las subfases de implementación.
Para completar la fila física se podrá usar después una pareja compatible
prestada o la colaboración autorizada de alguien con esos dispositivos. Mientras
esa evidencia falte, DX6/DX7 la conservan pendiente y no se declara superado el
Deluxe Release Gate. Cualquier cambio de ese criterio requerirá una decisión
explícita en la SDD 06; la aprobación de este contrato no lo elimina.

## Fuentes y riesgos

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

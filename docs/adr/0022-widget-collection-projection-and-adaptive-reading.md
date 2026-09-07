# ADR-0022: Colección en el widget mediano y lectura adaptable

**Estado:** Accepted
**Fecha:** 2026-09-07
**Supersede:** [ADR-0021](0021-widget-reading-rotation-and-priority.md), cuya rotación y prioridad de lectura conserva.

## Contexto

El propietario solicita que el pequeño abrevie el progreso, que el grande
aproveche el espacio cuando haya pocas lecturas y que el mediano pase a «Mi
colección», mostrando sucesivamente todos sus mangas, propiedad, completitud y
cantidad total. Es una ampliación autorizada de DX4, no una entrega ni el inicio
de watchOS. La proyección de lectura excluye entradas sin tomo actual y su
presupuesto de transporte de 32 KiB no permite representar toda la colección.

El mismo 7 de septiembre, después de confirmar que la rotación sí avanza, el
propietario solicita que una alta local muestre primero el manga recién añadido
y ajustar las portadas del grande para una, cinco y seis lecturas. Esta decisión
Accepted se concreta dentro de la misma DX4 local todavía no entregada.
Una petición posterior del mismo día amplía de nuevo las variantes de cinco y
seis lecturas para aprovechar el espacio disponible, conservando las anteriores
como alternativas cuando falte espacio.
El propietario también solicita trasladar el total del mediano a la cabecera,
destacarlo en una pastilla roja tenue y reservar el pie para la fecha.

## Decisión

Se conserva `StaticConfiguration`, un `kind`, el escritor de Colección, el
publicador serializado, su ledger de publicación y el `SessionFence` existentes.
La familia determina el contenido: pequeño y grande muestran lecturas; mediano,
colección. No se introduce otra autoridad, store SwiftData, migración, servicio,
entitlement, acceso Keychain ni red en la extensión.

Una consulta autorizada y confirmada prepara las dos proyecciones. Colección
incluye todas las entradas activas del usuario, tengan o no lectura o tomos
poseídos; excluye tombstones y otras cuentas. Publica ID, título preparado,
número de tomos en propiedad, total conocido opcional, `isComplete` persistido
y referencia opcional de portada. No infiere adquisición ni actividad reciente.
Mantiene el orden por título y desempate por ID de Deluxe. Los números de tomo
siguen las invariantes `1...300`; propiedad corrupta hace no disponible esta
proyección sin convertirla en una colección vacía ni invalidar lecturas válidas.

El envelope de lectura formato 1 incorpora `collectionReference` opcional. Su
descriptor enlaza un slot 0/1, tamaño y SHA-256 hexadecimal con un JSON local
formato 1 que contiene la colección completa. Ausencia significa no disponible
o productor anterior; `items: []` significa vacío real. El descriptor se incluye
en todas las mediciones y en el límite final de 32 KiB. Los estados de lectura
`content` y `empty` pueden referir colección; `redacted` y `unavailable` no.
Watch conserva exclusivamente su proyección de lecturas y no necesita ese JSON.

El JSON de colección incorpora `preferredStartMangaID` opcional, omitido cuando
es nulo y compatible con lectores anteriores de formato 1. Ausencia o `null`
indican inicio canónico; un valor no nulo debe ser un `Int64` presente en `items`,
de modo que una colección vacía no puede tenerlo. Sus bytes cuentan dentro del
MiB del recurso. Es una preferencia de presentación, no historial ni fecha de
adquisición local o remota.

La mutación local captura si la entrada estaba ausente o era tombstone antes
de aplicar el comando. Solo la transición confirmada a activa emite
`preferredCollectionStartMangaID` después del commit, dentro de la autorización
y ticket existentes. Este foco es
independiente del de lectura. La última alta local confirmada de la misma
autoridad prevalece al coalescer; los eventos sin nueva alta la conservan y los
lotes o confirmaciones remotos no deducen una alta reciente. Si esa entrada se
elimina antes de publicar, se descarta la propuesta. El publicador solo hereda
el foco anterior desde una lectura autorizada de la misma sesión y si sigue
presente en el contenido actual. Logout y cambio de autoridad no lo heredan.
Una publicación o no-op consume únicamente las preferencias del ticket actual.

Los archivos `collection-0.json` y `collection-1.json` forman dos slots acotados.
El mismo publicador elige el opuesto al manifest vigente, lo reemplaza
atómicamente y verifica sus bytes antes de publicar el manifest. Revalida el
ticket y la autoridad en cada frontera durable. Un fallo previo al manifest
conserva el slot y los datos anteriores. El ledger actual sigue reservando
revisiones y recuperando reloads: no se crea otro journal ni contador.

El lector mediano realiza `fence → manifest → slot verificado/decodificado →
fence`. Solo devuelve datos si ambas lecturas del fence coinciden, permiten las
generaciones del manifest y el recurso coincide con tamaño/digest. Un slot
reutilizado durante dos publicaciones puede causar no disponible; nunca permite
mezclar revisiones ni recuperar una entry anterior. El lector abre recursos regulares sin seguir links. El escritor comprueba el
directorio y el slot de destino antes del reemplazo atómico. Ambos usan rutas
canónicas y cotas, sin interpretar rutas del payload.

Cada JSON admite como máximo 1 MiB y 4.096 mangas. Se publica completo o se
indica no disponible, nunca un prefijo presentado como toda la colección. Las
referencias opcionales de portada se retiran antes de rechazar un payload cuyo
texto sí cabe. Son límites propios de memoria y almacenamiento, no límites de
Apple ni del número de mangas permitido por la app. Dos slots retienen como
máximo 2 MiB; un reemplazo atómico puede necesitar un tercer MiB temporal.

Las portadas reutilizan preparación, validación, admisión y recibos permanentes
existentes. El lote conserva candidatos de lectura y añade hasta 128 URLs
distintas de colección, sin repetir fuentes, dentro de los 8 MiB ya aprobados.
La portada de la alta preferida tiene prioridad dentro de esas 128, sustituyendo
una candidata final si hace falta, sin ampliar cantidad ni cuota. Las demás
siguen el orden canónico y las URLs ya seleccionadas no consumen otra plaza.
El resto mantiene texto y placeholder. La extensión decodifica solo el horizonte
visible: hasta 13 posiciones de colección a 256 px, o hasta 18 de lectura a
160 px. Para 1–4 lecturas completas en grande admite hasta cuatro imágenes de
384 px. No prepara miles de imágenes antes de cada publicación.

El no-op compara ambas proyecciones publicables y comprueba que el recurso
referenciado sigue íntegro. Igualdad conserva slot, revisión y ancla; reparar un
recurso perdido o corrupto exige el otro slot y una revisión nueva. Propiedad,
completitud, altas, bajas o presentación cambiadas ahora pueden publicar aunque
las lecturas no cambien. Una publicación visible reinicia el ancla común. Una
preferencia por sí sola no fuerza una publicación de contenido idéntico: el
no-op conserva los focos, revisión y ancla existentes.

Se conserva la política de ADR-0021: slots de 300 segundos, actual más doce
futuros, renovación `.atEnd` y fase estable desde `generatedAt`. Cero/uno o
estado sin contenido usa `.never`; el reloj hacia atrás empieza en `now` sin
saltar el primer elemento. Colección selecciona una sola ficha por entry sobre
un array compartido, sin copiar todo el array trece veces. Empieza por el índice
de la preferencia de colección, o por el primero si no existe, y continúa
circularmente por el orden canónico sin reordenar `items`. La prioridad de una
edición de lectura sigue aplicándose solo a pequeño/grande. El sistema decide
cuándo presenta las entradas: la entrega es asíncrona y los 300 segundos no son
un plazo garantizado de actualización visible.

El pequeño muestra `Tomo N/T` o `Tomo N`, conservando la etiqueta accesible
completa. El grande prueba una variante por cantidad cuando el snapshot completo
tiene 1–6 lecturas. Para 1–4 conserva alturas base de 184/104/76/56 puntos. Para
5/6 prueba primero 56/47 puntos, título `footnote` semibold, progreso `caption`
y 2 puntos entre filas; los espaciadores entre encabezado, contenido y pie
pueden reducirse hasta 0 puntos. Si no cabe, prueba la variante anterior de
48/44 puntos con título `caption` y progreso `caption2`, después las mismas
filas compactas con portada de 40 puntos y, finalmente, menos filas.

Esta ampliación solo afecta a snapshots completos de 5/6 lecturas fuera de
los tamaños de accesibilidad. Conserva las variantes de 1–4, snapshots parciales,
accesibilidad, datos y timeline. No interpreta una reducción por Dynamic Type
o transporte como una colección pequeña ni muestra portadas en tamaños de
accesibilidad. Conserva hasta seis filas, contador restante y fecha. El mediano
muestra una ficha, propiedad, completitud, total de mangas y fecha, con textos
EN/ES y adaptación por espacio y Dynamic Type.

En el mediano con contenido, «My collection» / «Mi colección» se alinea a la
izquierda de la cabecera y una pastilla de fondo rojo tenue muestra el total a
la derecha. El número es mayor y semibold, con la palabra localizada «mangas»
en tamaño menor. Si el título y la pastilla completa no caben juntos, la
variante compacta muestra solo el número; su etiqueta accesible conserva el
total y la unidad completos. El pie muestra únicamente la fecha. Se mantiene
el mismo conteo de títulos activos y la misma proyección. Los estados sin
contenido conservan su presentación y no incorporan esta cabecera.

## Alternativas y consecuencias

- Colección inline compartiría y agotaría el presupuesto de lecturas/Watch.
- Recursos con nombre por contenido requerirían otra política de retención y
  limpieza; dos slots mantienen almacenamiento acotado sin otro ledger.
- Un único archivo reemplazado antes del manifest rompería la conservación del
  contenido anterior ante fallo. Escribirlo después publicaría una referencia
  antes de disponer de sus datos.
- Inferir la última alta mediante diferencias en el publicador confundiría
  restauración o importación remota con la intención local y no ordenaría altas
  coalescidas. El evento explícito usa el commit como autoridad sin crear historial.
- Hay más bytes y validación local, una posibilidad segura de no disponible
  durante carreras, y cotas explícitas de colección e imágenes. No se promete
  rotación a segundos, precisión temporal ni retirada visual instantánea.
- La validación añade codec, lector, slots/fallos, igualdad, propiedad sin
  lectura y rotación de la colección completa. La prioridad añade oráculos de
  alta local y reincorporación, coalescencia/retirada, no-op, independencia del
  foco de lectura, límite de imágenes y vuelta circular desde el manga elegido.
  Firma/protección y VoiceOver en
  hardware siguen pendientes de DX4.5; no hace falta Apple Watch para este cambio.

## Fuentes

- [SDD 05](../specs/05-deluxe-watch-and-widget.md) y [SDD 09](../specs/09-deluxe-reading-contract.md).
- [WidgetKit: mantener un widget actualizado](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/).
- [SwiftUI ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits).

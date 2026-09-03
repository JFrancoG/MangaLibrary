# Colección local e invariantes

- Estado: aprobado
- Versión: 1.5
- Última revisión: 2026-09-03

## Propósito y alcance

Definir el estado local que representa la colección de un usuario y las invariantes que toda creación, edición, sincronización y migración debe preservar. La especificación describe semántica, no fija nombres de propiedades o payloads remotos.

## Modelo conceptual

Existe como máximo una entrada de colección por la pareja **usuario + manga**. La entrada contiene, como mínimo conceptual:

- la identidad estable del usuario;
- la identidad estable del manga;
- los volúmenes que posee;
- el volumen por el que va leyendo, si lo indica;
- si considera completa la colección;
- la última versión confirmada necesaria para reconciliar sincronización;
- el estado mínimo necesario para representar una eliminación pendiente cuando proceda.

Los detalles exclusivos de la outbox se definen en [Autenticación y sincronización](04-authentication-and-sync.md).

## Cota global de números de tomo

El dominio de Colección admite únicamente números de tomo dentro del rango
inclusivo `1...300`. La cota `300` es una política de producto transversal y debe
tener una sola representación compartida por catálogo, editor, persistencia e
importación y envío remotos; no se repite como número mágico en cada frontera.

`totalVolumes == nil` significa que no existe un total editorial conocido y
fiable. No equivale a cero, a 300 ni a una colección vacía, y tampoco relaja la
cota de cada tomo poseído o de lectura. Cuando existe, el total conocido debe
estar en `1...300`; cada número de tomo debe estar también en `1...300` y, además,
no superar ese total.

La cota se valida antes de construir `1...total`, un `Set` equivalente o cualquier
otra colección derivada. Ordenar y deduplicar son normalizaciones seguras;
recortar a 300, saturar, descartar valores o reinterpretar un valor inválido como
válido no lo son.

Un total explícito fuera de `1...300` en una respuesta de Catálogo invalida la
página como deriva de contrato; no se proyecta a `nil`. Colección conserva además
el valor wire bruto de R1 para poder rechazar atómicamente el snapshot, aunque el
modelo `Manga` intermedio no exponga ese total incompatible.

## Decisiones de persistencia

- SwiftData es la persistencia local.
- Los tipos persistidos usan `@Model`.
- Las Views leen directamente con `@Query` cuando esa consulta pertenece a su contexto.
- Las Views no escriben directamente propiedades sujetas a invariantes.
- Una única ruta de mutación valida, normaliza y persiste colección y outbox.
- Esa ruta usa `@ModelActor` por defecto y su propio `ModelContext`.
- Los límites entre contextos intercambian identificadores o snapshots por valor, no instancias vivas de `@Model`.

Véase [ADR-0004](../adr/0004-swiftdata-local-first-and-model-actors.md).

## Invariantes

### Identidad

| ID | Invariante |
| --- | --- |
| COL-001 | Solo puede existir una entrada para una pareja usuario + manga. |
| COL-002 | Una entrada no puede cambiar de usuario o manga mediante una edición ordinaria; ese cambio equivale a otra identidad. |
| COL-003 | Los datos de un usuario no pueden aparecer en consultas ni sincronizaciones ejecutadas para otro. |

### Volúmenes en propiedad

| ID | Invariante |
| --- | --- |
| COL-010 | Cada volumen en propiedad es un entero incluido en `1...300`. |
| COL-011 | No hay volúmenes duplicados. |
| COL-012 | Los volúmenes se persisten en orden ascendente canónico. |
| COL-013 | Si el total de volúmenes es conocido, ningún volumen en propiedad puede superarlo. |
| COL-014 | El total de volúmenes es `nil` cuando se desconoce o un entero incluido en `1...300` cuando se conoce. |

Los duplicados y el orden se normalizan antes de persistir. Un valor fuera de
`1...300` o superior al total conocido invalida el comando; no se elimina ni
ajusta silenciosamente.

Cuando el catálogo no publica un total, el editor acompaña el campo numérico con
un botón nativo `plus` bordeado y circular para añadir el tomo. Cada tomo ya
incluido ofrece un botón equivalente con `trash`, rol y color destructivos para
retirarlo del borrador. Ambos controles conservan un objetivo táctil mínimo de
`44 × 44 pt` y nombres accesibles localizados equivalentes a «Añadir tomo» y
«Eliminar tomo N»; la iconografía no sustituye esas etiquetas.

### Volumen de lectura

| ID | Invariante |
| --- | --- |
| COL-020 | `readingVolume` puede ser `nil`. |
| COL-021 | Si existe, `readingVolume` es un entero incluido en `1...300`. |
| COL-022 | Si el total es conocido, `readingVolume` no puede superarlo. |
| COL-023 | `readingVolume` no necesita formar parte de los volúmenes en propiedad. |

La separación de COL-023 es intencional: leer un volumen y poseerlo son hechos distintos.

### Colección completa

| ID | Invariante |
| --- | --- |
| COL-030 | `complete` solo puede ser verdadero cuando el total de volúmenes es conocido y está incluido en `1...300`. |
| COL-031 | Activar `complete` canonicaliza los volúmenes en propiedad al rango completo `1...total`. |
| COL-032 | Si se retira un volumen de una colección completa, `complete` pasa a falso en la misma mutación. |
| COL-033 | Un estado con `complete == true` y volúmenes distintos de `1...total` nunca se persiste. |
| COL-034 | En el editor con total conocido, seleccionar manualmente el último volumen pendiente activa `complete`. |
| COL-035 | En el editor con total conocido, desactivar el control `complete` vacía los volúmenes del borrador sin alterar `readingVolume`. |

El editor L2 presenta `complete` como control de selección total: activarlo
selecciona `1...total`, desactivarlo vacía la selección y cualquier cambio manual
vuelve a derivar su valor desde los volúmenes. Fuera de ese borrador editorial,
una mutación persistente que reciba `complete == false` no infiere por sí sola qué
volúmenes concretos debería borrar; conserva la lista explícita del comando.

Antes de activar o derivar `complete`, el editor y la ruta persistente validan el
total contra la cota global. Ninguna comprobación de completitud materializa un
rango a partir de un total todavía no validado.

## Semántica de mutación

Cada comando se procesa de forma atómica para una entrada:

1. resuelve la identidad usuario + manga;
2. carga el estado actual en el contexto del actor;
3. valida valores que no admiten normalización segura;
4. canonicaliza orden, unicidad y, si corresponde, colección completa;
5. actualiza la entrada local;
6. registra o coalesce la intención de sincronización en la misma operación lógica;
7. guarda el contexto;
8. devuelve un resultado por valor, nunca el `@Model` mutable del actor.

Si cambia un total conocido y el estado actual dejaría de ser válido, la actualización no puede confirmar un estado intermedio inválido. Debe reconciliarse mediante una política explícita de servidor o rechazarse atómicamente; nunca se descartan volúmenes silenciosamente.

### Estado persistido anterior a la cota

Un estado persistido por una versión anterior puede contener un total, un tomo en
propiedad o una lectura fuera de `1...300`. Ese estado histórico incompatible se
detecta antes de editarlo, construir rangos o preparar una escritura remota. Sus
valores se conservan sin truncado, borrado o reparación automática y una edición
ordinaria falla mediante una categoría tipada, sin modificar Colección ni outbox.
La presentación explica de forma localizada y segura que el estado guardado no ha
cambiado.

La eliminación explícita es la única mutación admitida sobre ese estado: puede
crear una tombstone conservando los valores históricos necesarios para rollback y
puede enviarse porque `DELETE` identifica únicamente el manga y no transporta
números de tomo. Confirmar el borrado puede retirar la entrada como consecuencia
de esa intención destructiva consciente; esta excepción no permite convertir el
estado incompatible en un payload de alta o edición.

Si una versión anterior dejó un POST incompatible en `sending`, la eliminación
explícita lo deja sin efecto dentro de la misma transacción antes de crear la tombstone
N+1. La operación incierta no se marca falsamente como confirmada: se retira solo
después de haber contribuido a la secuencia monotónica. El DELETE posterior es el
resultado dominante tanto si aquel POST llegó a aplicarse remotamente como si no.
Si el snapshot remoto todavía contiene esa fila incompatible, R1 la reconoce solo
como presencia opaca cuando la primera intención pendiente exacta es la tombstone
procesable N+1: valida identidad y duplicados, pero no importa sus valores ni la
interpreta como ausencia. Una tombstone `queued` puede así ejecutar DELETE; una
`sending` se clasifica como resultado no confirmado por la presencia, sin adoptar
la base inválida ni repetir el borrado. Cualquier otra fila incompatible conserva
el rechazo atómico del snapshot completo.

Eliminar desde el editor es una acción destructiva local-first. Se presenta como
un botón prominente, centrado y solo textual, separado de Guardar. Antes de
crear la tombstone, una alerta nativa identifica el manga cuando su título está
disponible y explica que se perderán los tomos marcados y el progreso de lectura;
volver a añadirlo no restaura esos datos. La alerta exige una confirmación
destructiva explícita y cancelar no ejecuta ninguna mutación.

## Consultas

- Toda consulta de colección se restringe al usuario activo.
- La UI obtiene su estado persistente mediante `@Query` o una proyección derivada de esa consulta.
- Una tombstone no aparece como elemento activo, pero permanece persistida hasta que el servidor confirme su eliminación o se revierta.
- Los órdenes de presentación son independientes del orden canónico de `volumesOwned`.

## Criterios de aceptación

| Caso | Resultado requerido |
| --- | --- |
| Guardar `[3, 1, 3, 2]` sin total conflictivo | Se persiste `[1, 2, 3]`. |
| Guardar `[0, 1]` | El comando falla y no deja una escritura parcial. |
| Guardar `[299, 300]` sin total conocido | Se persiste `[299, 300]`. |
| Guardar `[301]` o `[Int64.max]` sin total conocido | El comando falla y conserva Colección y outbox anteriores. |
| Total conocido `300`, marcar completa | Persiste `complete == true` y el rango acotado `1...300`. |
| Total conocido `301` o `Int64.max` | Falla antes de construir un rango o modificar persistencia. |
| Total conocido `3`, guardar `[1, 4]` | El comando falla y conserva el estado anterior. |
| Lectura `2` con propiedad `[1, 3]` | Estado válido. |
| Total desconocido, lectura `300` | Estado válido. |
| Total desconocido, lectura `301` o `Int64.max` | El comando falla y conserva el estado anterior. |
| Total conocido `3`, lectura `4` | El comando falla. |
| Total desconocido, marcar completa | El comando falla. |
| Total `3`, marcar completa | Persiste `complete == true` y `[1, 2, 3]`. |
| Quitar `2` del estado completo anterior | Persiste `complete == false` y `[1, 3]`. |
| Editor con total `3`, marcar manualmente `1`, `2` y `3` | El borrador activa `complete`. |
| Editor completo con total `3`, desactivar `complete` | El borrador conserva la lectura, pasa a `complete == false` y vacía los volúmenes. |
| Crear dos veces usuario A + manga M | Existe una entrada actualizada, no dos. |
| Mismo manga para usuarios A y B | Existen dos entradas aisladas y cada consulta devuelve solo la propia. |
| Dos mutaciones concurrentes de la misma entrada | El actor las serializa y el resultado final cumple todas las invariantes. |
| Error al guardar outbox o colección | No queda una mitad de la operación confirmada. |
| Abrir o editar un estado histórico fuera de `1...300` | No construye rangos ni altera los valores; presenta el error seguro y bloquea una edición ordinaria. |
| Eliminar explícitamente ese estado histórico | Crea una tombstone sin enviar sus números de tomo; solo una confirmación de DELETE permite retirar la entrada. |
| Eliminar con un POST histórico incompatible en `sending` | Retira la intención N sustituida, conserva el salto monotónico y deja la tombstone N+1 reclamable para DELETE. |
| R1 aún observa la fila incompatible y N+1 es la primera tombstone procesable | Conserva la fila como presencia opaca sin importarla ni confirmar ausencia; `queued` puede enviar DELETE y `sending` queda bloqueada sin repetirlo. |
| Otra intención anterior bloquea N+1 | No aplica la excepción: R1 rechaza atómicamente el dato remoto incompatible. |
| Editor sin total conocido | Añadir y retirar tomos usa botones nativos circulares y bordeados, con `plus` y `trash`, objetivos mínimos de `44 × 44 pt` y etiquetas accesibles inequívocas. |
| Cancelar la alerta de eliminación | No cambia colección ni outbox. |
| Confirmar la alerta de eliminación | Oculta la entrada y persiste su tombstone por la única ruta de mutación. |

Estas reglas deben cubrirse principalmente con Swift Testing y un `ModelContainer` real en memoria. Las pruebas puramente algebraicas pueden ejercitar valores sin contenedor; las restricciones de unicidad, consultas y atomicidad requieren integración SwiftData.

## Errores

La ruta de mutación diferencia al menos semánticamente:

- identidad ausente o incoherente;
- volumen no positivo;
- total o volumen superior a la cota global;
- volumen superior al total conocido;
- colección completa sin total válido;
- estado persistido histórico incompatible con la cota vigente;
- conflicto de persistencia;
- cancelación antes de confirmar una operación.

No se exige que esos sean nombres de casos Swift. Los contratos DocC relevantes deben indicar invariantes, efectos persistentes y condición de error.

## Fuera de alcance y riesgos

- No se infiere propiedad de un volumen a partir del progreso de lectura.
- No se inventa un total cuando el catálogo no lo proporciona de forma fiable.
- La unicidad lógica debe reforzarse en la ruta de mutación aunque la versión usada de SwiftData no pueda expresarla completamente en el esquema.
- Migraciones futuras deben demostrar que preservan estas invariantes antes de reemplazar el almacén existente.

## Especificaciones y decisiones relacionadas

- [Arquitectura y composición](01-architecture-and-composition.md)
- [Autenticación y sincronización](04-authentication-and-sync.md)
- [ADR-0004: SwiftData local-first y model actors](../adr/0004-swiftdata-local-first-and-model-actors.md)
- [ADR-0005: estrategia híbrida de testing](../adr/0005-hybrid-testing-strategy.md)

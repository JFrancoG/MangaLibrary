# ADR-0021: Rotación de lecturas y prioridad de la última edición

**Estado:** Superseded por [ADR-0022](0022-widget-collection-projection-and-adaptive-reading.md)
**Fecha:** 2026-09-07
**Supersede:** [ADR-0010](0010-widgetkit-event-driven-freshness.md)
**Aprobación:** el propietario aprueba rotación lenta con reinicio por el manga actualizado y tamaño grande con grupos de lecturas en DX4, issue #84.

## Contexto

Una lectura destacada y un contador de restantes no permiten consultar el progreso
de las otras lecturas. El propietario quiere conservar ese diseño y ofrecer
también más lecturas simultáneas. WidgetKit recomienda separar las entradas de
timeline unos cinco minutos y conserva la decisión final sobre cuándo mostrarlas.
Una secuencia cada dos o tres segundos no es un contrato realizable.

## Decisión

Se incorporan las decisiones de publicación, almacenamiento, `SessionFence`,
recuperación, privacidad y reload dirigido de ADR-0010. Cambia exclusivamente su
política de presentación de una única entrada `.never`, ampliada con prioridad
local de una edición y una timeline de rotación. No se añade una fuente de verdad,
un escritor, un entitlement, un mecanismo de red o sincronización ni interactividad.

- La misma `StaticConfiguration` y el mismo `kind` ofrecen pequeño, mediano y
  grande. Las ventanas muestran como máximo 1, 3 y 6 lecturas respectivamente;
  las dos últimas reducen filas con `ViewThatFits` para mantener el texto legible.
- La ventana circular avanza un manga cada 300 segundos. Los grupos se solapan:
  así reducir filas por espacio, título o Dynamic Type no omite lecturas.
- `generatedAt` es el ancla local del ciclo, no un orden causal ni una fecha de
  adquisición. El provider conserva la fase al renovar una timeline o recibir
  una recarga del sistema. Una publicación visible nueva reinicia el ciclo.
- Cada petición prepara el slot actual y las doce fronteras siguientes: trece
  entradas como máximo y renovación `.atEnd`. La primera fecha puede ser anterior
  a la petición; las fechas consecutivas quedan separadas 300 segundos. Con cero
  o una lectura, redacción o error, se entrega una entrada con `.never`.
  Si el reloj retrocede antes de `generatedAt`, se entrega primero el foco en
  `now` y después las doce fronteras del ancla. En esa excepción el primer
  intervalo es mayor de 300 segundos y el horizonte puede superar una hora;
  sigue habiendo como máximo trece entradas, ninguna primera entrada futura.
- Una edición individual relevante indica el manga preferido para iniciar el
  ciclo. Guardar valores iguales no publica ni reinicia. Los cambios por lotes no
  inventan una cronología a partir del orden remoto. La preferencia se descarta
  cuando deja de ser una lectura válida y se elimina al redactar la sesión.
  No-op significa igualdad del contenido publicable: una ida y vuelta 1 → 2 → 1
  coalescida antes de publicar conserva bytes, foco y ancla. No se conserva un
  historial de pulsaciones. Cambios visibles de título, total o portada publican
  con nueva ancla y conservan el foco válido; solo una edición de `readingVolume`
  propone un foco nuevo. Reactivar un tombstone mediante propiedad o completitud
  sin cambiar su tomo conservado tampoco propone un foco. Si el manga editado
  estaba excluido por el presupuesto, priorizarlo cambia el manifest publicable
  aunque su progreso vuelva al valor original; no se guarda un historial privado
  de toda la colección para decidir el no-op.
- El snapshot conserva el orden por título. Su nuevo campo opcional de prioridad
  es compatible con formato 1; ausencia significa inicio por el orden canónico.
  Toda reserva de bytes incluye ese campo. Si el preferido quedaría fuera del
  prefijo de 32 KiB, sustituye tantos elementos finales como sea necesario y se
  conserva el orden canónico de la selección resultante. El contador informa
  también de las lecturas excluidas por transporte.
- La extensión prepara únicamente la unión de portadas que puede necesitar en
  ese horizonte, hasta 18 posiciones para la familia grande, con miniaturas
  ImageIO de 160 píxeles como máximo. Recursos ausentes o rechazados usan el
  placeholder; nunca impiden mostrar el título y el progreso.

La app sigue publicando tras commits reales y solicita reload solo después del
envelope/fence seguros. La renovación temporal de presentación relee el bridge
local autorizado: no consulta el servidor ni mantiene ejecución continua.
No se garantiza el instante del cambio, que se rendericen todos los slots ni la
desaparición inmediata de una vista que WidgetKit ya haya almacenado en caché.
Cada nueva lectura debe superar el fence; las vistas mantienen `privacySensitive`.

## Alternativas y consecuencias

Una lista estática mayor mejora la consulta simultánea pero conserva un límite
físico. Los botones permitirían navegar a demanda, a costa de cambiar la superficie
a interactiva. La rotación rápida y ActivityKit no corresponden a este widget
persistente. Se elige combinar ventanas estáticas y rotación pausada.

El ciclo alcanza todas las lecturas **publicadas**, sin prometer colecciones
ilimitadas ni tiempos de entrega. El límite de 32 KiB se conserva deliberadamente
para el bridge compartido con Deluxe; eliminarlo requeriría otro contrato de
transporte. El manga editado obtiene prioridad dentro de ese presupuesto.

La selección prioritaria, compatibilidad, no-op, ciclos, fronteras temporales,
renovaciones, retirada y redacción requieren pruebas con fechas inyectadas y
colecciones sintéticas. Previews verifican filas, estados e idiomas. La cadencia
real y privacidad en hardware se registran separadamente de esa evidencia.

## Referencias

- [SDD 05](../specs/05-deluxe-watch-and-widget.md), [SDD 09](../specs/09-deluxe-reading-contract.md)
- Apple: [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/)
- Apple: [Timeline](https://developer.apple.com/documentation/widgetkit/timeline)

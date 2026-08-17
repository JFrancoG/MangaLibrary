# ADR-0007: Puentes de datos para watchOS y WidgetKit

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

El nivel Deluxe añade superficies de consulta en Apple Watch y widgets. Abrir el
mismo almacén SwiftData desde varios procesos o intentar compartir modelos vivos
entre dispositivos introduciría coordinación, migración y aislamiento difíciles de
garantizar para vistas que solo necesitan una proyección pequeña.

## Drivers

- Mantener a la app iOS como única propietaria de mutaciones y sincronización.
- Entregar datos mínimos, versionados y tolerantes a ausencia o antigüedad.
- Evitar abrir el almacén principal desde extensiones o el reloj.

## Opciones consideradas

1. **Puentes de snapshots:** WatchConnectivity para watchOS y archivo en App Group
   para WidgetKit; reduce acoplamiento a cambio de consistencia eventual.
2. **Compartir el almacén SwiftData con el widget:** evita proyecciones, pero
   expone el store a procesos, migraciones y escrituras concurrentes.
3. **Sincronización remota independiente en cada superficie:** ofrece autonomía,
   pero duplica autenticación, conflictos y consumo de recursos.

## Decisión

La app de watchOS será de solo lectura. La app iOS producirá DTOs versionados y
mínimos y los transferirá mediante WatchConnectivity; el reloj conservará el
último snapshot válido y representará explícitamente su antigüedad. El envelope
incluirá una generación opaca de sesión, una revisión de publicación monotónica
entre sesiones y un estado de contenido o redacción. El instante de generación
será informativo y no decidirá el orden.

Para WidgetKit, la app iOS escribirá atómicamente el mismo envelope versionado en
un App Group y solicitará la recarga de timelines cuando corresponda. La
extensión leerá ese snapshot y nunca abrirá el `ModelContainer` principal. Los
consumidores ignorarán revisiones repetidas o anteriores; una redacción solo
afectará a su generación de sesión, por lo que una entrega tardía de la cuenta A
no podrá borrar ni sustituir contenido posterior de la cuenta B. Ninguna de estas
superficies escribirá la colección ni gestionará tokens.

## Consecuencias

### Positivas

- Los procesos auxiliares no compiten por el store ni conocen modelos SwiftData.
- El conjunto de datos compartido es pequeño, auditable y puede minimizar
  información sensible.
- Las superficies pueden mostrar el último estado válido sin conectividad.

### Negativas

- Los datos son eventualmente consistentes y pueden quedar obsoletos.
- Hay que versionar, serializar y probar dos mecanismos de transporte.
- Las acciones de escritura desde reloj o widget quedan fuera de alcance.

## Validación

- Probar snapshot ausente, antiguo, incompatible y corrupto con fallback seguro.
- Probar WatchConnectivity no alcanzable y entregas repetidas o fuera de orden.
- Probar la secuencia contenido A, redacción A, contenido B y entregas tardías de
  A sin mezclar ni retirar B.
- Verificar que los targets auxiliares no enlazan ni abren el store de SwiftData.

## Condiciones de revisión

- El producto exige mutaciones desde watchOS o widgets interactivos.
- Una API de plataforma ofrece compartición transaccional con aislamiento y
  migraciones adecuadas para estos procesos.

## Especificaciones relacionadas

- [Deluxe, watchOS y widget](../specs/05-deluxe-watch-and-widget.md)
- [Alcance y niveles del producto](../specs/00-product-scope-and-levels.md)
- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)

# ADR-0008: DocC selectivo y límites de publicación

**Estado:** Superseded
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** [ADR-0012](0012-private-repository-and-sanitized-practice-source.md)

## Contexto

El proyecto necesita documentación técnica fiable sin convertir cada símbolo en
texto redundante. Además, `docs/` ya tiene una función clara para documentos
humanos versionados y no debe mezclarse con catálogos del target ni artefactos
generados.

## Drivers

- Documentar contratos que reduzcan errores de uso y mantenimiento.
- Validar enlaces y diagnósticos DocC con la misma exigencia que el código.
- Separar fuentes públicas, notas privadas y resultados regenerables.

## Opciones consideradas

1. **DocC selectivo dentro del target:** integra símbolos y artículos con el build,
   manteniendo `docs/` humano; exige criterio editorial.
2. **Documentar exhaustivamente todos los símbolos:** maximiza cobertura nominal,
   pero genera ruido y contenido que envejece sin aportar semántica.
3. **Catálogo bajo `docs/` y publicación inmediata con plugin/Pages:** centraliza
   archivos, pero mezcla audiencias y añade infraestructura antes de necesitarla.

## Decisión

DocC cubrirá selectivamente contratos, invariantes, estados, errores,
cancelación, idempotencia y efectos observables. No se documentarán propiedades
triviales, conformidades mecánicas, Views, helpers o tests solo para aumentar
cobertura.

El catálogo residirá dentro del target de la app, en
`MangaLibrary/Documentation/MangaLibrary.docc/`. `docs/` se reservará para
especificaciones, ADRs y documentación humana pública. Los `.doccarchive`,
directorios de build y demás salidas generadas se ignorarán. El build DocC tratará
warnings como errores. No se incorporará un plugin de publicación ni GitHub Pages
antes de la entrega del 15 de septiembre de 2026. Una publicación posterior será
una decisión y autorización separadas. Las notas privadas permanecerán fuera del
repositorio, en Obsidian.

## Consecuencias

### Positivas

- La documentación concentra esfuerzo en semántica difícil de inferir del código.
- `docs/`, el catálogo del target y Obsidian tienen propietarios y audiencias
  inequívocos.
- Los errores de enlaces y símbolos bloquean antes de publicar.

### Negativas

- La cobertura cuantitativa no será un indicador útil por sí solo.
- Seleccionar qué documentar requiere revisión experta y mantenimiento editorial.
- No habrá sitio público navegable hasta abordar expresamente la entrega.

## Validación

- Construir DocC con warnings como errores y comprobar enlaces de símbolos y
  artículos.
- Revisar que cada comentario aporta contrato o comportamiento no obvio.
- Confirmar que ningún archive, build ni contenido privado está versionado.

## Condiciones de revisión

- La entrega requiere publicar DocC y se puede decidir hosting, versionado y URL.
- El proyecto se divide en módulos o paquetes que necesitan catálogos separados.
- Cambian las fronteras entre material público y privado.

## Especificaciones relacionadas

- [Alcance y niveles del producto](../specs/00-product-scope-and-levels.md)
- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
- [Documentación y DocC](../specs/07-documentation-and-docc.md)
- [Entrega, presentación y vídeo](../specs/08-delivery-presentation-and-video.md)

# Documentación de Manga Library

Este directorio contiene la documentación humana versionada dentro del repositorio privado. No es la salida de DocC ni un almacén de notas privadas.

## Autoridad

Para resolver discrepancias, consulta [AGENTS.md](../AGENTS.md). En resumen: petición aprobada, SDD, ADR Accepted, constitución, guías, progreso e issue operativo.

## Navegación

### Especificaciones

- [00 — Alcance de producto y niveles](specs/00-product-scope-and-levels.md)
- [01 — Arquitectura y composición](specs/01-architecture-and-composition.md)
- [02 — API, catálogo, búsqueda e imágenes](specs/02-api-catalog-search-and-images.md)
- [03 — Colección local e invariantes](specs/03-local-collection-and-invariants.md)
- [04 — Autenticación y sincronización](specs/04-authentication-and-sync.md)
- [05 — Deluxe, watchOS y widget](specs/05-deluxe-watch-and-widget.md)
- [06 — Testing, calidad y accesibilidad](specs/06-testing-quality-and-accessibility.md)
- [07 — Documentación y DocC](specs/07-documentation-and-docc.md)
- [08 — Entrega, presentación y vídeo](specs/08-delivery-presentation-and-video.md)

### Contrato API

- [Caracterización del contrato OpenAPI](api/openapi-contract.md)
- [Snapshot OpenAPI canónico y sanitizado](../Contracts/OpenAPI/openapi.json)
- [Checksum SHA-256](../Contracts/OpenAPI/SHA256SUMS)

### Fuentes versionadas

- [Enunciado completo saneado de la práctica](sources/Practica_Mis_Mangas_SDP_2026.md)
- [Autoridad, procedencia y límites de uso](Sources.md)

### Decisiones y estado

- [Índice de ADR](adr/README.md)
- [Progreso y evidencia](Progress.md)

### Material de entrega

- [Outline de presentación](presentation/outline.md)
- [Guía de vídeo](video/README.md)
- [Storyboard de vídeo](video/storyboard.md)

## DocC

El catálogo fuente vive en `MangaLibrary/Documentation/MangaLibrary.docc/`. Conserva una landing breve y extrae documentación selectiva de los contratos de red y carga que ya necesitan explicar validación, errores y cancelación. [El gate reproducible](../Scripts/validate-docc.sh) genera `.build/docc/MangaLibrary.doccarchive`, ignorado por Git. No se genera un sitio dentro de `/docs`.

## Privacidad

Notas de orador, ensayos, logs de grabación, rutas locales y material docente no aprobado permanecen fuera del repositorio. El enunciado saneado es la única fuente docente completa versionada; el original exacto sigue fuera de Git. GitHub Issues es el tracker operativo y este directorio conserva la verdad normativa y la evidencia durable.

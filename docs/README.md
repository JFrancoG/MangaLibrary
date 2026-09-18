# Documentación de Manga Library

Este directorio contiene la documentación humana versionada. El repositorio está
público temporalmente para la corrección académica conforme a
[ADR 0023](adr/0023-temporary-public-access-for-assessment.md). No es la salida
de DocC ni un almacén de notas privadas.

## Para empezar

- [README en inglés](../README.md) · [README en español](../README.es.md)
- [Desarrollo, configuración local y validación](development.md)
- [Estado y evidencia fechada](Progress.md): último checkpoint de producto C6, PR #125, del 14 de septiembre; ReleaseGate 846 declaraciones / 1.274 invocaciones. La revisión documental del 18 de septiembre no reejecuta esos gates.

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
- [09 — Contrato de lectura Deluxe](specs/09-deluxe-reading-contract.md) — proyección, recuperación y publicación DX1–DX3; widgets de lectura/colección DX4 y companion Watch DX5 y caché acotada de portadas C6. Las matrices [DX6](dx6-integration-accessibility.md) y [DX7](dx7-deluxe-release-gate.md) separan los cortes técnicos entregados de los criterios físicos pendientes. [Progress](Progress.md) registra las correcciones posteriores hasta C6, con 5/7 subfases plenamente entregadas y la implementación técnica DX1–DX7 integrada.

### Contrato API

- [Caracterización del contrato OpenAPI](api/openapi-contract.md)
- [Snapshot OpenAPI canónico y sanitizado](../Contracts/OpenAPI/openapi.json)
- [Checksum SHA-256](../Contracts/OpenAPI/SHA256SUMS)

### Diseño

- [Contrato cromático Library Red](design/brand-palette.md)
- [Tokens cromáticos canónicos y auditables](design/library-color-tokens.json)

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

El catálogo fuente vive en `MangaLibrary/Documentation/MangaLibrary.docc/`. Conserva una landing breve y extrae documentación selectiva de contratos, invariantes, efectos, errores, aislamiento y recuperación no obvios; no replica las SDD ni mide cobertura por cantidad. [El gate reproducible](../Scripts/validate-docc.sh) genera `.build/docc/MangaLibrary.doccarchive`, ignorado por Git. No se genera un sitio dentro de `/docs`.

## Privacidad

Notas de orador, ensayos, logs de grabación, rutas locales y material docente no aprobado permanecen fuera del repositorio. El enunciado saneado es la única fuente docente completa versionada; el original exacto sigue fuera de Git. GitHub Issues es el tracker operativo y este directorio conserva la verdad normativa y la evidencia durable.

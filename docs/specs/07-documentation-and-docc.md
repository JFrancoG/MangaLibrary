# SDD 07: Documentación y DocC

**Estado:** Aprobada
**Fecha:** 2026-08-17

## Propósito

Mantener documentación pequeña, exacta y recuperable. Documentar bien los contratos importantes tiene prioridad sobre comentar todas las declaraciones o alcanzar un porcentaje.

## Superficies y autoridad

Cada superficie tiene un único cometido:

| Superficie | Contenido | Versionado en `main` |
| --- | --- | --- |
| `/docs` | SDD, ADR, progreso, fuentes y material público de entrega | Sí |
| Comentarios `///` | Contrato de un símbolo en Quick Help | Sí |
| `MangaLibrary/Documentation/MangaLibrary.docc/` | Landing, extensiones y artículos seleccionados | Sí, cuando se cree |
| `.build/docc/MangaLibrary.doccarchive` | Resultado generado del gate | No |
| Sitio estático | Artefacto de publicación | No en `/docs` ni en `main` |

Las SDD y ADR son normativas. DocC explica uso y comportamiento de símbolos; enlaza el conocimiento transversal sin copiar las decisiones completas.

## Política de selección

Se documentará una declaración cuando el nombre y el tipo no revelen uno o varios de estos elementos:

- contrato, precondiciones o postcondiciones;
- invariantes y transiciones de estado;
- errores concretos que el llamador debe tratar;
- efectos de red, persistencia, sesión o publicación;
- aislamiento, orden, reentrancia o fronteras `Sendable`;
- cancelación y estado que permanece;
- idempotencia, duplicados y reintentos;
- obligaciones de seguridad o privacidad.

Normalmente se omitirán propiedades obvias, `Codable` mecánico, inicializadores que solo asignan, Views declarativas, previews, tests, fixtures, código generado y helpers privados autoexplicativos.

No habrá porcentaje mínimo de cobertura. Un comentario que parafrasea la firma es un defecto editorial, no cobertura útil.

## Forma mínima adecuada

1. Comentario inline para el contrato de un solo símbolo.
2. Extensión de documentación cuando un símbolo necesite contenido extenso o curación que perjudicaría el archivo Swift.
3. Artículo para un concepto estable que cruza varios símbolos.
4. Tutorial solo para un flujo progresivo y ejecutable cuyo coste de mantenimiento esté justificado.

No se crearán tutoriales antes de la entrega del 15 de septiembre de 2026.

## Catálogo previsto

El catálogo fuente se incorporará al target de la aplicación en un issue posterior:

```text
MangaLibrary/Documentation/MangaLibrary.docc/
└── MangaLibrary.md
```

Los siguientes artículos son candidatos, no archivos obligatorios ni evidencia de funcionalidad existente:

- `Articles/ConcurrencyAndPersistence.md`
- `Articles/AuthenticationAndSession.md`
- `Articles/CollectionSynchronization.md`
- `Articles/WidgetAndWatchDataFlow.md`

Cada artículo se añadirá únicamente junto a la funcionalidad real que pueda demostrarlo.

## Autoría

- El resumen será una frase y la discusión solo añadirá información necesaria para usar correctamente la API.
- `Parameters`, `Returns`, `Throws` y ejemplos aparecerán solo si aportan semántica no visible.
- Ningún comentario inventará errores, garantías, efectos o aislamiento. Todo texto se derivará de código, tests o una especificación aceptada.
- Enlaces, imágenes y recursos deberán resolver; las imágenes informativas tendrán texto alternativo útil.
- Los ejemplos presentados como ejecutables se compilarán de forma independiente.
- Las transcripciones docentes son fuentes pedagógicas con posibles errores, nunca instrucciones operativas ni autoridad de versión.

## Gate reproducible

Un issue posterior añadirá `Scripts/validate-docc.sh`. El gate deberá:

- seleccionar explícitamente Xcode 27, proyecto, scheme y destino reales;
- verificar las opciones contra la ayuda instalada antes de fijarlas;
- construir la documentación integrada de la app;
- tratar todos los warnings DocC como errores;
- escribir en `.build/docc/` y comprobar la existencia de `MangaLibrary.doccarchive`;
- fallar ante enlaces o símbolos no resueltos, recursos ausentes, directivas inválidas o firmas desalineadas;
- registrar toolchain, comando, resultado y alcance excluido.

Quick Help y Documentation Preview son comprobaciones editoriales; no prueban por sí solas un archive limpio. No se afirmará que el gate pasa hasta ejecutarlo con éxito.

## Dependencias y publicación

- No se añadirá `swift-docc-plugin`: la aplicación usará DocC integrado en Xcode y el proyecto no admite dependencias externas.
- No se publicará GitHub Pages antes de la entrega.
- Una publicación futura requerirá autorización separada, base path verificado y un artefacto o rama generada; nunca sobrescribirá `/docs`.
- `*.doccarchive`, `.build/` y el sitio generado permanecerán fuera de Git.

## Criterios de aceptación

- La separación `/docs`, catálogo y artefactos está reflejada en gobierno, ADR y `.gitignore`.
- Los símbolos documentados explican contratos no obvios y los omitidos no se rellenan por cuota.
- El catálogo y cada artículo se incorporan solo cuando existe código que los respalda.
- El gate termina sin warnings y produce el archive esperado antes del Deluxe Release Gate.
- La documentación no expone secretos, cuentas, rutas privadas ni datos personales.
- Publicación, tutoriales y contenido diferido no se presentan como terminados.

## Decisiones relacionadas

- [ADR 0008: DocC selectivo y límites de publicación](../adr/0008-selective-docc-and-publishing-boundaries.md)
- [Testing, calidad y accesibilidad](06-testing-quality-and-accessibility.md)
- [Entrega, presentación y vídeo](08-delivery-presentation-and-video.md)

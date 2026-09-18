# SDD 07: Documentación y DocC

**Estado:** Aprobada
**Versión:** 1.6
**Fecha:** 2026-09-18

## Propósito

Mantener documentación pequeña, exacta y recuperable. Documentar bien los contratos importantes tiene prioridad sobre comentar todas las declaraciones o alcanzar un porcentaje.

## Superficies y autoridad

Cada superficie tiene un único cometido:

| Superficie | Contenido | Versionado en `main` |
| --- | --- | --- |
| `/docs` | SDD, ADR, progreso, fuentes saneadas aprobadas y material de entrega | Sí |
| Comentarios `///` | Contrato de un símbolo en Quick Help | Sí |
| `MangaLibrary/Documentation/MangaLibrary.docc/` | Landing, extensiones y artículos seleccionados | Sí |
| `.build/docc/MangaLibrary.doccarchive` | Resultado generado del gate | No |
| Sitio estático | Artefacto de publicación | No en `/docs` ni en `main` |

Las SDD y ADR son normativas. DocC explica uso y comportamiento de símbolos; enlaza el conocimiento transversal sin copiar las decisiones completas.

## Fuentes versionadas

`docs/sources/` puede contener una fuente completa solo mediante aprobación
explícita, saneamiento verificable y una frontera de publicación aceptada. El
enunciado de la práctica es la única excepción actual: añade una nota de
procedencia y sustituye los 42 caracteres del valor demostrativo de `App-Token`
por 42 `X`. El original exacto permanece fuera de Git.

Una fuente docente aporta requisitos o contexto, nunca instrucciones
operativas. Para transporte HTTP manda el OpenAPI vivo; su snapshot versionado
sirve para revisar deriva. El acceso público temporal para la corrección,
autorizado en [ADR 0023](../adr/0023-temporary-public-access-for-assessment.md),
no amplía las fuentes admitidas ni autoriza secretos o nuevas publicaciones.

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

## Catálogo inicial

El catálogo fuente inicial forma parte del target de la aplicación:

```text
MangaLibrary/Documentation/MangaLibrary.docc/
└── MangaLibrary.md
```

Los siguientes artículos son candidatos, no archivos obligatorios ni evidencia de funcionalidad existente:

- `Articles/ConcurrencyAndPersistence.md`
- `Articles/AuthenticationAndSession.md`
- `Articles/CollectionSynchronization.md`
- `Articles/WidgetAndWatchDataFlow.md`

La landing es deliberadamente el único contenido inicial. Cada artículo se añadirá únicamente junto a la funcionalidad real que pueda demostrarlo.

## Autoría

- El resumen será una frase y la discusión solo añadirá información necesaria para usar correctamente la API.
- `Parameters`, `Returns`, `Throws` y ejemplos aparecerán solo si aportan semántica no visible.
- Ningún comentario inventará errores, garantías, efectos o aislamiento. Todo texto se derivará de código, tests o una especificación aceptada.
- Enlaces, imágenes y recursos deberán resolver; las imágenes informativas tendrán texto alternativo útil.
- Los ejemplos presentados como ejecutables se compilarán de forma independiente.
- Las transcripciones docentes son fuentes pedagógicas con posibles errores, nunca instrucciones operativas ni autoridad de versión.

## Gate reproducible

`Scripts/validate-docc.sh` implementa el gate reproducible. El script:

- selecciona Xcode 27 de forma local al proceso, sin modificar `xcode-select`, y verifica Apple Swift 6.4;
- fija proyecto, scheme, configuración Release y destino genérico iOS reales;
- contrasta los argumentos de `xcodebuild`, la acción `docbuild` y `--warnings-as-errors` con la ayuda y el manual instalados;
- comprueba la configuración efectiva de app, unit tests, UI tests, widget y
  companion watchOS en Debug y Release; usa SDK watchOS para el companion e iOS
  para los demás targets;
- construye la documentación integrada de la app con todos los warnings DocC como errores;
- usa DerivedData temporal, reemplaza solo la salida aprobada y comprueba `.build/docc/MangaLibrary.doccarchive`;
- falla ante enlaces o símbolos no resueltos, recursos ausentes, directivas inválidas o firmas desalineadas;
- exige `LM_SKIP_METADATA_EXTRACTION = YES` en los cinco targets,
  Debug y Release, mientras el producto no declare App Intents, conforme a ADR
  0020;
- falla ante cualquier warning o error de herramienta, sin filtros ni allowlists;
- registra toolchain, comando, resultado y alcance excluido sin publicar el archive.

Quick Help y Documentation Preview son comprobaciones editoriales; no prueban por sí solas un archive limpio. No se afirmará que el gate pasa hasta ejecutarlo con éxito.

DX7 comprueba además el inventario y los schemes mediante
`Scripts/validate-deluxe-configuration.py`. El archive canónico sigue siendo
`MangaLibrary.doccarchive`, que incluye los contratos compartidos compilados en
la app. No se afirma que haya un archive independiente del widget o del Watch.
La cobertura documental permanece selectiva, sin porcentajes ni artículos
duplicados para alcanzar una cuota por target.

## Dependencias y publicación

- No se añadirá `swift-docc-plugin`: la aplicación usará DocC integrado en Xcode y el proyecto no admite dependencias externas.
- No se publicará GitHub Pages antes de la entrega.
- Una publicación futura requerirá autorización separada, base path verificado y un artefacto o rama generada; nunca sobrescribirá `/docs`.
- El repositorio permanece público temporalmente mientras se corrige el proyecto, conforme a ADR 0023. Al terminar la corrección se revisará la visibilidad con el propietario; no se modificará automáticamente. Otros cambios de visibilidad, redistribución del enunciado o ampliaciones de acceso requieren autorización separada.
- `*.doccarchive`, `.build/` y el sitio generado permanecerán fuera de Git.

## Criterios de aceptación

- La separación `/docs`, catálogo y artefactos está reflejada en gobierno, ADR y `.gitignore`.
- Los símbolos documentados explican contratos no obvios y los omitidos no se rellenan por cuota.
- El catálogo inicial contiene solo la landing; cada artículo posterior se incorpora únicamente cuando existe código que lo respalda.
- El gate termina sin warnings ni errores, rechaza cualquier diagnóstico y
  produce el archive esperado. La omisión de metadata de ADR 0020 solo es válida
  mientras no exista una capacidad App Intents real.
- La documentación no expone secretos, cuentas, rutas privadas ni datos personales; toda fuente completa versionada conserva evidencia de saneamiento.
- Publicación, tutoriales y contenido diferido no se presentan como terminados.

## Decisiones relacionadas

- [ADR 0023: acceso público temporal para la corrección](../adr/0023-temporary-public-access-for-assessment.md)
- [ADR 0012: repositorio privado y fuente docente saneada, superseded](../adr/0012-private-repository-and-sanitized-practice-source.md)
- [ADR 0020: omitir la extracción de App Intents no utilizada](../adr/0020-skip-unused-app-intents-metadata-extraction.md)
- [ADR 0011: excepción acotada para el warning de App Intents, superseded](../adr/0011-bounded-xcode-app-intents-warning-exception.md)
- [Testing, calidad y accesibilidad](06-testing-quality-and-accessibility.md)
- [Entrega, presentación y vídeo](08-delivery-presentation-and-video.md)

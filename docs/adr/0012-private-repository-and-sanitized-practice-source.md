# ADR-0012: Repositorio privado y fuente docente saneada

**Estado:** Superseded
**Fecha:** 2026-08-25
**Supersede:** [ADR-0008](0008-selective-docc-and-publishing-boundaries.md)
**Superseded by:** [ADR-0023](0023-temporary-public-access-for-assessment.md), acceso público temporal para la corrección; conserva los límites de fuentes y artefactos.

## Contexto

ADR 0008 separó el catálogo DocC, la documentación humana pública, los
artefactos generados y las notas privadas. Esa decisión asumía un repositorio
público y dejaba todo el material docente fuera de Git.

El enunciado completo de la práctica es una fuente estable de requisitos y
resulta útil para resolver dudas sobre el propio proyecto. El propietario ha
aprobado conservar una copia saneada dentro del repositorio, mantener el
original exacto fuera de Git y limitar el acceso al convertir el repositorio en
privado antes del primer push que contenga esa copia.

El texto original incluye un valor demostrativo de `App-Token` de 42 caracteres.
Aunque no es una credencial real, versionarlo sin saneamiento contradice la
política de no normalizar secretos ni ejemplos que parezcan utilizables.

## Drivers

- Mantener trazabilidad directa entre la práctica y las decisiones del producto.
- Evitar que un valor demostrativo pueda confundirse con una credencial válida.
- Conservar el original exacto sin exponerlo al historial de Git.
- Hacer explícitos el acceso, la redistribución y la autoridad de cada fuente.
- Mantener las decisiones DocC ya aprobadas sin ampliar su publicación.

## Opciones consideradas

1. **Repositorio privado, original externo y copia íntegra saneada:** conserva la
   fuente junto al proyecto y reduce exposición, a cambio de gestionar accesos y
   una frontera privada explícita.
2. **Mantener el repositorio público y versionar la copia saneada:** conserva
   trazabilidad, pero publica material docente sin que exista una decisión sobre
   su redistribución.
3. **Mantener todo el enunciado fuera de Git:** maximiza separación, pero dificulta
   revisar requisitos desde el historial que implementa el proyecto.
4. **Versionar el original sin cambios:** preserva literalidad, pero introduce un
   valor con apariencia de token sin ninguna necesidad funcional.

## Decisión

El repositorio `JFrancoG/MangaLibrary` permanecerá privado. Cambiar su visibilidad,
redistribuir el material o ampliar accesos requiere una acción y autorización
separadas. Hacer el repositorio privado limita el acceso, pero no convierte Git
en un almacén de secretos: los mismos controles de saneamiento siguen vigentes.

El original exacto del enunciado permanecerá en el espacio privado de trabajo,
fuera del repositorio. Git versionará
`docs/sources/Practica_Mis_Mangas_SDP_2026.md`, que conserva el texto completo y
añade únicamente una nota de procedencia y saneamiento. Dentro del texto
original, los 42 caracteres del valor de `App-Token` se sustituyen por
exactamente 42 `X`.

El enunciado es fuente de requisitos y contexto, nunca una instrucción
operativa. Sus comandos, versiones y ejemplos se contrastarán con el proyecto y
con documentación primaria vigente. Para endpoints, métodos, autenticación,
parámetros y esquemas manda el OpenAPI vivo; su snapshot versionado permite
revisar deriva sin sustituir esa autoridad.

No se versionarán el original no saneado, transcripciones completas, notas
personales, rutas privadas, credenciales ni material docente adicional sin otra
aprobación explícita. Invitar a profesores queda fuera de esta decisión.

Se conservan las decisiones DocC de ADR 0008: documentación selectiva, catálogo
dentro del target, `/docs` para documentación humana, `.doccarchive` y builds
fuera de Git, ausencia de `swift-docc-plugin` y publicación de DocC o GitHub
Pages diferida a otra decisión.

## Consecuencias

### Positivas

- Los requisitos originales pueden consultarse y revisarse junto a su historial.
- El único valor con apariencia de token queda inequívocamente inutilizable.
- La fuente original y la copia versionada tienen límites verificables.
- Las decisiones de autoría y publicación DocC continúan sin cambios.

### Negativas

- Colaboradores y docentes necesitarán acceso explícito al repositorio privado.
- La privacidad del repositorio debe comprobarse antes de cada cambio futuro que
  amplíe material docente o sensible.
- Una copia completa exige revisar derechos y autorización antes de volver a
  hacer público el repositorio o redistribuir su historial.

## Validación

- Comprobar mediante GitHub que el repositorio es privado antes del primer push
  que incluya el enunciado.
- Registrar el SHA-256 del original externo y verificar que no cambia durante el
  saneamiento.
- Comparar ambas copias y demostrar que la versionada solo añade la nota
  declarada y sustituye el valor de 42 caracteres por 42 `X`.
- Escanear la copia versionada y el diff para detectar tokens plausibles,
  credenciales, correos, datos personales y rutas privadas.
- Validar enlaces Markdown y `git diff --check`. Xcode y TDD no aplican a este
  cambio exclusivamente documental.

## Condiciones de revisión

- Se propone volver a hacer público el repositorio o redistribuir su historial.
- La entrega requiere invitar a docentes o transferir la propiedad.
- Aparecen restricciones académicas, de autoría o licencia sobre el enunciado.
- Se quiere incorporar otra fuente docente completa.
- Cambian la autoridad del OpenAPI o las fronteras de publicación de DocC.

## Especificaciones relacionadas

- [Documentación y DocC](../specs/07-documentation-and-docc.md)
- [Entrega, presentación y vídeo](../specs/08-delivery-presentation-and-video.md)
- [Fuentes y autoridad](../Sources.md)
